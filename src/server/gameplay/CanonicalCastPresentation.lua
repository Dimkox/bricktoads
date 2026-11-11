-- Source graphics/bytecode are separate from authored 3D articulation.
-- Every returned command is a cosmetic marker; this module has no world effects.
local Animation=if script then require(script.Parent.CanonicalAnimation) else require('./CanonicalAnimation')
local Walker=if script then require(script.Parent.CanonicalWalker) else require('./CanonicalWalker')
local Profiles=if script then require(script.Parent.CanonicalCastProfiles) else require('./CanonicalCastProfiles')
local P={}
local groups={Pig='Biped',Walker='Walker',Dragon='Dragon',Raven='Bird',LargeRaven='Bird',HealingFly='Bird',
    Invader='Biped',RocketRat='Rider',Snowman='Biped',SentryDrone='Machine',GasTurret='Machine',
    RetroBlaster='Machine',SaturnToadtrap='Trap',Robot='Machine',Slug='Slug',Electrofish='Fish',
    Hammerfish='Fish',Shark='Fish',Duck='Duck',Hordhead='Head',Swellcheeks='Head',FlyingHead='Head',
    RacingRat='Quadruped',Snake='Snake',BigBlag='Blag',RoboManus='RobotBoss',
    GeneralSlaughter='Bull',Buzzball='Orb',DarkQueen='Queen'}
local clips={Pig={PigJab=0x28,PigHeavy=0x2A,PigRush=0x40,EnemyRunStrike=0x40},
    Walker={WalkerLight=0x3C,WalkerHeavy=0x3A,EnemyRunStrike=0x3A},
    Dragon={DragonHeadbutt=0x32,Capture=0x34},BigBlag={Hop=0x84,BellyDrop=0x84},
    GeneralSlaughter={Charge=0x86,Headbutt=0x86},RoboManus={Burst=0x88,Jump=0x88},
    DarkQueen={Sweep=0x8A,Spin=0x8A},Raven={Swoop=0x30},SaturnToadtrap={Snap=0x42},
    RetroBlaster={Bolt=0x4A},Snowman={Snowball=0x58},Hordhead={Roll=0x6C},
    RocketRat={DropObstacle=0x6E},Hammerfish={Lunge=0x7E},Shark={Bite=0x7C},Duck={Bite=0x80}}
local masks={Pig=3,Walker=0,Dragon=3,BigBlag=1,GeneralSlaughter=1,RoboManus=1,DarkQueen=1,
    Raven=3,SaturnToadtrap=1,RetroBlaster=3,Snowman=3,Hordhead=3,RocketRat=0,Hammerfish=1,Shark=1,Duck=1}
local high={BigBlag=true,GeneralSlaughter=true,RoboManus=true,DarkQueen=true,Hammerfish=true,Shark=true,Duck=true}
local names={};for kind in pairs(groups) do names[#names+1]=kind end;table.sort(names);table.freeze(names)
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function joint(x,y,z) return {x or 0,y or 0,z or 0} end
local JOINT_NAMES={'Body','Head','Jaw','LeftArm','RightArm','LeftLeg','RightLeg','LeftFoot','RightFoot',
    'Tail','LeftWing','RightWing','LeftFin','RightFin','Fin','Weapon','Hair','Cape','Spikes','Tongue','Cheeks','LeftLowerLeg','RightLowerLeg'}
local function neutral()
    local j={};for _,name in ipairs(JOINT_NAMES)do j[name]=joint()end;return j
end
-- Decoded graphics select these poses, not a second arbitrary attack phase.
-- Source sprites do not contain skeleton angles: every angle is authored3D.
local FRAME_POSES={
    Pig={
        [2]={Body={.04},Head={.03},LeftArm={.25,0,-.12},RightArm={.25,0,.12}},
        [3]={Body={.06},Head={.02},LeftArm={-.35,0,-.12},RightArm={.35,0,.12},LeftLeg={.55},RightLeg={-.55}},
        [4]={Body={.04},Head={-.02},LeftArm={.35,0,-.12},RightArm={-.35,0,.12},LeftLeg={-.55},RightLeg={.55}},
        [5]={Body={-.18},Head={-.25},Jaw={.05},LeftArm={2.25,0,-.4},RightArm={2.25,0,.4},LeftLeg={.18},RightLeg={.18}},
        [6]={Body={.3},Head={.18},Jaw={.25},LeftArm={1.45,0,-.2},RightArm={1.85,0,.15},LeftLeg={.6},RightLeg={-.4}},
        [7]={Body={-.25},Head={-.3},Jaw={.2},LeftArm={.6,0,-.3},RightArm={.6,0,.3}},
        [8]={Body={-.4},Head={.3},LeftArm={.8,0,-.3},RightArm={.8,0,.3},LeftLeg={.8},RightLeg={.8}},
    },
    Dragon={
        [9]={Head={.02},Jaw={.05},LeftWing={0,.12,.65},RightWing={0,-.12,-.65},LeftLeg={.35},RightLeg={.35},Tail={0,.15}},
        [10]={Body={.08},Head={.2},Jaw={.02},LeftWing={0,.12,-.35},RightWing={0,-.12,.35},LeftLeg={.5},RightLeg={.5},Tail={0,-.15}},
        [11]={Body={.2},Head={-.6},Jaw={.6},LeftWing={0,.12,.15},RightWing={0,-.12,-.15},LeftLeg={.3},RightLeg={.3}},
        [12]={Body={-.25},Head={-.3},Jaw={.2},LeftWing={0,.12,-.1},RightWing={0,-.12,.1},LeftLeg={.6},RightLeg={.6}},
    },
    BigBlag={
        [0xEF]={Body={.08},Head={.1},LeftArm={-.7,0,-.25},RightArm={-.7,0,.25},LeftLeg={.3},RightLeg={.3}},
        [0xF1]={Body={-.25},Head={-.1},LeftArm={1.2,0,-.35},RightArm={1.2,0,.35},LeftLeg={.8},RightLeg={.8}},
    },
    GeneralSlaughter={
        [0xF2]={Body={.12},Head={.1},LeftArm={.2},RightArm={.2},LeftLeg={.45},RightLeg={-.45}},
        [0xF3]={Body={.25},Head={.55},LeftArm={-.6,0,-.2},RightArm={-.6,0,.2},LeftLeg={.3},RightLeg={.3}},
        [0xF4]={Body={.35},Head={-.45},LeftArm={1.2,0,-.2},RightArm={1.2,0,.2},LeftLeg={-.5},RightLeg={.5}},
        [0xF5]={Body={-.25},Head={-.3},LeftArm={.6,0,-.3},RightArm={.6,0,.3}},
        [0xF6]={Body={.1},Head={.08},LeftArm={.2},RightArm={.2},LeftLeg={-.45},RightLeg={.45}},
    },
    RoboManus={
        [0xF7]={Body={-.15},Head={.1},LeftArm={.6},RightArm={.6},LeftLeg={1},RightLeg={.5},Weapon={.1}},
        [0xF8]={Head={0},LeftArm={1.1},RightArm={1.1},Weapon={-.15}},
    },
    DarkQueen={
        [0x81]={Body={.05},Head={.05},LeftArm={.3,0,-.3},RightArm={-.6,0,.35},Hair={.1}},
        [0x82]={Body={-.15},Head={-.1},LeftArm={.65,0,-.4},RightArm={1.5,0,.3},RightLeg={1.1},Hair={.4}},
        -- main.asm14433-14452 selects83 from raw NES Xspeed/counter bits.
        -- Those bytes have no runtime producer here; world speed is not a byte.
        [0x83]={Body={.12},Head={.1},LeftArm={0,0,-1.3},RightArm={0,0,1.3},LeftLeg={.5},RightLeg={.5},Hair={.6}},
    },
}
local function birdPose(wing,head,jaw)
    return {Head={head or 0},Jaw={jaw or .05},LeftWing={0,.12,wing},RightWing={0,-.12,-wing},
        LeftLeg={.35},RightLeg={.35},Tail={0,wing*.2}}
end
FRAME_POSES.Raven={[0x1C]=birdPose(.8),[0x1D]=birdPose(.05),[0x1E]=birdPose(-.65),
    [0x1F]=birdPose(-.2,-.6,.65),[0x20]=birdPose(.3),[0x21]=birdPose(.1)}
FRAME_POSES.LargeRaven={[0x26]=birdPose(.8),[0x27]=birdPose(.05),[0x28]=birdPose(-.65),[0x29]=birdPose(.1)}
FRAME_POSES.Invader={
    [0x24]={Body={-.1},LeftArm={.5},RightArm={.5},LeftLeg={.7},RightLeg={-.5}},
    [0x25]={Body={.1},LeftArm={-.3},RightArm={-.3},LeftLeg={-.5},RightLeg={.7}},
    [0x39]={Body={-.1},LeftArm={2.3},RightArm={2.3},LeftLeg={.7},RightLeg={-.5}},
    [0x3A]={Body={.1},LeftArm={2.3},RightArm={2.3},LeftLeg={-.5},RightLeg={.7}},
}
FRAME_POSES.RocketRat={[0x55]={Body={.2},Head={-.1},LeftArm={.8},RightArm={.8},LeftLeg={1.1},RightLeg={1.1},Weapon={-.1}}}
FRAME_POSES.SaturnToadtrap={[0x5D]={Head={.05},Jaw={.08}},[0x5E]={Head={-.15},Jaw={.95}}}
FRAME_POSES.RetroBlaster={
    [0x60]={Body={-.1},Head={-.2},Weapon={-.3}},[0x61]={Head={.02},Weapon={.02}},
    [0x62]={Body={.1},Jaw={.5},Weapon={-.1}},[0x63]={Head={-.2},Jaw={.8},Weapon={-.2}},[0x80]={Head={.1},Jaw={.7}},
}
FRAME_POSES.Snowman={
    [0x64]={LeftArm={.2},RightArm={.2}},[0x6B]={Body={-.25},Head={-.3},LeftArm={.6,0,-.3},RightArm={.6,0,.3}},
    [0x6C]={Body={-.15},LeftArm={2.3},RightArm={2.3}},[0x6E]={Body={.25},LeftArm={.8},RightArm={1.8}},
}
FRAME_POSES.SentryDrone={[0x9D]={Head={0,.06},Weapon={0,.1}},[0x9E]={Head={0,-.06},Weapon={0,-.1}}}
FRAME_POSES.GasTurret={[0xA5]={Weapon={.12}}}
FRAME_POSES.Robot={[0xD6]={Head={.02},Weapon={.1}},[0xD8]={Head={-.3},Weapon={-.2},Jaw={.2}}}
FRAME_POSES.Slug={
    [0x9F]={Body={.1},Head={.3},Tail={0,.2}},[0xA0]={Head={0},Tail={0,-.15}},
    [0xA1]={Body={-.4},Head={-.2},Jaw={.5}},[0xA2]={Body={0,0,.6},Head={-.1},Tail={0,.3}},
}
local function fishPose(tail,head,jaw)
    return {Body={0,tail*.12},Head={head or 0},Jaw={jaw or .05},Tail={0,tail},
        LeftFin={0,0,tail*.5},RightFin={0,0,-tail*.5}}
end
FRAME_POSES.Electrofish={[0xE2]=fishPose(.35),[0xE3]=fishPose(-.35),[0xE4]=fishPose(.5,-.15),[0xE5]=fishPose(-.5,-.15)}
FRAME_POSES.Hammerfish={[0xD7]=fishPose(.1,-.4,.65),[0xD9]=fishPose(.4),[0xDA]=fishPose(0),[0xDB]=fishPose(-.4)}
FRAME_POSES.Shark={[0xDE]=fishPose(.4),[0xDF]=fishPose(0),[0xE0]=fishPose(-.4),[0xE1]=fishPose(.1,-.5,.7)}
FRAME_POSES.Duck={[0xE7]=birdPose(-.2,.02,.1),[0xE8]=birdPose(.4,-.3,.7),[0xE9]=birdPose(-.1,-.3,.2)}
FRAME_POSES.Hordhead={
    [0xB6]={Body={.15},Head={.1},LeftLeg={-.5},RightLeg={.5}},[0xB7]={Body={-.1},Head={-.1},LeftLeg={.4},RightLeg={-.4}},
    [0xB8]={Body={-.25},Head={.2},LeftLeg={.8},RightLeg={.8}},[0xB9]={Head={-.2},LeftArm={1.2},RightArm={1.2}},
    [0xBA]={Head={.3},LeftArm={1.8},RightArm={1.8}},[0xBB]={Body={-.25},Head={-.3}},
    [0xC6]={Body={.4},Head={-.4},LeftLeg={.5},RightLeg={.5}},
}
FRAME_POSES.FlyingHead={[0xBC]=birdPose(.6,.1),[0xBD]=birdPose(-.4,-.1),[0xC4]={Head={.05},Jaw={.15}}}
FRAME_POSES.Swellcheeks={[0xBC]=birdPose(.3,.05,.1),[0xBD]=birdPose(-.3,-.1,.6)}
FRAME_POSES.RacingRat={
    [0x82]={Body={-.12},Head={.03},LeftArm={-.5},RightArm={.5},LeftLeg={.5},RightLeg={-.5},Tail={0,.2}},
    [0x83]={Body={-.12},Head={-.03},LeftArm={.5},RightArm={-.5},LeftLeg={-.5},RightLeg={.5},Tail={0,-.2}},
    [0x84]={Body={-.2},LeftArm={.8},RightArm={.8},LeftLeg={.9},RightLeg={.9},Tail={0,.1}},
}
FRAME_POSES.Buzzball={
    [0x7C]={Body={0,0,0},Fin={0,0,0}},[0x7D]={Body={0,0,math.pi/2},Fin={0,.2}},
    [0x7E]={Body={0,0,math.pi},Fin={0,0,0}},[0x7F]={Body={0,0,-math.pi/2},Fin={0,-.2}},
}
FRAME_POSES.Snake={
    [0x92]={Head={0,0},Jaw={.08}},[0x93]={Head={0,.5},Jaw={.08}},[0x94]={Head={0,-.5},Jaw={.08}},
    [0x95]={Head={0,.8},Jaw={.08}},[0x96]={Head={0,-.8},Jaw={.08}},[0x97]={Head={0,math.pi},Jaw={.08}},
    [0x98]={Head={.3}},[0x99]={Head={.5}},[0x9A]={Head={-.2}},
}
local function framePose(result,frame,priority)
    local values=FRAME_POSES[result.kind] and FRAME_POSES[result.kind][frame]
    if values and priority~='Dead' and priority~='Carried' then
        local j=neutral();for name,angles in pairs(values)do j[name]=joint(table.unpack(angles))end;result.joints=j
    end
end
local function priorityPose(priority)
    local j=neutral()
    if priority=='Dead' then j.Body=joint(0,0,1.45);j.Head=joint(.4);j.Jaw=joint(.3);j.LeftArm=joint(.4,0,-.5);j.RightArm=joint(.4,0,.5)
    elseif priority=='Reaction' then j.Body=joint(-.25);j.Head=joint(-.3);j.Jaw=joint(.2);j.LeftArm=joint(.6,0,-.3);j.RightArm=joint(.6,0,.3)
    else j.Body=joint(0,0,1.2);j.LeftArm=joint(.8);j.RightArm=joint(.8)end
    return j
end
function P.kinds() return names end
function P.new() return {} end
function P.cancel(state)
    if state.sequence and state.seen then state.seen[state.sequence.attack]=true end
    state.sequence=nil;state.spinAttack=nil
end
local function queenSpin(result,state,c,authored)
    if c.kind=='DarkQueen'and c.phase=='Active'and state.spinAttack and state.spinAttack==c.attack then
        -- The accepted gameplay Spin can outlast its decoded81/82 clip.
        -- Keep the authored spin on the imported Hair/body instead of letting
        -- the representative neutral source frame replace the whole action.
        for _,name in ipairs({'Body','LeftArm','RightArm','Hair'})do result.joints[name]=authored[name]end
        result.actionBinding='Authored3DSpin'
    end
    return result
end
local function articulation(group,c,state)
    local t=c.now-state.started;local speed=math.clamp(c.speed or 0,0,40)
    local cycle=math.sin(t*(group=='Bird' and 12 or 7)+.25)
    local stride=cycle*math.min(speed/12,1)*.65
    local j={Body=joint(),Head=joint(),Jaw=joint(),LeftArm=joint(),RightArm=joint(),
        LeftLeg=joint(stride),RightLeg=joint(-stride),Tail=joint(0,cycle*.18)}
    if group=='Bird' or group=='Dragon' then
        local wing=c.mode=='Disabled' and .15 or math.sin(t*12+.25)*.65
        j.LeftWing=joint(0,.12,wing);j.RightWing=joint(0,-.12,-wing)
        j.Tail=joint(0,cycle*.2);j.LeftLeg=joint(.35);j.RightLeg=joint(.35)
        j.Head=joint(c.phase=='Active' and -.4 or 0)
    elseif group=='Fish' or group=='Duck' then
        j.Body=joint(0,cycle*.08);j.Tail=joint(0,math.sin(t*10+.25)*.5)
        j.LeftFin=joint(0,0,cycle*.35);j.RightFin=joint(0,0,-cycle*.35)
    elseif group=='Machine' or group=='RobotBoss' then
        j.Weapon=joint(0,cycle*.06);j.LeftArm=joint(-stride*.4);j.RightArm=joint(stride*.4)
        j.LeftLeg=joint(stride*.6);j.RightLeg=joint(-stride*.6)
    elseif group=='Quadruped' then
        j.LeftArm=joint(-stride);j.RightArm=joint(stride)
        j.Body=joint(-.12,0,0);j.Tail=joint(0,cycle*.3)
    elseif group=='Snake' or group=='Slug' then
        j.Body=joint(0,cycle*.10);j.Tail=joint(0,cycle*.25);j.Jaw=joint(.08)
    elseif group=='Orb' then
        j.Body=joint(0,t*.7,t*1.7);j.Spikes=joint(0,0,-t*.4)
    elseif group=='Queen' then
        j.Hair=joint(.1+math.sin(t*4)*.08);j.LeftArm=joint(-stride*.5,0,-.1)
        j.RightArm=joint(stride*.5,0,.1);j.Head=joint(0,cycle*.04)
    elseif group=='Trap' then
        j.Jaw=joint(.08);j.Tongue=joint();j.Body=joint()
    elseif group=='Head' then
        j.Head=joint(0,cycle*.12,cycle*.06);j.LeftWing=joint(0,0,cycle*.5)
        j.RightWing=joint(0,0,-cycle*.5);j.Cheeks=joint(0,0,cycle*.08)
    else
        j.LeftArm=joint(-stride*.7,0,-.12);j.RightArm=joint(stride*.7,0,.12)
    end
    if c.phase=='Tell' then
        j.Body=joint(.15);j.Head=joint(.12);j.RightArm=joint(-.8,0,.25)
        if group=='Bull' then j.Head=joint(.55);j.Body=joint(.25) end
    elseif c.phase=='Active' then
        j.RightArm=joint(1.5,0,-.2);j.LeftArm=joint(.65);j.Jaw=joint(.55)
        if group=='Bull' then j.Head=joint(-.45);j.Body=joint(.25)
        elseif group=='Queen' and c.attack and c.attack.name=='Spin' then
            j.Body=joint(0,t*15);j.LeftArm=joint(0,0,-1.3);j.RightArm=joint(0,0,1.3)
        elseif group=='RobotBoss' then j.Weapon=joint(-.15);j.LeftArm=joint(1.1);j.RightArm=joint(1.1)
        elseif group=='Machine' then j.Weapon=joint(-.2)
        elseif group=='Blag' then j.Body=joint(-.25);j.LeftArm=joint(1.2);j.RightArm=joint(1.2)
        elseif group=='Trap' then j.Jaw=joint(.95);j.Tongue=joint(-.2) end
    elseif c.phase=='Recovery' then j.Body=joint(.1);j.RightArm=joint(.4) end
    -- Keep long-running cosmetic phases bounded; CFrame's trigonometry is periodic.
    for _,angles in pairs(j) do for i,n in ipairs(angles) do angles[i]=(n+math.pi)%(2*math.pi)-math.pi end end
    return j
end
function P.sample(state,c)
    if type(state)~='table' or type(c)~='table' or not groups[c.kind] or type(c.actorId)~='string'
        or c.actorId=='' or not finite(c.now) or (c.speed~=nil and not finite(c.speed)) then return nil,'INVALID_CONTEXT' end
    if state.actorId~=c.actorId or state.levelEpoch~=c.levelEpoch or state.kind~=c.kind then
        table.clear(state);state.actorId=c.actorId;state.levelEpoch=c.levelEpoch;state.kind=c.kind;state.started=c.now
        state.seen=setmetatable({},{__mode='k'})
    end
    if state.lastNow and c.now<state.lastNow then P.cancel(state);return nil,'CLOCK_REWIND' end
    state.lastNow=c.now
    local attack=c.attack
    if attack~=nil and (type(attack)~='table' or attack.actorId~=c.actorId or attack.levelEpoch~=c.levelEpoch) then
        P.cancel(state);return nil,'STALE_ATTACK'
    end
    if state.sequence and state.sequence.attack==attack and (attack.name~=state.sequence.name or attack.start~=state.sequence.acceptedStart) then
        P.cancel(state);return nil,'ATTACK_CHANGED'
    end
    if state.spinAttack and state.spinAttack==attack and(attack.name~='Spin'or attack.start~=state.spinStart)then
        P.cancel(state);return nil,'ATTACK_CHANGED'
    end
    local priority=c.dead and 'Dead' or c.reacting and 'Reaction' or c.carried and 'Carried' or nil
    local profile=Profiles.get(c.kind)
    local result={kind=c.kind,appliesDamage=false,state=priority or c.phase or c.mode or 'Idle',
        adaptation='Authored3DJointAngles',namespace=profile.namespace,spriteNamespace=profile.spriteNamespace,bankRecipe=profile.bankRecipe,
        joints=priority and priorityPose(priority) or articulation(groups[c.kind],c,state),events={}}
    local authored=result.joints
    local phase=math.floor(math.max(0,c.now-state.started)*8)
    if priority then
        if attack then state.seen[attack]=true end;state.sequence=nil;state.spinAttack=nil
        local selector=priority=='Dead' and 'Dead' or priority=='Carried' and (c.kind=='Raven' and 'CarriedCorpse' or 'CarriedOrDisabled')
            or (c.reactionHeavy and 'HeavyReaction' or 'LightReaction')
        local selected=Profiles.sample(c.kind,{state=selector,phase=phase,timerRaw=c.reactionTimerRaw,speed=c.speed})
        if not selected and priority=='Reaction' then selected=Profiles.sample(c.kind,{state='Reaction',phase=phase,speed=c.speed})end
        if not selected and priority=='Reaction' and c.reactionTimerRaw==nil then
            -- Seconds are not an NES timer byte. The 3D reaction phase selects
            -- between verified source silhouettes without fabricating a raw counter.
            local progress=finite(c.reactionProgress) and math.clamp(c.reactionProgress,0,1) or 0
            if c.kind=='Pig' then
                -- main.asm:16703-16720 keeps light7 ->4 separate from heavy5 ->8.
                selected={frameId=progress<.5 and (c.reactionHeavy and 5 or 7) or (c.reactionHeavy and 8 or 4),
                    frameBasis='Authored3DReactionPhaseMapping'}
            elseif c.kind=='Dragon' and not c.reactionHeavy then
                -- main.asm:2997-3001 returns0C to the normal9/9/0A/0A table.
                -- The halfway boundary and 8Hz cycle index are authored3D clocks.
                local frame=0xC
                if progress>=.5 then frame=Profiles.sample(c.kind,{state='Fly',phase=phase}).frameId end
                selected={frameId=frame,frameBasis='Authored3DReactionPhaseMapping'}
            end
        end
        if selected then result.frameId=selected.frameId;result.frameBasis=selected.frameBasis;framePose(result,result.frameId,priority)end
        return result
    end
    local clip=attack and clips[c.kind] and clips[c.kind][attack.name]
    if attack and (not state.sequence or state.sequence.attack~=attack) then
        state.sequence=nil
        if state.spinAttack~=attack then state.spinAttack=nil end
        if clip and not state.seen[attack] then
            state.seen[attack]=true
            if c.kind=='DarkQueen'and attack.name=='Spin'then state.spinAttack=attack;state.spinStart=attack.start end
            state.sequence={attack=attack,name=attack.name,acceptedStart=attack.start,id=clip,
                start=finite(attack.start) and math.min(attack.start,c.now) or c.now,lastCall=-1}
        end
    elseif not attack and c.phase~='Recovery' then state.sequence=nil end
    if not attack then state.spinAttack=nil end
    local sequence=state.sequence
    if sequence then
        local calls=math.clamp(math.floor((c.now-sequence.start)*60+1e-7),0,4096)
        local clock={elapsedCalls=calls,callerMask=masks[c.kind],firstFrameCounterPhase=0,firstRead='Read'}
        local sample=Animation.sampleClock(sequence.id,clock)
        for call=sequence.lastCall+1,calls do
            clock.elapsedCalls=call;local row=Animation.sampleClock(sequence.id,clock)
            if not row then break end
            for _,event in ipairs(row.events) do result.events[#result.events+1]=event end
            if row.ended then break end
        end
        sequence.lastCall=calls
        if sample and not sample.ended then
            result.animationId=sequence.id;result.frameId=sample.frameId;result.sourceCallerMask=masks[c.kind]
            if c.kind=='Walker' then
                local offsets=Walker.attackOffsets(sequence.id,sample.frameId,c.facingLeft==true)
                result.frameId=0x19;result.namespace='WalkerComponents'
                if offsets then result.components=Walker.pose(c.sourceObjectType or 0x11,offsets.firstDelta,offsets.secondDelta) end
            elseif high[c.kind] then result.frameId=bit32.bor(result.frameId,0x80) end
            result.frameBasis='SourceClipWithAuthored3DJointAngles';framePose(result,result.frameId)
            return queenSpin(result,state,c,authored)
        end
        state.sequence=nil
    end
    if c.kind=='Walker' then
        result.frameId=0x19;result.namespace='WalkerComponents'
        local first,second=c.walkerFirstDelta,c.walkerSecondDelta
        if type(first)~='number' or type(second)~='number' then
            if (c.speed or 0)>.5 then
                -- World distance/counter parity is untraced: this local gait
                -- drives the exact source straight-leg renderer explicitly.
                first=math.floor(math.sin((c.now-state.started)*7+.25)*math.min(c.speed,12)*1.5)
                second=-first;result.frameBasis='Authored3DGaitDrivingSourceComponents'
            else first,second=0,0;result.frameBasis='VerifiedNeutralComponents'end
        end
        result.components=Walker.pose(c.sourceObjectType or 0x11,first,second)
    else
        local mode=c.sourceState or c.mode or 'Idle'
        if c.kind=='Dragon' and mode=='Disabled' then mode='HeavyDisabled'
        elseif (mode=='Idle' or mode=='Ground') and (c.speed or 0)>.5 then mode='Walk' end
        local selected=Profiles.sample(c.kind,{state=mode,phase=phase,speed=c.speed,verticalSpeed=c.verticalSpeed,
            timerRaw=c.reactionTimerRaw,frameCounter=c.sourceFrameCounter})
        if not selected then selected=Profiles.sample(c.kind,{state='Neutral'}) end
        if selected then
            local actionJoints=result.joints
            result.frameId=selected.frameId;result.frameBasis=selected.frameBasis
            result.phaseClockBasis='Authored3D8HzCycleCalibration';framePose(result,result.frameId)
            if attack and not clip and (c.phase=='Tell' or c.phase=='Active' or c.phase=='Recovery')then
                for _,name in ipairs({'Body','Head','Jaw','LeftArm','RightArm','Weapon'})do result.joints[name]=actionJoints[name] or joint()end
                result.actionBinding='Authored3DAttackWithoutSourceClip'
            end
        end
    end
    return queenSpin(result,state,c,authored)
end
P.provenance=table.freeze({sourceCommit=Animation.provenance.commit,sourceCatalogSha256=Animation.provenance.sourceCatalogSha256,
    knownAttackCallers='Pig3;Walker0;Dragon3;BigBlag1;GeneralSlaughter1;RoboManus1;DarkQueen1',
    graphicsPostprocessing='BossHighBit OR0x80;Walker stream values are leg endpoints, not graphics frames',
    skeleton='Authored 3D adaptation, not original NES joint angles'})
return P
