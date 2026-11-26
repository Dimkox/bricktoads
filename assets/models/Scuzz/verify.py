"""BT-88 export acceptance. Reopens shipped artifacts in a new Blender scene per file."""
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET
import bpy
from PIL import Image
import numpy as np
from sculpt import bones, poses, sockets, envelope

out=Path(__file__).resolve().parent
for lod,max_faces in enumerate([8000,5000,2000]):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(out/f'Scuzz_LOD{lod}.fbx'))
    scene=bpy.context.scene
    mesh,=[o for o in scene.objects if o.type=='MESH']
    rig,=[o for o in scene.objects if o.type=='ARMATURE']
    assert set(rig.data.bones.keys())==set(bones)
    assert set(o.name for o in scene.objects if o.type=='EMPTY')==set(sockets)
    assert len(mesh.data.materials)==1 and mesh.data.uv_layers.active and len(mesh.data.polygons)<=max_faces
    assert all(len(v.groups)==1 and v.groups[0].weight==1 for v in mesh.data.vertices)
    assert len(bpy.data.actions)==(17 if lod==0 else 0)
    if lod==0:assert {a.name.rsplit('|',1)[-1] for a in bpy.data.actions}==set(poses)
    assert all(len(p.vertices)==3 and p.area>0 for p in mesh.data.polygons)
    edges=Counter(tuple(sorted(e)) for p in mesh.data.polygons for e in p.edge_keys)
    assert set(edges.values())=={2}
    print(mesh.name,len(mesh.data.polygons),'closed triangles')
for name in poses:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(out/'clips'/(name+'.fbx')))
    rig,=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    action,=bpy.data.actions
    assert set(rig.data.bones.keys())==set(bones)
    assert round(action.frame_range[1]-action.frame_range[0])==envelope(name)[-1][0]-1
print('17 individual FBX takes reimported')
bpy.ops.wm.open_mainfile(filepath=str(out/'Scuzz.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['ScuzzRig'];mesh=bpy.data.objects['Scuzz_LOD0']
for name in set(poses)-{'Attack68','Hop','DeathAir','Fall'}:
    action=bpy.data.actions[name];rig.animation_data.action=action
    for frame in range(1,int(action.frame_range[1])+1):
        scene.frame_set(frame)
        ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        assert abs(min(v.co.z for v in ev.data.vertices)-.032)<.001,(name,frame)
for name,size in [('Color',1024),('Normal',1024),('Metalness',512),('Roughness',512)]:
    with Image.open(out/(name+'.png')) as im:assert im.size==(size,size)
xml=ET.parse(out/'Scuzz.rbxmx')
items=xml.findall('.//Item');ids={o.attrib['referent'] for o in items}
assert len(ids)==len(items) and all(r.text in ids for r in xml.findall('.//Ref'))
assert sum(o.attrib['class']=='Motor6D' for o in items)==len(bones)
assert {o.findtext('Properties/string[@name="Name"]') for o in items if o.attrib['class']=='KeyframeSequence'}==set(poses)
for o in items:
    if o.attrib['class'] in ('Part','WedgePart'):
        props=o.find('Properties')
        assert all(props.findtext(f'bool[@name="{name}"]')=='false' for name in ['CanTouch','CanQuery','CanCollide'])
        assert props.findtext('bool[@name="Massless"]')=='true'
print('DCC grounded frames, 4 maps, native model references, joints and sequences OK')
