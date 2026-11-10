"""Versioned owner-directed green brawler,15cosmetic nodes/onePBRmaterial.

The owner's detailed2026-11-09 art brief supersedes the earlier minimal-palette
study. This file never overwrites its GLBs. Neutral rig and preview pose differ.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import random
import struct
import zlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
BRIEF=ROOT/'docs/superpowers/specs/2026-11-09-green-brawler-art-direction.md'
METRES=.28
spec=importlib.util.spec_from_file_location('neutral_geometry',HERE/'build_canonical_hero.py')
G=importlib.util.module_from_spec(spec);spec.loader.exec_module(G)
add,sub,mul,dot,cross,unit,length=G.add,G.sub,G.mul,G.dot,G.cross,G.unit,G.length


def linear(rgb):return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1.,)
def mix(a,b,t):return tuple(x*(1-t)+y*t for x,y in zip(a,b))
def clamp(v,a=0,b=1):return min(b,max(a,v))
def smooth(a,b,v):
    t=clamp((v-a)/(b-a));return t*t*(3-2*t)
FOREST=linear((.025,.17,.055));GRASS=linear((.13,.43,.09));LIME=linear((.63,.78,.16))
RED=linear((.65,.025,.045));CUFF=linear((.12,.14,.15));SILVER=linear((.65,.70,.72))
BLACK=linear((.008,.012,.012));GLINT=linear((.85,.93,.94));CREASE=linear((.025,.075,.025))
ROLES={'roughSkin':0,'smoothSkin':1,'cloth':2,'darkMetal':3,'silver':4,'lens':5,'frame':6,'glint':7}
PIVOTS={'LowerTorso':(0,-.24,.06),'UpperTorso':(0,.12,.05),'Head':(0,1.52,-.04),
    'LeftUpperArm':(-1.55,1.34,0),'RightUpperArm':(1.55,1.34,0),
    'LeftLowerArm':(-2.07,.04,.02),'RightLowerArm':(2.07,.04,.02),
    'LeftHand':(-2.02,-.93,-.14),'RightHand':(2.02,-.93,-.14),
    'LeftUpperLeg':(-.63,-.42,.05),'RightUpperLeg':(.63,-.42,.05),
    'LeftLowerLeg':(-.90,-1.60,-.02),'RightLowerLeg':(.90,-1.60,-.02),
    'LeftFoot':(-.82,-2.65,.15),'RightFoot':(.82,-2.65,.15)}
PARENTS=G.HIERARCHY.copy();JOINTS=G.JOINT_NAMES.copy()


def skin(name,p):
    x,y,z=p
    front=smooth(-.14,-.55,z) # inverted range is intentional: negativeZ faces front.
    if name=='UpperTorso':
        light=front*(1-smooth(1.05,1.53,abs(x)))
        base=mix(GRASS,LIME,light)
        if z>.05:base=mix(base,FOREST,.75)
    elif name=='LowerTorso':base=mix(GRASS,LIME,front*(1-smooth(.42,.85,abs(x))))
    elif name=='Head':
        light=front*(1-smooth(2.04,2.22,y));base=mix(FOREST,LIME,light)
    else:
        side=-1 if name.startswith('Left') else 1
        outward=smooth(.0,.35,side*(x-PIVOTS[name][0]))
        base=mix(GRASS,FOREST,.55*outward+.15*(z>.08))
    patch=(math.sin(x*13.7+y*8.3+z*17.9)*math.sin(x*7.2-y*11.4+z*5.8))
    is_smooth=front>.75 and name in ('UpperTorso','LowerTorso','Head')
    # Chest/belly retain a smooth amphibian surface; coarse pigment triangles
    # must not impersonate the bump/normal detail supplied by the atlas.
    blemish=.975+.025*(patch+1)/2 if is_smooth else (.73 if patch>.72 and name!='Head' else .94+.06*(patch+1)/2)
    return tuple(v*blemish for v in base[:3])+(1.,),1 if front>.75 and name in ('UpperTorso','LowerTorso','Head') else 0


class Part(G.Mesh):
    def __init__(self,name):
        super().__init__(name);self.roles=[];self.uv=[];self.role=0;self.tint=None;self._normals=None;self.analytic={}
    def material(self,role,tint=None):self.role=ROLES[role] if isinstance(role,str) else role;self.tint=tint
    def append(self,vertices,faces,color=None):
        start=len(self.vertices);self.vertices.extend(vertices)
        self.faces.extend(tuple(i+start for i in f) for f in faces)
        for p in vertices:
            c,r=skin(self.name,p) if self.tint is None and self.role==0 else (self.tint or color or GRASS,self.role)
            self.colors.append(c);self.roles.append(r)
            rel=sub(p,PIVOTS[self.name]);u=(math.atan2(rel[2],rel[0])/math.tau+.5)*3;v=rel[1]*1.7
            self.uv.append(((r%4+.06+.88*(u%1))/4,(r//4+.06+.88*(v%1))/2))
        self._normals=None
    def normals(self):
        if self._normals is None:
            self._normals=super().normals()
            for i,n in self.analytic.items():self._normals[i]=n
        return self._normals


def loft(m,rows,radial=24,steps=3,power=1):G.sweep(m,rows,GRASS,radial,steps,power)
def orb(m,c,r,radial=14,rings=7):G.ellipsoid(m,c,r,GRASS,radial,rings)
def smin(a,b,k=.08):
    h=max(k-abs(a-b),0)/k;return min(a,b)-h*h*k*.25
def ell(p,c,r):
    q=sub(p,c);a=length(tuple(v/d for v,d in zip(q,r)));b=length(tuple(v/(d*d) for v,d in zip(q,r)))
    return a*(a-1)/b if b>1e-9 else -min(r)
def capsule(p,a,b,r):
    d=sub(b,a);t=clamp(dot(sub(p,a),d)/dot(d,d));return length(sub(p,add(a,mul(d,t))))-r


def torso_field(p):
    x,y,z=p
    yy=clamp(y,.02,1.72)
    controls=[(.02,.61,.48),(.45,.78,.57),(.90,1.20,.65),(1.35,1.47,.60),(1.72,.70,.32)]
    for a,b in zip(controls,controls[1:]):
        if a[0]<=yy<=b[0]:
            t=(yy-a[0])/(b[0]-a[0]);rx=a[1]*(1-t)+b[1]*t;rz=a[2]*(1-t)+b[2]*t;break
    dside=(math.hypot(x/rx,(z-.04)/rz)-1)*min(rx,rz);dy=max(.02-y,y-1.72)
    d=min(max(dside,dy),0)+math.hypot(max(dside,0),max(dy,0))
    for side in (-1,1):
        # Broad flattened pectorals connect deeply to the thorax. They are
        # sculpted muscle masses, not independent oval volumes in front of it.
        d=smin(d,ell(p,(side*.73,1.20,-.34),(.90,.45,.53)),.17)
        d=smin(d,capsule(p,(side*.45,1.73,.10),(side*1.28,1.51,.12),.35),.12)
        d=smin(d,ell(p,(side*.64,.39,-.29),(.26,.45,.31)),.12)
        for yy in (.55,.13):d=smin(d,ell(p,(side*.29,yy,-.45),(.30,.235,.20)),.09)
    # Actual shallow muscle grooves, rather than an armour texture.
    d=max(d,-capsule(p,(0,.82,-.848),(0,1.52,-.848),.028))
    return d


def pelvis_field(p):
    d=smin(ell(p,(0,-.35,.06),(.82,.44,.47)),ell(p,(0,.08,.04),(.61,.27,.36)),.18)
    for side in (-1,1):d=smin(d,ell(p,(side*.25,-.20,-.38),(.28,.24,.20)),.12)
    return d


def implicit(m,field,bounds,step=.12):
    axes=[]
    for lo,hi in bounds:
        n=math.ceil((hi-lo)/step);axes.append([lo+(hi-lo)*i/n for i in range(n+1)])
    xs,ys,zs=axes;nx,ny,nz=map(len,axes)
    points=[(x,y,z) for z in zs for y in ys for x in xs];values=[field(p) for p in points]
    vertices=[];faces=[];edges={}
    def vertex(a,b):
        key=tuple(sorted((a,b)))
        if key not in edges:
            t=values[a]/(values[a]-values[b]);edges[key]=len(vertices);vertices.append(add(points[a],mul(sub(points[b],points[a]),t)))
        return edges[key]
    def face(ids,out):
        a,b,c=(vertices[i] for i in ids);n=cross(sub(b,a),sub(c,a))
        if length(n)<1e-10:return
        faces.append(ids if dot(n,out)>0 else (ids[0],ids[2],ids[1]))
    tets=((0,5,1,6),(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6))
    for k in range(nz-1):
        for j in range(ny-1):
            for i in range(nx-1):
                a=(k*ny+j)*nx+i;cube=(a,a+1,a+nx+1,a+nx,a+nx*ny,a+nx*ny+1,a+nx*ny+nx+1,a+nx*ny+nx)
                if all(values[v]>0 for v in cube) or all(values[v]<0 for v in cube):continue
                for tet in tets:
                    inside=[cube[v] for v in tet if values[cube[v]]<0];outside=[cube[v] for v in tet if values[cube[v]]>=0]
                    if not inside or not outside:continue
                    cin=mul(tuple(sum(points[v][c] for v in inside) for c in range(3)),1/len(inside))
                    cout=mul(tuple(sum(points[v][c] for v in outside) for c in range(3)),1/len(outside));direction=sub(cout,cin)
                    if len(inside)==1:face(tuple(vertex(inside[0],b) for b in outside),direction)
                    elif len(inside)==3:face(tuple(vertex(a,outside[0]) for a in inside),direction)
                    else:
                        a,b=inside;c,d=outside;p,q,r,s=vertex(a,c),vertex(a,d),vertex(b,c),vertex(b,d)
                        face((p,q,r),direction);face((q,s,r),direction)
    used=sorted({v for f in faces for v in f});remap={old:new for new,old in enumerate(used)}
    start=len(m.vertices)
    m.append([vertices[i] for i in used],[tuple(remap[i] for i in f) for f in faces])
    # Analytic field gradients avoid asymmetric marching-tetrahedron tessellation
    # changing the intended smooth muscle shading.
    for j,i in enumerate(used):
        p=vertices[i];eps=.0001;gradient=[]
        for axis in range(3):
            a=list(p);b=list(p);a[axis]+=eps;b[axis]-=eps
            gradient.append((field(a)-field(b))/(2*eps))
        m.analytic[start+j]=unit(gradient)


def ring(m,c,axis,rx,rz,height,thickness=.055,segments=24,wave=0):
    axis=unit(axis);right=unit(cross(axis,(0,0,1)));back=cross(right,axis)
    vertices=[]
    for inner,level in ((False,-1),(False,1),(True,-1),(True,1)):
        for j in range(segments):
            a=j/segments*math.tau;wr=wave*math.sin(a*7+level*.8)
            x=(rx-(thickness if inner else 0)+wr)*math.cos(a);z=(rz-(thickness if inner else 0)+wr)*math.sin(a)
            vertices.append(add(c,add(mul(axis,level*height/2),add(mul(right,x),mul(back,z)))))
    faces=[]
    for j in range(segments):
        k=(j+1)%segments
        for a,b,c_,d in ((j,k,segments+j,segments+k),(2*segments+k,2*segments+j,3*segments+k,3*segments+j),
                         (j,2*segments+j,k,2*segments+k),(segments+k,3*segments+k,segments+j,3*segments+j)):
            faces.extend(((a,c_,b),(b,c_,d)))
    m.append(vertices,faces)


def ribbon(m,points,width=.18,thickness=.035):
    vertices=[]
    for i,p in enumerate(points):
        tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(i-1,0)]));right=unit(cross(tangent,(0,0,1)));normal=cross(right,tangent)
        w=width*(1-.20*i/(len(points)-1))
        for a,b in ((-1,-1),(1,-1),(-1,1),(1,1)):vertices.append(add(p,add(mul(right,a*w/2),mul(normal,b*thickness/2))))
    faces=[]
    for i in range(len(points)-1):
        a=i*4;b=(i+1)*4
        for p,q,r,s in ((a,a+1,b,b+1),(a+3,a+2,b+3,b+2),(a+2,a,b+2,b),(a+1,a+3,b+1,b+3)):
            faces.extend(((p,r,q),(q,r,s)))
    faces.extend(((0,1,2),(1,3,2)));a=(len(points)-1)*4;faces.extend(((a,a+2,a+1),(a+1,a+2,a+3)))
    m.append(vertices,faces)


def cone(m,base,axis,radius,height,sides=12):
    axis=unit(axis);ref=(0,1,0) if abs(axis[1])<.9 else (0,0,1);right=unit(cross(axis,ref));other=cross(right,axis)
    vertices=[add(base,add(mul(right,math.cos(i/sides*math.tau)*radius),mul(other,math.sin(i/sides*math.tau)*radius))) for i in range(sides)]
    vertices.extend((base,add(base,mul(axis,height))))
    faces=[]
    for i in range(sides):
        j=(i+1)%sides;faces.extend(((i,j,sides+1),(sides,j,i)))
    m.append(vertices,faces)


def prism(m,polygon,depth=.04):
    n=len(polygon);vertices=[(x,y,z+d) for d in (0,depth) for x,y,z in polygon];faces=[]
    for i in range(1,n-1):faces.extend(((0,i+1,i),(n,n+i,n+i+1)))
    for i in range(n):
        j=(i+1)%n;faces.extend(((i,j,n+i),(j,n+j,n+i)))
    m.append(vertices,faces)


def warts(m,controls,side,count=10,size=.06):
    for i in range(count):
        t=(i+.5)/count*(len(controls)-1);j=min(int(t),len(controls)-2);f=t-j
        row=tuple(a*(1-f)+b*f for a,b in zip(controls[j],controls[j+1]));axis=unit(sub(controls[j+1][:3],controls[j][:3]))
        right=unit(cross(axis,(0,0,1)));other=cross(right,axis);angle=(i*2.3999632)%(math.tau)
        radial=add(mul(right,math.cos(angle)),mul(other,math.sin(angle)))
        if side*radial[0]<0:radial=mul(radial,-1)
        point=add(row[:3],add(mul(right,math.cos(angle)*row[3]*.97*(1 if side*dot(right,radial)>=0 else -1)),mul(other,math.sin(angle)*row[4]*.97)))
        # Project to the actual outward half of the swept surface.
        outward=unit((side*abs(radial[0]),radial[1],radial[2]));point=add(row[:3],mul(outward,min(row[3],row[4])*.94))
        r=size*(.7+.3*math.sin(i*5.1)**2);orb(m,point,(r,r*.65,r),10,5)


def build():
    parts={name:Part(name) for name in PIVOTS}
    implicit(parts['UpperTorso'],torso_field,((-1.78,1.78),(-.25,2.14),(-1.18,.88)),.12)
    torso=parts['UpperTorso']
    for i in range(24):
        x=math.sin(i*2.4)*1.12;y=.35+(i%9)/9*1.35;lo,hi=0,.9
        if torso_field((x,y,0))>=0:continue
        for _ in range(14):
            mid=(lo+hi)/2
            if torso_field((x,y,mid))<0:lo=mid
            else:hi=mid
        orb(torso,(x,y,(lo+hi)/2-.015),(.055,.045,.07),10,5)
    lower=parts['LowerTorso'];implicit(lower,pelvis_field,((-.94,.94),(-.88,.45),(-.76,.65)),.10)
    head=parts['Head'];loft(head,[(0,1.45,-.08,.34,.26),(0,1.63,-.18,.64,.43),(0,1.83,-.24,.82,.59),
        (0,2.02,-.19,.88,.62),(0,2.20,-.02,.81,.47),(0,2.40,.06,.66,.36),(0,2.53,.07,.42,.25),(0,2.60,.06,.12,.10)],28,3,.78)
    # Low, heavy jaw and asymmetric closed smirk.
    orb(head,(0,1.72,-.43),(.73,.30,.43),22,10)
    head.material(0,CREASE);loft(head,[(-.68,1.82,-.66,.022,.022),(-.36,1.76,-.81,.026,.026),(0,1.77,-.87,.027,.027),
        (.36,1.83,-.82,.027,.027),(.69,1.94,-.67,.020,.020)],10,3)
    head.material(0)
    for side in (-1,1):
        loft(head,[(side*.10,2.38,-.43,.10,.08),(side*.43,2.49,-.38,.13,.10),(side*.73,2.40,-.20,.10,.07)],16,3)
        for i in range(5):orb(head,(side*(.25+i*.11),2.43+math.sin(i)*.08,-.04+i*.03),(.065,.045,.065),10,5)
        head.material(0,CREASE);orb(head,(side*.24,2.04,-.791),(.065,.032,.026),12,6);head.material(0)
        # Narrow angular lens, thick physical frame and temple arm.
        polygon=[(side*.08,2.23,-.80),(side*.79,2.34,-.56),(side*.76,2.08,-.58),(side*.12,2.02,-.79)]
        if side==-1:polygon.reverse()
        head.material('frame',BLACK);prism(head,[(x*1.045,(y-2.18)*1.10+2.18,z-.232) for x,y,z in polygon],.065)
        head.material('lens',BLACK);prism(head,[(x,y,z-.25) for x,y,z in polygon],.025)
        head.material('frame',BLACK);loft(head,[(side*.75,2.23,-.79,.044,.042),(side*.86,2.26,-.12,.044,.042),(side*.83,2.22,.21,.04,.04)],10,2)
        head.material('glint',GLINT);prism(head,[(side*.27,2.226,-1.009),(side*.48,2.263,-.942),(side*.45,2.228,-.947),(side*.27,2.201,-1.012)],.005)
        head.material(0)
    head.material('frame',BLACK);loft(head,[(-.12,2.18,-1.06,.04,.035),(0,2.16,-1.09,.04,.035),(.12,2.18,-1.06,.04,.035)],10,2);head.material(0)
    for side,name in ((-1,'Left'),(1,'Right')):
        upper=parts[name+'UpperArm'];rows=[(side*1.43,1.50,.03,.55,.50),(side*1.67,1.16,.03,.73,.61),
            (side*1.91,.69,-.01,.64,.55),(side*2.06,.28,.02,.50,.43),(side*2.07,.04,.02,.41,.36)]
        loft(upper,rows,28,3);orb(upper,PIVOTS[name+'UpperArm'],(.70,.73,.60),22,10);warts(upper,rows,side,14,.065)
        # Cloth wraps above the elbow, following the arm axis.
        axis=unit(sub(PIVOTS[name+'UpperArm'],PIVOTS[name+'LowerArm']));band=add(PIVOTS[name+'LowerArm'],mul(axis,.28))
        upper.material('cloth',RED);ring(upper,band,axis,.525,.455,.26,.052,28,.015)
        outer=add(band,(side*.48,0,.06))
        ribbon(upper,[outer,add(outer,(side*.25,-.09,.10)),add(outer,(side*.34,-.40,.17)),add(outer,(side*.20,-.66,.22))],.21)
        ribbon(upper,[add(outer,(0,.04,.10)),add(outer,(side*.36,-.06,.24)),add(outer,(side*.43,-.40,.30))],.16)
        upper.material(0)
        arm=parts[name+'LowerArm'];rows=[(side*2.07,.08,.02,.42,.37),(side*2.13,-.22,-.04,.57,.48),(side*2.08,-.58,-.10,.52,.42),(side*2.02,-.96,-.14,.31,.29)]
        loft(arm,rows,26,3);orb(arm,PIVOTS[name+'LowerArm'],(.42,.41,.37),18,8);warts(arm,rows,side,12,.052)
        hand=parts[name+'Hand'];orb(hand,(side*2.02,-1.25,-.15),(.55,.44,.37),22,10);orb(hand,PIVOTS[name+'Hand'],(.33,.29,.29),16,8)
        for finger in (-1,0,1):
            x=side*2.02+finger*.31
            loft(hand,[(x,-1.17,-.40,.19,.19),(x,-1.48,-.47,.205,.19),(x,-1.69,-.32,.20,.18),(x,-1.53,-.10,.17,.16)],16,3)
            hand.material(0,CREASE);loft(hand,[(x-.105,-1.47,-.565,.012,.012),(x,-1.50,-.585,.013,.013),(x+.105,-1.47,-.565,.012,.012)],8,2);hand.material(0)
        loft(hand,[(side*1.59,-1.07,-.13,.23,.21),(side*1.44,-1.26,-.32,.24,.22),(side*1.59,-1.47,-.47,.22,.20),(side*1.82,-1.45,-.49,.18,.17)],16,3)
        thigh=parts[name+'UpperLeg'];rows=[(side*.63,-.41,.06,.49,.50),(side*.78,-.76,.02,.61,.58),(side*.90,-1.13,-.03,.51,.47),(side*.90,-1.59,-.02,.32,.33)]
        loft(thigh,rows,28,3);orb(thigh,PIVOTS[name+'UpperLeg'],(.47,.40,.45),18,8);warts(thigh,rows,side,15,.060)
        calf=parts[name+'LowerLeg'];rows=[(side*.90,-1.56,-.02,.32,.33),(side*.90,-1.92,.10,.46,.42),(side*.86,-2.24,.17,.35,.30),(side*.82,-2.66,.15,.21,.21)]
        loft(calf,rows,26,3);orb(calf,PIVOTS[name+'LowerLeg'],(.33,.32,.34),18,8);warts(calf,rows,side,9,.045)
        knee=PIVOTS[name+'LowerLeg'];calf.material('darkMetal',CUFF);ring(calf,knee,(0,1,0),.43,.42,.60,.07,28,.006)
        calf.material('silver',SILVER)
        for level in (-.29,.29):ring(calf,add(knee,(0,level,0)),(0,1,0),.455,.445,.065,.07,28,.004)
        for angle in (-2.3,-1.35,-.40,.55,1.5,2.45):
            n=(math.cos(angle),0,math.sin(angle));orb(calf,add(knee,(n[0]*.445,0,n[2]*.435)),(.105,.105,.105),12,6)
        for angle in (-2.40,-1.57,-.74):
            n=(math.cos(angle),0,math.sin(angle));cone(calf,add(knee,(n[0]*.44,0,n[2]*.43)),n,.12,.24,12)
        calf.material(0)
        foot=parts[name+'Foot'];orb(foot,PIVOTS[name+'Foot'],(.24,.24,.24),16,8)
        loft(foot,[(side*.82,-2.79,.34,.15,.12),(side*.84,-2.82,.02,.30,.18),(side*.87,-2.87,-.44,.43,.13),(side*.91,-2.89,-.98,.48,.10),(side*.92,-2.88,-1.22,.32,.06)],22,3)
        for toe in (-1,0,1):
            x=side*.91+toe*.31;loft(foot,[(x,-2.86,-.78,.18,.12),(x+side*.04,-2.89,-1.11,.19,.10),(x+side*.07,-2.88,-1.43+abs(toe)*.10,.12,.06)],14,3)
    return parts


def orient(mesh):
    edge_faces={}
    for i,f in enumerate(mesh.faces):
        for a,b in zip(f,(f[1],f[2],f[0])):edge_faces.setdefault(tuple(sorted((a,b))),[]).append((i,a,b))
    assert all(len(items)==2 for items in edge_faces.values()),(mesh.name,'nonclosed geometry')
    neighbors=[[] for _ in mesh.faces]
    for items in edge_faces.values():
        (i,a,b),(j,c,d)=items;same=(a==c and b==d)
        neighbors[i].append((j,same));neighbors[j].append((i,same))
    orientation={};components=[]
    for start in range(len(mesh.faces)):
        if start in orientation:continue
        orientation[start]=False;stack=[start];group=[]
        while stack:
            i=stack.pop();group.append(i)
            for j,same in neighbors[i]:
                flip=orientation[i]^same
                if j in orientation:assert orientation[j]==flip,(mesh.name,'nonorientable surface')
                else:orientation[j]=flip;stack.append(j)
        components.append(group)
    for i,flip in orientation.items():
        if flip:a,b,c=mesh.faces[i];mesh.faces[i]=(a,c,b)
    for group in components:
        volume=sum(dot(mesh.vertices[a],cross(mesh.vertices[b],mesh.vertices[c]))/6 for i in group for a,b,c in [mesh.faces[i]])
        if volume<0:
            for i in group:a,b,c=mesh.faces[i];mesh.faces[i]=(a,c,b)
    mesh._normals=None
    return len(components)


def noise(x,y):
    return (math.sin(x*12.9898+y*78.233)*43758.5453)%1


def atlas():
    size=256;tile=64
    albedo=bytearray(size*size*4);orm=bytearray(size*size*4);normal=bytearray(size*size*4);emissive=bytearray(size*size*4)
    role_settings=[(.66,0),(.50,0),(.91,0),(.48,.75),(.27,1),(.10,.05),(.34,.30),(.10,0)]
    for y in range(size):
        for x in range(size):
            role=(y//(tile*2))*4+x//tile;u=x%tile;v=y%(tile*2);n=noise(u,v)
            rough,metal=role_settings[role]
            if role in (0,1):
                grain=(math.sin(u*1.7)*math.sin(v*1.9)+math.sin(u*.63+v*.91))*.25
                shade=.90+.10*n if role==0 else .96+.04*n
                rough=clamp(rough+(n-.5)*(.20 if role==0 else .10),.08,.95)
                dx=math.sin(u*1.7)*.16+math.cos(v*.71+u*.29)*.08;dy=math.sin(v*1.9)*.16
                if role==1:dx*=.35;dy*=.35
                ao=.9+.1*n
            elif role==2:
                weave=(u%4==0 or v%4==0);shade=.86 if weave else .98;rough=.94 if weave else .88
                dx=.12 if u%4==0 else -.04;dy=.12 if v%4==0 else -.04;ao=1
            elif role in (3,4):
                scratch=(u*3+v)%31==0;shade=.72 if scratch else .94+.06*n;rough=clamp(rough+(.22 if scratch else .04*(n-.5)))
                dx=.04 if scratch else 0;dy=0;ao=1
            else:shade=1;dx=dy=0;ao=1
            index=(y*size+x)*4
            albedo[index:index+4]=bytes([int(shade*255)]*3+[255])
            orm[index:index+4]=bytes((int(ao*255),int(rough*255),int(metal*255),255))
            nrm=unit((dx,dy,1));normal[index:index+4]=bytes(int((c*.5+.5)*255) for c in nrm)+bytes([255])
            emissive[index:index+4]=bytes((255,255,255,255) if role==7 else (0,0,0,255))
    def png_bytes(data):
        def chunk(kind,payload):return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
        scan=b''.join(b'\0'+bytes(data[y*size*4:(y+1)*size*4]) for y in range(size))
        return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan,9))+chunk(b'IEND',b'')
    return [png_bytes(data) for data in (albedo,orm,normal,emissive)],{'albedo':albedo,'orm':orm,'normal':normal,'size':size}


def export(parts,images,path):
    data=bytearray();views=[];accessors=[];nodes=[];meshes=[]
    def accessor(values,ctype,kind,minimum=None,maximum=None,target=34962):
        while len(data)%4:data.append(0)
        offset=len(data);flat=[x for row in values for x in row] if isinstance(values[0],(tuple,list)) else values
        data.extend(struct.pack('<'+str(len(flat))+('f' if ctype==5126 else 'H'),*flat))
        view=len(views);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)-offset,'target':target})
        entry={'bufferView':view,'componentType':ctype,'count':len(values),'type':kind}
        if minimum is not None:entry.update(min=minimum,max=maximum)
        accessors.append(entry);return len(accessors)-1
    names=list(parts);lookup={n:i for i,n in enumerate(names)}
    for name,m in parts.items():
        local=[mul(sub(p,PIVOTS[name]),METRES) for p in m.vertices];b=G.bounds(local);normals=m.normals()
        tangents=[]
        for n in normals:
            ref=(0,1,0) if abs(n[1])<.9 else (1,0,0);t=unit(cross(ref,n));tangents.append((*t,1.))
        attrs={'POSITION':accessor(local,5126,'VEC3',b[0],b[1]),'NORMAL':accessor(normals,5126,'VEC3'),
            'TANGENT':accessor(tangents,5126,'VEC4'),'COLOR_0':accessor(m.colors,5126,'VEC4'),'TEXCOORD_0':accessor(m.uv,5126,'VEC2')}
        idx=accessor([v for f in m.faces for v in f],5123,'SCALAR',target=34963)
        meshes.append({'name':name,'primitives':[{'attributes':attrs,'indices':idx,'material':0}]})
        parent=PARENTS[name];translation=sub(PIVOTS[name],PIVOTS[parent]) if parent else PIVOTS[name]
        node={'name':name,'mesh':lookup[name],'translation':mul(translation,METRES)}
        children=[lookup[n] for n,p in PARENTS.items() if p==name]
        if children:node['children']=children
        nodes.append(node)
    gltf_images=[]
    for i,blob in enumerate(images):
        while len(data)%4:data.append(0)
        offset=len(data);data.extend(blob);view=len(views);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(blob)})
        gltf_images.append({'name':('BrawlerAlbedo','BrawlerORM','BrawlerNormal','BrawlerEmissive')[i],'bufferView':view,'mimeType':'image/png'})
    scene={'asset':{'version':'2.0','generator':'BrickToads owner-directed Green Brawler v2',
            'extras':{'metresPerStud':METRES,'artDirection':'owner detailed2026-11-09 brief; not minimal NES palette claim'}},
        'scene':0,'scenes':[{'name':'GreenBrawler','nodes':[lookup['LowerTorso']]}],
        'nodes':nodes,'meshes':meshes,'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(data)}],
        'images':gltf_images,'textures':[{'sampler':0,'source':i} for i in range(4)],
        'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}],
        'materials':[{'name':'BrawlerSharedAtlas','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],
            'baseColorTexture':{'index':0},'metallicFactor':1,'roughnessFactor':1,'metallicRoughnessTexture':{'index':1}},
            'normalTexture':{'index':2,'scale':.55},'occlusionTexture':{'index':1,'strength':.7},
            'emissiveTexture':{'index':3},'emissiveFactor':[.25,.25,.25],'doubleSided':False}]}
    encoded=json.dumps(scene,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);data+=b'\0'*((-len(data))%4)
    total=12+8+len(encoded)+8+len(data)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(data),b'BIN\0')+data)
    return scene


def pose(parts):
    def mm(a,b):return tuple(tuple(sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
    def apply(a,v):return tuple(dot(row,v) for row in a)
    def rotation(x,y,z):
        cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
        return mm(((cz,-sz,0),(sz,cz,0),(0,0,1)),mm(((cy,0,sy),(0,1,0),(-sy,0,cy)),((1,0,0),(0,cx,-sx),(0,sx,cx))))
    angles={'LowerTorso':(0,-.13,0),'UpperTorso':(0,-.08,0),'Head':(.08,-.22,0),
        'LeftUpperArm':(.20,0,.15),'LeftLowerArm':(.85,0,1.0),
        'RightUpperArm':(.24,0,.35),'RightLowerArm':(.10,0,.80),
        'LeftUpperLeg':(.10,0,-.12),'RightUpperLeg':(.10,0,.12),
        'LeftLowerLeg':(-.20,0,0),'RightLowerLeg':(-.20,0,0)}
    transforms={}
    def transform(name):
        if name in transforms:return transforms[name]
        parent=PARENTS[name];local=rotation(*angles.get(name,(0,0,0)))
        if not parent:answer=(PIVOTS[name],local)
        else:
            p,r=transform(parent);answer=(add(p,apply(r,sub(PIVOTS[name],PIVOTS[parent]))),mm(r,local))
        transforms[name]=answer;return answer
    out={}
    for name,m in parts.items():
        p,r=transform(name);q=Part(name);q.vertices=[add(p,apply(r,sub(v,PIVOTS[name]))) for v in m.vertices]
        q.faces=list(m.faces);q.colors=list(m.colors);q.roles=list(m.roles);q.uv=list(m.uv)
        q._normals=[unit(apply(r,n)) for n in m.normals()];out[name]=q
    return out,angles


def render(parts,texture,path,composition=False):
    width,height=(1200,900) if composition else (1440,900)
    pixels=bytearray((19,14,12) if composition else (20,27,28))*(width*height)
    depth=[-1e10]*(width*height);light=unit((-.55,.82,-.65));fill=unit((.1,.15,-1))
    if composition:
        rng=random.Random(8421)
        for i in range(46):
            x,y=rng.randrange(width),rng.randrange(height-100);color=(124,191,194) if i%3==0 else (190,187,173)
            for dx,dy in ((0,0),(1,0),(0,1)):
                k=((y+dy)*width+x+dx)*3;pixels[k:k+3]=bytes(color)
        # Preview-only minimal platform; it is not exported as another model part.
        for y in range(height-47,height):
            shade=(126,151,158) if y<height-32 else (77,101,110)
            for x in range(0,width):pixels[(y*width+x)*3:(y*width+x)*3+3]=bytes(shade)
    def display(v):
        v=clamp(v);srgb=v*12.92 if v<=.0031308 else 1.055*v**(1/2.4)-.055
        return int(clamp(srgb)*255)
    bounds=G.bounds([p for m in parts.values() for p in m.vertices]);views=[0] if composition else [0,35,90]
    panel=width/len(views);target=(.25,.45,0) if composition else ((bounds[0][0]+bounds[1][0])/2,(bounds[0][1]+bounds[1][1])/2,0)
    scale=157 if composition else (height-75)/(bounds[1][1]-bounds[0][1])
    if composition:
        # Feet may be cropped, as requested; the complete fighting arms/fists
        # remain visible at either side of the review image.
        camera_right=(1,0,0);side=[dot(sub(p,target),camera_right) for m in parts.values() for p in m.vertices]
        scale=min(scale,(width-64)/(max(side)-min(side)))
        cx_offset=-(max(side)+min(side))/2*scale
    if not composition:
        for angle in views:
            right=(math.cos(math.radians(angle)),0,math.sin(math.radians(angle)));values=[dot(p,right) for m in parts.values() for p in m.vertices]
            scale=min(scale,(panel-42)/(max(values)-min(values)))
    for index,angle in enumerate(views):
        az=math.radians(angle);el=math.radians(-4 if composition else 5)
        camera=(math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el));right=(math.cos(az),0,math.sin(az));up=cross(right,camera)
        half=unit(add(light,camera));cx=index*panel+panel/2+(cx_offset if composition else 0);cy=height/2+13
        for m in parts.values():
            positions=[];colors=[]
            for p,n,c,role,uv in zip(m.vertices,m.normals(),m.colors,m.roles,m.uv):
                rel=sub(p,target);positions.append((cx+dot(rel,right)*scale,cy-dot(rel,up)*scale,dot(rel,camera)))
                tx=min(255,int(uv[0]*256));ty=min(255,int(uv[1]*256));a=(ty*256+tx)*4
                tex=texture['albedo'][a]/255;rough=texture['orm'][a+1]/255;metal=texture['orm'][a+2]/255
                lum=.20+.68*max(0,dot(n,light))+.18*max(0,dot(n,fill))
                shine=12+(1-rough)*135;specular=max(0,dot(n,half))**shine
                strength=.09 if role in (0,1) else .025 if role==2 else .65 if role in (3,4) else .75
                emission=.45 if role==7 else 0
                colors.append(tuple(display(v*tex*lum+specular*strength*(.55+.45*metal)+emission) for v in c[:3]))
            for ia,ib,ic in m.faces:
                p,q,r=positions[ia],positions[ib],positions[ic]
                area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-7:continue
                minx=max(int(index*panel),int(min(p[0],q[0],r[0])));maxx=min(int((index+1)*panel)-1,int(max(p[0],q[0],r[0]))+1)
                miny=max(0,int(min(p[1],q[1],r[1])));maxy=min(height-1,int(max(p[1],q[1],r[1]))+1)
                for y in range(miny,maxy+1):
                    for x in range(minx,maxx+1):
                        u=((q[0]-x-.5)*(r[1]-y-.5)-(q[1]-y-.5)*(r[0]-x-.5))/area
                        v=((r[0]-x-.5)*(p[1]-y-.5)-(r[1]-y-.5)*(p[0]-x-.5))/area;w=1-u-v
                        if min(u,v,w)<0:continue
                        z=u*p[2]+v*q[2]+w*r[2];point=y*width+x
                        if z<=depth[point]:continue
                        depth[point]=z
                        for channel in range(3):pixels[point*3+channel]=int(u*colors[ia][channel]+v*colors[ib][channel]+w*colors[ic][channel])
    G.png(path,width,height,pixels)


def validate(parts,scene,path):
    assert len(parts)==len(scene['nodes'])==len(scene['meshes'])==15
    assert len(scene['materials'])==1 and all(len(m['primitives'])==1 for m in scene['meshes'])
    roles={};counts={}
    for name,m in parts.items():
        assert len(m.faces)<20000,(name,len(m.faces))
        assert len(m.vertices)<65536 and len(m.vertices)==len(m.colors)==len(m.uv)==len(m.roles)
        assert all(math.isfinite(v) for p in m.vertices for v in p)
        assert all(0<=v<=1 for uv in m.uv for v in uv)
        assert all(abs(length(n)-1)<1e-6 for n in m.normals()),name
        for f in m.faces:
            assert min(f)>=0 and max(f)<len(m.vertices)
            a,b,c=(m.vertices[i] for i in f);assert length(cross(sub(b,a),sub(c,a)))>1e-11,(name,f)
        counts[name]={'vertices':len(m.vertices),'triangles':len(m.faces),'boundsStuds':G.bounds(m.vertices)}
        roles[name]={role:m.roles.count(role) for role in set(m.roles)}
    assert 5 in roles['Head'] and 6 in roles['Head'] and 7 in roles['Head']
    assert all(2 in roles[side+'UpperArm'] for side in ('Left','Right'))
    assert all(3 in roles[side+'LowerLeg'] and 4 in roles[side+'LowerLeg'] for side in ('Left','Right'))
    b=G.bounds([p for m in parts.values() for p in m.vertices]);blob=path.read_bytes()
    assert struct.unpack_from('<4sII',blob)==(b'glTF',2,len(blob))
    jlen=struct.unpack_from('<I',blob,12)[0];gltf=json.loads(blob[20:20+jlen]);binary=28+jlen
    parents={c:i for i,n in enumerate(gltf['nodes']) for c in n.get('children',[])}
    def position(i):
        local=tuple(gltf['nodes'][i].get('translation',(0,0,0)))
        return add(position(parents[i]),local) if i in parents else local
    actual=[]
    for i,node in enumerate(gltf['nodes']):
        a=gltf['accessors'][gltf['meshes'][node['mesh']]['primitives'][0]['attributes']['POSITION']];view=gltf['bufferViews'][a['bufferView']]
        start=binary+view.get('byteOffset',0)+a.get('byteOffset',0)
        for v in range(a['count']):actual.append(add(position(i),struct.unpack_from('<fff',blob,start+v*12)))
    decoded=G.bounds(actual);expected=[mul(p,METRES) for p in b]
    error=max(abs(x-y) for row,want in zip(decoded,expected) for x,y in zip(row,want));assert error<1e-5
    return {'status':'PASS','nodes':15,'materials':1,'primitivesPerNode':1,'embeddedTextureCount':4,
        'bytes':len(blob),'sha256':hashlib.sha256(blob).hexdigest(),'parts':counts,'roleVertexCounts':roles,
        'triangles':sum(len(m.faces) for m in parts.values()),'boundsStuds':b,'heightStuds':b[1][1]-b[0][1],
        'decodedGlbBoundsMetres':decoded,'metreConversionMaximumError':error,
        'geometryFeatures':['sculpted V torso/pectorals/segmentedabs/traps','small low head with angular physical sunglasses/smirk',
            'actual wart/crease geometry','red cloth arm wraps and3D tails','dark knee cuffs/silver rims/rivets/conical spikes'],
        'actualStudioImport':'NOT_RUN','productionReady':False}


def main():
    frozen={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('canonical-hero*.glb')}
    parts=build();components={name:orient(m) for name,m in parts.items()}
    ground=min(v[1] for m in parts.values() for v in m.vertices)
    vertical=1.08
    for m in parts.values():
        m.vertices=[(x,-3+(y-ground)*vertical,z) for x,y,z in m.vertices]
        m.analytic={i:unit((n[0],n[1]/vertical,n[2])) for i,n in m.analytic.items()};m._normals=None
    for name,(x,y,z) in list(PIVOTS.items()):PIVOTS[name]=(x,-3+(y-ground)*vertical,z)
    for name,m in parts.items():
        if len(m.faces)>=20000:raise ValueError(f'{name} over budget: {len(m.faces)}')
    images,texture=atlas()
    for name,blob in zip(('albedo','orm','normal','emissive'),images):(HERE/f'green-brawler-{name}.png').write_bytes(blob)
    path=HERE/'green-brawler.glb';scene=export(parts,images,path);report=validate(parts,scene,path);report['closedGeometryComponents']=components
    render(parts,texture,HERE/'green-brawler-turntable.png')
    posed,angles=pose(parts);render(posed,texture,HERE/'green-brawler-preview.png',True)
    joints=[]
    for name,parent in PARENTS.items():
        if parent:joints.append({'name':JOINTS[name],'parent':parent,'child':name,'worldPositionStuds':PIVOTS[name],
            'parentAttachmentStuds':sub(PIVOTS[name],PIVOTS[parent]),'childAttachmentStuds':[0,0,0]})
    metadata={'schema':2,'status':'owner-directed-green-brawler-study','brief':BRIEF.relative_to(ROOT).as_posix(),
        'briefSha256':hashlib.sha256(BRIEF.read_bytes()).hexdigest() if BRIEF.exists() else None,
        'artDirection':'owner-authored2026-11-09 detailed adaptation; not a minimal NES palette claim',
        'rigContract':{'nodes':15,'onePrimitivePerNode':True,'oneSharedMaterial':True,'newHumanoid':False,
            'allDetailsMergedIntoExistingCosmeticSegments':True,'neutralPose':'symmetric rig; asymmetric stance onlypreview',
            'shoulderRestCorrectionRadians':0,'physics':'existing physical body/health/identity unchanged; all visuals massless/noCollide/noTouch/noQuery; pin server ownership after attachment'},
        'units':{'authoring':'Roblox studs','gltf':'metres','metresPerStud':METRES,'up':[0,1,0],'forward':[0,0,-1],
            'root':[0,0,0],'groundYStuds':-3,'boundsStuds':report['boundsStuds'],'heightStuds':report['heightStuds']},
        'parts':[{'name':name,'parent':PARENTS[name],'pivotStuds':PIVOTS[name],
            'boundingBoxCenterStuds':mul(add(*report['parts'][name]['boundsStuds']),.5),
            'boundingBoxSizeStuds':sub(report['parts'][name]['boundsStuds'][1],report['parts'][name]['boundsStuds'][0]),
            'neutralWorldAxes':{'right':[1,0,0],'up':[0,1,0],'forward':[0,0,-1]},**report['parts'][name]} for name in parts],
        'joints':joints,'atlas':{'resolution':[256,256],'layout':'4columns×2rows;8 role cells',
            'roles':ROLES,'maps':['albedo','ORM(occlusionR/roughnessG/metalnessB)','normal(OpenGL)','emissive'],
            'allEmbedded':True,'vertexColors':'macro forest/grass/lime; texture albedo adds grain/material detail'},
        'headFeatures':{'smallLowNeck':True,'sunglassesGeometry':True,'mouth':'closed asymmetric smirk, no teeth/snarl',
            'jawHingeStuds':[0,-3+(1.68-ground)*vertical,-.08],
            'leftEyeRegionStuds':[-.43,-3+(2.18-ground)*vertical,-.63],
            'rightEyeRegionStuds':[.43,-3+(2.18-ground)*vertical,-.63]},
        'accessories':{'redCloth':'above elbows, both upper-arm nodes; tails actual closed ribbon geometry',
            'kneeCuffs':'both lower-leg nodes; darkmetalbody, silverrings,6rivets and3short conical spikes each',
            'excluded':['armour','gloves','hair','tail','headhorns','ears','weapons','text','logos']},
        'previewPoseEulerRadians':angles,'previewOnly':'low-camera lighting/platform/stars/crop are not part of model or a fixed gameplay pose',
        'frozenEarlierGlbs':frozen,'pending':['actual Studio15MeshPart/PBR import','source-driven attack morph geometry','whole fear32/33 forms','runtime animation/network/device acceptance']}
    assert frozen=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('canonical-hero*.glb')}
    (HERE/'green-brawler-rig.json').write_text(json.dumps(metadata,indent=2)+'\n')
    (HERE/'green-brawler-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('status','nodes','materials','triangles','bytes','sha256','heightStuds')},indent=2))
    # Studio SurfaceAppearance drops COLOR_0 after its texture pack loads.
    from bake_green_brawler_surface import bake
    bake(path)


if __name__=='__main__':main()
