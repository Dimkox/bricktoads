"""Validate and package the four mandatory uploaded course vehicle resources."""
from __future__ import annotations
import hashlib,json,math,re,struct
from pathlib import Path

PIN='f1a43b69577246850d136473700a333b3cdfe93f'
SOURCE_SHA256='637d406e20e3596f56f5f812027aecfb669d02ad5147d7f4db7ab22e022a7d46'
SOURCE_BYTES=303500
SOURCE_FILE='canonical-course-vehicles.glb'
DECKS={'Speeder':(5.6,2.4),'Surfboard':(5.6,2.1),'Jet':(6.2,4.6),'ClingerVehicle':(2.6,2.0)}
PARTS={
    'Speeder':{'Body','Nose','RiderDeck','Undercarriage','LeftEngine','LeftTailFin','LeftHandle','RightEngine','RightTailFin','RightHandle'},
    'Surfboard':{'Body','UpperShell','Deck','CentreStripe','TailCrest','BottomKeel','LeftFin','RightFin'},
    'Jet':{'Body','Nose','RiderDeck','CockpitRim','LeftWing','LeftIntake','LeftTailplane','RightWing','RightIntake','RightTailplane','TailFin','Exhaust'},
    'ClingerVehicle':{'Body','Wheel','Fork','RiderDeck','HandleStem','Handlebar'},
}
MESH_FIELDS={'name','meshId','textureId','meshSize','size','cframe','color','material','renderFidelity',
             'doubleSided','transparency','reflectance','attachments','surfaceAppearances'}
SURFACE_FIELDS={'name','colorMap','normalMap','roughnessMap','metalnessMap','color','alphaMode'}
REST_ROTATION=[-1,0,0,0,1,0,0,0,-1]

def _number(value,name,minimum=None,maximum=None):
    try:valid=type(value) in (int,float) and math.isfinite(value)
    except OverflowError:valid=False
    if not valid or minimum is not None and value<minimum or maximum is not None and value>maximum:
        raise ValueError('Invalid course number: '+name)
    return value

def _numbers(value,count,name,minimum=None,maximum=None):
    if not isinstance(value,list) or len(value)!=count:raise ValueError('Invalid course vector: '+name)
    for n in value:_number(n,name,minimum,maximum)
    return value

def _same(actual,expected,name,tolerance=.001):
    if len(actual)!=len(expected) or any(abs(a-b)>tolerance for a,b in zip(actual,expected)):
        raise ValueError('Course geometry differs from frozen source: '+name)

def _content(value,name,empty=True):
    if not isinstance(value,str) or not value and not empty or value and (
            not re.fullmatch(r'rbxassetid://[0-9]+',value) or int(value[13:])<=0):
        raise ValueError('Invalid course content: '+name)

def _json(raw):
    def unique(pairs):
        result={}
        for k,v in pairs:
            if k in result:raise ValueError('Duplicate course receipt field: '+k)
            result[k]=v
        return result
    return json.loads(raw,object_pairs_hook=unique)

def _source_parts(blob):
    """Derive exact rest bounds from the frozen GLB, not editable sidecar claims."""
    if struct.unpack_from('<4sII',blob)!=(b'glTF',2,len(blob)):raise ValueError('Invalid frozen course GLB')
    n,kind=struct.unpack_from('<I4s',blob,12)
    if kind!=b'JSON':raise ValueError('Frozen course GLB requires JSON chunk')
    scene=_json(blob[20:20+n]);nodes=scene['nodes'];meshes=scene['meshes'];parents={};result={}
    if len(nodes)!=36 or len(meshes)!=36:raise ValueError('Frozen course source requires36 mesh nodes')
    for index,node in enumerate(nodes):
        for child in node.get('children',[]):
            if child in parents:raise ValueError('Multiple course node parents')
            parents[child]=index
    def position(index,seen=None):
        seen=set() if seen is None else seen
        if index in seen:raise ValueError('Cyclic course GLB nodes')
        seen.add(index);node=nodes[index]
        if any(k in node for k in ('matrix','rotation','scale')):raise ValueError('Unexpected course source transform')
        xyz=node.get('translation',[0,0,0])
        if index in parents:xyz=[a+b for a,b in zip(xyz,position(parents[index],seen))]
        return xyz
    for index,node in enumerate(nodes):
        name=node['name'];kind,separator,part=name.partition('__')
        if not separator or kind not in PARTS or part not in PARTS[kind] or name in result:raise ValueError('Unknown frozen course node')
        mesh=meshes[node['mesh']]
        if mesh['name']!=name or len(mesh['primitives'])!=1:raise ValueError('Course source mesh identity mismatch')
        accessor=scene['accessors'][mesh['primitives'][0]['attributes']['POSITION']];pivot=position(index)
        low=[(v+p)/.28 for v,p in zip(accessor['min'],pivot)];high=[(v+p)/.28 for v,p in zip(accessor['max'],pivot)]
        result[name]={'size':[b-a for a,b in zip(low,high)],'center':[(a+b)/2 for a,b in zip(low,high)]}
    if set(result)!={kind+'__'+part for kind,parts in PARTS.items() for part in parts}:raise ValueError('Missing frozen course nodes')
    return result

def _mesh(row,expected,kind):
    if not isinstance(row,dict) or set(row) not in (MESH_FIELDS,MESH_FIELDS|{'initialSize'}):
        raise ValueError('Course MeshParts require only exact mesh resource fields')
    _content(row['meshId'],'MeshId',False);_content(row['textureId'],'TextureID')
    for key in ('size','meshSize'):
        if any(v<=0 for v in _numbers(row[key],3,key)):raise ValueError('Course mesh sizes must be positive')
    if 'initialSize' in row:
        if any(v<=0 for v in _numbers(row['initialSize'],3,'InitialSize')):raise ValueError('Course InitialSize must be positive')
        _same(row['initialSize'],row['meshSize'],'InitialSize',1e-6)
    _same(row['size'],expected['size'],kind+'__'+row['name']+' size')
    _numbers(row['cframe'],12,'CFrame');_same(row['cframe'][:3],expected['center'],kind+'__'+row['name']+' position')
    # Native importer reflects source facing with a 180-degree Y conversion;
    # this is the measured rest transform that restores authored -Z forward.
    _same(row['cframe'][3:],REST_ROTATION,'course native rest orientation',1e-6)
    _numbers(row['color'],3,'Color',0,1);_number(row['reflectance'],'Reflectance',0,1)
    if _number(row['transparency'],'Transparency',0,1)>=1:raise ValueError('Course MeshParts must be visible')
    if type(row['doubleSided']) is not bool:raise ValueError('Invalid course DoubleSided')
    if row['material'] not in ('Plastic','Metal') or row['renderFidelity'] not in ('Automatic','Precise','Performance'):
        raise ValueError('Unsupported course mesh enum')
    if row['attachments']!=[]:raise ValueError('Course meshes must be flat with no attachments or joints')
    appearances=row['surfaceAppearances']
    if not isinstance(appearances,list) or len(appearances)>1:raise ValueError('Course meshes allow at most one SurfaceAppearance')
    if not appearances:
        if not row['textureId']:raise ValueError('Course meshes require actual uploaded texture content')
        return
    appearance=appearances[0]
    if not isinstance(appearance,dict) or set(appearance)!=SURFACE_FIELDS or appearance.get('name')!='SurfaceAppearance':
        raise ValueError('Course SurfaceAppearance may contain only supported resource fields')
    for key in ('colorMap','normalMap','roughnessMap','metalnessMap'):_content(appearance[key],key,key!='colorMap')
    _numbers(appearance['color'],3,'SurfaceColor',0,1)
    if appearance['alphaMode'] not in ('Overlay','Transparency'):raise ValueError('Unsupported course alpha mode')

def _load(root_path):
    root=Path(root_path).resolve();folder=root/'assets/vehicles/canonical-course'
    if folder.resolve()!=folder:raise ValueError('Course asset folder must remain inside its owned project path')
    path=folder/'roblox-course-vehicles.json'
    if path.resolve()!=path:raise ValueError('Course resource receipt path escapes asset folder')
    raw=path.read_bytes();receipt=_json(raw)
    fields={'schema','sourcePin','modelAssetId','sourceGlbFile','sourceGlbSha256','sourceGlbBytes','templates'}
    if not isinstance(receipt,dict) or set(receipt)!=fields or type(receipt.get('schema')) is not int or receipt['schema']!=1 or receipt['sourcePin']!=PIN:
        raise ValueError('Invalid canonical course resource receipt')
    if not isinstance(receipt['modelAssetId'],str) or not re.fullmatch('[0-9]+',receipt['modelAssetId']) or int(receipt['modelAssetId'])<=0:
        raise ValueError('Course assets require an uploaded model asset ID')
    if receipt['sourceGlbFile']!=SOURCE_FILE or receipt['sourceGlbSha256']!=SOURCE_SHA256 or type(receipt['sourceGlbBytes']) is not int or receipt['sourceGlbBytes']!=SOURCE_BYTES:
        raise ValueError('Course source provenance must match the frozen source GLB')
    source=folder/SOURCE_FILE
    if source.resolve()!=source:raise ValueError('Course source GLB path escapes asset folder')
    blob=source.read_bytes()
    if len(blob)!=SOURCE_BYTES or hashlib.sha256(blob).hexdigest()!=SOURCE_SHA256:raise ValueError('Course source GLB SHA256 mismatch')
    expected=_source_parts(blob);templates=receipt['templates']
    if not isinstance(templates,dict) or set(templates)!=set(PARTS):raise ValueError('Course receipt requires exactly four vehicle templates')
    for kind,entry in templates.items():
        if not isinstance(entry,dict) or set(entry)!={'deckTop','deckLength','deckWidth','parts'}:raise ValueError('Invalid course template fields')
        for field,value in [('deckTop',0),('deckLength',DECKS[kind][0]),('deckWidth',DECKS[kind][1])]:
            if _number(entry[field],field)!=value:raise ValueError('Course deck dimensions differ from frozen source: '+kind)
        rows=entry['parts']
        if not isinstance(rows,list) or len(rows)!=len(PARTS[kind]) or any(not isinstance(r,dict) or not isinstance(r.get('name'),str) for r in rows) or {r['name'] for r in rows}!=PARTS[kind]:
            raise ValueError('Course vehicle requires every unique frozen mesh segment: '+kind)
        for row in rows:_mesh(row,expected[kind+'__'+row['name']],kind)
    return receipt

def package_course_assets(root_path,storage,*,item,prop,mesh_resource):
    """Validate all36 resources before emitting flat, private vehicle models."""
    receipt=_load(root_path);folder=item(storage,'Folder','BrickToadsCourseTemplates')
    for kind,entry in sorted(receipt['templates'].items()):
        model=item(folder,'Model',kind)
        for key,value in {'AppearanceProfile':'CanonicalCourseVehicle','CourseKind':kind,'SourcePin':PIN}.items():
            prop(item(model,'StringValue',key),'string','Value',value)
        for field in ('deckTop','deckLength','deckWidth'):
            prop(item(model,'NumberValue',field[0].upper()+field[1:]),'double','Value',entry[field])
        for row in sorted(entry['parts'],key=lambda r:r['name']):mesh_resource(model,row)
    return folder
