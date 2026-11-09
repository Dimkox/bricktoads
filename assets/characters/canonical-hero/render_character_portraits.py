"""Front three-quarter UI busts rendered from frozen game GLBs, image writes only."""
from __future__ import annotations
import hashlib, importlib.util, json, math
from pathlib import Path

HERE=Path(__file__).resolve().parent
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,HERE/file);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
B=load('surface_reader','bake_green_brawler_surface.py')
G=load('portrait_geometry','build_canonical_hero.py')
WIDTH=HEIGHT=512

def image(path,destination):
    blob=path.read_bytes();scene,binary=B.parse(blob);parents={c:i for i,node in enumerate(scene['nodes']) for c in node.get('children',[])}
    def world(i):
        node=scene['nodes'][i];assert 'rotation' not in node and 'matrix' not in node and 'scale' not in node
        point=tuple(node.get('translation',(0,0,0)))
        return G.add(world(parents[i]),point) if i in parents else point
    texture=None
    if scene.get('images'):
        material=scene['materials'][0];index=material['pbrMetallicRoughness']['baseColorTexture']['index']
        source=scene['textures'][index]['source'];view=scene['bufferViews'][scene['images'][source]['bufferView']]
        texture=B.png_decode(binary[view['byteOffset']:view['byteOffset']+view['byteLength']])
    meshes=[];allowed={'Head','UpperTorso','LeftUpperArm','RightUpperArm'}
    for i,node in enumerate(scene['nodes']):
        if node['name'] not in allowed:continue
        primitive=scene['meshes'][node['mesh']]['primitives'][0]
        arrays={key:B.read_accessor(scene,binary,index) for key,index in primitive['attributes'].items()}
        positions=[G.mul(G.add(v,world(i)),1/.28) for v in arrays['POSITION']]
        meshes.append((node['name'],positions,arrays,B.read_accessor(scene,binary,primitive['indices'])))
    az=math.radians(18);el=math.radians(3)
    camera=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el))
    right=(math.cos(az),0,math.sin(az));up=G.cross(right,camera)
    light=G.unit((-.55,.82,-.75));fill=G.unit((.1,.12,-1));half=G.unit(G.add(light,camera))
    points=[p for _,vs,_,_ in meshes for p in vs];top=max(G.dot(p,up) for p in points)
    scale=126 if texture else 146
    # Head close to the upper edge; crop the outer upper arms as a tight bust.
    cy=42+top*scale;cx=WIDTH/2+12
    pixels=bytearray(WIDTH*HEIGHT*3);depth=[-1e10]*(WIDTH*HEIGHT)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            glow=max(0,1-math.hypot((x-250)/380,(y-200)/480));value=int(17+glow*12)
            pixels[(y*WIDTH+x)*3:(y*WIDTH+x)*3+3]=bytes((value,value+3,value+5))
    srgb=[B.srgb_decode(v/255) for v in range(256)]
    for name,vertices,arrays,indices in meshes:
        projected=[(cx+G.dot(p,right)*scale,cy-G.dot(p,up)*scale,G.dot(p,camera)) for p in vertices]
        normals=arrays['NORMAL'];uv=arrays.get('TEXCOORD_0');color=arrays.get('COLOR_0')
        lit=[.28+.62*max(0,G.dot(n,light))+.20*max(0,G.dot(n,fill)) for n in normals]
        spec=[max(0,G.dot(n,half))**45*.05 for n in normals]
        for i in range(0,len(indices),3):
            ia,ib,ic=indices[i:i+3];p,q,r=(projected[j] for j in (ia,ib,ic))
            area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
            if abs(area)<1e-8:continue
            minx=max(0,int(min(p[0],q[0],r[0])));maxx=min(WIDTH-1,int(max(p[0],q[0],r[0]))+1)
            miny=max(0,int(min(p[1],q[1],r[1])));maxy=min(HEIGHT-1,int(max(p[1],q[1],r[1]))+1)
            for y in range(miny,maxy+1):
                for x in range(minx,maxx+1):
                    a=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area
                    b=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area;c=1-a-b
                    if min(a,b,c)<0:continue
                    z=a*p[2]+b*q[2]+c*r[2];pixel=y*WIDTH+x
                    if z<=depth[pixel]:continue
                    depth[pixel]=z;lum=a*lit[ia]+b*lit[ib]+c*lit[ic];shine=a*spec[ia]+b*spec[ib]+c*spec[ic]
                    if texture:
                        u=a*uv[ia][0]+b*uv[ib][0]+c*uv[ic][0];v=a*uv[ia][1]+b*uv[ib][1]+c*uv[ic][1]
                        tw,th,texels=texture;tx=max(0,min(tw-1,int(u*tw)));ty=max(0,min(th-1,int(v*th)));offset=(ty*tw+tx)*4
                        rgb=[srgb[texels[offset+j]] for j in range(3)]
                    else:rgb=[a*color[ia][j]+b*color[ib][j]+c*color[ic][j] for j in range(3)]
                    pixels[pixel*3:pixel*3+3]=bytes(B.srgb_encode(v*lum+shine) for v in rgb)
    G.png(destination,WIDTH,HEIGHT,pixels)
    return {'file':destination.name,'source':path.name,'sourceSha256':hashlib.sha256(blob).hexdigest(),
        'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'size':[WIDTH,HEIGHT],
        'camera':{'azimuthDegrees':18,'elevationDegrees':3,'forward':'front is-Z'},'sourceMeshNames':sorted(allowed)}

def main():
    frozen={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.glb')}
    assert frozen['green-brawler.glb']=='22c949f45a084f68dd61053cd9e62c2651cb8d351bf124c9eb2a23347a0fe543'
    reports=[image(HERE/'green-brawler.glb',HERE/'green-brawler-portrait.png'),
        image(HERE/'canonical-hero-player2.glb',HERE/'player-two-portrait.png')]
    assert frozen=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.glb')}
    (HERE/'character-portraits.json').write_text(json.dumps({'status':'PASS','sourceGlbsUnchanged':True,'portraits':reports},indent=2)+'\n')
    print(json.dumps(reports,indent=2))

if __name__=='__main__':main()
