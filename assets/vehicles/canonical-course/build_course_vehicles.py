"""Closed segmented course vehicles grounded in pinned NES sprite research.

The source supplies silhouette cues and palette. Thickness, unseen surfaces,
mechanical details and neutral 3D pivots are authored; no sprite is embedded.
"""
from pathlib import Path
from collections import Counter
import hashlib,importlib.util,json,math,struct

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
geo=module('course_mesh_geometry',ROOT/'assets/characters/canonical-cast/build_cast.py')
render=module('course_mesh_render',ROOT/'assets/characters/canonical-cast/render_cast.py')
PIN=geo.PIN
BLACK=(18,19,20); TEAL=(0,102,120); CYAN=(56,180,204)
RED=(180,0,0); PINK=(255,100,97); YELLOW=(205,202,62); OLIVE=(117,118,0); WHITE=(255,255,255)
FOOTPRINTS={'Speeder':(5.6,2.4),'Surfboard':(5.6,2.1),'Jet':(6.2,4.6),'ClingerVehicle':(2.6,2.0)}

def poly(m,points,y,thickness,color):
    """Closed bevelled convex plate in XZ, with upward Y thickness."""
    temp=geo.Mesh('temporary');geo.plate(temp,points,y,thickness,color)
    m.append([(x,z,y_) for x,y_,z in temp.vertices],temp.faces,color)

def rod(m,a,b,r,color,radial=12):geo.tube(m,[(*a,r,r),(*b,r,r)],color,radial,2)
def tire(m,center,radius,width,color=BLACK,segments=36,around=10):
    # Wheel axis local X; a closed torus. The hollow centre is genuine geometry.
    cx,cy,cz=center;vs=[];fs=[]
    minor=width/2
    for i in range(segments):
        a=i*math.tau/segments
        for j in range(around):
            b=j*math.tau/around;ring=radius+minor*math.cos(b)
            vs.append((cx+minor*math.sin(b),cy+ring*math.sin(a),cz+ring*math.cos(a)))
    for i in range(segments):
        for j in range(around):
            a=i*around+j;b=((i+1)%segments)*around+j;c=i*around+(j+1)%around;d=((i+1)%segments)*around+(j+1)%around
            fs.extend(((a,b,c),(b,d,c)))
    m.append(vs,fs,color)

def scooter():
    o=geo.Model('Speeder')
    m=o.part('Body');geo.tube(m,[(0,-.32,2.65,.16,.12),(0,-.36,2.05,.64,.30),(0,-.38,.95,1.02,.38),
        (0,-.33,-.6,1.04,.36),(0,-.25,-1.8,.86,.38),(0,-.27,-2.8,.22,.15)],TEAL,24,4,power=.78)
    m.vertices=[(x,y-.20,z) for x,y,z in m.vertices]
    m=o.part('Nose',(0,-.08,-1.50));geo.tube(m,[(0,-.1,-.90,.65,.22),(0,.05,-1.55,.83,.35),(0,-.09,-2.55,.52,.20),(0,-.19,-2.82,.10,.09)],CYAN,24,3,power=.8)
    m=o.part('RiderDeck');geo.tube(m,[(0,-.10,1.60,.42,.08),(0,-.10,.55,.62,.10),(0,-.10,-.68,.48,.10)],BLACK,20,3,power=.60)
    m=o.part('Undercarriage',(0,-.63,.30));geo.tube(m,[(0,-.65,1.90,.26,.12),(0,-.73,.8,.68,.18),(0,-.70,-1.35,.64,.14),(0,-.53,-2.0,.30,.11)],BLACK,20,3,power=.65)
    for s,name in ((-1,'Left'),(1,'Right')):
        m=o.part(name+'Engine',(s*.70,-.55,1.25))
        geo.tube(m,[(s*.70,-.48,1.85,.26,.20),(s*.77,-.59,1.28,.35,.29),(s*.75,-.62,.72,.28,.22)],CYAN,18,3,power=.75)
        geo.tube(m,[(s*.70,-.48,1.95,.19,.14),(s*.70,-.48,1.82,.19,.14)],BLACK,16,1)
        # Source has tall swept rear shoulders; no invented road wheels.
        m=o.part(name+'TailFin',(s*.65,-.04,1.45))
        temp=geo.Mesh('fin');geo.plate(temp,[(.45,-.15),(1.00,-.05),(2.38,.70),(2.13,.91),(1.10,.50)],s*.72,.19,CYAN)
        m.append([(z,y,x) for x,y,z in temp.vertices],temp.faces,CYAN)
        m=o.part(name+'Handle',(s*.48,.34,-1.08))
        geo.tube(m,[(s*.36,.1,-1.32,.11,.11),(s*.42,.65,-1.24,.11,.11),(s*.65,1.23,-1.49,.12,.10),(s*.88,1.34,-1.39,.13,.11)],TEAL,14,3)
        rod(m,(s*.68,1.35,-1.39),(s*1.08,1.35,-1.39),.135,BLACK)
    o.facts=['Source object2A: cyan/teal elongated hover-scooter; raised rear shoulders, forward cowling, dark rider recess and two raised handle shapes.','No road wheels added: source does not show a conventional two-wheel motorcycle.']
    return o

def surfboard():
    o=geo.Model('Surfboard');m=o.part('Body')
    # A broad pointed board with squared/fork-like tail cues from source D2.
    outline=[(-.72,2.8),(-1.03,2.02),(-1.03,.48),(-.82,-1.55),(0,-2.8),(.82,-1.55),(1.03,.48),(1.03,2.02),(.72,2.8)]
    poly(m,outline,-.275,.38,OLIVE)
    m=o.part('UpperShell');poly(m,[(x*.93,z*.97) for x,z in outline],-.105,.14,YELLOW)
    m=o.part('Deck');poly(m,[(-.60,2.35),(-.76,1.25),(-.64,-1.27),(0,-2.44),(.64,-1.27),(.76,1.25),(.60,2.35)],-.020,.032,WHITE)
    m=o.part('CentreStripe');geo.tube(m,[(0,-.009,2.30,.075,.009),(0,-.009,.9,.105,.009),(0,-.009,-.9,.12,.009),(0,-.009,-2.03,.025,.009)],YELLOW,12,3,power=.4)
    m=o.part('TailCrest',(0,-.03,1.85));poly(m,[(-.54,1.80),(-.70,2.56),(-.48,2.64),(-.25,2.05),(.25,2.05),(.48,2.64),(.70,2.56),(.54,1.80)],-.015,.035,YELLOW)
    # Bottom keel and twin short aft fins: inferred thickness, below rider deck.
    m=o.part('BottomKeel',(0,-.40,.55));geo.tube(m,[(0,-.36,1.96,.18,.11),(0,-.46,.5,.22,.16),(0,-.36,-1.50,.07,.10)],OLIVE,16,3,power=.6)
    for s,name in ((-1,'Left'),(1,'Right')):
        m=o.part(name+'Fin',(s*.55,-.36,1.73));temp=geo.Mesh('fin');geo.plate(temp,[(1.1,-.30),(2.24,-.30),(2.24,-.83),(1.77,-.64)],s*.55,.12,OLIVE)
        m.append([(z,y,x) for x,y,z in temp.vertices],temp.faces,OLIVE)
    o.facts=['Source objectD2: long pointed yellow/olive board with broad white top, central interrupted yellow seam and squared divided tail.']
    return o

def jet():
    o=geo.Model('Jet');m=o.part('Body')
    geo.tube(m,[(0,-.32,3.10,.10,.10),(0,-.35,2.30,.38,.35),(0,-.40,1.12,.73,.52),
        (0,-.34,-.85,.72,.51),(0,-.30,-2.15,.43,.32),(0,-.30,-3.10,.05,.07)],RED,24,4,power=.8)
    m.vertices=[(x,y-.20,z) for x,y,z in m.vertices]
    m=o.part('Nose',(0,-.28,-2.18));geo.tube(m,[(0,-.31,-1.9,.45,.29),(0,-.22,-2.55,.35,.24),(0,-.29,-3.12,.04,.06)],PINK,20,3,power=.8)
    m=o.part('RiderDeck');geo.tube(m,[(0,-.10,.95,.34,.10),(0,-.09,.2,.48,.09),(0,-.12,-.90,.34,.12)],BLACK,20,3,power=.58)
    m=o.part('CockpitRim',(0,-.05,-.85));geo.tube(m,[(0,-.02,-.74,.38,.08),(0,.02,-1.0,.43,.09),(0,-.02,-1.21,.34,.06)],PINK,18,3,power=.65)
    for s,name in ((-1,'Left'),(1,'Right')):
        m=o.part(name+'Wing',(s*.62,-.38,.45));poly(m,[(s*.46,-.86),(s*2.46,1.43),(s*2.30,2.02),(s*.43,1.05)],-.38,.18,PINK)
        # Dark red trailing root gives the source's swept, contrasting wing.
        poly(m,[(s*.51,.23),(s*1.76,1.66),(s*.50,1.18)],-.37,.19,RED)
        m=o.part(name+'Intake',(s*.65,-.30,-1.17));geo.tube(m,[(s*.63,-.31,-1.57,.22,.25),(s*.69,-.34,-.88,.26,.30)],RED,16,3,power=.55)
        for z in (-1.38,-1.16,-.94):rod(m,(s*.883,-.49,z),(s*.883,-.19,z),.035,BLACK,10)
        m=o.part(name+'Tailplane',(s*.36,-.22,2.20));poly(m,[(s*.23,1.91),(s*1.34,2.74),(s*1.13,3.04),(s*.18,2.70)],-.23,.13,PINK)
    m=o.part('TailFin',(0,-.16,2.28));temp=geo.Mesh('fin');geo.plate(temp,[(1.4,-.13),(2.93,-.13),(2.93,1.31),(2.55,1.40)],0,.18,RED)
    m.append([(z,y,x) for x,y,z in temp.vertices],temp.faces,RED)
    rod(m,(-.11,1.33,2.56),(-.11,1.25,2.86),.055,PINK)
    m=o.part('Exhaust',(0,-.38,2.72));geo.tube(m,[(0,-.37,2.54,.28,.29),(0,-.37,2.92,.22,.23)],BLACK,20,3)
    o.facts=['Source object8B: red/pink pointed aircraft, black rider/cockpit recess, broad swept near wing, high vertical tail, side vent marks.','Volkmire bike fallback object8B is selected by bike_frame_id, not an invented generic spacecraft.']
    return o

def clinger():
    o=geo.Model('ClingerVehicle');m=o.part('Body')
    # The source upright frame74 explicitly separates a wavy handlebar and one
    # circular wheel. The fork/stem is authored to connect those visible pieces.
    geo.tube(m,[(0,-.18,.14,.30,.18),(0,-.48,.12,.40,.28),(0,-.77,.10,.31,.22)],RED,20,3,power=.7)
    m=o.part('Wheel',(0,-1.00,.10));tire(m,(0,-1.00,.10),.70,.38,BLACK,40,12)
    tire(m,(0,-1.00,.10),.69,.24,PINK,40,10)
    # Wide dark central tyre is visible around both red sidewall rings.
    for s in (-1,1):
        geo.tube(m,[(s*.22,-1.0,.1,.48,.48),(s*.25,-1.0,.1,.48,.48)],RED,30,1)
        geo.ellipsoid(m,(s*.28,-1,.1),(.055,.21,.21),BLACK,14,8)
        for k in range(5):
            a=k*math.tau/5;rod(m,(s*.292,-1,.1),(s*.292,-1+math.sin(a)*.42,.1+math.cos(a)*.42),.045,PINK,10)
    m=o.part('Fork',(0,-.32,-.10))
    for s in (-1,1):rod(m,(s*.31,-1.0,.10),(s*.31,-.18,-.18),.085,BLACK)
    m=o.part('RiderDeck');poly(m,[(-.92,.77),(-.92,-.60),(-.35,-.76),(.35,-.76),(.92,-.60),(.92,.77)],-.08,.16,RED)
    for s in (-1,1):rod(m,(s*.42,-.01,-.42),(s*.82,-.01,-.42),.045,PINK)
    m=o.part('HandleStem',(0,.25,-.78));geo.tube(m,[(0,-.08,-.55,.10,.10),(0,.62,-.89,.105,.105),(0,1.26,-.89,.10,.10)],BLACK,14,3)
    m=o.part('Handlebar',(0,1.26,-.89))
    geo.tube(m,[(-1.08,1.30,-.89,.10,.10),(-.88,1.62,-.89,.11,.11),(-.65,1.17,-.89,.11,.11),
        (-.31,1.29,-.89,.11,.11),(0,1.18,-.89,.11,.11),(.31,1.29,-.89,.11,.11),(.65,1.17,-.89,.11,.11),(.88,1.62,-.89,.11,.11),(1.08,1.30,-.89,.10,.10)],RED,14,3)
    for s in (-1,1):rod(m,(s*.89,1.58,-.89),(s*1.08,1.31,-.89),.062,PINK)
    o.facts=['Source object74 upright Clinger: red/pink single circular wheel and red undulating handlebar silhouette.','frames_koleso74/76/78/7A and flags_koleso select track orientations; this asset is upright rest geometry for whole-vehicle rotation.']
    return o

BUILDERS={'Speeder':scooter,'Surfboard':surfboard,'Jet':jet,'ClingerVehicle':clinger}

def parse(blob):
    magic,version,total=struct.unpack_from('<4sII',blob);assert(magic,version,total)==(b'glTF',2,len(blob))
    n=struct.unpack_from('<I',blob,12)[0];return json.loads(blob[20:20+n]),blob[28+n:]

def pack(entries):
    combined={'asset':{'version':'2.0','generator':'BrickToads source-informed course vehicles','extras':{'metresPerStud':.28,'sourcePin':PIN}},'scene':0,'scenes':[{'name':'CanonicalCourseVehicles','nodes':[]}],
              'nodes':[],'meshes':[],'accessors':[],'bufferViews':[],'images':[],'textures':[],'materials':[],'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]}
    data=bytearray();contract={}
    for kind,entry in entries.items():
        scene,binary=parse((HERE/kind/(kind+'.glb')).read_bytes())
        while len(data)%4:data.append(0)
        offset=len(data);data.extend(binary)
        vb=len(combined['bufferViews']);ab=len(combined['accessors']);mb=len(combined['meshes']);nb=len(combined['nodes']);ib=len(combined['images']);tb=len(combined['textures']);matb=len(combined['materials'])
        for v in scene['bufferViews']:v['byteOffset']=v.get('byteOffset',0)+offset
        for a in scene['accessors']:a['bufferView']+=vb
        for image in scene['images']:image['bufferView']+=vb;image['name']=kind+'__'+image['name']
        for tex in scene['textures']:tex['source']+=ib;tex['sampler']=0
        for mat in scene['materials']:mat['name']=kind+'__'+mat['name'];mat['pbrMetallicRoughness']['baseColorTexture']['index']+=tb
        for mesh in scene['meshes']:
            mesh['name']=kind+'__'+mesh['name']
            for p in mesh['primitives']:p['attributes']={k:v+ab for k,v in p['attributes'].items()};p['indices']+=ab;p['material']+=matb
        for node in scene['nodes']:
            node['name']=kind+'__'+node['name'];node['mesh']+=mb
            if 'children' in node:node['children']=[v+nb for v in node['children']]
        for key in ('nodes','meshes','accessors','bufferViews','images','textures','materials'):combined[key].extend(scene[key])
        combined['scenes'][0]['nodes'].extend(i+nb for i in scene['scenes'][0]['nodes'])
        rig=json.loads((HERE/kind/(kind+'-rig.json')).read_text())
        contract[kind]={'deckTop':0,'deckLength':FOOTPRINTS[kind][0],'deckWidth':FOOTPRINTS[kind][1],'forward':[0,0,-1],
                        'parts':[{'importedName':kind+'__'+p['name'],'name':p['name'],'globalPivotStuds':p['pivot'],
                                  'globalBoundsStuds':p['globalBounds'],'sizeStuds':[b-a for a,b in zip(*p['globalBounds'])],
                                  'centerStuds':[(a+b)/2 for a,b in zip(*p['globalBounds'])]} for p in rig['parts']]}
    combined['buffers']=[{'byteLength':len(data)}];encoded=json.dumps(combined,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    blob=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(data))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data
    path=HERE/'canonical-course-vehicles.glb';path.write_bytes(blob)
    result={'schema':1,'glb':path.name,'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),'familyCount':4,'meshCount':len(combined['meshes']),
            'sourcePin':PIN,'meshNames':[m['name'] for m in combined['meshes']],'templates':contract,
            'contract':{'folder':'ServerStorage.BrickToadsCourseTemplates','modelMetadata':{'AppearanceProfile':'CanonicalCourseVehicle','CourseKind':'<kind>','SourcePin':PIN},
                        'numberValues':['DeckTop=0','DeckLength=<localZ footprint>','DeckWidth=<localX footprint>'],
                        'axis':'Y-up, forward -Z. Runtime rotates Y=-pi/2 to +X. Source origin is deck top at XZ centre.',
                        'reconstruction':'Match imported MeshParts by Kind__Segment. Set each flat template part.Size=sizeStuds and CFrame=CFrame.new(centerStuds)*CFrame.Angles(0,math.pi,0), restoring the observed native importer Y180 conversion. Keep actual imported MeshId,TextureID and SurfaceAppearance if present. Preserve raw imported MeshSize as InitialSize independently of resized Size. Source GLB nodes use pivot-relative mesh geometry; globalBoundsStuds accounts for importer recentering.',
                        'physics':'All visual parts anchored,CanCollide=false,CanTouch=false,CanQuery=false,Massless=true. Existing collider unchanged.',
                        'fit':'Uniform scale=min(collider.Size.X/DeckLength,collider.Size.Z/DeckWidth). Place localDeckTop0 at collider top. Do not fit to collider height.'},'nativeImportStatus':'PENDING'}
    (HERE/'canonical-course-vehicles-pack.json').write_text(json.dumps(result,indent=2)+'\n');return result

def main():
    sources={v['kind']:v for v in json.loads((HERE/'vehicle-source-catalog.json').read_text())['vehicles']};entries={};reports={}
    for kind,builder in BUILDERS.items():
        o=builder();geo.EXPECTED[kind]=list(o.parts)
        o.reference=['assets/vehicles/canonical-course/vehicle-source-catalog.json','https://github.com/feos-tas/DisAssemble/tree/'+PIN+'/Battletoads']
        o.sourceTrace=sources[kind];o.sourcePalette={'colors':sources[kind]['rgbColors'],'scope':'Representative source vehicle palette; RGB illustrative; recurring palette loops not reproduced.'}
        report=geo.validate(o);assert report['triangles']<=12000,(kind,report)
        assert max(v[1] for v in o.parts['Body'].vertices)<=0,(kind,'hull crosses rider deck')
        used=set(c for m in o.parts.values() for c in m.colors);assert used.issubset(set(map(tuple,sources[kind]['rgbColors']))),(kind,used)
        entry=geo.export(o,HERE/kind);entry.update(deckTop=0,deckLength=FOOTPRINTS[kind][0],deckWidth=FOOTPRINTS[kind][1]);entries[kind]=entry;reports[kind]=report
        rigpath=HERE/kind/(kind+'-rig.json');rig=json.loads(rigpath.read_text());rig['coordinateSystem']='Y-up forward-Z; deck top Y0 at XZ centre; cosmetic hull below deck, handlebars ahead of rider.';rig['deck']={'top':0,'length':FOOTPRINTS[kind][0],'width':FOOTPRINTS[kind][1]};rigpath.write_text(json.dumps(rig,indent=2)+'\n')
        render.render(o,HERE/kind/'turntable.png',size=(900,420),azimuths=(0,40,90))
        print(kind,entry['triangles'],entry['bytes'],flush=True)
    manifest={'schema':1,'sourcePin':PIN,'scope':'Four closed low-cost textured authored3D vehicles; source silhouette and source palettes; no runtime changes.','families':entries}
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    result=pack(entries)
    from PIL import Image,ImageDraw
    sheet=Image.new('RGB',(900,4*450),(25,32,39));draw=ImageDraw.Draw(sheet)
    for i,kind in enumerate(BUILDERS):sheet.paste(Image.open(HERE/kind/'turntable.png'),(0,i*450));draw.text((12,i*450+425),kind+' | source palette / authored3D depth',fill='white')
    sheet.save(HERE/'vehicle-model-contact-sheet.png')
    (HERE/'validation.json').write_text(json.dumps({'schema':1,'status':'PASS','sourcePin':PIN,'families':reports,'combined':{k:result[k] for k in ('sha256','bytes','familyCount','meshCount')},'softwarePreview':'vehicle-model-contact-sheet.png','nativeImport':'PENDING'},indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('sha256','bytes','familyCount','meshCount')},indent=2))
if __name__=='__main__':main()
