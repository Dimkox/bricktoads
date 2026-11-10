"""Lossless GLB merge for a single native import, retaining per-family rigs.

Only accessor/material/texture/node indices and byte offsets change. Mesh and
node names gain the Family__ prefix; triangle arrays and transforms are copied
byte-for-byte. The28cast families plus HealingFly remain independent hierarchies
at their authored origins. No coordinate-layout offsets are introduced.
"""
from pathlib import Path
import hashlib, json, struct

HERE=Path(__file__).resolve().parent

def parse(blob):
    magic,version,total=struct.unpack_from('<4sII',blob);assert(magic,version,total)==(b'glTF',2,len(blob))
    size=struct.unpack_from('<I',blob,12)[0];scene=json.loads(blob[20:20+size]);return scene,blob[28+size:]

def pack():
    manifest=json.loads((HERE/'manifest.json').read_text());data=bytearray()
    combined={'asset':{'version':'2.0','generator':'BrickToads lossless combined cast import pack','extras':{'metresPerStud':.28,'sourcePin':manifest['sourcePin']}},'scene':0,'scenes':[{'name':'CanonicalCast','nodes':[]}],
              'nodes':[],'meshes':[],'accessors':[],'bufferViews':[],'images':[],'textures':[],'materials':[],'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]}
    families={}
    for family,entry in manifest['families'].items():
        path=HERE/family/(family+'.glb');blob=path.read_bytes();scene,binary=parse(blob)
        assert hashlib.sha256(blob).hexdigest()==entry['sha256'],family
        while len(data)%4:data.append(0)
        offset=len(data);data.extend(binary)
        vb=len(combined['bufferViews']);ab=len(combined['accessors']);mb=len(combined['meshes']);nb=len(combined['nodes']);ib=len(combined['images']);tb=len(combined['textures']);matb=len(combined['materials'])
        for view in scene['bufferViews']:view['byteOffset']=view.get('byteOffset',0)+offset
        for accessor in scene['accessors']:accessor['bufferView']+=vb
        for image in scene['images']:image['bufferView']+=vb;image['name']=family+'__'+image['name']
        for texture in scene['textures']:texture['source']+=ib;texture['sampler']=0
        for material in scene['materials']:material['name']=family+'__'+material['name'];material['pbrMetallicRoughness']['baseColorTexture']['index']+=tb
        for mesh in scene['meshes']:
            mesh['name']=family+'__'+mesh['name']
            for primitive in mesh['primitives']:
                primitive['attributes']={k:v+ab for k,v in primitive['attributes'].items()};primitive['indices']+=ab;primitive['material']+=matb
        for node in scene['nodes']:
            node['name']=family+'__'+node['name'];node['mesh']+=mb
            if 'children' in node:node['children']=[i+nb for i in node['children']]
        for key in ('nodes','meshes','accessors','bufferViews','images','textures','materials'):combined[key].extend(scene[key])
        combined['scenes'][0]['nodes'].extend(i+nb for i in scene['scenes'][0]['nodes'])
        families[family]={'individualGlbSha256':entry['sha256'],'meshNames':[m['name'] for m in scene['meshes']],'nodeNames':[n['name'] for n in scene['nodes']],'rig':entry['rig'],'bounds':entry['bounds'],'layoutOffsetStuds':[0,0,0]}
    combined['buffers']=[{'byteLength':len(data)}];encoded=json.dumps(combined,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    blob=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(data))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data
    assert len(blob)<20_000_000
    target=HERE/'canonical-cast.glb';target.write_bytes(blob)
    result={'schema':1,'glb':target.name,'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),'familyCount':len(families),'meshCount':len(combined['meshes']),'sourcePin':manifest['sourcePin'],'families':families,'meshNames':[m['name'] for m in combined['meshes']],'layout':'Independent family hierarchies at their authored origins. NamesFamily__Segment. Exact individual vertex/normal/UV/index arrays and transforms retained.','nativeImportStatus':'PENDING'}
    (HERE/'canonical-cast-pack.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ('glb','sha256','bytes','familyCount','meshCount')},indent=2))
    return result

if __name__=='__main__':pack()
