"""Decode pinned NES source graphics into indexed research frames, not production assets.

No ROM is fetched or assembled. Inputs are the public pinned ASM, sprite tables,
symbol map, and explicitly listed gfx blocks cached under build/canonical-source.
The PNG writer uses only the standard library. Palette *indices* come from source;
display RGB is an illustrative 2C02 palette, not a claim about an analog CRT.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / 'build/canonical-source'
OUT = Path(__file__).resolve().parent
PIN = 'f1a43b69577246850d136473700a333b3cdfe93f'


def number(token):
    token = token.strip()
    return int(token[1:], 16) if token.startswith('$') else int(token)


def signed(value): return value-256 if value>=128 else value


def byte_blocks(path):
    data, labels = bytearray(), {}
    for raw in path.read_text(encoding='utf-8', errors='replace').splitlines():
        line = raw.split(';', 1)[0]
        match = re.match(r'^([^\s:]+):', line)
        if match:
            labels[match[1]] = len(data)
        if '.BYTE' in line.upper():
            part = re.split(r'\.BYTE', line, flags=re.I)[1]
            data.extend(number(v) & 255 for v in part.split(',') if v.strip())
    names = list(labels)
    blocks = {name: bytes(data[start:labels[names[i+1]] if i+1 < len(names) else len(data)])
              for i, (name, start) in enumerate(labels.items())}
    return bytes(data), labels, blocks


def main_block(text, label):
    body = text.split(label + ':', 1)[1]
    lines = []
    for line in body.splitlines():
        if re.match(r'^[^\s:]+:', line):
            break
        lines.append(line.split(';', 1)[0])
    return '\n'.join(lines)


def numeric_block(text, label):
    return [number(v) for line in main_block(text, label).splitlines() if '.BYTE' in line
            for v in line.split('.BYTE')[1].split(',') if v.strip()]


def unpack4(path, tiles, following=None):
    packed = path.read_bytes() + (following.read_bytes() if following else b'')
    zero, ones = packed[:2]
    output, cursor = bytearray(), 2
    while len(output) < tiles * 16:
        value = packed[cursor]; cursor += 1
        if value in (zero, ones):
            count = packed[cursor] or 256; cursor += 1
            output.extend(bytes([0 if value == zero else 255]) * count)
        else:
            output.append(value)
    assert len(output) == tiles * 16, (path, len(output), tiles * 16)
    if following is None:
        assert cursor == len(packed), (path, cursor, len(packed))
    return bytes(output)


def png(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    scan = b''.join(b'\0' + pixels[y*width*4:(y+1)*width*4] for y in range(height))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(scan, 9)) + chunk(b'IEND', b''))


def rgba(index):
    # Only the palette codes currently used by the source character palette.
    colors = {0x0f:(18,19,20),0x0a:(0,102,0),0x1a:(88,184,44),0x17:(155,83,0),
              0x27:(250,160,66),0x18:(117,118,0),0x28:(205,202,62),0x20:(255,255,255),
              0x16:(180,0,0),0x26:(255,100,97)}
    return colors.get(index, (180,180,180)) + (255,)


def glyph(canvas, width, x, y, value, color=(226,234,238,255)):
    font = ['111101101101111','010110010010111','111001111100111','111001111001111',
            '101101111001001','111100111001111','111100111101111','111001001001001',
            '111101111101111','111101111001111','010101111101101','110101110101110',
            '111100100100111','110101101101110','111100110100111','111100110100100']
    for digit in f'{value:02X}':
        for i, bit in enumerate(font[int(digit,16)]):
            if bit == '1':
                pos=((y+i//3)*width+x+i%3)*4; canvas[pos:pos+4]=bytes(color)
        x += 5


def sheet(frames, path, scale=4, columns=8):
    cellw = max(f['width'] for f in frames) * scale + 24
    cellh = max(f['height'] for f in frames) * scale + 25
    width, height = columns * cellw, ((len(frames)+columns-1)//columns)*cellh
    canvas = bytearray(bytes((39,43,48,255))*(width*height))
    for i, frame in enumerate(frames):
        ox, oy = (i%columns)*cellw, (i//columns)*cellh
        glyph(canvas,width,ox+5,oy+7,frame['frameId'])
        for py in range(frame['height']):
            for px in range(frame['width']):
                color=frame['pixels'][(py*frame['width']+px)*4:(py*frame['width']+px+1)*4]
                if color[3]:
                    for dy in range(scale):
                        for dx in range(scale):
                            x=ox+12+px*scale;y=oy+18+py*scale
                            pos=((y+dy)*width+x+dx)*4;canvas[pos:pos+4]=color
    png(path,width,height,canvas)


def main():
    for pattern in ('hero-*.png','object-*.png'):
        for path in (OUT/'frames').glob(pattern):path.unlink()
    main_path=CACHE/'main.asm'
    text=main_path.read_text(encoding='utf-8',errors='replace')
    raw, labels, gfx=byte_blocks(CACHE/'gfx/rash.asm')
    bank={}
    for filename,base in [('spr_lists1.asm',0xae89),('spr_lists2.asm',0xc838)]:
        data, _, _=byte_blocks(CACHE/'data'/filename)
        bank.update({base+i:v for i,v in enumerate(data)})
    # Some object configurations remain literal inline byte runs in main.asm.
    # The pinned IDA listing records each run's starting address; continuation
    # rows intentionally repeat that address, so advance through their bytes.
    listing=CACHE/'source.lst'
    last_address=None;cursor=0;listing_matches=0
    for line in listing.read_text(encoding='utf-8',errors='replace').splitlines():
        match=re.match(r'BANK6:([0-9A-F]{4})\s+(.*)',line)
        if not match or '.BYTE' not in match[2]:continue
        address=int(match[1],16)
        try: values=[number(t)&255 for t in match[2].split('.BYTE')[1].split(';')[0].split(',') if t.strip()]
        except ValueError:last_address=None;continue
        if address!=last_address:cursor=address
        for value in values:
            if cursor in bank:
                assert bank[cursor]==value, ('source/listing byte disagreement',hex(cursor))
                listing_matches+=1
            bank[cursor]=value;cursor+=1
        last_address=address
    def read(address,count): return bytes(bank[address+i] for i in range(count))
    lo,hi=numeric_block(text,'rash_sprcfg_ptr_l'),numeric_block(text,'rash_sprcfg_ptr_h')
    refs=re.findall(r'\.WORD\s+(\w+)',main_block(text,'gfx_ptrs'))
    palettes=numeric_block(text,'palette_chars')[:16]
    raw_prefix=b''.join((CACHE/'gfx'/p).read_bytes() for p in ('sprite0.chr','game_std.chr','level1_obj.4'))
    static=b''.join([raw_prefix[:0x21*16],(CACHE/'gfx/game_std.chr').read_bytes(),
        unpack4(CACHE/'gfx/level1_obj.4',0x83),unpack4(CACHE/'gfx/levels1_5_obj.4',0x23),
        unpack4(CACHE/'gfx/tall_walker.4',0xa),unpack4(CACHE/'gfx/stick.4',4),
        # The source declares ten common tiles although this packed block
        # expands to nine: its actual stream continues into the next incbin.
        unpack4(CACHE/'gfx/common.4',0xa,CACHE/'gfx/byte_BC65.chr'),(CACHE/'gfx/level1_lift.chr').read_bytes()])
    assert len(static)==234*16
    frames=[];failures=[]
    for frame_id,(low,high) in enumerate(zip(lo,hi)):
        # set_gfxanim_ptr indexes gfx_ptrs-2 using frame*2; frame0 is
        # explicitly normalized to2. The sprite config itself is zero-based.
        graphics_index=max(frame_id-1,0)
        if graphics_index>=len(refs) or refs[graphics_index] not in gfx:
            failures.append({'frameId':frame_id,'reason':'external graphics block not loaded'});continue
        address=(high<<8)|low
        try:
            hx,hy,attr=read(address,3);cursor=address+3;parts=[]
            for group in range(2 if frame_id in (0x1a,0x1e,0x4c,0x4d) else 1):
                count=bank[cursor];cursor+=1
                incremental=count>=128
                if incremental:
                    count &=127; first=bank[cursor];cursor+=1
                for i in range(count):
                    tile=first+i if incremental else bank[cursor]
                    if not incremental:cursor+=1
                    x,y=read(cursor,2);cursor+=2
                    partattr=bank[cursor] if attr&128 else attr
                    if attr&128:cursor+=1
                    if incremental and first<3:partattr &=252 # P1 palette slot0; source code rewrites low bits.
                    parts.append({'tile':tile,'x':signed(x)-signed(hx),'y':signed(hy)-signed(y),'attributes':partattr})
            pixels={}
            dynamic=gfx[refs[graphics_index]]
            for part in parts:
                tile=part['tile'];a=part['attributes'];pal=palettes[(a&3)*4:(a&3)*4+4]
                source=dynamic[(tile-1)*16:tile*16] if 1<=tile<=16 else static[tile*16:(tile+1)*16]
                if len(source)!=16:raise ValueError('tile bytes unavailable')
                for y in range(8):
                    for x in range(8):
                        ix=7-x if a&64 else x;iy=7-y if a&128 else y
                        code=((source[iy]>>(7-ix))&1)|(((source[iy+8]>>(7-ix))&1)<<1)
                        pos=(part['x']+x,part['y']+y)
                        if code and pos not in pixels:pixels[pos]=rgba(pal[code])
            if not pixels:raise ValueError('no visible pixels')
            minx,miny=min(x for x,y in pixels),min(y for x,y in pixels)
            maxx,maxy=max(x for x,y in pixels),max(y for x,y in pixels)
            width,height=maxx-minx+1,maxy-miny+1
            image=bytearray(width*height*4)
            for (x,y),color in pixels.items():
                pos=((y-miny)*width+x-minx)*4;image[pos:pos+4]=bytes(color)
            png(OUT/'frames'/f'hero-{frame_id:02x}.png',width,height,image)
            frames.append({'frameId':frame_id,'frameHex':f'{frame_id:02X}','graphicsLabel':refs[graphics_index],
                'metaspriteAddress':f'{address:04X}','parts':parts,'visibleBounds':{'minX':minx,'minY':miny,'maxX':maxx,'maxY':maxy},
                'width':width,'height':height,'pixels':image})
        except (KeyError,ValueError) as error:
            failures.append({'frameId':frame_id,'reason':str(error)})
    sheet(frames,OUT/'hero-source-contact-sheet.png')
    selected_ids=[1,2,3,4,5,6,7,8,9,0x17,0x18,0x19,0x1a,0x1d,0x1e,0x21,0x22,0x23,0x24,0x2d,0x2e,0x32,0x33]
    sheet([f for f in frames if f['frameId'] in selected_ids],OUT/'hero-locomotion-and-morph-reference.png',scale=6,columns=5)
    sheet([f for f in frames if f['frameId'] in (0x32,0x33)],OUT/'hero-boss-appearance-reaction.png',scale=10,columns=2)
    # Object gfx frame IDs are a separate namespace from hero frames.
    object_frames=[]
    olo,ohi=numeric_block(text,'obj_sprcfg_ptr_l'),numeric_block(text,'obj_sprcfg_ptr_h')
    selected_objects={2:'Pig move frame A',3:'Pig move frame B',4:'Pig move frame C',
                      5:'Pig strike windup',6:'Pig strike contact',9:'Dragon final normal frame A',
                      0xa:'Dragon final normal frame B or heavy disabled',0xb:'Dragon headbutt or link',
                      0xc:'Dragon light reaction',0x12:'Boss Walker intro foot before arena graphics cut',
                      0x19:'Tall Walker upper body only; articulated legs not included'}
    for fid,meaning in selected_objects.items():
        address=olo[fid]|ohi[fid]<<8
        hx,hy,attr=read(address,3);cursor=address+3;count=bank[cursor];cursor+=1
        incremental=count>=128;parts=[];pixels={}
        if incremental:count&=127;first=bank[cursor];cursor+=1
        for i in range(count):
            tile=first+i if incremental else bank[cursor]
            if not incremental:cursor+=1
            x,y=read(cursor,2);cursor+=2
            a=bank[cursor] if attr&128 else attr
            if attr&128:cursor+=1
            x,y=signed(x)-signed(hx),signed(hy)-signed(y)
            parts.append({'tile':tile,'x':x,'y':y,'attributes':a})
            source=static[tile*16:(tile+1)*16]
            assert len(source)==16,(fid,tile)
            pal=palettes[(a&3)*4:(a&3)*4+4]
            for py in range(8):
                for px in range(8):
                    ix=7-px if a&64 else px;iy=7-py if a&128 else py
                    code=(source[iy]>>(7-ix)&1)|((source[iy+8]>>(7-ix)&1)<<1)
                    if code and (x+px,y+py) not in pixels:pixels[x+px,y+py]=rgba(pal[code])
        minx,miny=min(x for x,y in pixels),min(y for x,y in pixels)
        maxx,maxy=max(x for x,y in pixels),max(y for x,y in pixels)
        width,height=maxx-minx+1,maxy-miny+1;image=bytearray(width*height*4)
        for (x,y),color in pixels.items():
            pos=((y-miny)*width+x-minx)*4;image[pos:pos+4]=bytes(color)
        png(OUT/'frames'/f'object-{fid:02x}.png',width,height,image)
        object_frames.append({'frameId':fid,'meaning':meaning,'metaspriteAddress':f'{address:04X}',
            'width':width,'height':height,'visibleBounds':{'minX':minx,'minY':miny,'maxX':maxx,'maxY':maxy},
            'parts':parts,'pixels':image})
    sheet([f for f in object_frames if f['frameId']!=0x12],OUT/'first-route-object-reference.png',scale=8,columns=4)
    sheet([f for f in object_frames if f['frameId']==0x12],OUT/'boss-intro-foot-source-reference.png',scale=5,columns=1)
    idle=next(f for f in frames if f['frameId']==1)
    rows=[]
    for y in range(idle['height']):
        xs=[x for x in range(idle['width']) if idle['pixels'][(y*idle['width']+x)*4+3]]
        rows.append({'imageY':y,'sourceY':y+idle['visibleBounds']['minY'],
                     'minX':min(xs) if xs else None,'maxX':max(xs) if xs else None,
                     'span':max(xs)-min(xs)+1 if xs else 0})
    proportions={k:v for k,v in idle.items() if k not in ('parts','pixels')}
    proportions.update({'widthHeightRatio':idle['width']/idle['height'],'paletteIndicesP1':palettes[:4],
        'rows':rows,'warning':'Measured silhouette spans; semantic head/torso joint landmarks are not inferred from a 2D alpha mask.'})
    (OUT/'hero-idle-proportions.json').write_text(json.dumps(proportions,indent=2)+'\n',encoding='utf-8')
    output={'schema':1,'pin':PIN,'source':'https://github.com/feos-tas/DisAssemble/tree/'+PIN+'/Battletoads',
        'method':'static source graphics + exact metasprite placement; P1 palette slot0; no emulation',
        'paletteIndices':palettes,'colorLimit':'RGB illustrative; source palette indices are authoritative',
        'frames':[{k:v for k,v in frame.items() if k!='pixels'} for frame in frames], 'unrendered':failures,
        'objectFrames':[{k:v for k,v in frame.items() if k!='pixels'} for frame in object_frames],
        'listingBytesCrosschecked':listing_matches,
        'inputs':{str(p.relative_to(CACHE)).replace('\\','/'):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
                  for p in [main_path,CACHE/'data/spr_lists1.asm',CACHE/'data/spr_lists2.asm',CACHE/'symbols.map',listing,
                    *[CACHE/'gfx'/name for name in ('rash.asm','sprite0.chr','game_std.chr','level1_obj.4','levels1_5_obj.4',
                        'tall_walker.4','stick.4','common.4','byte_BC65.chr','level1_lift.chr')]]}}
    (OUT/'hero-frame-catalog.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'rendered':len(frames),'unrendered':len(failures),'out':str(OUT)}))


if __name__=='__main__':main()
