"""Validate all 28 mandatory uploaded course prop resources before packaging."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import struct

PIN = 'f1a43b69577246850d136473700a333b3cdfe93f'
SOURCE_FILE = 'canonical-course-props.glb'
SOURCE_SHA256 = 'a5fc292cb0a58f82aee5b6d9bb16e3cfd3636ef3779ba99b424a661db8590157'
SOURCE_BYTES = 991060
KINDS = {'AirMine','BoardingPad','Bomb','Buzzball','ElectricTrap','Fan','Gas','Gear','IceBlock','Icicle',
         'Lift','Log','Mine','MovingIcePlatform','Ramp','Rocket','RocketLauncher','Rope','RotatingSpike',
         'Snowball','Spike','Spring','Telegraph','Tower','TowerPlatform','Warning','Water','Whirlpool'}
TILED = {'AirMine','Bomb','Icicle','Log','Mine','RotatingSpike','Spike'}
MESH_FIELDS = {'name','meshId','textureId','meshSize','size','cframe','color','material','renderFidelity',
               'doubleSided','transparency','reflectance','attachments','surfaceAppearances'}
SURFACE_FIELDS = {'name','colorMap','normalMap','roughnessMap','metalnessMap','color','alphaMode'}
REST_ROTATION = [-1,0,0,0,1,0,0,0,-1]


def _number(value, name, minimum=None, maximum=None):
    try:
        valid = type(value) in (int,float) and math.isfinite(value)
    except OverflowError:
        valid = False
    if not valid or minimum is not None and value < minimum or maximum is not None and value > maximum:
        raise ValueError('Invalid course prop number: '+name)
    return value


def _numbers(value, count, name, minimum=None, maximum=None):
    if not isinstance(value,list) or len(value) != count:
        raise ValueError('Invalid course prop vector: '+name)
    for number in value:
        _number(number,name,minimum,maximum)
    return value


def _same(actual, expected, name, tolerance=.001):
    if len(actual) != len(expected) or any(abs(a-b) > tolerance for a,b in zip(actual,expected)):
        raise ValueError('Course prop differs from frozen source: '+name)


def _content(value, name, empty=True):
    if not isinstance(value,str) or not value and not empty or value and (
            not re.fullmatch(r'rbxassetid://[0-9]+',value) or int(value[13:]) <= 0):
        raise ValueError('Invalid course prop content: '+name)


def _json(raw):
    def unique(pairs):
        result = {}
        for key,value in pairs:
            if key in result:
                raise ValueError('Duplicate course prop receipt field: '+key)
            result[key] = value
        return result
    return json.loads(raw,object_pairs_hook=unique)


def _motion(kind, name, pivot):
    axis = ('SpinY' if kind == 'RotatingSpike' or kind == 'Whirlpool' and name == 'Spiral' else
            'SpinZ' if kind in ('Buzzball','Gear') or kind == 'Fan' and name == 'Rotor' else
            'Pulse' if kind == 'Gas' or kind in ('Telegraph','Warning') and name != 'Body'
            or kind == 'ElectricTrap' and name == 'Arc' else None)
    if axis:
        return {'kind':axis,'speed':2 if kind == 'Fan' else .7 if kind == 'Gas' else 1.2 if kind == 'Whirlpool' else 1,
                'pivot':pivot}
    return None


def _source_parts(blob):
    """Read real float vertex bounds and rest pivots from immutable GLB bytes."""
    if struct.unpack_from('<4sII',blob) != (b'glTF',2,len(blob)):
        raise ValueError('Invalid frozen course prop GLB')
    length,chunk = struct.unpack_from('<I4s',blob,12)
    if chunk != b'JSON':
        raise ValueError('Frozen course prop GLB requires JSON')
    scene = _json(blob[20:20+length])
    binary_length,binary_kind = struct.unpack_from('<I4s',blob,20+length)
    if binary_kind != b'BIN\0' or binary_length != len(blob)-28-length:
        raise ValueError('Invalid course prop GLB binary chunk')
    binary = memoryview(blob)[28+length:]
    nodes,meshes = scene['nodes'],scene['meshes']
    if len(nodes) != 98 or len(meshes) != 98 or scene.get('skins') or scene.get('animations'):
        raise ValueError('Frozen course props require 98 flat unrigged meshes')
    roots = scene['scenes'][scene['scene']]['nodes']
    if len(roots) != 98 or set(roots) != set(range(98)):
        raise ValueError('Every course prop mesh must be a flat scene root')
    result = {kind:{'parts':{},'low':[math.inf]*3,'high':[-math.inf]*3} for kind in KINDS}
    used_meshes = set()
    for node in nodes:
        name = node.get('name','')
        kind,separator,part = name.partition('__')
        if not separator or kind not in KINDS or not re.fullmatch('[A-Za-z][A-Za-z0-9]*',part) \
                or part in result[kind]['parts'] or set(node)-{'name','mesh','translation'}:
            raise ValueError('Unknown or rigged frozen course prop node')
        index=node['mesh']
        if type(index) is not int or index in used_meshes or not 0 <= index < 98:
            raise ValueError('Duplicate frozen course prop mesh')
        used_meshes.add(index)
        mesh = meshes[index]
        if mesh['name'] != name or len(mesh['primitives']) != 1:
            raise ValueError('Course prop source mesh identity mismatch')
        primitive = mesh['primitives'][0]
        if primitive.get('mode',4) != 4 or set(primitive['attributes']) != {'POSITION','NORMAL','TEXCOORD_0'}:
            raise ValueError('Course props require textured triangle meshes')
        accessor = scene['accessors'][primitive['attributes']['POSITION']]
        if accessor['type'] != 'VEC3' or accessor['componentType'] != 5126 or accessor['count'] < 4:
            raise ValueError('Invalid frozen course prop positions')
        view = scene['bufferViews'][accessor['bufferView']]
        offset = view.get('byteOffset',0)+accessor.get('byteOffset',0)
        stride = view.get('byteStride',12)
        vertices = [struct.unpack_from('<fff',binary,offset+i*stride) for i in range(accessor['count'])]
        if any(not math.isfinite(n) for vertex in vertices for n in vertex):
            raise ValueError('Nonfinite frozen course prop positions')
        material = scene['materials'][primitive['material']]
        texture = scene['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]
        image = scene['images'][texture['source']]
        if image.get('mimeType') != 'image/png' or 'bufferView' not in image:
            raise ValueError('Course props require embedded source palette textures')
        pivot = [v/.28 for v in _numbers(node.get('translation',[0,0,0]),3,'SourcePivot')]
        low = [min(v[axis] for v in vertices)/.28+pivot[axis] for axis in range(3)]
        high = [max(v[axis] for v in vertices)/.28+pivot[axis] for axis in range(3)]
        size = [b-a for a,b in zip(low,high)]
        if any(n <= 0 for n in size):
            raise ValueError('Frozen prop mesh must have solid three dimensional bounds')
        entry = result[kind]
        entry['parts'][part] = {'size':size,'center':[(a+b)/2 for a,b in zip(low,high)],
                                'motion':_motion(kind,part,pivot),
                                'transparency':.3 if kind=='Gas'and part in ('Body','UpperCloud','TrailingCloud') else 0}
        entry['low'] = [min(a,b) for a,b in zip(entry['low'],low)]
        entry['high'] = [max(a,b) for a,b in zip(entry['high'],high)]
    for kind,entry in result.items():
        if not 1 <= len(entry['parts']) <= 8:
            raise ValueError('Frozen course prop requires one to eight meshes per kind')
        entry['referenceSize'] = [b-a for a,b in zip(entry['low'],entry['high'])]
        _same([(a+b)/2 for a,b in zip(entry['low'],entry['high'])],[0,0,0],kind+' reference center')
        entry['fitMode'] = 'TileZ' if kind in TILED else kind if kind in ('Tower','Rope') else 'Stretch'
    return result


def _mesh(row, expected, kind):
    fields = MESH_FIELDS | ({'motion'} if expected['motion'] else set())
    if not isinstance(row,dict) or set(row) not in (fields,fields|{'initialSize'}):
        raise ValueError('Course prop MeshParts require exact resource and frozen motion fields')
    name=kind+'__'+row['name']
    _content(row['meshId'],'MeshId',False)
    _content(row['textureId'],'TextureID')
    for field in ('size','meshSize'):
        if any(v <= 0 for v in _numbers(row[field],3,field)):
            raise ValueError('Course prop mesh sizes must be positive')
    _same(row['size'],expected['size'],name+' size')
    _same(row['meshSize'],[v*.28 for v in expected['size']],name+' source mesh size')
    if 'initialSize' in row:
        _numbers(row['initialSize'],3,'InitialSize')
        _same(row['initialSize'],row['meshSize'],name+' InitialSize',1e-6)
    _numbers(row['cframe'],12,'CFrame')
    _same(row['cframe'][:3],expected['center'],name+' position')
    _same(row['cframe'][3:],REST_ROTATION,name+' native Y180 rest rotation',1e-6)
    _numbers(row['color'],3,'Color',0,1)
    _number(row['reflectance'],'Reflectance',0,1)
    if _number(row['transparency'],'Transparency',0,1) >= 1:
        raise ValueError('Course prop source MeshParts must be visible')
    _same([row['transparency']],[expected['transparency']],name+' transparency',1e-6)
    if type(row['doubleSided']) is not bool or row['material'] not in ('Plastic','Metal') \
            or row['renderFidelity'] not in ('Automatic','Precise','Performance'):
        raise ValueError('Unsupported course prop material or fidelity')
    if row['attachments'] != []:
        raise ValueError('Course prop meshes must have no attachments, scripts, or joints')
    appearances=row['surfaceAppearances']
    if not isinstance(appearances,list) or len(appearances)>1:
        raise ValueError('Course props allow at most one SurfaceAppearance')
    if not appearances and not row['textureId']:
        raise ValueError('Course props require actual uploaded texture content')
    for surface in appearances:
        if not isinstance(surface,dict) or set(surface) != SURFACE_FIELDS or surface['name'] != 'SurfaceAppearance':
            raise ValueError('Course prop SurfaceAppearance requires exact leaf resource fields')
        for field in ('colorMap','normalMap','roughnessMap','metalnessMap'):
            _content(surface[field],field,field!='colorMap')
        _numbers(surface['color'],3,'SurfaceColor',0,1)
        if surface['alphaMode'] not in ('Overlay','Transparency'):
            raise ValueError('Unsupported course prop SurfaceAppearance alpha mode')
    if expected['motion']:
        motion=row['motion'];source=expected['motion']
        if not isinstance(motion,dict) or set(motion) != {'kind','speed','pivot'} or motion['kind'] != source['kind']:
            raise ValueError('Invalid frozen course prop motion')
        if _number(motion['speed'],'MotionSpeed') != source['speed']:
            raise ValueError('Course prop motion speed differs from frozen contract')
        _same(_numbers(motion['pivot'],3,'MotionPivot'),source['pivot'],name+' motion pivot')


def _load(root_path):
    root=Path(root_path).resolve()
    folder=root/'assets/props/canonical-course'
    if folder.resolve() != folder:
        raise ValueError('Course prop asset folder escapes owned project path')
    path=folder/'roblox-course-props.json'
    if path.resolve() != path:
        raise ValueError('Course prop receipt path escapes asset folder')
    receipt=_json(path.read_bytes())
    fields={'schema','sourcePin','modelAssetId','sourceGlbFile','sourceGlbSha256','sourceGlbBytes','templates'}
    if not isinstance(receipt,dict) or set(receipt) != fields or type(receipt.get('schema')) is not int \
            or receipt['schema'] != 1 or receipt['sourcePin'] != PIN:
        raise ValueError('Invalid canonical course prop resource receipt')
    asset_id=receipt['modelAssetId']
    if not isinstance(asset_id,str) or not re.fullmatch('[0-9]+',asset_id) or int(asset_id)<=0:
        raise ValueError('Course props require an uploaded model asset ID')
    if receipt['sourceGlbFile'] != SOURCE_FILE or receipt['sourceGlbSha256'] != SOURCE_SHA256 \
            or type(receipt['sourceGlbBytes']) is not int or receipt['sourceGlbBytes'] != SOURCE_BYTES:
        raise ValueError('Course prop provenance must match frozen source GLB')
    path=folder/SOURCE_FILE
    if path.resolve() != path:
        raise ValueError('Course prop GLB path escapes asset folder')
    blob=path.read_bytes()
    if len(blob) != SOURCE_BYTES or hashlib.sha256(blob).hexdigest() != SOURCE_SHA256:
        raise ValueError('Course prop source GLB SHA256 mismatch')
    expected=_source_parts(blob)
    templates=receipt['templates']
    if not isinstance(templates,dict) or set(templates) != KINDS:
        raise ValueError('Course prop receipt requires exactly all 28 templates')
    for kind,entry in templates.items():
        if not isinstance(entry,dict) or set(entry) != {'referenceSize','fitMode','parts'}:
            raise ValueError('Invalid course prop template fields')
        source=expected[kind]
        _same(_numbers(entry['referenceSize'],3,'ReferenceSize'),source['referenceSize'],kind+' reference size')
        if entry['fitMode'] != source['fitMode']:
            raise ValueError('Course prop fit mode differs from frozen contract: '+kind)
        rows=entry['parts']
        if not isinstance(rows,list) or len(rows) != len(source['parts']) \
                or any(not isinstance(row,dict) or not isinstance(row.get('name'),str) for row in rows) \
                or {row['name'] for row in rows} != set(source['parts']):
            raise ValueError('Course prop requires every unique frozen mesh segment: '+kind)
        for row in rows:
            _mesh(row,source['parts'][row['name']],kind)
    return receipt


def package_course_props(root_path, storage, *, item, prop, mesh_resource):
    """Validate the complete receipt before emitting any flat private templates."""
    receipt=_load(root_path)
    folder=item(storage,'Folder','BrickToadsCoursePropTemplates')
    for kind,entry in sorted(receipt['templates'].items()):
        model=item(folder,'Model',kind)
        for key,value in {'AppearanceProfile':'CanonicalCourseProp','CourseKind':kind,'SourcePin':PIN,
                          'FitMode':entry['fitMode']}.items():
            prop(item(model,'StringValue',key),'string','Value',value)
        for axis,value in zip('XYZ',entry['referenceSize']):
            prop(item(model,'NumberValue','ReferenceSize'+axis),'double','Value',value)
        for row in sorted(entry['parts'],key=lambda value:value['name']):
            motion=row.get('motion')
            if motion:
                suffix='_'+row['name']
                prop(item(model,'StringValue','MotionKind'+suffix),'string','Value',motion['kind'])
                prop(item(model,'NumberValue','MotionSpeed'+suffix),'double','Value',motion['speed'])
                for axis,value in zip('XYZ',motion['pivot']):
                    prop(item(model,'NumberValue','MotionPivot'+axis+suffix),'double','Value',value)
            mesh_resource(model,{key:value for key,value in row.items() if key != 'motion'})
    return folder
