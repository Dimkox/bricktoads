"""Export the skinned LOD0 using embedded standard glTF metallic-roughness PBR."""
from pathlib import Path
import json
import struct
import bpy

out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'Scuzz.blend'))
bpy.ops.object.select_all(action='DESELECT')
rig=bpy.data.objects['ScuzzRig']
rig.select_set(True)
for child in rig.children:
    child.select_set(child.name=='Scuzz_LOD0' or child.type=='EMPTY')
bpy.context.view_layer.objects.active=rig
# Blender's glTF exporter packs roughness and metalness into G and B of a shared PNG.
target=out/'Scuzz_LOD0.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
    export_yup=True,export_texcoords=True,export_normals=True,export_tangents=True,
    export_materials='EXPORT',export_skins=True,export_animations=True,
    export_animation_mode='ACTIONS',export_image_format='AUTO')
data=target.read_bytes();length,kind=struct.unpack_from('<II',data,12)
assert kind==0x4e4f534a
gltf=json.loads(data[20:20+length])
assert len(gltf['meshes'])==1 and len(gltf['skins'])==1 and len(gltf['animations'])==17
prim,=gltf['meshes'][0]['primitives']
assert {'POSITION','TEXCOORD_0','NORMAL','TANGENT','JOINTS_0','WEIGHTS_0'} <= prim['attributes'].keys()
material=gltf['materials'][prim['material']]
pbr=material['pbrMetallicRoughness']
for info in [material['normalTexture'],pbr['baseColorTexture'],pbr['metallicRoughnessTexture']]:
    image=gltf['images'][gltf['textures'][info['index']]['source']]
    assert image['mimeType']=='image/png' and 'bufferView' in image and 'uri' not in image
print('Embedded textures, skin, UVs, tangents and 17 animations verified.',target.stat().st_size,'bytes.')
