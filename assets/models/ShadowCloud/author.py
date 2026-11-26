"""BT-107 procedural DCC source. Run with Python 3 + numpy + Pillow."""
from pathlib import Path
import json
import struct
from math import sin, cos, pi, exp, sqrt
import numpy as np
from PIL import Image, ImageDraw
import io

OUT = Path(__file__).resolve().parent
TAU = 2*pi
# Name, parent, center, diameters, sRGB albedo.
LOBES = [
    ((.15,1.02,.23),(3.30,2.06,2.69),(107,143,27)),
    ((1.33,.18,.12),(2.49,2.60,2.84),(85,126,29)),
    ((.76,-.97,.10),(2.53,2.14,2.66),(77,113,27)),
    ((-1.28,.65,.18),(2.50,2.15,2.73),(112,150,32)),
    ((-1.36,-.88,.35),(2.24,1.91,2.46),(71,111,24)),
    ((.23,.02,1.01),(2.93,2.74,1.57),(85,123,29))]
CLIPS = {"HoverIdle":1.8,"Drift":1.2,"Turn":.6,"MouthPulse":.6,"GasTell":.5,
         "GasRelease":.2,"GasRecover":.9,"WindTell":.55,"WindBlow":1.2,"WindStop":.4,
         "HitLight":.25,"HitHeavy":.45,"Defeat":.75,"TransitionBC":.32,"TransitionBD":.32}
MARKERS = {"GasRelease":{"GasRelease":0},"GasRecover":{"RecoveryEnd":1},
           "WindBlow":{"BlowOn":0},"WindStop":{"BlowOff":0,"RecoveryEnd":1}}
MX, MY = -1.04, -.44

def textures():
    y,x=np.mgrid[0:1024,0:1024]/1024*TAU
    h=.38*np.sin(17*x+2*np.sin(9*y))*np.cos(13*y)+.17*np.sin(41*x+5*np.sin(7*y))*np.cos(29*y)
    h+=.14*np.sin(83*x+14*np.cos(y))*np.sin(59*y)
    def save(name,a):
        Image.fromarray(np.asarray(a,dtype=np.uint8)).save(OUT/(name+".png"),optimize=True)
    save("ColorMap",np.stack([241+18*h,244+15*h,230+21*h],-1))
    dx=(np.roll(h,1,1)-np.roll(h,-1,1))*.56
    dy=(np.roll(h,1,0)-np.roll(h,-1,0))*.56
    normals=np.stack([dx,dy,np.ones_like(h)],-1)
    save("NormalMap",127.5+127.5*normals/np.linalg.norm(normals,axis=-1,keepdims=True))
    save("RoughnessMap",(186+31*h)[::2,::2])
    save("MetalnessMap",np.zeros((512,512)))

class Geometry:
    def __init__(self):
        self.p,self.uv,self.col,self.tris=[],[],[],[]
    def grid(self,u,v,fn):
        first=len(self.p)
        for j in range(v+1):
            for i in range(u+1):
                pos,col=fn(i/u,j/v)
                self.p.append(pos);self.uv.append((i/u,j/v));self.col.append(col)
        for j in range(v):
            for i in range(u):
                a=first+j*(u+1)+i
                self.tris.extend([(a,a+1,a+u+2),(a,a+u+2,a+u+1)])
    def sphere(self,center,size,color,u,v,base,seed,carve=True):
        def fn(s,t):
            a,b=TAU*s,pi*(t-.5)
            nx,ny,nz=cos(a)*cos(b),sin(b),sin(a)*cos(b)
            w=1+.044*sin(3*a+seed)*cos(b)**2+.036*cos(5*a+4*b)*cos(b)**2
            px,py,pz=[center[k]+n*size[k]*.5*w for k,n in enumerate((nx,ny,nz))]
            if carve:
                # Hollow space behind the continuous modeled lips and blind throat.
                r=((px+base[0]-MX)/1.05)**2+((py+base[1]-MY)/1.27)**2
                if r<1.3 and pz+base[2]<.22:
                    pz=max(pz, .16-1.6*min(1,r/1.3)**2-base[2])
            tint=.88+.12*ny+.05*cos(a*3+b)
            return (px,py,pz),np.clip(np.array(color)*tint/255,0,1)**2.2
        # flip longitude for outward triangles
        self.grid(u,v,lambda s,t:fn(1-s,t))

def geometry(lod=0,gas=False):
    meshes={}
    def obj(name,parent,pos):
        g=Geometry();meshes[name]=(parent,np.array(pos,dtype=float),g);return g
    root=obj("Root",None,(0,0,0))
    if gas:
        for i in range(4):
            root.sphere((.30*cos(i*2.4),.21*sin(i*2.4),.19*i-.21),(.85,.71,.76),
                        (140-i*8,160-i*6,47),10,6,(0,0,0),i,False)
        return meshes
    u,v=[(16,10),(12,7),(8,5)][lod]
    core=obj("Core","Root",(0,0,0))
    core.sphere((0,0,0),(4.1,3.45,2.78),(65,97,24),u,v,(0,0,0),0)
    for i,(loc,size,color) in enumerate(LOBES,1):
        g=obj("Lobe"+str(i),"Core",loc)
        g.sphere((0,0,0),size,color,u,v,loc,i)
        for j in range(3):
            a=i*1.7+(j+1)*2.09
            p=(cos(a)*size[0]*.28,sin(a)*size[1]*.27,(1 if i==6 else -1)*size[2]*.30)
            g.sphere(p,np.array(size)*(.48,.51,.46),np.array(color)+(9,10,0),
                     max(6,u-4),max(3,v-3),loc,i+j*.45)
    rim=obj("MouthRim","Core",(MX,MY,-1.33))
    # Revolved section travels from blind inner throat to the outer rear closure.
    # Small radial waves follow the entire lip into the mouth.
    profile=[(0,.61,(11,18,8)),(.30,.50,(14,22,10)),(.58,.18,(23,33,12)),
             (.76,-.18,(33,49,14)),(.83,-.35,(58,82,19)),(.89,-.47,(137,171,39)),
             (.99,-.40,(115,151,29)),(1.06,-.19,(92,124,22)),(1.03,.08,(73,104,19)),
             (.82,.36,(62,84,19)),(0,.66,(51,74,18))]
    def section(s,t):
        r,z,c=profile[round(t*(len(profile)-1))]
        a=TAU*s
        r*=1+.047*cos(5*a)+.025*sin(7*a)
        x,y=r*cos(a),r*1.15*sin(a)
        return (x+.17*y,y,z+.05*r*sin(3*a)),(np.array(c)/255)**2.2
    rim.grid([36,28,18][lod],len(profile)-1,section)
    for sign,name in [(1,"MouthUpper"),(-1,"MouthLower")]:
        obj(name,"MouthRim",(sign*.13,sign*1.02,-.28)).sphere(
            (0,0,0),(1.15,.37,.30),(120,159,31),u,v,(0,0,0),sign,False)
    for n in ("Aim","Mouth","GasOrigin","WindOrigin"):
        obj(n,"MouthRim",(0,0,-.55))
    obj("HitFX","Core",(0,.8,-1.22))
    return meshes

def pose(name,clip,t):
    cycle=sin(TAU*t);accent=sin(pi*t)
    squeeze=opened=lift=tilt=0
    if clip in ("GasTell","WindTell","TransitionBC"): squeeze=t;opened=-t
    elif clip=="GasRelease": squeeze=1-t;opened=1.3*t
    elif clip=="GasRecover": opened=1.3*(1-t)
    elif clip=="WindBlow": opened=.8+.2*cycle
    elif clip=="WindStop": opened=.8*(1-t)
    elif clip=="MouthPulse": opened=accent
    elif clip=="TransitionBD": squeeze=1-t;opened=t-1
    elif clip=="Turn": tilt=.26*accent
    elif clip=="Drift": lift=.11*cycle;tilt=.08*cycle
    elif clip in ("HitLight","HitHeavy"): tilt=accent*(-.32 if clip=="HitHeavy" else -.14)
    elif clip=="Defeat": tilt=.36*t;squeeze=t;lift=-.35*t
    else: lift=.09*cycle
    delta=np.zeros(3);roll=0.
    if name=="Core": delta[1]=lift;roll=tilt
    elif name.startswith("Lobe"):
        delta[:2]=-np.asarray(LOBES[int(name[4:])-1][0][:2])*.12*squeeze
    elif name=="MouthRim": delta[2]=-.13*opened
    elif name in ("MouthUpper","MouthLower"): delta[1]=(.15 if name=="MouthUpper" else -.15)*opened
    return delta,roll

def export(meshes,file,animated):
    g={"asset":{"version":"2.0","generator":"BrickToads BT-107"},"scene":0,"scenes":[{"nodes":[0]}],
       "nodes":[],"meshes":[],"accessors":[],"bufferViews":[],"buffers":[],"materials":[{}]}
    binary=bytearray()
    def view(raw):
        binary.extend(bytes((-len(binary))%4));offset=len(binary);binary.extend(raw)
        g["bufferViews"].append({"buffer":0,"byteOffset":offset,"byteLength":len(raw)})
        return len(g["bufferViews"])-1
    def acc(data,dtype,kind,bounds=False):
        ar=np.asarray(data,dtype=dtype)
        ac={"bufferView":view(ar.tobytes()),"count":len(ar),"type":kind,
            "componentType":5123 if dtype=="<u2" else 5126}
        if bounds: ac.update(min=ar.min(axis=0).reshape(-1).tolist(),max=ar.max(axis=0).reshape(-1).tolist())
        g["accessors"].append(ac);return len(g["accessors"])-1
    # Pack roughness/metalness in standard glTF channels.
    rough=Image.open(OUT/"RoughnessMap.png")
    packed=Image.merge("RGB",(Image.new("L",rough.size,255),rough,Image.open(OUT/"MetalnessMap.png")))
    buf=io.BytesIO();packed.save(buf,format="PNG")
    imgs=[(OUT/"ColorMap.png").read_bytes(),(OUT/"NormalMap.png").read_bytes(),buf.getvalue()]
    g["images"]=[{"bufferView":view(img),"mimeType":"image/png"} for img in imgs]
    g["textures"]=[{"source":i} for i in range(3)]
    g["materials"][0]={"name":"Cloud skin","normalTexture":{"index":1,"scale":.55},
      "pbrMetallicRoughness":{"baseColorTexture":{"index":0},"metallicRoughnessTexture":{"index":2}}}
    names=list(meshes)
    for name,(parent,pivot,m) in meshes.items():
        node={"name":name,"translation":pivot.tolist()};g["nodes"].append(node)
        children=[names.index(k) for k,(p,_,_) in meshes.items() if p==name]
        if children: node["children"]=children
        if not m.p: continue
        pos=np.array(m.p);tri=np.array(m.tris);norm=np.zeros_like(pos)
        a,b,c=pos[tri[:,0]],pos[tri[:,1]],pos[tri[:,2]]
        cross=np.cross(b-a,c-a)
        keep=np.linalg.norm(cross,axis=1)>1e-8
        tri=tri[keep];cross=cross[keep]
        for k in range(3): np.add.at(norm,tri[:,k],cross)
        # Smooth coincident UV seam vertices.
        buckets={}
        for i,p in enumerate(pos): buckets.setdefault(tuple(p.round(6)),[]).append(i)
        for ids in buckets.values(): norm[ids]=norm[ids].sum(axis=0)
        nlen=np.linalg.norm(norm,axis=1)
        norm[nlen<1e-8]=(0,1,0)
        norm/=np.linalg.norm(norm,axis=1,keepdims=True)
        attrs={"POSITION":acc(pos,"<f4","VEC3",True),"NORMAL":acc(norm,"<f4","VEC3"),
               "TEXCOORD_0":acc(m.uv,"<f4","VEC2"),"COLOR_0":acc(m.col,"<f4","VEC3")}
        node["mesh"]=len(g["meshes"])
        g["meshes"].append({"name":name,"primitives":[{"attributes":attrs,
               "indices":acc(tri.flatten(),"<u2","SCALAR"),"material":0}]})
    if animated:
        g["animations"]=[]
        for clip,duration in CLIPS.items():
            keys=np.linspace(0,1,9);time=acc(keys*duration,"<f4","SCALAR",True)
            anim={"name":clip,"samplers":[],"channels":[],"extras":{"markersNormalized":MARKERS.get(clip,{})}}
            for i,(name,(_,pivot,_)) in enumerate(meshes.items()):
                offsets,angles=zip(*(pose(name,clip,t) for t in keys))
                for path,values,kind,active in [
                    ("translation",pivot+np.array(offsets),"VEC3",np.any(offsets)),
                    ("rotation",[(0,0,sin(a/2),cos(a/2)) for a in angles],"VEC4",np.any(angles))]:
                    if active:
                        anim["channels"].append({"sampler":len(anim["samplers"]),"target":{"node":i,"path":path}})
                        anim["samplers"].append({"input":time,"output":acc(values,"<f4",kind),"interpolation":"LINEAR"})
            g["animations"].append(anim)
    g["buffers"]=[{"byteLength":len(binary)}]
    document=json.dumps(g,separators=(",",":")).encode()
    document+=b" "*((-len(document))%4);binary.extend(bytes((-len(binary))%4))
    file.write_bytes(struct.pack("<4sII",b"glTF",2,28+len(document)+len(binary))+
        struct.pack("<I4s",len(document),b"JSON")+document+struct.pack("<I4s",len(binary),b"BIN\0")+binary)
    return sum(g["accessors"][m["primitives"][0]["indices"]]["count"]//3 for m in g["meshes"])

if __name__=="__main__":
    textures()
    for lod in range(3):
        print("LOD",lod,export(geometry(lod),OUT/f"ShadowCloud_LOD{lod}.glb",True))
    print("Gas",export(geometry(gas=True),OUT/"GasCloud.glb",False))
