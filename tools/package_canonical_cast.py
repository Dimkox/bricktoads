"""Validate and package mandatory, private, uploaded canonical cast resources."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re

PIN='f1a43b69577246850d136473700a333b3cdfe93f'
MESH_FIELDS={'name','parentSegment','meshId','textureId','size','meshSize','cframe','color','material',
             'renderFidelity','doubleSided','transparency','reflectance','attachments','surfaceAppearances'}
SURFACE_FIELDS={'name','colorMap','normalMap','roughnessMap','metalnessMap','color','alphaMode'}


def _number(value,name,minimum=None,maximum=None):
    try:valid=type(value) in (int,float) and math.isfinite(value)
    except OverflowError:valid=False
    if not valid \
            or minimum is not None and value<minimum or maximum is not None and value>maximum:
        raise ValueError('Invalid cast number: '+name)
    return value


def _numbers(value,length,name,minimum=None,maximum=None):
    if not isinstance(value,list) or len(value)!=length:raise ValueError('Invalid cast vector: '+name)
    for n in value:_number(n,name,minimum,maximum)
    return value


def _frame(value):
    _numbers(value,12,'CFrame');rows=[value[3:6],value[6:9],value[9:12]]
    for i in range(3):
        for j in range(3):
            if abs(sum(a*b for a,b in zip(rows[i],rows[j]))-(1 if i==j else 0))>.001:
                raise ValueError('Invalid cast rotation')
    a,b,c=rows
    determinant=a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0])
    if abs(determinant-1)>.001:raise ValueError('Invalid cast orientation')
    return value


def _compose(a,b):
    return [a[i]+sum(a[3+i*3+j]*b[j] for j in range(3)) for i in range(3)]+[
        sum(a[3+i*3+k]*b[3+k*3+j] for k in range(3)) for i in range(3) for j in range(3)]


def _content(value,name,empty=True):
    if not isinstance(value,str) or not value and not empty \
            or value and (not re.fullmatch(r'rbxassetid://[0-9]+',value) or int(value[13:])<=0):
        raise ValueError('Invalid cast content: '+name)


def _name(value):
    return isinstance(value,str) and re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*',value) is not None


def _mesh(row):
    if not isinstance(row,dict) or set(row)!=MESH_FIELDS or not _name(row.get('name')):
        raise ValueError('Cast MeshParts require only the exact mesh resource fields')
    _content(row['meshId'],'MeshId',False);_content(row['textureId'],'TextureID')
    for key in ('size','meshSize'):
        if any(n<=0 for n in _numbers(row[key],3,key)):raise ValueError('Cast dimensions must be positive')
    _frame(row['cframe']);_numbers(row['color'],3,'Color',0,1)
    _number(row['reflectance'],'Reflectance',0,1)
    if _number(row['transparency'],'Transparency',0,1)>=1:raise ValueError('Cast meshes must be visible')
    if type(row['doubleSided']) is not bool:raise ValueError('Invalid cast DoubleSided')
    if row['material'] not in ('Plastic','Metal') or row['renderFidelity'] not in ('Automatic','Precise','Performance'):
        raise ValueError('Unsupported cast enum')
    attachments=row['attachments']
    if not isinstance(attachments,list) or any(not isinstance(a,dict) or set(a)!={'name','cframe'}
            or not _name(a.get('name')) for a in attachments):raise ValueError('Invalid cast attachments')
    if len({a['name'] for a in attachments})!=len(attachments):raise ValueError('Duplicate cast attachment')
    for a in attachments:_frame(a['cframe'])
    appearances=row['surfaceAppearances']
    if not isinstance(appearances,list) or len(appearances)>1:raise ValueError('Invalid cast surfaces')
    for a in appearances:
        if not isinstance(a,dict) or set(a)!=SURFACE_FIELDS or a.get('name')!='SurfaceAppearance':
            raise ValueError('Cast SurfaceAppearance must contain only supported resource fields')
        for key in ('colorMap','normalMap','roughnessMap','metalnessMap'):_content(a[key],key)
        _numbers(a['color'],3,'SurfaceColor',0,1)
        if a['alphaMode'] not in ('Overlay','Transparency'):raise ValueError('Invalid cast alpha mode')


def _template(record):
    fields={'name','appearanceProfile','fitYOffset','parts'}
    if not isinstance(record,dict) or set(record) not in (fields,fields|{'sourcePixelScale'}) \
            or not _name(record.get('name')) or record.get('appearanceProfile')!='CanonicalNESCast':
        raise ValueError('Invalid cast template identity or unexpected content')
    _number(record['fitYOffset'],'FitYOffset')
    if 'sourcePixelScale' in record:
        if _number(record['sourcePixelScale'],'SourcePixelScale',0,10)==0:raise ValueError('SourcePixelScale must be positive')
    rows=record['parts']
    if not isinstance(rows,list) or not 1<=len(rows)<=32:raise ValueError('Cast requires1..32 MeshParts')
    for row in rows:_mesh(row)
    parts={r['name']:r for r in rows}
    if len(parts)!=len(rows) or 'Body' not in parts or parts['Body']['parentSegment']!='@Torso':
        raise ValueError('Cast requires exactly one Body root')
    for name,row in parts.items():
        parent=row['parentSegment'];seen={name}
        if name!='Body' and parent=='@Torso':raise ValueError('Cast has multiple roots')
        while parent!='@Torso':
            if not isinstance(parent,str) or parent not in parts or parent in seen:raise ValueError('Cyclic or missing cast parent')
            seen.add(parent);parent=parts[parent]['parentSegment']
        expected={'CastRigAttachment'}|{'Cast'+child+'RigAttachment' for child,p in parts.items() if p['parentSegment']==name}
        if {a['name'] for a in row['attachments']}!=expected:raise ValueError('Cast requires exact child and parent pivot attachments')
    origins={name:{a['name']:a['cframe'] for a in row['attachments']} for name,row in parts.items()}
    identity=[0,0,0,1,0,0,0,1,0,0,0,1]
    for name,row in parts.items():
        own=_compose(row['cframe'],origins[name]['CastRigAttachment'])
        parent=row['parentSegment']
        source=identity if parent=='@Torso' else _compose(parts[parent]['cframe'],origins[parent]['Cast'+name+'RigAttachment'])
        if any(abs(a-b)>.0001 for a,b in zip(own,source)):raise ValueError('Misaligned cast joint origin: '+name)


def _load(root_path):
    root=Path(root_path).resolve();expected_folder=root/'assets/characters/canonical-cast'
    folder=expected_folder.resolve()
    if folder!=expected_folder:raise ValueError('Cast asset folder must remain inside its owned project path')
    family_path=folder/'manifest.json'
    if family_path.resolve()!=family_path:raise ValueError('Cast family manifest must remain in its owned folder')
    family_manifest=json.loads(family_path.read_bytes())
    expected=family_manifest.get('families') if isinstance(family_manifest,dict) else None
    if not isinstance(family_manifest,dict) or family_manifest.get('sourcePin')!=PIN or not isinstance(expected,dict) or len(expected)!=29 \
            or any(not _name(name) for name in expected):raise ValueError('Expected29 pinned canonical cast families')
    manifest_path=folder/'roblox-cast.json'
    if manifest_path.resolve()!=manifest_path:raise ValueError('Cast receipt must remain in its owned folder')
    raw=manifest_path.read_bytes();manifest=json.loads(raw)
    fields={'schema','appearanceProfile','sourceAssetId','sourceGlbFile','sourceGlbSha256','sourcePin','templates'}
    if not isinstance(manifest,dict) or set(manifest)!=fields or type(manifest.get('schema')) is not int \
            or manifest['schema']!=1 or manifest.get('appearanceProfile')!='CanonicalNESCastAssets' or manifest.get('sourcePin')!=PIN:
        raise ValueError('Invalid canonical cast resource receipt')
    asset_id=manifest['sourceAssetId'];sha=manifest['sourceGlbSha256']
    if not isinstance(asset_id,str) or not re.fullmatch('[0-9]+',asset_id) or int(asset_id)<=0 \
            or not isinstance(sha,str) or not re.fullmatch('[0-9a-f]{64}',sha):raise ValueError('Invalid cast source provenance')
    if manifest['sourceGlbFile']!='canonical-cast.glb':raise ValueError('Cast source GLB must be canonical-cast.glb')
    glb=folder/'canonical-cast.glb'
    if glb.resolve()!=glb or hashlib.sha256(glb.read_bytes()).hexdigest()!=sha:raise ValueError('Cast source GLB hash mismatch or path escape')
    records=manifest['templates']
    if not isinstance(records,list) or len(records)!=29 or any(not isinstance(r,dict) or not _name(r.get('name')) for r in records) \
            or {r['name'] for r in records}!=set(expected):raise ValueError('Cast receipt requires every unique expected family')
    for row in records:_template(row)
    return manifest,hashlib.sha256(raw).hexdigest()


def package_cast(root_path,storage,*,item,prop,mesh_resource):
    """Validate before emitting, then package into an existing builder XML tree.

    item(parent,class_name,name), prop(item,type,name,value), and
    mesh_resource(model,row)->MeshPart are the existing builder callbacks.
    """
    manifest,receipt_sha=_load(root_path)
    folder=item(storage,'Folder','BrickToadsCastTemplates')
    for record in sorted(manifest['templates'],key=lambda r:r['name']):
        model=item(folder,'Model',record['name'])
        metadata={'AppearanceProfile':'CanonicalNESCast','CastKind':record['name'],'SourcePin':PIN,
                  'SourceAssetId':manifest['sourceAssetId'],'SourceGlbSha256':manifest['sourceGlbSha256'],
                  'AssetManifestSha256':receipt_sha,'FitYOffset':record['fitYOffset']}
        if 'sourcePixelScale' in record:metadata['SourcePixelScale']=record['sourcePixelScale']
        for key,value in metadata.items():prop(item(model,'StringValue',key),'string','Value',value)
        for row in sorted(record['parts'],key=lambda p:p['name']):
            mesh=mesh_resource(model,row)
            prop(item(mesh,'StringValue','ParentSegment'),'string','Value',row['parentSegment'])
    return folder
