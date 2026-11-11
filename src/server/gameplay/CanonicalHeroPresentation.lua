-- Cosmetic, source-FRAME driven poses. NES sprites have no 3D skeleton:
-- the angles below are authored 3D adaptations of the decoded source images.
-- No command in a source stream applies damage, motion, health or game state.
local Animation=if script then require(script.Parent.CanonicalAnimation) else require('./CanonicalAnimation')
local Presentation={}
local JOINTS={'Waist','Neck','LeftShoulder','LeftElbow','LeftWrist','RightShoulder','RightElbow','RightWrist',
    'LeftHip','LeftKnee','LeftAnkle','RightHip','RightKnee','RightAnkle'}
local EMPTY=table.freeze({})
local function pose(values)
    local result={}
    for _,name in ipairs(JOINTS) do result[name]=table.freeze(values[name] or {0,0,0}) end
    return table.freeze(result)
end
-- Keyed by graphics frame, NOT the attack opcode or an action's arbitrary phase.
-- Reference: research/canonical-visuals/frames/hero-{01..08,18..23,26,57}.png.
-- 01 is the authored mesh's neutral stance. Verified gfx1C/1E request one
-- enlarged fist/boot; selecting the right limb is an explicit 3D adaptation.
-- 1F is a folded-leg windup, not the extended1E morph. Its compressed/expanded
-- segments below are an authored3D silhouette mapping. Source1A is another move.
local POSES={
    [0x01]=pose({}),[0x02]=pose({}),
    -- Source32 is the asymmetric stretched-jaw fear,33 the frontal scream.
    -- Head geometry and these full-body joint angles are authored3D adaptations.
    [0x32]=pose({Waist={-.14,.55,-.06},Neck={-.12,-.1,-.12},
        LeftShoulder={-.65,0,-.8},LeftElbow={.45,0,0},LeftWrist={0,0,-.15},
        RightShoulder={-.3,0,.65},RightElbow={.7,0,0},RightWrist={0,0,.15},
        LeftHip={-.12,0,-.12},LeftKnee={-.22,0,0},RightHip={.15,0,.12},RightKnee={-.25,0,0}}),
    [0x33]=pose({Waist={.08,0,0},Neck={-.1,0,0},
        LeftShoulder={-.4,0,-1},LeftElbow={.3,0,0},LeftWrist={0,0,-.2},
        RightShoulder={-.4,0,1},RightElbow={.3,0,0},RightWrist={0,0,.2},
        LeftHip={.12,0,-.17},LeftKnee={-.25,0,0},RightHip={.12,0,.17},RightKnee={-.25,0,0}}),
    [0x03]=pose({Waist={-.08,0,0},LeftShoulder={.65,0,-.08},LeftElbow={.75,0,0},
        RightShoulder={.4,0,.08},RightElbow={1,0,0},LeftHip={-.55,0,0},LeftKnee={-.85,0,0},
        LeftAnkle={.25,0,0},RightHip={.3,0,0},RightAnkle={-.1,0,0}}),
    [0x04]=pose({Waist={-.2,0,0},LeftShoulder={-.4,0,-.1},LeftElbow={1.15,0,0},
        RightShoulder={1,0,.1},RightElbow={.9,0,0},LeftHip={.95,0,0},LeftKnee={-1.3,0,0},
        LeftAnkle={.35,0,0},RightHip={-.6,0,0},RightKnee={-.55,0,0},RightAnkle={.25,0,0}}),
    [0x05]=pose({Waist={-.1,0,0},LeftShoulder={1.1,0,-.3},LeftElbow={.5,0,0},
        RightShoulder={.8,0,.3},RightElbow={.6,0,0},LeftHip={-1,0,-.1},LeftKnee={-.9,0,0},
        LeftAnkle={.35,0,0},RightHip={1.1,0,.1},RightKnee={-.15,0,0},RightAnkle={-.2,0,0}}),
    [0x06]=pose({Waist={-.08,0,0},LeftShoulder={.4,0,-.08},LeftElbow={1,0,0},
        RightShoulder={.65,0,.08},RightElbow={.75,0,0},LeftHip={.3,0,0},LeftAnkle={-.1,0,0},
        RightHip={-.55,0,0},RightKnee={-.85,0,0},RightAnkle={.25,0,0}}),
    [0x07]=pose({Waist={-.1,0,0},LeftShoulder={.8,0,-.3},LeftElbow={.6,0,0},
        RightShoulder={1.1,0,.3},RightElbow={.5,0,0},LeftHip={1.1,0,-.1},LeftKnee={-.15,0,0},
        LeftAnkle={-.2,0,0},RightHip={-1,0,.1},RightKnee={-.9,0,0},RightAnkle={.35,0,0}}),
    [0x08]=pose({Waist={-.2,0,0},LeftShoulder={1,0,-.1},LeftElbow={.9,0,0},
        RightShoulder={-.4,0,.1},RightElbow={1.15,0,0},LeftHip={-.6,0,0},LeftKnee={-.55,0,0},
        LeftAnkle={.25,0,0},RightHip={.95,0,0},RightKnee={-1.3,0,0},RightAnkle={.35,0,0}}),
    [0x18]=pose({Waist={.1,-.2,0},LeftShoulder={2.4,0,-.15},LeftElbow={.65,0,0},
        RightShoulder={-.55,0,.2},RightElbow={1.35,0,0},LeftHip={-.2,0,0},RightHip={.3,0,0},RightKnee={-.3,0,0}}),
    [0x19]=pose({Waist={-.16,-.2,0},LeftShoulder={.5,0,-.12},LeftElbow={1.35,0,0},
        RightShoulder={1.6,0,-.12},RightElbow={.08,0,0},RightWrist={0,0,-.1},
        LeftHip={-.25,0,0},LeftKnee={-.2,0,0},RightHip={.35,0,0},RightKnee={-.25,0,0}}),
    [0x1B]=pose({Waist={-.16,.2,0},LeftShoulder={1.6,0,.12},LeftElbow={.08,0,0},
        LeftWrist={0,0,.1},RightShoulder={.5,0,.12},RightElbow={1.35,0,0},
        LeftHip={.35,0,0},LeftKnee={-.25,0,0},RightHip={-.25,0,0},RightKnee={-.2,0,0}}),
    [0x1C]=pose({Waist={-.32,-.3,0},LeftShoulder={.2,0,-.2},LeftElbow={1.1,0,0},
        RightShoulder={1.8,0,-.15},RightElbow={.04,0,0},RightWrist={0,0,-.12},
        LeftHip={-.5,0,0},RightHip={.45,0,0},RightKnee={-.3,0,0}}),
    [0x1D]=pose({Waist={-.12,0,0},LeftShoulder={.55,0,-.15},LeftElbow={1.35,0,0},
        RightShoulder={.55,0,.15},RightElbow={1.35,0,0},LeftHip={.2,0,0},LeftKnee={-.3,0,0},
        RightHip={.2,0,0},RightKnee={-.3,0,0}}),
    [0x1E]=pose({Waist={.28,0,0},LeftShoulder={.9,0,-.3},LeftElbow={.75,0,0},
        RightShoulder={.5,0,.35},RightElbow={1,0,0},LeftHip={-.2,0,0},LeftAnkle={.15,0,0},
        RightHip={2.05,0,.12},RightKnee={-.12,0,0},RightAnkle={-.25,0,0}}),
    [0x1F]=pose({Waist={.4,0,0},LeftShoulder={1,0,-.25},LeftElbow={.8,0,0},
        RightShoulder={.7,0,.25},RightElbow={1.1,0,0},LeftHip={-.15,0,0},LeftKnee={-.3,0,0},
        RightHip={1.45,0,.1},RightKnee={-2.2,0,0},RightAnkle={.85,0,0}}),
    [0x20]=pose({Waist={.2,0,0},LeftShoulder={.7,0,-.35},LeftElbow={1,0,0},
        RightShoulder={.35,0,.3},RightElbow={1.25,0,0},LeftHip={-.25,0,0},LeftKnee={-.15,0,0},
        RightHip={1.6,0,.1},RightKnee={-.1,0,0},RightAnkle={-.18,0,0}}),
    [0x21]=pose({Waist={.08,0,0},LeftShoulder={.75,0,-.2},LeftElbow={1.15,0,0},
        RightShoulder={.45,0,.2},RightElbow={1.3,0,0},RightHip={.8,0,.1},RightKnee={-1.25,0,0}}),
    [0x22]=pose({Waist={-.18,-.15,0},LeftShoulder={.4,0,-.2},LeftElbow={1.2,0,0},
        RightShoulder={2.65,0,-.15},RightElbow={.1,0,0},RightWrist={0,0,-.1},
        LeftHip={-.3,0,0},RightHip={.25,0,0},RightKnee={-.2,0,0}}),
    [0x23]=pose({Waist={-.65,0,0},Neck={.3,0,0},LeftShoulder={-.5,0,-.2},LeftElbow={1.25,0,0},
        RightShoulder={-.5,0,.2},RightElbow={1.25,0,0},LeftHip={-.3,0,0},LeftKnee={-.3,0,0},
        RightHip={.45,0,0},RightKnee={-.35,0,0}}),
    [0x26]=pose({Waist={.12,0,0},LeftShoulder={2.7,0,-.12},LeftElbow={.45,0,0},
        RightShoulder={2.7,0,.12},RightElbow={.45,0,0},LeftHip={-.15,0,0},RightHip={.25,0,0}}),
    [0x57]=pose({Waist={-.4,0,0},Neck={.15,0,0},LeftShoulder={1.3,0,-.18},LeftElbow={1.2,0,0},
        RightShoulder={1.3,0,.18},RightElbow={1.2,0,0},LeftHip={.2,0,0},LeftKnee={-.35,0,0},
        RightHip={.2,0,0},RightKnee={-.35,0,0}}),
}
-- Additional poses follow the decoded silhouettes in hero-source-contact-sheet.
-- Their angles/depth are authored adaptations; a graphics ID is not a 3D rig.
local EXTRA_POSES={
    [0x09]={Waist={0,.3,0},LeftShoulder={.5,0,-.2},RightShoulder={-.3,0,.2},LeftHip={.4,0,0},RightHip={-.4,0,0}},
    [0x0A]={Waist={0,-.3,0},LeftShoulder={-.3,0,-.2},RightShoulder={.5,0,.2},LeftHip={-.4,0,0},RightHip={.4,0,0}},
    [0x0B]={Waist={.45,0,0},Neck={-.2,0,0},LeftShoulder={.7,0,-.2},LeftElbow={.7,0,0},RightShoulder={.7,0,.2},RightElbow={.7,0,0},LeftHip={.4,0,0},LeftKnee={-.8,0,0},RightHip={.4,0,0},RightKnee={-.8,0,0}},
    [0x0D]={Waist={.8,0,0},Neck={-.4,0,0},LeftShoulder={1.1,0,-.15},RightShoulder={1.1,0,.15},LeftHip={.55,0,0},LeftKnee={-1.1,0,0},RightHip={.55,0,0},RightKnee={-1.1,0,0}},
    [0x0E]={Waist={-.15,0,0},LeftShoulder={2.9,0,-.15},LeftElbow={.4,0,0},RightShoulder={2.9,0,.15},RightElbow={.4,0,0},LeftHip={-.25,0,0},RightHip={.3,0,0}},
    [0x0F]={Waist={.4,0,0},LeftShoulder={1.8,0,-.1},RightShoulder={1.8,0,.1},LeftHip={-.35,0,0},RightHip={.4,0,0}},
    [0x10]={LeftShoulder={2.7,0,-.2},LeftElbow={.35,0,0},RightShoulder={2.7,0,.2},RightElbow={.35,0,0},LeftHip={.5,0,0},LeftKnee={-.3,0,0},RightHip={-.5,0,0}},
    [0x11]={LeftShoulder={2.7,0,-.2},LeftElbow={.35,0,0},RightShoulder={2.7,0,.2},RightElbow={.35,0,0},LeftHip={-.15,0,0},RightHip={.15,0,0}},
    [0x12]={LeftShoulder={2.7,0,-.2},LeftElbow={.35,0,0},RightShoulder={2.7,0,.2},RightElbow={.35,0,0},LeftHip={-.5,0,0},RightHip={.5,0,0},RightKnee={-.3,0,0}},
    [0x13]={Waist={-.5,0,0},Neck={.2,0,0},LeftShoulder={.2,0,-1},RightShoulder={.3,0,1},LeftHip={.8,0,-.15},LeftKnee={-.8,0,0},RightHip={-.5,0,.15}},
    [0x14]={Waist={-1.2,0,0},Neck={.3,0,0},LeftShoulder={.8,0,-.8},RightShoulder={.8,0,.8},LeftHip={1.3,0,-.2},LeftKnee={-1.1,0,0},RightHip={1.3,0,.2},RightKnee={-1.1,0,0}},
    [0x15]={Waist={-1.45,0,0},Neck={.3,0,0},LeftShoulder={.2,0,-.6},RightShoulder={.2,0,.6},LeftHip={.3,0,-.15},RightHip={.15,0,.15}},
    [0x16]={Waist={.45,0,0},Neck={-.3,0,0},LeftShoulder={.5,0,-.45},RightShoulder={.5,0,.45},LeftHip={-.2,0,0},RightHip={.2,0,0}},
    [0x1A]={Waist={-.3,0,0},LeftShoulder={.4,0,-.2},LeftElbow={1,0,0},RightShoulder={3.05,0,-.1},RightElbow={.05,0,0},LeftHip={-.2,0,0},RightHip={.2,0,0}},
    [0x24]={Waist={-.6,0,0},LeftShoulder={2.8,0,-.1},RightShoulder={2.8,0,.1},LeftHip={1.3,0,0},LeftKnee={-.9,0,0},RightHip={1.3,0,0},RightKnee={-.9,0,0}},
    [0x28]={Waist={.8,0,0},Neck={-.2,0,0},LeftShoulder={1.15,0,-.2},RightShoulder={1.15,0,.2},LeftHip={.3,0,0},LeftKnee={-.7,0,0},RightHip={.3,0,0},RightKnee={-.7,0,0}},
    [0x29]={Waist={-.15,0,0},Neck={.15,0,0},LeftShoulder={.4,0,-.3},LeftElbow={1.1,0,0},RightShoulder={.4,0,.3},RightElbow={1.1,0,0},LeftHip={-.3,0,0},RightHip={.3,0,0}},
    [0x2A]={Waist={.35,0,0},Neck={-.25,0,0},LeftShoulder={.2,0,-.65},RightShoulder={.2,0,.65},LeftHip={-.3,0,0},RightHip={.3,0,0}},
    [0x2B]={Waist={-1,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.7,0,0},LeftKnee={-.15,0,0},RightHip={1.7,0,0},RightKnee={-.15,0,0}},
    [0x2C]={Waist={-.8,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.8,0,0},LeftKnee={-1.7,0,0},RightHip={1.8,0,0},RightKnee={-1.7,0,0}},
    [0x2D]={Waist={-.1,0,0},LeftShoulder={1,0,-.6},RightShoulder={1,0,.6},LeftHip={1.35,0,-.15},LeftKnee={-.35,0,0},RightHip={1.35,0,.15},RightKnee={-.35,0,0}},
    [0x2E]={LeftShoulder={2.8,0,-.15},RightShoulder={2.8,0,.15},LeftHip={1.3,0,-.15},LeftKnee={-.3,0,0},RightHip={1.3,0,.15},RightKnee={-.3,0,0}},
    [0x30]={Waist={-1.45,0,0},LeftShoulder={.3,0,-.6},RightShoulder={.3,0,.6},LeftHip={.45,0,-.2},RightHip={.45,0,.2}},
    [0x31]={Waist={-.9,0,0},LeftShoulder={-.6,0,-.2},RightShoulder={-.6,0,.2},LeftHip={.4,0,0},LeftKnee={-.3,0,0},RightHip={-.3,0,0}},
    [0x34]={Waist={-.8,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.8,0,0},LeftKnee={-.1,0,0},RightHip={1.8,0,0},RightKnee={-.1,0,0}},
    [0x36]={Waist={-.65,0,0},Neck={.25,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.6,0,0},LeftKnee={-1.5,0,0},RightHip={1.6,0,0},RightKnee={-1.5,0,0}},
    [0x37]={Waist={-.3,0,0},Neck={-.2,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.2,0,0},LeftKnee={-.7,0,0},RightHip={1.2,0,0},RightKnee={-.7,0,0}},
    [0x3F]={Waist={-.15,0,0},LeftShoulder={2.5,0,-.2},RightShoulder={2.5,0,.2},LeftHip={-.3,0,0},RightHip={.3,0,0}},
    [0x40]={Waist={.65,0,0},LeftShoulder={1.3,0,-.2},RightShoulder={1.3,0,.2},LeftHip={.3,0,0},LeftKnee={-.7,0,0},RightHip={.3,0,0},RightKnee={-.7,0,0}},
    [0x43]={Waist={-.5,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={.8,0,0},RightHip={.8,0,0}},
    [0x44]={Waist={.2,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.3,0,0},RightHip={1.3,0,0}},
    [0x4C]={Waist={-.6,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={2,0,0},RightHip={2,0,0}},
    [0x4D]={Waist={-.5,0,0},Neck={-.15,0,0},LeftShoulder={2.9,0,-.1},RightShoulder={2.9,0,.1},LeftHip={1.8,0,0},LeftKnee={-.9,0,0},RightHip={1.8,0,0},RightKnee={-.9,0,0}},
    [0x61]={Waist={.25,0,0},LeftShoulder={1.9,0,-.2},RightShoulder={1.9,0,.2},LeftHip={.8,0,-.15},LeftKnee={-.35,0,0},RightHip={.8,0,.15},RightKnee={-.35,0,0}},
}
for id,values in pairs(EXTRA_POSES) do POSES[id]=pose(values) end
table.freeze(POSES)
local function frozen(value)
    if type(value)=='table' then for _,item in pairs(value)do frozen(item)end;table.freeze(value)end
    return value
end
-- Viewed references: hero-1f/32/33.png. These are deliberate relative segment
-- scales in the imported mesh axes, not pixel-derived anatomy or NES bones.
-- Head is excluded: existing wide-mouth meshes retain their exact dimensions.
local GEOMETRY=frozen({
    [0x1F]={kind='FoldedBootWindup',adaptation='Authored3DSourceSilhouetteMapping',
        parts={UpperTorso={1.08,.8,.95},LowerTorso={1.05,.82,.98},
            RightUpperLeg={1.3,.72,1.2},RightLowerLeg={1.32,.68,1.2},RightFoot={1.25,.78,1.2}},
        offsets={Waist={0,-.06,-.04},RightHip={0,.18,-.12},RightKnee={0,.1,-.1},RightAnkle={0,.04,.06}}},
    [0x32]={kind='FearBeforeCutBody',adaptation='Authored3DSourceSilhouetteMapping',rootOffset={0,.28,0},
        parts={UpperTorso={.56,.82,.72},LowerTorso={.62,.8,.75},
            LeftUpperArm={.52,1.12,.6},RightUpperArm={.52,1.12,.6},LeftLowerArm={.52,1.2,.6},RightLowerArm={.52,1.2,.6},
            LeftHand={.75,1.08,.8},RightHand={.75,1.08,.8},LeftUpperLeg={.62,.94,.7},RightUpperLeg={.62,.94,.7},
            LeftLowerLeg={.58,1.08,.7},RightLowerLeg={.58,1.08,.7},LeftFoot={.85,.8,.9},RightFoot={.85,.8,.9}}},
    [0x33]={kind='FearAfterCutBody',adaptation='Authored3DSourceSilhouetteMapping',rootOffset={0,.4,0},
        parts={UpperTorso={.42,.78,.64},LowerTorso={.48,.8,.65},
            LeftUpperArm={.42,1.25,.58},RightUpperArm={.42,1.25,.58},LeftLowerArm={.42,1.3,.58},RightLowerArm={.42,1.3,.58},
            LeftHand={.62,1.1,.7},RightHand={.62,1.1,.7},LeftUpperLeg={.48,1.08,.65},RightUpperLeg={.48,1.08,.65},
            LeftLowerLeg={.45,1.18,.65},RightLowerLeg={.45,1.18,.65},LeftFoot={.85,.78,.85},RightFoot={.85,.78,.85}}},
})
local ACTIONS={HeroJab=0x02,HeroJabB=0x04,HeroUppercut=0x06,HeroBigUppercut=0x10,
    HeroPowerPunch=0x0E,HeroKick=0x12,HeroBoot=0x14,HeroElbow=0x36,Dash=0x16,
    Club=0x1A,Tongue=0x18,PickupObject=0x08,PickupEnemy=0x0A,Throw=0x0C,BossBallThrow=0x70,
    JumpAttack=0x26,RopeStrike=0x1C,RopeReverseStrike=0x1E,RopeTongue=0x20,RopeKick=0x22,
    RopeWeight=0x24,RopeFastStrike=0x46,RopeBeakStrike=0x48,RopeCannonWeight=0x4E,
    RopeCannonBoot=0x50,RopeRavenStrike=0x52,RopePropellerKick=0x82,
    ClubOverhead=0x3E,HeroFastPunch=0x72,HeroFastUppercut=0x74,HeroFastBoot=0x76,HeroFastElbow=0x78}
local CALLS_PER_SECOND=60
local DISTANCE_PER_PHASE=1.25
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function rawByte(v) return finite(v) and v%1==0 and v>=-128 and v<=255 end
local function cancel(state,attack)
    state.sequence=nil
    if attack then state.observedAttack=attack;state.observedAction=attack.action end
end
function Presentation.new() return {gaitPhase=0} end
function Presentation.cancel(state,attack) cancel(state,attack) end
local function sourcePose(kind,frame,events,basis)
    local joints=POSES[frame]
    if not joints then return nil,'UnknownSourcePose' end
    return {kind=kind,namespace='Hero',frameId=frame,joints=joints,geometry=GEOMETRY[frame],
        frameBasis=basis or 'SourceSelector',adaptation='Authored3DJointAngles',events=events or EMPTY}
end
local function phase(state,c,length)
    if not finite(c.speed) or c.speed<=.5 then state.gaitPhase=0
    else state.gaitPhase=(state.gaitPhase+math.clamp(c.dt or 0,0,.1)*math.clamp(c.speed,0,80)/DISTANCE_PER_PHASE)%length end
    return math.floor(state.gaitPhase+1e-7)
end
local function locomotion(state,c,events)
    local moving=finite(c.speed) and c.speed>.5
    local carrying=c.visualState=='Carrying' or c.holding==true
    local mode=carrying and (moving and 'CarryWalk' or 'CarryIdle')
        or (c.visualState=='DepthWalk' and moving and 'DepthWalk')
        or ((c.mode=='Walk' or c.mode=='Run') and moving and c.mode) or 'Idle'
    local gait=phase(state,c,8)
    if mode=='Idle' then state.gaitPhase=0;gait=0 end
    local frame=Animation.heroFrame(mode,{phase=gait,blink=c.blink})
    local result=sourcePose(mode,frame,events);result.locomotionPhase=gait
    return result
end
local function air(c)
    local raw=c.sourceZSpeedRaw
    local basis='SourceSelector'
    if raw~=nil and not rawByte(raw) then return nil,'InvalidSourceZSpeed' end
    if raw==nil then
        if not finite(c.verticalSpeed) and c.holding~=true then return nil,'MissingAirVelocity' end
        -- Source Z is not a Roblox velocity. This near-apex threshold is a
        -- declared 3D adaptation, never an inferred NES byte conversion.
        raw=finite(c.verticalSpeed) and math.abs(c.verticalSpeed)<=1 and 0 or 5
        basis='Authored3DVelocityMapping'
    end
    return sourcePose('Air',Animation.heroFrame('Air',{zSpeedRaw=raw,holding=c.holding}),nil,basis)
end
local function reaction(c)
    local r=type(c.reaction)=='table' and c.reaction or {}
    local frame,basis
    basis='SourceSelector'
    if r.heavy then
        if r.grounded==true or (r.grounded==nil and c.grounded~=false) then frame=r.planar==true and 0x30 or 0x15
        else
            local raw=c.sourceZSpeedRaw
            if raw~=nil and not rawByte(raw) then return nil,'InvalidSourceZSpeed' end
            local rising
            if raw~=nil then rising=raw%256<128
            else rising=not finite(c.verticalSpeed) or c.verticalSpeed>=0;basis='Authored3DVelocityMapping' end
            frame=rising and 0x13 or 0x14
        end
    elseif rawByte(r.timerRaw) then frame=r.timerRaw%256<0x18 and 2 or (r.fromRear==true and 0x16 or 0x29)
    else
        local elapsed=finite(r.startedAt) and math.max(0,c.now-r.startedAt) or 0
        frame=elapsed>=.15 and 2 or (r.fromRear==true and 0x16 or 0x29)
        basis='Authored3DReactionTiming'
    end
    return sourcePose('Reaction',frame,nil,basis)
end
local function adapted(kind,c,state)
    state.modeStartedAt=state.modeStartedAt or c.now
    local stroke=math.sin(math.max(0,c.now-state.modeStartedAt)*8)
    local values
    if kind=='Dead' then values={Waist={-1.45,0,.3},Neck={.4,0,0},LeftShoulder={.3,0,-.7},RightShoulder={.3,0,.7},LeftHip={.4,0,-.2},RightHip={.4,0,.2}}
    elseif kind=='Carried' then values={Waist={-.4,0,0},LeftShoulder={1.5,0,-.6},RightShoulder={1.5,0,.6},LeftHip={.8,0,0},LeftKnee={-.9,0,0},RightHip={.8,0,0},RightKnee={-.9,0,0}}
    elseif kind=='DragonMounted' or kind=='Ride' then values={Waist={.25,0,0},LeftShoulder={.65,0,-.2},LeftElbow={.7,0,0},RightShoulder={.65,0,.2},RightElbow={.7,0,0},LeftHip={1.2,0,-.25},LeftKnee={-1.15,0,0},RightHip={1.2,0,.25},RightKnee={-1.15,0,0}}
    elseif kind=='DragonCaptured' then values={Waist={-.3,0,0},LeftShoulder={2.6,0,-.25},RightShoulder={2.6,0,.25},LeftHip={.45,0,0},LeftKnee={-.5,0,0},RightHip={.45,0,0},RightKnee={-.5,0,0}}
    elseif kind=='Swim' then values={Waist={-.95,0,0},Neck={.5,0,0},LeftShoulder={1.2+stroke*.7,0,-.2},LeftElbow={.3,0,0},RightShoulder={1.2-stroke*.7,0,.2},RightElbow={.3,0,0},LeftHip={stroke*.45,0,0},LeftKnee={-.4,0,0},RightHip={-stroke*.45,0,0},RightKnee={-.4,0,0}}
    elseif kind=='Rope' then values={Waist={-.1,0,0},LeftShoulder={2.9,0,-.15},RightShoulder={2.9,0,.15},LeftHip={.3+stroke*.1,0,0},LeftKnee={-.3,0,0},RightHip={.3-stroke*.1,0,0},RightKnee={-.3,0,0}}
    elseif kind=='Club' then values={Waist={-.1,0,0},LeftShoulder={.4,0,-.15},LeftElbow={.7,0,0},RightShoulder={.7,0,.2},RightElbow={.6,0,0}}
    else return nil,'UnknownVisualState' end
    return {kind=kind,namespace='Authored3D',joints=pose(values),frameBasis='Authored3DAdaptation',
        adaptation='Authored3DJointAngles',events=EMPTY}
end
local PRIORITY={Dead=true,Reaction=true,Carried=true,DragonMounted=true,DragonCaptured=true}
local COURSE={Swim=true,Ride=true,Rope=true}
local function accepts(kind,action)
    if kind=='Carrying' then return action=='Throw' or action=='BossBallThrow' or action=='PickupObject' or action=='PickupEnemy' end
    if kind=='Club' then return action=='Club' or action=='ClubOverhead' end
    if kind=='Rope' then return type(action)=='string' and action:sub(1,4)=='Rope' end
    if kind=='Swim' or kind=='Ride' or kind=='Air' then return false end
    return true
end
function Presentation.sample(state,c)
    if type(c)~='table' or not finite(c.now) then cancel(state);return nil,'InvalidContext' end
    local attack=c.attack or c.visualAction
    if state.actorId~=c.actorId or state.body~=c.body or state.levelEpoch~=c.levelEpoch then
        state.actorId=c.actorId;state.sequence=nil;state.observedAttack=nil;state.observedAction=nil
        state.body=c.body;state.levelEpoch=c.levelEpoch
        state.invalidAttack=nil;state.lastNow=nil;state.reactionEpoch=nil;state.gaitPhase=0
        state.visualState=nil;state.modeStartedAt=nil
    end
    if state.lastNow and c.now<state.lastNow then
        cancel(state,attack);state.lastNow=c.now;return nil,'ClockRewind'
    end
    state.lastNow=c.now
    if state.reactionEpoch~=nil and state.reactionEpoch~=c.reactionEpoch then cancel(state,attack) end
    state.reactionEpoch=c.reactionEpoch
    local kind=c.visualState
    if kind~=state.visualState then state.modeStartedAt=c.now;state.visualState=kind end
    local blocked=c.enabled~=true and 'Disabled' or c.blocked or (c.grounded==false and not kind and 'Airborne')
    if blocked then cancel(state,attack);state.gaitPhase=0;return nil,blocked end
    if PRIORITY[kind] then
        cancel(state,attack);state.gaitPhase=0
        if kind=='Reaction' then return reaction(c) end
        return adapted(kind,c,state)
    end
    if kind=='Air' then cancel(state,attack);state.gaitPhase=0;return air(c) end
    if kind and kind~='DepthWalk' and kind~='Carrying' and kind~='Club' and not COURSE[kind] then
        cancel(state,attack);return nil,'UnknownVisualState'
    end
    if not accepts(kind,attack and attack.action) then
        cancel(state,attack)
        if kind=='Carrying' then return locomotion(state,c) end
        return adapted(kind,c,state)
    end
    local fear=c.fearIntro
    if type(fear)=='table' and type(fear.id)=='string' and #fear.id>0 and fear.actorId==c.actorId
        and finite(fear.counter) and fear.counter%1==0 and fear.counter>=1 and fear.counter<255
        and ((fear.frameId==0x32 and fear.counter<=0xE0) or (fear.frameId==0x33 and fear.counter>0xE0)) then
        -- The server's finite intro reassigns fear; no animation byte writes
        -- here move a physical body or block accepted player intents.
        cancel(state,attack);state.gaitPhase=0
        return {kind='Fear',animationId=fear.frameId==0x32 and 0x2C or 0x2E,frameId=fear.frameId,
            introId=fear.id,sourceCounter=fear.counter,morphKind=fear.frameId==0x32 and 'FearBeforeCut' or 'FearAfterCut',
            namespace='Hero',frameBasis='SourceSelector',adaptation='Authored3DJointAngles',joints=POSES[fear.frameId],geometry=GEOMETRY[fear.frameId],events=EMPTY}
    end
    if attack and attack==state.observedAttack and attack.action~=state.observedAction then
        state.sequence=nil;state.invalidAttack='AttackChanged'
    elseif attack and attack~=state.observedAttack then
        state.observedAttack=attack;state.observedAction=attack.action;state.sequence=nil;state.invalidAttack=nil
        local id=ACTIONS[attack.action]
        if not id then state.invalidAttack='UnsupportedAttack'
        elseif attack.actorId~=c.actorId then state.invalidAttack='StaleAttack'
        else
            -- This is a local, explicit clock, not the NES global FrameCounter.
            -- 60 calls/s and gait distance are presentation calibration in 3D.
            local start,basis=c.now,'ObservedServerAcceptance'
            if finite(attack.at) and type(attack.tuning)=='table' and finite(attack.tuning.windup)
                and attack.tuning.windup>=0 and attack.at-attack.tuning.windup<=c.now then
                start=attack.at-attack.tuning.windup;basis='AcceptedWindupTimestamp'
            end
            state.sequence={attack=attack,action=attack.action,id=id,start=start,basis=basis,lastCall=-1,
                body=c.body,levelEpoch=c.levelEpoch,
                baselineRecovery=finite(c.recoveryUntil) and c.recoveryUntil or -math.huge}
        end
    end
    if attack and state.invalidAttack then return nil,state.invalidAttack end
    local sequence=state.sequence
    if sequence and attack~=sequence.attack and not sequence.resolved then
        if c.recoveryAction==sequence.action and finite(c.recoveryUntil) and c.recoveryUntil>sequence.baselineRecovery then
            sequence.resolved=true
        else state.sequence=nil;sequence=nil end
    end
    if sequence then
        local result=c.dashResult
        if sequence.branch==nil and sequence.action=='Dash' and type(result)=='table'
            and result.branch=='DashLowLifeTail' and result.profile==3
            and type(sequence.attack.tuning)=='table' and result.tuning==sequence.attack.tuning
            and c.body~=nil and sequence.body==c.body and result.body==c.body
            and finite(c.levelEpoch) and c.levelEpoch%1==0 and c.levelEpoch>=1
            and sequence.levelEpoch==c.levelEpoch and result.levelEpoch==c.levelEpoch
            and result.actorId==c.actorId and finite(result.at) and result.at<=c.now
            and finite(sequence.attack.at) and result.at>=sequence.attack.at and result.at>=sequence.start then
            -- main15829-15840 redirects a confirmed low-Life Dash effect to
            -- byte36; the same E2 call increments it and reads byte37/graphics31.
            -- Resume with Read at call0, retaining the original mask1 parity.
            sequence.branch='DashLowLifeTail';sequence.branchAt=result.at
            sequence.branchPhase=math.floor((result.at-sequence.start)*CALLS_PER_SECOND+1e-7)%2
            sequence.lastCall=-1
        end
        local calls=math.clamp(math.floor(math.max(0,c.now-(sequence.branchAt or sequence.start))*CALLS_PER_SECOND+1e-7),0,4096)
        local clock={elapsedCalls=calls,callerMask=1,firstFrameCounterPhase=sequence.branchPhase or 0,
            firstRead='Read',branch=sequence.branch}
        local sample,code=Animation.sampleClock(sequence.id,clock)
        if not sample then state.sequence=nil;return nil,code end
        local events={}
        for call=sequence.lastCall+1,calls do
            clock.elapsedCalls=call
            local row=Animation.sampleClock(sequence.id,clock)
            if not row then break end
            for _,event in ipairs(row.events) do events[#events+1]=event end
            if row.ended then break end
        end
        sequence.lastCall=calls
        if not sample.ended then
            local joints=POSES[sample.frameId]
            if not joints then state.sequence=nil;return nil,'UnknownSourcePose' end
            return {kind='Attack',namespace='Hero',frameBasis='SourceClip',action=sequence.action,animationId=sequence.id,frameId=sample.frameId,
                sourceCall=calls,sourcePhase=clock.firstFrameCounterPhase,sourceCallerMask=1,clockBasis=sequence.basis,
                sourceBranch=sequence.branch or'Normal',sourceEffectAt=sequence.branchAt,
                morphKind=sample.frameId==0x1C and 'PowerFist' or (sample.frameId==0x1E and 'BigBoot' or nil),
                adaptation='Authored3DJointAngles',joints=joints,geometry=GEOMETRY[sample.frameId],events=table.freeze(events)}
        end
        state.sequence=nil
        if COURSE[kind] or kind=='Club' then
            local result=adapted(kind,c,state);result.events=table.freeze(events);return result
        end
        return locomotion(state,c,table.freeze(events))
    end
    if COURSE[kind] or kind=='Club' then return adapted(kind,c,state) end
    return locomotion(state,c)
end
Presentation.provenance=table.freeze({sourceCommit=Animation.provenance.commit,sourceCatalogSha256=Animation.provenance.sourceCatalogSha256,
    firstFrameCounterPhase=0,firstRead='Read',callerMask=1,callsPerSecond=CALLS_PER_SECOND,
    locomotionStudsPerPhase=DISTANCE_PER_PHASE,adaptation='Authored3DJointAngles',
    scope='HeroSourceSelectorsAndAcceptedClipsWithExplicitCourseAdaptations',
    morphBindings='Graphics1C=PowerFist;Graphics1E=BigBoot;RightLimb3DAdaptation',
    silhouetteBindings='Graphics1F=CompressedFoldedRightLeg;Graphics32/33=NarrowTorsoAndElongatedLimbs;Authored3DRelativeSegmentMapping',
    pending='RemainingMorphMeshes;ExactWorldToSourceZMapping;CompleteModeSpecificDeathTraces',
    courseStates='Swim;Ride;Rope;DragonMounted;DragonCaptured;Carried;Dead are authored3D adaptations, not full source FSM traces'})
return Presentation
