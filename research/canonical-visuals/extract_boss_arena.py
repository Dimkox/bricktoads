"""Decode Boss Walker arena sprite components after its real source bank swaps.

Does not invent the unseen whole robot or claim an emulated final scene.
"""
from pathlib import Path
import hashlib,json,re,sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from extract_source_frames import CACHE,OUT,number,png,rgba,sheet,unpack4,signed,numeric_block,byte_blocks


def prefix4(path,tiles,following=None):
    packed=path.read_bytes()+(following.read_bytes()if following else b'')
    zero,ones=packed[:2];cursor=2;output=bytearray()
    while len(output)<tiles*16:
        value=packed[cursor];cursor+=1
        if value in (zero,ones):
            count=packed[cursor] or 256;cursor+=1
            output.extend(bytes([0 if value==zero else 255])*count)
        else:output.append(value)
    return bytes(output[:tiles*16])


def main():
    text=(CACHE/'main.asm').read_text(encoding='utf-8',errors='replace')
    bank={}
    for filename,base in [('spr_lists1.asm',0xae89),('spr_lists2.asm',0xc838)]:
        data,_,_=byte_blocks(CACHE/'data'/filename);bank.update({base+i:v for i,v in enumerate(data)})
    last=None;cursor=0
    for line in (CACHE/'source.lst').read_text(encoding='utf-8',errors='replace').splitlines():
        match=re.match(r'BANK6:([0-9A-F]{4})\s+(.*)',line)
        if not match or '.BYTE'not in match[2]:continue
        address=int(match[1],16)
        try:values=[number(t)&255 for t in match[2].split('.BYTE')[1].split(';')[0].split(',')if t.strip()]
        except ValueError:last=None;continue
        if address!=last:cursor=address
        for value in values:bank[cursor]=value;cursor+=1
        last=address
    raw_prefix=b''.join((CACHE/'gfx'/p).read_bytes()for p in ('sprite0.chr','game_std.chr','level1_obj.4'))
    static=bytearray(b''.join([raw_prefix[:0x21*16],(CACHE/'gfx/game_std.chr').read_bytes(),
        unpack4(CACHE/'gfx/level1_obj.4',0x83),unpack4(CACHE/'gfx/levels1_5_obj.4',0x23),
        unpack4(CACHE/'gfx/tall_walker.4',0xa),unpack4(CACHE/'gfx/stick.4',4),
        unpack4(CACHE/'gfx/common.4',0xa,CACHE/'gfx/byte_BC65.chr'),(CACHE/'gfx/level1_lift.chr').read_bytes()]))
    # The E0 intro branch calls bank4 set0C, then bank1 sets36 and38.
    patches=[(0x2a,prefix4(CACHE/'gfx/level1_boss.4',0x40,CACHE/'gfx/zastavki_bkg.4'),'level1_boss_set'),
             (0x57,prefix4(CACHE/'gfx/level4_obj.4',0x11),'l1_boss_gfx_set1 part1'),
             (0x68,(CACHE/'gfx/l1_boss2.chr').read_bytes()[:0xb*16],'l1_boss_gfx_set1 part2'),
             (0xb6,prefix4(CACHE/'gfx/level4_obj2.4',8),'l1_boss_gfx_set2')]
    for start,data,_ in patches:static[start*16:start*16+len(data)]=data
    # flag_boss_1 is1 here, so load_palettes_2_22_or_4_6 chooses spr offset6:
    # palettes_ptrs+6 -> byte_6000_A2FD, not the normal palette_chars table.
    palette=numeric_block(text,'byte_6000_A2FD')[:16]
    olo,ohi=numeric_block(text,'obj_sprcfg_ptr_l'),numeric_block(text,'obj_sprcfg_ptr_h')
    frames=[]
    for fid,meaning in [(0x10,'Boss Walker turret'),(0x11,'Boss Walker arena overlay'),(0xc7,'Damaged glass sprite')]:
        address=olo[fid]|ohi[fid]<<8
        hx,hy,attr=[bank[address+i]for i in range(3)];cursor=address+3;count=bank[cursor];cursor+=1
        incremental=count>=128;parts=[];pixels={}
        if incremental:count&=127;first=bank[cursor];cursor+=1
        for i in range(count):
            tile=first+i if incremental else bank[cursor]
            if not incremental:cursor+=1
            x,y=bank[cursor],bank[cursor+1];cursor+=2
            a=bank[cursor]if attr&128 else attr
            if attr&128:cursor+=1
            x,y=signed(x)-signed(hx),signed(hy)-signed(y)
            parts.append({'tile':tile,'x':x,'y':y,'attributes':a})
            source=static[tile*16:(tile+1)*16]
            assert len(source)==16,(fid,tile)
            pal=palette[(a&3)*4:(a&3)*4+4]
            for py in range(8):
                for px in range(8):
                    ix=7-px if a&64 else px;iy=7-py if a&128 else py
                    code=(source[iy]>>(7-ix)&1)|((source[iy+8]>>(7-ix)&1)<<1)
                    if code and (x+px,y+py)not in pixels:pixels[x+px,y+py]=rgba(pal[code])
        minx,miny=min(x for x,y in pixels),min(y for x,y in pixels)
        maxx,maxy=max(x for x,y in pixels),max(y for x,y in pixels)
        width,height=maxx-minx+1,maxy-miny+1;image=bytearray(width*height*4)
        for (x,y),color in pixels.items():
            pos=((y-miny)*width+x-minx)*4;image[pos:pos+4]=bytes(color)
        png(OUT/'boss-arena-frames'/f'boss-arena-{fid:02x}.png',width,height,image)
        frames.append({'frameId':fid,'meaning':meaning,'metaspriteAddress':f'{address:04X}',
            'width':width,'height':height,'visibleBounds':{'minX':minx,'minY':miny,'maxX':maxx,'maxY':maxy},
            'parts':parts,'pixels':image})
    sheet(frames,OUT/'boss-walker-arena-component-reference.png',scale=5,columns=3)
    output={'schema':1,'sourcePin':'f1a43b69577246850d136473700a333b3cdfe93f',
            'method':'Static source sprite components with exact post-intro tile-bank and palette swaps; no full-scene/emulator claim',
            'paletteIndices':palette,'bankPatches':[{'firstTile':start,'tiles':len(data)//16,'sourceSet':name}for start,data,name in patches],
            'frames':[{k:v for k,v in f.items()if k!='pixels'}for f in frames],
            'inputs':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in [CACHE/'gfx/level1_boss.4',CACHE/'gfx/level4_obj.4',CACHE/'gfx/l1_boss2.chr',CACHE/'gfx/level4_obj2.4']},
            'unknown':['Complete final arena nametable/background composition','Unseen whole-robot geometry and rear view','Exact complete runtime projection/layout before a source emulation trace']}
    (OUT/'boss-walker-arena-component-catalog.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'frames':[(f['frameId'],f['width'],f['height'])for f in frames],'patches':output['bankPatches']}))


if __name__=='__main__':main()
