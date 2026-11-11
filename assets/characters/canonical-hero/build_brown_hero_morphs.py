"""Dedicated Brown atlases on exact existing Green attack/fear mesh data.

No input GLB, Roblox manifest or runtime source is modified. Brown is an
approved third-player palette adaptation, not an original NES player slot.
"""
from __future__ import annotations
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import zlib

HERE=Path(__file__).resolve().parent


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,HERE/path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


Palette=load('brown_morph_palette','build_brawler_palette_variants.py')
B=Palette.B
SOURCES=(
    {'file':'hero-attack-morphs.glb','rig':'hero-attack-morphs-rig.json',
        'sha256':'250a7dec19adba96c735b55164fc4d4e1fef9b5a595ce4fac59e8852dbc79f0e',
        'parts':(('GreenPowerFist','BrownPowerFist'),('GreenBigBoot','BrownBigBoot'))},
    {'file':'hero-fear-wide-mouth.glb','rig':'hero-fear-wide-mouth-rig.json',
        'sha256':'e5dd859b9be454198046580a147f7d202fd5374502f0f860384d1590efa325c1',
        'parts':(('GreenFearBeforeCut','BrownFearBeforeCut'),('GreenFearAfterCut','BrownFearAfterCut'))},
)


def sha(data):return hashlib.sha256(data).hexdigest()


def recolor(pixels):return Palette.recolor_rgba(pixels,'brown')


def png_encode(width,height,pixels):
    assert len(pixels)==width*height*4
    def chunk(kind,payload):
        return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    stride=width*4;scan=b''.join(b'\0'+pixels[y*stride:(y+1)*stride] for y in range(height))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan,8))+chunk(b'IEND',b'')


def mesh_fingerprint(scene,binary,index):
    """Hash accessor metadata and bytes, independent of new index/name layout."""
    digest=hashlib.sha256()
    for primitive in scene['meshes'][index]['primitives']:
        for semantic,accessor_index in [*sorted(primitive['attributes'].items()),('INDICES',primitive['indices'])]:
            accessor=scene['accessors'][accessor_index];view=scene['bufferViews'][accessor['bufferView']]
            digest.update(semantic.encode());metadata={k:v for k,v in accessor.items() if k!='bufferView'}
            digest.update(json.dumps(metadata,sort_keys=True,separators=(',',':')).encode())
            digest.update(str(view.get('byteStride',0)).encode())
            start=view.get('byteOffset',0);digest.update(binary[start:start+view['byteLength']])
    return digest.hexdigest()


def build(destination=HERE/'brown-hero-morphs.glb'):
    destination=Path(destination)
    if destination.parent.resolve()==HERE and destination.name!='brown-hero-morphs.glb':
        raise ValueError('Only the new brown-hero-morphs.glb may be written in the asset directory')
    output=bytearray();scene={'asset':{'version':'2.0','generator':'BrickToads exact Green geometry with dedicated Brown atlases'},
        'scene':0,'scenes':[{'nodes':[0,1,2,3]}],'nodes':[],'meshes':[],'accessors':[],
        'bufferViews':[],'materials':[],'textures':[],'images':[],'samplers':[]}
    reports=[];image_reports=[];source_hashes={};atlas_outputs=[]
    def add_view(data,metadata=None):
        output.extend(b'\0'*((-len(output))%4));offset=len(output);output.extend(data)
        view=copy.deepcopy(metadata or {});view.update(buffer=0,byteOffset=offset,byteLength=len(data))
        scene['bufferViews'].append(view);return len(scene['bufferViews'])-1
    for material_index,spec in enumerate(SOURCES):
        original=(HERE/spec['file']).read_bytes();assert sha(original)==spec['sha256'],'Frozen source changed'
        source_hashes[spec['file']]=sha(original);source,binary=B.parse(original)
        assert len(source['materials'])==len(source['images'])==1
        source_rig=json.loads((HERE/spec['rig']).read_text(encoding='utf-8'))
        copied_views={};copied_accessors={}
        def copy_accessor(old_index):
            if old_index in copied_accessors:return copied_accessors[old_index]
            accessor=copy.deepcopy(source['accessors'][old_index]);old_view=accessor['bufferView']
            if old_view not in copied_views:
                view=source['bufferViews'][old_view];start=view.get('byteOffset',0)
                copied_views[old_view]=add_view(binary[start:start+view['byteLength']],view)
            accessor['bufferView']=copied_views[old_view]
            scene['accessors'].append(accessor);index=len(scene['accessors'])-1;copied_accessors[old_index]=index
            return index
        for source_name,name in spec['parts']:
            old_node=next(n for n in source['nodes'] if n['name']==source_name)
            assert not old_node.get('children') and 'skin' not in old_node
            mesh=copy.deepcopy(source['meshes'][old_node['mesh']]);mesh['name']=name
            for primitive in mesh['primitives']:
                assert 'COLOR_0' not in primitive['attributes']
                primitive['attributes']={key:copy_accessor(value) for key,value in primitive['attributes'].items()}
                primitive['indices']=copy_accessor(primitive['indices']);primitive['material']=material_index
            scene['meshes'].append(mesh);node=copy.deepcopy(old_node);node.update(name=name,mesh=len(scene['meshes'])-1)
            scene['nodes'].append(node)
            rig=copy.deepcopy(next(p for p in source_rig['parts'] if p['name']==source_name))
            rig.update(name=name,heroTemplate='Mr. Brown',sourceName=source_name,sourceGlb=spec['file'],sourceRig=spec['rig'],
                sourceGlbSha256=spec['sha256'],geometryAndUVSha256=mesh_fingerprint(source,binary,old_node['mesh']),
                sourceNodeTransform={k:v for k,v in old_node.items() if k not in ('name','mesh')})
            assert mesh_fingerprint(scene,output,node['mesh'])==rig['geometryAndUVSha256']
            reports.append(rig)
        image_view=source['bufferViews'][source['images'][0]['bufferView']];start=image_view.get('byteOffset',0)
        width,height,pixels=B.png_decode(binary[start:start+image_view['byteLength']])
        recolored,stats=recolor(pixels);png=png_encode(width,height,recolored)
        w,h,checked=B.png_decode(png);assert (w,h)==(width,height) and checked==recolored
        # Every qualifying visible green becomes a Brown red-dominant texel.
        remaining=sum(1 for i in range(0,len(recolored),4)
            if recolored[i+1]>=32 and recolored[i+1]>recolored[i]*1.15 and recolored[i+1]>recolored[i+2]*1.15)
        assert remaining==0,'Bright green remains in Brown atlas'
        new_view=add_view(png);scene['images'].append({'name':f'BrownMorphAtlas{material_index}','bufferView':new_view,'mimeType':'image/png'})
        scene['samplers'].append(copy.deepcopy(source['samplers'][0]))
        scene['textures'].append({'sampler':material_index,'source':material_index})
        material=copy.deepcopy(source['materials'][0]);material['name']=f'BrownMorphMaterial{material_index}'
        material['pbrMetallicRoughness']['baseColorTexture']['index']=material_index;scene['materials'].append(material)
        image_reports.append({'sourceGlb':spec['file'],'image':material_index,'size':[width,height],
            'sourcePngSha256':sha(binary[start:start+image_view['byteLength']]),'pngSha256':sha(png),
            'brightGreenRemaining':remaining,'pixels':stats,'redTongueDarkCavityTeethEyesPreserved':True})
        atlas_outputs.append((f'brown-hero-morphs-atlas-{material_index}.png',png))
    scene['buffers']=[{'byteLength':len(output)}];blob=Palette.encode_glb(scene,bytes(output))
    assert len(blob)<20_000_000;decoded,raw=B.parse(blob)
    for index,row in enumerate(reports):
        assert mesh_fingerprint(decoded,raw,index)==row['geometryAndUVSha256']
        node=decoded['nodes'][index]
        assert {k:v for k,v in node.items() if k not in ('name','mesh')}==row['sourceNodeTransform']
    assert all(sha((HERE/name).read_bytes())==value for name,value in source_hashes.items())
    destination.write_bytes(blob)
    return {'schema':1,'status':'PASS','file':destination.name,'bytes':len(blob),'sha256':sha(blob),
        'sourcePin':'f1a43b69577246850d136473700a333b3cdfe93f','sourceGlbs':source_hashes,
        'heroTemplate':'Mr. Brown','paletteAdaptation':Palette.PALETTES['brown'],'parts':reports,'atlases':image_reports,
        'units':{'metadata':'Roblox studs','gltf':'metres','metresPerStud':.28},
        'validation':{'oldGlbsPreserved':True,'allFourGeometryUVsAndPivotsExact':True,'nodes':4,'materials':2,'atlases':2,
            'COLOR_0':'absent','runtimeDimensionsOrAttachmentsChanged':False,'nativeImport':'PENDING'},
        '_atlases':atlas_outputs}


def main():
    report=build();atlases=report.pop('_atlases')
    for name,png in atlases:(HERE/name).write_bytes(png)
    for name in ('brown-hero-morphs-rig.json','brown-hero-morphs-validation.json'):
        (HERE/name).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report[key] for key in ('status','file','bytes','sha256','validation')},indent=2))


if __name__=='__main__':main()
