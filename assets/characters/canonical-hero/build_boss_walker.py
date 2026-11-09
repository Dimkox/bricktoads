"""Source-informed Boss Walker cosmetic package; four independent GLB meshes.

The red intro silhouette and camera-relative cannon are evidenced. Chassis,
depth, rear anatomy, material response and 3D assembly are authored. No Studio,
place, source, avatar, or earlier GLB writes occur here.
"""
from __future__ import annotations
import hashlib, importlib.util, json, math, struct, zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
METRES = .28
PIXEL = 23.28 / 128
NAMES = ('GuardianChassis', 'GuardianLeftCannon', 'GuardianRightCannon', 'IntroLeg12')
LAYOUT = dict(zip(NAMES, ([0,0,0], [-16,0,0], [16,0,0], [35,0,0])))
PIVOTS = {'GuardianChassis':[0,0,0], 'GuardianLeftCannon':[-2.5,.7,.5],
          'GuardianRightCannon':[2.5,.7,.5], 'IntroLeg12':[0,0,0]}
MUZZLES = {'GuardianLeftCannon':[-3.1,.7,-4.6], 'GuardianRightCannon':[3.1,.7,-4.6]}
EARLIER = ('canonical-hero.glb','canonical-hero-player1.glb','canonical-hero-player2.glb',
           'green-brawler.glb','hero-attack-morphs.glb','hero-fear-morphs.glb')

def module(name, file):
    s=importlib.util.spec_from_file_location(name,HERE/file)
    m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
A=module('boss_morph_helpers','build_hero_attack_morphs.py')
H=A.H; G=H.G; B=A.B
add,sub,mul,dot,cross,unit,length=G.add,G.sub,G.mul,G.dot,G.cross,G.unit,G.length
RED=H.linear((.76,.027,.035)); LIGHT=H.linear((1,.17,.17))
DARKRED=H.linear((.34,.008,.016)); BLACK=H.linear((.018,.018,.023))
METAL=H.linear((.19,.21,.23)); EDGE=H.linear((.46,.48,.49)); DARK=H.linear((.055,.059,.063))

class Mesh(A.Mesh):
    def __init__(self,name):
        super().__init__(name);self.components=[]
    def append(self,vertices,faces,color=RED):
        offset=len(self.vertices);super().append(vertices,faces,color)
        self._normals=None
        return offset

def polygon_area(poly):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))/2

def loft(m, polygon, layers, color=RED):
    """Closed loft of a convex XY polygon; layers are (z, xscale, yscale, cx,cy)."""
    if polygon_area(polygon)<0:polygon=list(reversed(polygon))
    n=len(polygon);vs=[]
    for z,sx,sy,cx,cy in layers:vs.extend((cx+x*sx,cy+y*sy,z) for x,y in polygon)
    faces=[]
    for row in range(len(layers)-1):
        for i in range(n):
            j=(i+1)%n;a=row*n+i;b=row*n+j;c=(row+1)*n+i;d=(row+1)*n+j
            faces.extend(((a,b,c),(b,d,c)))
    for i in range(1,n-1):faces.extend(((0,i+1,i),((len(layers)-1)*n,(len(layers)-1)*n+i,(len(layers)-1)*n+i+1)))
    m.append(vs,faces,color)

def bevel_box(m,c,size,bevel=.10,color=RED):
    x,y,z=c;rx,ry,rz=(v/2 for v in size);b=min(bevel,rx*.45,ry*.45,rz*.45)
    poly=[(-rx+b,-ry),(rx-b,-ry),(rx,-ry+b),(rx,ry-b),(rx-b,ry),(-rx+b,ry),(-rx,ry-b),(-rx,-ry+b)]
    insetx=(rx-b)/rx;insety=(ry-b)/ry
    loft(m,poly,[(z-rz,insetx,insety,x,y),(z-rz+b,1,1,x,y),
                 (z+rz-b,1,1,x,y),(z+rz,insetx,insety,x,y)],color)

def axial(m,c,axis,profile,color=RED,sides=40):
    """Closed radial solid. Profile ordered from back to front along axis."""
    axis=unit(axis);ref=(0,1,0) if abs(axis[1])<.98 else (0,0,1)
    u=unit(cross(ref,axis));v=cross(axis,u);vs=[]
    for t,r in profile:
        vs.extend(add(c,add(mul(axis,t),add(mul(u,math.cos(j/sides*math.tau)*r),mul(v,math.sin(j/sides*math.tau)*r)))) for j in range(sides))
    faces=[]
    for row in range(len(profile)-1):
        for i in range(sides):
            j=(i+1)%sides;a=row*sides+i;b=row*sides+j;d=(row+1)*sides+j;e=(row+1)*sides+i
            faces.extend(((a,b,e),(b,d,e)))
    # Fan caps avoid repeated coincident pole vertices.
    vs.extend((add(c,mul(axis,profile[0][0])),add(c,mul(axis,profile[-1][0]))))
    a=len(vs)-2;b=len(vs)-1;k=(len(profile)-1)*sides
    for i in range(sides):
        j=(i+1)%sides;faces.extend(((a,j,i),(b,k+i,k+j)))
    m.append(vs,faces,color)

def ring(m,c,axis,ro,ri,depth,color=RED,sides=48):
    """Closed annular wall, leaving a genuine open central recess."""
    axis=unit(axis);ref=(0,1,0) if abs(axis[1])<.98 else (0,0,1)
    u=unit(cross(ref,axis));v=cross(axis,u);b=min(.075,depth*.24,(ro-ri)*.24)
    profile=[(-depth/2,ro-b),(-depth/2+b,ro),(depth/2-b,ro),(depth/2,ro-b),
             (depth/2,ri+b),(depth/2-b,ri),(-depth/2+b,ri),(-depth/2,ri+b)]
    vs=[]
    for t,r in profile:
        vs.extend(add(c,add(mul(axis,t),add(mul(u,math.cos(j/sides*math.tau)*r),mul(v,math.sin(j/sides*math.tau)*r)))) for j in range(sides))
    faces=[]
    for row in range(len(profile)):
        nxt=(row+1)%len(profile)
        for i in range(sides):
            j=(i+1)%sides;a=row*sides+i;b_=row*sides+j;d=nxt*sides+j;e=nxt*sides+i
            faces.extend(((a,b_,e),(b_,d,e)))
    m.append(vs,faces,color)

def beam(m,a,b,width,depth,color=METAL):
    axis=unit(sub(b,a));u=unit(cross(axis,(0,0,1)));v=cross(axis,u)
    vs=[]
    for p in (a,b):
        for x,y in ((-1,-1),(1,-1),(1,1),(-1,1)):vs.append(add(p,add(mul(u,width*x/2),mul(v,depth*y/2))))
    fs=[(0,2,1),(0,3,2),(4,5,6),(4,6,7)]
    for i in range(4):j=(i+1)%4;fs.extend(((i,j,4+i),(j,4+j,4+i)))
    m.append(vs,fs,color)

def bolt(m,p,axis=(0,0,-1),radius=.10):
    axial(m,p,axis,[(-.015,radius*.82),(0,radius),(.07,radius),(.10,radius*.77)],EDGE,6)
    axial(m,add(p,mul(axis,.101)),axis,[(0,radius*.30),(.008,radius*.30)],DARK,6)

def transform_new(m,start,axis,angle,origin):
    # Rodrigues rotation for authored tilted plate, preserving component closure.
    a=unit(axis);co=math.cos(angle);si=math.sin(angle)
    for i in range(start,len(m.vertices)):
        p=sub(m.vertices[i],origin)
        m.vertices[i]=add(origin,add(add(mul(p,co),mul(cross(a,p),si)),mul(a,dot(a,p)*(1-co))))

def chassis():
    m=Mesh('GuardianChassis')
    # Compact segmented pod. This entire body is authored because source never
    # presents an objective full chassis or rear view.
    outline=[(-2.08,-1.65),(2.08,-1.65),(2.62,-.70),(2.44,1.52),
             (1.70,3.07),(-1.70,3.07),(-2.44,1.52),(-2.62,-.70)]
    loft(m,outline,[(-2.28,.82,.83,0,.28),(-1.94,1,1,0,.28),
                    (1.80,1,1,0,.28),(3.47,.78,.80,0,.12),(3.88,.65,.68,0,.10)],BLACK)
    # Raised red upper hood and angular split plates, no eye/reticle geometry.
    hood=[(-2.34,-.64),(2.34,-.64),(2.45,.48),(1.64,1.70),(-1.64,1.70),(-2.45,.48)]
    loft(m,hood,[(-1.90,.88,.86,0,3.65),(-1.58,1,1,0,3.65),
                 (1.68,.96,.94,0,3.65),(2.36,.72,.76,0,3.65)],DARKRED)
    # Individually bevelled front armor facets make a readable red carapace.
    for side in (-1,1):
        start=len(m.vertices)
        bevel_box(m,(side*1.20,2.82,-2.14),(2.26,2.52,.48),.16,RED)
        transform_new(m,start,(0,0,1),side*-.105,(side*1.20,2.82,-2.14))
        bevel_box(m,(side*1.04,.65,-2.27),(1.97,1.52,.38),.13,DARKRED)
        bevel_box(m,(side*1.42,-.88,-1.80),(1.67,.70,.54),.12,RED)
        # Short hydraulic ground supports; no invented giant battle legs.
        beam(m,(side*1.72,-1.03,1.6),(side*2.08,-2.63,2.10),.56,.62,DARK)
        beam(m,(side*1.60,-1.04,-.91),(side*1.96,-2.57,-1.28),.43,.47,METAL)
        bevel_box(m,(side*2.0,-2.78,.40),(1.12,.44,4.72),.13,BLACK)
        bevel_box(m,(side*2.0,-2.65,-1.53),(.91,.34,.64),.09,DARKRED)
        for z in (-1.28,.16,1.55,2.16):bolt(m,(side*2.0,-2.49,z),(0,1,0),.11)
        # Side pivot trunnion and two cheek brackets connect the cannons.
        axial(m,(side*2.5,.7,.5),(side,0,0),[(-.47,.73),(.18,.73),(.29,.63),(.39,.63)],METAL,32)
        for y in (-.15,1.52):
            bevel_box(m,(side*2.58,y,.63),(.52,.35,2.16),.09,DARKRED)
            bolt(m,(side*2.89,y,-.16),(side,0,0),.13)
        for x in (side*.56,side*1.79):
            for y in (2.00,3.59):bolt(m,(x,y,-2.405),radius=.115)
        # Lateral black ventilation slits are actual recessed panel gaps.
        bevel_box(m,(side*2.52,2.27,.82),(.22,1.43,2.10),.06,DARK)
        for z in (-.01,.34,.69,1.04,1.39,1.74):
            bevel_box(m,(side*2.68,2.29,z),(.18,1.19,.14),.045,RED)
    # Narrow center seam and lower impact strip instead of a face or reactor.
    bevel_box(m,(0,2.74,-2.46),(.22,2.71,.16),.055,BLACK)
    bevel_box(m,(0,.77,-2.48),(.24,1.52,.15),.04,METAL)
    bevel_box(m,(0,-.66,-2.13),(1.44,.70,.42),.12,METAL)
    for x in (-.48,0,.48):bevel_box(m,(x,-.66,-2.38),(.16,.42,.09),.035,BLACK)
    # Top hatch, ridge protection and restrained service details.
    bevel_box(m,(0,4.91,.19),(2.74,.48,2.64),.16,RED)
    bevel_box(m,(0,5.25,.26),(1.98,.20,1.92),.065,BLACK)
    for x in (-.69,.69):
        bevel_box(m,(x,5.10,.30),(.22,.39,2.42),.06,METAL)
        for z in (-.70,1.23):bolt(m,(x,5.31,z),(0,1,0),.105)
    for side in (-1,1):
        # A bolted upper cooling cassette breaks the broad hood face into
        # mechanical surfaces while leaving the central armor seam legible.
        bevel_box(m,(side*1.12,4.42,-1.87),(1.29,.62,.26),.08,BLACK)
        for yy in (4.23,4.42,4.61):
            bevel_box(m,(side*1.12,yy,-2.035),(1.06,.075,.13),.025,RED)
        for xx in (side*1.65,side*.59):bolt(m,(xx,4.42,-2.05),radius=.065)
    # Engine is on the rear: black grilled intake, bands, bolted service hatch.
    bevel_box(m,(0,1.28,3.70),(2.96,2.73,.49),.16,DARKRED)
    bevel_box(m,(0,1.33,4.00),(2.49,2.11,.22),.08,BLACK)
    for y in (.49,.83,1.17,1.51,1.85,2.19):
        bevel_box(m,(0,y,4.14),(2.22,.13,.18),.035,METAL)
    for x in (-1.27,1.27):
        for y in (.28,2.37):bolt(m,(x,y,4.12),(0,0,1),.10)
    for side in (-1,1):
        axial(m,(side*1.60,3.14,2.73),(0,0,1),[(-.2,.38),(.5,.38),(.61,.31)],METAL,24)
        axial(m,(side*1.60,3.14,3.35),(0,0,1),[(0,.265),(.025,.265)],BLACK,24)
    return m

def cannon(name,side):
    m=Mesh(name);x=side*3.1;y=.7
    # Coaxial source-inspired red/black stepped barrel, forward -Z. Longitudinal
    # profile and detailed breech are authored from the 31x24 perspective sprite.
    axial(m,(x,y,0),(0,0,-1),[(-2.25,.85),(-2.1,1.00),(-1.72,1.13),
             (-.50,1.24),(.2,1.12),(1.10,.88),(3.64,.79)],DARK,40)
    axial(m,(x,y,0),(0,0,-1),[(-2.08,.94),(-1.92,1.13),(-.62,1.13),
             (-.40,1.25),(-.15,1.25),(.02,1.10)],RED,40)
    # Recoil sleeve leaves dark channels visible between armor bands.
    for t,ro,ri,w in ((.50,1.14,.87,.32),(1.48,1.07,.80,.31),(2.45,.99,.77,.30)):
        ring(m,(x,y,-t),(0,0,-1),ro,ri,w,RED,40)
    ring(m,(x,y,-3.62),(0,0,-1),1.08,.70,.55,DARKRED,48)
    # Open muzzle with beveled red lip, long dark inner wall and recessed rear.
    # No front cap crosses the 1.34-stud bore opening.
    ring(m,(x,y,-4.33),(0,0,-1),1.20,.67,.54,RED,56)
    ring(m,(x,y,-4.03),(0,0,-1),.735,.665,.70,METAL,48)
    axial(m,(x,y,-3.66),(0,0,1),[(0,.663),(.12,.663)],BLACK,48)
    axial(m,(x,y,-3.655),(0,0,-1),[(0,.19),(.01,.19)],DARK,24)
    # Front-facing bolts and six black support fins around the red muzzle.
    for i in range(8):
        a=i/8*math.tau
        bolt(m,(x+math.cos(a)*.963,y+math.sin(a)*.963,-4.60),radius=.075)
    for i in range(6):
        a=i/6*math.tau;cx=x+math.cos(a)*.91;cy=y+math.sin(a)*.91
        start=len(m.vertices);bevel_box(m,(cx,cy,-2.25),(.18,.30,2.62),.06,DARKRED)
        transform_new(m,start,(0,0,1),a-math.pi/2,(cx,cy,-2.25))
    # Breech roof and shorter side rails, mounting pad around explicit pivot.
    bevel_box(m,(x,y+1.17,.85),(.68,.37,2.23),.11,RED)
    bevel_box(m,(x,y+1.39,.72),(.30,.16,1.70),.045,METAL)
    for yy in (-.67,.67):
        bevel_box(m,(x+side*1.05,y+yy,.77),(.37,.29,2.08),.075,RED)
    axial(m,(side*2.5,.7,.5),(side,0,0),[(-.20,.68),(.75,.68),(.88,.58)],METAL,32)
    for z in (.00,1.42):bolt(m,(x+side*1.275,y,z),(side,0,0),.11)
    # Left/right have mirrored but intentionally asymmetric service latch.
    bevel_box(m,(x+side*.86,y+.32,1.86),(.55,.81,.27),.08,METAL)
    bolt(m,(x+side*.87,y+.32,2.03),(0,0,1),.10)
    return m

def intro_leg():
    m=Mesh('IntroLeg12');source=ROOT/'research/canonical-visuals/frames/object-12.png'
    w,h,rgba=B.png_decode(source.read_bytes());assert (w,h)==(35,128)
    mask={(x,y) for y in range(h) for x in range(w) if rgba[(y*w+x)*4+3]}
    verts=[];faces=[];index={};colors=[];half=.57
    def vi(x,y,z):
        key=(x,y,z)
        if key not in index:
            index[key]=len(verts);verts.append(((x-8)*PIXEL,(128-y)*PIXEL,z))
            samples=[]
            for px,py in ((x-1,y-1),(x,y-1),(x-1,y),(x,y)):
                if (px,py) in mask:
                    j=(py*w+px)*4;samples.append(tuple(rgba[j+k]/255 for k in range(3)))
            rgb=tuple(sum(v[k] for v in samples)/len(samples) for k in range(3))
            # Source RGB table is approximate. Metal face response and all depth
            # are authored; original NES palette indices are not changed.
            colors.append(H.linear(rgb))
        return index[key]
    for x,y in sorted(mask):
        for z,rev in ((-half,False),(half,True)):
            a,b,c,d=(vi(xx,yy,z) for xx,yy in ((x,y),(x+1,y),(x+1,y+1),(x,y+1)))
            fs=((a,b,c),(a,c,d));faces.extend(tuple(reversed(f)) if rev else f for f in fs)
        for neighbor,a,b in (((x,y-1),(x,y),(x+1,y)),((x+1,y),(x+1,y),(x+1,y+1)),
                ((x,y+1),(x+1,y+1),(x,y+1)),((x-1,y),(x,y+1),(x,y))):
            if neighbor not in mask:
                p,q,r,s=vi(*a,-half),vi(*b,-half),vi(*a,half),vi(*b,half)
                faces.extend(((p,r,q),(q,r,s)))
    m.append(verts,faces);m.colors[:]=colors
    # Source upper disk is a mechanical joint, with an authored depth housing.
    joint=(1.837,17.55,0)
    axial(m,joint,(0,0,-1),[(-1.44,1.73),(-1.25,1.94),(.81,1.94),(.99,1.83)],DARKRED,56)
    ring(m,(joint[0],joint[1],-1.12),(0,0,-1),1.92,1.56,.36,LIGHT,56)
    ring(m,(joint[0],joint[1],-1.31),(0,0,-1),1.55,1.26,.25,RED,56)
    axial(m,(joint[0],joint[1],-1.45),(0,0,1),[(0,1.235),(.11,1.235)],BLACK,48)
    axial(m,(joint[0],joint[1],-1.505),(0,0,-1),[(0,.72),(.06,.72),(.10,.60)],DARKRED,12)
    # Recessed red spoke in front hub: a solid mechanical cap, no luminous eye.
    for angle in (-.23,math.pi/2-.23):
        start=len(m.vertices);bevel_box(m,(joint[0],joint[1],-1.60),(1.39,.30,.16),.055,RED)
        transform_new(m,start,(0,0,1),angle,(joint[0],joint[1],-1.60))
    # Narrow raised shaft runner follows the exact source diagonal, with small
    # periodic mechanical rib highlights. Everything stays inside source XY.
    beam(m,(.10,1.08,-.635),(1.85,15.45,-.635),.36,.16,RED)
    beam(m,(.46,1.05,.63),(2.14,15.3,.63),.32,.16,METAL)
    for yy in [1.55+i*.75 for i in range(19)]:
        xx=.10+(yy-1.08)*(1.75/14.37)
        bevel_box(m,(xx-.13,yy,-.755),(.24,.105,.10),.025,LIGHT)
    # Small toe remains a toe, not a wide boot sole.
    bevel_box(m,(-.02,.34,-.67),(2.22,.40,.36),.07,RED)
    # Three right-edge service studs on the evidenced diagonal top assembly.
    for x,y in ((4.19,19.66),(4.27,18.63),(4.18,17.67)):
        ring(m,(x,y,-.66),(0,0,-1),.36,.245,.18,RED,24)
        axial(m,(x,y,-.60),(0,0,1),[(0,.24),(.05,.24)],BLACK,24)
    return m

def build():
    meshes={m.name:m for m in (chassis(),cannon(NAMES[1],-1),cannon(NAMES[2],1),intro_leg())}
    components={}
    for name,m in meshes.items():
        components[name]=H.orient(m)
        assert len(m.faces)<20000,(name,len(m.faces))
        assert len(m.faces)*3<65536
        assert all(length(cross(sub(m.vertices[b],m.vertices[a]),sub(m.vertices[c],m.vertices[a])))>1e-10 for a,b,c in m.faces)
        print(name,len(m.faces),'triangles',components[name],'closed shell components',flush=True)
    bounds=G.bounds(meshes['IntroLeg12'].vertices)
    assert abs(bounds[0][1])<1e-9 and abs(bounds[1][1]-23.28)<1e-9
    return meshes,components

def export(meshes,path):
    # Reviewed shared single-albedo exporter; larger atlas accommodates all four
    # detailed meshes without adding materials, attributes or attachment nodes.
    src=(HERE/'build_hero_attack_morphs.py').read_text()
    fn=src[src.index('def export(meshes,path):'):src.index('\ndef main():')]
    fn=fn.replace('size=2048;cell=8','size=4096;cell=8')
    fn=fn.replace('HeroAttackMorphs','BossWalkerCosmetics')
    fn=fn.replace('MorphBakedAlbedo','BossWalkerBakedAlbedo').replace('MorphSkinBakedAlbedo','BossWalkerPaintedMetal')
    fn=fn.replace('source-derived attack morphs; source2D depth/authored origin inferred',
                  'Boss Walker source-informed components; complete chassis and 3D depth authored')
    fn=fn.replace("'roughnessFactor':.63,'metallicFactor':0", "'roughnessFactor':.48,'metallicFactor':.32")
    ns={'G':G,'B':B,'LAYOUT':LAYOUT,'METRES':METRES,'struct':struct,'json':json,
        'hashlib':hashlib,'png_rgba':A.png_rgba}
    exec(fn,ns);return ns['export'](meshes,path)

def preview(meshes,path):
    """Render actual triangles with a z-buffer; no concept mockup substitution."""
    import numpy as np
    from PIL import Image,ImageDraw
    width,height=1800,1200;canvas=Image.new('RGB',(width,height),(21,25,29));draw=ImageDraw.Draw(canvas)
    panels=[('Battle front',list(NAMES[:3]),0,0,0),('Battle three-quarter',list(NAMES[:3]),44,0,1),
            ('Battle side',list(NAMES[:3]),90,0,2),('IntroLeg12 front',['IntroLeg12'],0,1,0),
            ('IntroLeg12 three-quarter',['IntroLeg12'],42,1,1),('IntroLeg12 side',['IntroLeg12'],90,1,2)]
    light=np.array(unit((-.55,.80,-.85)))
    for title,names,az,row,col in panels:
        pw,ph=600,600;az=math.radians(az);el=math.radians(7 if row==0 else 0)
        camera=np.array((math.sin(az)*math.cos(el),math.sin(el),-math.cos(az)*math.cos(el)))
        right=np.array((math.cos(az),0,math.sin(az)));up=np.cross(right,camera)
        vs=[];ns=[];cs=[];fs=[]
        for name in names:
            m=meshes[name];off=len(vs);vs.extend(m.vertices);ns.extend(m.normals());cs.extend(m.colors)
            fs.extend(tuple(off+i for i in f) for f in m.faces)
        vs=np.array(vs);ns=np.array(ns);cs=np.array(cs)[:,:3]
        projected=np.stack((vs@right,vs@up,vs@camera),axis=-1)
        lo=projected[:,:2].min(0);hi=projected[:,:2].max(0)
        scale=min((pw-70)/(hi[0]-lo[0]),(ph-96)/(hi[1]-lo[1]))
        projected[:,0]=(projected[:,0]-(lo[0]+hi[0])/2)*scale+pw/2
        projected[:,1]=ph/2+18-(projected[:,1]-(lo[1]+hi[1])/2)*scale
        shade=.25+.78*np.maximum(0,ns@light)
        linear=np.clip(cs*shade[:,None],0,1)
        rgb=np.where(linear<=.0031308,linear*12.92,1.055*np.power(linear,1/2.4)-.055)*255
        pixels=np.full((ph,pw,3),(25,30,34),dtype=np.uint8);zbuf=np.full((ph,pw),-1e30)
        for f in fs:
            p,q,r=projected[list(f)];area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
            if abs(area)<1e-7:continue
            x0=max(0,int(min(p[0],q[0],r[0])));x1=min(pw-1,int(max(p[0],q[0],r[0]))+1)
            y0=max(0,int(min(p[1],q[1],r[1])));y1=min(ph-1,int(max(p[1],q[1],r[1]))+1)
            if x0>x1 or y0>y1:continue
            xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
            a=((q[0]-xx)*(r[1]-yy)-(q[1]-yy)*(r[0]-xx))/area
            b=((r[0]-xx)*(p[1]-yy)-(r[1]-yy)*(p[0]-xx))/area;c=1-a-b
            zz=a*p[2]+b*q[2]+c*r[2];region=zbuf[y0:y1+1,x0:x1+1]
            valid=(a>=0)&(b>=0)&(c>=0)&(zz>region)
            if not valid.any():continue
            region[valid]=zz[valid];out=pixels[y0:y1+1,x0:x1+1]
            value=a[...,None]*rgb[f[0]]+b[...,None]*rgb[f[1]]+c[...,None]*rgb[f[2]]
            out[valid]=np.clip(value[valid],0,255).astype(np.uint8)
        canvas.paste(Image.fromarray(pixels),(col*pw,row*ph));draw.text((col*pw+20,row*ph+18),title,fill=(226,232,234))
    canvas.save(path)

def inspect_export(path,parts):
    blob=path.read_bytes();assert struct.unpack_from('<4sII',blob)==(b'glTF',2,len(blob))
    jlen=struct.unpack_from('<I',blob,12)[0];scene=json.loads(blob[20:20+jlen]);binary=28+jlen
    assert len(scene['nodes'])==len(scene['meshes'])==4
    assert len(scene['materials'])==len(scene['images'])==1
    assert not any('emissive' in key.lower() for key in scene['materials'][0])
    results={}
    for node,m,p in zip(scene['nodes'],scene['meshes'],parts):
        assert node['name']==m['name']==p['name'];assert len(m['primitives'])==1
        prim=m['primitives'][0];assert set(prim['attributes'])=={'POSITION','NORMAL','TEXCOORD_0'}
        arrays={}
        for name in ('POSITION','NORMAL'):
            acc=scene['accessors'][prim['attributes'][name]];view=scene['bufferViews'][acc['bufferView']]
            at=binary+view.get('byteOffset',0)+acc.get('byteOffset',0)
            arrays[name]=[struct.unpack_from('<fff',blob,at+i*12) for i in range(acc['count'])]
        assert all(abs(length(n)-1)<2e-6 for n in arrays['NORMAL'])
        assert all(math.isfinite(v) for pos in arrays['POSITION'] for v in pos)
        area=min(length(cross(sub(arrays['POSITION'][i+1],arrays['POSITION'][i]),sub(arrays['POSITION'][i+2],arrays['POSITION'][i])))/2 for i in range(0,len(arrays['POSITION']),3))
        assert area>1e-12
        bounds=G.bounds(arrays['POSITION'])
        error=max(abs(actual-wanted*METRES) for a,b in zip(bounds,p['boundsStuds']) for actual,wanted in zip(a,b))
        assert error<1e-6
        assert max(abs(a-b*METRES) for a,b in zip(node['translation'],LAYOUT[p['name']]))<1e-9
        results[p['name']]={'decodedBoundsMetres':bounds,'minimumTriangleAreaSquareMetres':area,'maximumBoundErrorMetres':error,'unitNormals':True}
    return {'serializedChecks':'PASS','decodedParts':results,'meshNodesOnly':True,'singleEmbeddedAlbedo':True,
        'singlePrimitivePerMesh':True,'singleMaterial':True,'vertexColors':False,'emissive':False}

def main():
    frozen={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in EARLIER}
    meshes,components=build();preview(meshes,HERE/'boss-walker-preview.png')
    print('ACTUAL GEOMETRY PREVIEW READY',flush=True)
    counts,sha,bytes_=export(meshes,HERE/'boss-walker.glb');parts=[]
    for name,m in meshes.items():
        bounds=G.bounds(m.vertices);center=mul(add(*bounds),.5);size=sub(bounds[1],bounds[0])
        p={'name':name,'role':'intro-ground-origin-leg' if name=='IntroLeg12' else 'battle-'+('chassis' if name=='GuardianChassis' else 'cannon'),
           'boundsStuds':bounds,'boundingBoxCenterStuds':center,'boundingBoxSizeStuds':size,
           'layoutOffsetStuds':LAYOUT[name],'nodeTranslationMetres':mul(LAYOUT[name],METRES),
           'layoutPurpose':'nonoverlapping native import only; subtract this offset before root binding',
           'mountPointStuds':PIVOTS[name],'mountAxesRootSpace':[1,0,0,0,1,0,0,0,1],
           'originAttachmentInIdentityBoundingBoxPartStuds':sub(PIVOTS[name],center),
           'expectedOrientation':{'up':[0,1,0],'forward':[0,0,-1],'rootAxes':'identity'},
           'frontAsymmetry':'muzzle cavity faces -Z; service latch outboard' if 'Cannon' in name else
               'source XY upper assembly leans +X, red joint and raised shaft runner on -Z' if name=='IntroLeg12' else
               'split red impact armor -Z; broad black engine grille +Z',
           'closedOrientableShellComponents':components[name],**counts[name]}
        if name in MUZZLES:
            p.update(muzzlePointStuds=MUZZLES[name],muzzleForwardStuds=[0,0,-1],muzzleAxesRootSpace=[1,0,0,0,1,0,0,0,1],
                muzzleAttachmentInIdentityBoundingBoxPartStuds=sub(MUZZLES[name],center),muzzleBoreRadiusStuds=.67,
                muzzleCavityRearStuds=[MUZZLES[name][0],.7,-3.66])
        if name=='IntroLeg12':p.update(sourceAnchorStuds=[0,12*PIXEL,0],sourceAnchorImagePixel=[8,116],
                authoredGroundOriginImageBoundary=[8,128],sourcePixelSize=[35,128],sourceStudsPerPixel=PIXEL,
                sourceXYMapping='x=(pixelBoundaryX-8)*.181875; y=(128-pixelBoundaryY)*.181875',
                originAttachmentName='IntroOriginRigAttachment',groundOriginStuds=[0,0,0])
        parts.append(p)
    assert frozen=={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in EARLIER}
    sourcefiles=['research/canonical-visuals/BOSS_WALKER_SOURCE.md','research/canonical-visuals/frames/object-12.png',
                 'research/canonical-visuals/boss-intro-foot-source-reference.png','research/canonical-visuals/boss-walker-arena-component-reference.png',
                 'research/canonical-visuals/boss-walker-arena-component-catalog.json']
    rig={'schema':1,'status':'frozen-preupload-source-informed-cosmetics','glbSha256':sha,'bytes':bytes_,
         'sourcePin':'f1a43b69577246850d136473700a333b3cdfe93f',
         'units':{'metadata':'Roblox studs','gltf':'metres','metresPerStud':METRES,'up':[0,1,0],'forward':[0,0,-1],
                  'battleOrigin':'R6 HumanoidRootPart identity; ground y=-3 at root worldY3',
                  'introOrigin':'separate ground-contact identity [0,0,0] near toe, actual geometry minY0'},
         'parts':parts,
         'sourceFacts':['graphics12 visible alpha silhouette is35x128 with a long narrow diagonal red shaft, small toe and large circular upper joint beneath diagonal plate',
             'graphics10 is31x24 red/black cannon in camera-relative boss presentation; two source turret records',
             'graphics11 reticle andC7 cracked glass are HUD/camera overlays and are absent from this physical asset',
             'source palette indices are verified; RGB rendering tables are approximate'],
         'authoredReconstruction':['entire compact chassis, brackets, short ground supports and rear engine are inferred, not an exact NES complete robot',
             'barrel length, 3D cross section, bore cavity, breech, recoil rails, bolts, muzzle marker and scale are authored',
             'intro depth, back, metallic response and raised mechanical details are authored around the source XY silhouette',
             'full arena camera projection, final nametable composition and live game presentation are not established by component references'],
         'material':{'oneSharedMaterial':True,'onePrimitivePerMesh':True,'bakedAlbedo':'embedded4096x4096 padded8x8 unique triangle atlas',
             'COLOR_0':'absent','emissive':'absent','alphaMode':'OPAQUE','roughnessFactor':.48,'metallicFactor':.32,
             'meaning':'source-informed red/black painted metal; PBR response and RGB approximate authored'},
         'runtimeContract':{'cosmeticOnly':True,'meshNodes':4,'extraAttachmentNodes':False,
             'battleAssembly':'geometry already root-local; preserve measured bbox center and subtract layout only',
             'nativeImport':'native mesh frame may includeY180; preserve it and solve attachment CFrames from actual imported orientation',
             'mountAttachment':'GuardianMountRigAttachment; MeshPart.CFrame*attachment.CFrame equals root*CFrame.new(mountPointStuds) with root axes identity',
             'muzzleAttachment':'MuzzleRigAttachment; same equation using muzzlePointStuds and root axes identity, forward -Z',
             'introAttachment':'IntroOriginRigAttachment; nativeMesh.CFrame*attachment.CFrame equals intro ground-origin frame',
             'chassisMountPointStuds':[0,0,0],'introMustRemainSeparate':True,
             'gameplay':'no Humanoid, collision, damage, movement or camera logic in this asset'},
         'sourceFiles':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sourcefiles},
         'frozenEarlierGlbs':frozen,'studioImport':'NOT_RUN; root owns reviewed upload and Studio integration'}
    validation={'status':'PASS','sha256':sha,'bytes':bytes_,'meshCount':4,'totalTriangles':sum(c['triangles'] for c in counts.values()),
                'parts':parts,'allSixEarlierGlbsUnchanged':True,'triangleLimitExclusive':20000,'exportVertexLimitExclusive':65536,
                'geometryClosure':'all indexed edges have exactly two incident faces per closed shell; all shells consistently outward oriented',
                'componentOverlap':'armor plates and bolts intentionally intersect; shell components remain individually closed',
                'actualStudioAcceptance':'NOT_RUN',**inspect_export(HERE/'boss-walker.glb',parts)}
    (HERE/'boss-walker-rig.json').write_text(json.dumps(rig,indent=2)+'\n')
    (HERE/'boss-walker-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
    print(json.dumps({'sha256':sha,'bytes':bytes_,'parts':parts},indent=2),flush=True)

if __name__=='__main__':main()
