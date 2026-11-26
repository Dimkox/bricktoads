"""Generate the Roblox rig, Studio clips, Blender source and inspection views."""
from author import *
from xml.etree import ElementTree as ET
import subprocess

def rgb(color):
    r,g,b=map(int,color)
    return str((255<<24)|(r<<16)|(g<<8)|b)

def rbx(gas=False):
    tree=ET.Element("roblox",version="4")
    numbered=0
    def item(parent,typ,name):
        nonlocal numbered
        numbered+=1
        obj=ET.SubElement(parent,"Item",{"class":typ,"referent":"RBX"+str(numbered)})
        props=ET.SubElement(obj,"Properties")
        ET.SubElement(props,"string",name="Name").text=name
        return obj,props
    def val(props,typ,key,value): ET.SubElement(props,typ,name=key).text=str(value)
    def vector(props,key,v):
        node=ET.SubElement(props,"Vector3",name=key)
        for k,x in zip("XYZ",v):ET.SubElement(node,k).text=str(float(x))
    def cf(props,key,p,angle=0):
        node=ET.SubElement(props,"CoordinateFrame",name=key)
        for k,x in zip("XYZ",p):ET.SubElement(node,k).text=str(float(x))
        for k,x in zip(range(9),(cos(angle),-sin(angle),0,sin(angle),cos(angle),0,0,0,1)):
            ET.SubElement(node,"R"+str(k//3)+str(k%3)).text=str(float(x))
    name="GasCloud" if gas else "ShadowCloud"
    model,mp=item(tree,"Model",name)
    parts={}
    def ball(name,base,offset,size,color,moving=False,angle=0):
        obj,pr=item(model,"Part",name)
        origin=np.array(offset,dtype=float)
        roll=angle
        if base:
            _,p,a=parts[base]
            origin=p+np.array((cos(a)*origin[0]-sin(a)*origin[1],sin(a)*origin[0]+cos(a)*origin[1],origin[2]))
            roll+=a
        parts[name]=(obj,origin,roll)
        vector(pr,"size",size);cf(pr,"CFrame",origin,roll)
        val(pr,"token","shape",0);val(pr,"Color3uint8","Color3uint8",rgb(color))
        val(pr,"token","Material",272)
        for k in ("CanCollide","CanTouch","CanQuery","Anchored","Massless"):
            val(pr,"bool",k,str(k=="Massless").lower())
        if not base:
            val(pr,"float","Transparency",1);val(mp,"Ref","PrimaryPart",obj.get("referent"))
        else:
            _,jr=item(obj,"Motor6D" if moving else "Weld",name+"Joint")
            val(jr,"Ref","Part0",parts[base][0].get("referent"));val(jr,"Ref","Part1",obj.get("referent"))
            cf(jr,"C0",offset,angle);cf(jr,"C1",(0,0,0))
    ball("Root",None,(0,0,0),(.1,.1,.1),(0,0,0))
    if gas:
        for i in range(1,5):
            ball("Puff"+str(i),"Root",(.30*cos(i*2.4),.21*sin(i*2.4),.19*i-.4),(.85,.71,.76),
                 (143-i*10,164-i*8,47))
    else:
        ball("Core","Root",(0,0,0),(4.10,3.45,2.78),(61,92,24),True)
        for i,(p,size,c) in enumerate(LOBES,1):
            n="Lobe"+str(i)
            ball(n,"Core",p,size,c,True)
            for j in range(1,4):
                a=i*1.7+j*2.09
                ball(f"Fold{i}_{j}",n,(cos(a)*size[0]*.28,sin(a)*size[1]*.27,(1 if i==6 else -1)*size[2]*.30),
                     np.array(size)*(.48,.51,.46),np.array(c)+(4*j,4*j,0))
        ball("MouthRim","Core",(MX,MY,-1.32),(2.14,2.51,.72),(95,134,24),True,-.26)
        ball("Gullet","MouthRim",(0,0,-.18),(1.71,2.10,.46),(21,32,11))
        ball("Throat","MouthRim",(-.06,.03,-.26),(1.37,1.77,.35),(10,15,8))
        for s,n in [(1,"MouthUpper"),(-1,"MouthLower")]:
            ball(n,"MouthRim",(0,s*1.04,-.12),(1.33,.42,.42),(120,157,28),True)
        for n in ("Aim","Mouth","GasOrigin","WindOrigin","HitFX"):
            _,pr=item(parts["Core" if n=="HitFX" else "MouthRim"][0],"Attachment",n)
            cf(pr,"CFrame",(0,.8,-1.22) if n=="HitFX" else (0,0,-.55))
        folder,_=item(model,"Folder","Clips")
        rig=geometry(2)
        for clip,duration in CLIPS.items():
            seq,pr=item(folder,"KeyframeSequence",clip)
            val(pr,"bool","Loop",str(clip in ("HoverIdle","Drift","WindBlow")).lower())
            for t in np.linspace(0,1,9):
                frame,pr=item(seq,"Keyframe",f"{t:.3f}")
                val(pr,"float","Time",t*duration)
                for marker,m in MARKERS.get(clip,{}).items():
                    if t==m:item(frame,"KeyframeMarker",marker)
                chain={}
                for n,(parent,_,_) in rig.items():
                    if n not in parts:continue
                    p,pp=item(chain[parent] if parent else frame,"Pose",n)
                    chain[n]=p
                    d,angle=pose(n,clip,t);cf(pp,"CFrame",d,angle)
    ET.ElementTree(tree).write(OUT/(name+".rbxmx"),encoding="utf-8",xml_declaration=True)

from inspect_gl import render_data, render

def preview():
    meshes=geometry(0);chunks=render_data(meshes)
    sheet=Image.new("RGB",(768,812),(23,32,36));draw=ImageDraw.Draw(sheet)
    for i,(label,yaw) in enumerate([("Front",0),("Three-quarter",-.62),("Side",-pi/2),("Back",pi)]):
        x=i%2*384;y=i//2*406
        sheet.paste(render(meshes,chunks,yaw,.08),(x,y));draw.text((x+14,y+384),label,fill="white")
    sheet.save(OUT/"Views.jpg",quality=90)
    meshes=geometry(0);chunks=render_data(meshes)
    target=OUT/"States.mp4"
    cmd=["ffmpeg","-hide_banner","-loglevel","error","-y","-f","rawvideo","-pixel_format","rgb24",
         "-video_size","256x256","-framerate","15","-i","-","-c:v","libx264","-crf","22",
         "-pix_fmt","yuv420p",str(target)]
    with subprocess.Popen(cmd,stdin=subprocess.PIPE) as encoder:
        for clip in ["Turntable"]+list(CLIPS):
            for t in np.linspace(0,1,45 if clip=="Turntable" else 14):
                im=render(meshes,chunks,TAU*t if clip=="Turntable" else -.22,.08,clip,t,256)
                ImageDraw.Draw(im).text((9,9),clip,fill="white");encoder.stdin.write(im.tobytes())
        encoder.stdin.close()
        if encoder.wait():raise RuntimeError("ffmpeg failed")

def blend():
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/"ShadowCloud_LOD0.glb"))
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"ShadowCloud.blend"),compress=True)

if __name__=="__main__":
    rbx();rbx(True);preview();blend()
