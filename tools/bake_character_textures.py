"""Bake species markings into diffuse atlases for the articulated release meshes."""
from pathlib import Path
import hashlib
import io
import json
import math
import struct
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAST = ROOT / "assets/characters/canonical-cast"
HERO = ROOT / "assets/characters/canonical-hero"
OUT = ROOT / "build/field-textures"
sys.path.insert(0, str(CAST))
from pack_cast import parse
import build_cast

# Broad markings survive the follow camera. Each scheme gives body, shadow,
# belly/face, and identifying accent, all in sRGB.
SCHEMES = {
    "Pig": ("armor", "cc635f 65343e ffa894 e2b05e"),
    "Dragon": ("scales", "169881 185560 f0cd74 ff774c"),
    "Raven": ("feathers", "293e71 202035 558ab1 5abbb6"),
    "LargeRaven": ("feathers", "463265 291f44 9a78b8 eb8551"),
    "Duck": ("feathers", "36715a 2d403d f4ddb7 f09c35"),
    "Shark": ("gills", "397a9d 1c425e d5f0df 609fb0"),
    "Hammerfish": ("reef", "e37837 913f38 ffe1a0 1f8f9a"),
    "Electrofish": ("bolt", "2575ac 193d73 a1e9e0 ffdf4d"),
    "HealingFly": ("bee", "efa839 3d3940 e6fff3 85dbb1"),
    "Snake": ("diamonds", "3c9067 184a4b eadd8a df8745"),
    "Slug": ("spots", "b18cca 533d73 ffdbab 63467c"),
    "SaturnToadtrap": ("teeth", "94982f 3a4a33 fff2bc ee8152"),
    "Snowman": ("snow", "dceef1 3f5668 f7fcff e14e43"),
    "Hordhead": ("fur", "ab865e 573b36 f0d1a1 db6442"),
    "RacingRat": ("check", "b65c47 593542 e9c596 f4ce47"),
    "RocketRat": ("thruster", "a97656 584855 ffcc97 52bcc6"),
    "Invader": ("circuit", "70b555 265c54 baed8c 61e1d5"),
    "Robot": ("armor", "7188a2 283b53 d5d4c0 f58b3e"),
    "SentryDrone": ("reticle", "426981 21354c d1e3dc ff6749"),
    "GasTurret": ("hazard", "6a806f 344b4d b6cb86 e5e246"),
    "RetroBlaster": ("circuit", "985180 482f60 ebadbd 6fd9dd"),
    "FlyingHead": ("bolt", "be6177 623455 ffbaa5 73ccdc"),
    "Swellcheeks": ("spots", "75a65f 305b51 e2d489 f39c56"),
    "BigBlag": ("vest", "795647 393342 dfad87 bc5647"),
    "RoboManus": ("armor", "466a9e 253749 c8d5d6 f0a636"),
    "GeneralSlaughter": ("chevron", "a34c41 4c3737 e8bc8e ecc059"),
    "Buzzball": ("hazard", "efaa31 413949 ffe396 f45c46"),
    "DarkQueen": ("brocade", "69438b 32263e f2ab92 66ddcb"),
    "CausewayGuardian": ("hazard", "b94b39 3b4249 cdab75 f5ba4a"),
    "MrGreen": ("spots", "58983d 315d39 adce59 d6e879"),
    "MrYellow": ("chevron", "d79735 965a2f ffe49b fcf0a8"),
    "MrBrown": ("diamonds", "a36c4b 613d39 e0ae77 ecad69"),
}

def rgb(value):
    return np.array(list(bytes.fromhex(value)), dtype=float)

def motifs(style, u, v):
    x, y = u*4, v*4
    dx, dy = (x+.5*(np.floor(y)%2))%1-.5, y%1-.5
    cell = np.sqrt(dx*dx+dy*dy)
    vein = abs((y+.64*abs(x%1-.5))%1-.5)
    diagonal = (x*.77+y*.55)%1
    if style=="scales": return vein<.085, (vein<.18)&(vein>=.085)
    if style=="feathers": return abs((x+.65*y)%1-.5)<.065, vein<.085
    if style in ("spots","snow"): return cell<.26, (cell<.13)&(dx<.04)
    if style=="diamonds": return abs(dx)+abs(dy)<.43, abs(dx)+abs(dy)<.17
    if style in ("armor","thruster"): return (abs(dy)>.45)|(abs(dx)>.465), (abs(dy)>.33)&(abs(dy)<.43)&(dx>0)
    if style=="circuit": return (abs(dx)<.055)|(abs(dy)<.055), cell<.16
    if style=="bolt": return abs((y+1.3*abs(x%1-.5))%1-.5)<.14, cell<.09
    if style=="bee": return (v*3.2+.11*np.cos(u*6))%1<.38, (v*3.2+.11*np.cos(u*6))%1>.93
    if style=="gills": return (u>.45)&(u<.89)&(diagonal<.15), v>.79
    if style=="reef": return abs(np.sin(3*np.pi*u+1.1*np.sin(v*5)))<.32, cell<.12
    if style=="check": return ((np.floor(x*1.4)+np.floor(y*1.4))%2==0)&(v<.49), abs(v-.5)<.055
    if style=="reticle": return abs(np.hypot(u-.5,v-.5)-.28)<.055, (abs(u-.5)<.04)|(abs(v-.5)<.04)
    if style=="teeth": return vein<.13, cell<.12
    if style=="vest": return (abs(u-.5)>.35)|(abs(v-.73)<.06), (abs(v-.73)<.035)&(u>.44)&(u<.56)
    if style=="fur": return (abs(dx+.33*dy)<.10)&(dy<.23), cell<.10
    if style=="brocade": return abs(abs(dx)+abs(dy)-.37)<.07, cell<.11
    if style=="chevron": return ((v*2+abs(u-.5)*1.65)%1)<.26, ((v*2+abs(u-.5)*1.65)%1)<.09
    if style=="hazard": return diagonal<.34, (diagonal>.83)&(diagonal<.94)
    raise ValueError(style)

def parse_file(path):
    scene, data = parse(path.read_bytes())
    return scene,bytearray(data)

def values(scene,data,i):
    a=scene["accessors"][i]; view=scene["bufferViews"][a["bufferView"]]
    dim={"VEC2":2,"VEC3":3,"VEC4":4,"SCALAR":1}[a["type"]]
    dtype={5126:"<f4",5123:"<u2",5125:"<u4"}[a["componentType"]]
    offset=view.get("byteOffset",0)+a.get("byteOffset",0)
    assert "byteStride" not in view
    return np.frombuffer(data,dtype=dtype,count=a["count"]*dim,offset=offset).reshape(-1,dim).copy()

def diffuse(scene,data):
    mat=scene["materials"][0]["pbrMetallicRoughness"]
    image=scene["images"][scene["textures"][mat["baseColorTexture"]["index"]]["source"]]
    view=scene["bufferViews"][image["bufferView"]];start=view.get("byteOffset",0)
    return image,Image.open(io.BytesIO(data[start:start+view["byteLength"]])).convert("RGBA")

def install(scene,data,image,texture):
    buf=io.BytesIO(); texture.save(buf,format="PNG",optimize=True); png=buf.getvalue()
    data.extend(b"\0"*(-len(data)%4))
    view={"buffer":0,"byteOffset":len(data),"byteLength":len(png)}
    image["bufferView"]=len(scene["bufferViews"]); image["mimeType"]="image/png"
    scene["bufferViews"].append(view);data.extend(png)
    return png

def save(scene,data,path):
    scene["buffers"][0]["byteLength"]=len(data)
    js=json.dumps(scene,separators=(",",":")).encode();js+=b" "*(-len(js)%4)
    data+=b"\0"*(-len(data)%4)
    path.write_bytes(struct.pack("<4sII",b"glTF",2,28+len(js)+len(data))+struct.pack("<I4s",len(js),b"JSON")+js+struct.pack("<I4s",len(data),b"BIN\0")+data)

def rocket_skin(original):
    u,v=np.meshgrid(np.linspace(0,1,96),np.linspace(0,1,96))
    steel=rgb("afc5d1")
    color=np.broadcast_to(steel,(96,96,3)).copy()
    color[u<.16]=rgb("cedbe1")
    color[u>.81]=rgb("657787")
    color[(u>.72)&(u<.755)]=rgb("cb733c")
    # Circumferential panel joints and paired rivets on each flange.
    for seam in (.17,.56,.79,.89):
        color[abs(u-seam)<.009]=rgb("485965")
        color[(u>seam+.009)&(u<seam+.022)]=rgb("d5e0e4")
        bolts=((u-seam-.036)/.012)**2+(((v+.1)%.2-.1)/.026)**2<1
        color[bolts]=rgb("61727d")
    if original==build_cast.PINK:
        color[:]=rgb("e3edf0")
    brushing=1+.018*np.sin(v*243+u*6)+.012*np.cos(v*131-u*12)
    return np.uint8(np.clip(color*brushing[:,:,None],0,255))

def tile(kind,segment,original,dominant):
    if kind=="RocketRat" and segment=="Weapon":
        return rocket_skin(original)
    style,swatches=SCHEMES[kind]; base,dark,light,accent=map(rgb,swatches.split())
    src=np.array(original); u,v=np.meshgrid(np.linspace(0,1,96),np.linspace(0,1,96))
    shade=src.mean()
    primary=original==dominant
    if original==(254,253,250): base=np.array([252,237,196]);strength=0
    elif original==(22,27,32): base=np.array([27,24,39]);strength=0
    elif not primary and max(original)-min(original)<12 and shade<43: base=dark*.48; strength=.04
    elif not primary and min(original)>205: base=np.array([249,241,207]); strength=.04
    elif primary:
        strength=.82
        if "Wing" in segment and kind=="Dragon": base=accent;accent=light
        elif segment in ("Jaw","Tail") and kind not in ("DarkQueen","RoboManus"): base=.54*base+.46*light
    else:
        base=light if shade>110 else .68*dark+.32*base
        strength=.26
    if kind in ("Raven","LargeRaven","Duck") and (segment=="Jaw" or
        (segment=="Head" and original in (build_cast.ORANGE,build_cast.RED) and not primary)):
        base=np.array([244,173,64]);strength=.08
    if kind=="Duck" and segment=="Head" and primary: base=np.array([33,125,91])
    if kind=="HealingFly" and "Wing" in segment:base=np.array([189,238,228]);strength=.15
    if kind=="Snowman" and segment=="Head":
        if original in (build_cast.PINK,build_cast.RED):base=light;strength=.09
        if original==build_cast.BROWN:base=dark;strength=.15
        if original==build_cast.ORANGE:base=np.array([244,151,65]);strength=.05
    if kind=="DarkQueen" and segment=="Head" and primary:base=light;strength=.09
    if kind=="Snowman" and segment=="Body" and primary:base=light;strength=.18
    mask,highlight=motifs(style,u,v)
    grain=.98+.024*np.sin(u*51+v*37)+.016*np.cos(v*79-u*19)
    color=np.broadcast_to(base,(96,96,3)).copy()
    color[mask]=(1-strength*.65)*base+strength*.65*dark
    color[highlight]=(1-strength*.83)*base+strength*.83*accent
    return np.uint8(np.clip(color*grain[:,:,None],0,255))

def bake_cast(kind,path):
    scene,data=parse_file(path);img,old=diffuse(scene,data);old=np.array(old)[:,:,:3]
    source=None
    if kind in build_cast.BUILDERS:
        # The release meshes retain authoring vertex order. Recover the colour roles
        # that the old three-colour palette merged, especially pupils and beaks.
        eye=build_cast.eye
        def marked_eye(mesh,x,y,z,s=.15,color=None,pupil=None):
            return eye(mesh,x,y,z,s,(254,253,250),(22,27,32))
        build_cast.eye=marked_eye
        try:
            source=build_cast.BUILDERS[kind]()
        finally:
            build_cast.eye=eye
    specs=[];tiles={}
    for mesh in scene["meshes"]:
        name=mesh["name"]
        for prim in mesh["primitives"]:
            attr=prim["attributes"]; uv=values(scene,data,attr["TEXCOORD_0"]);pos=values(scene,data,attr["POSITION"])
            ix=values(scene,data,prim["indices"]).ravel()
            col=old[np.clip((uv[:,1]*old.shape[0]).astype(int),0,old.shape[0]-1),np.clip((uv[:,0]*old.shape[1]).astype(int),0,old.shape[1]-1)]
            if source:
                col=np.asarray(source.parts[name].colors)
                assert len(col)==len(pos)
            colors,indices=np.unique(col,axis=0,return_inverse=True);indices=indices.ravel()
            triangles=pos[ix.reshape(-1,3)]
            area=np.linalg.norm(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]),axis=1)
            dominant=tuple(colors[np.bincount(indices[ix],weights=np.repeat(area,3)).argmax()].tolist())
            # Oblique projection exposes markings on the front, profile, and crown.
            projected=np.stack([pos[:,0]+.63*pos[:,2],-pos[:,1]+.31*pos[:,2]],axis=1)
            if kind=="RocketRat" and name=="Weapon":
                projected=np.stack([pos[:,2],-pos[:,1]+.35*pos[:,0]],axis=1)
                steel={
                    "name":"RocketBrushedSteel",
                    "pbrMetallicRoughness":{
                        "baseColorTexture":{"index":0},
                        "metallicFactor":.9,"roughnessFactor":.32,
                    },
                }
                prim["material"]=len(scene["materials"])
                scene["materials"].append(steel)
            projected=(projected-projected.min(0))/np.maximum(np.ptp(projected,axis=0),1e-6)
            keys=[]
            for color in colors.tolist():
                key=(name,tuple(color))
                if key not in tiles: tiles[key]=tile(kind,name,tuple(color),dominant)
                keys.append(key)
            specs.append((attr["TEXCOORD_0"],projected,indices,keys))
    cols=math.ceil(math.sqrt(len(tiles)));rows=math.ceil(len(tiles)/cols)
    atlas=np.zeros((rows*100,cols*100,3),np.uint8);offsets={}
    for i,(key,pixels) in enumerate(tiles.items()):
        x=i%cols*100;y=i//cols*100
        atlas[y:y+100,x:x+100]=np.pad(pixels,((2,2),(2,2),(0,0)),mode="edge")
        offsets[key]=(x+2.5,y+2.5)
    for index,coords,indices,keys in specs:
        xy=np.array([offsets[k] for k in keys])[indices]+coords*95
        uv=np.asarray(xy/[cols*100,rows*100],dtype="<f4")
        a=scene["accessors"][index];view=scene["bufferViews"][a["bufferView"]];start=view.get("byteOffset",0)+a.get("byteOffset",0)
        data[start:start+uv.nbytes]=uv.tobytes()
        if "min" in a: a["min"]=uv.min(0).tolist();a["max"]=uv.max(0).tolist()
    scene["samplers"][0].update(magFilter=9729,minFilter=9987)
    return scene,data,img,Image.fromarray(atlas)

def bake_hero(kind,path):
    scene,data=parse_file(path);img,old=diffuse(scene,data)
    pixels=np.asarray(old).copy();original=pixels[:,:,:3].astype(float)
    green,red,blue=original[:,:,1],original[:,:,0],original[:,:,2]
    if kind=="MrGreen": mask=(green>red*1.08)&(green>blue*1.08)&(green>12)
    elif kind=="MrYellow":mask=(red>green*1.03)&(green>blue*1.38)&(green>25)
    else:mask=(red>green*1.09)&(green>blue*1.08)&(green>28)&(red<green*1.7)
    y,x=np.indices(mask.shape,dtype=np.float32)
    u=(x/970)%1;v=(y/970)%1
    style,swatches=SCHEMES[kind];base,dark,light,accent=map(rgb,swatches.split())
    m,h=motifs(style,u,v)
    shade=np.clip(original.max(2)/200,.25,1.23)[:,:,None]
    color=original*.45+base*shade*.55
    color[m]=color[m]*.62+dark*shade[m]*.38
    color[h]=color[h]*.39+accent*shade[h]*.61
    pixels[:,:,:3][mask]=np.uint8(np.clip(color[mask],0,255))
    return scene,data,img,Image.fromarray(pixels)

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    for kind in SCHEMES:
        if kind.startswith("Mr"):
            key={"MrGreen":"player1","MrYellow":"player2","MrBrown":"brown"}[kind]
            m=json.loads((HERO/f"roblox-{key}.json").read_text());path=HERO/m["sourceGlbFile"]
            assert hashlib.sha256(path.read_bytes()).hexdigest()==m["sourceGlbSha256"]
            scene,data,img,texture=bake_hero(kind,path)
        else:
            path=HERO/"boss-walker.glb" if kind=="CausewayGuardian" else CAST/kind/(kind+".glb")
            scene,data,img,texture=bake_cast(kind,path)
        png=install(scene,data,img,texture);(OUT/(kind+".png")).write_bytes(png)
        save(scene,data,OUT/(kind+".glb"))
    print(f"{len(SCHEMES)} textured models in {OUT}")

if __name__=="__main__": main()
