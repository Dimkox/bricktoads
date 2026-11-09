"""Author a segmented 3D study from the pinned NES hero reference.

Pure Python: smooth swept surfaces, GLB/OBJ writer, numerical validation and a
software turntable renderer. No ROM data or source sprite is embedded in GLB.
Depth, anatomical landmarks and a neutral symmetric rest pose are adaptations.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PREVIEW = ROOT / "research/canonical-visuals/hero-model-turntable.png"
REFERENCE = ROOT / "research/canonical-visuals/hero-idle-proportions.json"
PIN = "f1a43b69577246850d136473700a333b3cdfe93f"
METRES_PER_STUD = .28
def linear_color(rgb): return tuple(v**2.2 for v in rgb)+(1.,)
GREEN = linear_color((.29, .72, .04))
DARK = linear_color((.025, .25, .012))
BLACK = linear_color((.018, .028, .012))


def add(a, b): return tuple(x+y for x, y in zip(a, b))
def sub(a, b): return tuple(x-y for x, y in zip(a, b))
def mul(a, s): return tuple(x*s for x in a)
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a, a))
def unit(a): return mul(a, 1/max(length(a), 1e-12))
def signpow(v, p): return math.copysign(abs(v)**p, v)


PIVOTS = {
    "LowerTorso": (0, -.12, .05), "UpperTorso": (0, .14, .04), "Head": (0, 1.88, -.03),
    "LeftUpperArm": (-1.03, 1.47, .0), "RightUpperArm": (1.03, 1.47, .0),
    "LeftLowerArm": (-1.68, .58, .03), "RightLowerArm": (1.68, .58, .03),
    "LeftHand": (-1.76, -.18, -.13), "RightHand": (1.76, -.18, -.13),
    "LeftUpperLeg": (-.50, -.30, .04), "RightUpperLeg": (.50, -.30, .04),
    "LeftLowerLeg": (-.72, -1.46, -.13), "RightLowerLeg": (.72, -1.46, -.13),
    "LeftFoot": (-.75, -2.60, .14), "RightFoot": (.75, -2.60, .14),
}
HIERARCHY = {
    "LowerTorso": None, "UpperTorso": "LowerTorso", "Head": "UpperTorso",
    **{s+"UpperArm": "UpperTorso" for s in ("Left", "Right")},
    **{s+"LowerArm": s+"UpperArm" for s in ("Left", "Right")},
    **{s+"Hand": s+"LowerArm" for s in ("Left", "Right")},
    **{s+"UpperLeg": "LowerTorso" for s in ("Left", "Right")},
    **{s+"LowerLeg": s+"UpperLeg" for s in ("Left", "Right")},
    **{s+"Foot": s+"LowerLeg" for s in ("Left", "Right")},
}
JOINT_NAMES = {
    "UpperTorso": "Waist", "Head": "Neck",
    **{s+"UpperArm": s+"Shoulder" for s in ("Left", "Right")},
    **{s+"LowerArm": s+"Elbow" for s in ("Left", "Right")},
    **{s+"Hand": s+"Wrist" for s in ("Left", "Right")},
    **{s+"UpperLeg": s+"Hip" for s in ("Left", "Right")},
    **{s+"LowerLeg": s+"Knee" for s in ("Left", "Right")},
    **{s+"Foot": s+"Ankle" for s in ("Left", "Right")},
}


class Mesh:
    def __init__(self, name):
        self.name, self.vertices, self.faces, self.colors = name, [], [], []

    def append(self, vertices, faces, color=GREEN):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(i+offset for i in face) for face in faces)
        self.colors.extend([color]*len(vertices))

    def normals(self):
        normals = [(0., 0., 0.) for _ in self.vertices]
        for a, b, c in self.faces:
            n = cross(sub(self.vertices[b], self.vertices[a]), sub(self.vertices[c], self.vertices[a]))
            for i in (a, b, c): normals[i] = add(normals[i], n)
        return [unit(n) for n in normals]


def catmull(a, b, c, d, t):
    return tuple(.5*((2*y)+(-x+z)*t+(2*x-5*y+4*z-w)*t*t+(-x+3*y-3*z+w)*t*t*t)
                 for x, y, z, w in zip(a, b, c, d))


def sweep(mesh, controls, color=GREEN, radial=18, steps=3, angular_power=1.):
    """Each control is x,y,z, first radius, second radius; caps are closed."""
    samples = []
    for i in range(len(controls)-1):
        a, b = controls[max(0, i-1)], controls[i]
        c, d = controls[i+1], controls[min(len(controls)-1, i+2)]
        for k in range(steps): samples.append(catmull(a, b, c, d, k/steps))
    samples.append(controls[-1])
    vertices, faces = [], []
    for i, row in enumerate(samples):
        center = row[:3]
        axis = unit(sub(samples[min(i+1, len(samples)-1)][:3], samples[max(0, i-1)][:3]))
        reference = (0, 0, 1) if abs(axis[2]) < .8 else (0, 1, 0)
        right = unit(cross(axis, reference)); other = unit(cross(right, axis))
        for j in range(radial):
            theta = j/radial*math.tau
            point = add(center, add(mul(right, signpow(math.cos(theta), angular_power)*max(.004, row[3])),
                                    mul(other, signpow(math.sin(theta), angular_power)*max(.004, row[4]))))
            vertices.append(point)
        if i:
            for j in range(radial):
                a, b = (i-1)*radial+j, (i-1)*radial+(j+1)%radial
                c, d = i*radial+j, i*radial+(j+1)%radial
                faces.extend(((a, c, b), (b, c, d)))
    begin, end = len(vertices), len(vertices)+1
    vertices.extend((samples[0][:3], samples[-1][:3]))
    last = (len(samples)-1)*radial
    for j in range(radial):
        faces.extend(((begin, j, (j+1)%radial), (end, last+(j+1)%radial, last+j)))
    mesh.append(vertices, faces, color)


def ellipsoid(mesh, center, radius, color=GREEN, radial=18, rings=10):
    controls = []
    for i in range(rings+1):
        angle = -.5*math.pi+math.pi*i/rings
        controls.append((center[0], center[1]+math.sin(angle)*radius[1], center[2],
                         max(.004, math.cos(angle)*radius[0]), max(.004, math.cos(angle)*radius[2])))
    sweep(mesh, controls, color, radial, 1)


def build_meshes():
    meshes = {name: Mesh(name) for name in PIVOTS}
    sweep(meshes["LowerTorso"], [(0,-.55,.06,.42,.31),(0,-.32,.07,.63,.43),
        (0,-.10,.03,.64,.40),(0,.16,.02,.56,.35),(0,.29,.02,.52,.32)], radial=24)
    sweep(meshes["UpperTorso"], [(0,.10,.03,.52,.33),(0,.43,.01,.68,.42),
        (0,.83,0,.94,.49),(0,1.17,0,1.10,.55),(0,1.46,.035,1.13,.48),
        (0,1.68,.06,.86,.38),(0,1.87,.04,.37,.29)], radial=28, angular_power=.92)
    # Shallow anatomy is sculpted into the continuous torso surface.
    chest = meshes["UpperTorso"]
    chest.vertices = [(x,y,z-.16*math.exp(-((abs(x)-.43)/.40)**2-((y-1.10)/.40)**2)
                       *max(0,min(1,-z/.40))) for x,y,z in chest.vertices]
    ellipsoid(meshes["LowerTorso"], (0,.14,.04), (.55,.24,.35), GREEN, 20, 8)
    head = meshes["Head"]
    ellipsoid(head, (0,1.86,-.02), (.36,.33,.30), GREEN, 16, 8)
    sweep(head, [(0,1.84,-.01,.35,.26),(0,2.04,-.13,.65,.43),
        (0,2.16,-.22,.80,.65),(0,2.34,-.21,.82,.69),
        (0,2.53,-.04,.72,.49),(0,2.74,.07,.60,.38),
        (0,2.90,.09,.43,.28),(0,2.97,.08,.12,.10)], radial=28, angular_power=.76)
    # Sculpted muzzle seam, separate nostrils and green-lidded eyes: no sunglasses.
    sweep(head, [(-.64,2.20,-.70,.025,.025),(-.40,2.17,-.88,.025,.025),
        (0,2.16,-.947,.027,.027),(.40,2.17,-.88,.025,.025),(.64,2.20,-.70,.020,.020)], BLACK, 10, 3)
    for side in (-1, 1):
        ellipsoid(head, (side*.43,2.72,-.39), (.25,.235,.18), GREEN, 18, 10)
        ellipsoid(head, (side*.44,2.70,-.55), (.14,.145,.048), DARK, 16, 8)
        ellipsoid(head, (side*.445,2.71,-.59), (.060,.105,.025), BLACK, 14, 8)
        sweep(head, [(side*.16,2.79,-.50,.065,.055),(side*.39,2.94,-.51,.090,.075),
            (side*.67,2.93,-.35,.080,.055)], GREEN, 12, 3)
        ellipsoid(head, (side*.22,2.48,-.862), (.067,.034,.022), BLACK, 12, 6)
    for side, name in ((-1, "Left"), (1, "Right")):
        sweep(meshes[name+"UpperArm"], [(side*.94,1.51,.02,.34,.35),
            (side*1.24,1.29,.04,.46,.43),(side*1.48,.98,.055,.37,.35),
            (side*1.68,.58,.03,.265,.26)], radial=20)
        # Joint-centred inner volumes stay at the same pivot during rotation,
        # covering the capped surface ends without moving the physical rig.
        ellipsoid(meshes[name+"UpperArm"], PIVOTS[name+"UpperArm"], (.42,.43,.40), GREEN, 18, 8)
        sweep(meshes[name+"LowerArm"], [(side*1.66,.62,.04,.27,.27),
            (side*1.75,.35,-.01,.36,.32),(side*1.78,.04,-.07,.32,.27),
            (side*1.76,-.22,-.13,.21,.22)], radial=20)
        ellipsoid(meshes[name+"LowerArm"], PIVOTS[name+"LowerArm"], (.285,.30,.285), GREEN, 16, 8)
        hand = meshes[name+"Hand"]
        ellipsoid(hand, PIVOTS[name+"Hand"], (.23,.24,.23), GREEN, 14, 6)
        ellipsoid(hand, (side*1.77,-.48,-.17), (.36,.40,.28), GREEN, 20, 10)
        for finger in (-1, 0, 1):
            x = side*1.77+finger*.205
            sweep(hand, [(x,-.42,-.33,.125,.13),(x,-.66,-.39,.135,.13),
                (x,-.80,-.32,.13,.12),(x,-.70,-.20,.105,.10)], GREEN, 12, 3)
        sweep(hand, [(side*1.48,-.35,-.12,.16,.15),(side*1.40,-.48,-.30,.17,.16),
            (side*1.49,-.62,-.40,.135,.13)], GREEN, 14, 3)
        # Defined knee, calf and ankle silhouettes; long lower limbs from reference.
        sweep(meshes[name+"UpperLeg"], [(side*.47,-.29,.08,.36,.37),
            (side*.62,-.58,.02,.44,.42),(side*.72,-.91,-.07,.38,.35),
            (side*.73,-1.22,-.14,.28,.27),(side*.72,-1.48,-.13,.245,.255)], radial=20)
        ellipsoid(meshes[name+"UpperLeg"], PIVOTS[name+"UpperLeg"], (.35,.36,.35), GREEN, 16, 8)
        sweep(meshes[name+"LowerLeg"], [(side*.72,-1.43,-.13,.25,.26),
            (side*.73,-1.76,.005,.34,.32),(side*.74,-2.08,.13,.28,.26),
            (side*.75,-2.38,.15,.18,.19),(side*.75,-2.66,.13,.17,.17)], radial=20)
        ellipsoid(meshes[name+"LowerLeg"], PIVOTS[name+"LowerLeg"], (.27,.29,.28), GREEN, 16, 8)
        foot = meshes[name+"Foot"]
        ellipsoid(foot, PIVOTS[name+"Foot"], (.20,.22,.20), GREEN, 14, 6)
        sweep(foot, [(side*.75,-2.78,.35,.12,.12),(side*.76,-2.80,.12,.26,.19),
            (side*.80,-2.85,-.25,.36,.15),(side*.85,-2.87,-.73,.49,.12),
            (side*.87,-2.88,-1.12,.46,.09),(side*.88,-2.88,-1.27,.25,.045)], radial=20)
        for toe in (-1, 0, 1):
            x = side*.87+toe*.30
            sweep(foot, [(x,-2.86,-.80,.16,.12),(x+side*.04,-2.88,-1.12,.185,.10),
                (x+side*.07,-2.88,-1.40+abs(toe)*.10,.11,.065)], GREEN, 12, 3)
    return meshes


def bounds(vertices):
    return [[min(v[a] for v in vertices) for a in range(3)], [max(v[a] for v in vertices) for a in range(3)]]


def export_glb(meshes, path):
    data = bytearray(); views = []; accessors = []; nodes = []; gltf_meshes = []
    def accessor(values, component, kind, *, minimum=None, maximum=None, target=34962):
        while len(data)%4: data.append(0)
        offset = len(data)
        flattened = [x for row in values for x in row] if isinstance(values[0], (list, tuple)) else values
        data.extend(struct.pack('<'+str(len(flattened))+{5126:'f',5123:'H'}[component], *flattened))
        view = len(views);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':target})
        entry={'bufferView':view,'componentType':component,'count':len(values),'type':kind}
        if minimum is not None: entry['min']=minimum;entry['max']=maximum
        accessors.append(entry);return len(accessors)-1
    names=list(meshes); lookup={n:i for i,n in enumerate(names)}
    for name, mesh in meshes.items():
        vertices=[mul(sub(v,PIVOTS[name]),METRES_PER_STUD) for v in mesh.vertices]
        b=bounds(vertices)
        attrs={'POSITION':accessor(vertices,5126,'VEC3',minimum=b[0],maximum=b[1]),
               'NORMAL':accessor(mesh.normals(),5126,'VEC3'),
               'COLOR_0':accessor(mesh.colors,5126,'VEC4')}
        index=accessor([i for f in mesh.faces for i in f],5123,'SCALAR',target=34963)
        gltf_meshes.append({'name':name,'primitives':[{'attributes':attrs,'indices':index,'material':0}]})
        parent=HIERARCHY[name]
        translation=sub(PIVOTS[name],PIVOTS[parent]) if parent else PIVOTS[name]
        node={'name':name,'mesh':lookup[name],'translation':list(mul(translation,METRES_PER_STUD))}
        children=[lookup[n] for n,p in HIERARCHY.items() if p==name]
        if children:node['children']=children
        nodes.append(node)
    scene={'asset':{'version':'2.0','generator':'BrickToads canonical-reference loft study',
            'extras':{'metresPerStud':METRES_PER_STUD,'authoringUnits':'Roblox studs','glTFUnits':'metres'}},
        'scene':0,'scenes':[{'name':'CanonicalHeroStudy','nodes':[lookup['LowerTorso']]}],
        'nodes':nodes,'meshes':gltf_meshes,'accessors':accessors,'bufferViews':views,
        'buffers':[{'byteLength':len(data)}],
        'materials':[{'name':'SourcePaletteVertexColor','pbrMetallicRoughness':
            {'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.82},'doubleSided':False}]}
    chunk=json.dumps(scene,separators=(',',':')).encode();chunk+=b' '*((-len(chunk))%4)
    data+=b'\0'*((-len(data))%4)
    total=12+8+len(chunk)+8+len(data)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(chunk),b'JSON')+chunk+
                     struct.pack('<I4s',len(data),b'BIN\0')+data)
    return scene


def export_obj(meshes, path):
    rows=['# Canonical-reference 3D study; vertex colour extension. Y-up; forward -Z.']
    offset=1
    for name,mesh in meshes.items():
        rows.append('o '+name)
        for v,c in zip(mesh.vertices,mesh.colors):rows.append('v '+' '.join(f'{x:.7f}' for x in (*v,*c[:3])))
        for f in mesh.faces:rows.append('f '+' '.join(str(i+offset) for i in f))
        offset+=len(mesh.vertices)
    path.write_text('\n'.join(rows)+'\n',encoding='utf-8')


def png(path,width,height,pixels):
    def chunk(kind,payload):return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    raw=b''.join(b'\0'+bytes(pixels[y*width*3:(y+1)*width*3]) for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+
                     chunk(b'IDAT',zlib.compress(raw,8))+chunk(b'IEND',b''))


def render(meshes, path=PREVIEW):
    width,height,panel=1440,650,480
    pixels=bytearray((23,31,34)*(width*height)); depth=[-1e10]*(width*height)
    light=unit((-.6,.9,-.7))
    projected_bounds={}
    for pi,(name,azimuth) in enumerate((('front',0),('threeQuarter',40),('side',90))):
        az=math.radians(azimuth);el=math.radians(7)
        d=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el))
        right=(math.cos(az),0,math.sin(az));up=cross(right,d)
        scale=86.;cx=pi*panel+panel/2;cy=height/2+4
        all2=[]
        for mesh in meshes.values():
            positions=[];colors=[]
            for v,n,c in zip(mesh.vertices,mesh.normals(),mesh.colors):
                x,y,z=dot(v,right),dot(v,up),dot(v,d)
                positions.append((cx+x*scale,cy-y*scale,z));all2.append((x,y))
                lum=.40+.60*max(0,dot(n,light))
                colors.append(tuple(min(255,int((max(0,a*lum)**(1/2.2))*255)) for a in c[:3]))
            for a,b,c in mesh.faces:
                p,q,r=positions[a],positions[b],positions[c]
                area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-7:continue
                minx=max(pi*panel,int(min(p[0],q[0],r[0])));maxx=min((pi+1)*panel-1,int(max(p[0],q[0],r[0]))+1)
                miny=max(0,int(min(p[1],q[1],r[1])));maxy=min(height-1,int(max(p[1],q[1],r[1]))+1)
                for y in range(miny,maxy+1):
                    for x in range(minx,maxx+1):
                        u=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area
                        v=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area
                        w=1-u-v
                        if u<0 or v<0 or w<0:continue
                        z=u*p[2]+v*q[2]+w*r[2];index=y*width+x
                        if z<=depth[index]:continue
                        depth[index]=z
                        for channel in range(3):pixels[index*3+channel]=int(u*colors[a][channel]+v*colors[b][channel]+w*colors[c][channel])
        projected_bounds[name]={'width':max(p[0] for p in all2)-min(p[0] for p in all2),
            'height':max(p[1] for p in all2)-min(p[1] for p in all2)}
        projected_bounds[name]['ratio']=projected_bounds[name]['width']/projected_bounds[name]['height']
    png(path,width,height,pixels)
    return projected_bounds


def rotated_study(meshes):
    """Articulation probe only, not an invented canonical animation."""
    def matmul(a,b):return tuple(tuple(sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
    def apply(a,v):return tuple(dot(row,v) for row in a)
    def rotation(x,y,z):
        cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
        return matmul(((cz,-sz,0),(sz,cz,0),(0,0,1)),matmul(((cy,0,sy),(0,1,0),(-sy,0,cy)),((1,0,0),(0,cx,-sx),(0,sx,cx))))
    identity=rotation(0,0,0)
    angles={'LeftUpperArm':(-.65,0,-.2),'LeftLowerArm':(-1.0,0,0),'RightUpperArm':(.75,0,.15),
        'RightLowerArm':(-.7,0,0),'LeftUpperLeg':(.5,0,0),'LeftLowerLeg':(-.8,0,0),
        'RightUpperLeg':(-.4,0,0),'RightLowerLeg':(-.3,0,0),'Head':(0,.25,0)}
    transforms={};result={};errors=[]
    def transform(name):
        if name in transforms:return transforms[name]
        parent=HIERARCHY[name];local=rotation(*angles.get(name,(0,0,0)))
        if not parent:answer=(PIVOTS[name],local)
        else:
            position,orient=transform(parent)
            joint=add(position,apply(orient,sub(PIVOTS[name],PIVOTS[parent])))
            answer=(joint,matmul(orient,local))
            errors.append(length(sub(answer[0],joint)))
        transforms[name]=answer;return answer
    for name,m in meshes.items():
        position,orient=transform(name);posed=Mesh(name)
        posed.vertices=[add(position,apply(orient,sub(v,PIVOTS[name]))) for v in m.vertices]
        posed.faces=list(m.faces);posed.colors=list(m.colors);result[name]=posed
    return result,{'pose':'noncanonical hinge articulation probe','maximumJointAttachmentError':max(errors),
        'localEulerRadians':angles,'jointCaps':'closed overlapping joint-centred volumes on every articulated limb'}


def metadata(meshes,scene,projections):
    joints=[]
    for name,parent in HIERARCHY.items():
        if not parent:continue
        pivot=PIVOTS[name]
        joints.append({'name':JOINT_NAMES[name],'parent':parent,'child':name,'worldPosition':pivot,
            'parentAttachment':sub(pivot,PIVOTS[parent]),'childAttachment':[0,0,0]})
    envelope=bounds([v for m in meshes.values() for v in m.vertices])
    dimensions=sub(envelope[1],envelope[0])
    return {'schema':1,'status':'canonical-reference-3d-study-not-release-approved','sourcePin':PIN,
        'sourceReference':'research/canonical-visuals/frames/hero-01.png',
        'measuredSource':json.loads(REFERENCE.read_text(encoding='utf-8')),
        'adaptation':{'coordinateSystem':'right-handed Y-up, forward -Z, R6 torso anchor at origin',
            'rest':'symmetric neutral bent-limb stance; not a traced canonical animation frame',
            'depth':'inferred: original NES sprites do not specify depth or a3D skeleton',
            'scale':'six-stud hero envelope; physics body is external and unchanged',
            'gltfUnits':'GLB positions and node translations are scaled by.28 from authored stud coordinates to metres',
            'shoulderRestCorrectionRadians':0,'fidelity':'source-derived silhouette/palette target, not a claim of exact3D canon'},
        'units':{'gltfMetresPerStud':METRES_PER_STUD,
            'gltfMetres':{'width':dimensions[0]*METRES_PER_STUD,'height':dimensions[1]*METRES_PER_STUD,'depth':dimensions[2]*METRES_PER_STUD},
            'desiredRobloxStuds':{'width':dimensions[0],'height':dimensions[1],'depth':dimensions[2]},
            'importCorrection':'uniformScale = desiredRobloxStuds.height / measuredImportedHeightStuds',
            'rigJsonUnits':'all pivot, bounds, joint and head-feature values are Roblox studs unless explicitly labelledgltfMetres',
            'rootReference':[0,0,0],'rootMeaning':'existing R6 Torso/HumanoidRootPart origin, not the bounding-box centre'},
        'headFeatures':{'status':'inferred3D landmarks for future morph authoring, not source joint measurements',
            'coordinateSpace':'global authored model space, relative to R6 Torso root',
            'faceForward':[0,0,-1],'up':[0,1,0],
            'muzzleCenter':[0,2.32,-.90],'jawHinge':[0,2.13,-.02],
            'mouthCorners':[[-.64,2.20,-.70],[.64,2.20,-.70]],
            'leftEye':[-.44,2.70,-.55],'rightEye':[.44,2.70,-.55],
            'leftBrow':[-.39,2.94,-.51],'rightBrow':[.39,2.94,-.51],
            'futureFear':'source gfx32/33 requires separately authored open-mouth/eye morph; no valid morph is included yet'},
        'materials':'one matte material with per-vertex source-inspired black/darkgreen/green; no texture dependency',
        'parts':[{'name':n,'parent':HIERARCHY[n],'pivot':PIVOTS[n],
            'vertices':len(m.vertices),'triangles':len(m.faces),'localBounds':bounds([sub(v,PIVOTS[n]) for v in m.vertices])} for n,m in meshes.items()],
        'joints':joints,'projections':projections,'bounds':envelope,
        'animation':{'included':False,'reason':'source frame/state catalogue must drive later authored poses and morph geometry'},
        'importNotes':['GLB nodes form a15-part hierarchy; vertex colours must be checked in Studio import.',
            'Intended Roblox envelope is6.04studs tall; confirm actual imported height and scale all parts/joints uniformly.',
            'Material/part splitting by importer is not yet verified.',
            'Use per-joint rest metadata to create cosmetic Motor6D; do not copy explorer45degree shoulder correction.',
            'All cosmetic parts must be massless/noCollide/noTouch/noQuery; pin completed body to server.',
            'No Humanoid, physical root, script, gameplay state or collision mesh is included.']}


def validate(meshes,scene,path):
    payload=path.read_bytes();magic,version,total=struct.unpack('<4sII',payload[:12])
    assert magic==b'glTF' and version==2 and total==len(payload)
    assert len(scene['meshes'])==len(scene['nodes'])==15
    json_length=struct.unpack('<I',payload[12:16])[0]
    decoded=json.loads(payload[20:20+json_length])
    binary_start=20+json_length+8
    parent_by_child={child:i for i,n in enumerate(decoded['nodes']) for child in n.get('children',[])}
    def node_position(i):
        local=tuple(decoded['nodes'][i].get('translation',(0,0,0)))
        return add(node_position(parent_by_child[i]),local) if i in parent_by_child else local
    decoded_vertices=[]
    for i,node in enumerate(decoded['nodes']):
        primitive=decoded['meshes'][node['mesh']]['primitives'][0]
        accessor=decoded['accessors'][primitive['attributes']['POSITION']]
        view=decoded['bufferViews'][accessor['bufferView']]
        offset=binary_start+view.get('byteOffset',0)+accessor.get('byteOffset',0)
        for vertex in range(accessor['count']):
            point=struct.unpack_from('<fff',payload,offset+vertex*12)
            decoded_vertices.append(add(node_position(i),point))
    decoded_bounds=bounds(decoded_vertices)
    expected_bounds=[list(mul(b,METRES_PER_STUD)) for b in bounds([v for m in meshes.values() for v in m.vertices])]
    scale_error=max(abs(a-b) for row,expected in zip(decoded_bounds,expected_bounds) for a,b in zip(row,expected))
    assert scale_error<1e-5,scale_error
    count=0;min_area=math.inf
    for name,mesh in meshes.items():
        assert mesh.vertices and mesh.faces and len(mesh.vertices)<65536
        assert all(math.isfinite(x) for v in mesh.vertices for x in v)
        assert len(mesh.colors)==len(mesh.vertices)
        for a,b,c in mesh.faces:
            assert len({a,b,c})==3 and min(a,b,c)>=0 and max(a,b,c)<len(mesh.vertices)
            area=length(cross(sub(mesh.vertices[b],mesh.vertices[a]),sub(mesh.vertices[c],mesh.vertices[a])))
            min_area=min(min_area,area);assert area>1e-12,(name,area)
        assert all(abs(length(n)-1)<1e-6 for n in mesh.normals()),name
        count+=len(mesh.faces)
    assert count<=20000,count
    return {'status':'PASS','meshCount':15,'triangles':count,'vertices':sum(len(m.vertices) for m in meshes.values()),
        'allFinite':True,'indicesValid':True,'unitNormals':True,'minimumDoubledTriangleArea':min_area,
        'glbBytes':len(payload),'glbSha256':hashlib.sha256(payload).hexdigest(),
        'decodedGlbBoundsMetres':decoded_bounds,'decodedGlbHeightMetres':decoded_bounds[1][1]-decoded_bounds[0][1],
        'metreConversionMaximumError':scale_error,
        'limitations':['No Studio upload/import/render or runtime animation test has been performed.',
            'This is an authored3D study; only source2D bounds and palette indices are measured canon.']}


def main():
    meshes=build_meshes()
    target=HERE/'canonical-hero.glb'
    scene=export_glb(meshes,target)
    export_obj(meshes,HERE/'canonical-hero.obj')
    result=validate(meshes,scene,target)
    projections=render(meshes)
    posed,articulation=rotated_study(meshes)
    render(posed,ROOT/'research/canonical-visuals/hero-model-joint-bend-check.png')
    result['articulation']=articulation
    (HERE/'canonical-hero-rig.json').write_text(json.dumps(metadata(meshes,scene,projections),indent=2)+'\n',encoding='utf-8')
    (HERE/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
