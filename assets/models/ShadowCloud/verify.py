"""Validate exported files independently of Blender and record measured budgets."""
from pathlib import Path
from xml.etree import ElementTree as ET
import struct
import json
import numpy as np
from PIL import Image
from author import CLIPS, MARKERS

HERE=Path(__file__).resolve().parent
records={}
for stem,cap in [("ShadowCloud_LOD0",10000),("ShadowCloud_LOD1",5000),("ShadowCloud_LOD2",1800),("GasCloud",800)]:
    raw=(HERE/(stem+".glb")).read_bytes()
    assert struct.unpack_from("<4sII",raw)==(b"glTF",2,len(raw))
    size=struct.unpack_from("<I",raw,12)[0]
    g=json.loads(raw[20:20+size])
    base=size+28
    def read(acc_id):
        a=g["accessors"][acc_id];v=g["bufferViews"][a["bufferView"]]
        shape={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[a["type"]]
        return np.frombuffer(raw,dtype={5123:"<u2",5126:"<f4"}[a["componentType"]],
                      count=a["count"]*shape,offset=base+v["byteOffset"]).reshape(-1,shape)
    nodes=g["nodes"];world={};bounds=[];per_mesh={}
    for i,n in enumerate(nodes):
        parents=[k for k,p in enumerate(nodes) if i in p.get("children",[])]
        world[i]=np.array(n["translation"])+(world[parents[0]] if parents else 0)
        if "mesh" not in n: continue
        p=g["meshes"][n["mesh"]]["primitives"][0]
        idx=read(p["indices"]).flatten()
        pos=read(p["attributes"]["POSITION"])
        assert idx.max()<len(pos) and idx.size%3==0 and idx.size//3<=8000
        assert np.isfinite(pos).all()
        normal=read(p["attributes"]["NORMAL"])
        assert np.allclose(np.linalg.norm(normal,axis=1),1,atol=1e-5)
        uv=read(p["attributes"]["TEXCOORD_0"])
        assert uv.min()>=0 and uv.max()<=1
        per_mesh[n["name"]]=idx.size//3
        bounds.append(pos+world[i])
    total=sum(per_mesh.values());assert total<=cap
    pts=np.concatenate(bounds)
    records[stem]={"triangles":total,"perMesh":per_mesh,"boundsMin":pts.min(axis=0).round(4).tolist(),
                   "boundsMax":pts.max(axis=0).round(4).tolist()}
    if stem!="GasCloud":
        assert {a["name"] for a in g["animations"]}==set(CLIPS)
        for a in g["animations"]:
            assert all(nodes[c["target"]["node"]]["name"]!="Root" for c in a["channels"])
            for s in a["samplers"]:
                t=read(s["input"]).flatten()
                assert t[0]==0 and np.all(np.diff(t)>0) and np.isclose(t[-1],CLIPS[a["name"]])
                assert np.isfinite(read(s["output"])).all()
        assert {"Aim","Mouth","GasOrigin","WindOrigin","HitFX"}<={n["name"] for n in nodes}
        if stem.endswith("0"):rig={n["name"]:{"localTranslation":n["translation"],
            "parent":next((p["name"] for p in nodes if i in p.get("children",[])),None)} for i,n in enumerate(nodes)}
for stem in ("GasCloud","ShadowCloud"):
    tree=ET.parse(HERE/(stem+".rbxmx"))
    refs={o.get("referent") for o in tree.findall(".//Item")}
    assert all(r.text in refs for r in tree.findall(".//Ref"))
    for part in tree.findall(".//Item[@class='Part']"):
        for k in ("CanCollide","CanTouch","CanQuery","Anchored","Massless"):
            assert part.find("./Properties/bool[@name='"+k+"']").text==str(k=="Massless").lower()
    if stem=="ShadowCloud":
        assert len(tree.findall(".//Item[@class='Motor6D']"))==10
        assert len(tree.findall(".//Item[@class='Attachment']"))==5
        seqs=tree.findall(".//Item[@class='KeyframeSequence']")
        assert {s.find("./Properties/string[@name='Name']").text for s in seqs}==set(CLIPS)
maps={k:list(Image.open(HERE/(k+".png")).size) for k in ("ColorMap","NormalMap","RoughnessMap","MetalnessMap")}
manifest={"version":"1.0","issue":"BT-107","visualName":"Shadow Cloud","sourceGfx":"0xBD",
    "sourceType":"0x62","runtimeKind":"Swellcheeks","visualSourceFrames":["0xBC","0xBD"],
    "placement":"Level 12 authored gas placement, sourceVariant=3, platform 15",
    "alternateSourceTypes":["0x5D","0x5E"],"alternateWindPlacementVerified":False,
    "gasEffect":{"sourceType":"0x53","sourceGfxRevolution":"0xC5","runtimeKind":"GasCloud","ownsLifetime":"campaign projectile"},
    "coordinates":{"units":"1 unit = 1 stud; import factor 1","up":"+Y","front":"-Z","pivot":"center of volume","targetDimensions":[5.2,4.2,3.6]},
    "rig":rig,"rigMethod":"GLB animates rigid node transforms. RBXMX uses 10 Motor6D joints and rigid welded lobe folds.",
    "material":"Single opaque green skin with vertex albedo and UV detail. Blind throat uses the same material.",
    "textureSizes":maps,"geometry":records,"clips":{k:{"durationSeconds":v,"markersNormalized":MARKERS.get(k,{})} for k,v in CLIPS.items()},
    "playback":"Begin at BD. GasTell and TransitionBC compress towards BC. TransitionBD relaxes to BD. GasRelease and GasRecover follow server phases. Wind clips are presentation-only. Any live clip can be interrupted by Hit or Defeat. Return to HoverIdle after recovery. Defeat dispersal is rendered by runtime transparency.",
    "roblox":"ShadowCloud.rbxmx and the Lua adapter use an offline sphere-and-joint rig with nested dark gullet relief. Detailed modeled throat and PBR assets are in the GLBs and Blender source.",
    "checks":"Export budgets, data bounds, socket names, node clips, RBXMX references and physical flags verified offline. LOD0 imported into Blender 5.3.",
    "assetPublication":"Local deliverables; no published MeshId, TextureId or AnimationId assigned."}
(HERE/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("Verified",[(k,v["triangles"]) for k,v in records.items()],"15 clips, 10 Motor6D joints, 5 sockets")
