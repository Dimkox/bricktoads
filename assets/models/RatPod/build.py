"""Build the two airborne hazard packages and their shared Roblox visual constructor.

Run in this checkout using Python with numpy and Pillow. Editable design.py files
use studs, Y-up, local -Z forward and Roblox CFrame.Angles (XYZ radians at runtime).
"""
from collections import Counter
from importlib.util import module_from_spec, spec_from_file_location
from math import cos, pi, radians, sin
from pathlib import Path
import io
import json
import struct
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def load(name, path):
    spec = spec_from_file_location(name, path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


geo = load('cast_geometry', ROOT / 'assets/characters/canonical-cast/build_cast.py')
renderer = load('prop_renderer', ROOT / 'assets/props/canonical-course/render_course_props.py')
KINDS = {'RatPod': ('BT-91', [5400, 2600, 900]), 'Meteorite': ('BT-95', [3600, 1600, 500])}


def rotation(angles):
    a, b, c = map(radians, angles)
    ca, cb, cc, sa, sb, sc = cos(a), cos(b), cos(c), sin(a), sin(b), sin(c)
    return np.array([[cb*cc, -cb*sc, sb], [ca*sc+sa*sb*cc, ca*cc-sa*sb*sc, -sa*cb],
                     [sa*sc-ca*sb*cc, sa*cc+ca*sb*sc, ca*cb]])


def polyhedron(mesh, points, sides, color):
    triangles = [(face[0], face[i], face[i+1]) for face in sides for i in range(1, len(face)-1)]
    mesh.append(points, triangles, color)


def surface(shape, size, color, resolution):
    m = geo.Mesh('surface')
    a, b, c = [s / 2 for s in size]
    n, rings = resolution
    if shape == 'Ball':
        geo.ellipsoid(m, (0, 0, 0), (a, b, c), color, n, rings)
    elif shape == 'Cylinder':
        geo.tube(m, [(-a, 0, 0, b, c), (a, 0, 0, b, c)], color, n, 1)
    elif shape == 'Wedge':
        polyhedron(m, [(-a,-b,-c),(a,-b,-c),(-a,-b,c),(a,-b,c),(-a,b,c),(a,b,c)],
                   [(0,1,3,2),(2,3,5,4),(4,5,1,0),(0,2,4),(1,5,3)], color)
    else:
        pts = [(x*a,y*b,z*c) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                                            (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        polyhedron(m, pts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)], color)
    return m


def geometry(kind, rows, lod):
    model = geo.Model(kind)
    for group, name, shape, size, pos, color, material, rot in rows:
        if lod == 2 and (name.startswith(('Intake','Reflected','Collar','Dimple'))):
            continue
        if lod == 2 and name.startswith('Tongue'):
            if not name.endswith('_1'):
                continue
            size = (size[0]*1.2, size[1]*1.2, size[2]*1.85)
            pos = (pos[0], pos[1], pos[2]+.30)
        major = name in {'PressureHull','SmokedCanopy','GoldenLimb','WhiteFront','Keel','CanopyFrame'}
        resolution = ([(20,10),(12,7),(8,4)] if major else [(10,4),(6,3),(5,3)])[lod]
        part = surface(shape, size, color, resolution)
        verts = (np.array(part.vertices) @ rotation(rot).T + np.array(pos)).tolist()
        mesh = model.parts.get(group) or model.part(group, parent=None)
        mesh.append(verts, part.faces, color)
    return model


def atlas(rows, target):
    colors = sorted({tuple(row[5]) for row in rows})
    width = 16*len(colors)
    uv = {color: ((i+.5)/len(colors), .5) for i,color in enumerate(colors)}
    labels = {'Metal': (132, 176), 'SmoothPlastic': (146, 0), 'Neon': (81, 0)}
    paint = {tuple(row[5]): labels[row[6]] for row in rows}
    layers = []
    for name in ('color','roughness-metalness','normal'):
        img = Image.new('RGB',(width,16))
        for i, color in enumerate(colors):
            roughness, metalness = paint[color]
            pixel = {'color': color, 'roughness-metalness': (255,roughness,metalness), 'normal': (128,128,255)}[name]
            img.paste(pixel, (16*i,0,16*(i+1),16))
        out = io.BytesIO()
        img.save(out, format='PNG')
        layers.append(out.getvalue())
        (target/(name+'.png')).write_bytes(layers[-1])
    return uv, layers


def export(model, path, uv, images):
    buffer = bytearray()
    views, accessors, meshes = [], [], []

    def view(data):
        buffer.extend(b'\0' * (-len(buffer)%4))
        views.append({'buffer': 0,'byteOffset': len(buffer),'byteLength':len(data)})
        buffer.extend(data)
        return len(views)-1

    def attr(values, typ):
        arr = np.array(values, dtype='<u2' if typ == 'SCALAR' else '<f4')
        entry = {'bufferView':view(arr.tobytes()), 'componentType':5123 if typ=='SCALAR' else 5126,
                 'type':typ, 'count':len(arr)}
        if typ == 'VEC3':
            entry.update(min=arr.min(axis=0).tolist(), max=arr.max(axis=0).tolist())
        accessors.append(entry)
        return len(accessors)-1

    for name, m in model.parts.items():
        primitive = {'attributes':{'POSITION':attr(np.array(m.vertices)*.28,'VEC3'),
                                   'NORMAL':attr(m.normals(),'VEC3'),'TEXCOORD_0':attr([uv[c] for c in m.colors],'VEC2')},
                     'indices':attr(np.asarray(m.faces).flatten(),'SCALAR'), 'material':0}
        meshes.append({'name':name,'primitives':[primitive]})
    scene = {'asset':{'version':'2.0','generator':'BrickToads airborne hazard builder'},
             'scene':0,'scenes':[{'nodes':list(range(len(meshes)))}],
             'nodes':[{'name':m['name'],'mesh':i} for i,m in enumerate(meshes)], 'meshes':meshes,
             'accessors':accessors,'bufferViews':views,
             'images':[{'bufferView':view(data),'mimeType':'image/png'} for data in images],
             'textures':[{'source':i} for i in range(3)],
             'materials':[{'name':'HazardPalette','pbrMetallicRoughness':{'baseColorTexture':{'index':0},
                           'metallicRoughnessTexture':{'index':1}},'normalTexture':{'index':2}}],
             'buffers':[{'byteLength':len(buffer)}]}
    raw = json.dumps(scene,separators=(',',':')).encode()
    raw += b' '*(-len(raw)%4)
    buffer.extend(b'\0'*(-len(buffer)%4))
    path.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(raw)+len(buffer))+struct.pack('<I4s',len(raw),b'JSON')+
                     raw+struct.pack('<I4s',len(buffer),b'BIN\0')+buffer)

def assembly(kind, rows, points, path):
    xml = ET.Element('roblox', version='4')
    def node(parent, cls, name):
        item = ET.SubElement(parent, 'Item', {'class':cls,'referent':'RBX'+name})
        p = ET.SubElement(item, 'Properties')
        ET.SubElement(p,'string',name='Name').text=name
        return item, p
    def prop(p, typ, name, val):
        ET.SubElement(p, typ, name=name).text = str(val)
    def vector(p, name, v):
        child = ET.SubElement(p,'Vector3',name=name)
        for key,value in zip('XYZ',v): ET.SubElement(child,key).text=str(value)
    def cf(p, pos, rot):
        child = ET.SubElement(p,'CoordinateFrame',name='CFrame')
        for key,value in zip('XYZ',pos): ET.SubElement(child,key).text=str(value)
        for i,row in enumerate(rotation(rot)):
            for j,value in enumerate(row): ET.SubElement(child,f'R{i}{j}').text=str(value)
    def part(parent, name, shape, size, pos, color, material, rot):
        item,p=node(parent,'WedgePart' if shape=='Wedge' else 'Part',name)
        if shape!='Wedge': prop(p,'token','shape',{'Block':1,'Ball':0,'Cylinder':2}[shape])
        vector(p,'size',size)
        cf(p,pos,rot)
        prop(p,'Color3uint8','Color3uint8',(255<<24)+(color[0]<<16)+(color[1]<<8)+color[2])
        prop(p,'token','Material',{'Metal':1088,'SmoothPlastic':272,'Neon':288}[material])
        for flag in ('CanCollide','CanTouch','CanQuery','Anchored','CastShadow'):
            prop(p,'bool',flag,'false')
        prop(p,'bool','Massless','true')
        return item,p
    model, mp=node(xml,'Model',kind)
    prop(mp,'Ref','PrimaryPart','RBXVisualRoot')
    root,rp=part(model,'VisualRoot','Block',(.1,.1,.1),(0,0,0),(0,0,0),'SmoothPlastic',(0,0,0))
    prop(rp,'float','Transparency',1)
    groups={}
    for section,name,shape,size,pos,color,material,rot in rows:
        if section not in groups: groups[section]=node(model,'Model',section)[0]
        item,p=part(groups[section],name,shape,size,pos,color,material,rot)
        _,w=node(item,'Weld','Weld'+name)
        prop(w,'Ref','Part0','RBXVisualRoot')
        prop(w,'Ref','Part1','RBX'+name)
        cf(w,pos,rot)
        w.find('CoordinateFrame').set('name','C0')
    origin=points['TrailOrigin']
    width=.38 if kind=='Meteorite' else .18
    attachments={**points,'TrailLeft':(-width,0,origin[2]),'TrailRight':(width,0,origin[2])}
    for name,pos in attachments.items():
        item,p=node(root,'Attachment',name)
        cf(p,pos,(0,180,0) if name=='Exhaust' else (0,0,0))
        if name=='ImpactVFX' and kind=='Meteorite':
            _,burst=node(item,'ParticleEmitter','ImpactBurst')
            prop(burst,'bool','Enabled','false')
            prop(burst,'float','Rate',0)
            prop(burst,'NumberRange','Lifetime','0.12 0.24')
            prop(burst,'NumberRange','Speed','2 5')
            prop(burst,'ColorSequence','Color','0 1 0.95 0.54 0 1 1 0.60 0.11 0')
            prop(burst,'NumberSequence','Size','0 0.34 0 1 0 0')
    _, trail=node(root,'Trail','TrailEmitter')
    prop(trail,'Ref','Attachment0','RBXTrailLeft')
    prop(trail,'Ref','Attachment1','RBXTrailRight')
    prop(trail,'float','Lifetime',.14 if kind=='Meteorite' else .10)
    prop(trail,'float','MaxLength',1.6 if kind=='Meteorite' else 1)
    prop(trail,'bool','FaceCamera','true')
    prop(trail,'NumberSequence','Transparency','0 0.3 0 1 1 0')
    prop(trail,'NumberSequence','WidthScale','0 1 0 1 0 0')
    rgb='1 0.85 0.24' if kind=='Meteorite' else '0.33 0.90 0.91'
    prop(trail,'ColorSequence','Color',f'0 {rgb} 0 1 {rgb} 0')
    ET.indent(xml)
    ET.ElementTree(xml).write(path, encoding='utf-8',xml_declaration=True)


def lua(value):
    if isinstance(value,(list,tuple)):
        return '{'+', '.join(map(lua,value))+'}'
    if isinstance(value,float): return f'{value:.9g}'
    return json.dumps(value)


def build():
    definitions=['-- Geometry generated from assets/models/{RatPod,Meteorite}/design.py.','local designs = {']
    for kind,(issue,budgets) in KINDS.items():
        target=HERE.parent/kind
        design=load(kind,target/'design.py')
        rows=[]
        design.shapes(lambda *row: rows.append(row))
        uv,images=atlas(rows,target)
        lods=[]
        definitions.extend(['    '+kind+' = {','        parts = {'])
        definitions.extend('            '+lua(row)+',' for row in rows)
        definitions.append('        },')
        definitions.append('        points = {'+', '.join(k+' = '+lua(v) for k,v in design.ATTACHMENTS.items())+'},')
        definitions.append('    },')
        for lod,budget in enumerate(budgets):
            model=geometry(kind,rows,lod)
            count=sum(len(m.faces) for m in model.parts.values())
            assert count<=budget,(kind,lod,count,budget)
            for name,m in model.parts.items():
                edges=Counter(tuple(sorted((a,b))) for tri in m.faces for a,b in zip(tri,tri[1:]+tri[:1]))
                assert all(n==2 for n in edges.values()),name
                assert all(abs(np.linalg.norm(n)-1)<1e-5 for n in m.normals()), name
            file=f'{kind}-L{lod}.glb'
            export(model,target/file,uv,images)
            lods.append({'file':file,'triangles':count,'parts':{k:len(m.faces) for k,m in model.parts.items()}})
            if lod==0:
                bounds=geo.bounds([v for m in model.parts.values() for v in m.vertices])
                renderer.render(model,target/'turntable.png',(1600,380),(0,46,90,180))
                assembly(kind,rows,design.ATTACHMENTS,target/(kind+'.rbxmx'))
        points={name:list(pos)+rotation((0,180,0) if name=='Exhaust' else (0,0,0)).flatten().tolist()
                for name,pos in design.ATTACHMENTS.items()}
        metadata={'issue':issue,'kind':kind,'units':'stud','metresPerStud':.28,'up':'+Y','forward':'-Z',
                  'reference':'assets/concept-art/uhd-cast-2026-11-09/enemies-02-uhd.png',
                  'pivot':[0,0,0],'bounds':bounds,'lods':lods,'attachmentsCFrame':points,'states':design.STATES,
                  'proxy':{'authority':'course','center':[0,0,0],'nominalBodySize':[2.5,2.5,2.5] if kind=='Meteorite' else [2.5,2.2,4.9],
                           'visualCollision':False,'trailCollision':False},
                  'textures':['color.png','normal.png','roughness-metalness.png'],
                  'impactBurst':{'count':8,'maximumLifetime':.24} if kind=='Meteorite' else None,
                  'assembly':'Roblox native primitives welded to VisualRoot; GLBs use the same authoring dimensions.'}
        (target/'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
        print(kind,[x['triangles'] for x in lods])
    definitions.extend(['}',''])
    module=ROOT/'src/server/gameplay/AirHazardModels.lua'
    marker='-- END OF GENERATED DESIGNS'
    body=module.read_text(encoding='utf-8-sig').split(marker,1)[1]
    module.write_text('\n'.join(definitions)+marker+body,encoding='utf-8')


if __name__=='__main__':
    build()
