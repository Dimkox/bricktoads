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
-- 1F is a folded-leg windup, not the extended1E morph. Its silhouette remains
-- an authored joint-pose approximation. Source uppercut1A is a different move.
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
    [0x1F]=pose({Waist={.16,0,0},LeftShoulder={1,0,-.25},LeftElbow={.8,0,0},
        RightShoulder={.7,0,.25},RightElbow={1.1,0,0},LeftHip={-.15,0,0},
        RightHip={1.1,0,.1},RightKnee={-1.3,0,0},RightAnkle={.35,0,0}}),
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
local ACTIONS={HeroJab=0x02,HeroUppercut=0x06,HeroPowerPunch=0x0E,HeroKick=0x12,
    HeroBoot=0x14,HeroElbow=0x36,Dash=0x16}
local CALLS_PER_SECOND=60
local DISTANCE_PER_PHASE=1.25
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function cancel(state,attack)
    state.sequence=nil
    if attack then state.observedAttack=attack;state.observedAction=attack.action end
end
function Presentation.new() return {gaitPhase=0} end
local function locomotion(state,c,events)
    local mode=(c.mode=='Walk' or c.mode=='Run') and finite(c.speed) and c.speed>.5 and c.mode or 'Idle'
    if mode=='Idle' then state.gaitPhase=0
    else state.gaitPhase=(state.gaitPhase+math.clamp(c.dt or 0,0,.1)*math.clamp(c.speed,0,80)/DISTANCE_PER_PHASE)%8 end
    local phase=math.floor(state.gaitPhase+1e-7)
    local frame=Animation.heroFrame(mode,{phase=phase})
    return {kind=mode,frameId=frame,joints=POSES[frame],locomotionPhase=phase,
        adaptation='Authored3DJointAngles',events=events or EMPTY}
end
function Presentation.sample(state,c)
    if type(c)~='table' or not finite(c.now) then cancel(state);return nil,'InvalidContext' end
    local attack=c.attack
    if state.actorId~=c.actorId then
        state.actorId=c.actorId;state.sequence=nil;state.observedAttack=nil;state.observedAction=nil
        state.invalidAttack=nil;state.lastNow=nil;state.reactionEpoch=nil;state.gaitPhase=0
    end
    if state.lastNow and c.now<state.lastNow then
        cancel(state,attack);state.lastNow=c.now;return nil,'ClockRewind'
    end
    state.lastNow=c.now
    if state.reactionEpoch~=nil and state.reactionEpoch~=c.reactionEpoch then state.sequence=nil end
    state.reactionEpoch=c.reactionEpoch
    local blocked=c.enabled~=true and 'Disabled' or c.blocked or (c.grounded==false and 'Airborne')
    if blocked then cancel(state,attack);state.gaitPhase=0;return nil,blocked end
    local fear=c.fearIntro
    if type(fear)=='table' and type(fear.id)=='string' and #fear.id>0 and fear.actorId==c.actorId
        and finite(fear.counter) and fear.counter%1==0 and fear.counter>=1 and fear.counter<255
        and ((fear.frameId==0x32 and fear.counter<=0xE0) or (fear.frameId==0x33 and fear.counter>0xE0)) then
        -- The server's finite intro reassigns fear; no animation byte writes
        -- here move a physical body or block accepted player intents.
        cancel(state,attack);state.gaitPhase=0
        return {kind='Fear',animationId=fear.frameId==0x32 and 0x2C or 0x2E,frameId=fear.frameId,
            introId=fear.id,sourceCounter=fear.counter,morphKind=fear.frameId==0x32 and 'FearBeforeCut' or 'FearAfterCut',
            adaptation='Authored3DJointAngles',joints=POSES[fear.frameId],events=EMPTY}
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
        local calls=math.clamp(math.floor(math.max(0,c.now-sequence.start)*CALLS_PER_SECOND+1e-7),0,4096)
        local clock={elapsedCalls=calls,callerMask=1,firstFrameCounterPhase=0,firstRead='Read'}
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
            return {kind='Attack',action=sequence.action,animationId=sequence.id,frameId=sample.frameId,
                sourceCall=calls,sourcePhase=0,sourceCallerMask=1,clockBasis=sequence.basis,
                morphKind=sample.frameId==0x1C and 'PowerFist' or (sample.frameId==0x1E and 'BigBoot' or nil),
                adaptation='Authored3DJointAngles',joints=joints,events=table.freeze(events)}
        end
        state.sequence=nil
        return locomotion(state,c,table.freeze(events))
    end
    return locomotion(state,c)
end
Presentation.provenance=table.freeze({sourceCommit=Animation.provenance.commit,sourceCatalogSha256=Animation.provenance.sourceCatalogSha256,
    firstFrameCounterPhase=0,firstRead='Read',callerMask=1,callsPerSecond=CALLS_PER_SECOND,
    locomotionStudsPerPhase=DISTANCE_PER_PHASE,adaptation='Authored3DJointAngles',
    scope='IdleWalkRunSevenAcceptedActionsAndFirstBossFear',
    morphBindings='Graphics1C=PowerFist;Graphics1E=BigBoot;RightLimb3DAdaptation',
    pending='RemainingMorphMeshes;Folded1FWindupSilhouette;CompleteFearBodySilhouette;AirborneSourceZMapping;Carry;Club;Damage;Death'})
return Presentation
