"""Source-exact prepared Tall Walker poses, including its procedural sprite legs.

The selected snapshots set a screen-safe body/ground anchor and real source leg
counters. They are static renderer evaluations, not an emulated gameplay trace.
"""
from pathlib import Path
import json
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from extract_source_frames import CACHE,OUT,number,png,rgba,sheet,unpack4,signed,numeric_block


def adc(a,b,carry):
    value=a+b+carry
    return value&255,int(value>255)


def sbc(a,b,carry):
    value=a-b-(1-carry)
    return value&255,int(value>=0)


def lsr(a):return a>>1,a&1
def ror(a,carry):return (a>>1)|(carry<<7),a&1
def rol(a,carry):return ((a<<1)|carry)&255,a>>7


def leg(delta,kind,screen_x,start_y):
    """Main ASM 33567–33639: fixed-point slope, tile lookup, screen-safe case."""
    a=delta&255;fraction=0;count=4
    if kind<0x12:
        count*=2;a,carry=lsr(a);fraction,carry=ror(fraction,carry)
    a,carry=lsr(a);fraction,carry=ror(fraction,carry)
    a,carry=lsr(a);fraction,carry=ror(fraction,carry)
    _,sign=rol(delta&255,carry)
    if sign:a|=0xe0
    step=a
    carry=int(a>=0x10)
    if carry:a,carry=adc(a^255,0,carry)
    slope_index=a
    tiles=[0xd0,0xd0,0xd1,0xd2]+[0xd4]*11
    assert 0<=slope_index<len(tiles),(delta,kind,slope_index)
    attrs=(step&0x40)^0x42
    x=(screen_x-3)&255;fx=0;y=start_y&255;parts=[]
    for i in range(count):
        fx,carry=adc(fx,fraction,0)
        part={'tile':tiles[slope_index],'x':x,'y':y,'attributes':attrs}
        parts.append(part)
        x,carry=adc(x,step,carry)
        rotated,carry=ror(x,carry)
        assert ((rotated^step)&128)==0,'Prepared pose must remain onscreen'
        y,carry=adc(y,8,0)
    parts[-1]['tile']=0xd3
    return parts,{'delta':delta,'segments':count,'integerStep':signed(step),'fractionByte':fraction,
                  'slopeIndex':slope_index,'attributes':attrs,'firstTile':tiles[slope_index],
                  'lastTile':0xd3,'theoreticalEndX':screen_x-3+delta}


def render(profile,body_parts,static,palettes):
    """Evaluate tall_walker_sprites for Z=0, no death flash, facing right."""
    screen_x,ground_y,original_z=128,200,0
    kind=profile['objectType']
    bias=0xc8 if kind<0x12 else 0xe8
    y,carry=adc(bias,ground_y,0)
    y,carry=sbc(y,original_z,1)
    assert carry,'Prepared body must be above the source clipping boundary'
    first,first_meta=leg(profile['footDeltas'][0],kind,screen_x,y)
    y,carry=sbc(y,2,1)
    second,second_meta=leg(profile['footDeltas'][1],kind,screen_x,y)
    # Restore the source shadow and derive its temporary visual Z for the head.
    shadow,carry=adc(y,original_z,0)
    shadow,carry=sbc(shadow,3,carry)
    shadow,carry=sbc(shadow,bias,carry)
    z,carry=sbc(original_z,second_meta['slopeIndex'],1)
    z,carry=sbc(z,4,1)
    z,carry=sbc(z,bias,carry)
    head_y,carry=sbc(shadow,z,1)
    assert carry
    head=[{**p,'x':p['x']+screen_x,'y':p['y']+head_y} for p in body_parts]
    parts=[*first,*second,*head]
    pixels={}
    for part in parts:
        tile=part['tile'];a=part['attributes'];source=static[tile*16:(tile+1)*16]
        assert len(source)==16
        palette=palettes[(a&3)*4:(a&3)*4+4]
        for py in range(8):
            for px in range(8):
                ix=7-px if a&64 else px;iy=7-py if a&128 else py
                code=(source[iy]>>(7-ix)&1)|((source[iy+8]>>(7-ix)&1)<<1)
                at=(part['x']+px,part['y']+py)
                if code and at not in pixels:pixels[at]=rgba(palette[code])
    minx,miny=min(x for x,y in pixels),min(y for x,y in pixels)
    maxx,maxy=max(x for x,y in pixels),max(y for x,y in pixels)
    width,height=maxx-minx+1,maxy-miny+1;image=bytearray(width*height*4)
    for (x,y),color in pixels.items():
        index=((y-miny)*width+x-minx)*4;image[index:index+4]=bytes(color)
    relative=[{**p,'x':p['x']-screen_x,'y':p['y']-ground_y} for p in parts]
    return {**profile,'width':width,'height':height,'pixels':image,'parts':relative,
            'visibleBounds':{'minX':minx-screen_x,'minY':miny-ground_y,'maxX':maxx-screen_x,'maxY':maxy-ground_y},
            'headAnchor':{'x':0,'y':head_y-ground_y},
            'legStarts':[{'x':p[0]['x']-screen_x,'y':p[0]['y']-ground_y}for p in (first,second)],
            'sourceLegs':[first_meta,second_meta]}


def main():
    text=(CACHE/'main.asm').read_text(encoding='utf-8',errors='replace')
    palette=numeric_block(text,'palette_chars')[:16]
    prefix=b''.join((CACHE/'gfx'/n).read_bytes()for n in ('sprite0.chr','game_std.chr','level1_obj.4'))
    static=b''.join([prefix[:33*16],(CACHE/'gfx/game_std.chr').read_bytes(),
        unpack4(CACHE/'gfx/level1_obj.4',131),unpack4(CACHE/'gfx/levels1_5_obj.4',35),
        unpack4(CACHE/'gfx/tall_walker.4',10)])
    base_catalog=json.loads((OUT/'hero-frame-catalog.json').read_text())
    body=next(f for f in base_catalog['objectFrames']if f['frameId']==0x19)['parts']
    profiles=[]
    for kind,extent in [(0x11,24),(0x12,16)]:
        for delta in [0,extent,-extent]:
            profiles.append({'objectType':kind,'mode':'prepared gait counters','counter':delta,
                             'footDeltas':[delta,-delta],'bodyGraphicsFrame':0x19})
    source_catalog=json.loads((OUT.parent/'2026-11-09-canonical-character-animation-catalog.json').read_text())
    for animation in (0x3a,0x3c):
        clip=next(a for a in source_catalog['animations']if a['animationId']==animation)
        seen=set()
        for run in clip['frameRuns']:
            delta=signed((run['frameId']-0x18)&255)
            if delta in seen:continue
            seen.add(delta)
            profiles.append({'objectType':0x11,'mode':'prepared source attack stream','sourceAnimation':animation,
                'sourceAdvance':run['startAdvance'],'sourceStreamValue':run['frameId'],
                'bodyGraphicsFrame':0x19,'footDeltas':[delta,(-delta)//2 if animation==0x3a else 0]})
    frames=[]
    for index,profile in enumerate(profiles):
        frame=render({'frameId':index,**profile},body,static,palette)
        png(OUT/'walker-frames'/f'walker-pose-{index:02x}.png',frame['width'],frame['height'],frame['pixels'])
        frames.append(frame)
    sheet(frames[:6],OUT/'tall-walker-procedural-leg-reference.png',scale=5,columns=6)
    sheet([f for f in frames if f.get('sourceAnimation')==0x3a],OUT/'tall-walker-heavy-attack-reference.png',scale=4,columns=8)
    sheet([f for f in frames if f.get('sourceAnimation')==0x3c],OUT/'tall-walker-light-attack-reference.png',scale=4,columns=8)
    output={'schema':1,'sourcePin':'f1a43b69577246850d136473700a333b3cdfe93f',
        'method':'Prepared source renderer snapshots with explicit counters; no emulation or Roblox acceptance',
        'caption':'Hex contact-sheet captions are pose indices into this catalog, not graphics frame IDs',
        'sourceLines':{'logic':[4608,4839],'renderer':[33499,33639]},
        'sourceTiles':{'body':list(range(0xc9,0xd0)),'legShaft':[0xd0,0xd1,0xd2,0xd4],'terminalFoot':0xd3},
        'frames':[{k:v for k,v in f.items()if k!='pixels'}for f in frames]}
    (OUT/'tall-walker-procedural-leg-catalog.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'poses':len(frames),'gaitBounds':[(f['objectType'],f['footDeltas'],f['width'],f['height'])for f in frames[:6]]}))


if __name__=='__main__':main()
