"""Bounded3D Tall Walker study from the verified source profile/straight rods.

No knees, filled cockpit or unseen rear machinery is invented. The upper body
is a lightly rounded extrusion of its visible source profile, including holes.
The five visual nodes remain external to all gameplay/physical bodies.
"""
from __future__ import annotations

import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys
import zlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
REF=ROOT/'research/canonical-visuals'
METRES_PER_STUD=.28
PIN='f1a43b69577246850d136473700a333b3cdfe93f'


def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result


HERO=module(HERE.parent/'canonical-hero/build_canonical_hero.py','hero_geometry_helpers')
Mesh=HERO.Mesh
add,sub,mul,dot,cross,unit,length=HERO.add,HERO.sub,HERO.mul,HERO.dot,HERO.cross,HERO.unit,HERO.length
HERO_HEIGHT=json.loads((HERE.parent/'canonical-hero/canonical-hero-rig.json').read_text())['units']['desiredRobloxStuds']['height']
PIXEL=HERO_HEIGHT/33
GROUND=-3.


def linear(rgb):
    def one(byte):
        value=byte/255
        return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
    return tuple(one(v) for v in rgb)+(1.,)


def source_rgb():
    tree=ast.parse((REF/'extract_source_frames.py').read_text())
    fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='rgba')
    scope={};exec(compile(ast.Module(body=[fn],type_ignores=[]),'source_rgba','exec'),scope)
    return scope['rgba']


RGB=source_rgb()
DARK,YELLOW,WHITE=[linear(RGB(code)[:3]) for code in (0x18,0x28,0x20)]


def read_png(path):
    payload=path.read_bytes();assert payload[:8]==b'\x89PNG\r\n\x1a\n'
    offset=8;compressed=b''
    while offset<len(payload):
        size=struct.unpack_from('>I',payload,offset)[0];kind=payload[offset+4:offset+8]
        data=payload[offset+8:offset+8+size];offset+=size+12
        if kind==b'IHDR':
            width,height,depth,color,*_=struct.unpack('>IIBBBBB',data)
            assert depth==8 and color==6,'Reference must be8bitRGBA'
        if kind==b'IDAT':compressed+=data
    decoded=zlib.decompress(compressed);rows=[];prior=bytes(width*4);stride=width*4
    for y in range(height):
        kind=decoded[y*(stride+1)];row=bytearray(decoded[y*(stride+1)+1:(y+1)*(stride+1)])
        for x in range(stride):
            a=row[x-4] if x>=4 else 0;b=prior[x];c=prior[x-4] if x>=4 else 0
            if kind==1:row[x]=(row[x]+a)&255
            elif kind==2:row[x]=(row[x]+b)&255
            elif kind==3:row[x]=(row[x]+((a+b)//2))&255
            elif kind==4:
                p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                row[x]=(row[x]+(a if pa<=pb and pa<=pc else b if pb<=pc else c))&255
            else:assert kind==0
        rows.append([tuple(row[x*4:x*4+4]) for x in range(width)]);prior=row
    return rows


class Profile:
    def __init__(self,pixels):
        self.pixels=pixels
        self.opaque={(x,y):c for y,row in enumerate(pixels) for x,c in enumerate(row) if c[3]}
        self.minx=min(x for x,y in self.opaque)-.5;self.maxx=max(x for x,y in self.opaque)+.5
        self.miny=min(y for x,y in self.opaque)-.5;self.maxy=max(y for x,y in self.opaque)+.5
        self.edges=[]
        for x,y in self.opaque:
            if (x-1,y) not in self.opaque:self.edges.append((0,x-.5,y-.5,y+.5))
            if (x+1,y) not in self.opaque:self.edges.append((0,x+.5,y-.5,y+.5))
            if (x,y-1) not in self.opaque:self.edges.append((1,y-.5,x-.5,x+.5))
            if (x,y+1) not in self.opaque:self.edges.append((1,y+.5,x-.5,x+.5))

    def distance(self,x,y):
        distance=math.inf
        for axis,coordinate,a,b in self.edges:
            normal=x if axis==0 else y;tangent=y if axis==0 else x
            squared=(normal-coordinate)**2+max(a-tangent,0,tangent-b)**2
            distance=min(distance,squared)
        signed=-math.sqrt(distance) if (math.floor(x+.5),math.floor(y+.5)) in self.opaque else math.sqrt(distance)
        # A tenth-pixel bridge connects source diagonal metal pixels. The exact
        # outer source box is retained, rather than adding unseen body volume.
        return max(signed-.10,self.minx-x,x-self.maxx,self.miny-y,y-self.maxy)

    def color(self,x,y):
        pixel=self.opaque.get((math.floor(x+.5),math.floor(y+.5)))
        if not pixel:pixel=min(self.opaque.items(),key=lambda item:(item[0][0]-x)**2+(item[0][1]-y)**2)[1]
        return linear(pixel[:3])

    def enclosed_pixels(self):
        width,height=len(self.pixels[0]),len(self.pixels)
        clear={(x,y) for y,row in enumerate(self.pixels) for x,c in enumerate(row) if not c[3]}
        seen=set();stack=[p for p in clear if p[0] in (0,width-1) or p[1] in (0,height-1)]
        while stack:
            x,y=stack.pop()
            if (x,y) in seen:continue
            seen.add((x,y))
            stack.extend(p for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)) if p in clear and p not in seen)
        return clear-seen


def extrude(name,profile,depth_studs,project):
    """Marching tetrahedra of a rounded profile extrusion, preserving holes."""
    mesh=Mesh(name);depth=depth_studs/PIXEL;bevel=.25;step=.65
    def sdf(x,y,z):
        a=profile.distance(x,y)+bevel;b=abs(z)-depth/2+bevel
        return min(max(a,b),0)+math.hypot(max(a,0),max(b,0))-bevel
    def samples(a,b):
        # Offset from exact pixel edges avoids zero-area isosurface ties.
        count=math.ceil((b-a)/step)
        return [a+(b-a)*i/count for i in range(count+1)]
    xs=samples(profile.minx-.63,profile.maxx+.61)
    ys=samples(profile.miny-.63,profile.maxy+.61)
    zs=samples(-depth/2-.63,depth/2+.61)
    nx,ny,nz=len(xs),len(ys),len(zs)
    positions=[];values=[]
    # The2D signed field is reused across every depth slice.
    field={(ix,iy):profile.distance(x,y) for iy,y in enumerate(ys) for ix,x in enumerate(xs)}
    for z in zs:
        for iy,y in enumerate(ys):
            for ix,x in enumerate(xs):
                a=field[ix,iy]+bevel;b=abs(z)-depth/2+bevel
                positions.append((x,y,z));values.append(min(max(a,b),0)+math.hypot(max(a,0),max(b,0))-bevel)
    cache={}
    def crossing(a,b):
        key=tuple(sorted((a,b)))
        if key in cache:return cache[key]
        fraction=values[a]/(values[a]-values[b])
        point=add(positions[a],mul(sub(positions[b],positions[a]),fraction))
        index=len(mesh.vertices);mesh.vertices.append(project(point));mesh.colors.append(profile.color(point[0],point[1]));cache[key]=index
        return index
    def face(ids,out):
        a,b,c=(mesh.vertices[i] for i in ids)
        normal=cross(sub(b,a),sub(c,a))
        if length(normal)<1e-10:return
        if dot(normal,out)<0:ids=(ids[0],ids[2],ids[1])
        mesh.faces.append(ids)
    tetrahedra=((0,5,1,6),(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6))
    for iz in range(nz-1):
        for iy in range(ny-1):
            for ix in range(nx-1):
                p=(iz*ny+iy)*nx+ix
                corners=(p,p+1,p+nx+1,p+nx,p+nx*ny,p+nx*ny+1,p+nx*ny+nx+1,p+nx*ny+nx)
                if all(values[c]>0 for c in corners) or all(values[c]<0 for c in corners):continue
                for tet in tetrahedra:
                    inside=[corners[k] for k in tet if values[corners[k]]<0]
                    outside=[corners[k] for k in tet if values[corners[k]]>=0]
                    if not inside or not outside:continue
                    center_in=mul(tuple(sum(positions[k][a] for k in inside) for a in range(3)),1/len(inside))
                    center_out=mul(tuple(sum(positions[k][a] for k in outside) for a in range(3)),1/len(outside))
                    direction=sub(project(center_out),project(center_in))
                    if len(inside)==1:
                        face(tuple(crossing(inside[0],b) for b in outside),direction)
                    elif len(inside)==3:
                        face(tuple(crossing(a,outside[0]) for a in inside),direction)
                    else:
                        a,b=inside;c,d=outside
                        p,q,r,s=crossing(a,c),crossing(a,d),crossing(b,c),crossing(b,d)
                        face((p,q,r),direction);face((q,s,r),direction)
    assert len(mesh.faces)<20000,(name,len(mesh.faces))
    return mesh


def foot_pixels():
    # Decode the verified terminal tileD3 from exactly the same pinned public
    # source blocks as the independently checked reference renderer.
    sys.path.insert(0,str(REF))
    from extract_source_frames import CACHE,unpack4
    prefix=b''.join((CACHE/'gfx'/n).read_bytes() for n in ('sprite0.chr','game_std.chr','level1_obj.4'))
    static=prefix[:33*16]+(CACHE/'gfx/game_std.chr').read_bytes()+unpack4(CACHE/'gfx/level1_obj.4',131)+unpack4(CACHE/'gfx/levels1_5_obj.4',35)+unpack4(CACHE/'gfx/tall_walker.4',10)
    tile=static[0xd3*16:0xd4*16];palette=[0x0f,0x18,0x28,0x20]
    return [[RGB(palette[code]) if code else (0,0,0,0)
             for x in range(8) for code in [((tile[y]>>x)&1)|(((tile[y+8]>>x)&1)<<1)]] for y in range(8)]


def geometry():
    catalog=json.loads((REF/'tall-walker-procedural-leg-catalog.json').read_text())
    idle=catalog['frames'][0]
    body_pixels=read_png(REF/'frames/object-19.png')
    body_profile=Profile(body_pixels)
    anchor_x=.5*PIXEL
    body_pivot=(0,(4.5-idle['headAnchor']['y'])*PIXEL+GROUND,0)
    # Source-profile X/Y are preserved. Z is explicitly inferred shallow depth.
    body=extrude('UpperBody',body_profile,.76,lambda p:((p[0]-9)*PIXEL,(4.5-(-84+p[1]))*PIXEL+GROUND,p[2]*PIXEL))
    foot_profile=Profile(foot_pixels())
    foot_top=5*PIXEL+GROUND
    top=63*PIXEL+GROUND
    meshes={'UpperBody':body};pivots={'UpperBody':body_pivot};nodes={};rig=[]
    for side,z in (('Left',-.18),('Right',.18)):
        foot=extrude(side+'Foot',foot_profile,.90,lambda p:((p[0]-3)*PIXEL,(4.5-p[1])*PIXEL+GROUND,p[2]*PIXEL+z))
        foot_pivot=(anchor_x,foot_top,z)
        rod=Mesh(side+'Strut')
        radius=1.8*PIXEL
        controls=[]
        for i in range(15):
            y=foot_top+(top-foot_top)*i/14
            controls.append((anchor_x,y,z,radius,.15))
        HERO.sweep(rod,controls,YELLOW,radial=16,steps=1)
        # The source shaft has a dark/yellow/white longitudinal stripe. No knee,
        # collar machinery or independent8-bone leg is introduced.
        for i,point in enumerate(rod.vertices):
            x=(point[0]-anchor_x)/radius;front=point[2]-z
            rod.colors[i]=WHITE if front<0 and .0<x<.75 else DARK if abs(x)>.80 else YELLOW
        meshes[side+'Strut']=rod;meshes[side+'Foot']=foot
        pivots[side+'Strut']=(anchor_x,(top+foot_top)/2,z);pivots[side+'Foot']=foot_pivot
        rig.append({'name':side,'strut':side+'Strut','foot':side+'Foot',
            'bodyAttachment':(anchor_x,top,z),'bodyAttachmentRelativeToUpperBodyPivot':sub((anchor_x,top,z),body_pivot),
            'footAttachment':foot_pivot,'rodLength':top-foot_top,'rodAxis':[0,1,0],
            'spriteSegments':8,'shaftSprites':7,'terminalFootSprites':1,'sourceTilePeriodPixels':8,
            'depthLayerStuds':z,'physicalKnee':False})
    return meshes,pivots,rig,catalog,body_profile


def glb(meshes,pivots,path):
    data=bytearray();views=[];accessors=[];nodes=[];definitions=[]
    def acc(values,kind,ctype,target=34962,minimum=None,maximum=None):
        while len(data)%4:data.append(0)
        offset=len(data);flat=[x for row in values for x in row] if isinstance(values[0],(tuple,list)) else values
        data.extend(struct.pack('<'+str(len(flat))+('f' if ctype==5126 else 'H'),*flat))
        view=len(views);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':target})
        item={'bufferView':view,'componentType':ctype,'count':len(values),'type':kind}
        if minimum is not None:item.update(min=minimum,max=maximum)
        accessors.append(item);return len(accessors)-1
    for index,(name,mesh) in enumerate(meshes.items()):
        local=[mul(sub(v,pivots[name]),METRES_PER_STUD) for v in mesh.vertices];b=HERO.bounds(local)
        attrs={'POSITION':acc(local,'VEC3',5126,minimum=b[0],maximum=b[1]),
            'NORMAL':acc(mesh.normals(),'VEC3',5126),'COLOR_0':acc(mesh.colors,'VEC4',5126)}
        indices=acc([i for f in mesh.faces for i in f],'SCALAR',5123,34963)
        definitions.append({'name':name,'primitives':[{'attributes':attrs,'indices':indices,'material':0}]})
        nodes.append({'name':name,'mesh':index,'translation':mul(pivots[name],METRES_PER_STUD)})
    scene={'asset':{'version':'2.0','generator':'BrickToads source-profile Tall Walker study',
            'extras':{'metresPerStud':METRES_PER_STUD,'sourcePin':PIN}},
        'scene':0,'scenes':[{'name':'TallWalkerStudy','nodes':list(range(len(nodes)))}],
        'nodes':nodes,'meshes':definitions,'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(data)}],
        'materials':[{'name':'SourceOliveGoldWhite','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],
            'metallicFactor':.25,'roughnessFactor':.62},'doubleSided':False}]}
    encoded=json.dumps(scene,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    total=12+8+len(encoded)+8+len(data)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data)
    return scene


def pose(meshes,pivots,rig,spread_pixels):
    result={};body_shift=(0,-2*PIXEL if spread_pixels else 0,0)
    body=Mesh('UpperBody');body.vertices=[add(v,body_shift) for v in meshes['UpperBody'].vertices];body.colors=list(meshes['UpperBody'].colors);body.faces=list(meshes['UpperBody'].faces);result['UpperBody']=body
    errors=[]
    for i,row in enumerate(rig):
        side=row['name'];delta=(1 if i==0 else -1)*spread_pixels*PIXEL
        top=add(row['bodyAttachment'],body_shift);bottom=add(row['footAttachment'],(delta,0,0))
        axis=unit(sub(top,bottom));right=unit(cross(axis,(0,0,1)));other=cross(right,axis)
        old_center=pivots[side+'Strut'];new_center=mul(add(top,bottom),.5);new_length=length(sub(top,bottom))
        original=meshes[side+'Strut'];rod=Mesh(side+'Strut')
        for vertex in original.vertices:
            local=sub(vertex,old_center)
            rod.vertices.append(add(new_center,add(mul(axis,local[1]*new_length/row['rodLength']),add(mul(right,local[0]),mul(other,local[2])))))
        rod.faces=list(original.faces);rod.colors=list(original.colors);result[rod.name]=rod
        foot=Mesh(side+'Foot');original=meshes[foot.name]
        foot.vertices=[add(v,(delta,0,0)) for v in original.vertices];foot.faces=list(original.faces);foot.colors=list(original.colors);result[foot.name]=foot
        for t in (0,.25,.5,.75,1):
            center=add(new_center,mul(axis,(t-.5)*new_length))
            line=add(bottom,mul(sub(top,bottom),t));errors.append(length(sub(center,line)))
    return result,max(errors)


def render(meshes,path,closeup=False):
    width,height,panel=1440,900,480;pixels=bytearray((23,31,34)*(width*height));depth=[-1e10]*(width*height)
    b=HERO.bounds([v for m in meshes.values() for v in m.vertices]);target=((b[0][0]+b[1][0])/2,(b[0][1]+b[1][1])/2,0)
    scale=(height-90)/(b[1][1]-b[0][1]);light=unit((-.6,.8,-.8))
    vertices=[v for m in meshes.values() for v in m.vertices]
    for angle in (0,35,90):
        right=(math.cos(math.radians(angle)),0,math.sin(math.radians(angle)))
        values=[dot(v,right) for v in vertices]
        scale=min(scale,(panel-60)/max(1e-9,max(values)-min(values)))
    def display(value):
        value=max(0,min(1,value));s=12.92*value if value<=.0031308 else 1.055*value**(1/2.4)-.055
        return min(255,max(0,int(s*255)))
    for pi,azimuth in enumerate((0,35,90)):
        az=math.radians(azimuth);el=math.radians(4)
        d=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el));right=(math.cos(az),0,math.sin(az));up=cross(right,d)
        cx=pi*panel+panel/2;cy=height/2+4
        for mesh in meshes.values():
            positions=[];colors=[]
            for vertex,normal,color in zip(mesh.vertices,mesh.normals(),mesh.colors):
                point=sub(vertex,target);x,y,z=dot(point,right),dot(point,up),dot(point,d)
                positions.append((cx+x*scale,cy-y*scale,z));lum=.38+.62*max(0,dot(normal,light));colors.append(tuple(display(c*lum) for c in color[:3]))
            for a,b,c in mesh.faces:
                p,q,r=positions[a],positions[b],positions[c];area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-7:continue
                minx=max(pi*panel,int(min(p[0],q[0],r[0])));maxx=min((pi+1)*panel-1,int(max(p[0],q[0],r[0]))+1)
                miny=max(0,int(min(p[1],q[1],r[1])));maxy=min(height-1,int(max(p[1],q[1],r[1]))+1)
                for y in range(miny,maxy+1):
                    for x in range(minx,maxx+1):
                        u=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area
                        v=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area;w=1-u-v
                        if min(u,v,w)<0:continue
                        z=u*p[2]+v*q[2]+w*r[2];index=y*width+x
                        if z<=depth[index]:continue
                        depth[index]=z
                        for channel in range(3):pixels[index*3+channel]=int(u*colors[a][channel]+v*colors[b][channel]+w*colors[c][channel])
    HERO.png(path,width,height,pixels)


def validate(meshes,scene,path,body_profile):
    report={'status':'PASS','meshes':{},'nodeCount':len(scene['nodes'])}
    assert set(meshes)=={'UpperBody','LeftStrut','RightStrut','LeftFoot','RightFoot'}
    for name,mesh in meshes.items():
        assert mesh.faces and len(mesh.faces)<20000 and len(mesh.vertices)<65536
        assert len(mesh.vertices)==len(mesh.colors)
        assert all(math.isfinite(v) for p in mesh.vertices for v in p)
        edge_counts={};neighbors=[set() for _ in mesh.vertices]
        for f in mesh.faces:
            assert min(f)>=0 and max(f)<len(mesh.vertices)
            a,b,c=(mesh.vertices[i] for i in f)
            assert length(cross(sub(b,a),sub(c,a)))>1e-12
            for u,v in zip(f,(f[1],f[2],f[0])):
                key=tuple(sorted((u,v)));edge_counts[key]=edge_counts.get(key,0)+1
                neighbors[u].add(v);neighbors[v].add(u)
        assert all(abs(length(n)-1)<1e-5 for n in mesh.normals())
        assert all(count==2 for count in edge_counts.values()),name
        components=0;remaining=set(range(len(mesh.vertices)))
        while remaining:
            components+=1;stack=[next(iter(remaining))]
            while stack:
                u=stack.pop()
                if u not in remaining:continue
                remaining.remove(u);stack.extend(neighbors[u]&remaining)
        assert components==1,name
        report['meshes'][name]={'vertices':len(mesh.vertices),'triangles':len(mesh.faces),'boundsStuds':HERO.bounds(mesh.vertices),
            'closedManifoldEdges':True,'connectedComponents':components,
            'eulerCharacteristic':len(mesh.vertices)-len(edge_counts)+len(mesh.faces)}
    blob=path.read_bytes();magic,version,size=struct.unpack_from('<4sII',blob)
    assert magic==b'glTF' and version==2 and size==len(blob)
    json_length=struct.unpack_from('<I',blob,12)[0];decoded=json.loads(blob[20:20+json_length]);binary=28+json_length
    actual=[]
    for node in decoded['nodes']:
        accessor=decoded['accessors'][decoded['meshes'][node['mesh']]['primitives'][0]['attributes']['POSITION']]
        view=decoded['bufferViews'][accessor['bufferView']];start=binary+view.get('byteOffset',0)+accessor.get('byteOffset',0)
        for i in range(accessor['count']):actual.append(add(tuple(node['translation']),struct.unpack_from('<fff',blob,start+i*12)))
    decoded_bounds=HERO.bounds(actual)
    expected=[mul(v,METRES_PER_STUD) for v in HERO.bounds([v for m in meshes.values() for v in m.vertices])]
    error=max(abs(a-b) for row,want in zip(decoded_bounds,expected) for a,b in zip(row,want));assert error<1e-5
    report.update(bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest(),boundsStuds=HERO.bounds([v for m in meshes.values() for v in m.vertices]))
    report['heightStuds']=report['boundsStuds'][1][1]-report['boundsStuds'][0][1]
    report['heightMetres']=report['heightStuds']*METRES_PER_STUD
    report['decodedGlbBoundsMetres']=decoded_bounds;report['metreConversionMaximumError']=error
    # A known source upper-body opening must remain empty in the actual mesh.
    def ray_intersections(x,y):
        count=0
        for face in meshes['UpperBody'].faces:
            a,b,c=(meshes['UpperBody'].vertices[i] for i in face)
            area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
            if abs(area)<1e-10:continue
            u=((b[0]-x)*(c[1]-y)-(b[1]-y)*(c[0]-x))/area
            v=((c[0]-x)*(a[1]-y)-(c[1]-y)*(a[0]-x))/area;w=1-u-v
            if min(u,v,w)>1e-7:count+=1
        return count
    candidates=[]
    for x,y in sorted(body_profile.enclosed_pixels(),key=lambda p:(p[1],p[0])):
        if body_profile.distance(x,y)>.35:
            world=((x-9)*PIXEL,(4.5-(-84+y))*PIXEL+GROUND)
            if ray_intersections(*world)==0:candidates.append({'sourceImageXY':[x,y],'meshRayHits':0})
    assert candidates,'Source opening was filled'
    report['sourceUpperOpeningProbe']=candidates[0]
    return report


def main():
    immutable={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE.parent/'canonical-hero').glob('*.glb')}
    meshes,pivots,rig,catalog,profile=geometry()
    path=HERE/'tall-walker.glb';scene=glb(meshes,pivots,path)
    report=validate(meshes,scene,path,profile)
    spread,error=pose(meshes,pivots,rig,24);report['spreadStraightCenterlineErrorStuds']=error;assert error<1e-10
    render(meshes,HERE/'turntable.png');render(spread,HERE/'source-spread-preview.png');render({'UpperBody':meshes['UpperBody']},HERE/'upperbody-closeup.png',True)
    data={'schema':1,'status':'source-profile3d-study-not-release-approved','sourcePin':PIN,
        'sourceReferences':['research/canonical-visuals/tall-walker-procedural-leg-reference.png','research/canonical-visuals/tall-walker-procedural-leg-catalog.json','research/canonical-visuals/tall-walker-source-verification.json'],
        'sourceFacts':{'type':17,'upperBodyGraphicsId':25,'upperBodyVisiblePixels':[13,27],
            'neutralFullPixels':[14,89],'heroIdlePixels':[24,33],'sourceLegSegments':8,'shaftSpritesPerLeg':7,'terminalFootSpritesPerLeg':1,
            'palettes':['0F','18','28','20'],'paletteRgbApproximation':[RGB(code)[:3] for code in (0x0f,0x18,0x28,0x20)],
            'sourceCaseCount':len(catalog['frames']),'sourceNeutral':catalog['frames'][0]},
        'units':{'authoring':'Roblox studs','glb':'metres','metresPerStud':METRES_PER_STUD,'studsPerSourcePixel':PIXEL,
            'referenceHeroHeightStuds':HERO_HEIGHT,'sourceTargetHeightStuds':89*PIXEL,'actualHeightStuds':report['heightStuds'],
            'rootReference':'existing R6 Torso origin, ground at localY−3','up':[0,1,0],
            'profileHorizontal':[1,0,0],'profileVertical':[0,1,0],'depthAxis':[0,0,1],
            'facing':'source renderer prepared facing-right; source horizontal mapped+X. Rotate visual for gameplay forward as required.'},
        'adaptations':{'depth':'Upper-body.76stud and foot.90stud shallow extrusion; unseen cockpit/back machinery is not invented',
            'rounding':'quarter-pixel edge bevel with.10pixel diagonal metal bridge, constrained to original outerprofilebox',
            'bodyMaterial':'metallic.25/roughness.62 is artistic3D calibration, not source material data',
            'feet':'both rest on one3D plane; source2pixel backleg vertical layer offset is preserved in sourceNeutral but not treated as a physical floating foot',
            'attachments':'common tops overlap the source lower-body tail to keep3D rods connected; source rawstartpoints remain recorded',
            'poses':'source24/-24pixel spread and2pixel body bob are prepared illustration, not complete source gait/attack timing'},
        'nodes':[{'name':n,'pivotStuds':pivots[n],'triangles':len(m.faces),'vertices':len(m.vertices)}for n,m in meshes.items()],
        'legs':rig,
        'runtimeContract':{'noKnees':True,'rodMotion':'one continuous straight strut between bodyAttachment and independent footAttachment',
            'rodFrame':'CFrame with local+Y along(normalized top−bottom), centred at(top+bottom)/2; Ysize=distance',
            'footMotion':'translate independent foot to endpoint without rotating a fictional shin/knee',
            'physics':'all5nodes cosmetic/massless/noCollide/noTouch/noQuery; no Humanoid or health state',
            'ownership':'pin completed existing physical body to server after attaching visual parts'},
        'preservedHeroGlbs':immutable,'validation':'validation.json','studioImport':'NOT_RUN','canonicalAnimation':'NOT_IMPLEMENTED'}
    (HERE/'rig.json').write_text(json.dumps(data,indent=2)+'\n')
    (HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    assert immutable=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE.parent/'canonical-hero').glob('*.glb')}
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
