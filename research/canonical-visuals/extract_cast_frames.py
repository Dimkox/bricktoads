"""Decode pinned cast references from source bank recipes; no ROM or art guesses.

Writes only cast-* outputs beside this file. The existing first-route extractor
is imported for PNG/metasprite helpers and never executed or modified.
"""
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen
import hashlib
import json
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_source_frames import CACHE, OUT, PIN, byte_blocks, main_block, numeric_block, number, signed, png, sheet, rgba as baseline_rgba

SOURCE = 'https://raw.githubusercontent.com/feos-tas/DisAssemble/' + PIN + '/Battletoads/'
BANK1 = ['sprite0.chr', 'game_std.chr', 'level1_obj.4', 'levels1_5_obj.4', 'tall_walker.4',
         'stick.4', 'common.4', 'byte_BC65.chr', 'byte_BDC5.chr', 'byte_BE25.chr', 'byte_BE55.chr',
         'terratubes_obj.4', 'surfcity_obj.4', 'byte_CC32.chr', 'karnathl_obj.4', 'revolution_obj.4',
         'turbotunnel_obj.4', 'ratrace_obj.4', 'level2_obj.4', 'snowman.4', 'level4_obj.4',
         'level4_obj2.4', 'l1_boss2.chr']
EXTRA = ['byte_85AA.1', 'robomanus.4', 'armageddon_spr.4', 'gen_slaughter.4', 'rev_obj.4',
         'clign_wing_obj.4', 'byte_7000_9310.4', 'byte_7000_92A1.4', 'level1_boss.4',
         'zastavki_bkg.4', 'bigtornado.4', 'pimple.4', 'angelika.4', 'toads_intro.4', 'title_screen.4']
# A tuple is (file, tile count, compression). These are literal source loads,
# main.asm 22231-22410; source padding is read from adjacent declared blocks.
PREFIX = [('sprite0.chr', 0x21, 0), ('game_std.chr', 9, 0)]
RECIPES = {
    'Canyon': PREFIX + [('level1_obj.4',0x83,4),('levels1_5_obj.4',0x23,4),('tall_walker.4',10,4),
                        ('stick.4',4,4),('common.4',10,4),('level1_lift.chr',2,0)],
    'Wookie': PREFIX + [('level2_obj.4',0xb4,4),('common.4',15,4)],
    'Tunnel': PREFIX + [('turbotunnel_obj.4',0xc3,4)],
    'Ice': PREFIX + [('snowman.4',0x2d,4),('level4_obj.4',0x5f,4),('level4_obj2.4',0x37,4)],
    'Tower': PREFIX + [('revolution_obj.4',0xa6,4),('tall_walker.4',6,4),('byte_BDC5.chr',4,0),
                       ('stick.4',4,4),('common.4',5,4),('byte_BE25.chr',10,0)],
    'Race': PREFIX + [('ratrace_obj.4',0xa6,4),('tall_walker.4',10,4),('stick.4',4,4),('common.4',15,4)],
    'Snake': PREFIX + [('karnathl_obj.4',0xc3,4)],
    'Tubes': [('sprite0.chr',0x21,0),('game_std.chr',8,0),('byte_85AA.1',1,1),('terratubes_obj.4',0xc3,4)],
    'Surf': [('sprite0.chr',0x21,0),('game_std.chr',8,0),('byte_CC32.chr',1,0),('surfcity_obj.4',0x61,4),
             ('turbotunnel_obj.4',0x22,4),('levels1_5_obj.4',0x23,4),('tall_walker.4',10,4),
             ('stick.4',4,4),('common.4',14,4)],
}
# namespace, source recipe, graphics IDs, source evidence. ID lists are verified
# assignments/table members, not an invented complete state-machine timeline.
CAST = [
 ('Hero','hero','Canyon',[1,2,3,4,5,6,7,8,9,10,0xe,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23,0x26,0x29,0x2d,0x2e,0x30,0x31,0x32,0x33,0x57,0x61],'main.asm:6196-8385'),
 ('Pig','object','Canyon',[2,3,4,5,6,7,8,0x44,0x45,0x46,0x47,0x48,0x49],'main.asm:16638-17143;9620-9652'),
 ('Walker','object','Canyon',[0x19],'main.asm:4608-4818; research/canonical-visuals/TALL_WALKER_SOURCE.md'),
 ('Dragon','object','Canyon',[9,10,11,12],'main.asm:2943-3056;5358-5359'),
 ('HealingFly','object','Canyon',[0xd,0xe],'main.asm:9449-9478; source type0A'),
 ('Raven','object','Wookie',list(range(0x1c,0x24)),'main.asm:4869-4906;4990-5393; anim30'),
 ('LargeRaven','object','Wookie',[0x26,0x27,0x28,0x29],'main.asm:4927-4984;5395'),
 ('Invader','object','Tunnel',[0x24,0x25,0x39,0x3a,0x3d],'main.asm:5472-5725;5394'),
 ('RocketRat','object','Tunnel',[0x55],'main.asm:10088-10124;11501-11577'),
 ('SaturnToadtrap','object','Wookie',[0x5d,0x5e],'main.asm:10191-10386;anims42/44/4C/54/56'),
 ('RetroBlaster','object','Wookie',[0x60,0x61,0x62,0x63,0x80],'main.asm:10789-10893;anim4A'),
 ('Snowman','object','Ice',[0x64,0x6b,0x6c,0x6e],'main.asm:20148-20317;anims58/5C/60/62/64'),
 ('Snake','object','Snake',list(range(0x92,0x9b)),'main.asm:18916-18940;23307-23970'),
 ('SentryDrone','object','Race',[0x9d,0x9e],'main.asm:19012-19040'),
 ('Slug','object','Race',[0x9f,0xa0,0xa1,0xa2],'main.asm:19050-19140'),
 ('GasTurret','object','Race',[0xa5,0xa6,0xa7,0xa8,0xa9,0xaa],'main.asm:19173-19270; A6-AA are emitted gas'),
 ('Hordhead','object','Tower',[0xb6,0xb7,0xb8,0xb9,0xba,0xbb,0xc6],'main.asm:10915-11130;anims6A/6C'),
 ('FlyingHead','object','Tower',[0xbc,0xbd,0xc4],'main.asm:13821-13892;13985-14014'),
 ('Swellcheeks','object','Tower',[0xbc,0xbd],'main.asm:14024-14204'),
 ('Robot','object','Tubes',[0xd6,0xd8],'main.asm:11827-11974'),
 ('Electrofish','object','Tubes',[0xe2,0xe3,0xe4,0xe5],'main.asm:12123-12238'),
 ('Hammerfish','object','Tubes',[0xd7,0xd9,0xda,0xdb,0xdf,0xe1],'main.asm:12243-12340;anims7C/7E highbit caller'),
 ('Shark','object','Tubes',[0xde,0xdf,0xe0,0xe1],'main.asm:12371-12429;anim7C highbit caller'),
 ('Duck','object','Tubes',[0xe7,0xe8,0xe9],'main.asm:12030-12117;anim80 highbit caller'),
 ('BossWalkerIntro','object','Canyon',[0x12],'main.asm:4103-4137'),
 ('BossWalker','object','Guardian',[0x10,0x11,0xc7],'main.asm:4281-4483;arena bank cut34374-34445'),
 ('BigBlag','object','Surf',[0xef,0xf1],'main.asm:13055-13204;anim84 highbit caller'),
 ('GeneralSlaughter','object','General',[0xf2,0xf3,0xf4,0xf5,0xf6],'main.asm:13288;13345-13456;anim86 highbit caller'),
 ('RoboManus','object','Robo',[0xf7,0xf8],'main.asm:13462-13574;anim88 highbit caller'),
 ('Buzzball','heroStatic','Clinger',[0x7c,0x7d,0x7e,0x7f],'main.asm:14783-14803;34116-34126 hero namespace override'),
 ('DarkQueen','heroStatic','Queen',[0x81,0x82,0x83],'main.asm:14307-14515;anim8A highbit;34116-34126'),
 ('RacingRat','object','Race',[0x82,0x83,0x84],'main.asm:18470-18537; dynamic type46'),
]

# Complete illustrative 2C02 display table; preserve the established reference
# colors for its already inspected indices. No unknown palette is painted gray.
NES_RGB = [
 '545454','001e74','081090','300088','440064','5c0030','540400','3c1800','202a00','083a00','004000','003c00','00323c','000000','000000','000000',
 '989698','084cc4','3032ec','5c1ee4','8814b0','a01464','982220','783c00','545a00','287200','087c00','007628','006678','000000','000000','000000',
 'eceeec','4c9aec','787cec','b062ec','e454ec','ec58b4','ec6a64','d48820','a0aa00','74c400','4cd020','38cc6c','38b4cc','3c3c3c','000000','000000',
 'eceeec','a8ccec','bcbcec','d4b2ec','ecaee4','ecaed4','ecb4b0','e4c490','ccd278','b4de78','a8e290','98e2b4','a0d6e4','a0a2a0','000000','000000']
KNOWN_RGB={0x0f,0x0a,0x1a,0x17,0x27,0x18,0x28,0x20,0x16,0x26}
def rgba(index):
    assert 0<=index<64,('Unknown source palette code',index)
    return baseline_rgba(index) if index in KNOWN_RGB else tuple(bytes.fromhex(NES_RGB[index]))+(255,)


def authored_palette_contexts(base):
    levels={};events={};active=None
    for filename in ('levels_cfgs1.asm','levels_cfgs2.asm'):
        for line_no,line in enumerate((CACHE/filename).read_text(errors='replace').splitlines(),1):
            found=re.match(r'^(level\d+_cfg):',line)
            if found:active=int(re.search(r'\d+',found[1])[0]);levels[active]=[]
            if active and '.BYTE' in line:
                values=[number(v) for v in line.split('.BYTE')[1].split(';')[0].split(',') if v.strip()]
                if len(values)==11:levels[active].append({'bytes':values,'file':filename,'line':line_no})
    snapshots={}
    for level,rows in levels.items():
        palette=list(base);snapshots[level]=[];events[level]=[];group=[]
        def consume(group):
            # A palette object and actor with the same trigger are both loaded
            # for that authored trigger. Snapshot after that finite load group.
            for row in group:
                r=row['bytes']
                if r[0]==0x19:
                    event={'source':row['file']+':'+str(row['line']),'trigger':r[1:3],
                           'paletteRamOffset':r[7],'colorCodes':r[3:6],'delayCounter':r[8],
                           'sourceHandler':'main.asm:9213-9306'}
                    events[level].append(event)
                    if 16<=r[7]<=28 and r[8]==0:
                        offset=r[7]-16
                        palette[offset+1:offset+4]=r[3:6]
            for row in group:
                r=row['bytes']
                if r[0]!=0x19:snapshots[level].append({'typeId':r[0],'actorPaletteXor':r[10]&3,
                    'source':row['file']+':'+str(row['line']),'trigger':r[1:3],
                    'paletteIndices':list(palette),'paletteWrites':list(events[level])})
        for row in rows:
            if group and row['bytes'][1:3]!=group[-1]['bytes'][1:3]:consume(group);group=[]
            group.append(row)
        if group:consume(group)
    return snapshots,events


ALIASES={'Pig':'PsykoPig','Walker':'TallWalker','Slug':'Slime','BossWalkerIntro':'BossWalker'}
LEVELS={'Canyon':1,'Wookie':2,'Tunnel':3,'Ice':4,'Tower':5,'Race':7,'Snake':8,'Tubes':11,
        'Surf':12,'Guardian':1,'General':9,'Robo':7,'Clinger':10,'Queen':13}


def fetch():
    for filename in sorted(set(BANK1+EXTRA+['level1_lift.chr'])):
        path=CACHE/'gfx'/filename
        if not path.exists():
            path.parent.mkdir(parents=True,exist_ok=True)
            with urlopen(SOURCE+quote('gfx/'+filename,safe='/'),timeout=45) as response:
                path.write_bytes(response.read())


def stream(filename):
    if filename in BANK1:
        # These immediately follow l1_boss2 in the pinned bank1 source:
        # FF65 RTI ($40), then FF66..FF77 .PAD $FF78,$FF. No invented padding.
        return b''.join((CACHE/'gfx'/f).read_bytes() for f in BANK1[BANK1.index(filename):])+b'\x40'+b'\xff'*18
    if filename=='level1_boss.4':
        return (CACHE/'gfx'/filename).read_bytes()+(CACHE/'gfx/zastavki_bkg.4').read_bytes()
    following={'armageddon_spr.4':'robomanus.4','bigtornado.4':'toads_intro.4',
               'clign_wing_obj.4':'title_screen.4','byte_7000_92A1.4':'byte_7000_9310.4'}
    if filename in following:
        return (CACHE/'gfx'/filename).read_bytes()+(CACHE/'gfx'/following[filename]).read_bytes()
    return (CACHE/'gfx'/filename).read_bytes()


def unpack(filename,count,compression):
    data=stream(filename);size=count*16
    if compression==0:
        assert len(data)>=size,(filename,'raw source boundary unavailable')
        return data[:size]
    if compression==1:
        # main21972-21975 type1 selects write_8unpacked_and_8zeros.
        assert len(data)>=8
        return (data[:8]+bytes(8))*count
    assert compression==4
    zero,ones=data[:2];cursor=2;out=bytearray()
    while len(out)<size:
        if cursor>=len(data):break
        value=data[cursor];cursor+=1
        if value in (zero,ones):
            if cursor>=len(data):break
            run=data[cursor] or 256;cursor+=1
            out.extend(bytes([0 if value==zero else 255])*run)
        else:out.append(value)
    return bytes(out[:size])


def tile_bank(name):
    patches=[]
    base={'Guardian':'Canyon','Robo':'Race','General':'Race','Clinger':'Race','Queen':'Race'}.get(name,name)
    data=bytearray(4096);valid=set();cursor=0
    for filename,count,compression in RECIPES[base]:
        part=unpack(filename,count,compression);data[cursor:cursor+len(part)]=part
        valid.update(range(cursor//16,cursor//16+len(part)//16))
        patches.append({'file':'gfx/'+filename,'firstTile':cursor//16,'tiles':count,'decodedCompleteTiles':len(part)//16,
                        'unknownTailBytes':max(0,count*16-len(part)),'compression':compression})
        cursor+=count*16
    overrides={
        'Guardian':[(0x2a,'level1_boss.4',0x40,4),(0x57,'level4_obj.4',0x11,4),(0x68,'l1_boss2.chr',11,0),(0xb6,'level4_obj2.4',8,4)],
        'Robo':[(0x2a,'robomanus.4',0x44,4)],
        'General':[(0x69,'gen_slaughter.4',0x15,4),(0xc0,'rev_obj.4',0x26,4),(0x4c,'byte_7000_92A1.4',0xc,4)],
        'Clinger':[(0x2a,'clign_wing_obj.4',0x40,4)],
        'Queen':[(0x30,'armageddon_spr.4',0x36,4),(0x5e,'bigtornado.4',0x12,4),(0x70,'pimple.4',0x15,4),
                 (0xd8,'angelika.4',0xf,4),(0xc0,'byte_7000_9310.4',0x13,4)],
    }
    for start,filename,count,compression in overrides.get(name,[]):
        part=unpack(filename,count,compression);data[start*16:start*16+len(part)]=part
        valid.difference_update(range(start,start+count))
        valid.update(range(start,start+len(part)//16));patches.append({'file':'gfx/'+filename,'firstTile':start,'tiles':count,
                        'decodedCompleteTiles':len(part)//16,'unknownTailBytes':max(0,count*16-len(part)),
                        'compression':compression,'override':True})
    # Always loaded by level_values_load (main38574-38576), independent of stage.
    part=unpack('byte_BC65.chr',0x16,0);data[0xea0:0x1000]=part;valid.update(range(0xea,0x100))
    patches.append({'file':'gfx/byte_BC65.chr','firstTile':0xea,'tiles':0x16,'compression':0,'override':True})
    return bytes(data),valid,patches


def sprite_memory():
    bank={}
    for filename,base in [('spr_lists1.asm',0xae89),('spr_lists2.asm',0xc838)]:
        data,_,_=byte_blocks(CACHE/'data'/filename);bank.update({base+i:v for i,v in enumerate(data)})
    last=None;cursor=0
    for line in (CACHE/'source.lst').read_text(errors='replace').splitlines():
        m=re.match(r'BANK6:([0-9A-F]{4})\s+(.*)',line)
        if not m or '.BYTE' not in m[2]:continue
        address=int(m[1],16)
        try:values=[number(t)&255 for t in m[2].split('.BYTE')[1].split(';')[0].split(',') if t.strip()]
        except ValueError:last=None;continue
        if address!=last:cursor=address
        for v in values:
            assert cursor not in bank or bank[cursor]==v,('metasprite disagreement',hex(cursor))
            bank[cursor]=v;cursor+=1
        last=address
    return bank


def decode(fid,namespace,text,bank,tiles,valid,gfx,refs,palette,actor_flags=0):
    prefix='rash' if namespace in ('hero','heroStatic') else 'obj'
    lo,hi=numeric_block(text,prefix+'_sprcfg_ptr_l'),numeric_block(text,prefix+'_sprcfg_ptr_h')
    address=lo[fid]|hi[fid]<<8;hx,hy,attr=[bank[address+i] for i in range(3)]
    cursor=address+3;parts=[];pixels={}
    dynamic=gfx.get(refs[max(fid-1,0)]) if namespace=='hero' and max(fid-1,0)<len(refs) else None
    if namespace=='hero' and dynamic is None:raise ValueError('external hero graphics block unavailable')
    for group in range(2 if namespace=='hero' and fid in (0x1a,0x1e,0x4c,0x4d) else 1):
        count=bank[cursor];cursor+=1;incremental=count>=128
        if incremental:count&=127;first=bank[cursor];cursor+=1
        for i in range(count):
            tile=first+i if incremental else bank[cursor]
            if not incremental:cursor+=1
            x,y=bank[cursor],bank[cursor+1];cursor+=2
            a=bank[cursor] if attr&128 else attr
            if attr&128:cursor+=1
            a^=actor_flags&3 # source actor flag low bits XOR metasprite attributes.
            if namespace=='hero' and incremental and first<3:a&=252
            x,y=signed(x)-signed(hx),signed(hy)-signed(y)
            parts.append({'tile':tile,'x':x,'y':y,'attributes':a,'paletteSlot':a&3})
            if namespace=='hero' and 1<=tile<=16:source=dynamic[(tile-1)*16:tile*16]
            else:
                if tile not in valid:raise ValueError('unloaded tile '+hex(tile))
                source=tiles[tile*16:(tile+1)*16]
            if len(source)!=16:raise ValueError('tile bytes unavailable')
            pal=palette[(a&3)*4:(a&3)*4+4]
            for py in range(8):
                for px in range(8):
                    ix=7-px if a&64 else px;iy=7-py if a&128 else py
                    code=(source[iy]>>(7-ix)&1)|((source[iy+8]>>(7-ix)&1)<<1)
                    if code and (x+px,y+py) not in pixels:pixels[x+px,y+py]=rgba(pal[code])
    if not pixels:raise ValueError('no visible pixels')
    minx,miny=min(x for x,y in pixels),min(y for x,y in pixels)
    maxx,maxy=max(x for x,y in pixels),max(y for x,y in pixels)
    width,height=maxx-minx+1,maxy-miny+1;image=bytearray(width*height*4)
    for (x,y),color in pixels.items():
        pos=((y-miny)*width+x-minx)*4;image[pos:pos+4]=bytes(color)
    return {'frameId':fid,'frameHex':f'{fid:02X}','namespace':namespace,'metaspriteAddress':f'{address:04X}',
            'parts':parts,'visibleBounds':{'minX':minx,'minY':miny,'maxX':maxx,'maxY':maxy},
            'width':width,'height':height,'pixels':image}


def main():
    fetch();text=(CACHE/'main.asm').read_text(errors='replace');bank=sprite_memory()
    _,_,gfx=byte_blocks(CACHE/'gfx/rash.asm')
    refs=re.findall(r'\.WORD\s+(\w+)',main_block(text,'gfx_ptrs'))
    palette=numeric_block(text,'palette_chars')[:16]
    contexts,palette_events=authored_palette_contexts(palette)
    source_catalog=json.loads((OUT.parent/'2026-11-09-canonical-character-animation-catalog.json').read_text())
    source_families={f['name']:f for f in source_catalog['families']}
    baseline=json.loads((OUT/'hero-frame-catalog.json').read_text())
    checked=[];families=[];all_frames=[]
    (OUT/'cast-frames').mkdir(exist_ok=True)
    (OUT/'cast-contact-sheets').mkdir(exist_ok=True)
    for family,namespace,recipe,ids,evidence in CAST:
        tiles,valid,patches=tile_bank(recipe)
        source_family=ALIASES.get(family,family)
        types=source_families.get(source_family,{}).get('types',{'HealingFly':[0xa],'RacingRat':[0x46]}.get(family,[]))
        if family=='BossWalkerIntro':types=[0xd]
        level=9 if family=='RacingRat' else LEVELS[recipe]
        candidates=[c for c in contexts[level] if c['typeId'] in types]
        if family=='Hero':candidates=[] # P1 frame checks intentionally use slot0.
        if family=='RacingRat':
            candidates=[{'typeId':0x46,'actorPaletteXor':0,'paletteIndices':contexts[9][0]['paletteIndices'],
                         'paletteWrites':palette_events[9],'source':'main.asm:18493-18495; cfg9 initial type19','trigger':[0,0]}]
            # Race palette setter is in the first authored trigger group.
            for e in palette_events[9]:
                if e['paletteRamOffset']==0x1c:
                    candidates[0]['paletteIndices'][13:16]=e['colorCodes'];break
        selected=candidates[0] if candidates else {'actorPaletteXor':0,'paletteIndices':palette,'source':'initial palette_chars'}
        pal=numeric_block(text,'byte_6000_A2FD')[:16] if recipe=='Guardian' else selected['paletteIndices']
        actor_flags=selected['actorPaletteXor']
        frames=[];unknown=[]
        for fid in ids:
            try:
                frame=decode(fid,namespace,text,bank,tiles,valid,gfx,refs,pal,actor_flags)
                if (family=='Hero' and fid in (1,5,0x19,0x1a,0x1e,0x32,0x33)) or (family=='Pig' and 2<=fid<=6) or family=='Dragon':
                    check=decode(fid,namespace,text,bank,tiles,valid,gfx,refs,palette)
                    old=next(f for f in baseline['frames' if family=='Hero' else 'objectFrames'] if f['frameId']==fid)
                    assert check['visibleBounds']==old['visibleBounds'],(family,fid,'bounds mismatch')
                    comparable=[{k:v for k,v in p.items() if k!='paletteSlot'} for p in check['parts']]
                    assert comparable==old['parts'],(family,fid,'component mismatch')
                    reference=(OUT/'frames'/f"{'hero' if family=='Hero' else 'object'}-{fid:02x}.png").read_bytes()
                    # PNG serialization is the same helper, allowing byte equality.
                    target=OUT/'cast-frames'/f'{family.lower()}-{fid:02x}.png'
                    png(target,check['width'],check['height'],check['pixels'])
                    assert target.read_bytes()==reference,(family,fid,'pixel mismatch')
                    checked.append({'family':family,'frameId':fid,'bounds':True,'pixels':True})
                filename=f'cast-frames/{family.lower()}-{fid:02x}.png';png(OUT/filename,frame['width'],frame['height'],frame['pixels'])
                frame['referencePng']=filename;frames.append(frame);all_frames.append(frame)
            except (ValueError,KeyError,IndexError) as error:
                unknown.append({'frameId':fid,'reason':str(error)})
        if family=='Walker':unknown.append({'state':'full articulated body','reason':'gfx19 is upper body only; reuse separate verified procedural leg catalog'})
        if family=='Snake':unknown.append({'state':'complete body','reason':'body is bank2 procedural nametable path; decoded sprite head/turn frames do not include full snake body'})
        name=f'cast-contact-sheets/{family.lower()}.png'
        if frames:sheet(frames,OUT/name,scale=6,columns=min(6,len(frames)))
        variants=[];seen=set()
        for candidate in candidates:
            key=(tuple(candidate['paletteIndices']),candidate['actorPaletteXor'])
            if key in seen:continue
            seen.add(key);variant_frames=[];n=len(variants)
            for fid in ids:
                try:variant_frames.append(decode(fid,namespace,text,bank,tiles,valid,gfx,refs,candidate['paletteIndices'],candidate['actorPaletteXor']))
                except (ValueError,KeyError,IndexError):pass
            variant_name=f'cast-contact-sheets/{family.lower()}-palette-{n}.png'
            if variant_frames:sheet(variant_frames,OUT/variant_name,scale=5,columns=min(6,len(variant_frames)))
            variants.append({**candidate,'contactSheet':variant_name if variant_frames else None})
        families.append({'family':family,'runtimeTemplates':['Mr. Green','Mr. Yellow','Mr. Brown'] if family=='Hero' else [family],
                         'sourceFamily':source_family,'sourceTypes':[f'{t:02X}' for t in types],
                         'namespace':namespace,'bankRecipe':recipe,'bankLoads':patches,'sourceEvidence':evidence,
                         'paletteIndices':pal,'actorPaletteXor':actor_flags,'selectedPaletteContext':selected,
                         'initialToEffectivePaletteMap':[
                             {'sourceSlot':slot,'pixelCode':code,'initialNesCode':palette[slot*4+code],
                              'initialRgb':list(rgba(palette[slot*4+code])[:3]),'effectiveSlot':slot^actor_flags,
                              'effectiveNesCode':pal[(slot^actor_flags)*4+code],
                              'effectiveRgb':list(rgba(pal[(slot^actor_flags)*4+code])[:3])}
                             for slot in range(4) for code in range(1,4)],
                         'paletteVariants':variants,'paletteScope':'authored source actor flags XOR sprite attributes; palette RAM after same-trigger type19 writes',
                         'frames':[{k:v for k,v in f.items() if k!='pixels'} for f in frames],
                         'contactSheet':name if frames else None,'unknown':unknown,
                         'stateTrace':'verified frame assignments; complete timeline and 3D depth remain separate'})
        print(f'{family}: {len(frames)} decoded, {len(unknown)} unknown',flush=True)
    assert len(checked)==16,checked
    sheet(all_frames,OUT/'cast-source-contact-sheet.png',scale=3,columns=12)
    inputs=[CACHE/'main.asm',CACHE/'source.lst',CACHE/'levels_cfgs1.asm',CACHE/'levels_cfgs2.asm',
            CACHE/'data/spr_lists1.asm',CACHE/'data/spr_lists2.asm',CACHE/'gfx/rash.asm',
            *[CACHE/'gfx'/f for f in sorted(set(BANK1+EXTRA+['level1_lift.chr']))]]
    catalog={'schema':1,'pin':PIN,'source':SOURCE,'method':'static pinned source CHR loads + exact sprite configurations; no ROM or emulator',
             'crossChecks':checked,'families':families,'levelPaletteWrites':palette_events,
             'paletteWarning':'Source codes and actor XOR are authoritative. RGB illustrative. Static authored trigger snapshots; Surf/Clinger changing-palette loops and exact interpreter scheduling remain separate.',
             'unknown':['Complete source state timelines','Repeated Surf/Clinger palette loops','Unseen 3D depth/back sides','Snake full nametable body','Tall Walker legs included only in separate existing catalog'],
             'inputs':{str(p.relative_to(CACHE)).replace('\\','/'):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in inputs}}
    (OUT/'cast-source-catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
    print(json.dumps({'families':len(families),'frames':len(all_frames),'crossChecks':len(checked),'sheet':str(OUT/'cast-source-contact-sheet.png')}))


if __name__=='__main__':main()
