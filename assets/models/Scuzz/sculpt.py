"""BT-88. Sculpt definitions in studs, +Y up, -Z forward; all sections are elliptical."""
from math import sin, cos, pi, radians

palette = {
    "ember": (183,83,26), "gold": (223,126,43), "cream": (250,181,84),
    "shade": (126,56,29), "mane": (37,29,28), "black": (22,22,25),
    "inner": (173,86,64), "tooth": (254,225,166), "eye": (248,190,70)
}
bones = {"Pelvis": (None,(0,1.28,.23)), "Chest": ("Pelvis",(0,1.94,.18)),
         "Head": ("Chest",(0,2.97,.09)), "Jaw": ("Head",(0,3.28,-.34))}
sockets = {"MuzzleAim":("Head",(0,3.32,-1.56)), "StrikeOrigin":("Hand_R",(.78,1.99,-.58)),
           "JumpCenter":("Pelvis",(0,1.45,.21)), "VfxHit":("Chest",(0,2.49,.08))}
pieces = []
def sweep(name,bone,color,sections,detail=0):
    pieces.append((name,bone,color,sections,detail))
def bulb(name,bone,color,p,q,radius,depth=None,detail=0):
    depth = radius if depth is None else depth
    sections=[]
    for t,w in [(.005,.12),(.13,.68),(.35,.97),(.59,1),(.82,.78),(.97,.34),(.999,.08)]:
        sections.append((*[p[i]+(q[i]-p[i])*t for i in range(3)],radius*w,depth*w))
    sweep(name,bone,color,sections,detail)
def lock(name,bone,color,p,m,q,r,d,detail=0):
    sweep(name,bone,color,[(*p,r*.65,d*.65),(*m,r,d),(*q,.008,.008)],detail)

# Lean torso, barrel-shaped haunches and foreshortened belly.
sweep("Haunch","Pelvis","ember",[(0,.76,.22,.27,.25),(0,1,.27,.53,.38),(0,1.5,.32,.62,.47),(0,1.84,.26,.51,.39),(0,2.15,.21,.32,.31)])
sweep("Mantle","Chest","gold",[(0,1.65,.23,.34,.34),(0,2.04,.21,.43,.38),(0,2.52,.22,.53,.39),(0,2.81,.18,.48,.37),(0,3.08,.03,.34,.29)])
bulb("Bib","Chest","cream",(0,1.68,-.04),(0,2.78,-.16),.32,.17)
# Head and long tapered bridge. A thin dark mouth line separates upper and lower jaw.
bulb("Skull","Head","gold",(0,2.99,.19),(0,3.78,.03),.49,.43)
sweep("Bridge","Head","gold",[(0,3.48,-.13,.45,.31),(0,3.43,-.47,.42,.25),(0,3.39,-.78,.35,.20),(0,3.31,-1.10,.25,.14),(0,3.31,-1.38,.13,.105)])
bulb("Nose","Head","black",(0,3.30,-1.35),(0,3.35,-1.57),.145,.107)
bulb("Mouth","Jaw","shade",(0,3.23,-.33),(0,3.23,-1.22),.31,.11)
bulb("Chin","Jaw","cream",(0,3.15,-.34),(0,3.20,-1.12),.28,.10)
for idx,(base,tip,r) in enumerate([(-.2,(-.12,4.46,.59),.14),(-.10,(-.06,4.31,.87),.17),(.04,(.07,4.14,.96),.16),(.19,(.28,4.28,.66),.12),(.27,(.41,4.09,.53),.10)]):
    lock("Crown%d"%idx,"Head","mane",(base,3.69,.03),(base,3.91,.18),tip,r,.16)
for i in range(4):
    y=2.76-i*.28
    lock("Spine%d"%i,"Chest","shade",(0,y,.39),(0,y-.08,.57),(0,y-.36,.73),.17,.12)
for side,sg in [("L",-1),("R",1)]:
    def pt(x,y,z):return (x*sg,y,z)
    arm,el,hand=["%s_%s"%(k,side) for k in ["Arm","Elbow","Hand"]]
    thigh,foot=["%s_%s"%(k,side) for k in ["Leg","Foot"]]
    shoulder,elbow,wrist=pt(.40,2.71,.13),pt(.78,2.23,.24),pt(.77,2.29,-.34)
    hip,knee,heel=pt(.37,1.53,.23),pt(.66,.83,-.01),pt(.63,.33,.48)
    bones.update({arm:("Chest",shoulder),el:(arm,elbow),hand:(el,wrist),thigh:("Pelvis",hip),foot:(thigh,heel)})
    sockets["Ground_"+side]=(foot,pt(.62,.015,-.32))
    bulb("Thigh"+side,thigh,"gold",pt(.39,1.53,.30),pt(.68,.66,-.05),.38,.38)
    bulb("Hock"+side,thigh,"ember",knee,heel,.24,.22)
    bulb("Foot"+side,foot,"gold",pt(.61,.27,.54),pt(.65,.17,-.57),.31,.184)
    for i in range(3):
        x=.47+i*.17
        bulb("Toe%s%d"%(side,i),foot,"cream",pt(x,.17,-.24),pt(x+.035,.108,-.80+abs(i-1)*.09),.101,.092)
    bulb("Shoulder"+side,arm,"gold",shoulder,elbow,.25,.245)
    bulb("Forearm"+side,el,"ember",elbow,wrist,.166,.18)
    bulb("Knuckles"+side,hand,"gold",wrist,pt(.79,2.19,-.55),.158,.14)
    for i in range(3):
        x=.68+i*.09
        lock("Digit%s%d"%(side,i),hand,"cream",pt(x,2.24,-.44),pt(x+.035,2.16,-.57),pt(x+.028,1.99+i*.014,-.50),.052,.055)
    bulb("Ear"+side,"Head","ember",pt(.38,3.41,.17),pt(.52,3.83,.23),.16,.14)
    bulb("EarCup"+side,"Head","inner",pt(.48,3.51,.11),pt(.575,3.76,.16),.092,.075)
    bulb("EyeRim"+side,"Head","shade",pt(.325,3.44,-.64),pt(.383,3.60,-.38),.127,.112)
    bulb("Eye"+side,"Head","eye",pt(.352,3.46,-.63),pt(.407,3.57,-.43),.108,.087)
    bulb("Pupil"+side,"Head","black",pt(.410,3.47,-.59),pt(.425,3.57,-.55),.049,.051)
    bulb("Catchlight"+side,"Head","tooth",pt(.448,3.542,-.585),pt(.448,3.566,-.575),.018,.016,1)
    lock("Brow"+side,"Head","mane",pt(.31,3.52,-.74),pt(.405,3.64,-.48),pt(.50,3.76,-.14),.094,.078)
    for i in range(3):
        y=3.55-i*.13
        lock("Cheek%s%d"%(side,i),"Head","ember",pt(.33,y,-.06),pt(.43,y-.03,.16),pt(.53,y-.13,.47),.09,.14)
    for i in range(3):
        x=.24-i*.035
        lock("Tooth%s%d"%(side,i),"Jaw","tooth",pt(x,3.22,-.68-i*.13),pt(x,3.20,-.7-i*.13),pt(x,3.15,-.71-i*.13),.027,.030,1)
    for i in range(3):
        lock("Whisker%s%d"%(side,i),"Head","mane",pt(.11,3.31,-1.30),pt(.23,3.34-i*.035,-1.31),pt(.47+i*.06,3.41-i*.116,-1.26+i*.075),.012,.012,1)
    for i in range(3):
        y=2.79-i*.30
        lock("Ruff%s%d"%(side,i),"Chest","ember",pt(.34,y,.13),pt(.45,y-.08,.25),pt(.55,y-.28,.41),.105,.1)

# Additive joint angles in degrees in project axes at the clip's accent.
poses = {
"Appear":{"Pelvis":(-12,0,0),"Head":(12,13,0),"Arm_L":(-31,0,-20)},
"IdleAlert":{"Chest":(-4,0,0),"Head":(4,10,-4),"Jaw":(5,0,0)},
"Step":{"Leg_L":(22,0,0),"Leg_R":(-22,0,0),"Arm_L":(-20,0,0),"Arm_R":(20,0,0),"Foot_L":(-12,0,0),"Foot_R":(12,0,0)},
"GroupAdvance":{"Chest":(-10,0,0),"Leg_L":(28,0,0),"Leg_R":(-28,0,0),"Arm_L":(-26,0,0),"Arm_R":(26,0,0),"Head":(4,-12,0)},
"Turn":{"Pelvis":(0,16,0),"Chest":(0,20,0),"Head":(0,19,0),"Leg_R":(12,0,0)},
"Hop":{"Chest":(-14,0,0),"Leg_L":(-32,0,0),"Leg_R":(-32,0,0),"Arm_L":(-31,0,-12),"Arm_R":(-31,0,12)},
"Fall":{"Head":(14,0,0),"Arm_L":(8,0,-41),"Arm_R":(8,0,41),"Leg_L":(20,0,0),"Leg_R":(-12,0,0)},
"Land":{"Chest":(-26,0,0),"Leg_L":(-27,0,0),"Leg_R":(-27,0,0),"Head":(19,0,0)},
"Attack66":{"Chest":(-19,-24,0),"Arm_R":(64,-12,14),"Elbow_R":(31,0,0),"Arm_L":(-30,0,0),"Head":(13,18,0),"Jaw":(15,0,0)},
"Attack68":{"Chest":(-24,8,0),"Arm_L":(47,0,-24),"Arm_R":(47,0,24),"Leg_L":(-30,0,0),"Leg_R":(-42,0,0),"Head":(16,0,0),"Jaw":(21,0,0)},
"Recover":{"Chest":(10,11,0),"Arm_R":(-20,0,0),"Head":(-8,-7,0)},
"ReactLight":{"Head":(19,12,-9),"Chest":(12,0,0),"Arm_L":(-15,0,-22)},
"ReactHeavyGround":{"Pelvis":(-85,0,-8),"Chest":(-5,0,0),"Head":(59,0,0),"Arm_L":(29,0,-24),"Arm_R":(29,0,24)},
"HeavyRecover":{"Pelvis":(-85,0,-8),"Chest":(-5,0,0),"Head":(59,0,0),"Arm_L":(29,0,-24),"Arm_R":(29,0,24)},
"DeathAir":{"Pelvis":(24,9,30),"Chest":(19,0,0),"Arm_L":(-26,0,-48),"Arm_R":(23,0,37)},
"DeathGround":{"Pelvis":(2,0,77),"Chest":(21,0,0),"Head":(-13,0,-7),"Leg_R":(21,0,0)},
"Remove":{"Pelvis":(2,0,77),"Chest":(21,0,0),"Head":(-13,0,-7),"Leg_R":(21,0,0)}}


def envelope(name):
    sequence=[(1,0),(7,1),(13,0)]
    if name in ['Step','GroupAdvance','IdleAlert']:sequence=[(1,0),(7,1),(13,0),(19,-1),(25,0)]
    if name=='Attack66':sequence=[(1,0),(5,-.32),(9,1),(13,.18),(17,.9),(22,0)]
    if name=='Attack68':sequence=[(1,0),(6,-.48),(12,1),(18,.64),(25,0)]
    if name in ['ReactHeavyGround','DeathAir','DeathGround']:sequence=[(1,0),(8,1),(16,1)]
    if name=='HeavyRecover':sequence=[(1,1),(7,.7),(16,0)]
    if name=='Remove':sequence=[(1,1),(12,1)]
    return sequence
