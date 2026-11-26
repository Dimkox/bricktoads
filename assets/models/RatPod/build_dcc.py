"""Build and reimport L0 FBX in Blender 5.3. Save an editable, marked preview scene.

The clean FBX is exported before preview-only pose and visibility keyframes.
"""
import json
from math import radians
from pathlib import Path
import bpy

for kind in ('RatPod', 'Meteorite'):
    folder=Path(__file__).resolve().parent.parent/kind
    manifest=json.loads((folder/'manifest.json').read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(folder/f'{kind}-L0.glb'))
    meshes={ob.name:ob for ob in bpy.context.scene.objects if ob.type=='MESH'}
    assert set(meshes)==set(manifest['lods'][0]['parts'])
    root=bpy.data.objects.new('VisualRoot',None)
    bpy.context.collection.objects.link(root)
    root.empty_display_size=.10
    for ob in meshes.values():
        world=ob.matrix_world.copy()
        ob.parent=root
        ob.matrix_world=world
    for name,cf in manifest['attachmentsCFrame'].items():
        ob=bpy.data.objects.new(name,None)
        bpy.context.collection.objects.link(ob)
        ob.parent=root
        ob.empty_display_type='ARROWS'
        ob.empty_display_size=.08
        x,y,z=cf[:3]
        ob.location=(.28*x,-.28*z,.28*y)
        if name=='Exhaust': ob.rotation_euler.z=radians(180)
    bpy.ops.export_scene.fbx(filepath=str(folder/f'{kind}.fbx'),path_mode='COPY',
                             embed_textures=True,bake_anim=False,add_leaf_bones=False,
                             axis_forward='-Z',axis_up='Y')
    scene=bpy.context.scene
    scene.render.fps=24
    scene.frame_end=12*len(manifest['states'])
    for i,state in enumerate(manifest['states']):
        frame=i*12+1
        scene.timeline_markers.new(state,frame=frame)
        for ob in meshes.values():
            hidden=state in ('Cleanup','Removed')
            ob.hide_render=hidden
            ob.hide_viewport=hidden
            for field in ('hide_render','hide_viewport'):
                ob.keyframe_insert(data_path=field,frame=frame,group='Presentation')
        if kind=='RatPod':
            for ob in meshes.values():
                ob.rotation_euler.y=radians({'CrossingForward':8,'TurnAtBound':-14,'CrossingReturn':-8}.get(state,0))
                ob.keyframe_insert(data_path='rotation_euler',frame=frame,group='Bank')
        else:
            flame=meshes['FlameShell']
            flame.scale.y={'SpawnIgnite':.72,'Flight_A':1,'Flight_B':.86,'PassExpire':.52}.get(state,1)
            flame.keyframe_insert(data_path='scale',frame=frame,group='Flame length')
    scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/f'{kind}.blend'),compress=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(folder/f'{kind}.fbx'))
    imported=[ob for ob in bpy.context.scene.objects if ob.type=='MESH']
    assert {ob.name for ob in imported}==set(meshes)
    count=sum(len(ob.data.polygons) for ob in imported)
    assert count==manifest['lods'][0]['triangles']
    print(kind,'verified FBX round-trip:',count)
