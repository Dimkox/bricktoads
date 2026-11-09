"""Bake macro vertex colour into unique triangle UVs for Roblox SurfaceAppearance.

The live importer ignores COLOR_0 when its texture pack is ready. This conversion
does not change triangle positions/normals, node transforms or joint metadata.
It intentionally removes all COLOR_0 and emissive references from the GLB.
"""
from __future__ import annotations
import copy, hashlib, json, math, struct, zlib
from pathlib import Path

HERE=Path(__file__).resolve().parent
SIZE=2048
CELL=8
COLS=SIZE//CELL

def unit(v):
    scale=math.sqrt(sum(x*x for x in v)) or 1
    return tuple(x/scale for x in v)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def srgb_decode(x):return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
def srgb_encode(x):
    x=max(0,min(1,x));return int(round(255*(12.92*x if x<=.0031308 else 1.055*x**(1/2.4)-.055)))

def png_decode(blob):
    cursor=8;data=bytearray()
    while cursor<len(blob):
        n=struct.unpack_from('>I',blob,cursor)[0];kind=blob[cursor+4:cursor+8];payload=blob[cursor+8:cursor+8+n];cursor+=12+n
        if kind==b'IHDR':width,height,depth,color,*_=struct.unpack('>IIBBBBB',payload);assert depth==8 and color==6
        if kind==b'IDAT':data.extend(payload)
    scan=zlib.decompress(data);stride=width*4;out=bytearray(width*height*4)
    for y in range(height):
        start=y*(stride+1);assert scan[start]==0
        out[y*stride:(y+1)*stride]=scan[start+1:start+1+stride]
    return width,height,out

def png_encode(data):
    def chunk(kind,payload):return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    scan=b''.join(b'\0'+data[y*SIZE*4:(y+1)*SIZE*4] for y in range(SIZE))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',SIZE,SIZE,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan,8))+chunk(b'IEND',b'')

def parse(blob):
    jlen=struct.unpack_from('<I',blob,12)[0]
    return json.loads(blob[20:20+jlen]),blob[28+jlen:]

def read_accessor(scene,binary,index):
    a=scene['accessors'][index];v=scene['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];code={5126:'f',5123:'H',5125:'I'}[a['componentType']]
    fmt='<'+str(n)+code;size=struct.calcsize(fmt);start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size)
    result=[struct.unpack_from(fmt,binary,start+i*stride) for i in range(a['count'])]
    return [v[0] for v in result] if n==1 else result

def triangle_fingerprint(scene,binary):
    result=hashlib.sha256()
    for mesh in scene['meshes']:
        result.update(mesh['name'].encode())
        for p in mesh['primitives']:
            positions=read_accessor(scene,binary,p['attributes']['POSITION']);normals=read_accessor(scene,binary,p['attributes']['NORMAL'])
            for index in read_accessor(scene,binary,p['indices']):result.update(struct.pack('<6f',*positions[index],*normals[index]))
    return result.hexdigest()

def bake(path):
    original=path.read_bytes();source,binary=parse(original)
    if any('COLOR_0' not in m['primitives'][0]['attributes'] for m in source['meshes']):
        raise ValueError('Input is already baked; first rebuild the authoring model')
    source_sha=hashlib.sha256(original).hexdigest();geometry_sha=triangle_fingerprint(source,binary)
    images=[]
    for image in source['images'][:3]:
        v=source['bufferViews'][image['bufferView']];images.append(png_decode(binary[v['byteOffset']:v['byteOffset']+v['byteLength']]))
    assert all(w==h==256 for w,h,_ in images)
    atlas=[bytearray(SIZE*SIZE*4) for _ in range(3)]
    # Unused atlas cells are harmless opaque neutral texels, not transparent.
    atlas[0][:]=bytes((16,32,16,255))*(SIZE*SIZE)
    atlas[1][:]=bytes((255,180,0,255))*(SIZE*SIZE)
    atlas[2][:]=bytes((128,128,255,255))*(SIZE*SIZE)
    srgb=[srgb_decode(i/255) for i in range(256)]
    output=bytearray();views=[];accessors=[];meshes=[];counts={};tile=0
    def accessor(values,ctype,kind,minimum=None,maximum=None,target=34962):
        while len(output)%4:output.append(0)
        offset=len(output);flat=[x for row in values for x in row] if isinstance(values[0],(tuple,list)) else values
        output.extend(struct.pack('<'+str(len(flat))+('f' if ctype==5126 else 'H'),*flat))
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(output)-offset,'target':target})
        a={'bufferView':len(views)-1,'componentType':ctype,'count':len(values),'type':kind}
        if minimum is not None:a.update(min=minimum,max=maximum)
        accessors.append(a);return len(accessors)-1
    for mesh in source['meshes']:
        p=mesh['primitives'][0];attrs=p['attributes'];arrays={k:read_accessor(source,binary,v) for k,v in attrs.items()}
        old_indices=read_accessor(source,binary,p['indices']);positions=[];normals=[];tangents=[];uvs=[]
        for k in range(0,len(old_indices),3):
            ids=old_indices[k:k+3];pos=[arrays['POSITION'][i] for i in ids];ns=[arrays['NORMAL'][i] for i in ids]
            cs=[arrays['COLOR_0'][i] for i in ids];old_uv=[arrays['TEXCOORD_0'][i] for i in ids]
            old_ts=[arrays['TANGENT'][i] for i in ids]
            roles=[(min(3,int(uv[0]*4)),min(1,int(uv[1]*2))) for uv in old_uv]
            local_uv=[(uv[0]*4-r[0],uv[1]*2-r[1]) for uv,r in zip(old_uv,roles)]
            e1=sub(pos[1],pos[0]);e2=sub(pos[2],pos[0]);new_ts=[];old_bs=[]
            for n,t in zip(ns,old_ts):
                nt=unit(tuple(e1[j]-n[j]*dot(n,e1) for j in range(3)));sign=1. if dot(cross(n,nt),e2)>0 else -1.
                new_ts.append((*nt,sign));old_bs.append(tuple(v*t[3] for v in cross(n,t[:3])))
            tx=(tile%COLS)*CELL;ty=(tile//COLS)*CELL
            assert ty+CELL<=SIZE
            for yy in range(CELL):
                for xx in range(CELL):
                    w=[1-(xx+.5-1.5)/4-(yy+.5-1.5)/4,(xx+.5-1.5)/4,(yy+.5-1.5)/4]
                    w=[max(0,v) for v in w];total=sum(w);w=[v/total for v in w]
                    lu=sum(w[i]*local_uv[i][0] for i in range(3));lv=sum(w[i]*local_uv[i][1] for i in range(3))
                    # Sample the same local grain in each corner's own role cell.
                    # Interpolating absolute role UVs would cross unrelated cells.
                    samples=[]
                    for col,row in roles:
                        x=min(255,max(0,int((col+lu)*64)));y=min(255,max(0,int((row+lv)*128)));samples.append((y*256+x)*4)
                    pixel=((ty+yy)*SIZE+tx+xx)*4
                    color=[sum(w[i]*cs[i][j] for i in range(3)) for j in range(3)]
                    for channel in range(3):
                        albedo=sum(w[i]*srgb[images[0][2][samples[i]+channel]] for i in range(3))
                        atlas[0][pixel+channel]=srgb_encode(color[channel]*albedo)
                        atlas[1][pixel+channel]=round(sum(w[i]*images[1][2][samples[i]+channel] for i in range(3)))
                    # Transfer the old tangent-space micro normal into the new UV
                    # basis. Preserve the old .55 normal strength in the bake.
                    sampled=[sum(w[i]*(images[2][2][samples[i]+j]/127.5-1) for i in range(3)) for j in range(3)]
                    sampled=unit((sampled[0]*.55,sampled[1]*.55,sampled[2]))
                    n=unit(tuple(sum(w[i]*ns[i][j] for i in range(3)) for j in range(3)))
                    ot=unit(tuple(sum(w[i]*old_ts[i][j] for i in range(3)) for j in range(3)))
                    ob=unit(tuple(sum(w[i]*old_bs[i][j] for i in range(3)) for j in range(3)))
                    perturb=unit(tuple(ot[j]*sampled[0]+ob[j]*sampled[1]+n[j]*sampled[2] for j in range(3)))
                    nt=unit(tuple(sum(w[i]*new_ts[i][j] for i in range(3)) for j in range(3)))
                    nb=tuple(v*new_ts[0][3] for v in cross(n,nt));mapped=unit((dot(perturb,nt),dot(perturb,nb),dot(perturb,n)))
                    for channel in range(3):atlas[2][pixel+channel]=round(max(0,min(255,(mapped[channel]*.5+.5)*255)))
            positions.extend(pos);normals.extend(ns);tangents.extend(new_ts)
            uvs.extend([((tx+x)/SIZE,(ty+y)/SIZE) for x,y in ((1.5,1.5),(5.5,1.5),(1.5,5.5))]);tile+=1
        assert len(positions)<65536
        bounds=[[min(p[i] for p in positions) for i in range(3)],[max(p[i] for p in positions) for i in range(3)]]
        attributes={'POSITION':accessor(positions,5126,'VEC3',*bounds),'NORMAL':accessor(normals,5126,'VEC3'),
            'TANGENT':accessor(tangents,5126,'VEC4'),'TEXCOORD_0':accessor(uvs,5126,'VEC2')}
        index=accessor(list(range(len(positions))),5123,'SCALAR',target=34963)
        meshes.append({'name':mesh['name'],'primitives':[{'attributes':attributes,'indices':index,'material':0}]})
        counts[mesh['name']]={'vertices':len(positions),'triangles':len(positions)//3,'sourceVertices':len(arrays['POSITION'])}
        print('Baked',mesh['name'],len(positions),flush=True)
    embedded=[]
    for name,data in zip(('albedo','orm','normal'),atlas):
        blob=png_encode(data);(HERE/f'green-brawler-baked-{name}.png').write_bytes(blob)
        while len(output)%4:output.append(0)
        offset=len(output);output.extend(blob);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(blob)})
        embedded.append({'name':'BrawlerBaked'+name.title(),'bufferView':len(views)-1,'mimeType':'image/png'})
    result={k:copy.deepcopy(source[k]) for k in ('asset','scene','scenes','nodes')}
    result['asset']['generator']='BrickToads Green Brawler SurfaceAppearance-safe bake'
    result.update(meshes=meshes,accessors=accessors,bufferViews=views,buffers=[{'byteLength':len(output)}],images=embedded,
        textures=[{'sampler':0,'source':i} for i in range(3)],samplers=[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],
        materials=[{'name':'BrawlerBakedSurface','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'baseColorTexture':{'index':0},
        'metallicFactor':1,'roughnessFactor':1,'metallicRoughnessTexture':{'index':1}},'normalTexture':{'index':2,'scale':1},
        'occlusionTexture':{'index':1,'strength':.7},'doubleSided':False}])
    encoded=json.dumps(result,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);output+=b'\0'*((-len(output))%4)
    total=12+8+len(encoded)+8+len(output);blob=struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(output),b'BIN\0')+output
    decoded,raw=parse(blob)
    assert triangle_fingerprint(decoded,raw)==geometry_sha,'positions/normals changed'
    assert decoded['nodes']==source['nodes'],'joint transforms changed'
    assert len(blob)<20_000_000
    assert len(meshes)==15 and len(result['materials'])==1
    path.write_bytes(blob)
    report={'status':'PASS','sourceGlbSha256':source_sha,'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),
        'trianglePositionsAndNormalsSha256':geometry_sha,'geometryAndNodeTransformsUnchanged':True,
        'triangles':tile,'nodes':15,'materials':1,'embeddedTextureCount':3,'atlasResolution':[SIZE,SIZE],'tileSize':CELL,
        'vertices':sum(v['vertices'] for v in counts.values()),'parts':counts,'COLOR_0':'omitted',
        'emissiveTexture':'omitted; geometric highlights retained','colorSpace':'macro linear COLOR_0 multiplied by decoded sRGB texture, encoded IEC sRGB into albedo',
        'padding':'each triangle has its own8x8 cell, clamp-barycentric dilation across cell;1.5texel minimum gutter',
        'normalTransfer':'old tangent normal at .55 strength transformed into new triangle UV basis; new normal scale1',
        'actualStudioImport':'PENDING'}
    (HERE/'green-brawler-surface-bake.json').write_text(json.dumps(report,indent=2)+'\n')
    update_metadata(report)
    print(json.dumps(report,indent=2),flush=True)
    return report

def update_metadata(report):
    """Keep authoring topology and actual exported vertex counts distinct."""
    path=HERE/'green-brawler-validation.json'
    if path.exists():
        validation=json.loads(path.read_text());validation.update({k:report[k] for k in ('bytes','sha256','embeddedTextureCount')})
        validation['surfaceBake']=report;validation['exportedVertices']=report['vertices']
        for name,counts in report['parts'].items():
            validation['parts'][name]['authoringVertices']=counts['sourceVertices'];validation['parts'][name]['vertices']=counts['vertices']
        path.write_text(json.dumps(validation,indent=2)+'\n')
    path=HERE/'green-brawler-rig.json'
    if path.exists():
        rig=json.loads(path.read_text())
        rig['atlas']={'resolution':[SIZE,SIZE],'layout':'unique8x8 cell per triangle with dilated gutters',
            'maps':['baked albedo(sRGB macro colour + material grain)','ORM(occlusionR/roughnessG/metalnessB)','normal(OpenGL; transferred into new UV basis)'],
            'allEmbedded':True,'vertexColors':'COLOR_0 intentionally omitted: Roblox SurfaceAppearance discards it',
            'emissive':'no emissive image, texture, factor or mask reference; highlights are geometry',
            'externalMaps':['green-brawler-baked-albedo.png','green-brawler-baked-orm.png','green-brawler-baked-normal.png'],
            'sourceRoleAtlas':'old256x256 maps retained only for authoring/software preview, not used by final GLB'}
        rig['surfaceBake']=report
        for part in rig['parts']:
            counts=report['parts'][part['name']];part['authoringVertices']=counts['sourceVertices'];part['vertices']=counts['vertices']
        path.write_text(json.dumps(rig,indent=2)+'\n')

if __name__=='__main__':bake(HERE/'green-brawler.glb')
