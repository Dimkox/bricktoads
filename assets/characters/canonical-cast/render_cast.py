"""Software orthographic renderer of exported authoring surfaces.

Depth is evaluated per pixel and vertex normals are interpolated. This avoids
the triangle-centroid painter's false wire patterns on intersecting joint caps.
No screenshots from Studio, AI image output or claimed native render is used.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

def render(model,path,size=(720,480),azimuths=(0,40,90)):
    width,height=size;panel=width//len(azimuths)
    pixels=np.full((height,width,3),(25,32,39),dtype=np.uint8)
    depth=np.full((height,width),-np.inf)
    light=np.array((-.55,.85,-.75));light/=np.linalg.norm(light)
    allvs=np.array([v for m in model.parts.values() for v in m.vertices]);panels=[]
    for k,angle in enumerate(azimuths):
        az=math.radians(angle);view=np.array((math.sin(az),.10,-math.cos(az)));view/=np.linalg.norm(view)
        right=np.array((math.cos(az),0,math.sin(az)));up=np.cross(right,view);up/=np.linalg.norm(up)
        projected=np.stack((allvs@right,allvs@up),axis=1);minimum=projected.min(axis=0);maximum=projected.max(axis=0);middle=(minimum+maximum)/2
        scale=min((panel-24)/(maximum[0]-minimum[0]),(height-60)/(maximum[1]-minimum[1]));cx=k*panel+panel/2;cy=height/2+8
        for mesh in model.parts.values():
            vertices=np.array(mesh.vertices);normals=np.array(mesh.normals());raw=np.array(mesh.colors)/255
            coords=np.stack((cx+(vertices@right-middle[0])*scale,cy-(vertices@up-middle[1])*scale,vertices@view),axis=1)
            luminance=.36+.64*np.maximum(0,normals@light)
            colors=255*np.clip(raw**2.2*luminance[:,None],0,1)**(1/2.2)
            for face in mesh.faces:
                ids=np.array(face);p,q,r=coords[ids]
                geometric=np.cross(vertices[face[1]]-vertices[face[0]],vertices[face[2]]-vertices[face[0]])
                if geometric@view<=0:continue
                area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-8:continue
                x0=max(k*panel,int(np.floor(min(p[0],q[0],r[0]))));x1=min((k+1)*panel-1,int(np.ceil(max(p[0],q[0],r[0]))))
                y0=max(22,int(np.floor(min(p[1],q[1],r[1]))));y1=min(height-26,int(np.ceil(max(p[1],q[1],r[1]))))
                if x1<x0 or y1<y0:continue
                ys,xs=np.mgrid[y0:y1+1,x0:x1+1];xs=xs+.5;ys=ys+.5
                a=((q[0]-xs)*(r[1]-ys)-(q[1]-ys)*(r[0]-xs))/area
                b=((r[0]-xs)*(p[1]-ys)-(r[1]-ys)*(p[0]-xs))/area;c=1-a-b
                z=a*p[2]+b*q[2]+c*r[2];old=depth[y0:y1+1,x0:x1+1]
                mask=(a>=-1e-7)&(b>=-1e-7)&(c>=-1e-7)&(z>old)
                if not mask.any():continue
                old[mask]=z[mask];paint=pixels[y0:y1+1,x0:x1+1];cs=colors[ids]
                shade=np.clip(a[...,None]*cs[0]+b[...,None]*cs[1]+c[...,None]*cs[2],0,255).astype(np.uint8)
                paint[mask]=shade[mask]
        panels.append((k*panel+10,height-19,f'{model.kind} {angle}deg'))
    image=Image.fromarray(pixels);draw=ImageDraw.Draw(image)
    for x,y,text in panels:draw.text((x,y),text,fill=(227,235,240))
    draw.text((10,6),'Authored source-informed3D | software preview | depth/joints inferred',fill=(150,166,175))
    image.save(path)

def contact_sheet(root,models,filename='cast-model-contact-sheet.png'):
    width=1600;cellw=320;cellh=254;rows=math.ceil(len(models)/5)
    result=Image.new('RGB',(width,rows*cellh),(25,32,39));draw=ImageDraw.Draw(result)
    for i,kind in enumerate(models):
        path=root/kind/'turntable.png';tile=Image.open(path).resize((320,213),Image.Resampling.LANCZOS);x=(i%5)*cellw;y=(i//5)*cellh
        result.paste(tile,(x,y));draw.text((x+8,y+224),kind,fill='white')
    result.save(root/filename)
