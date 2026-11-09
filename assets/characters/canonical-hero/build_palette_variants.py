"""Create source-indexed P1/P2 colour-only variants without changing base GLB.

The exact illustrative RGB table is imported from the source frame extractor.
Original source palette codes remain authoritative; this is not a CRT claim.
"""
from __future__ import annotations

import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
BASE_PATH=HERE/'canonical-hero.glb'
EXPECTED_BASE='305453efba3302e3935183e4f3e2b28e2c72e7e6b7ff93beb4f9869d191af39c'
EXTRACTOR=ROOT/'research/canonical-visuals/extract_source_frames.py'
SOURCE_CATALOG=ROOT/'research/canonical-visuals/hero-frame-catalog.json'


def sha(data):return hashlib.sha256(data).hexdigest()


def load_rgba():
    source=EXTRACTOR.read_text(encoding='utf-8')
    tree=ast.parse(source)
    function=next(node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name=='rgba')
    module=ast.Module(body=[function],type_ignores=[])
    namespace={}
    exec(compile(module,str(EXTRACTOR),'exec'),namespace)
    return namespace['rgba']


def read_glb(data):
    magic,version,total=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and total==len(data)
    json_length,json_type=struct.unpack_from('<I4s',data,12)
    assert json_type==b'JSON'
    scene=json.loads(data[20:20+json_length])
    binary_length,binary_type=struct.unpack_from('<I4s',data,20+json_length)
    assert binary_type==b'BIN\0'
    binary_start=28+json_length
    assert binary_start+binary_length==len(data)
    return scene,binary_start


def color_ranges(scene,start):
    result=[]
    for mesh in scene['meshes']:
        assert len(mesh['primitives'])==1
        accessor=scene['accessors'][mesh['primitives'][0]['attributes']['COLOR_0']]
        assert accessor['type']=='VEC4' and accessor['componentType']==5126
        view=scene['bufferViews'][accessor['bufferView']]
        assert view.get('byteStride',16)==16
        offset=start+view.get('byteOffset',0)+accessor.get('byteOffset',0)
        result.append((mesh['name'],offset,accessor['count']))
    return result


def neutral_color_hash(data,ranges):
    normalized=bytearray(data)
    for _,offset,count in ranges:normalized[offset:offset+count*16]=bytes(count*16)
    return sha(normalized)


def load_authoring():
    spec=importlib.util.spec_from_file_location('canonical_hero_authoring',HERE/'build_canonical_hero.py')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def linear(rgb):
    def channel(byte):
        value=byte/255
        return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
    return tuple(channel(v) for v in rgb)+(1.,)


def render_variant(author,meshes,path):
    """Identical camera/light to the neutral study; exact inverse IEC transfer."""
    width,height,panel=1440,650,480
    pixels=bytearray((23,31,34)*(width*height));depth=[-1e10]*(width*height)
    light=author.unit((-.6,.9,-.7))
    def display(value):
        value=max(0,min(1,value))
        srgb=12.92*value if value<=.0031308 else 1.055*value**(1/2.4)-.055
        return min(255,max(0,int(srgb*255)))
    for pi,azimuth in enumerate((0,40,90)):
        az=math.radians(azimuth);el=math.radians(7)
        d=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el))
        right=(math.cos(az),0,math.sin(az));up=author.cross(right,d)
        scale=86.;cx=pi*panel+panel/2;cy=height/2+4
        for mesh in meshes.values():
            positions=[];colors=[]
            for v,n,c in zip(mesh.vertices,mesh.normals(),mesh.colors):
                x,y,z=author.dot(v,right),author.dot(v,up),author.dot(v,d)
                positions.append((cx+x*scale,cy-y*scale,z))
                lum=.40+.60*max(0,author.dot(n,light))
                colors.append(tuple(display(a*lum) for a in c[:3]))
            for a,b,c in mesh.faces:
                p,q,r=positions[a],positions[b],positions[c]
                area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-7:continue
                minx=max(pi*panel,int(min(p[0],q[0],r[0])));maxx=min((pi+1)*panel-1,int(max(p[0],q[0],r[0]))+1)
                miny=max(0,int(min(p[1],q[1],r[1])));maxy=min(height-1,int(max(p[1],q[1],r[1]))+1)
                for y in range(miny,maxy+1):
                    for x in range(minx,maxx+1):
                        u=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area
                        v=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area
                        w=1-u-v
                        if u<0 or v<0 or w<0:continue
                        z=u*p[2]+v*q[2]+w*r[2];index=y*width+x
                        if z<=depth[index]:continue
                        depth[index]=z
                        for channel in range(3):pixels[index*3+channel]=int(u*colors[a][channel]+v*colors[b][channel]+w*colors[c][channel])
    author.png(path,width,height,pixels)


def main():
    original=BASE_PATH.read_bytes()
    assert sha(original)==EXPECTED_BASE,'Frozen base GLB changed; do not overwrite or silently use another geometry'
    scene,start=read_glb(original)
    ranges=color_ranges(scene,start)
    author=load_authoring()
    old_colors={
        struct.unpack('<4f',struct.pack('<4f',*author.BLACK)):1,
        struct.unpack('<4f',struct.pack('<4f',*author.DARK)):2,
        struct.unpack('<4f',struct.pack('<4f',*author.GREEN)):3,
    }
    source=json.loads(SOURCE_CATALOG.read_text(encoding='utf-8'))
    rgba=load_rgba()
    codes=source['paletteIndices']
    assert codes[:4]==[0x0f,0x0f,0x0a,0x1a] and codes[4:8]==[0x0f,0x0f,0x17,0x27]
    identity_hash=neutral_color_hash(original,ranges)
    variants=[]
    for player,palette in ((1,codes[:4]),(2,codes[4:8])):
        colors={slot:linear(rgba(code)[:3]) for slot,code in enumerate(palette)}
        changed=bytearray(original);counts={1:0,2:0,3:0}
        for _,offset,count in ranges:
            for i in range(count):
                pointer=offset+i*16
                old=struct.unpack_from('<4f',original,pointer)
                slot=old_colors[old]
                struct.pack_into('<4f',changed,pointer,*colors[slot]);counts[slot]+=1
        path=HERE/f'canonical-hero-player{player}.glb'
        path.write_bytes(changed)
        # This covers the entire file, including every transform, face, normal,
        # position and JSON byte. Only COLOR_0 bytes may differ.
        assert neutral_color_hash(changed,ranges)==identity_hash
        meshes=author.build_meshes()
        remap={author.BLACK:colors[1],author.DARK:colors[2],author.GREEN:colors[3]}
        for mesh in meshes.values():mesh.colors=[remap[color] for color in mesh.colors]
        preview=ROOT/f'research/canonical-visuals/hero-model-player{player}-palette.png'
        render_variant(author,meshes,preview)
        variants.append({'file':path.name,'sourcePlayerSlot':player-1,'sourcePaletteCodes':[f'{v:02X}' for v in palette],
            'displayRGBApproximation':[list(rgba(code)[:3]) for code in palette],
            'colorTransfer':'IEC sRGB to linear glTF COLOR_0: c<=0.04045 -> c/12.92, else ((c+0.055)/1.055)^2.4; exact inverse IEC in previews',
            'bytes':len(changed),'sha256':sha(changed),'colorNeutralizedWholeFileSha256':identity_hash,
            'colorVertexCounts':counts,'preview':preview.relative_to(ROOT).as_posix(),
            'geometryAndRigByteIdenticalToBase':True,
            'templateNameAdaptation':'Mr. Green' if player==1 else 'Mr. Yellow (legacy BrickToads name; source P2 is orange/brown, not an invented yellow palette)'})
    assert sha(BASE_PATH.read_bytes())==EXPECTED_BASE,'Base must remain byte-identical'
    manifest={'schema':1,'status':'source-palette-3d-study-not-release-approved',
        'sourcePin':source['pin'],'source':'palette_chars main.asm line36743',
        'sourceRGBFunction':'research/canonical-visuals/extract_source_frames.py::rgba',
        'extractorSha256':sha(EXTRACTOR.read_bytes()),'paletteIs':'source codes authoritative; RGB approximate2C02 display, not analog CRT measurement',
        'base':{'file':BASE_PATH.name,'sha256':EXPECTED_BASE,'modified':False},
        'sharedRig':'canonical-hero-rig.json','gltfMetresPerStud':.28,'variants':variants,
        'thirdHero':{'included':False,'reason':'The source has two playable slots. Brown/Pimple playable appearance is not inferred from P2 or a guessed third palette.'},
        'validation':{'status':'PASS','vertexPositionsNormalsIndicesAndNodeTransformsUnchanged':True,
            'allDifferencesRestrictedToColor0':True,'basePreserved':True,'studioImport':'NOT_RUN','animation':'NOT_INCLUDED'}}
    (HERE/'palette-variants.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))


if __name__=='__main__':main()
