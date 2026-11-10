"""Downward, almost-to-the-feet fear jaw adaptation; NEW artifact only.

User screenshot is private provenance, read in place and never copied. Source
32/33 inform expression; body proportions/depth and rubber-jaw anatomy inferred.
"""
from __future__ import annotations
import hashlib, importlib.util, json, math, struct
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];METRES=.28
REFERENCE=Path('C:/Temp/codex-clipboard-97d370f2-282e-4c65-9d04-fb2aa60447cd.png')
def module(name,file):
    s=importlib.util.spec_from_file_location(name,HERE/file);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
F=module('wide_fear_previous','build_hero_fear_morphs.py');A=F.A;H=F.H;G=F.G;B=F.B
LAYOUT=F.LAYOUT
EARLIER=(*F.EARLIER,'hero-fear-morphs.glb','boss-walker.glb')
MOUTH=H.linear((.045,.004,.009)); DEEP=H.linear((.12,.009,.017))
TONGUE=H.linear((.66,.10,.15));TOOTH=F.TOOTH;WHITE=F.WHITE;PUPIL=F.PUPIL

def shell(before,glasses):
    # Neck-relative coordinates: neck world/rootY+1.886, hero ground rootY-3.
    # New chin at -4.25 therefore ends rootY-2.364 before the source body pose.
    mouth_x=.055 if before else 0
    cy=-1.635;ry=2.615;rx=.84 if before else 1.045
    inner_rx=.635 if before else .825;inner_ry=2.365
    def center_x(y):return mouth_x+(.025*(.8-y) if before else 0)
    def center_z(y):return -1.44+.12*(y-.8)
    eyes=[(-.43,1.27,-.81),(.43,1.31 if before else 1.27,-.81)]
    if before:eyes=[(x-.055,y,z+(.045 if x<0 else -.035)) for x,y,z in eyes]
    eye_r=(.285,.345,.305)
    glasses_centers=[(x,1.69+(y-1.27)*.3,-.43) for x,y,z in eyes]
    teeth=[(-.23+mouth_x,.79,-1.44),(.23+mouth_x,.79,-1.44)]
    tongue=(center_x(-3.68),-3.68,center_z(-3.68))
    def mouth_fields(p):
        x,y,z=p;q=(x-center_x(y),y,z-center_z(y))
        outer=H.ell(q,(0,cy,0),(rx,ry,.76))
        cavity=H.ell(q,(0,-1.575,-.37),(inner_rx,inner_ry,.88))
        return outer,cavity
    def components(p):
        d=H.ell(p,(0,.02,.10),(.34,.39,.32))
        d=H.smin(d,H.capsule(p,(0,.13,.09),(-.035 if before else 0,.83,-.19),.31),.10)
        d=H.smin(d,H.ell(p,(-.035 if before else 0,1.00,-.25),(.77,.55,.56)),.13)
        d=H.smin(d,H.ell(p,(mouth_x,.83,-.87),(.76 if before else .91,.235,.64)),.10)
        outer,cavity=mouth_fields(p);d=H.smin(d,outer,.09)
        # Actual tall concave chamber. Its curved back is forward of the chest;
        # the thin rubber jaw reaches down, rather than stretching the skull up.
        d=max(d,-cavity)
        for c in teeth:d=H.smin(d,H.ell(p,c,(.105,.155,.17)),.025)
        d=H.smin(d,H.ell(p,tongue,(inner_rx*.66,.25,.42)),.035)
        for c in eyes:
            d=H.smin(d,H.capsule(p,(c[0],c[1]-.14,-.36),(c[0],c[1],c[2]+.11),.20),.065)
            d=H.smin(d,H.ell(p,c,eye_r),.04)
        if glasses:
            for c in glasses_centers:
                d=H.smin(d,H.capsule(p,(c[0],1.43,-.35),c,.10),.025)
                d=H.smin(d,H.ell(p,c,(.34,.105,.22)),.025)
            d=H.smin(d,H.capsule(p,(-.19,1.66,-.49),(.19,1.66,-.49),.045),.025)
        return d
    def color(p,palette):
        x,y,z=p;outer,cavity=mouth_fields(p)
        for c in eyes:
            if H.ell(p,c,eye_r)<.028 and z<c[2]+.11:
                pupil=((x-c[0]-.02)/.115)**2+((y-c[1]+.015)/.205)**2
                if pupil<1 and z<c[2]-.237:
                    if ((x-c[0]+.025)/.027)**2+((y-c[1]-.08)/.034)**2<1:return H.GLINT
                    return PUPIL
                return WHITE
        if glasses:
            vals=[H.ell(p,c,(.34,.105,.22)) for c in glasses_centers]
            vals.extend(H.capsule(p,(c[0],1.43,-.35),c,.10) for c in glasses_centers)
            vals.append(H.capsule(p,(-.19,1.66,-.49),(.19,1.66,-.49),.045))
            if min(vals)<.026:return H.GLINT if 1.69<y<1.714 and z<-.56 else F.GLASS
        if any(H.ell(p,c,(.105,.155,.17))<.032 for c in teeth) and z<-1.35:return TOOTH
        if H.ell(p,tongue,(inner_rx*.66,.25,.42))<.04 and z<tongue[2]+.10:return TONGUE
        low,high=(H.FOREST,H.LIME) if palette=='Green' else (F.OCHRE,F.ORANGE)
        front=H.smooth(.10,-.58,z-center_z(y)) if y<.65 else H.smooth(.1,-.60,z)
        c=H.mix(low,high,front*.96)
        noise=.975+.025*(math.sin(x*14.7+y*9.1+z*11.9)*math.sin(y*5.9-z*8.3)+1)/2
        c=tuple(v*noise for v in c[:3])+(1.,)
        # Continuous inner-lip pigment avoids a high-contrast per-triangle seam
        # where the thin shell turns into its curved dark interior.
        inner_projection=math.sqrt(((x-center_x(y))/inner_rx)**2+((y+1.575)/inner_ry)**2)
        outer_projection=math.sqrt(((x-center_x(y))/rx)**2+((y-cy)/ry)**2)
        if inner_projection<1.55 and z-center_z(y)<.64 and y<.86:
            inner_margin=max(0,(inner_projection-1)*inner_rx)
            outer_margin=max(0,(1-outer_projection)*rx)
            lip=inner_margin/max(.0001,inner_margin+outer_margin)
            interior=H.mix(MOUTH,DEEP,H.smooth(-3.75,-.1,y)*.22)
            return H.mix(interior,c,H.smooth(.10,.90,lip))
        return c
    ref={'sourceGraphics':'32' if before else '33','sourceAnimation':'2C' if before else '2E',
         'shape':'narrower asymmetric downward rubber-jaw scream' if before else 'broader frontal downward rubber-jaw scream',
         'mouthOuterCenterNeckSpaceStuds':[mouth_x,cy,center_z(cy)],'mouthOuterRadiiStuds':[rx,ry,.76],
         'mouthCavityCenterNeckSpaceStuds':[mouth_x,-1.575,center_z(-1.575)-.37],
         'mouthCavityRadiiStuds':[inner_rx,inner_ry,.88],
         'cavityNominalHeightStuds':inner_ry*2,'cavityNominalWidthStuds':inner_rx*2,
         'jawNominalMinimumYNeckSpaceStuds':cy-ry,'eyeCentersNeckSpaceStuds':eyes,'eyeRadiiStuds':eye_r,
         'projectingJaw':'zCenter(y)=-1.44+.12*(y-.8); lower jaw bends forward toward -Z',
         'glasses':'raised onto brow above pop-out eyes' if glasses else 'absent to preserve established orange Player Two appearance'}
    return components,color,ref

def build():
    meshes={};refs={};components={}
    for palette in ('Green','PlayerTwo'):
        for before in (True,False):
            name=palette+('FearBeforeCut' if before else 'FearAfterCut')
            field,color,ref=shell(before,palette=='Green');m=A.Mesh(name)
            H.implicit(m,field,((-1.30,1.40),(-4.65,2.02),(-2.90,.70)),.135)
            A.weld_numerical_slivers(m);components[name]=H.orient(m)
            assert components[name]==1,(name,components[name])
            assert len(m.faces)<20000,(name,len(m.faces))
            m.colors=[color(p,palette) for p in m.vertices]
            m.surface_color=lambda p,c=color,pal=palette:c(p,pal)
            meshes[name]=m;refs[name]=ref
            print(name,len(m.faces),'triangles',flush=True)
    return meshes,refs,components

def export(meshes,path):
    # Same padded unique-triangle UV strategy as reviewed morph exporter. Bake
    # linear vertex pigments in vector batches; never export COLOR_0.
    import numpy as np
    size=4096;cell=8;columns=size//cell;tile=0
    texture=np.full((size,size,4),(15,25,15,255),dtype=np.uint8)
    xx,yy=np.meshgrid(np.arange(cell),np.arange(cell))
    weights=np.stack((np.maximum(0,1-(xx-1)/4-(yy-1)/4),np.maximum(0,(xx-1)/4),np.maximum(0,(yy-1)/4)),axis=-1)
    weights/=weights.sum(-1,keepdims=True)
    data=bytearray();views=[];accessors=[];nodes=[];output=[];counts={}
    def acc(values,ctype,kind,bounds=None,target=34962):
        while len(data)%4:data.append(0)
        offset=len(data);array=np.asarray(values,dtype='<f4' if ctype==5126 else '<u2');data.extend(array.tobytes())
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':target})
        a={'bufferView':len(views)-1,'componentType':ctype,'type':kind,'count':len(values)}
        if bounds:a.update(min=bounds[0],max=bounds[1])
        accessors.append(a);return len(accessors)-1
    for name,m in meshes.items():
        normals=m.normals();vs=[];ns=[];uv=[];colors=np.asarray(m.colors)[:,:3]
        for face in m.faces:
            tx=tile%columns*cell;ty=tile//columns*cell;assert ty+cell<=size
            rgb=weights@colors[list(face)]
            rgb=np.clip(rgb,0,1);srgb=np.where(rgb<=.0031308,rgb*12.92,1.055*np.power(rgb,1/2.4)-.055)
            texture[ty:ty+cell,tx:tx+cell,:3]=np.rint(srgb*255).astype(np.uint8)
            for i,(u,v) in zip(face,((1.5,1.5),(5.5,1.5),(1.5,5.5))):
                vs.append(G.mul(m.vertices[i],METRES));ns.append(normals[i]);uv.append(((tx+u)/size,(ty+v)/size))
            tile+=1
        assert len(vs)<65536
        attrs={'POSITION':acc(vs,5126,'VEC3',G.bounds(vs)),'NORMAL':acc(ns,5126,'VEC3'),'TEXCOORD_0':acc(uv,5126,'VEC2')}
        indices=acc(list(range(len(vs))),5123,'SCALAR',target=34963)
        output.append({'name':name,'primitives':[{'attributes':attrs,'indices':indices,'material':0}]})
        nodes.append({'name':name,'mesh':len(nodes),'translation':G.mul(LAYOUT[name],METRES)})
        counts[name]={'triangles':len(m.faces),'authoringVertices':len(m.vertices),'exportedVertices':len(vs)}
    image=A.png_rgba(texture.tobytes(),size)
    while len(data)%4:data.append(0)
    offset=len(data);data.extend(image);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(image)})
    scene={'asset':{'version':'2.0','generator':'BrickToads downward fear jaw; source/user-reference interpretation, inferred3Ddepth'},
        'scene':0,'scenes':[{'name':'HeroFearWideMouth','nodes':list(range(4))}],'nodes':nodes,'meshes':output,
        'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(data)}],
        'images':[{'name':'WideFearBakedAlbedo','bufferView':len(views)-1,'mimeType':'image/png'}],
        'textures':[{'sampler':0,'source':0}],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],
        'materials':[{'name':'WideFearSharedAlbedo','pbrMetallicRoughness':{'baseColorTexture':{'index':0},
            'baseColorFactor':[1,1,1,1],'roughnessFactor':.63,'metallicFactor':0},'doubleSided':False}]}
    encoded=json.dumps(scene,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    total=12+8+len(encoded)+8+len(data);blob=struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data
    path.write_bytes(blob);return counts,hashlib.sha256(blob).hexdigest(),len(blob)

def main():
    frozen={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in EARLIER}
    fixtures={'Green':F.fixture('roblox-player1.json'),'PlayerTwo':F.fixture('roblox-player2.json')}
    old=json.loads((HERE/'hero-fear-morphs-rig.json').read_text())
    meshes,refs,components=build()
    counts,sha,bytes_=export(meshes,HERE/'hero-fear-wide-mouth.glb');parts=[]
    R=module('wide_fear_actual_preview','render_hero_fear_wide_mouth.py')
    preview_info=R.render(HERE/'hero-fear-wide-mouth.glb');print('ACTUAL EXPORTED MATERIAL PREVIEW READY',flush=True)
    for name,m in meshes.items():
        bounds=G.bounds(m.vertices);center=G.mul(G.add(*bounds),.5);size=G.sub(bounds[1],bounds[0]);previous=next(p for p in old['parts'] if p['name']==name)
        parts.append({'name':name,'morphKind':'FearBeforeCut' if name.endswith('BeforeCut') else 'FearAfterCut',
          'heroTemplate':'Mr. Green' if name.startswith('Green') else 'Mr. Yellow','attachmentName':'NeckRigAttachment',
          'attachmentOriginStuds':[0,0,0],'nodeTranslationMetres':G.mul(LAYOUT[name],METRES),'layoutOffsetStuds':LAYOUT[name],
          'layoutPurpose':'native import orientation only; subtract before neck binding','boundsStuds':bounds,
          'boundingBoxCenterStuds':center,'boundingBoxSizeStuds':size,'heightStuds':size[1],
          'neckSpaceCenterStuds':center,'originAttachmentInIdentityBboxPartStuds':G.mul(center,-1),
          'expectedOrientation':{'up':[0,1,0],'forward':[0,0,-1],'neckAxes':'identity'},
          'oldBoundsStuds':previous['boundsStuds'],'oldHeightStuds':previous['heightStuds'],
          'chinMinimumYChangeStuds':bounds[0][1]-previous['boundsStuds'][0][1],
          'upperMaximumYChangeStuds':bounds[1][1]-previous['boundsStuds'][1][1],
          'closedConnectedOrientableComponents':components[name],**counts[name]})
        oldref=old['sourceReferences'][name];ratios=oldref['neutralHeadDimensionRatiosApplied']
        oldheight=oldref['mouthCavityRadiiStuds'][1]*2*ratios[1]
        oldwidth=oldref['mouthCavityRadiiStuds'][0]*2*ratios[0]
        parts[-1].update(cavityNominalHeightStuds=refs[name]['cavityNominalHeightStuds'],
            cavityNominalWidthStuds=refs[name]['cavityNominalWidthStuds'],oldCavityNominalHeightStuds=oldheight,
            oldCavityNominalWidthStuds=oldwidth,cavityHeightRatioToOld=refs[name]['cavityNominalHeightStuds']/oldheight,
            cavityWidthRatioToOld=refs[name]['cavityNominalWidthStuds']/oldwidth)
    assert frozen=={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in EARLIER}
    sourcefiles=[ROOT/'research/canonical-visuals/frames/hero-32.png',ROOT/'research/canonical-visuals/frames/hero-33.png',
                 HERE/'hero-fear-morphs-rig.json',HERE/'green-brawler-rig.json']
    rig={'schema':1,'status':'preupload-source-informed-dramatic-downward-fear-jaw','glbSha256':sha,'bytes':bytes_,
      'sourcePin':A.CATALOG['pin'],'units':{'metadata':'Roblox studs','gltf':'metres','metresPerStud':METRES,
      'up':[0,1,0],'forward':[0,0,-1],'origin':'existing actual Head.NeckRigAttachment; neck-space identity'},
      'parts':parts,'sourceReferences':refs,'existingHeadFixtures':fixtures,
      'privateUserReference':{'path':str(REFERENCE),'sha256':hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
          'copiedIntoRepository':False,'observation':'eyes stay near ordinary head level; very long thin jaw drops almost to feet, with dark concave gape and tongue'},
      'changesFromOld':['chin drops about4stud farther downward; skull/eye maximum reduced instead of stretching up',
          'nominal cavity height4.73stud, narrower asymmetricBefore and wider frontalAfter',
          'lower jaw projects forward of chest, -Z, while retaining a real closed concave interior',
          'Green keeps bulging eyes and raised sunglasses; PlayerTwo retains established orange/ochre palette and no sunglasses',
          'both palettes share downward height rather than blindly scaling PlayerTwo jaw toward/below ground'],
      'sourceFiles':{str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sourcefiles},
      'material':{'oneSharedMaterial':True,'onePrimitivePerMesh':True,'embeddedAlbedo':'4096x4096 sRGB padded8x8 triangle atlas from analytic surface vertex pigments',
          'COLOR_0':'absent','emissive':'absent','alphaMode':'OPAQUE','roughnessFactor':.63,'metallicFactor':0},
      'adaptationLimits':['source32/33 and user screenshot inform exaggerated downward expression, not exact body/depth reconstruction',
          '3D eye anatomy, mouth depth, cavity back, lip thickness, tongue and neck connection are authored',
          'actual attached-body ground clearance and source-pose occlusion require root Studio verification'],
      'runtimeContract':{'cosmeticOnly':True,'newHumanoid':False,'collisionOrDamageChanges':False,
          'originAttachment':'MorphOriginRigAttachment','joint':'existing Head.NeckRigAttachment',
          'origin':'Morph.CFrame*MorphOriginRigAttachment.CFrame equals actual neck frame; retain center offset and native imported orientation',
          'hide':'existing cosmetic Head only; retain body and limbs','jawNominalNeckMinimumY':-4.25,
          'approximateRootNeckY':1.886,'approximateJawRootMinimumY':-2.364,'groundAtRootY':-3,
          'source32PoseAllowance':'neutral jaw clearance .636stud; approximately .5stud lower under source32 body/head pitch; native check required'},
      'frozenEarlierGlbs':frozen,'studioImport':'NOT_RUN; root owns native attachment/pose verification'}
    rig['authoringDependencySha256']={n:hashlib.sha256((HERE/n).read_bytes()).hexdigest() for n in
        ['build_hero_fear_wide_mouth.py','render_hero_fear_wide_mouth.py','build_hero_fear_morphs.py',
         'build_hero_attack_morphs.py','build_green_brawler.py','build_canonical_hero.py','bake_green_brawler_surface.py']}
    validation={'status':'PASS','sha256':sha,'bytes':bytes_,'meshCount':4,'materials':1,'primitivesPerMesh':1,
      'totalTriangles':sum(c['triangles'] for c in counts.values()),'parts':parts,'allSevenEarlierGlbsUnchanged':True,
      'closedConnectedOrientableComponentsPerMesh':1,'meshTriangleLimitExclusive':20000,'exportVertexLimitExclusive':65536,
      'actualStudioAcceptance':'NOT_RUN','preview':preview_info,**F.inspect_export(HERE/'hero-fear-wide-mouth.glb',parts)}
    (HERE/'hero-fear-wide-mouth-rig.json').write_text(json.dumps(rig,indent=2)+'\n')
    (HERE/'hero-fear-wide-mouth-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
    print(json.dumps({'sha256':sha,'bytes':bytes_,'parts':parts},indent=2),flush=True)
if __name__=='__main__':main()
