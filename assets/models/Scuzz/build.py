"""Rebuild the Blender source, FBX meshes/actions and previews with bpy, Pillow and NumPy."""
from pathlib import Path
from math import pi, cos, sin
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw
import bpy
from mathutils import Vector, Matrix, Euler
sys.path.insert(0,str(Path(__file__).resolve().parent))
from sculpt import bones, pieces, palette, sockets, poses, envelope

out=Path(__file__).resolve().parent
os.chdir(out)
def dcc(p): return (p[0],-p[2],p[1])
def unit(p):return p / np.linalg.norm(p)
def geometry(lod):
    vertices, faces, uv_faces, groups, colors = [],[],[],{},[]
    for name,bone,color,sections,detail in pieces:
        if lod==2 and detail:continue
        stride=(1,2,3)[lod]
        rings=sections[::stride]
        if rings[-1]!=sections[-1]:rings.append(sections[-1])
        if len(rings)<3:rings=[sections[0],sections[len(sections)//2],sections[-1]]
        n=(9,7,5)[lod]
        if detail: n-=2
        off=len(vertices)
        patch=list(palette).index(color)
        def uv(u,v):return ((patch%3+.05+.90*u)/3,(patch//3+.05+.90*v)/3)
        def triangle(indices,coords):
            faces.append(indices);uv_faces.append([uv(u,v) for u,v in coords]);colors.append(palette[color])
        direction=unit(np.subtract(rings[-1][:3],rings[0][:3]))
        guide=np.array([1.,0,0]) if abs(direction[0])<.9 else np.array([0.,0,1.])
        for i,(*center,rx,ry) in enumerate(rings):
            tangent=unit(np.subtract(rings[min(i+1,len(rings)-1)][:3],rings[max(0,i-1)][:3]))
            u=unit(guide-tangent*np.dot(guide,tangent));v=np.cross(tangent,u)
            for j in range(n):
                a=2*pi*j/n
                vertices.append(tuple(center+u*(rx*cos(a))+v*(ry*sin(a))))
        for i in range(len(rings)-1):
            for j in range(n):
                a,b=off+i*n+j,off+i*n+(j+1)%n
                u,v,t,w=j/n,(j+1)/n,i/(len(rings)-1),(i+1)/(len(rings)-1)
                triangle((a,b,b+n),[(u,t),(v,t),(v,w)]);triangle((a,b+n,a+n),[(u,t),(v,w),(u,w)])
        for i,reverse in [(0,True),(len(rings)-1,False)]:
            for j in range(1,n-1):
                idx=(0,j+1,j) if reverse else (0,j,j+1)
                triangle(tuple(off+i*n+k for k in idx),[(.5+.4*cos(2*pi*k/n),.5+.4*sin(2*pi*k/n)) for k in idx])
        groups.setdefault(bone,[]).extend(range(off,len(vertices)))
    return vertices,faces,uv_faces,groups,colors

def previews(vertices,faces,colors):
    verts=np.array(vertices); faces=np.array(faces);colors=np.array(colors)
    panel=440
    canvas=Image.new('RGB',(panel*4,520),'#ede7de')
    for index,angle in enumerate([0,43,90,180]):
        a=np.radians(angle)
        side=np.array([cos(a),0,sin(a)])
        cam=unit(np.array([sin(a),.16,-cos(a)]))
        up=unit(np.cross(side,cam))
        x,y,z=verts@side,verts@up,verts@cam
        xx=(x-(x.min()+x.max())/2)*96+panel/2; yy=468-y*96
        pic=Image.new('RGB',(panel*2,520*2),'#ede7de');d=ImageDraw.Draw(pic)
        normals=np.cross(verts[faces[:,1]]-verts[faces[:,0]],verts[faces[:,2]]-verts[faces[:,0]])
        normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-9)
        # Barycentric depth and smooth normals keep the eyes and crossing whiskers legible.
        from PIL import ImageFilter
        d.ellipse((panel*.40,922,panel*1.60,954),fill='#c8baab')
        pic=pic.filter(ImageFilter.GaussianBlur(8))
        pixels=np.array(pic);zbuffer=np.full(pixels.shape[:2],-np.inf)
        vn=np.zeros_like(verts)
        for i in range(3):np.add.at(vn,faces[:,i],normals)
        vn/=np.maximum(np.linalg.norm(vn,axis=1)[:,None],1e-9)
        light=unit(side*-.48+up*.7+cam*.64)
        luminosity=.65+.39*(vn@light)
        sx,sy=xx*2,yy*2
        for f,idx in enumerate(faces):
            if normals[f]@cam<=0:continue
            tx,ty=sx[idx],sy[idx]
            x0,x1=max(0,int(tx.min())),min(pixels.shape[1],int(tx.max())+2)
            y0,y1=max(0,int(ty.min())),min(pixels.shape[0],int(ty.max())+2)
            if x0>=x1 or y0>=y1:continue
            gy,gx=np.ogrid[y0:y1,x0:x1]
            den=(ty[1]-ty[2])*(tx[0]-tx[2])+(tx[2]-tx[1])*(ty[0]-ty[2])
            if abs(den)<1e-8:continue
            u=((ty[1]-ty[2])*(gx-tx[2])+(tx[2]-tx[1])*(gy-ty[2]))/den
            v=((ty[2]-ty[0])*(gx-tx[2])+(tx[0]-tx[2])*(gy-ty[2]))/den
            w=1-u-v
            depth=u*z[idx[0]]+v*z[idx[1]]+w*z[idx[2]]
            region=zbuffer[y0:y1,x0:x1]
            mask=(u>=0)&(v>=0)&(w>=0)&(depth>region)
            region[mask]=depth[mask]
            intensity=u*luminosity[idx[0]]+v*luminosity[idx[1]]+w*luminosity[idx[2]]
            pixels[y0:y1,x0:x1][mask]=(intensity[mask,None]*colors[f]).clip(0,255).astype(np.uint8)
        pic=Image.fromarray(pixels)
        canvas.paste(pic.resize((panel,520),Image.Resampling.LANCZOS),(index*panel,0))
        ImageDraw.Draw(canvas).text((index*panel+16,492),['FRONT','THREE-QUARTER','PROFILE','REAR'][index],fill='#38352f')
    canvas.save('turnaround.png')

def texture_set():
    material=bpy.data.materials.new('Scuzz_FurAtlas')
    material.use_nodes=True
    tree=material.node_tree
    shader=tree.nodes.get('Principled BSDF')
    for kind,size in [('Color',1024),('Normal',1024),('Roughness',512),('Metalness',512)]:
        yy,xx=np.indices((size,size))
        tile=(2-np.minimum(2,yy*3//size))*3+np.minimum(2,xx*3//size)
        rgb=np.array(list(palette.values()))[tile].astype(float)
        fur=(tile<=4)
        groove=np.sin(xx*.54+yy*.19+2*np.sin(yy*.07))*.56+np.sin(xx*.19-yy*.04)*.44
        if kind=='Color': data=rgb+(groove*fur*6)[:,:,None]
        elif kind=='Normal':data=np.stack((128+groove*fur*17,128+np.sin(yy*.28+xx*.22)*fur*6,np.full_like(xx,253)),axis=-1)
        elif kind=='Roughness':data=np.where(fur,201+groove*12,np.where(tile==5,80,145))
        else:data=np.zeros_like(xx)
        path=out/(kind+'.png');Image.fromarray(data.clip(0,255).astype('uint8')).save(path)
        tex=tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path));tex.image.filepath='//'+path.name
        if kind!='Color':tex.image.colorspace_settings.name='Non-Color'
        if kind=='Normal':
            normal=tree.nodes.new('ShaderNodeNormalMap');tree.links.new(tex.outputs['Color'],normal.inputs['Color']);tree.links.new(normal.outputs['Normal'],shader.inputs['Normal'])
        else:tree.links.new(tex.outputs['Color'],shader.inputs[{'Color':'Base Color','Roughness':'Roughness','Metalness':'Metallic'}[kind]])
    return material

bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.fps=24
arm=bpy.data.armatures.new('ScuzzSkeleton');rig=bpy.data.objects.new('ScuzzRig',arm);scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name,(parent,p) in bones.items():
    b=arm.edit_bones.new(name);b.head=dcc(p);b.tail=b.head+Vector((0,.16,0))
    if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for name,(bone,p) in sockets.items():
    obj=bpy.data.objects.new(name,None);scene.collection.objects.link(obj);obj.parent=rig;obj.parent_type='BONE';obj.parent_bone=bone
    obj.location=Vector(dcc(p))-arm.bones[bone].tail_local;obj.empty_display_size=.09
mat=texture_set()
meshes=[];stats={}
for lod in range(3):
    verts,faces,uv,groups,cols=geometry(lod)
    if lod==0:previews(verts,faces,cols)
    name='Scuzz_LOD'+str(lod);mesh=bpy.data.meshes.new(name);mesh.from_pydata([dcc(p) for p in verts],[],faces);mesh.update()
    assert not mesh.validate() and len(faces)<(8000,5000,2000)[lod]
    obj=bpy.data.objects.new(name,mesh);scene.collection.objects.link(obj);obj.parent=rig;obj.data.materials.append(mat)
    mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
    for bone,indices in groups.items():obj.vertex_groups.new(name=bone).add(indices,1.,'REPLACE')
    uv_layer=mesh.uv_layers.new()
    for poly,coords in zip(mesh.polygons,uv):
        poly.use_smooth=True
        for loop,xy in zip(poly.loop_indices,coords):uv_layer.data[loop].uv=xy
    meshes.append(obj);stats[name]={'vertices':len(verts),'triangles':len(faces)}
# All clips share one rest rig. Timing is an authored normalized visual envelope.
basis=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
actions=[]
floor_tracks={}
for name,targets in poses.items():
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data_create().action=action
    sequence=envelope(name)
    for frame,factor in sequence:
        for pb in rig.pose.bones:
            xyz=targets.get(pb.name,(0,0,0))
            rot=Euler(tuple(np.radians(xyz)*factor),'XYZ').to_matrix()
            pb.rotation_mode='XYZ';pb.rotation_euler=(basis@rot@basis.transposed()).to_euler()
            pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=pb.name)
        pb=rig.pose.bones['Pelvis'];pb.location=(0,0,0)
        pb.keyframe_insert(data_path='location',frame=frame,group='Pelvis')
    channelbag=action.layers[0].strips[0].channelbag(action.slots[0])
    for fc in channelbag.fcurves:
        for key in fc.keyframe_points:key.interpolation='LINEAR'
    grounded=name not in ['Hop','Fall','DeathAir','Attack68']
    heights=[]
    for frame in range(1,sequence[-1][0]+1):
        scene.frame_set(frame)
        verts=meshes[0].evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices
        heights.append(round(.032-min(v.co.z for v in verts),4) if grounded else 0)
    for frame,height in enumerate(heights,1):
        pb.location=(0,0,height)
        pb.keyframe_insert(data_path='location',frame=frame,group='Pelvis')
    for fc in channelbag.fcurves:
        for key in fc.keyframe_points:key.interpolation='LINEAR'
    floor_tracks[name]=heights
    actions.append(action)
(out/'floor_tracks.json').write_text(json.dumps(floor_tracks,separators=(',',':'))+'\n')
rig.animation_data.action=None
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
for i,obj in enumerate(meshes):obj.hide_viewport=i!=0;obj.hide_render=i!=0
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Scuzz.blend'),compress=True)
for i,obj in enumerate(meshes):
    for m in meshes:m.hide_viewport=False
    bpy.ops.object.select_all(action='DESELECT')
    for o in [rig,obj]+[o for o in rig.children if o.type=='EMPTY']:o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.fbx(filepath=str(out/(obj.name+'.fbx')),use_selection=True,axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=i==0,bake_anim_use_nla_strips=False,bake_anim_use_all_actions=True,bake_anim_simplify_factor=0,path_mode='RELATIVE',apply_unit_scale=False)
(out/'metrics.json').write_text(json.dumps({'lods':stats,'joints':len(bones),'actions':list(poses),'sockets':list(sockets)},indent=2)+'\n')

clips=out/'clips'
clips.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for action in actions:
    rig.animation_data.action=action
    scene.frame_start,scene.frame_end=map(int,action.frame_range)
    bpy.ops.export_scene.fbx(filepath=str(clips/(action.name+'.fbx')),use_selection=True,
        axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=True,
        bake_anim_use_nla_strips=False,bake_anim_use_all_actions=False,bake_anim_simplify_factor=0,
        apply_unit_scale=False)
