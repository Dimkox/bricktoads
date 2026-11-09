"""Author the two source-informed boss-fear heads as closed, connected 3D shells.

This intentionally adapts the incomplete 2D frames 32/33 to the existing Green
and orange Player Two models. No source/test/place/avatar file is modified.
"""
from __future__ import annotations
import hashlib, importlib.util, json, math, struct, zlib
from pathlib import Path

HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]; METRES=.28

def module(name,file):
    s=importlib.util.spec_from_file_location(name,HERE/file)
    m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

A=module('fear_attack_helpers','build_hero_attack_morphs.py')
H=A.H;G=H.G;B=A.B
LAYOUT={'GreenFearBeforeCut':[-6,0,0],'GreenFearAfterCut':[-2,0,0],
        'PlayerTwoFearBeforeCut':[2,0,0],'PlayerTwoFearAfterCut':[6,0,0]}
EARLIER=('canonical-hero.glb','canonical-hero-player1.glb','canonical-hero-player2.glb',
         'green-brawler.glb','hero-attack-morphs.glb')
WHITE=H.linear((.94,.95,.82)); PUPIL=H.linear((.008,.012,.014))
MOUTH=H.linear((.085,.012,.018));TONGUE=H.linear((.54,.10,.12))
TOOTH=H.linear((.91,.91,.71));GLASS=H.linear((.012,.020,.017))
ORANGE=H.linear((250/255,160/255,66/255));OCHRE=H.linear((155/255,83/255,0))

def shell(kind,glasses=True):
    before=kind=='FearBeforeCut'
    stretch=.23 if before else 0
    # Frame32 gives the asymmetric long side scream; frame33 gives the wide
    # frontal scream. The dimensions, eyeballs and back of skull are inferred.
    mouth_x=.11 if before else 0
    mouth_y=1.14+stretch*.65; mouth_ry=.68+stretch*.45
    mouth_rx=.395 if before else .49
    top=1.79+stretch
    upper=(mouth_x*.55,top,-.45)
    lower=(mouth_x,.43,-.34)
    eyes=[(-.43,2.20+stretch,-.57),(.43,2.20+stretch+(.08 if before else 0),-.57)]
    if before:eyes=[(x-.06,y,z+(.03 if x<0 else -.025)) for x,y,z in eyes]
    eye_r=(.285,.375,.31)
    teeth=[(-.24+mouth_x*.6,top-.165,-.65),(.24+mouth_x*.6,top-.165,-.65)]
    tongue=(mouth_x,.61,-.18)
    mouth_c=(mouth_x,mouth_y,-.70);mouth_r=(mouth_rx,mouth_ry,.79)
    glasses_centers=[(x,2.49+stretch+(y-2.20-stretch)*.3,-.25) for x,y,z in eyes]
    def components(p):
        d=H.ell(p,(0,.27,.15),(.34,.47,.30))
        d=H.smin(d,H.ell(p,(-.045 if before else 0,1.18+stretch*.45,.19),(.61,.89+stretch*.3,.45)),.14)
        d=H.smin(d,H.ell(p,(-.08 if before else 0,top+.05,.11),(.74,.63,.49)),.13)
        for side in (-1,1):
            cx=side*.55+mouth_x*.7
            d=H.smin(d,H.ell(p,(cx,1.11+stretch*.4,-.21),(.235,.78+stretch*.3,.41)),.10)
        d=H.smin(d,H.ell(p,upper,(.75,.235,.57)),.12)
        d=H.smin(d,H.ell(p,lower,(.69,.285,.55)),.11)
        # A real open cavity, with an internal back surface and substantial lips.
        cavity=H.ell(p,mouth_c,mouth_r)
        d=max(d,-cavity)
        # Teeth and tongue connect into the cavity walls; no floating islands.
        for c in teeth:d=H.smin(d,H.ell(p,c,(.105,.145,.16)),.025)
        d=H.smin(d,H.ell(p,tongue,(.30,.11,.34)),.025)
        eyevals=[]
        for c in eyes:
            base=(c[0],c[1]-.12,-.18)
            d=H.smin(d,H.capsule(p,base,(c[0],c[1],c[2]+.09),.205),.08)
            e=H.ell(p,c,eye_r);eyevals.append(e);d=H.smin(d,e,.045)
        glassvals=[]
        if glasses:
            # The familiar sunglasses have sprung up onto the brow, exposing
            # popped eyes. Lenses remain volumes connected to the skull/eyelids.
            for c in glasses_centers:
                g=H.ell(p,c,(.365,.12,.235));glassvals.append(g);d=H.smin(d,g,.015)
            bridge=H.capsule(p,(-.19,2.46+stretch,-.37),(.19,2.46+stretch,-.37),.045)
            d=H.smin(d,bridge,.025);glassvals.append(bridge)
        return d,cavity,eyevals,glassvals
    def field(p):return components(p)[0]
    def color(p,palette):
        x,y,z=p;cavity=H.ell(p,mouth_c,mouth_r);glassvals=[]
        if glasses:
            glassvals=[H.ell(p,c,(.365,.12,.235)) for c in glasses_centers]
            glassvals.append(H.capsule(p,(-.19,2.46+stretch,-.37),(.19,2.46+stretch,-.37),.045))
        for c in eyes:
            e=H.ell(p,c,eye_r)
            if e<.025 and z<c[2]+.12:
                # Pupil is a surface pigment on the convex protruding eyeball.
                pupil=((x-c[0]-.01)/.112)**2+((y-c[1]+.025)/.205)**2
                if pupil<1 and z<c[2]-.245:
                    if ((x-c[0]+.025)/.028)**2+((y-c[1]-.075)/.038)**2<1:return H.GLINT
                    return PUPIL
                return WHITE
        if glassvals and min(glassvals)<.024:
            if 2.49+stretch<y<2.525+stretch and z<-.42 and .20<abs(x)<.53:return H.GLINT
            return GLASS
        if any(H.ell(p,c,(.105,.145,.16))<.035 for c in teeth) and z<-.48:return TOOTH
        if H.ell(p,tongue,(.30,.11,.34))<.025 and y>.60 and z<.10:return TONGUE
        if abs(cavity)<.037 and z<.135 and abs(x-mouth_x)<mouth_rx+.03 and abs(y-mouth_y)<mouth_ry+.04:
            return H.mix(MOUTH,H.linear((.18,.025,.028)),max(0,min(1,(.1-z)*.5)))
        # Broad green/cream muzzle and darker forest back match Green's existing
        # appearance; P2 retains the older orange/ochre palette and no glasses.
        front=H.smooth(.14,-.37,z)
        face=front*(1-H.smooth(top-.2,top+.15,y))
        low,high=(H.FOREST,H.LIME) if palette=='Green' else (OCHRE,ORANGE)
        c=H.mix(low,high,face*.96)
        # Mild baked mottling gives a frog surface without vertex-colour import.
        noise=.955+.045*(math.sin(x*15.1+y*11.3+z*17.4)*math.sin(x*5.9-y*7.2)+1)*.5
        return tuple(v*noise for v in c[:3])+(1.,)
    refs={'sourceGraphics':'32' if before else '33','sourceAnimation':'2C' if before else '2E',
        'mouthCavityCenterNeckSpaceStuds':mouth_c,'mouthCavityRadiiStuds':mouth_r,
        'eyeCentersNeckSpaceStuds':eyes,'eyeRadiiStuds':eye_r,
        'authoredCharacter':'asymmetric extended jaw/neck' if before else 'broad frontal open scream',
        'glasses':'pushed onto brow to expose eyes' if glasses else 'absent on existing orange Player Two style'}
    return field,color,refs

def fixture(name):
    j=json.loads((HERE/name).read_text());p=next(x for x in j['parts'] if x['name']=='Head')
    cf=p['cframe'];att=next(x for x in p['attachments'] if x['name']=='NeckRigAttachment')['cframe']
    # Both imported parts are rotated by Pi about Y; multiply their actual
    # CFrames rather than assuming a mesh bounding-box center is the neck.
    neck=[cf[i]+sum(cf[3+i*3+k]*att[k] for k in range(3)) for i in range(3)]
    center=G.sub(cf[:3],neck)
    return {'file':name,'sha256':hashlib.sha256((HERE/name).read_bytes()).hexdigest(),
        'headSizeStuds':p['size'],'headCenterWorldStuds':cf[:3],
        'neckWorldStuds':neck,'headCenterRelativeToNeckStuds':center,
        'headNeckAttachmentCFrame':att,'jointSpaceAxes':'identity in authoring/avatar rest space'}

def build():
    meshes={};refs={};fixtures={'Green':fixture('roblox-player1.json'),'PlayerTwo':fixture('roblox-player2.json')}
    ratios=[b/a for a,b in zip(fixtures['Green']['headSizeStuds'],fixtures['PlayerTwo']['headSizeStuds'])]
    for palette in ('Green','PlayerTwo'):
        for kind in ('FearBeforeCut','FearAfterCut'):
            name=palette+kind;field,color,ref=shell(kind,palette=='Green')
            m=A.Mesh(name)
            H.implicit(m,field,((-1.03,1.03),(-.30,3.12),(-1.18,.82)),.115)
            A.weld_numerical_slivers(m)
            components=H.orient(m);assert components==1,(name,components)
            assert len(m.faces)<20000,(name,len(m.faces))
            m.colors=[color(p,palette) for p in m.vertices]
            if palette=='PlayerTwo':
                m.vertices=[tuple(v*s for v,s in zip(p,ratios)) for p in m.vertices]
                m.analytic={i:G.unit(tuple(n/s for n,s in zip(n,ratios))) for i,n in m.analytic.items()};m._normals=None
            scale=ratios if palette=='PlayerTwo' else [1,1,1]
            m.surface_color=lambda p,c=color,pal=palette,s=scale:c(tuple(v/r for v,r in zip(p,s)),pal)
            ref['neutralHeadDimensionRatiosApplied']=ratios if palette=='PlayerTwo' else [1,1,1]
            meshes[name]=m;refs[name]=ref
            print(name,len(m.faces),'triangles',flush=True)
    return meshes,refs,fixtures

def export(meshes,path):
    # Reuse the reviewed per-triangle albedo bake/export, with a 4096 atlas so
    # the complete four-head package has ample unique padded triangle cells.
    src=(HERE/'build_hero_attack_morphs.py').read_text()
    start=src.index('def export(meshes,path):');end=src.index('\ndef main():',start)
    fn=src[start:end].replace('size=2048;cell=8','size=4096;cell=12')
    fn=fn.replace('(xx-1)/4','(xx-1)/8').replace('(yy-1)/4','(yy-1)/8')
    fn=fn.replace('((1.5,1.5),(5.5,1.5),(1.5,5.5))','((1.5,1.5),(9.5,1.5),(1.5,9.5))')
    fn=fn.replace('for yy in range(cell):','detailed=max(max(m.colors[k][j] for k in face)-min(m.colors[k][j] for k in face) for j in range(3))>.12\n            for yy in range(cell):')
    fn=fn.replace('for j in range(3):texture[p+j]=B.srgb_encode(sum(w[i]*m.colors[face[i]][j] for i in range(3)))',
        'rgb=m.surface_color(tuple(sum(w[i]*m.vertices[face[i]][j] for i in range(3)) for j in range(3))) if detailed else tuple(sum(w[i]*m.colors[face[i]][j] for i in range(3)) for j in range(3))\n                    for j in range(3):texture[p+j]=B.srgb_encode(rgb[j])')
    fn=fn.replace('HeroAttackMorphs','HeroFearMorphs').replace('source-derived attack morphs; source2D depth/authored origin inferred','source-informed fear head adaptation; inferred 3D depth/eyes/neck anatomy')
    namespace={'G':G,'B':B,'LAYOUT':LAYOUT,'METRES':METRES,'struct':struct,'json':json,
               'hashlib':hashlib,'png_rgba':A.png_rgba}
    exec(fn,namespace);return namespace['export'](meshes,path)

def inspect_export(path,parts):
    """Check the serialized asset, including its actual float32 dimensions."""
    blob=path.read_bytes();assert struct.unpack_from('<4sII',blob)==(b'glTF',2,len(blob))
    jlen=struct.unpack_from('<I',blob,12)[0];scene=json.loads(blob[20:20+jlen]);binary=28+jlen
    assert len(scene['meshes'])==len(scene['nodes'])==4 and len(scene['materials'])==len(scene['images'])==1
    assert not any('emissive' in k.lower() for k in scene['materials'][0])
    measured={};maximum_error=0
    for node,m,p in zip(scene['nodes'],scene['meshes'],parts):
        assert node['name']==m['name']==p['name'] and len(m['primitives'])==1
        prim=m['primitives'][0];assert prim['material']==0
        assert set(prim['attributes'])=={'POSITION','NORMAL','TEXCOORD_0'}
        positions=[];normals=[]
        for name,target in (('POSITION',positions),('NORMAL',normals)):
            acc=scene['accessors'][prim['attributes'][name]];view=scene['bufferViews'][acc['bufferView']]
            start=binary+view.get('byteOffset',0)+acc.get('byteOffset',0)
            target.extend(struct.unpack_from('<fff',blob,start+i*12) for i in range(acc['count']))
        assert len(positions)==p['exportedVertices']<65536
        assert all(abs(G.length(n)-1)<2e-6 for n in normals)
        assert all(math.isfinite(v) for q in positions for v in q)
        minimum_area=min(G.length(G.cross(G.sub(positions[i+1],positions[i]),G.sub(positions[i+2],positions[i])))*.5 for i in range(0,len(positions),3))
        assert minimum_area>1e-12,(p['name'],'float32 degenerate triangle',minimum_area)
        bounds=G.bounds(positions)
        error=max(abs(v-w*METRES) for actual,wanted in zip(bounds,p['boundsStuds']) for v,w in zip(actual,wanted))
        assert error<1e-6;maximum_error=max(maximum_error,error)
        assert max(abs(a-b*METRES) for a,b in zip(node['translation'],p['layoutOffsetStuds']))<1e-9
        measured[p['name']]={'decodedBoundsMetres':bounds,'metreConversionMaximumError':error,
            'minimumTriangleAreaSquareMetres':minimum_area,'unitNormals':True}
    return {'serializedAssetChecks':'PASS','decodedParts':measured,'metreConversionMaximumError':maximum_error,
        'attributesPerPrimitive':['POSITION','NORMAL','TEXCOORD_0'],'oneEmbeddedAlbedo':True,'noEmissive':True,'noVertexColors':True}

def preview(meshes,path):
    # Actual mesh software render: rows Green/P2; each expression gets front
    # and three-quarter views, so cavity depth and protruding eyes are visible.
    width,height=1440,1040;pixels=bytearray((21,27,29))*(width*height);depth=[-1e10]*(width*height)
    light=G.unit((-.6,.8,-1));pw,ph=360,520
    for name,m in meshes.items():
        row=0 if name.startswith('Green') else 1;base=0 if name.endswith('BeforeCut') else 2
        for view,az in enumerate((0,56)):
            col=base+view;az=math.radians(az);el=math.radians(5)
            camera=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el))
            right=(math.cos(az),0,math.sin(az));up=G.cross(right,camera)
            projected=[(G.dot(p,right),G.dot(p,up),G.dot(p,camera)) for p in m.vertices]
            lo=[min(p[i] for p in projected) for i in range(2)];hi=[max(p[i] for p in projected) for i in range(2)]
            scale=min((pw-50)/(hi[0]-lo[0]),(ph-70)/(hi[1]-lo[1]))
            cx=col*pw+pw/2-(lo[0]+hi[0])/2*scale;cy=row*ph+ph/2+(lo[1]+hi[1])/2*scale
            ps=[(cx+x*scale,cy-y*scale,z) for x,y,z in projected]
            colors=[tuple(B.srgb_encode(c*(.38+.68*max(0,G.dot(n,light)))) for c in rgb[:3]) for n,rgb in zip(m.normals(),m.colors)]
            for face in m.faces:
                p,q,r=(ps[i] for i in face);area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-8:continue
                detailed=max(max(m.colors[k][j] for k in face)-min(m.colors[k][j] for k in face) for j in range(3))>.12
                for y in range(max(row*ph,int(min(p[1],q[1],r[1]))),min((row+1)*ph-1,int(max(p[1],q[1],r[1]))+1)+1):
                    for x in range(max(col*pw,int(min(p[0],q[0],r[0]))),min((col+1)*pw-1,int(max(p[0],q[0],r[0]))+1)+1):
                        a=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area
                        b=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area;c=1-a-b
                        if min(a,b,c)<0:continue
                        at=y*width+x;z=a*p[2]+b*q[2]+c*r[2]
                        if z<=depth[at]:continue
                        depth[at]=z
                        if detailed:
                            point=tuple(a*m.vertices[face[0]][j]+b*m.vertices[face[1]][j]+c*m.vertices[face[2]][j] for j in range(3))
                            rgb=m.surface_color(point)
                            n=G.unit(tuple(a*m.normals()[face[0]][j]+b*m.normals()[face[1]][j]+c*m.normals()[face[2]][j] for j in range(3)))
                            shade=.38+.68*max(0,G.dot(n,light));pixels[at*3:at*3+3]=bytes(B.srgb_encode(v*shade) for v in rgb[:3])
                        else:pixels[at*3:at*3+3]=bytes(int(a*colors[face[0]][j]+b*colors[face[1]][j]+c*colors[face[2]][j]) for j in range(3))
    G.png(path,width,height,pixels)

def source_preview():
    # Inspection aid only; original files are read unchanged. Nearest sampling
    # preserves their exact pixels and does not participate in the 3D bake.
    width,height=640,480;pixels=bytearray((45,49,49))*(width*height)
    for fid,left in (('32',25),('33',340)):
        w,h,data=B.png_decode((ROOT/'research/canonical-visuals/frames'/f'hero-{fid}.png').read_bytes())
        for y in range(h):
            for x in range(w):
                i=(y*w+x)*4
                if not data[i+3]:continue
                for dy in range(10):
                    for dx in range(10):
                        at=((40+y*10+dy)*width+left+x*10+dx)*3
                        pixels[at:at+3]=data[i:i+3]
    G.png(HERE/'hero-fear-source-reference.png',width,height,pixels)

def main():
    frozen={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in EARLIER}
    place=ROOT/'places/BrickToads.rbxlx';placehash=hashlib.sha256(place.read_bytes()).hexdigest() if place.exists() else None
    source_preview();meshes,refs,fixtures=build();preview(meshes,HERE/'hero-fear-morphs-preview.png')
    counts,sha,bytes_=export(meshes,HERE/'hero-fear-morphs.glb');parts=[]
    for name,m in meshes.items():
        bounds=G.bounds(m.vertices);center=G.mul(G.add(*bounds),.5);size=G.sub(bounds[1],bounds[0])
        assert all(abs(G.length(n)-1)<1e-6 for n in m.normals())
        parts.append({'name':name,'morphKind':'FearBeforeCut' if name.endswith('BeforeCut') else 'FearAfterCut',
            'heroTemplate':'Mr. Green' if name.startswith('Green') else 'Mr. Yellow',
            'attachmentName':'NeckRigAttachment','attachmentOriginStuds':[0,0,0],
            'nodeTranslationMetres':G.mul(LAYOUT[name],METRES),'layoutOffsetStuds':LAYOUT[name],
            'layoutPurpose':'import orientation only; subtract before neck binding',
            'boundsStuds':bounds,'boundingBoxCenterStuds':center,'boundingBoxSizeStuds':size,
            'heightStuds':size[1],'neckSpaceCenterStuds':center,
            'originAttachmentInIdentityBboxPartStuds':G.mul(center,-1),**counts[name]})
    assert frozen=={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in EARLIER}
    assert placehash==(hashlib.sha256(place.read_bytes()).hexdigest() if place.exists() else None)
    src=ROOT/'research/2026-11-09-canonical-character-animation-source.md'
    rig={'schema':1,'status':'frozen-preupload-source-informed-3d-head-adaptation',
        'glbSha256':sha,'bytes':bytes_,'sourcePin':A.CATALOG['pin'],
        'units':{'metadata':'Roblox studs','gltf':'metres','metresPerStud':METRES,'up':[0,1,0],'forward':[0,0,-1],
                 'origin':'actual existing Head.NeckRigAttachment; authoring rest/world identity'},
        'parts':parts,'sourceReferences':refs,'existingHeadFixtures':fixtures,
        'sourceFiles':{str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in
            [src,ROOT/'research/canonical-visuals/frames/hero-32.png',ROOT/'research/canonical-visuals/frames/hero-33.png',
             ROOT/'research/canonical-visuals/hero-boss-appearance-reaction.png',HERE/'green-brawler-rig.json']},
        'sourceTiming':{'FearBeforeCut':'first-route intro counter01..DF; animation2C graphics32',
            'FearAfterCut':'counterE1..FE; animation2E graphics33','E0':'camera/arena cut; helper skipped','FF':'intro removal; helper skipped'},
        'adaptation':['actual recessed mouth cavity, elongated jaw/neck and bulging eyes are authored 3D interpretations',
            'asymmetry/depth/eye anatomy/glasses displacement are inferred; no exact whole-body source silhouette claim',
            'Green sunglasses pushed onto brow; PlayerTwo orange palette and no sunglasses preserve current template distinction',
            'body joint poses and source Z motion are handled separately; this asset supplies head form only'],
        'material':{'oneSharedMaterial':True,'onePrimitivePerMesh':True,'embeddedAlbedo':'4096x4096 sRGB unique padded12x12 triangle cells; analytic feature boundaries baked per texel',
            'COLOR_0':'absent','emissive':'absent','alphaMode':'OPAQUE','roughnessFactor':.63,'metallicFactor':0},
        'runtimeContract':{'oneMeshPartPerMorph':'Morph','originAttachment':'MorphOriginRigAttachment',
            'joint':'existing cosmetic Head.NeckRigAttachment, never wrist','origin':'Morph.CFrame * attachment.CFrame equals neck-space identity after import normalization',
            'bbox':'retain measured origin-to-center; do not snap bbox center to neck','hide':'only existing cosmetic Head while fear morph visible',
            'cosmeticOnly':True,'newHumanoid':False,'collisionOrDamageChanges':False},
        'frozenEarlierGlbs':frozen,'placeSha256Unchanged':placehash,'studioImport':'NOT_RUN; delegated to root after review'}
    rig['authoringDependencySha256']={n:hashlib.sha256((HERE/n).read_bytes()).hexdigest() for n in
        ['build_hero_fear_morphs.py','build_hero_attack_morphs.py','build_green_brawler.py','bake_green_brawler_surface.py','build_canonical_hero.py']}
    validation={'status':'PASS','sha256':sha,'bytes':bytes_,'meshCount':4,'materials':1,'primitivesPerMesh':1,
        'totalTriangles':sum(v['triangles'] for v in counts.values()),'closedConnectedOrientableComponentsPerMesh':1,
        'meshTriangleLimitExclusive':20000,'exportVertexLimitExclusive':65536,'parts':parts,
        'allFiveEarlierGlbsUnchanged':True,'placeUnchanged':True,'actualStudioAcceptance':'NOT_RUN'}
    validation.update(inspect_export(HERE/'hero-fear-morphs.glb',parts))
    (HERE/'hero-fear-morphs-rig.json').write_text(json.dumps(rig,indent=2)+'\n')
    (HERE/'hero-fear-morphs-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
    print(json.dumps({'sha256':sha,'bytes':bytes_,'parts':parts},indent=2),flush=True)

if __name__=='__main__':main()
