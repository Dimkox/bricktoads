"""Deterministic articulated cast surfaces; no ROM, Studio or gameplay changes.

The source supplies 2D contours, colours and state identities. Depth, rear views,
rest joints and all 3D surfaces are authored adaptations, explicitly recorded.
Each surface component is a closed manifold. Shared palette UVs work with the
Roblox importer which discards COLOR_0 when SurfaceAppearance is present.
"""
from __future__ import annotations
from collections import Counter
from pathlib import Path
import argparse, hashlib, importlib.util, json, math, struct, zlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
PIN='f1a43b69577246850d136473700a333b3cdfe93f'
METRES=.28
BLACK=(18,19,20); WHITE=(255,255,255); CREAM=(255,221,171)
RED=(180,0,0); PINK=(255,100,97); DARKRED=(91,0,0)
YELLOW=(205,202,62); OLIVE=(117,118,0); GOLD=(229,170,37)
GREY=(145,151,157); STEEL=(65,79,95); BLUE=(71,115,214)
PURPLE=(130,65,168); DARKPURPLE=(54,25,76); GREEN=(83,147,55)
BROWN=(155,83,0); TAN=(228,196,144); ORANGE=(250,160,66)

def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,k):return tuple(x*k for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def length(a):return math.sqrt(dot(a,a))
def unit(a):return mul(a,1/max(1e-14,length(a)))
def bounds(vs):return [[min(v[i] for v in vs) for i in range(3)],[max(v[i] for v in vs) for i in range(3)]]

class Mesh:
    def __init__(self,name):self.name=name;self.vertices=[];self.faces=[];self.colors=[];self.components=[]
    def append(self,vs,fs,color):
        vs=list(vs);fs=list(fs)
        volume=sum(dot(vs[a],cross(vs[b],vs[c])) for a,b,c in fs)/6
        if volume<0:fs=[(a,c,b) for a,b,c in fs]
        start=len(self.vertices);self.vertices.extend(vs);self.faces.extend(tuple(i+start for i in f) for f in fs)
        self.colors.extend([tuple(color)]*len(vs));self.components.append((start,len(vs),len(fs)))
    def normals(self):
        ns=[(0,0,0)]*len(self.vertices)
        for a,b,c in self.faces:
            n=cross(sub(self.vertices[b],self.vertices[a]),sub(self.vertices[c],self.vertices[a]))
            for i in (a,b,c):ns[i]=add(ns[i],n)
        return [unit(n) for n in ns]

def ellipsoid(m,c,r,color,radial=20,rings=12,power=1):
    vs=[(c[0],c[1]-r[1],c[2])]
    for i in range(1,rings):
        t=-math.pi/2+math.pi*i/rings
        for j in range(radial):
            a=math.tau*j/radial
            sp=lambda x:math.copysign(abs(x)**power,x)
            vs.append((c[0]+r[0]*math.cos(t)*sp(math.cos(a)),c[1]+r[1]*math.sin(t),c[2]+r[2]*math.cos(t)*sp(math.sin(a))))
    vs.append((c[0],c[1]+r[1],c[2]));top=len(vs)-1;fs=[]
    for j in range(radial):fs.append((0,1+j,1+(j+1)%radial))
    for i in range(rings-2):
        for j in range(radial):
            a=1+i*radial+j;b=1+i*radial+(j+1)%radial;c_=a+radial;d=b+radial
            fs.extend(((a,c_,b),(b,c_,d)))
    for j in range(radial):fs.append((top,1+(rings-2)*radial+(j+1)%radial,1+(rings-2)*radial+j))
    m.append(vs,fs,color)

def tube(m,controls,color,radial=16,steps=3,power=1):
    """Closed parallel-frame swept volume. Controls x,y,z,radius1,radius2."""
    rows=[]
    for a,b in zip(controls,controls[1:]):
        for i in range(steps):rows.append(tuple(x+(y-x)*i/steps for x,y in zip(a,b)))
    rows.append(controls[-1]);vs=[];fs=[];prior=None
    for i,row in enumerate(rows):
        axis=unit(sub(rows[min(i+1,len(rows)-1)][:3],rows[max(0,i-1)][:3]))
        ref=(0,0,1) if abs(axis[2])<.85 else (0,1,0)
        u=unit(cross(axis,ref))
        if prior is not None:
            projected=sub(prior,mul(axis,dot(prior,axis)))
            if length(projected)>.001:u=unit(projected)
        v=unit(cross(u,axis))
        prior=u
        for j in range(radial):
            a=math.tau*j/radial;sp=lambda x:math.copysign(abs(x)**power,x)
            vs.append(add(row[:3],add(mul(u,sp(math.cos(a))*max(.006,row[3])),mul(v,sp(math.sin(a))*max(.006,row[4])))))
        if i:
            for j in range(radial):
                a=(i-1)*radial+j;b=(i-1)*radial+(j+1)%radial;c=i*radial+j;d=i*radial+(j+1)%radial
                fs.extend(((a,c,b),(b,c,d)))
    a=len(vs);b=a+1;vs.extend((rows[0][:3],rows[-1][:3]));k=(len(rows)-1)*radial
    for j in range(radial):fs.extend(((a,j,(j+1)%radial),(b,k+(j+1)%radial,k+j)))
    m.append(vs,fs,color)

def plate(m,poly,z,thickness,color):
    """Closed convex rounded-depth plate; polygon in XY."""
    cx=sum(x for x,y in poly)/len(poly);cy=sum(y for x,y in poly)/len(poly);n=len(poly);vs=[]
    for dz,s in ((-thickness/2,.88),(-thickness*.28,1),(thickness*.28,1),(thickness/2,.88)):
        vs.extend((cx+(x-cx)*s,cy+(y-cy)*s,z+dz) for x,y in poly)
    fs=[]
    for r in range(3):
        for i in range(n):j=(i+1)%n;a=r*n+i;b=r*n+j;c=(r+1)*n+i;d=(r+1)*n+j;fs.extend(((a,b,c),(b,d,c)))
    vs.extend(((cx,cy,z-thickness/2),(cx,cy,z+thickness/2)));a=4*n;b=a+1
    for i in range(n):j=(i+1)%n;fs.extend(((a,j,i),(b,3*n+i,3*n+j)))
    m.append(vs,fs,color)

def eye(m,x,y,z,s=.15,color=WHITE,pupil=BLACK):
    ellipsoid(m,(x,y,z),(s,s*1.12,s*.48),color,16,8)
    ellipsoid(m,(x,y,z-s*.43),(s*.40,s*.67,s*.16),pupil,12,8)

def seam(m,points,width=.035,color=BLACK):tube(m,[(*p,width,width) for p in points],color,10,2)

class Model:
    def __init__(self,kind):self.kind=kind;self.parts={};self.pivots={};self.parents={};self.facts=[];self.reference=[]
    def part(self,name,pivot=(0,0,0),parent='Body'):
        assert name not in self.parts,name
        self.parts[name]=Mesh(name);self.pivots[name]=tuple(pivot);self.parents[name]=None if name=='Body' else parent
        return self.parts[name]
    def resize(self,height=None,scale=None):
        if scale is None:
            b=bounds([v for m in self.parts.values() for v in m.vertices]);scale=height/(b[1][1]-b[0][1])
        for m in self.parts.values():m.vertices=[mul(v,scale) for v in m.vertices]
        self.pivots={n:mul(v,scale) for n,v in self.pivots.items()}
        return self

def limb(model,name,a,b,c,r,color,foot=False):
    m=model.part(name,a);tube(m,[(*a,r,r),(*b,r*1.20,r*1.13),(*c,r*.80,r*.82)],color)
    ellipsoid(m,a,(r*1.05,r*1.05,r*1.05),color,16,8)
    if foot:ellipsoid(m,(c[0],c[1]-.02,c[2]-.26),(r*1.30,r*.57,r*1.90),color,18,8,power=.8)
    else:
        ellipsoid(m,(c[0],c[1]-.14,c[2]),(r*1.2,r*1.12,r),color,18,10)
        for j in (-1,0,1):seam(m,[(c[0]+j*r*.52,c[1]-.12,c[2]-r*.90),(c[0]+j*r*.52,c[1]-.48*r,c[2]-r*.92)],r*.045)
    return m

def pig():
    o=Model('Pig');body=o.part('Body')
    tube(body,[(0,-1.1,.1,.45,.33),(0,-.7,.10,.60,.40),(0,-.15,.10,.79,.45),(0,.50,.07,1.10,.56),(0,.92,.09,1.12,.49),(0,1.15,.1,.71,.36)],RED,28,3,power=.86)
    for s in (-1,1):
        ellipsoid(body,(s*.47,.61,-.36),(.54,.42,.24),RED,22,12)
        tube(body,[(s*.20,.79,-.53,.12,.045),(s*.48,.85,-.53,.24,.06),(s*.81,.66,-.43,.14,.04)],PINK,16,3)
    tube(body,[(0,-.68,-.26,.24,.13),(0,-.10,-.39,.30,.17),(0,.30,-.41,.32,.16)],RED,20,3,power=.75)
    seam(body,[(-.55,.24,-.46),(0,.14,-.54),(.55,.24,-.46)],.024,DARKRED)
    seam(body,[(0,.33,-.56),(0,.78,-.62)],.025,DARKRED)
    head=o.part('Head',(0,1.12,.05));ellipsoid(head,(0,1.58,-.03),(.62,.60,.48),RED,24,12,power=.75)
    # Source Pig is a helmeted muscular brute. Sculpt the flat face under its
    # angular crown; gameplay labels do not justify inventing a generic pig.
    ellipsoid(head,(0,1.39,-.44),(.51,.25,.21),PINK,24,10,power=.58)
    ellipsoid(head,(0,1.92,.02),(.68,.43,.53),RED,24,12,power=.62)
    tube(head,[(-.60,1.76,-.34,.11,.10),(0,1.67,-.56,.12,.11),(.60,1.76,-.34,.11,.10)],DARKRED,14,3)
    for s in (-1,1):
        eye(head,s*.27,1.59,-.59,.075,PINK)
        tube(head,[(s*.08,1.69,-.57,.09,.065),(s*.38,1.78,-.48,.10,.075)],RED,14,3)
        plate(head,[(s*.40,1.99),(s*.73,2.43),(s*.79,1.91)],.04,.30,RED)
        arm=limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.96,.78,.05),(s*1.37,.12,.02),(s*1.24,-.42,-.45),.44,RED)
        ellipsoid(arm,(s*1.27,-.47,-.49),(.57,.50,.53),RED,24,14,power=.70)
        tube(arm,[(s*.92,.65,-.21,.24,.13),(s*1.24,.27,-.25,.27,.13),(s*1.16,-.14,-.41,.20,.11)],PINK,16,3)
        leg=limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.54,-.87,.08),(s*.70,-1.43,.05),(s*.72,-1.95,-.10),.30,RED,True)
        start,count,_=leg.components[-1];leg.colors[start:start+count]=[PINK]*count
    jaw=o.part('Jaw',(0,1.22,-.16),'Head');ellipsoid(jaw,(0,1.14,-.48),(.46,.15,.24),RED,20,8,power=.7)
    seam(jaw,[(-.39,1.25,-.66),(0,1.22,-.75),(.39,1.25,-.66)],.036)
    o.facts=['Pig decoded graphics02-06 show a red helmeted muscular brute, enormous fists, hunched broad shoulders and short bent legs; attack boxes34x31 and40x28 pixels.','Helmet crown and face are modelled from decoded contours; no animal tail is evidenced.']
    o.reference=['research/canonical-visuals/frames/object-05.png','research/canonical-visuals/frames/object-06.png']
    return o.resize(5.5)

def dragon():
    o=Model('Dragon');m=o.part('Body');tube(m,[(0,-.90,.12,.45,.40),(0,-.5,.1,.71,.54),(0,.10,.13,.74,.54),(0,.77,.04,.43,.34),(0,1.05,-.05,.30,.27)],RED,22,3)
    ellipsoid(m,(0,-.02,-.35),(.48,.66,.20),PINK,20,12)
    head=o.part('Head',(0,.95,-.03));ellipsoid(head,(0,1.28,-.17),(.49,.48,.40),RED,22,12)
    ellipsoid(head,(0,1.13,-.64),(.57,.25,.49),PINK,22,10,power=.8)
    for s in (-1,1):
        eye(head,s*.26,1.52,-.50,.14,PINK)
        ellipsoid(head,(s*.23,1.23,-1.02),(.065,.05,.02),DARKRED,12,8)
        tube(head,[(s*.33,1.60,.03,.16,.15),(s*.40,2.01,.14,.11,.10),(s*.51,2.21,.19,.017,.017)],PINK,14,3)
        wing=o.part(('Left' if s<0 else 'Right')+'Wing',(s*.46,.58,.33))
        # Web is a closed scalloped loft with three visible finger spars.
        for j,(endx,endy) in enumerate(((1.68,1.85),(1.98,.96),(1.70,.13))):
            tube(wing,[(s*.46,.58,.33,.10,.10),(s*1.04,.91,.38,.085,.065),(s*endx,endy,.31,.025,.025)],RED,12,3)
        for poly in [[(s*.56,.63),(s*1.68,1.85),(s*1.49,.98)],[(s*.56,.63),(s*1.98,.96),(s*1.43,.35)],[(s*.56,.63),(s*1.70,.13),(s*.93,.12)]]:plate(wing,poly,.34,.095,PINK)
        limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.43,-.65,.12),(s*.58,-1.00,-.08),(s*.58,-1.34,-.25),.23,RED,True)
        arm=limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.48,.48,-.01),(s*.70,.15,-.25),(s*.57,-.10,-.55),.14,PINK)
        for j in (-1,0,1):tube(arm,[(s*.57+j*.09,-.10,-.55,.045,.045),(s*.57+j*.11,-.28,-.70,.02,.02)],PINK,10,2)
    jaw=o.part('Jaw',(0,1.00,-.20),'Head');ellipsoid(jaw,(0,.90,-.68),(.44,.12,.40),RED,18,8)
    seam(jaw,[(-.37,1.015,-.91),(0,.99,-1.08),(.37,1.015,-.91)],.026)
    tail=o.part('Tail',(0,-.55,.45));tube(tail,[(0,-.55,.45,.25,.23),(0,-.83,1.08,.22,.19),(0,-.68,1.65,.14,.11),(0,-.25,1.89,.025,.025)],RED,18,4)
    for y,z in ((-.73,1.10),(-.60,1.56)):plate(tail,[(-.14,y),(0,y+.34),(.14,y)],z,.09,PINK)
    o.facts=['Dragon graphics09/0A/0B/0C show pointed horns, wing membranes, long muzzle, tail and small clawed feet; frame boxes26x32,29x23,26x31,24x20 pixels.']
    o.reference=['research/canonical-visuals/frames/object-09.png','research/canonical-visuals/frames/object-0b.png']
    return o.resize(5.7)

def walker():
    # Preserve the independently verified source profile, holes and straight rods.
    path=HERE.parent/'tall-walker/build_tall_walker.py';spec=importlib.util.spec_from_file_location('cast_walker_source',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    source,pivots,_,_,_=module.geometry();o=Model('Walker')
    rename={'UpperBody':'Body','LeftStrut':'LeftLeg','RightStrut':'RightLeg','LeftFoot':'LeftFoot','RightFoot':'RightFoot'}
    for name,m in source.items():
        dest=rename[name];parent=rename[name.replace('Foot','Strut')] if name.endswith('Foot') else 'Body'
        out=o.part(dest,pivots[name],parent);out.vertices=list(m.vertices);out.faces=list(m.faces)
        def encode(v):return round(255*(v*12.92 if v<=.0031308 else 1.055*v**(1/2.4)-.055))
        out.colors=[tuple(encode(v) for v in c[:3]) for c in m.colors]
    o.facts=['Verified type11 upperBody graphics19 is13x27 pixels; full neutral14x89 vs hero24x33. Each leg uses seven straight shaft sprites plus terminal D3 foot; no knees.','Palette0F182820; exact previously verified shallow source profile with visible holes reused.']
    o.reference=['research/canonical-visuals/tall-walker-source-verification.json','research/canonical-visuals/tall-walker-procedural-leg-reference.png']
    return o

def bird(kind='Raven'):
    o=Model(kind);m=o.part('Body');ellipsoid(m,(0,-.12,.10),(.48,.69,.62),BLACK,22,14)
    head=o.part('Head',(0,.44,-.24));ellipsoid(head,(0,.66,-.40),(.40,.45,.43),BLACK,22,12)
    large=kind=='LargeRaven';beakLength=1.30 if large else .55
    tube(head,[(0,.54,-.62,.28,.21),(0,.56,-.91,.27,.19),(0,.46,-.85-beakLength,.025,.025)],ORANGE,20,3)
    jaw=o.part('Jaw',(0,.39,-.64),'Head');tube(jaw,[(0,.38,-.66,.22,.10),(0,.28,-.82-beakLength*.77,.16,.07),(0,.33,-.85-beakLength,.014,.014)],ORANGE,16,2)
    for s in (-1,1):
        eye(head,s*.30,.76,-.65,.065,CREAM)
        wing=o.part(('Left' if s<0 else 'Right')+'Wing',(s*.34,.27,.16))
        ellipsoid(wing,(s*.75,.31,.15),(.59,.24,.42),BLACK,20,10)
        for j in range(5):
            start=(s*(.57+j*.12),.34-j*.05,.28);end=(s*(1.08+j*.18),.55+j*.20,.15+j*.09)
            tube(wing,[(*start,.17,.14),(*end,.09,.07),(end[0]+s*.10,end[1]+.12,end[2],.015,.015)],BLACK,14,3)
            seam(wing,[(start[0],start[1],start[2]-.14),(end[0],end[1],end[2]-.08)],.023,BROWN)
        leg=o.part(('Left' if s<0 else 'Right')+'Leg',(s*.22,-.55,.03));tube(leg,[(s*.22,-.55,.03,.07,.07),(s*.24,-.92,-.11,.07,.07)],BROWN,12,2)
        for j in (-1,0,1):tube(leg,[(s*.24,-.91,-.11,.065,.05),(s*.24+j*.13,-.96,-.36,.025,.025)],ORANGE,10,2)
    tail=o.part('Tail',(0,-.40,.51));
    for j in (-1,0,1):tube(tail,[(j*.14,-.40,.50,.17,.12),(j*.22,-.56,1.15,.12,.08),(j*.23,-.62,1.33,.025,.025)],BLACK,14,2)
    o.facts=['Source Raven1C-23 and LargeRaven26-29 have dark bodies, long fingered wings, orange hooked beaks. LargeRaven is distinguished by its dramatically extended bill.'];o.reference=[f'research/canonical-visuals/cast-contact-sheets/{kind.lower()}.png']
    return o.resize(3.7 if not large else 4.3)

def invader():
    o=Model('Invader');m=o.part('Body');c=(73,174,25);dark=(0,91,0)
    plate(m,[(-.82,-.46),(-.82,.28),(-.48,.62),(.48,.62),(.82,.28),(.82,-.46)],0,.48,c)
    for s in (-1,1):
        plate(m,[(s*.27,.48),(s*.42,.97),(s*.62,.90),(s*.48,.45)],0,.31,dark)
        eye(m,s*.35,.13,-.27,.12,dark,dark)
        a=o.part(('Left' if s<0 else 'Right')+'Arm',(s*.73,.10,0));tube(a,[(s*.75,.10,0,.10,.12),(s*.95,-.16,0,.10,.12),(s*.95,-.58,0,.10,.12)],c,12,2,power=.55)
        l=o.part(('Left' if s<0 else 'Right')+'Leg',(s*.43,-.40,0));tube(l,[(s*.43,-.40,0,.12,.14),(s*.43,-.65,0,.12,.14),(s*.25,-.65,0,.10,.13)],dark,12,2,power=.55)
    o.facts=['Graphics24/25/39/3A are a flat green arcade-invader silhouette with two raised antennae, square eye holes, side arms and short feet; shallow3D extrusion is authored.'];o.reference=['research/canonical-visuals/cast-contact-sheets/invader.png'];return o.resize(3.3)

def ratface(o,head,p=(0,1.12,-.12),color=RED,highlight=PINK,scale=1):
    x,y,z=p;r=scale;ellipsoid(head,(x,y,z),(.48*r,.51*r,.42*r),color,22,12)
    tube(head,[(x,y-.06*r,z-.23*r,.34*r,.25*r),(x,y-.13*r,z-.72*r,.28*r,.20*r),(x,y-.13*r,z-1.00*r,.12*r,.10*r)],highlight,20,3,power=.83)
    ellipsoid(head,(x,y-.12*r,z-1.025*r),(.13*r,.10*r,.08*r),BLACK,14,8)
    for s in (-1,1):
        ellipsoid(head,(x+s*.40*r,y+.30*r,z+.02*r),(.24*r,.29*r,.10*r),color,18,10)
        ellipsoid(head,(x+s*.40*r,y+.30*r,z-.07*r),(.13*r,.19*r,.025*r),highlight,16,8)
        eye(head,x+s*.25*r,y+.13*r,z-.39*r,.065*r,highlight)
        tube(head,[(x+s*.10*r,y+.23*r,z-.42*r,.065*r,.045*r),(x+s*.36*r,y+.30*r,z-.31*r,.075*r,.055*r)],color,12,3)

def rocket_rat():
    o=Model('RocketRat');m=o.part('Body');ellipsoid(m,(0,.42,.15),(.52,.57,.48),ORANGE,22,12);head=o.part('Head',(0,.79,-.04));ratface(o,head,(0,1.03,-.03),ORANGE,TAN,.64)
    for s in (-1,1):
        arm=limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.35,.62,-.10),(s*.48,.32,-.37),(s*.35,.13,-.63),.14,ORANGE)
        limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.35,.17,.15),(s*.55,-.06,.08),(s*.49,-.12,-.42),.18,ORANGE,True)
    rocket=o.part('Weapon',(0,-.27,.10));tube(rocket,[(0,-.39,1.12,.42,.32),(0,-.39,.70,.64,.46),(0,-.39,-.36,.62,.45),(0,-.39,-1.12,.26,.24),(0,-.39,-1.44,.025,.025)],RED,24,3,power=.8)
    for s in (-1,1):plate(rocket,[(s*.35,-.40),(s*.82,-.12),(s*.73,-.74),(s*.37,-.63)],.70,.22,RED)
    seam(rocket,[(-.42,-.19,-.96),(0,-.09,-1.12),(.42,-.19,-.96)],.038,PINK)
    o.facts=['Graphics55 shows an orange long-nosed rider hunched over a rounded red rocket/vehicle; the rider and mount are distinct silhouettes.'];o.reference=['research/canonical-visuals/cast-contact-sheets/rocketrat.png'];return o.resize(3.4)

def snowman():
    o=Model('Snowman');m=o.part('Body');ellipsoid(m,(0,-.22,.08),(.80,1.02,.63),PINK,24,14)
    ellipsoid(m,(0,.55,.06),(.55,.52,.43),RED,22,12);head=o.part('Head',(0,.88,.02));ellipsoid(head,(0,1.10,-.06),(.50,.47,.41),PINK,22,12)
    ellipsoid(head,(0,1.54,.01),(.70,.10,.54),BROWN,26,8);tube(head,[(0,1.55,.04,.44,.35),(0,1.90,.04,.37,.31)],BROWN,22,2,power=.55)
    tube(head,[(0,1.75,-.28,.38,.06),(0,1.87,-.27,.33,.06)],ORANGE,18,2)
    tube(head,[(0,1.11,-.35,.17,.14),(0,1.05,-.87,.025,.025)],RED,16,3)
    for s in (-1,1):
        eye(head,s*.20,1.24,-.40,.075,BLACK,BLACK)
        limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.52,.65,.02),(s*.81,.15,-.03),(s*.90,-.40,-.21),.21,PINK)
        limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.45,-.78,.04),(s*.50,-1.23,-.03),(s*.50,-1.46,-.16),.25,PINK,True)
    for y in (.45,.04,-.35):ellipsoid(m,(0,y,-.57),(.075,.075,.03),BLACK,12,8)
    o.facts=['Graphics64/6B/6C/6E show a rounded humanoid snowman, broad brown/orange brimmed hat, long pointed nose, dangling arms and broad feet. Red/pink is the decoded initial palette, not a traced final dynamic palette.'];o.reference=['research/canonical-visuals/cast-contact-sheets/snowman.png'];return o.resize(5.5)

def sentry():
    o=Model('SentryDrone');m=o.part('Body');ellipsoid(m,(0,.15,0),(.77,.68,.59),RED,24,14,power=.84)
    head=o.part('Head',(0,.21,-.41));ellipsoid(head,(0,.17,-.48),(.49,.31,.18),DARKRED,22,10,power=.68)
    eye(head,0,.17,-.65,.19,PINK)
    tube(m,[(0,.72,.01,.12,.12),(0,.98,.01,.075,.075)],PINK,12,2)
    for s in (-1,1):ellipsoid(m,(s*.76,.15,0),(.13,.10,.13),RED,14,8)
    engine=o.part('Weapon',(0,-.37,0));tube(engine,[(0,-.38,0,.34,.30),(0,-.70,0,.43,.35),(0,-.82,0,.35,.28)],RED,22,2,power=.8)
    seam(engine,[(-.30,-.65,-.29),(0,-.62,-.36),(.30,-.65,-.29)],.040,PINK)
    o.facts=['Graphics9D/9E show a red rounded hovering pod, short top peg, lateral nubs and lower cylindrical thruster. No large bird wings are present.'];o.reference=['research/canonical-visuals/cast-contact-sheets/sentrydrone.png'];return o.resize(3.2)

def gas_turret():
    o=Model('GasTurret');m=o.part('Body');ellipsoid(m,(0,-.40,.16),(.50,.16,.50),DARKRED,22,8)
    tube(m,[(0,-.35,.1,.33,.34),(0,.18,.08,.48,.40),(0,.68,.07,.06,.08)],RED,20,3,power=.78)
    weapon=o.part('Weapon',(0,.06,-.24));tube(weapon,[(0,.07,-.25,.18,.18),(0,.07,-.65,.13,.13),(0,.07,-.79,.09,.09)],RED,20,2)
    ellipsoid(weapon,(0,.07,-.80),(.07,.07,.012),BLACK,14,8)
    o.facts=['GraphicsA5 turret is a short red triangular/conical fixture with a small horizontal nozzle. A6-AA are emitted gas bursts, not anatomy.'];o.reference=['research/canonical-visuals/cast-contact-sheets/gasturret.png'];return o.resize(2.8)

def blaster(kind='RetroBlaster'):
    o=Model(kind);m=o.part('Body');ellipsoid(m,(0,.13,.10),(.69,.99,.63),RED,24,16,power=.71)
    head=o.part('Head',(0,.50,-.24));ellipsoid(head,(0,.57,-.42),(.48,.39,.22),DARKRED,22,10,power=.65)
    if kind=='Robot':
        eye(head,0,.61,-.61,.15,PINK)
    else:
        for s in (-1,1):ellipsoid(head,(s*.30,.41,-.57),(.105,.25,.025),BLACK,16,10,power=.5)
    weapon=o.part('Weapon',(0,-.02,-.43));tube(weapon,[(0,-.03,-.38,.37,.31),(0,-.03,-.92,.34,.29),(0,-.03,-1.13,.28,.24)],RED,24,3,power=.72)
    ellipsoid(weapon,(0,-.03,-1.14),(.19,.17,.024),BLACK,20,10);ellipsoid(weapon,(0,-.03,-1.17),(.08,.08,.012),PINK,16,8)
    jaw=o.part('Jaw',(0,-.50,-.15));plate(jaw,[(-.44,-.45),(.44,-.45),(.28,-1.05),(0,-1.22),(-.28,-1.05)],-.12,.34,PINK)
    if kind=='RetroBlaster':
        tail=o.part('Tail',(0,-.25,.57));plate(tail,[(-.08,-.18),(.08,-.18),(.29,-.75),(0,-.62),(-.29,-.75)],.85,.25,RED)
    else:
        for s in (-1,1):ellipsoid(m,(s*.63,.22,.03),(.19,.32,.21),RED,18,10)
    for j in range(4):seam(m,[(-.47+j*.15,.76,-.31),(-.38+j*.15,.93,-.14)],.025,DARKRED)
    o.facts=[f'{kind} decoded graphics show a domed red casing with recessed face, forward circular muzzle and tapered lower assembly; the meshes follow that source machine silhouette.'];o.reference=[f'research/canonical-visuals/cast-contact-sheets/{kind.lower()}.png'];return o.resize(4.0)

def toadtrap():
    o=Model('SaturnToadtrap');m=o.part('Body');ellipsoid(m,(0,0,.14),(.81,.59,.57),YELLOW,24,14,power=.76)
    head=o.part('Head',(0,.22,-.12));ellipsoid(head,(0,.30,-.35),(.78,.25,.50),YELLOW,24,10,power=.72)
    jaw=o.part('Jaw',(0,-.04,.02));ellipsoid(jaw,(0,-.25,-.35),(.78,.21,.50),YELLOW,24,10,power=.72)
    ellipsoid(jaw,(0,-.09,-.48),(.61,.04,.34),OLIVE,20,8)
    for s in (-1,1):
        for i in range(4):
            x=s*(.13+i*.15);z=-.66+abs(x)*.22
            tube(head,[(x,.18,z,.065,.055),(x,-.01,z,.015,.015)],WHITE,12,2)
            tube(jaw,[(x,-.15,z,.065,.055),(x,.045,z,.015,.015)],WHITE,12,2)
    o.facts=['Graphics5D/5E show a yellow/white compact clamshell trap with two toothed jaws and a dark recessed mouth; no humanoid limbs.'];o.reference=['research/canonical-visuals/cast-contact-sheets/saturntoadtrap.png'];return o.resize(2.8)

def slug():
    o=Model('Slug');m=o.part('Body');tube(m,[(0,-.25,.75,.20,.15),(0,-.15,.30,.64,.29),(0,.0,-.23,.64,.42),(0,.10,-.61,.38,.30)],YELLOW,24,3,power=.75)
    head=o.part('Head',(0,.10,-.45));ellipsoid(head,(0,.20,-.65),(.48,.37,.29),YELLOW,22,12)
    for s in (-1,1):eye(head,s*.24,.31,-.90,.11,WHITE,OLIVE)
    jaw=o.part('Jaw',(0,-.03,-.52));ellipsoid(jaw,(0,-.04,-.83),(.33,.10,.16),OLIVE,18,8);seam(jaw,[(-.27,-.0,-.94),(0,-.06,-.99),(.27,-.0,-.94)],.024,WHITE)
    tail=o.part('Tail',(0,-.18,.56));tube(tail,[(0,-.18,.55,.30,.20),(0,-.24,1.11,.18,.11),(0,-.25,1.36,.025,.025)],YELLOW,18,3)
    o.facts=['Graphics9F-A2 show a low yellow slug/blob with pale facial spots, wide mouth and stretching lobes; limbs are absent in the resting silhouette.'];o.reference=['research/canonical-visuals/cast-contact-sheets/slug.png'];return o.resize(1.8)

def electrofish():
    o=Model('Electrofish');m=o.part('Body');tube(m,[(0,.05,.96,.08,.08),(0,.16,.55,.15,.15),(0,-.07,.05,.20,.17),(0,.17,-.44,.22,.20),(0,.12,-.86,.17,.15)],PINK,20,4)
    head=o.part('Head',(0,.11,-.65));ellipsoid(head,(0,.12,-.86),(.23,.22,.33),PINK,20,10);eye(head,.15,.17,-1.07,.05,RED,BLACK);eye(head,-.15,.17,-1.07,.05,RED,BLACK)
    tail=o.part('Tail',(0,.05,.85));tube(tail,[(0,.05,.85,.09,.09),(0,.26,1.32,.07,.07),(0,.18,1.65,.025,.025)],PINK,14,3)
    o.facts=['GraphicsE2/E3 show a narrow red/pink undulating eel with tiny head and tapered tail; E4/E5 are curled/spiral states, not broad fish fins.'];o.reference=['research/canonical-visuals/cast-contact-sheets/electrofish.png'];return o.resize(scale=2)

def fish(kind='Shark'):
    o=Model(kind);m=o.part('Body');isHammer=kind=='Hammerfish';ellipsoid(m,(0,.0,.05),(.45,.50,.94) if isHammer else (.32,.35,1.05),PINK,24,14)
    head=o.part('Head',(0,.02,-.62));ellipsoid(head,(0,.04,-.79),(.47,.44,.47) if isHammer else (.35,.29,.49),PINK,22,12)
    for s in (-1,1):eye(head,s*(.33 if isHammer else .26),.15,-1.01,.065,RED,BLACK)
    jaw=o.part('Jaw',(0,-.11,-.61),'Head')
    if isHammer:
        ellipsoid(head,(0,.02,-1.15),(.31,.30,.10),RED,22,12);ellipsoid(head,(0,.02,-1.24),(.19,.19,.035),BLACK,20,10)
        ellipsoid(jaw,(0,-.26,-1.03),(.29,.12,.22),RED,20,8)
    else:
        ellipsoid(jaw,(0,-.23,-.94),(.28,.08,.41),RED,20,8);seam(jaw,[(-.23,-.15,-1.06),(0,-.17,-1.34),(.23,-.15,-1.06)],.028,BLACK)
        for x in (-.16,-.055,.055,.16):tube(jaw,[(x,-.18,-1.15,.034,.034),(x,-.11,-1.15,.010,.010)],PINK,10,2)
    fin=o.part('Fin',(0,.25,.15));plate(fin,[(-.06,.25),(0,.92),(.08,.25)],.15,.50,PINK)
    for s in (-1,1):
        fin=o.part(('Left' if s<0 else 'Right')+'Fin',(s*.24,-.07,.08));plate(fin,[(s*.20,-.04),(s*.84,-.40),(s*.35,-.44)],.12,.52,RED)
    tail=o.part('Tail',(0,.02,.78));tube(tail,[(0,.02,.78,.16,.15),(0,.02,1.24,.07,.08)],PINK,16,2)
    plate(tail,[(-.04,.02),(0,.54),(.07,.01),(0,-.48)],1.38,.16,PINK)
    o.facts=['Hammerfish graphicsD7/D9/DA/DB have a broad puffer-like body and round forward mouth; the gameplay name does not denote a hammerhead silhouette.' if isHammer else 'Shark graphicsDE-E1 show a slim pointed shark, triangular dorsal fin, forked tail and opening lower jaw.'];o.reference=[f'research/canonical-visuals/cast-contact-sheets/{kind.lower()}.png'];return o.resize(scale=1.85)

def duck():
    o=Model('Duck');m=o.part('Body');ellipsoid(m,(0,-.15,.20),(.57,.51,.90),PINK,24,14)
    tube(m,[(0,.0,-.41,.30,.30),(0,.50,-.48,.25,.27),(0,.79,-.55,.27,.29)],PINK,20,3)
    head=o.part('Head',(0,.58,-.48));ellipsoid(head,(0,.86,-.58),(.35,.38,.34),PINK,22,12)
    tube(head,[(0,.72,-.82,.23,.09),(0,.72,-1.32,.24,.07),(0,.73,-1.45,.15,.045)],RED,20,3,power=.65)
    for s in (-1,1):
        eye(head,s*.24,.93,-.82,.065,RED,BLACK)
        wing=o.part(('Left' if s<0 else 'Right')+'Wing',(s*.42,-.03,.21));ellipsoid(wing,(s*.53,-.08,.24),(.11,.29,.55),RED,20,12)
        for j in range(3):seam(wing,[(s*.62,-.10+j*.10,-.02),(s*.62,-.08+j*.10,.59)],.024,PINK)
    tail=o.part('Tail',(0,-.02,.80));tube(tail,[(0,-.04,.74,.27,.21),(0,.25,1.19,.17,.13),(0,.37,1.23,.025,.025)],PINK,18,3)
    jaw=o.part('Jaw',(0,.66,-.81),'Head');ellipsoid(jaw,(0,.63,-1.14),(.20,.035,.34),RED,18,8)
    o.facts=['GraphicsE7-E9 show a duck silhouette with round body, raised neck, compact head, flat long bill, short swept tail and flapping side wing.'];o.reference=['research/canonical-visuals/cast-contact-sheets/duck.png'];return o.resize(3.7)

def walking_rat(kind='Hordhead'):
    o=Model(kind);m=o.part('Body');c=(0,91,0) if kind=='Hordhead' else RED;hi=(73,174,25) if kind=='Hordhead' else PINK
    ellipsoid(m,(0,-.12,.12),(.54,.86,.43),c,24,14);ellipsoid(m,(0,-.26,-.23),(.40,.62,.20),hi,20,12)
    head=o.part('Head',(0,.65,-.02));ratface(o,head,(0,.96,-.07),c,hi,.85)
    for s in (-1,1):
        limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.43,.40,.02),(s*.68,.02,-.15),(s*.52,-.12,-.58),.16,c)
        limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.33,-.69,.10),(s*.53,-1.11,.12),(s*.44,-1.48,-.20),.23,c,True)
    tail=o.part('Tail',(0,-.58,.41));tube(tail,[(0,-.58,.41,.14,.13),(.32,-.90,.89,.10,.10),(.31,-1.22,1.31,.055,.055),(.05,-1.28,1.43,.018,.018)],hi,14,4)
    o.facts=['Hordhead graphicsB6-B9 show a green long-snouted rat-like humanoid with large ears, bent limbs and tail; BA/C6 include swollen/rolling forms.' if kind=='Hordhead' else 'RacingRat graphicsB2-B4 show a red/pink long-nosed rat runner, large ears, a thin neck and bent jogging legs.'];o.reference=[f'research/canonical-visuals/cast-contact-sheets/{kind.lower()}.png'];return o.resize(5.0)

def flying_head(kind='FlyingHead'):
    o=Model(kind);m=o.part('Body');c=(0,91,0);hi=(73,174,25)
    ellipsoid(m,(0,-.05,.05),(.76,.66,.56),c,24,14)
    head=o.part('Head',(0,.22,-.08));ellipsoid(head,(0,.27,-.13),(.64,.50,.44),hi,24,14)
    for s in (-1,1):
        ellipsoid(head,(s*.55,-.04,-.42),(.38,.39,.28),hi,22,12)
        eye(head,s*.27,.42,-.50,.11,c,BLACK)
        wing=o.part(('Left' if s<0 else 'Right')+'Wing',(s*.57,.36,.13));tube(wing,[(s*.57,.36,.13,.21,.13),(s*.92,.66,.18,.17,.10),(s*1.24,.83,.21,.025,.025)],hi,18,3)
    jaw=o.part('Jaw',(0,-.18,-.18),'Head');ellipsoid(jaw,(0,-.35,-.48),(.35,.17,.23),c,20,10);seam(jaw,[(-.25,-.29,-.63),(0,-.39,-.70),(.25,-.29,-.63)],.03,hi)
    o.facts=['GraphicsBC/BD are shared green flying head silhouettes with bulging cheek lobes, tiny eyes and two swept side appendages; C4 is an expanded form. Dynamic palette chronology is untraced.'];o.reference=[f'research/canonical-visuals/cast-contact-sheets/{kind.lower()}.png'];return o.resize(3.4 if kind=='FlyingHead' else 4.0)

def big_blag():
    o=Model('BigBlag');m=o.part('Body');ellipsoid(m,(0,-.18,.15),(1.08,1.50,.82),BLACK,28,18)
    ellipsoid(m,(0,.05,-.49),(.88,1.10,.38),PINK,26,16)
    # Black shorts and open black vest match the source's very broad belly.
    tube(m,[(0,-1.35,.16,.73,.60),(0,-.87,.16,1.08,.80),(0,-.61,.16,1.00,.73)],BLACK,26,2,power=.82)
    for s in (-1,1):tube(m,[(s*.53,.99,-.36,.24,.16),(s*.68,.56,-.64,.24,.12),(s*.82,-.10,-.53,.20,.11)],BLACK,18,3)
    head=o.part('Head',(0,1.06,.0));ratface(o,head,(0,1.43,-.06),BLACK,PINK,1.18)
    for s in (-1,1):
        limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.84,.75,.06),(s*1.25,.16,-.05),(s*1.13,-.36,-.51),.34,PINK)
        limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.64,-1.07,.09),(s*.74,-1.55,.10),(s*.67,-1.93,-.16),.34,PINK,True)
    tail=o.part('Tail',(0,-.97,.72));tube(tail,[(0,-.97,.72,.17,.16),(.74,-1.15,1.19,.14,.12),(1.52,-.97,1.35,.10,.09),(2.13,-1.10,1.04,.025,.025)],PINK,16,4)
    o.facts=['BigBlag graphicsEF/F1 show an enormous black-clad rat with pale/red belly, long pointed muzzle, round ears, heavy arms, shorts, broad feet and long trailing tail.'];o.reference=['research/canonical-visuals/cast-contact-sheets/bigblag.png'];return o.resize(8.1)

def robomanus():
    o=Model('RoboManus');m=o.part('Body');tube(m,[(0,-.65,.09,.42,.30),(0,-.23,.09,.55,.34),(0,.48,.04,.88,.41),(0,.89,.03,.75,.36)],BLACK,24,3,power=.70)
    for s in (-1,1):tube(m,[(s*.52,.79,-.22,.22,.15),(s*.28,.20,-.31,.16,.10),(s*.24,-.35,-.21,.10,.08)],PINK,16,3)
    head=o.part('Head',(0,.86,.01));ellipsoid(head,(0,1.29,-.03),(.43,.55,.39),RED,24,14,power=.72)
    plate(head,[(-.38,1.44),(.38,1.44),(.35,1.16),(-.35,1.16)],-.40,.08,PINK)
    plate(head,[(-.30,1.38),(.30,1.38),(.30,1.25),(-.30,1.25)],-.46,.035,BLACK)
    jaw=o.part('Jaw',(0,1.11,-.12),'Head');ellipsoid(jaw,(0,1.00,-.28),(.28,.13,.22),PINK,20,10,power=.65)
    for s in (-1,1):
        a=limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.80,.65,.05),(s*1.11,.20,-.06),(s*1.05,-.37,-.30),.28,RED)
        ellipsoid(a,(s*.83,.64,.05),(.36,.42,.39),PINK,22,12,power=.76)
        l=limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.40,-.54,.10),(s*.54,-1.22,-.03),(s*.54,-1.90,.01),.25,PINK,True)
        tube(l,[(s*.53,-1.15,-.01,.26,.27),(s*.55,-1.65,.02,.17,.17),(s*.54,-1.91,.02,.15,.16)],RED,20,3,power=.78)
    weapon=o.part('Weapon',(0,-.25,-.30));tube(weapon,[(0,-.25,-.30,.19,.17),(0,-.25,-1.13,.19,.17)],RED,16,2,power=.55)
    o.facts=['RoboManus graphicsF7/F8 show a tall narrow humanoid robot with visor helmet, exposed bright shoulder/limb segments, black torso and long angular boots; F8 carries a horizontal firearm.'];o.reference=['research/canonical-visuals/cast-contact-sheets/robomanus.png'];return o.resize(9.0)

def buzzball():
    o=Model('Buzzball');m=o.part('Body');ellipsoid(m,(0,0,0),(1,1,1),RED,36,22)
    spiral=o.part('Fin',(0,0,0))
    controls=[]
    for i in range(100):
        t=i/99;angle=t*math.tau*1.75;r=.05+.87*t;x=math.cos(angle)*r;y=math.sin(angle)*r;z=-math.sqrt(max(.02,1-x*x-y*y))-.015
        controls.append((x,y,z,.075,.045))
    tube(spiral,controls,PINK,12,1)
    o.facts=['Buzzball graphics7C-7F form a circular red/pink rotating spiral. Its spherical depth and raised spiral ribbon are authored adaptations.'];o.reference=['research/canonical-visuals/cast-contact-sheets/buzzball.png'];return o.resize(5.5)

def snake():
    o=Model('Snake');m=o.part('Body');tube(m,[(0,0,1.10,.45,.45),(0,0,.55,.50,.50),(0,0,0,.50,.50),(0,0,-.35,.45,.45)],YELLOW,24,3)
    for z in (.85,.42,0):tube(m,[(0,0,z+.04,.506,.506),(0,0,z-.04,.506,.506)],OLIVE,24,1)
    head=o.part('Head',(0,0,-.28));ellipsoid(head,(0,.12,-.70),(.72,.53,.80),RED,28,16,power=.76)
    ellipsoid(head,(0,.03,-1.21),(.67,.30,.53),RED,24,12,power=.73)
    for s in (-1,1):eye(head,s*.49,.36,-1.04,.12,PINK,BLACK)
    jaw=o.part('Jaw',(0,-.15,-.45),'Head');ellipsoid(jaw,(0,-.32,-.98),(.64,.18,.70),RED,24,12,power=.76)
    seam(jaw,[(-.55,-.17,-1.32),(0,-.18,-1.68),(.55,-.17,-1.32)],.04,BLACK)
    for s in (-1,1):tube(jaw,[(s*.42,-.18,-1.37,.075,.065),(s*.42,.04,-1.37,.015,.015)],PINK,14,3)
    tail=o.part('Tail',(0,0,.93));tube(tail,[(0,0,.93,.44,.44),(0,0,1.55,.29,.29),(0,0,1.92,.05,.05)],YELLOW,20,3)
    o.facts=['Snake graphics92-97 show a broad red angular head/jaw and turns;98-9A are yellow/white narrow shaft strips. Full nametable path is not reconstructed; this is a reusable head/body/tail segment cosmetic.'];o.reference=['research/canonical-visuals/cast-contact-sheets/snake.png'];return o.resize(scale=2.2)

def general_slaughter():
    o=Model('GeneralSlaughter');m=o.part('Body')
    tube(m,[(0,-.84,.10,.44,.31),(0,-.46,.12,.64,.40),(0,.20,.12,1.02,.53),(0,.77,.10,1.04,.48),(0,1.01,.11,.63,.35)],BLACK,28,3,power=.74)
    for s in (-1,1):
        ellipsoid(m,(s*.48,.41,-.31),(.52,.42,.25),RED,22,12,power=.80)
        tube(m,[(s*.23,.72,-.43,.14,.10),(s*.61,.71,-.44,.20,.10),(s*.80,.47,-.35,.14,.08)],PINK,16,3)
    plate(m,[(-.56,-.49),(.56,-.49),(.50,-.72),(-.50,-.72)],-.30,.16,RED)
    head=o.part('Head',(0,.84,-.11));ellipsoid(head,(0,1.28,-.15),(.67,.65,.54),RED,26,14,power=.74)
    ellipsoid(head,(0,1.06,-.63),(.62,.37,.41),RED,24,12,power=.65)
    ellipsoid(head,(0,1.09,-.94),(.47,.22,.16),PINK,22,10,power=.62)
    jaw=o.part('Jaw',(0,.90,-.22),'Head');ellipsoid(jaw,(0,.82,-.61),(.50,.15,.35),RED,22,10,power=.7)
    seam(jaw,[(-.43,.96,-.86),(0,.91,-1.05),(.43,.96,-.86)],.036,BLACK)
    for s in (-1,1):
        eye(head,s*.33,1.44,-.59,.085,PINK)
        tube(head,[(s*.12,1.55,-.58,.11,.08),(s*.48,1.64,-.42,.13,.10)],RED,16,3)
        tube(head,[(s*.45,1.69,-.02,.22,.19),(s*.65,2.05,.01,.14,.12),(s*.81,2.32,.03,.02,.02)],PINK,18,4)
        arm=limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.94,.64,.08),(s*1.31,.14,-.03),(s*1.12,-.46,-.37),.35,RED)
        ellipsoid(arm,(s*1.03,.66,.05),(.49,.51,.46),PINK,24,14,power=.72)
        ellipsoid(arm,(s*1.11,-.47,-.40),(.43,.36,.38),RED,20,12,power=.67)
        leg=limb(o,('Left' if s<0 else 'Right')+'Leg',(s*.43,-.74,.12),(s*.56,-1.20,-.03),(s*.51,-1.69,-.16),.27,RED,True)
        start,count,_=leg.components[-1];leg.colors[start:start+count]=[BLACK]*count
    o.facts=['GeneralSlaughter graphicsF2-F6 show a broad horned bovine face, large muzzle, heavy shoulder plates, muscular forearms, narrow belted waist and cloven dark hoof/boot silhouette. Bank overrides69/C0/4C are applied in decoded reference.'];o.reference=['research/canonical-visuals/cast-contact-sheets/generalslaughter.png'];return o.resize(8.3)

def dark_queen():
    o=Model('DarkQueen');m=o.part('Body')
    tube(m,[(0,-.76,.07,.43,.28),(0,-.43,.05,.41,.25),(0,-.11,.03,.30,.20),(0,.29,.02,.39,.23),(0,.72,.03,.52,.26),(0,.93,.03,.33,.21)],BLACK,26,3)
    for s in (-1,1):
        ellipsoid(m,(s*.24,.58,-.16),(.28,.25,.19),BLACK,22,12)
        # High pointed collar/shoulder fins belong to the source outfit.
        plate(m,[(s*.22,.91),(s*.85,1.07),(s*.56,.64),(s*.33,.65)],.02,.18,BROWN)
        tube(m,[(s*.32,-.48,-.12,.055,.035),(s*.20,.04,-.20,.05,.025),(s*.28,.52,-.32,.045,.025),(s*.21,.81,-.23,.04,.025)],BROWN,12,3)
    head=o.part('Head',(0,.96,.03));tube(head,[(0,.91,.02,.17,.17),(0,1.20,.0,.18,.17)],ORANGE,18,2)
    ellipsoid(head,(0,1.53,-.01),(.30,.46,.28),ORANGE,24,14)
    for s in (-1,1):
        eye(head,s*.13,1.61,-.245,.040,CREAM,BLACK)
        tube(head,[(s*.04,1.68,-.26,.035,.025),(s*.20,1.71,-.18,.035,.025)],BLACK,10,2)
    ellipsoid(head,(0,1.49,-.28),(.035,.065,.035),ORANGE,12,8)
    seam(head,[(-.10,1.34,-.24),(0,1.32,-.27),(.10,1.34,-.24)],.018,BLACK)
    hair=o.part('Hair',(0,1.72,.08),'Head');ellipsoid(hair,(0,1.66,.16),(.40,.55,.29),BLACK,26,14)
    # Long pointed black hair, swept down both sides. Front face remains open.
    for s in (-1,1):
        tube(hair,[(s*.29,1.86,.06,.17,.15),(s*.37,1.39,.09,.20,.17),(s*.43,.74,.22,.19,.15),(s*.59,.24,.31,.10,.10),(s*.52,.10,.34,.015,.015)],BLACK,20,4)
        tube(hair,[(s*.27,2.02,.11,.025,.018),(s*.47,1.57,.18,.03,.022),(s*.48,.81,.32,.022,.018)],BROWN,10,3)
        arm=limb(o,('Left' if s<0 else 'Right')+'Arm',(s*.53,.78,.02),(s*.79,.38,-.02),(s*.87,-.10,-.14),.12,ORANGE)
        tube(arm,[(s*.78,.35,-.02,.13,.13),(s*.87,-.14,-.14,.105,.10)],BLACK,18,3)
        upper=o.part(('Left' if s<0 else 'Right')+'Leg',(s*.28,-.58,.06));tube(upper,[(s*.28,-.58,.06,.25,.23),(s*.29,-1.18,.0,.22,.20),(s*.27,-1.65,-.03,.14,.14)],ORANGE,22,4)
        lower=o.part(('Left' if s<0 else 'Right')+'LowerLeg',(s*.27,-1.63,-.03),('Left' if s<0 else 'Right')+'Leg');tube(lower,[(s*.27,-1.63,-.03,.15,.15),(s*.25,-2.10,.04,.15,.14),(s*.23,-2.64,.03,.095,.10)],BROWN,20,4)
        ellipsoid(lower,(s*.23,-2.70,-.17),(.13,.09,.32),BLACK,20,10,power=.73)
        tube(lower,[(s*.23,-2.70,.12,.045,.045),(s*.23,-2.91,.12,.033,.033)],BLACK,12,2)
        tube(lower,[(s*.27,-1.66,-.17,.025,.015),(s*.25,-2.13,-.10,.025,.015),(s*.23,-2.61,-.07,.020,.015)],ORANGE,10,3)
    o.facts=['DarkQueen standing81/kick82 show a very tall slender woman, long black swept hair, high pointed shoulder collar, black leotard/gloves, long legs and high heeled boots. No crown or broad superhero cape is present in these source poses.','Tornado83 is an alternate source attack form; the resting body here retains articulated hips/knees for pose sampling.'];o.reference=['research/canonical-visuals/cast-contact-sheets/darkqueen.png'];return o.resize(8.9)

def healing_fly():
    o=Model('HealingFly');m=o.part('Body');ellipsoid(m,(0,0,.05),(.15,.15,.30),YELLOW,20,12)
    head=o.part('Head',(0,.03,-.17));ellipsoid(head,(0,.04,-.25),(.18,.16,.17),YELLOW,20,10)
    for s in (-1,1):
        eye(head,s*.12,.07,-.36,.038,OLIVE,OLIVE)
        wing=o.part(('Left' if s<0 else 'Right')+'Wing',(s*.08,.12,.06))
        ellipsoid(wing,(s*.29,.23,.16),(.29,.025,.14),WHITE,20,10)
        tube(m,[(s*.10,-.09,.04,.025,.025),(s*.18,-.23,.03,.020,.020)],OLIVE,10,2)
    tail=o.part('Tail',(0,0,.28));tube(tail,[(0,0,.27,.10,.09),(0,-.03,.45,.025,.025)],YELLOW,14,3)
    o.facts=['HealingFly graphics0D/0E show a tiny yellow/olive insect, two white flapping wings and small dark appendages; this collectible is distinct from hostile Raven/Dragon flight.'];o.reference=['research/canonical-visuals/cast-contact-sheets/healingfly.png'];return o.resize(scale=1.7)

EXPECTED={'Pig':['Head','Jaw','LeftArm','RightArm','LeftLeg','RightLeg'],'Dragon':['Head','Jaw','LeftWing','RightWing','LeftLeg','RightLeg','Tail'],'Walker':['LeftLeg','RightLeg','LeftFoot','RightFoot']}
BUILDERS={'Pig':pig,'Dragon':dragon,'Walker':walker}
BUILDERS.update({'Raven':lambda:bird('Raven'),'LargeRaven':lambda:bird('LargeRaven'),'Invader':invader,'RocketRat':rocket_rat,'Snowman':snowman,'SentryDrone':sentry,'GasTurret':gas_turret,'RetroBlaster':lambda:blaster('RetroBlaster'),'SaturnToadtrap':toadtrap,'Robot':lambda:blaster('Robot'),'Slug':slug,'Electrofish':electrofish,'Hammerfish':lambda:fish('Hammerfish'),'Shark':lambda:fish('Shark'),'Duck':duck,'Hordhead':lambda:walking_rat('Hordhead'),'RacingRat':lambda:walking_rat('RacingRat'),'FlyingHead':lambda:flying_head('FlyingHead'),'Swellcheeks':lambda:flying_head('Swellcheeks'),'BigBlag':big_blag,'RoboManus':robomanus,'Buzzball':buzzball,'Snake':snake})
BUILDERS.update({'GeneralSlaughter':general_slaughter,'DarkQueen':dark_queen})
BUILDERS['HealingFly']=healing_fly
for _kind in BUILDERS:
    if _kind not in EXPECTED:EXPECTED[_kind]=['Head'] if _kind not in ('Buzzball','GasTurret') else ['Fin' if _kind=='Buzzball' else 'Weapon']
EXPECTED['Invader']=['LeftArm','RightArm','LeftLeg','RightLeg']

def apply_source_palette(o):
    """Resolve each authored material role through verified spawn palette RAM.

    A role is quantised to the3source colour codes of the evidenced sprite
    slot, then that samecode is looked up after actor XOR and palette writes.
    No model colour is guessed from the family name.
    """
    catalog=json.loads((ROOT/'research/canonical-visuals/cast-source-catalog.json').read_text())
    source=next(f for f in catalog['families'] if f['family']==o.kind)
    primary={'Walker':2,'Raven':1,'LargeRaven':1,'Invader':0,'SaturnToadtrap':2,'Slug':2,'HealingFly':2,'Hordhead':0,'FlyingHead':0,'Swellcheeks':0,'DarkQueen':1}.get(o.kind,3)
    for name,m in o.parts.items():
        result=[]
        for c in m.colors:
            slot=primary
            if o.kind=='RocketRat':slot=3 if name=='Weapon' else 1
            if o.kind=='Snake' and name in ('Body','Tail'):slot=2
            if o.kind=='Snowman' and c in (BROWN,ORANGE,TAN):slot=1
            candidates=[p for p in source['initialToEffectivePaletteMap'] if p['sourceSlot']==slot]
            entry=min(candidates,key=lambda p:sum((a-b)**2 for a,b in zip(c,p['initialRgb'])))
            result.append(tuple(entry['effectiveRgb']))
        m.colors=result
    o.sourcePalette={'paletteIndices':source['paletteIndices'],'actorPaletteXor':source['actorPaletteXor'],'selectedPaletteContext':source.get('selectedPaletteContext'),'sourceSlotPrimary':primary,'initialToEffectivePaletteMap':source['initialToEffectivePaletteMap'],'variantCount':len(source.get('paletteVariants',[])),'limitation':'Representative authored spawn palette only; other source palette variants remain catalogued and are not claimed identical.'}
    o.sourceTrace={'namespace':source['namespace'],'bankRecipe':source['bankRecipe'],'sourceEvidence':source['sourceEvidence'],'frames':[{'frameId':f['frameId'],'width':f['width'],'height':f['height'],'visibleBounds':f['visibleBounds'],'referencePng':f['referencePng']} for f in source['frames']]}
    o.reference.append('research/canonical-visuals/cast-source-catalog.json')
    return o

def build(kind):return apply_source_palette(BUILDERS[kind]())

def validate(o):
    triangles=0;vertices=0;minimum=math.inf;components=0
    assert o.parents['Body'] is None
    for name,m in o.parts.items():
        assert m.vertices and m.faces and len(m.colors)==len(m.vertices),(o.kind,name)
        assert all(math.isfinite(x) for v in m.vertices for x in v),(o.kind,name,'finite')
        assert all(abs(length(n)-1)<1e-6 for n in m.normals()),(o.kind,name,'normal')
        edges=Counter();directed=Counter()
        for a,b,c in m.faces:
            assert len({a,b,c})==3 and min(a,b,c)>=0 and max(a,b,c)<len(m.vertices)
            area=length(cross(sub(m.vertices[b],m.vertices[a]),sub(m.vertices[c],m.vertices[a])))
            assert area>1e-12,(o.kind,name,'zero area',area)
            minimum=min(minimum,area)
            for x,y in ((a,b),(b,c),(c,a)):edges[tuple(sorted((x,y)))]+=1;directed[x,y]+=1
        assert all(n==2 for n in edges.values()),(o.kind,name,'open/nonmanifold',Counter(edges.values()))
        assert all(directed[x,y]==directed[y,x] for x,y in directed),(o.kind,name,'inconsistent winding')
        # Acyclic chain and valid parent references.
        seen=set();node=name
        while node is not None:
            assert node not in seen,(o.kind,'cycle');seen.add(node);node=o.parents[node]
        triangles+=len(m.faces);vertices+=len(m.vertices);components+=len(m.components) or 1
    assert set(EXPECTED[o.kind]).issubset(o.parts),o.kind
    return {'status':'PASS','triangles':triangles,'vertices':vertices,'closedComponents':True,'components':components,'allFinite':True,'unitNormals':True,'validIndices':True,'minimumDoubledTriangleArea':minimum}

def png_rgb(width,height,pixels):
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=b''.join(b'\0'+bytes(pixels[y*width*3:(y+1)*width*3]) for y in range(height))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')

def export(o,directory):
    directory.mkdir(parents=True,exist_ok=True);data=bytearray();views=[];accessors=[];meshes=[];nodes=[];names=list(o.parts);lookup={n:i for i,n in enumerate(names)}
    palette=sorted(set(c for m in o.parts.values() for c in m.colors));cols=math.ceil(math.sqrt(len(palette)));tile=16;size=cols*tile;pixels=bytearray(size*size*3)
    for i,color in enumerate(palette):
        for y in range(tile):
            for x in range(tile):idx=(((i//cols)*tile+y)*size+(i%cols)*tile+x)*3;pixels[idx:idx+3]=bytes(color)
    uv={c:(((i%cols)*tile+tile/2)/size,((i//cols)*tile+tile/2)/size) for i,c in enumerate(palette)}
    def acc(values,kind,ctype=5126,target=34962):
        while len(data)%4:data.append(0)
        offset=len(data);flat=[x for r in values for x in r] if isinstance(values[0],(list,tuple)) else values
        data.extend(struct.pack('<'+str(len(flat))+{5126:'f',5123:'H',5125:'I'}[ctype],*flat));views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':target})
        item={'bufferView':len(views)-1,'componentType':ctype,'count':len(values),'type':kind}
        if kind=='VEC3':item.update(min=bounds(values)[0],max=bounds(values)[1])
        accessors.append(item);return len(accessors)-1
    exported_counts={}
    for name,m in o.parts.items():
        vs=[mul(sub(v,o.pivots[name]),METRES) for v in m.vertices];normals=m.normals();uvs=[uv[c] for c in m.colors];indices=[];split=0
        for face in m.faces:
            colors=[m.colors[i] for i in face]
            if len(set(colors))==1:indices.extend(face)
            else:
                # A source-profile triangle can straddle two sprite colours.
                # Give it a private constant palette UV: interpolating between
                # atlas cells would sample unrelated colours in the gutter.
                counts=Counter(colors);majority=max(counts,key=lambda c:(counts[c],-sum(sum((a-b)**2 for a,b in zip(c,d)) for d in colors)))
                start=len(vs);vs.extend(vs[i] for i in face);normals.extend(normals[i] for i in face);uvs.extend([uv[majority]]*3);indices.extend((start,start+1,start+2));split+=1
        attrs={'POSITION':acc(vs,'VEC3'),'NORMAL':acc(normals,'VEC3'),'TEXCOORD_0':acc(uvs,'VEC2')}
        ix=acc(indices,'SCALAR',5123 if len(vs)<65536 else 5125,34963)
        exported_counts[name]={'vertices':len(vs),'authoringVertices':len(m.vertices),'paletteSplitTriangles':split}
        meshes.append({'name':name,'primitives':[{'attributes':attrs,'indices':ix,'material':0}]})
        parent=o.parents[name];delta=sub(o.pivots[name],o.pivots[parent]) if parent else o.pivots[name]
        node={'name':name,'mesh':lookup[name],'translation':mul(delta,METRES)};children=[lookup[n] for n in names if o.parents[n]==name]
        if children:node['children']=children
        nodes.append(node)
    atlas=png_rgb(size,size,pixels);(directory/'palette.png').write_bytes(atlas)
    while len(data)%4:data.append(0)
    offset=len(data);data.extend(atlas);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(atlas)})
    scene={'asset':{'version':'2.0','generator':'BrickToads deterministic source-informed articulated cast','extras':{'metresPerStud':METRES,'sourcePin':PIN}},'scene':0,'scenes':[{'name':o.kind,'nodes':[lookup['Body']]}],
        'nodes':nodes,'meshes':meshes,'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(data)}],
        'images':[{'name':'SourceInspiredPalette','bufferView':len(views)-1,'mimeType':'image/png'}],
        'textures':[{'source':0,'sampler':0}],'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}],
        'materials':[{'name':'PaletteSurface','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.78},'doubleSided':False}]}
    encoded=json.dumps(scene,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    total=28+len(encoded)+len(data);blob=struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data
    target=directory/(o.kind+'.glb');target.write_bytes(blob);assert len(blob)<20_000_000
    envelope=bounds([v for m in o.parts.values() for v in m.vertices]);report=validate(o)
    rig={'schema':1,'kind':o.kind,'status':'source-informed-authored3d-pending-native-review','sourcePin':PIN,'sourceReference':o.reference,'sourceFacts':o.facts,
        'inferred3D':['All depth, unseen rear surfaces, rest pivots and 3D joint angles are authored adaptations of2D source.','Neutral stance is for articulated runtime playback, not a claim of exact canonical3D anatomy.','Cosmetic only; collider health, physics and gameplay dimensions remain external.'],
        'metresPerStud':METRES,'coordinateSystem':'right-handed Y-up, forward -Z; root at existing torso collider centre','bounds':envelope,'sourceTrace':o.sourceTrace,'sourcePalette':o.sourcePalette,
        'parts':[{'name':n,'parent':o.parents[n],'pivot':o.pivots[n],'localBounds':bounds([sub(v,o.pivots[n]) for v in m.vertices]),'globalBounds':bounds(m.vertices),**exported_counts[n],'triangles':len(m.faces)} for n,m in o.parts.items()],
        'joints':[{'name':n,'parent':p,'child':n,'parentAttachment':sub(o.pivots[n],o.pivots[p]),'childAttachment':[0,0,0]} for n,p in o.parents.items() if p],
        'surface':{'embeddedTexture':True,'paletteColors':palette,'atlasResolution':[size,size],'COLOR_0':'omitted; source-inspired sRGB colour baked into palette texture','uvSafety':'Each triangle has a constant UV inside one16x16palette cell. Mixed-colour source-profile triangles are split and quantised to their majority colour; positions/normals unchanged.','paletteSplitTriangles':sum(e['paletteSplitTriangles'] for e in exported_counts.values())},'validation':report}
    (directory/(o.kind+'-rig.json')).write_text(json.dumps(rig,indent=2)+'\n')
    return {**report,'glb':str(target.relative_to(ROOT)).replace('\\','/'),'rig':str((directory/(o.kind+'-rig.json')).relative_to(ROOT)).replace('\\','/'),'bytes':len(blob),'sha256':hashlib.sha256(blob).hexdigest(),'segments':names,'bounds':envelope}

def preview(o,path,size=(640,420),azimuths=(0,40,90)):
    spec=importlib.util.spec_from_file_location('cast_software_render',HERE/'render_cast.py');renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
    return renderer.render(o,path,size=(720,480),azimuths=azimuths)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--families',nargs='*');parser.add_argument('--no-preview',action='store_true');args=parser.parse_args()
    kinds=args.families or list(BUILDERS);manifest={'schema':1,'sourcePin':PIN,'scope':'cosmetic authored3D, source facts distinguished from depth inference','families':{}}
    existing=HERE/'manifest.json'
    if existing.exists():manifest=json.loads(existing.read_text())
    for kind in kinds:
        o=build(kind);manifest['families'][kind]=export(o,HERE/kind)
        if not args.no_preview:preview(o,HERE/kind/'turntable.png')
        print(kind,manifest['families'][kind]['triangles'],manifest['families'][kind]['bytes'],flush=True)
    existing.write_text(json.dumps(manifest,indent=2)+'\n')
    if not args.no_preview:
        spec=importlib.util.spec_from_file_location('cast_software_contact',HERE/'render_cast.py');renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
        renderer.contact_sheet(HERE,list(BUILDERS))

if __name__=='__main__':main()
