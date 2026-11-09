"""Source-ROI derived, independently attachable 3D attack morphs; no avatar writes."""
from __future__ import annotations
import hashlib, importlib.util, json, math, struct, zlib
from pathlib import Path

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];METRES=.28
def module(name,file):
    s=importlib.util.spec_from_file_location(name,HERE/file);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
H=module('morph_geometry','build_green_brawler.py');G=H.G;B=module('morph_glb','bake_green_brawler_surface.py')
SOURCE=ROOT/'research/canonical-visuals';CATALOG=json.loads((SOURCE/'hero-frame-catalog.json').read_text())
PIXEL=6.074600064717276/33
CONFIG={
    'PowerFist':{'frame':'1C','roi':[22,35,-19,-4],'anchor':[22,-9],'halfDepth':.68,'bevel':.39},
    'BigBoot':{'frame':'1E','roi':[8,30,-36,-15],'anchor':[13,-17],'halfDepth':.53,'bevel':.32},
}
PALETTES={'Green':{(18,19,20):H.linear((.012,.045,.016)),(0,102,0):H.FOREST,(88,184,44):H.GRASS},
    'PlayerTwo':{(18,19,20):H.linear(tuple(v/255 for v in (18,19,20))),
        (0,102,0):H.linear(tuple(v/255 for v in (155,83,0))),
        (88,184,44):H.linear(tuple(v/255 for v in (250,160,66)))}}
LAYOUT={'GreenPowerFist':[-6,0,0],'GreenBigBoot':[-2,0,0],'PlayerTwoPowerFist':[2,0,0],'PlayerTwoBigBoot':[6,0,0]}

class Mesh(G.Mesh):
    def __init__(self,name):super().__init__(name);self.analytic={};self._normals=None
    def normals(self):
        if self._normals is None:
            self._normals=super().normals()
            for i,n in self.analytic.items():self._normals[i]=n
        return self._normals

def weld_numerical_slivers(mesh,epsilon=.0001):
    """Collapse sub-0.1mm authoring slivers before float32 serialization."""
    buckets={};parent=list(range(len(mesh.vertices)))
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for i,p in enumerate(mesh.vertices):
        key=tuple(math.floor(v/epsilon) for v in p)
        for dx in (-1,0,1):
            for dy in (-1,0,1):
                for dz in (-1,0,1):
                    for j in buckets.get((key[0]+dx,key[1]+dy,key[2]+dz),[]):
                        if sum((a-b)**2 for a,b in zip(p,mesh.vertices[j]))<epsilon*epsilon:parent[root(i)]=root(j)
        buckets.setdefault(key,[]).append(i)
    groups={}
    for i in range(len(parent)):groups.setdefault(root(i),[]).append(i)
    index={r:i for i,r in enumerate(groups)};remap={i:index[root(i)] for i in range(len(parent))}
    mesh.vertices=[tuple(sum(mesh.vertices[i][j] for i in group)/len(group) for j in range(3)) for group in groups.values()]
    mesh.analytic={index[r]:G.unit(tuple(sum(mesh.analytic[i][j] for i in group) for j in range(3))) for r,group in groups.items()}
    mesh.faces=list(dict.fromkeys(tuple(remap[i] for i in f) for f in mesh.faces if len({remap[i] for i in f})==3));mesh._normals=None

def profile(kind):
    cfg=CONFIG[kind];fid=cfg['frame'];frame=next(f for f in CATALOG['frames'] if f['frameHex']==fid)
    w,h,pixels=B.png_decode((SOURCE/'frames'/f'hero-{fid.lower()}.png').read_bytes());bb=frame['visibleBounds'];x0,x1,y0,y1=cfg['roi']
    mask={};rgb={}
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            p=((y-bb['minY'])*w+x-bb['minX'])*4
            if pixels[p+3] and not(kind=='BigBoot' and y>=-23 and x<12):mask[x,y]=True;rgb[x,y]=tuple(pixels[p:p+3])
    # Keep the single largest four-connected limb region, excluding any body
    # fragments introduced by the semantic crop (not a source skeleton).
    remaining=set(mask);groups=[]
    while remaining:
        start=remaining.pop();group={start};stack=[start]
        while stack:
            x,y=stack.pop()
            for q in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if q in remaining:remaining.remove(q);group.add(q);stack.append(q)
        groups.append(group)
    mask=max(groups,key=len);rgb={p:rgb[p] for p in mask}
    edges={}
    for x,y in mask:
        for neighbor,a,b in (((x,y-1),(x,y),(x+1,y)),((x+1,y),(x+1,y),(x+1,y+1)),
            ((x,y+1),(x+1,y+1),(x,y+1)),((x-1,y),(x,y+1),(x,y))):
            if neighbor not in mask:edges.setdefault(a,[]).append(b)
    loops=[]
    while edges:
        start=min(edges);p=start;loop=[]
        while True:
            loop.append(p);q=edges[p].pop()
            if not edges[p]:del edges[p]
            p=q
            if p==start:break
        loops.append(loop)
    def area(loop):return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(loop,loop[1:]+loop[:1])))
    loop=max(loops,key=area)
    # Remove only collinear pixel-boundary points, then round corners by one
    # Chaikin pass. This is a bounded smooth 3D interpretation of the silhouette.
    loop=[p for i,p in enumerate(loop) if G.cross((p[0]-loop[i-1][0],p[1]-loop[i-1][1],0),
        (loop[(i+1)%len(loop)][0]-p[0],loop[(i+1)%len(loop)][1]-p[1],0))[2]!=0]
    smooth=[]
    for a,b in zip(loop,loop[1:]+loop[:1]):smooth.extend(((a[0]*.75+b[0]*.25,a[1]*.75+b[1]*.25),(a[0]*.25+b[0]*.75,a[1]*.25+b[1]*.75)))
    ax,ay=cfg['anchor'];polygon=[(-(x-ax)*PIXEL,(y-ay)*PIXEL) for x,y in smooth]
    segments=[]
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        d=(b[0]-a[0],b[1]-a[1]);segments.append((a,d,d[0]*d[0]+d[1]*d[1]))
    cache={}
    def sdf2(y,z):
        key=(y,z)
        if key in cache:return cache[key]
        best=1e10;inside=False
        for a,d,denom in segments:
            t=max(0,min(1,((y-a[0])*d[0]+(z-a[1])*d[1])/denom))
            best=min(best,(y-a[0]-d[0]*t)**2+(z-a[1]-d[1]*t)**2)
            b=(a[0]+d[0],a[1]+d[1])
            if (a[1]>z)!=(b[1]>z) and y<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:inside=not inside
        value=math.sqrt(best)*(-1 if inside else 1);cache[key]=value;return value
    def field(p):
        x,y,z=p;d=sdf2(y,z);r=cfg['bevel'];h=cfg['halfDepth']
        # Inflated closed volume with the measured source contour at X=0;
        # thickness and the rounded depth profile are explicitly inferred.
        return math.hypot(max(0,d+r),x*r/h)-r
    def color(p,palette):
        x,y,z=p;sx=ax-y/PIXEL;sy=ay+z/PIXEL
        # Smooth resampling of the source's own pixel regions, rather than
        # interpolating UVs across unrelated material-role atlas cells.
        fx=sx-.5;fy=sy-.5;ix=math.floor(fx);iy=math.floor(fy);tx=fx-ix;ty=fy-iy
        result=[0.,0.,0.];weight=0
        for xx,yy,wgt in ((ix,iy,(1-tx)*(1-ty)),(ix+1,iy,tx*(1-ty)),(ix,iy+1,(1-tx)*ty),(ix+1,iy+1,tx*ty)):
            if (xx,yy) in rgb:
                c=PALETTES[palette][rgb[xx,yy]]
                for i in range(3):result[i]+=c[i]*wgt
                weight+=wgt
        if weight<1e-8:
            nearest=min(mask,key=lambda q:(q[0]+.5-sx)**2+(q[1]+.5-sy)**2);return PALETTES[palette][rgb[nearest]]
        return tuple(v/weight for v in result)+(1.,)
    return cfg,frame,mask,polygon,field,color

def build():
    result={};references={}
    for kind in CONFIG:
        cfg,frame,mask,polygon,field,color=profile(kind)
        ys=[p[0] for p in polygon];zs=[p[1] for p in polygon];pad=.10
        mesh=Mesh(kind);H.implicit(mesh,field,((-cfg['halfDepth']-.1,cfg['halfDepth']+.1),
            (min(ys)-pad,max(ys)+pad),(min(zs)-pad,max(zs)+pad)),.14 if kind=='BigBoot' else .12)
        weld_numerical_slivers(mesh)
        components=H.orient(mesh);assert components==1,(kind,components)
        assert len(mesh.faces)<20000,(kind,len(mesh.faces))
        coverage=set();ax,ay=cfg['anchor']
        projected=[(ax-p[1]/PIXEL,ay+p[2]/PIXEL) for p in mesh.vertices]
        for face in mesh.faces:
            p,q,r=(projected[i] for i in face);area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
            if abs(area)<1e-10:continue
            for yy in range(math.floor(min(p[1],q[1],r[1])),math.ceil(max(p[1],q[1],r[1]))+1):
                for xx in range(math.floor(min(p[0],q[0],r[0])),math.ceil(max(p[0],q[0],r[0]))+1):
                    a=((q[0]-xx-.5)*(r[1]-yy-.5)-(q[1]-yy-.5)*(r[0]-xx-.5))/area
                    b=((r[0]-xx-.5)*(p[1]-yy-.5)-(r[1]-yy-.5)*(p[0]-xx-.5))/area
                    if min(a,b,1-a-b)>=-1e-9:coverage.add((xx,yy))
        iou=len(coverage&mask)/len(coverage|mask);assert iou>.9,(kind,iou)
        for palette in PALETTES:
            name=palette+kind;q=Mesh(name);q.vertices=list(mesh.vertices);q.faces=list(mesh.faces);q.analytic=dict(mesh.analytic)
            q.colors=[color(p,palette) for p in q.vertices];result[name]=q
        references[kind]={'frameHex':cfg['frame'],'graphicsLabel':frame['graphicsLabel'],'metaspriteAddress':frame['metaspriteAddress'],
            'fullFrameBoundsPixels':frame['visibleBounds'],'semanticRoiInclusivePixels':cfg['roi'],'attachmentSourcePixelInferred':cfg['anchor'],
            'opaqueSelectedPixels':len(mask),'opaqueSelectedBoundsPixels':[[min(p[i] for p in mask) for i in range(2)],[max(p[i] for p in mask) for i in range(2)]],
            'semanticMaskCut':'BigBoot excludes x<12 when y>=-23 to remove overlapping body fragment' if kind=='BigBoot' else 'largest4connectedcomponent only',
            'contourSmoothing':'one Chaikin pass, source pixel boundary corners rounded within0.25pixel',
            'depthInferredStuds':cfg['halfDepth']*2,'roundedDepthBevelStuds':cfg['bevel'],
            'sourceToRestAxes':{'source+X':'local-Y','source+Y':'local+Z','inferredDepth':'local±X'},
            'sourcePixelStuds':PIXEL,'attachmentWarning':'no skeletal wrist/ankle exists in metasprite; origin and rest orientation are authored adaptations'}
        references[kind]['projectedMeshPixelCentreIoU']=iou
        references[kind]['projectedMeshOpaquePixels']=len(coverage)
    return result,references

def preview(meshes,path):
    width,height=1200,760;pixels=bytearray((20,26,28))*(width*height);depth=[-1e10]*(width*height)
    light=G.unit((-.65,.75,-.7));az=math.radians(48);el=math.radians(8)
    camera=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el));right=(math.cos(az),0,math.sin(az));up=G.cross(right,camera)
    for index,(name,m) in enumerate(meshes.items()):
        col=index%2;row=index//2;panelw=600;panelh=380
        projected=[(G.dot(p,right),G.dot(p,up),G.dot(p,camera)) for p in m.vertices]
        xmin,xmax=min(p[0] for p in projected),max(p[0] for p in projected);ymin,ymax=min(p[1] for p in projected),max(p[1] for p in projected)
        scale=min((panelw-90)/(xmax-xmin),(panelh-55)/(ymax-ymin));cx=col*panelw+panelw/2-(xmin+xmax)/2*scale;cy=row*panelh+panelh/2+(ymin+ymax)/2*scale
        positions=[(cx+x*scale,cy-y*scale,z) for x,y,z in projected]
        colors=[tuple(B.srgb_encode(c*(.32+.72*max(0,G.dot(n,light)))) for c in rgb[:3]) for n,rgb in zip(m.normals(),m.colors)]
        for ia,ib,ic in m.faces:
            p,q,r=(positions[j] for j in (ia,ib,ic));area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
            if abs(area)<1e-8:continue
            for y in range(max(row*panelh,int(min(p[1],q[1],r[1]))),min((row+1)*panelh-1,int(max(p[1],q[1],r[1]))+1)+1):
                for x in range(max(col*panelw,int(min(p[0],q[0],r[0]))),min((col+1)*panelw-1,int(max(p[0],q[0],r[0]))+1)+1):
                    a=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area;b=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area;c=1-a-b
                    if min(a,b,c)<0:continue
                    pixel=y*width+x;z=a*p[2]+b*q[2]+c*r[2]
                    if z<=depth[pixel]:continue
                    depth[pixel]=z;pixels[pixel*3:pixel*3+3]=bytes(int(a*colors[ia][j]+b*colors[ib][j]+c*colors[ic][j]) for j in range(3))
    G.png(path,width,height,pixels)

def png_rgba(data,size):
    def chunk(kind,payload):return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    scan=b''.join(b'\0'+data[y*size*4:(y+1)*size*4] for y in range(size))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan,8))+chunk(b'IEND',b'')

def export(meshes,path):
    size=2048;cell=8;columns=size//cell;texture=bytearray((15,25,15,255))*(size*size);tile=0
    data=bytearray();views=[];accessors=[];nodes=[];outputmeshes=[];counts={}
    def acc(values,ctype,kind,bounds=None,target=34962):
        while len(data)%4:data.append(0)
        offset=len(data);flat=[v for row in values for v in row] if isinstance(values[0],(tuple,list)) else values
        data.extend(struct.pack('<'+str(len(flat))+('f' if ctype==5126 else 'H'),*flat));views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':target})
        a={'bufferView':len(views)-1,'componentType':ctype,'type':kind,'count':len(values)}
        if bounds:a.update(min=bounds[0],max=bounds[1])
        accessors.append(a);return len(accessors)-1
    for name,m in meshes.items():
        normals=m.normals();vs=[];ns=[];uv=[]
        for face in m.faces:
            tx=tile%columns*cell;ty=tile//columns*cell;assert ty+cell<=size
            for yy in range(cell):
                for xx in range(cell):
                    w=[max(0,1-(xx-1)/4-(yy-1)/4),max(0,(xx-1)/4),max(0,(yy-1)/4)];total=sum(w);w=[v/total for v in w]
                    p=((ty+yy)*size+tx+xx)*4
                    for j in range(3):texture[p+j]=B.srgb_encode(sum(w[i]*m.colors[face[i]][j] for i in range(3)))
            for i,(u,v) in zip(face,((1.5,1.5),(5.5,1.5),(1.5,5.5))):
                vs.append(G.mul(m.vertices[i],METRES));ns.append(normals[i]);uv.append(((tx+u)/size,(ty+v)/size))
            tile+=1
        assert len(vs)<65536
        bounds=G.bounds(vs);attributes={'POSITION':acc(vs,5126,'VEC3',bounds),'NORMAL':acc(ns,5126,'VEC3'),'TEXCOORD_0':acc(uv,5126,'VEC2')}
        indices=acc(list(range(len(vs))),5123,'SCALAR',target=34963)
        outputmeshes.append({'name':name,'primitives':[{'attributes':attributes,'indices':indices,'material':0}]})
        nodes.append({'name':name,'mesh':len(nodes),'translation':G.mul(LAYOUT[name],METRES)})
        counts[name]={'triangles':len(m.faces),'authoringVertices':len(m.vertices),'exportedVertices':len(vs)}
    image=png_rgba(texture,size)
    while len(data)%4:data.append(0)
    offset=len(data);data.extend(image);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(image)})
    scene={'asset':{'version':'2.0','generator':'BrickToads source-derived attack morphs; source2D depth/authored origin inferred'},
        'scene':0,'scenes':[{'name':'HeroAttackMorphs','nodes':list(range(4))}],'nodes':nodes,'meshes':outputmeshes,
        'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(data)}],
        'images':[{'name':'MorphBakedAlbedo','bufferView':len(views)-1,'mimeType':'image/png'}],
        'textures':[{'sampler':0,'source':0}],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],
        'materials':[{'name':'MorphSkinBakedAlbedo','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'baseColorFactor':[1,1,1,1],
            'roughnessFactor':.63,'metallicFactor':0},'doubleSided':False}]}
    encoded=json.dumps(scene,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    total=12+8+len(encoded)+8+len(data);blob=struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data
    assert len(blob)<20_000_000;path.write_bytes(blob)
    return counts,hashlib.sha256(blob).hexdigest(),len(blob)

def main():
    frozen={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.glb') if p.name!='hero-attack-morphs.glb'}
    meshes,refs=build();preview(meshes,HERE/'hero-attack-morphs-preview.png');print('FIRST PREVIEW READY',flush=True)
    counts,sha,bytes_=export(meshes,HERE/'hero-attack-morphs.glb');parts=[]
    for name,m in meshes.items():
        bounds=G.bounds(m.vertices);kind='PowerFist' if name.endswith('PowerFist') else 'BigBoot'
        assert all(abs(G.length(n)-1)<1e-6 for n in m.normals())
        parts.append({'name':name,'morphKind':kind,'heroTemplate':'Mr. Green' if name.startswith('Green') else 'Mr. Yellow',
            'attachmentOriginStuds':[0,0,0],'nodeTranslationMetres':G.mul(LAYOUT[name],METRES),'layoutOffsetStuds':LAYOUT[name],
            'layoutPurpose':'import orientation only; remove node layout offset before wrist/ankle binding','jointRootOrientation':'worldidentity',
            'boundsStuds':bounds,'boundingBoxCenterStuds':G.mul(G.add(*bounds),.5),'boundingBoxSizeStuds':G.sub(bounds[1],bounds[0]),**counts[name]})
    rig={'schema':1,'status':'source-derived-cosmetic-attack-morph-study','glbSha256':sha,'bytes':bytes_,
        'sourcePin':CATALOG['pin'],'sourceCatalogSha256':hashlib.sha256((SOURCE/'hero-frame-catalog.json').read_bytes()).hexdigest(),
        'units':{'metadata':'Robloxstuds','gltf':'metres','metresPerStud':METRES,'up':[0,1,0],'forward':[0,0,-1],'restExtension':'down-Y from wrist/ankle'},
        'parts':parts,'sourceReferences':refs,
        'sourceBindings':{'PowerFist':'anim0E gfx1C displayadvances11..31','BigBoot':'anim14 gfx1F windup advances0..11 then gfx1E contact12..36',
            'notImplemented':'gfx1A uppercut belongsanim10/74, not current narrow-fist anim06/gfx22'},
        'material':{'oneSharedMaterial':True,'onePrimitivePerNode':True,'albedo':'embedded2048x2048 sRGB unique8x8 UVcell pertriangle',
            'COLOR_0':'absent','emissive':'absent','Green':'owner-style grass/forest colours mapped from source slot0 regions',
            'PlayerTwo':'source0F/17/27 RGBtableapprox:18,19,20 /155,83,0 /250,160,66'},
        'runtimeContract':{'cosmeticOnly':True,'newHumanoid':False,'physicsOrDamageChanges':False,
            'origin':'MeshPart.CFrame*MorphOriginRigAttachment.CFrame equals wrist-spaceidentity after importnormalization',
            'binding':'actual RightWrist/RightAnkle frame; preserve offset to bboxcenter instead of snapping bboxcenter onto joint'},
        'limits':['semanticROI/depth/anchor andrightlimbassignment are3D adaptations, not original skeletal data',
            'first source-contour morph prototype; actual Studio silhouette/attachment/animation acceptance pending',
            'fear32/33 wholebody/head forms still pending'],'frozenEarlierGlbs':frozen}
    assert frozen=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.glb') if p.name!='hero-attack-morphs.glb'}
    (HERE/'hero-attack-morphs-rig.json').write_text(json.dumps(rig,indent=2)+'\n')
    (HERE/'hero-attack-morphs-validation.json').write_text(json.dumps({'status':'PASS','sha256':sha,'bytes':bytes_,'meshCount':4,'materials':1,
        'totalTriangles':sum(v['triangles'] for v in counts.values()),'parts':parts,'closedComponentsPerMesh':1,'allEarlierGlbsUnchanged':True},indent=2)+'\n')
    print(json.dumps({'sha256':sha,'bytes':bytes_,'counts':counts},indent=2),flush=True)

if __name__=='__main__':main()
