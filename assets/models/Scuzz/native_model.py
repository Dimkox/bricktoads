"""Generate the offline native Roblox model with the same runtime primitives and joint hierarchy."""
from pathlib import Path
import xml.etree.ElementTree as ET
import numpy as np
from math import sin,cos
from sculpt import bones, poses, sockets, palette, envelope
from runtime_data import runtime_shapes, tracks

root=ET.Element('roblox',version='4')
counter=0
def obj(parent,cls,name):
    global counter
    counter+=1
    inst=ET.SubElement(parent,'Item',{'class':cls,'referent':'RBX'+str(counter)})
    ET.SubElement(inst,'Properties')
    prop(inst,'string','Name',name)
    return inst
def prop(obj,tag,name,value):
    elem=ET.SubElement(obj.find('Properties'),tag,name=name)
    if tag=='CoordinateFrame':
        for k,v in zip(['X','Y','Z']+['R%d%d'%(i,j) for i in range(3) for j in range(3)],value):
            ET.SubElement(elem,k).text='%.8g'%v
    elif tag=='Vector3':
        for k,v in zip('XYZ',value):ET.SubElement(elem,k).text='%.8g'%v
    elif tag=='Ref':elem.text=value.attrib['referent']
    elif tag=='bool':elem.text=str(value).lower()
    else:elem.text=str(value)
def frame(pos,rot=None):return [*pos,*(np.eye(3) if rot is None else rot).flatten()]
def part(parent,cls,name,p,size,shade=None,rot=None):
    o=obj(parent,cls,name)
    for k in ['CanTouch','CanCollide','CanQuery','Anchored']:prop(o,'bool',k,k=='Anchored' and name=='Anchor')
    prop(o,'bool','Massless',True)
    prop(o,'CoordinateFrame','CFrame',frame(p,rot));prop(o,'Vector3','size',size)
    if shade:
        r,g,b=palette[shade];prop(o,'Color3uint8','Color3uint8',255*2**24+r*2**16+g*256+b)
    else:prop(o,'float','Transparency',1)
    return o
def unit(v):return v/np.linalg.norm(v)
model=obj(root,'Model','Scuzz');anchor=part(model,'Part','Anchor',(0,0,0),(.05,)*3)
prop(model,'Ref','PrimaryPart',anchor)
pivots={}
for name,(parent,pt) in bones.items():
    hub=part(model,'Part',name,pt,(.05,)*3);pivots[name]=hub
    motor=obj(hub,'Motor6D',name+'Motor')
    prop(motor,'Ref','Part0',pivots[parent] if parent else anchor);prop(motor,'Ref','Part1',hub)
    prop(motor,'CoordinateFrame','C0',frame(np.array(pt)-(bones[parent][1] if parent else np.zeros(3))))
for name,bone,shade,p,q,w,d,wedge in runtime_shapes():
    axis=unit(np.subtract(q,p));guide=np.array([1,0,0]) if abs(axis[0])<.9 else np.array([0,0,1])
    right=unit(guide-axis*np.dot(guide,axis));back=-axis
    rot=np.stack([right,np.cross(back,right),back],axis=1)
    elem=part(model,'WedgePart' if wedge else 'Part',name,(np.array(q)+p)*.5,(max(.05,w),max(.05,d),max(.05,np.linalg.norm(np.subtract(q,p)))),shade,rot)
    if not wedge:prop(elem,'token','shape',0)
    # A native Weld stores the authored offset explicitly, independent of Studio's loading order.
    weld=obj(elem,'Weld','ArtWeld');prop(weld,'Ref','Part0',pivots[bone]);prop(weld,'Ref','Part1',elem)
    prop(weld,'CoordinateFrame','C0',frame((np.array(q)+p)*.5-bones[bone][1],rot))
for name,(bone,pt) in sockets.items():
    socket=obj(pivots[bone],'Attachment',name)
    prop(socket,'CoordinateFrame','CFrame',frame(np.subtract(pt,bones[bone][1])))
clips=obj(model,'Folder','Clips')
for name,targets in poses.items():
    clip=obj(clips,'KeyframeSequence',name);prop(clip,'bool','Loop',name in ['IdleAlert','Step','GroupAdvance'])
    keys=envelope(name)
    for f in range(1,keys[-1][0]+1):
        factor=float(np.interp(f,[k[0] for k in keys],[k[1] for k in keys]))
        key=obj(clip,'Keyframe','Keyframe');prop(key,'float','Time',(f-1)/24)
        base=obj(key,'Pose','Anchor');by_bone={}
        for bone,(parent,pt) in bones.items():
            pose=obj(by_bone[parent] if parent else base,'Pose',bone);by_bone[bone]=pose
            x,y,z=np.radians(targets.get(bone,(0,0,0)))*factor
            rx=[[1,0,0],[0,cos(x),-sin(x)],[0,sin(x),cos(x)]]
            ry=[[cos(y),0,sin(y)],[0,1,0],[-sin(y),0,cos(y)]]
            rz=[[cos(z),-sin(z),0],[sin(z),cos(z),0],[0,0,1]]
            dy=tracks[name][f-1] if bone=='Pelvis' else 0
            prop(pose,'CoordinateFrame','CFrame',frame((0,dy,0),np.array(rz)@ry@rx))
file=Path(__file__).with_name('Scuzz.rbxmx')
ET.ElementTree(root).write(file,encoding='utf-8',xml_declaration=True)
