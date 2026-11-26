"""Generate a finite authoring state reel and same-scale vehicle comparison."""
from copy import deepcopy
from math import cos, pi, radians, sin
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
from PIL import Image, ImageDraw
import build

BACKGROUND=(25,32,39)


def sprite(model, angle, tmp):
    build.renderer.render(model,tmp,(420,265),(angle,))
    image=Image.open(tmp).convert('RGBA').crop((0,24,420,235))
    data=np.asarray(image).copy()
    data[:,:,3]=np.where((data[:,:,:3]!=BACKGROUND).any(axis=-1),255,0)
    return Image.fromarray(data).crop(Image.fromarray(data).getbbox())


def preview(kind, design, model, temp):
    path=build.HERE.parent/kind
    base=sprite(model,65,temp)
    frames=[]
    for i,state in enumerate(design.STATES):
        for step in range(5):
            t=step/4
            frame=Image.new('RGB',(580,300),BACKGROUND)
            draw=ImageDraw.Draw(frame)
            for x in range(0,580,44):
                draw.line((x,252,x+70,204),fill=(38,51,61),width=1)
            draw.line((0,212,580,212),fill=(50,67,79))
            draw.text((18,15),f'{kind}  /  {state}',fill=(226,237,241))
            draw.text((18,275),'Authoring preview   |   course controls movement and impact',fill=(163,183,193))
            # Preview-only motion in the viewing window. No gameplay trajectory is exported.
            x,y=290,149
            tilt=0
            scale=.74
            if state=='Enter': x=420-80*t
            if state=='CrossingForward': x=340-100*t; tilt=8
            if state=='TurnAtBound': x=240; tilt=8-16*t
            if state=='CrossingReturn': x=240+100*t; tilt=-8
            if state=='PassExit': x=340+280*t
            if state=='SpawnIgnite': scale=.24+.50*t
            if state=='Flight_A': x=420-108*t; tilt=3*t
            if state=='Flight_B': x=312-108*t; tilt=3-6*t
            if state=='ScrollStopped': x=204
            if state=='WarningPreview': scale=.60
            if state=='PassExpire': scale=.74*(1-t)
            if state=='Impact':
                scale=.74*(1-t)
                for ray in range(8):
                    a=ray*pi/4
                    radius=15+38*t
                    px,py=x+radius*cos(a),y+radius*sin(a)
                    dot=max(1,4*(1-t))
                    draw.ellipse((px-dot,py-dot,px+dot,py+dot),fill=(255,209,65))
            if state not in ('Cleanup','Removed') and scale>.02:
                obj=base.resize((int(base.width*scale),int(base.height*scale)),Image.Resampling.LANCZOS)
                obj=obj.rotate(tilt,Image.Resampling.BICUBIC,expand=True)
                frame.paste(obj,(int(x-obj.width/2),int(y-obj.height/2)),obj)
            frames.append(frame)
    frames[0].save(path/'states.gif',save_all=True,append_images=frames[1:],duration=120,optimize=True)


def context(kind,model,target):
    vehicles=build.load('vehicles',build.ROOT/'assets/vehicles/canonical-course/build_course_vehicles.py')
    vehicle=vehicles.scooter() if kind=='RatPod' else vehicles.jet()
    for k,mesh in vehicle.parts.items():
        mesh=deepcopy(mesh)
        mesh.vertices=[(x-2.9,y-.6,z-3.5) for x,y,z in mesh.vertices]
        model.parts['vehicle'+k]=mesh
    if kind=='Meteorite':
        hoop=model.part('NominalCoreProxy',parent=None)
        for plane in (0,1):
            pts=[]
            for j in range(41):
                a=j*2*pi/40
                x,y,z=1.27*cos(a),1.27*sin(a),0
                pts.append((x if not plane else 0,y,z if not plane else x,.014,.014))
            build.geo.tube(hoop,pts,(35,218,236),6,1)
    model.kind='Rat Pod and Speeder' if kind=='RatPod' else 'Meteorite, nominal core proxy and Jet'
    build.renderer.render(model,target/'vehicle-scale.png',(830,430),(56,))


if __name__=='__main__':
    with TemporaryDirectory() as directory:
        temp=Path(directory)/'render.png'
        for kind in build.KINDS:
            path=build.HERE.parent/kind
            design=build.load(kind,path/'design.py')
            rows=[]
            design.shapes(lambda *row: rows.append(row))
            model=build.geometry(kind,rows,0)
            preview(kind,design,model,temp)
            context(kind,model,path)
