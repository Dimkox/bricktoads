"""Remap only the embedded base-color atlas of the frozen detailed brawler.

P2 uses pinned source palette17/27. Brown is the owner's explicit third-player
adaptation. Positions, normals, indices, UVs, joints and PBR maps remain exact.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import zlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
SOURCE_SHA='22c949f45a084f68dd61053cd9e62c2651cb8d351bf124c9eb2a23347a0fe543'


def load(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


B=load('brawler_surface_tools','bake_green_brawler_surface.py')
P=load('brawler_source_palette','build_palette_variants.py')
RGB=P.load_rgba()
PALETTES={
    'player2':{'shadow':RGB(0x17)[:3],'highlight':RGB(0x27)[:3],
        'sourcePaletteCodes':['0F','0F','17','27'],'sourcePlayerSlot':1,
        'meaning':'Pinned NES P2 swatches with authored 3D shading; Mr. Yellow is the legacy runtime name'},
    'brown':{'shadow':(160,112,86),'highlight':(224,186,129),
        'sourcePaletteCodes':None,'sourcePlayerSlot':None,
        'meaning':'Owner-approved third-player Brown palette; not an original third NES playable slot'},
}


def sha(data):return hashlib.sha256(data).hexdigest()


def recolor_rgba(pixels,variant):
    """Preserve non-green texels exactly; remap the skin's linear tonal ramp.

    The frozen authoring Grass/Lime green-channel anchors are110/199 sRGB.
    Their original linear ratios retain grain, creases, warts and dark shading.
    This is an atlas remap, never a multiplicative green SurfaceAppearance tint.
    """
    palette=PALETTES[variant]
    assert len(pixels)%4==0
    ramp=[B.srgb_decode(i/255) for i in range(256)]
    shadow=[B.srgb_decode(v/255) for v in palette['shadow']]
    highlight=[B.srgb_decode(v/255) for v in palette['highlight']]
    mapped=[]
    for g in range(256):
        t=(ramp[g]-ramp[110])/(ramp[199]-ramp[110])
        color=[v*ramp[g]/ramp[110] for v in shadow] if g<=110 else [a+(b-a)*t for a,b in zip(shadow,highlight)]
        mapped.append(bytes(B.srgb_encode(v) for v in color))
    result=bytearray(pixels);changed=0;preserved=0
    for i in range(0,len(pixels),4):
        r,g,b=pixels[i:i+3]
        if g>=8 and g>r*1.08 and g>b*1.08 and g-min(r,b)>8:
            result[i:i+3]=mapped[g];changed+=1
        else:preserved+=1
    assert result[3::4]==pixels[3::4],'Alpha must be preserved'
    return result,{'changedPixels':changed,'preservedPixels':preserved,'totalPixels':len(pixels)//4,
        'method':'Selective green-hue linear tonal remap through source17/27 or approved Brown anchors',
        'sourceGreenAnchors':[110,199],'nonGreenTexelsByteIdentical':True,'alphaByteIdentical':True}


def base_color_view(scene):
    materials=scene['materials'];assert len(materials)==1
    texture=materials[0]['pbrMetallicRoughness']['baseColorTexture']['index']
    image=scene['textures'][texture]['source']
    return scene['images'][image]['bufferView']


def embedded_png(scene,binary,image):
    view=scene['bufferViews'][scene['images'][image]['bufferView']]
    return binary[view['byteOffset']:view['byteOffset']+view['byteLength']]


def validate_png(blob):
    assert blob[:8]==b'\x89PNG\r\n\x1a\n'
    cursor=8;ended=False
    while cursor<len(blob):
        count=struct.unpack_from('>I',blob,cursor)[0];kind=blob[cursor+4:cursor+8]
        payload=blob[cursor+8:cursor+8+count]
        crc=struct.unpack_from('>I',blob,cursor+8+count)[0]
        assert zlib.crc32(kind+payload)&0xffffffff==crc,'Invalid PNG CRC'
        cursor+=count+12
        if kind==b'IEND':ended=True;break
    assert ended and cursor==len(blob)
    width,height,pixels=B.png_decode(blob)
    assert width==height==B.SIZE and len(pixels)==width*height*4
    assert sum(pixels[0::4])+sum(pixels[1::4])+sum(pixels[2::4])>0,'Black texture'
    return width,height,pixels


def noncolor_fingerprint(scene,binary):
    view=scene['bufferViews'][base_color_view(scene)];start=view['byteOffset']
    end=(start+view['byteLength']+3)//4*4
    return sha(binary[:start]+binary[end:])


def encode_glb(scene,binary):
    encoded=json.dumps(scene,separators=(',',':')).encode()
    encoded+=b' '*((-len(encoded))%4);binary+=b'\0'*((-len(binary))%4)
    total=12+8+len(encoded)+8+len(binary)
    return struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(binary),b'BIN\0')+binary


def build_variant(source,destination,variant):
    source=Path(source);destination=Path(destination)
    if source.resolve()==destination.resolve():raise ValueError('The source GLB cannot be overwritten')
    if destination.parent.resolve()==HERE and destination.name not in ('brawler-player2.glb','brawler-brown.glb'):
        raise ValueError('Only the two new brawler variant filenames may be written in the asset directory')
    original=source.read_bytes();assert sha(original)==SOURCE_SHA,'Frozen detailed P1 GLB changed'
    source_scene,binary=B.parse(original);scene=copy.deepcopy(source_scene)
    assert len(scene['nodes'])==len(scene['meshes'])==15 and len(scene['images'])==3
    palette_catalog=json.loads((ROOT/'research/canonical-visuals/hero-frame-catalog.json').read_text(encoding='utf-8'))
    assert palette_catalog['paletteIndices'][4:8]==[0x0F,0x0F,0x17,0x27]
    images=[validate_png(embedded_png(scene,binary,i)) for i in range(3)]
    view_index=base_color_view(scene);view=scene['bufferViews'][view_index]
    assert scene['images'][0]['bufferView']==view_index
    pixels,pixel_report=recolor_rgba(images[0][2],variant)
    new_png=B.png_encode(pixels);validate_png(new_png)
    start=view['byteOffset'];old_end=(start+view['byteLength']+3)//4*4
    replacement=new_png+b'\0'*((-len(new_png))%4)
    changed=binary[:start]+replacement+binary[old_end:]
    delta=len(replacement)-(old_end-start)
    view['byteLength']=len(new_png)
    for index,item in enumerate(scene['bufferViews']):
        if index!=view_index and item.get('byteOffset',0)>=old_end:item['byteOffset']+=delta
    scene['buffers'][0]['byteLength']+=delta
    for key in ('nodes','meshes','accessors','materials','images','textures','samplers','asset','scene','scenes'):
        assert scene[key]==source_scene[key],key+' changed'
    assert noncolor_fingerprint(scene,changed)==noncolor_fingerprint(source_scene,binary),'Non-color binary changed'
    geometry=B.triangle_fingerprint(source_scene,binary)
    assert B.triangle_fingerprint(scene,changed)==geometry
    for i in (1,2):assert embedded_png(scene,changed,i)==embedded_png(source_scene,binary,i)
    blob=encode_glb(scene,changed);decoded,decoded_binary=B.parse(blob)
    assert B.triangle_fingerprint(decoded,decoded_binary)==geometry
    assert len(blob)<20_000_000
    destination.write_bytes(blob)
    assert sha(source.read_bytes())==SOURCE_SHA
    return {'file':destination.name,'variant':variant,'bytes':len(blob),'sha256':sha(blob),
        'sourceFile':source.name,'sourceSha256':SOURCE_SHA,'sourceRig':'green-brawler-rig.json',
        'sourceReference':PALETTES[variant],'pixels':pixel_report,
        'trianglePositionsAndNormalsSha256':geometry,'nonColorBinarySha256':noncolor_fingerprint(decoded,decoded_binary),
        'embeddedImages':[{'image':i,'sha256':sha(embedded_png(decoded,decoded_binary,i)),'size':[images[i][0],images[i][1]]} for i in range(3)],
        'validation':{'status':'PASS','onlyBaseColorTextureChanged':True,'geometryNodesUVsAndMaterialsUnchanged':True,
            'ormAndNormalByteIdentical':True,'allPngCRCsValid':True,'nodes':15,'materials':1,'textures':3,
            'sourcePreserved':True,'actualStudioImport':'PENDING'}}


def preview(variants):
    renderer=load('brawler_palette_portraits','render_character_portraits.py')
    rows=[]
    for label,path in [('player1',HERE/'green-brawler.glb'),*[(row['variant'],HERE/row['file']) for row in variants]]:
        target=HERE/f'brawler-{label}-portrait.png';rows.append(renderer.image(path,target))
    # The portrait renderer produces ordinary filter0 RGB PNGs; compose those
    # actual textured mesh projections, not concept art or a mockup.
    def rgb_png(path):
        blob=path.read_bytes();cursor=8;compressed=bytearray()
        while cursor<len(blob):
            count=struct.unpack_from('>I',blob,cursor)[0];kind=blob[cursor+4:cursor+8];payload=blob[cursor+8:cursor+8+count];cursor+=count+12
            if kind==b'IHDR':w,h,depth,color,*_=struct.unpack('>IIBBBBB',payload);assert depth==8 and color==2
            if kind==b'IDAT':compressed.extend(payload)
        data=zlib.decompress(compressed);stride=w*3;pixels=bytearray()
        for y in range(h):assert data[y*(stride+1)]==0;pixels.extend(data[y*(stride+1)+1:(y+1)*(stride+1)])
        return w,h,pixels
    portraits=[rgb_png(HERE/row['file']) for row in rows];width,height,_=portraits[0]
    pixels=bytearray()
    for y in range(height):
        for w,h,data in portraits:assert (w,h)==(width,height);pixels.extend(data[y*width*3:(y+1)*width*3])
    renderer.G.png(HERE/'brawler-palette-triptych.png',width*3,height,pixels)
    return rows


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--preview',action='store_true');args=parser.parse_args()
    protected={p.name:sha(p.read_bytes()) for p in HERE.glob('*.glb') if p.name not in ('brawler-player2.glb','brawler-brown.glb')}
    variants=[build_variant(HERE/'green-brawler.glb',HERE/f'brawler-{variant}.glb',variant) for variant in ('player2','brown')]
    portraits=preview(variants) if args.preview else []
    assert all(sha((HERE/name).read_bytes())==fingerprint for name,fingerprint in protected.items())
    manifest={'schema':1,'status':'PASS','sourceCommit':'f1a43b69577246850d136473700a333b3cdfe93f',
        'sourcePaletteLocation':'main.asm:36743 palette_chars; P2=0F/0F/17/27',
        'rgbBoundary':'NES palette codes authoritative; extractor RGB approximates display; 3D tonal interpolation authored',
        'sourceGlbSha256':SOURCE_SHA,'allPriorGlbsPreserved':protected,'variants':variants,'portraits':portraits,
        'actualStudioImport':'PENDING; no Roblox manifests modified by this builder'}
    (HERE/'brawler-palette-variants.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'PASS','variants':[{k:row[k] for k in ('file','bytes','sha256')} for row in variants],'preview':bool(portraits)},indent=2))


if __name__=='__main__':main()
