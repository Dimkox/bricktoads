"""Deterministic closed course scenery: source contours, authored solid depth.

No ROM or sprite image is embedded. Every visible triangle belongs to a closed
volume; the embedded image is an original constant-cell palette UV atlas.
Source mappings live separately in source/source-catalog.json. System markers
are explicitly authored conventions rather than purported NES objects.
"""
from pathlib import Path
from collections import Counter
import argparse, hashlib, importlib.util, json, math, struct

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
geo=module('course_prop_geometry',ROOT/'assets/characters/canonical-cast/build_cast.py')
render=module('course_prop_render',HERE/'render_course_props.py')
PIN=geo.PIN
BLACK=(18,19,20); WHITE=(255,255,255); CREAM=(255,221,171)
RED=(180,0,0); PINK=(255,100,97); DARKRED=(91,0,0)
YELLOW=(205,202,62); OLIVE=(117,118,0); GOLD=(229,170,37)
GREY=(145,151,157); STEEL=(65,79,95); BLUE=(71,115,214)
CYAN=(56,180,204); TEAL=(0,102,120); GREEN=(83,147,55)
BROWN=(155,83,0); TAN=(228,196,144); ORANGE=(250,160,66)
KINDS=['AirMine','BoardingPad','Bomb','Buzzball','ElectricTrap','Fan','Gas','Gear','IceBlock','Icicle','Lift','Log','Mine','MovingIcePlatform','Ramp','Rocket','RocketLauncher','Rope','RotatingSpike','Snowball','Spike','Spring','Telegraph','Tower','TowerPlatform','Warning','Water','Whirlpool']

def part(o,name,role='Shell',pivot=(0,0,0)):
    if not hasattr(o,'roles'):o.roles={}
    o.roles[name]=role
    return o.part(name,pivot)
def rod(m,a,b,r,color,radial=8):geo.tube(m,[(*a,r,r),(*b,r,r)],color,radial,1)
def ball(m,c,r,color,radial=16,rings=10,power=1):geo.ellipsoid(m,c,r,color,radial,rings,power)
def poly(m,points,y,thickness,color):
    t=geo.Mesh('temporary');geo.plate(t,points,y,thickness,color)
    m.append([(x,z,y_) for x,y_,z in t.vertices],t.faces,color)
def box(m,c,size,color):
    x,y,z=c;rx,ry,rz=[s/2 for s in size]
    poly(m,[(x-rx,z-rz),(x+rx,z-rz),(x+rx,z+rz),(x-rx,z+rz)],y,ry*2,color)
def panel(m,points,z,thickness,color):geo.plate(m,points,z,thickness,color)
def cone(m,a,b,r,color,sides=8):
    axis=geo.unit(geo.sub(b,a));ref=(0,0,1) if abs(axis[2])<.85 else (0,1,0)
    u=geo.unit(geo.cross(axis,ref));v=geo.unit(geo.cross(u,axis))
    vs=[geo.add(a,geo.add(geo.mul(u,r*math.cos(i*math.tau/sides)),geo.mul(v,r*math.sin(i*math.tau/sides)))) for i in range(sides)]+[b,a]
    fs=[]
    for i in range(sides):j=(i+1)%sides;fs.extend(((i,j,sides),(sides+1,j,i)))
    m.append(vs,fs,color)
def ring(m,c,r,minor,color,axis='Y',segments=24,around=6):
    vs=[];fs=[]
    for i in range(segments):
        a=i*math.tau/segments
        for j in range(around):
            b=j*math.tau/around;q=r+minor*math.cos(b)
            xyz=(q*math.cos(a),minor*math.sin(b),q*math.sin(a))
            if axis=='Z':xyz=(xyz[0],xyz[2],xyz[1])
            elif axis=='X':xyz=(xyz[1],xyz[0],xyz[2])
            vs.append(geo.add(c,xyz))
    for i in range(segments):
        for j in range(around):
            a=i*around+j;b=((i+1)%segments)*around+j;cc=i*around+(j+1)%around;d=((i+1)%segments)*around+(j+1)%around
            fs.extend(((a,b,cc),(b,d,cc)))
    m.append(vs,fs,color)
def helix(m,axis,r,length,turns,width,color,phase=0,steps=64):
    controls=[]
    for i in range(steps+1):
        t=i/steps;a=t*math.tau*turns+phase
        p=(r*math.cos(a),length*(t-.5),r*math.sin(a))
        if axis=='Z':p=(p[0],p[2],p[1])
        controls.append((*p,width,width))
    geo.tube(m,controls,color,8,1)
def bolts(m,xs,zs,y,color=GREY,r=.09):
    for x in xs:
        for z in zs:ball(m,(x,y,z),(r,r*.6,r),color,8,6)
def star(m,r1,r2,teeth,y,thickness,color):
    points=[]
    for i in range(teeth):
        for k,r in ((0,r1),(.20,r2),(.70,r2),(.90,r1)):
            a=(i+k)*math.tau/teeth;points.append((math.cos(a)*r,math.sin(a)*r))
    poly(m,points,y,thickness,color)
def annular_shell(m,y0,y1,outer,inner,color,n=12):
    vs=[];fs=[]
    for y,r in ((y0,outer),(y1,outer),(y0,inner),(y1,inner)):
        vs.extend((r*math.cos(i*math.tau/n),y,r*math.sin(i*math.tau/n)) for i in range(n))
    for i in range(n):
        j=(i+1)%n
        fs.extend(((i,j,n+i),(j,n+j,n+i),(2*n+i,3*n+i,2*n+j),(2*n+j,3*n+i,3*n+j),
                   (i,2*n+i,j),(j,2*n+i,2*n+j),(n+i,n+j,3*n+i),(n+j,3*n+j,3*n+i)))
    m.append(vs,fs,color)

def air_mine():
    o=geo.Model('AirMine');m=part(o,'Body','Casing');ball(m,(0,0,0),(1.05,.82,1.05),RED,20,12,power=.8)
    ring(m,(0,-.10,0),1.01,.12,DARKRED)
    m=part(o,'Sensors','Prongs')
    for i in range(6):
        a=i*math.tau/6;p=(math.cos(a),.05,math.sin(a));q=(p[0]*1.44,.10,p[2]*1.44)
        rod(m,geo.mul(p,.85),q,.10,BLACK);ball(m,q,(.15,.15,.15),PINK,10,6)
    m=part(o,'Cap','Beacon');rod(m,(0,.68,0),(0,1.16,0),.17,DARKRED);ball(m,(0,1.17,0),(.24,.15,.24),YELLOW,12,8)
    return o
def boarding_pad():
    o=geo.Model('BoardingPad');m=part(o,'Body','Deck');box(m,(0,-.19,0),(4,.38,4),STEEL)
    m=part(o,'Rim','Edge');ring(m,(0,.01,0),1.68,.12,CYAN,segments=32)
    # Four inward chevrons supply a visible landing target, with no text label.
    m=part(o,'Target','Pattern')
    for i in range(4):
        a=i*math.pi/2;points=[(-.25,1.40),(0,1.08),(.25,1.40),(.25,1.17),(0,.82),(-.25,1.17)]
        points=[(x*math.cos(a)-z*math.sin(a),x*math.sin(a)+z*math.cos(a)) for x,z in points];poly(m,points,.021,.045,YELLOW)
    ring(m,(0,.034,0),.38,.045,WHITE,segments=20)
    return o
def bomb():
    # B3 is a bundled three-lobed green explosive, not a spherical cartoon bomb.
    o=geo.Model('Bomb');m=part(o,'Body','Casing');geo.tube(m,[(0,-.85,.10,.43,.40),(0,.56,.10,.43,.40)],(0,102,0),14,1)
    for x,name in ((-.62,'LeftCanister'),(.62,'RightCanister')):
        m=part(o,name,'Casing');geo.tube(m,[(x,-.85,0,.29,.34),(x,.60,0,.29,.34),(x,.83,0,.22,.28)],(0,102,0),12,2)
        ball(m,(x,.94,0),(.28,.22,.30),(88,184,44),12,8)
        rod(m,(x-.15,-.64,-.30),(x-.15,.54,-.30),.045,(88,184,44),6)
    m=part(o,'Strap','Band');ring(m,(0,.10,0),.74,.105,BLACK,'Y',segments=24)
    box(m,(0,.08,-.41),(.92,.78,.08),(88,184,44))
    m=part(o,'Emblem','Pattern');panel(m,[(-.31,.32),(.31,.32),(0,-.12)],-.47,.055,(0,102,0))
    for x in (-.34,.34):ball(m,(x,1.10,0),(.16,.15,.20),BLACK,10,6)
    return o
def buzzball():
    o=geo.build('Buzzball');o.parts['Ribbon']=o.parts.pop('Fin');o.parts['Ribbon'].name='Ribbon';o.pivots['Ribbon']=o.pivots.pop('Fin');o.parents['Ribbon']=o.parents.pop('Fin')
    o.roles={'Body':'Casing','Ribbon':'Ribbon'};o.resize(scale=.50);return o
def electric():
    # Source5A is a semicircular cyan mechanical emitter. Mirrored pair and
    # the short linking arc are authored to suit the existing runtime volume.
    o=geo.Model('ElectricTrap');m=part(o,'Body','Mount');box(m,(0,-.91,0),(3.6,.30,1.12),BLACK)
    m=part(o,'Emitters','Electrodes')
    for s in (-1,1):
        pts=[]
        for i in range(15):
            a=-math.pi/2+i*math.pi/14;pts.append((s*(1.52-.65*math.cos(a)),.65*math.sin(a),0,.16,.25))
        geo.tube(m,pts,TEAL,10,1)
        for y in (-.46,0,.46):rod(m,(s*1.25,y,-.23),(s*.92,y+.08,-.23),.075,CYAN)
    m=part(o,'Arc','Ribbon');geo.tube(m,[(-.91,.11,0,.06,.06),(-.50,.28,0,.06,.06),(-.15,-.18,0,.06,.06),(.19,.27,0,.06,.06),(.55,-.13,0,.06,.06),(.91,.11,0,.06,.06)],WHITE,8,1)
    return o
def fan():
    o=geo.Model('Fan');m=part(o,'Body','Housing');annular_shell(m,-.44,.44,1.65,1.27,STEEL,16)
    # Rotate housing and rotor from the deck-normal orientation to forward -Z.
    m.vertices=[(x,z,-y) for x,y,z in m.vertices]
    m=part(o,'Rotor','Rotor',(0,0,0));rod(m,(0,0,-.20),(0,0,.20),.30,RED,16)
    for i in range(5):
        a=i*math.tau/5;points=[(.20,-.14),(.55,-.39),(1.23,-.25),(1.16,.20),(.43,.26)]
        points=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in points];panel(m,points,0,.19,CYAN)
    m=part(o,'Grille','Guard')
    for i in range(6):
        a=i*math.tau/6;rod(m,(math.cos(a)*.31,math.sin(a)*.31,-.48),(math.cos(a)*1.45,math.sin(a)*1.45,-.48),.038,GREY)
    ring(m,(0,0,-.48),.63,.035,GREY,'Z',segments=24)
    ring(m,(0,0,-.45),1.52,.055,WHITE,'Z',segments=32)
    m=part(o,'Bracket','Bracket');box(m,(0,-1.64,0),(2,.25,1.4),BLACK)
    for x in (-.85,.85):rod(m,(x,-1.58,0),(x,-1.15,0),.13,STEEL)
    return o
def gas():
    o=geo.Model('Gas')
    for name,coords in [('Body',[(-.70,-.05,0,.75),(0,-.1,0,.85)]),('UpperCloud',[(.48,.32,.05,.73),(-.14,.65,.13,.57)]),('TrailingCloud',[(-1.38,-.10,.13,.44),(.95,-.02,-.04,.52)])]:
        m=part(o,name,'CloudLobe')
        for x,y,z,r in coords:ball(m,(x,y,z),(r,r*.68,r*.65),CREAM if name=='UpperCloud' else GREEN,14,8)
    m=part(o,'Contours','Pattern')
    for x,y,z in ((-.78,.08,-.49),(.26,.37,-.43),(.78,.07,-.36)):
        geo.tube(m,[(x-.22,y,z,.035,.025),(x-.10,y+.14,z-.03,.035,.025),(x+.10,y+.10,z,.035,.025)],OLIVE,8,2)
    return o
def gear():
    o=geo.Model('Gear');m=part(o,'Body','Teeth');star(m,1.32,1.70,12,0,.42,GREY)
    m=part(o,'Hub','Hub');rod(m,(0,-.32,0),(0,.32,0),.52,GREY,20);rod(m,(0,-.37,0),(0,.37,0),.19,BLACK,12)
    m=part(o,'Spokes','Pattern')
    for i in range(6):
        a=i*math.tau/6;rod(m,(math.cos(a)*.53,.227,math.sin(a)*.53),(math.cos(a)*1.18,.227,math.sin(a)*1.18),.10,BLACK)
    for m in o.parts.values():m.vertices=[(x,-z,y) for x,y,z in m.vertices]
    return o
def ice_block(kind='IceBlock',length=3.2):
    o=geo.Model(kind);m=part(o,'Body','Ice');box(m,(0,0,0),(3.8,1.45,length),CYAN)
    m=part(o,'Frost','Crust');poly(m,[(-1.77,-length*.45),(1.77,-length*.45),(1.77,length*.45),(-1.77,length*.45)],.73,.08,WHITE)
    m=part(o,'Cracks','Pattern')
    for x,z,s in ((-.7,-.3,1),(.7,.4,-1)):
        geo.tube(m,[(x-.4,.24,-length/2-.011,.035,.018),(x,.03,-length/2-.015,.035,.018),(x-.18,-.30,-length/2-.015,.035,.018),(x+.10,-.52,-length/2-.011,.025,.018)],WHITE,6,1)
        geo.tube(m,[(x-.20,.775,z-.70,.025,.025),(x+.10,.775,z-.20,.025,.025),(x-.05,.775,z+.20,.025,.025)],TEAL,6,1)
    if kind=='MovingIcePlatform':
        m=part(o,'Runner','Bracket')
        for x in (-1.15,1.15):geo.tube(m,[(x,-.82,-length*.40,.13,.10),(x,-.99,0,.13,.10),(x,-.82,length*.40,.13,.10)],TEAL,10,2)
        m=part(o,'HangingIce','Point')
        for x in (-1.50,-.90,-.30,.30,.90,1.50):
            for z in (-length*.43,length*.43):cone(m,(x,-.58,z),(x+.08,-1.08-(.12 if abs(x)>.6 else 0),z),.20,WHITE,6)
    return o
def icicle():
    o=geo.Model('Icicle');m=part(o,'Body','Point');cone(m,(0,.90,0),(.10,-1.85,-.05),.70,CYAN,7)
    m=part(o,'Crown','Ice');cone(m,(0,.88,0),(-.30,-.48,.18),.43,WHITE,6)
    for x,z in ((-.52,.10),(.45,.20),(.10,-.45)):cone(m,(x,.90,z),(x*.80,-.04,z*.75),.24,CYAN,6)
    return o
def lift():
    o=geo.Model('Lift');m=part(o,'Body','Deck');box(m,(0,-.22,0),(4.6,.44,3.3),BROWN)
    m=part(o,'Deck','Deck');box(m,(0,.03,0),(4.35,.12,3.05),ORANGE)
    m=part(o,'Brackets','Bracket')
    for x in (-1.80,1.80):
        rod(m,(x,-.40,-1.12),(x,-1.23,0),.13,BLACK);rod(m,(x,-1.23,0),(x,-.40,1.12),.13,BLACK)
    m=part(o,'EdgeMarks','Pattern')
    for x in (-1.7,-.85,0,.85,1.7):poly(m,[(x-.20,-1.45),(x+.12,-1.45),(x+.37,-1.14),(x+.05,-1.14)],.10,.035,YELLOW)
    return o
def log():
    o=geo.Model('Log');m=part(o,'Body','Wood');geo.tube(m,[(0,0,-2.3,.68,.64),(0,0,-1.85,.73,.67),(0,0,1.85,.70,.65),(0,0,2.3,.63,.61)],BROWN,14,2)
    m=part(o,'EndGrain','Pattern')
    for s in (-1,1):
        rod(m,(0,0,s*2.30),(0,0,s*2.33),.56,TAN,14)
        for r in (.14,.29,.43):ring(m,(0,0,s*2.355),r,.024,BROWN,'Z',segments=18)
        rod(m,(0,0,s*2.37),(.30,.35,s*2.37),.022,BROWN,6)
    m=part(o,'Bark','Pattern')
    for i in range(7):
        a=i*math.tau/7;x=.695*math.cos(a);y=.65*math.sin(a)
        geo.tube(m,[(x,y,-1.98,.025,.025),(x*1.03,y*1.03,-.7,.033,.025),(x*.99,y*.99,.30,.027,.025),(x,y,1.9,.025,.025)],TAN if i%3==0 else OLIVE,6,1)
    m=part(o,'Branch','Wood',(.50,.35,.65));geo.tube(m,[(.48,.28,.65,.24,.20),(.90,.60,.69,.16,.15),(1.08,.79,.69,.14,.13)],BROWN,10,2)
    rod(m,(1.08,.79,.69),(1.09,.81,.69),.12,TAN,10)
    return o
def mine():
    o=geo.Model('Mine');m=part(o,'Body','Casing');ball(m,(0,0,0),(1.0,.66,1.0),GREY,20,12,power=.70)
    m=part(o,'Prongs','Prongs')
    for i in range(8):
        a=i*math.tau/8;p=(math.cos(a)*.88,.05,math.sin(a)*.88);q=(math.cos(a)*1.34,.08,math.sin(a)*1.34)
        rod(m,p,q,.13,DARKRED,8);ball(m,q,(.17,.16,.17),PINK,10,6)
    m=part(o,'Plate','Band');ring(m,(0,.08,0),.93,.10,BLACK,segments=24);rod(m,(0,.57,0),(0,.83,0),.28,WHITE,14)
    for a in (0,math.tau/3,math.tau*2/3):ball(m,(math.cos(a)*.40,.625,math.sin(a)*.40),(.15,.035,.15),BLACK,10,6)
    m=part(o,'ArmingStud','Beacon');ball(m,(0,.86,0),(.18,.10,.18),WHITE,12,8)
    return o
def ramp():
    o=geo.Model('Ramp');m=part(o,'Body','Wedge')
    vs=[(-2,-.6,-2.4),(2,-.6,-2.4),(-2,-.6,2.4),(2,-.6,2.4),(-2,.6,2.4),(2,.6,2.4)]
    fs=[(0,2,1),(1,2,3),(0,1,4),(1,5,4),(0,4,2),(1,3,5),(2,4,3),(3,4,5)]
    m.append(vs,fs,WHITE)
    m=part(o,'Rails','Edge')
    for x in (-1.82,1.82):rod(m,(x,-.50,-2.10),(x,.66,2.18),.11,PINK,10)
    m=part(o,'Grip','Pattern')
    for z in (-1.50,-.70,.10,.90,1.70):rod(m,(-1.50,-.54+(z+2.4)/4,z),(1.50,-.54+(z+2.4)/4,z),.045,DARKRED)
    return o
def rocket():
    o=geo.Model('Rocket');m=part(o,'Body','Casing');geo.tube(m,[(0,0,1.65,.41,.41),(0,0,.70,.48,.48),(0,0,-.85,.48,.48)],GREY,20,2)
    m=part(o,'Nose','Point');cone(m,(0,0,-.82),(0,0,-2.05),.48,WHITE,16)
    m=part(o,'Fins','Fins')
    for i in range(4):
        a=i*math.pi/2;t=geo.Mesh('fin');panel(t,[(.30,.55),(.96,1.50),(.87,1.78),(.27,1.36)],0,.15,GREY)
        m.append([(x*math.cos(a)-z*math.sin(a),x*math.sin(a)+z*math.cos(a),y) for x,y,z in t.vertices],t.faces,GREY)
    m=part(o,'Nozzle','Nozzle');rod(m,(0,0,1.53),(0,0,1.85),.30,BLACK,16);ring(m,(0,0,1.83),.30,.06,GREY,'Z',segments=20)
    m=part(o,'Band','Band');ring(m,(0,0,-.37),.48,.045,BLACK,'Z',segments=24)
    return o
def launcher():
    o=geo.Model('RocketLauncher');m=part(o,'Body','Mount');box(m,(0,-.72,.20),(2.55,.40,2.90),BLACK)
    m=part(o,'Barrel','Barrel',(0,.10,0));annular_shell(m,-1.57,1.57,.76,.54,STEEL,16);m.vertices=[(x,z+.20,-y) for x,y,z in m.vertices]
    m=part(o,'Muzzle','Rim');ring(m,(0,.20,-1.58),.65,.15,RED,'Z',segments=24)
    m=part(o,'Stand','Bracket')
    for x in (-.78,.78):rod(m,(x,-.57,-.7),(x*.56,.20,.20),.14,GREY);rod(m,(x*.56,.20,.20),(x,-.57,.9),.14,GREY)
    m=part(o,'Breech','Socket');box(m,(0,.20,1.47),(1.48,1.24,.35),RED)
    for x in (-.65,.65):box(m,(x,.65,.77),(.12,.18,.50),YELLOW)
    return o
def rope():
    o=geo.Model('Rope');m=part(o,'Body','Rope');rod(m,(0,0,-3.0),(0,0,3.0),.13,BROWN,10)
    m=part(o,'Twist','Ribbon')
    for phase in (0,math.pi):helix(m,'Z',.13,6,8,.045,TAN,phase,96)
    m=part(o,'Knots','Knot')
    for z in (-2.90,2.90):
        ring(m,(0,0,z),.17,.09,BROWN,'Z',segments=14);ball(m,(0,0,z),(.19,.19,.16),TAN,10,6)
    return o
def rotating_spike():
    o=geo.Model('RotatingSpike');m=part(o,'Body','Hub');ball(m,(0,0,0),(.47,.47,.47),STEEL,16,10)
    m=part(o,'Teeth','Teeth')
    for i in range(8):
        a=i*math.tau/8;cone(m,(math.cos(a)*.33,0,math.sin(a)*.33),(math.cos(a)*1.65,0,math.sin(a)*1.65),.28,GREY,6)
    m=part(o,'Axle','Axle');rod(m,(0,-.59,0),(0,.59,0),.20,RED,12);ring(m,(0,.48,0),.25,.065,BLACK,segments=16)
    return o
def snowball():
    o=geo.Model('Snowball');m=part(o,'Body','Snow');ball(m,(0,0,0),(1.05,.99,1.04),WHITE,20,12,power=.86)
    m=part(o,'PackedRidges','Pattern')
    for a in (-1.1,0,1.1):
        points=[]
        for i in range(12):
            t=-1.0+i/11*2.0;x=math.sin(t)*.88;y=math.sin(a)*math.cos(t)*.92;z=-math.cos(a)*math.cos(t)*1.02;points.append((x,y,z,.025,.025))
        geo.tube(m,points,CYAN,6,1)
    return o
def spike():
    o=geo.Model('Spike');m=part(o,'Body','Point');cone(m,(0,-.48,0),(0,1.42,0),.30,WHITE,6)
    for i in range(6):
        a=i*math.tau/6;r=.62
        cone(m,(math.cos(a)*r,-.48,math.sin(a)*r),(math.cos(a)*r*1.15,.58+(i%2)*.24,math.sin(a)*r*1.15),.27,YELLOW,6)
    m=part(o,'Socket','Mount');ball(m,(0,-.57,0),(1.05,.20,1.05),OLIVE,20,8);ring(m,(0,-.43,0),.90,.06,WHITE,segments=24)
    m=part(o,'Edge','Pattern');rod(m,(.13,-.29,-.21),(.012,1.29,-.012),.025,YELLOW,6)
    return o
def spring():
    o=geo.Model('Spring');m=part(o,'Body','Mount');box(m,(0,-1.07,0),(2.35,.28,2.35),ORANGE)
    m=part(o,'Coil','Coil');helix(m,'Y',.63,1.60,4.25,.13,YELLOW,0,72)
    m=part(o,'Deck','Deck',(0,.98,0));box(m,(0,.96,0),(2.3,.28,2.3),OLIVE);box(m,(0,1.13,0),(1.94,.06,1.94),WHITE)
    m=part(o,'Grip','Pattern');
    for z in (-.55,0,.55):rod(m,(-.65,1.18,z),(.65,1.18,z),.035,YELLOW)
    return o
def telegraph():
    o=geo.Model('Telegraph');m=part(o,'Body','Marker');ring(m,(0,0,0),1.64,.055,ORANGE,segments=40)
    m=part(o,'Segments','Pattern')
    for i in range(8):
        a=i*math.tau/8;rod(m,(math.cos(a)*1.04,.02,math.sin(a)*1.04),(math.cos(a)*1.40,.02,math.sin(a)*1.40),.055,YELLOW,6)
    m=part(o,'Centre','Pattern');
    for axis in (0,1):rod(m,(-.32 if axis==0 else 0,.02,-.32 if axis==1 else 0),(.32 if axis==0 else 0,.02,.32 if axis==1 else 0),.045,RED,6)
    return o
def tower():
    # Revolution background blocks evidence purple/magenta cylindrical bricks.
    # The cylinder, hollow rear wall and exact wrap layout are authored depth.
    dark=(68,0,100);purple=(136,20,176);light=(228,84,236)
    o=geo.Model('Tower');m=part(o,'Body','Shell');annular_shell(m,-8,8,3.40,3.03,dark,24)
    faces=[part(o,'PurpleBricks','Masonry'),part(o,'MagentaBricks','Masonry')]
    for row in range(12):
        y=-7.33+row*1.333
        for i in range(8):
            a0=(i+(row%2)*.5)*math.tau/8+.018;a1=a0+math.tau/8-.036
            pts=[(3.51*math.cos(a0+(a1-a0)*j/3),3.51*math.sin(a0+(a1-a0)*j/3)) for j in range(4)]
            pts +=[(3.38*math.cos(a0+(a1-a0)*j/3),3.38*math.sin(a0+(a1-a0)*j/3)) for j in range(3,-1,-1)]
            poly(faces[(row+i)%2],pts,y,1.23,purple if (row+i)%2==0 else light)
    m=part(o,'Rims','Rim')
    for y in (-7.91,7.91):ring(m,(0,y,0),3.40,.10,dark,segments=36)
    return o
def tower_platform():
    o=geo.Model('TowerPlatform');m=part(o,'Body','Deck');poly(m,[(-2.8,-1.3),(2.8,-1.3),(2.8,1.3),(-2.8,1.3)],-.19,.38,BROWN)
    m=part(o,'Deck','Deck');box(m,(0,.045,0),(5.20,.10,2.30),ORANGE)
    m=part(o,'Brackets','Bracket')
    for x in (-2,2):rod(m,(x,-.30,-.95),(x,-1.40,1.0),.14,BLACK);box(m,(x,-.75,1.08),(.4,1.55,.28),STEEL)
    m=part(o,'EdgeMarks','Pattern')
    for x in (-2.1,-1.3,-.5,.3,1.1,1.9):poly(m,[(x,-1.24),(x+.25,-1.24),(x+.48,-.95),(x+.23,-.95)],.105,.035,YELLOW)
    return o
def warning():
    o=geo.Model('Warning');m=part(o,'Body','Marker');poly(m,[(-1.52,1.12),(1.52,1.12),(0,-1.50)],0,.12,BLACK)
    m=part(o,'Border','Pattern')
    for a,b in [((-1.30,.075,.98),(1.30,.075,.98)),((1.30,.075,.98),(0,.075,-1.25)),((0,.075,-1.25),(-1.30,.075,.98))]:rod(m,a,b,.065,PINK,8)
    m=part(o,'Symbol','Pattern');box(m,(0,.08,-.11),(.18,.10,1.02),WHITE);ball(m,(0,.085,.69),(.13,.06,.13),WHITE,10,6)
    return o
def water():
    o=geo.Model('Water');m=part(o,'Body','Water');box(m,(0,-.12,0),(4,.24,4),(8,16,144))
    for k,name in enumerate(('NearWaves','FarWaves')):
        m=part(o,name,'Ribbon')
        for j in range(3):
            z=-1.45+j*1.40+k*.35;controls=[]
            for i in range(13):
                x=-1.80+i*.30;controls.append((x,.035+math.sin(i*.8+j)*.035,z+math.sin(i*.8+j)*.16,.06,.045))
            geo.tube(m,controls,CYAN if k==0 else WHITE,8,1)
    return o
def whirlpool():
    o=geo.Model('Whirlpool');m=part(o,'Body','Water');ball(m,(0,-.15,0),(2.0,.23,2.0),TEAL,28,8)
    m=part(o,'OuterFoam','Rim');ring(m,(0,.02,0),1.85,.11,CYAN,segments=40)
    m=part(o,'Spiral','Ribbon');controls=[]
    for i in range(90):
        t=i/89;a=t*math.tau*2.5;r=.16+1.56*t;controls.append((math.cos(a)*r,.01+.08*t,math.sin(a)*r,.085,.055))
    geo.tube(m,controls,WHITE,8,1)
    m=part(o,'Eye','Socket');ball(m,(0,-.015,0),(.25,.055,.25),BLACK,16,8)
    return o

BUILDERS={'AirMine':air_mine,'BoardingPad':boarding_pad,'Bomb':bomb,'Buzzball':buzzball,'ElectricTrap':electric,'Fan':fan,'Gas':gas,'Gear':gear,'IceBlock':ice_block,'Icicle':icicle,'Lift':lift,'Log':log,'Mine':mine,'MovingIcePlatform':lambda:ice_block('MovingIcePlatform',4.3),'Ramp':ramp,'Rocket':rocket,'RocketLauncher':launcher,'Rope':rope,'RotatingSpike':rotating_spike,'Snowball':snowball,'Spike':spike,'Spring':spring,'Telegraph':telegraph,'Tower':tower,'TowerPlatform':tower_platform,'Warning':warning,'Water':water,'Whirlpool':whirlpool}

def parse(blob):
    magic,version,total=struct.unpack_from('<4sII',blob);assert(magic,version,total)==(b'glTF',2,len(blob))
    n=struct.unpack_from('<I',blob,12)[0];return json.loads(blob[20:20+n]),blob[28+n:]
def write_glb(path,scene,data):
    data=bytearray(data);data+=b'\0'*((-len(data))%4);scene['buffers']=[{'byteLength':len(data)}]
    encoded=json.dumps(scene,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    blob=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(data))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data
    path.write_bytes(blob);return blob
def flatten(kind):
    path=HERE/kind/(kind+'.glb');scene,binary=parse(path.read_bytes())
    # Mesh positions are pivot-relative. Flatten node transforms to global
    # pivots and remove all parenting; no rig objects enter native templates.
    rigpath=HERE/kind/(kind+'-rig.json');rig=json.loads(rigpath.read_text());pivots={p['name']:p['pivot'] for p in rig['parts']}
    for n in scene['nodes']:n.pop('children',None);n['translation']=[v*geo.METRES for v in pivots[n['name']]]
    scene['scenes'][0]['nodes']=list(range(len(scene['nodes'])));scene['asset']['generator']='BrickToads closed source-informed course props'
    blob=write_glb(path,scene,binary)
    rig['joints']=[]
    for p in rig['parts']:p['parent']=None
    rig['coordinateSystem']='Y-up, forward -Z. Flat closed segments. Model origin is authored reference pivot; see pack fit metadata.'
    rig['inferred3D']=['Source supplies only 2D contours, palette and identity; all depth, rear surfaces, mechanical thickness and rest pivots are authored.','System-only markers and environmental composition are explicitly identified in source catalog.','Cosmetic only. Existing physical colliders and gameplay actions remain external.']
    rigpath.write_text(json.dumps(rig,indent=2)+'\n');return blob,rig
def source_records():
    path=HERE/'source/source-catalog.json'
    if not path.exists():return {}
    catalog=json.loads(path.read_text())
    records=catalog.get('families',catalog.get('kinds',catalog.get('records',catalog.get('elements',catalog.get('props',[])))))
    if isinstance(records,dict):return records
    return {r.get('runtimeKind',r.get('kind',r.get('family'))):r for r in records}
def fit_metadata(kind,bounds):
    size=[round(b-a,6) for a,b in zip(*bounds)]
    result={'referenceSize':size,'referenceSizeStuds':size,'referenceCenterStuds':[0,0,0],'fitMode':'Stretch','authoredUp':[0,1,0],'forward':[0,0,-1],'fitAxis':'Y','visualPivotStuds':[0,0,0]}
    if kind in ('BoardingPad','IceBlock','Lift','MovingIcePlatform','TowerPlatform','Water','Telegraph','Warning','Whirlpool'):
        result.update(deckTop=max(0,bounds[1][1]),surfaceNormal=[0,1,0])
    if kind in ('Mine','AirMine','Bomb','Spike','Icicle','RotatingSpike','Log'):
        result.update(fitMode='TileZ',tileReferenceSizeStuds=size,maxStretchRatio=1.45,tileGapStuds=.25)
    if kind=='Rope':result.update(fitMode='Rope',fitAxis='Z',radialAxes=['X','Y'])
    if kind=='Tower':result.update(fitMode='Tower',fitAxis='Y',colliderLengthAxis='X',radialAxes=['X','Z'],authoredDescription='Hollow purple/magenta cylindrical masonry with staggered brick courses; Y is the long axis.')
    if kind=='RotatingSpike':result['spinAxis']=[0,1,0]
    if kind in ('Gear','Buzzball','Fan'):result['spinAxis']=[0,0,1]
    return result
def pack(entries,models):
    scene={'asset':{'version':'2.0','generator':'BrickToads source-informed course props','extras':{'metresPerStud':.28,'sourcePin':PIN}},'scene':0,'scenes':[{'name':'CanonicalCourseProps','nodes':[]}],
           'nodes':[],'meshes':[],'accessors':[],'bufferViews':[],'images':[],'textures':[],'materials':[],'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]}
    data=bytearray();contract={}
    for kind,entry in entries.items():
        item,binary=parse((HERE/kind/(kind+'.glb')).read_bytes());rig=json.loads((HERE/kind/(kind+'-rig.json')).read_text())
        while len(data)%4:data.append(0)
        offset=len(data);data.extend(binary)
        vb=len(scene['bufferViews']);ab=len(scene['accessors']);mb=len(scene['meshes']);nb=len(scene['nodes']);ib=len(scene['images']);tb=len(scene['textures']);matb=len(scene['materials'])
        for v in item['bufferViews']:v['byteOffset']=v.get('byteOffset',0)+offset
        for a in item['accessors']:a['bufferView']+=vb
        for im in item['images']:im['bufferView']+=vb;im['name']=kind+'__'+im['name']
        for t in item['textures']:t['source']+=ib;t['sampler']=0
        for m in item['materials']:m['name']=kind+'__'+m['name'];m['pbrMetallicRoughness']['baseColorTexture']['index']+=tb
        for m in item['meshes']:
            m['name']=kind+'__'+m['name']
            for p in m['primitives']:p['attributes']={k:v+ab for k,v in p['attributes'].items()};p['indices']+=ab;p['material']+=matb
        for n in item['nodes']:n['name']=kind+'__'+n['name'];n['mesh']+=mb
        for key in ('nodes','meshes','accessors','bufferViews','images','textures','materials'):scene[key].extend(item[key])
        scene['scenes'][0]['nodes'].extend(i+nb for i in range(len(item['nodes'])))
        motion={}
        for n in models[kind].parts:
            motionkind='SpinY' if kind=='RotatingSpike' or (kind=='Whirlpool' and n=='Spiral') else ('SpinZ' if kind in ('Gear','Buzzball') or (kind=='Fan' and n=='Rotor') else ('Pulse' if kind=='Gas' or (kind in ('Telegraph','Warning') and n!='Body') or (kind=='ElectricTrap' and n=='Arc') else None))
            if motionkind:motion[n]={'kind':motionkind,'pivot':models[kind].pivots[n],'speed':2.0 if kind=='Fan' else .7 if kind=='Gas' else 1.2 if kind=='Whirlpool' else 1.0}
        contract[kind]={**fit_metadata(kind,entry['bounds']),'globalBoundsStuds':entry['bounds'],'motionParts':motion,
            'sourceStatus':entry['sourceStatus'],'parts':[{'importedName':kind+'__'+p['name'],'name':p['name'],'role':models[kind].roles[p['name']],
            'globalPivotStuds':p['pivot'],'baseTransparency':.30 if kind=='Gas' and p['name']!='Contours' else 0,'globalBoundsStuds':p['globalBounds'],'sizeStuds':[round(b-a,7) for a,b in zip(*p['globalBounds'])],
            'centerStuds':[round((a+b)/2,7) for a,b in zip(*p['globalBounds'])],'triangles':p['triangles']} for p in rig['parts']]}
    path=HERE/'canonical-course-props.glb';blob=write_glb(path,scene,data)
    result={'schema':1,'glb':path.name,'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),'familyCount':len(entries),'meshCount':len(scene['meshes']),'triangles':sum(e['triangles'] for e in entries.values()),'sourcePin':PIN,'meshNames':[m['name'] for m in scene['meshes']],'templates':contract,
        'contract':{'folder':'ServerStorage.BrickToadsPropTemplates','modelMetadata':{'AppearanceProfile':'CanonicalCourseProp','CourseKind':'<kind>','SourcePin':PIN},
        'axis':'Y-up; forward -Z. Tower long axis Y; Rope long axis Z. Every GLB node is a scene root; no joints or attachments.',
        'reconstruction':'Match exact Kind__Part names. Recenter each native MeshPart with sizeStuds and centerStuds, applying observed native importer Y180 conversion as in existing vehicle protocol. Preserve actual MeshId/TextureID/SurfaceAppearance and raw imported MeshSize as InitialSize. Rotation uses globalPivotStuds, never inferred mesh centre.',
        'physics':'Anchored true; CanCollide/CanTouch/CanQuery false; Massless true. Retain original gameplay collider dimensions, positions and actions.',
        'fit':'Bound all visuals. Mine/Bomb/AirMine/Spike/Icicle runs use repeated uniformly scaled templates when collider aspect ratio exceeds maxStretchRatio; avoid stretching a round mine into an elongated strip. Decks fit footprint and reference top; Tower and Rope fit declared length axis. Roles are cosmetic only.'},'nativeImportStatus':'PENDING'}
    (HERE/'canonical-course-props-pack.json').write_text(json.dumps(result,indent=2)+'\n');return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-preview',action='store_true');args=parser.parse_args()
    records=source_records();models={};entries={};reports={}
    assert set(records)==set(KINDS),'All28 source records must be complete before a release build'
    source_hash=hashlib.sha256((HERE/'source/source-catalog.json').read_bytes()).hexdigest()
    for kind in KINDS:
        o=BUILDERS[kind]();geo.EXPECTED[kind]=list(o.parts)
        if not hasattr(o,'roles'):o.roles={n:'Shell' for n in o.parts}
        record=records.get(kind,{'kind':kind,'status':'source-catalog-pending'})
        # Match the complete visible envelope to a stable centred rest frame.
        envelope=geo.bounds([v for m in o.parts.values() for v in m.vertices]);centre=tuple((a+b)/2 for a,b in zip(*envelope))
        for m in o.parts.values():m.vertices=[geo.sub(v,centre) for v in m.vertices]
        o.pivots={n:geo.sub(v,centre) for n,v in o.pivots.items()}
        # Preserve verified cast Buzzball. Source objects use only the proved
        # representative palette; environmental/system adaptations retain
        # authored palette roles documented in their source records.
        palette=record.get('rgbColors',[])
        if palette and kind!='Buzzball':
            palette=[tuple(c) for c in palette]
            for m in o.parts.values():m.colors=[min(palette,key=lambda d:sum((a-b)**2 for a,b in zip(c,d))) for c in m.colors]
        o.sourceTrace=record;o.sourcePalette={'scope':'Source-informed palette roles; authored3D surface atlas. Source records distinguish exact object, background and system adaptation.',
            'sourceRgbColors':record.get('rgbColors',[]),'sourceCatalogSha256':source_hash,'mapping':'Authored material role RGB is mapped to nearest evidenced representative source RGB by squared RGB distance; Buzzball reuses the previously verified cast palette. The original palette atlas contains color swatches only; no source sprite image is embedded.'}
        o.reference=['assets/props/canonical-course/source/source-catalog.json','https://github.com/feos-tas/DisAssemble/tree/'+PIN+'/Battletoads']
        o.facts=[str(record.get('visualCues',record.get('appearanceCues',record.get('cues','Per-kind source mapping and limits are recorded in source catalog.'))))]
        report=geo.validate(o);assert len(o.parts)<=8,(kind,'too many parts');assert all(len(m.faces)<=8000 for m in o.parts.values()),(kind,'mesh triangle limit')
        volumes=[]
        for name,m in o.parts.items():
            for start,count,faces in m.components:
                ids=set(range(start,start+count));triangles=[f for f in m.faces if f[0] in ids]
                assert len(triangles)==faces,(kind,name,'component face count')
                volume=sum(geo.dot(m.vertices[a],geo.cross(m.vertices[b],m.vertices[c])) for a,b,c in triangles)/6
                assert volume>1e-10,(kind,name,'inward or zero volume',volume)
                volumes.append(volume)
        report.update(positiveVolumes=True,minimumComponentVolumeStuds3=min(volumes),maximumPartTriangles=max(len(m.faces) for m in o.parts.values()))
        entry=geo.export(o,HERE/kind);blob,rig=flatten(kind);entry.update(bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest(),sourceStatus=record.get('status',record.get('classification','source-informed-authored3d')))
        for p in rig['parts']:p['role']=o.roles[p['name']]
        (HERE/kind/(kind+'-rig.json')).write_text(json.dumps(rig,indent=2)+'\n')
        models[kind]=o;entries[kind]=entry;reports[kind]=report
        if not args.no_preview:render.render(o,HERE/kind/'turntable.png',size=(900,420),azimuths=(0,40,90))
        print(kind,entry['triangles'],entry['bytes'],flush=True)
    result=pack(entries,models)
    manifest={'schema':1,'sourcePin':PIN,'sourceCatalogSha256':source_hash,'scope':'28 closed source-informed authored3D course prop templates. System markers explicitly authored. No source sprites embedded.','families':entries}
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    if not args.no_preview:
        from PIL import Image,ImageDraw
        sheet=Image.new('RGB',(1800,7*450),(25,32,39));draw=ImageDraw.Draw(sheet)
        for i,kind in enumerate(KINDS):
            tile=Image.open(HERE/kind/'turntable.png').resize((450,210));x=(i%4)*450;y=(i//4)*450
            # A large oblique view beneath the compact three-view strip.
            p=HERE/kind/'oblique.png';render.render(models[kind],p,size=(450,210),azimuths=(40,));sheet.paste(tile,(x,y));sheet.paste(Image.open(p),(x,y+210));draw.text((x+12,y+425),kind+' | closed authored3D',fill='white')
        sheet.save(HERE/'course-props-contact-sheet.png')
    (HERE/'validation.json').write_text(json.dumps({'schema':1,'status':'PASS','sourcePin':PIN,'families':reports,'combined':{k:result[k] for k in ('sha256','bytes','familyCount','meshCount','triangles')},'softwarePreview':'course-props-contact-sheet.png','nativeImport':'PENDING','limits':{'meshTrianglesMaximum':8000,'partsPerKindMaximum':8,'combinedBytesMaximum':20000000}},indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('sha256','bytes','familyCount','meshCount','triangles')},indent=2))
if __name__=='__main__':main()
