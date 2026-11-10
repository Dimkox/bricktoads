local sourceContexts={}
local bossCalls={attach=0,shots={},health={},updates=0}
local bossAdapter={}
function bossAdapter.attach(body)
    bossCalls.attach+=1
    local p=node('Part','ImportedGuardianSurface',body.model);p.Anchored=false;p.Massless=true;p.CanCollide=false
    return true
end
function bossAdapter.shot(body,mode,now)bossCalls.shots[#bossCalls.shots+1]={body=body,mode=mode,now=now}end
function bossAdapter.health(body,raw,maximum,now)bossCalls.health[#bossCalls.health+1]={raw=raw,maximum=maximum,now=now}end
function bossAdapter.update(body,now)
    bossCalls.updates+=1
    assert(body.root:GetNetworkOwner()==nil and not body.root:GetNetworkOwnershipAuto())
end
function bossAdapter.detach(body)bossCalls.detached=body end
local bossWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50},
    {name='GuardianAppearanceHook',guardianAppearance=bossAdapter})
assert(bossWorld:spawnEnemy(-99,'Boss',{x=10,y=3,z=0}))
local guardian=bossWorld.actors[-99]
assert(bossCalls.attach==1 and not guardian.model:FindFirstChild('GuardianBase'),
    'A valid imported model replaces the generic cosmetic builder')
assert(guardian.root.assemblyOwnershipResets>0 and guardian.root:GetNetworkOwner()==nil
    and not guardian.root:GetNetworkOwnershipAuto() and guardian.humanoid.Health==100)
bossWorld:bossShot('Bullet');assert(#bossCalls.shots==1 and bossCalls.shots[1].body==guardian)
bossWorld:enemyHealth(-99,31,47);assert(bossCalls.health[#bossCalls.health].raw==31)
bossWorld:updatePresentation({now=1,combat={}},.1,{[-99]={boss=true}})
assert(bossCalls.updates==1 and bossCalls.shots[1].mode=='Bullet')
local bossBase=bossWorld._base;bossWorld._base=table.clone(bossBase)
bossWorld._base.spawn=function()return false end
assert(not bossWorld:spawnEnemy(-99,'Boss',{x=10,y=3,z=0}) and not bossCalls.detached,
    'A failed replacement cannot detach the existing living Guardian appearance')
bossWorld._base=bossBase
bossWorld:clearActors()
assert(bossCalls.detached==guardian)
print('PASS imported Guardian integration preserves authority and uses distinct shot health and update hooks')
local rejectedBossAdapter=table.clone(bossAdapter);rejectedBossAdapter.attach=function()return false end
local rejectedBossWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50},
    {name='GuardianSafeFallback',guardianAppearance=rejectedBossAdapter})
assert(rejectedBossWorld:spawnEnemy(-99,'Boss',{x=10,y=3,z=0}))
local fallbackBoss=rejectedBossWorld.actors[-99]
assert(fallbackBoss.model:FindFirstChild('GuardianBase') and fallbackBoss.humanoid.Health==100
    and fallbackBoss.root:GetNetworkOwner()==nil and not fallbackBoss.root:GetNetworkOwnershipAuto())
rejectedBossWorld:clearActors()
print('PASS missing or rejected Guardian art retains the existing playable fallback')
local sourceAdapter={attach=function()return true end,update=function(body,context)sourceContexts[body]=context end}
local sourceWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50},
    {name='SourceFrameContext',characterAppearance=sourceAdapter})
assert(sourceWorld:spawn(1,'source-context-p1',nil,false,'Mr. Green'))
assert(sourceWorld:spawn(2,'source-context-p2',nil,false,'Mr. Yellow'))
local sourceBody=sourceWorld.actors[1]
local accepted={action='HeroBoot',actorId='source-context-p1',at=2.1,tuning={windup=.1}}
local sourceState={attack=accepted,reactionEpoch=3,lastStrikeAction='HeroJab',strikeRecoveryUntil=1.8}
local sourceSession={now=2,sourceCombat={},combat={[1]=sourceState,[2]={}}}
sourceBody.root.AssemblyLinearVelocity=vector(8,0,0)
local function capture()
    sourceWorld:updatePresentation(sourceSession,.1,{})
    return assert(sourceContexts[sourceBody],'World must forward trusted context to the real cosmetic hook')
end
local ctx=capture()
assert(ctx.attack==accepted and ctx.actorId=='source-context-p1' and ctx.now==2 and ctx.enabled==true,
    'Presentation must use the accepted server attack table and current body identity')
assert(ctx.reactionEpoch==3 and ctx.recoveryAction=='HeroJab' and ctx.recoveryUntil==1.8)
assert(ctx.speed==8 and ctx.dt==.1 and ctx.grounded==true)
assert(sourceContexts[sourceWorld.actors[2]].attack==nil,'The second actor must not borrow another hero attack')
print('PASS source presentation hook forwards accepted action identity clock movement and recovery per actor')
sourceBody.campaignControl=true
sourceWorld.config.Movement={heroRunSpeed=24,enemyRunSpeed=16,runThresholdRatio=.75}
sourceWorld.campaignModes={mode='Ascent',actors={[1]={grounded=false}}}
assert(capture().visualState=='Air' and capture().grounded==false,'Campaign jumps must reach the source air selector')
sourceBody.campaignControl=nil;sourceWorld.campaignModes=nil;sourceWorld.config.Movement=nil

local function blocked(reason)
    local context=capture()
    if reason=='Paused' then assert(context.blocked==reason,'Paused collider must retain fallback')
    else
        local expected=reason=='Dragon' and 'DragonMounted' or reason=='Airborne' and 'Air' or reason
        assert(context.blocked==nil and context.visualState==expected,'Expected rendered state '..expected)
    end
end
sourceBody.humanoid.Health=0;blocked('Dead');sourceBody.humanoid.Health=100
sourceState.reactionEnd=3;blocked('Reaction');sourceState.reactionEnd=nil
sourceBody.model:SetAttribute('CarryingEnemy',-1);blocked('Carrying');sourceBody.model:SetAttribute('CarryingEnemy',nil)
sourceWorld.enemyCarries[1]={mode='Carried'};blocked('Carried');sourceWorld.enemyCarries[1]=nil
sourceBody.model:SetAttribute('DragonLink','Mounted');blocked('Dragon');sourceBody.model:SetAttribute('DragonLink',nil)
sourceWorld.equippedClubs['source-club']={owner=sourceBody};sourceBody.model:SetAttribute('EquippedClub','source-club')
blocked('Club');sourceWorld.equippedClubs['source-club']=nil;sourceBody.model:SetAttribute('EquippedClub',nil)
sourceBody.root.Anchored=true;blocked('Paused');sourceBody.root.Anchored=false
sourceBody.humanoid.FloorMaterial=enum.Material.Air;blocked('Airborne');sourceBody.humanoid.FloorMaterial=enum.Material.Slate
sourceBody.root.AssemblyLinearVelocity=vector(8,12,0);assert(capture().verticalSpeed==12)
sourceBody.root.AssemblyLinearVelocity=vector(8,0,0)
assert(capture().blocked==nil,'Removing priority must provide fresh locomotion context')
sourceSession.sourceCombat=nil;assert(capture().enabled==false,'Stand/unsupported combat keeps its established retarget')
assert(sourceState.attack==accepted and sourceBody.humanoid.Health==100 and sourceBody.root:GetNetworkOwner()==nil)
sourceWorld.bossIntroState={id='run:intro',counter=0xE1,fearFrame=0x33,
    heroActors={[1]='source-context-p1',[2]='stale-p2'}}
ctx=capture()
assert(ctx.fearIntro and ctx.fearIntro.id=='run:intro' and ctx.fearIntro.actorId=='source-context-p1'
    and ctx.fearIntro.frameId==0x33 and ctx.fearIntro.counter==0xE1,'Forward the captured intro only to its exact actor')
assert(sourceContexts[sourceWorld.actors[2]].fearIntro==nil,'A replacement cannot borrow an earlier body fear')
sourceBody.model:SetAttribute('ActorId','replacement');assert(capture().fearIntro==nil)
sourceBody.model:SetAttribute('ActorId','source-context-p1')
sourceWorld.bossIntroState=nil;assert(capture().fearIntro==nil,'Ending intro removes its presentation context')
local castContexts={}
sourceWorld.castAppearance={attach=function(body,kind) body.castAppearance={kind=kind};return true end,
    update=function(body,context) castContexts[body]=context end}
assert(sourceWorld:spawnEnemy(-1,'Raven',{x=-20,y=3,z=0}))
sourceWorld:enemyIdentity(-1,'real-raven')
local raven=sourceWorld.actors[-1];raven.model:SetAttribute('CampaignMode','EnemyFly')
raven.campaignVelocity=vector(9,0,0)
sourceSession.state={levelEpoch=4}
local enemies={[-1]={kind='Raven'}}
local attack={name='Swoop',at=2.4,move={tell=.4}}
local director={campaignEnemies={states={[-1]={mode='Tell',attack=attack}}}}
sourceWorld:updatePresentation(sourceSession,.1,enemies,director)
local rc=assert(castContexts[raven])
assert(rc.mode=='Fly' and rc.actorId=='real-raven' and rc.levelEpoch==4,'Normalize the real campaign movement channel')
assert(rc.attack.actorId==rc.actorId and rc.attack.levelEpoch==4 and rc.attack.start==2)
assert(sourceWorld:spawnEnemy(-2,'Dragon',{x=-20,y=3,z=8}))
sourceWorld:enemyIdentity(-2,'real-dragon');local dragon=sourceWorld.actors[-2]
dragon.root.AssemblyLinearVelocity=vector(0,0,0);dragon.model:SetAttribute('DragonFlight',true)
enemies[-2]={kind='Dragon'};director.dragons={states={[-2]={mode='Turn'}}}
sourceWorld:updatePresentation(sourceSession,.1,enemies,director)
assert(castContexts[dragon].mode=='Fly','Dragon flight must reach the verified object graphics cycle')
director.dragons.states[-2].mode='Disabled'
enemies[-2].reactionUntil=3;enemies[-2].heavyReaction=true
sourceWorld:updatePresentation(sourceSession,.1,enemies,director)
assert(castContexts[dragon].sourceState=='HeavyDisabled','Disabled Dragon has a distinct source selector')
assert(castContexts[dragon].reactionHeavy==true and castContexts[dragon].reactionProgress==0,
    'Forward the real heavy flag and clearly separate authored phase from a source timer byte')
print('PASS actual campaign cast channels normalize modes and preserve accepted body/epoch identity')
sourceWorld:healingFly('imported-fly',{x=-30,y=5,z=0})
local fly=sourceWorld.healingFlyVisuals['imported-fly']
assert(fly.castActor and fly.castActor.castAppearance.kind=='HealingFly','The collectible must use its imported family')
sourceWorld:updatePresentation(sourceSession,.1,enemies,director)
assert(castContexts[fly.castActor].kind=='HealingFly' and castContexts[fly.castActor].mode=='Fly')
assert(sourceWorld:catchFly(1,'imported-fly'))
assert(not sourceWorld.healingFlyVisuals['imported-fly'] and sourceBody.cosmeticActionEvent.action=='Tongue')
local actionContext=capture();assert(actionContext.visualAction.action=='Tongue' and actionContext.visualAction.actorId=='source-context-p1')
assert(capture().visualAction==actionContext.visualAction,'The same accepted effect must keep one immutable animation identity')
print('PASS imported healing fly stays cosmetic and follows the collectible lifecycle')
local pendingReady=false
local pendingAdapter={attach=function(body,kind)
    if not pendingReady then return false,'CAST_ASSETS_LOADING' end
    body.castAppearance={kind=kind};return true
end,update=function()end}
local pendingWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50},
    {name='PendingCastFallback',castAppearance=pendingAdapter})
assert(pendingWorld:spawnEnemy(-1,'Pig',{x=-20,y=3,z=0}))
local pendingPig=pendingWorld.actors[-1]
pendingWorld:healingFly('pending-fly',{x=-30,y=5,z=0})
local pendingFly=pendingWorld.healingFlyVisuals['pending-fly']
assert(not pendingPig.castAppearance,'A pending Pig cannot have an attached cast')
local visibleFallback=false
for _,p in ipairs(pendingPig.model:GetDescendants()) do
    if p:IsA('BasePart') and (p.Transparency or 0)<1 then visibleFallback=true end
end
assert(visibleFallback,'The existing Pig builder must remain visible')
assert(pendingFly.castActor and not pendingFly.castActor.castAppearance and pendingFly.root.Transparency~=1,
    'A pending fly keeps its body visible and retains an actor for the retry')
pendingReady=true;pendingWorld:updatePresentation({now=4,combat={},state={levelEpoch=1}},.1,{[-1]={kind='Pig'}})
assert(pendingPig.castAppearance.kind=='Pig' and pendingFly.castActor.castAppearance.kind=='HealingFly')
assert(pendingFly.root.Transparency~=1,'Client resource readiness owns fallback visibility')
pendingWorld:clearActors()
print('PASS pending enemy and collectible assets keep a visible fallback and attach after resource readiness')
sourceWorld:clearActors()
print('PASS source context gives death reaction carry club Dragon air and paused states priority without altering combat')
print('PASS fear context uses captured actor identity and never leaks to replaced bodies')

-- Weld target/initial grip contracts only. Native doubles do not solve welds;
-- following the moving mesh during a real swing is checked in Studio.
local gripWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50},{name='CanonicalClubGrip'})
assert(gripWorld:spawn(1,'canonical-club-hero',nil,false,'Mr. Green'))
local gripHero=gripWorld.actors[1]
gripHero.model['Right Arm'].CFrame=frame(20,10,30)
local visual=node('Model','CanonicalPlayer1Appearance',gripHero.model)
local hand=node('Part','RightHand',visual);hand.CFrame=frame(13,5,-4);hand.CFrame.rotationY=math.pi
local wrist=node('Attachment','RightWristRigAttachment',hand)
wrist.CFrame=frame(0,.4,.2);wrist.CFrame.Rotation=frame();wrist.CFrame.Rotation.rotationY=-math.pi
local canonicalState={profile='CanonicalNESHero',ownerModel=gripHero.model,model=visual}
gripHero.appearance=canonicalState
local function assertGrip(target,position)
    local equipped=assert(gripWorld.equippedClubs['canonical-grip'])
    eq(equipped.root.Position,position.X,position.Y,position.Z,'Grip must lie at the selected palm/legacy offset')
    local count=0
    for _,part in ipairs(equipped.model:GetDescendants())do
        if part:IsA('WeldConstraint')then assert(part.Part0==target,'Every weapon piece must follow the same actual selected hand');count+=1 end
    end
    assert(count>0 and gripHero.root:GetNetworkOwner()==nil and not gripHero.root:GetNetworkOwnershipAuto(),
        'Completed cosmetic assembly must retain manual server authority')
    return equipped
end
assert(gripWorld:equipClub('canonical-grip',1))
local handClub=assertGrip(hand,hand.CFrame.Position)
assert(math.abs(handClub.root.CFrame.rotationY or 0)<1e-6,'Wrist rotation must compensate the imported hand Y180 axes')
assert(gripWorld:unequipClub('canonical-grip'))
-- Re-equip at a distinct actual hand pose. The hidden R6 arm stays fixed.
hand.CFrame=frame(14,6,-7);hand.CFrame.rotationX=.8;hand.CFrame.rotationY=math.pi
assert(gripWorld:equipClub('canonical-grip',1));local posedClub=assertGrip(hand,hand.CFrame.Position)
assert(math.abs(posedClub.root.CFrame.rotationX-.8)<1e-6,'Grip must preserve the current visible hand pose')
assert(gripWorld:unequipClub('canonical-grip'))
print('PASS canonical club welds every piece to the actual posed hand with palm position and corrected wrist axes')

for _,invalid in ipairs({'WrongOwner','DetachedAppearance','LegacyProfile','MissingWrist','WrongWristClass','DetachedHand'})do
    gripHero.appearance=canonicalState;canonicalState.ownerModel=gripHero.model;canonicalState.profile='CanonicalNESHero'
    visual.Parent=gripHero.model;hand.Parent=visual;wrist.Parent=hand;wrist.ClassName='Attachment'
    if invalid=='WrongOwner'then canonicalState.ownerModel=node('Model','OldOwner')
    elseif invalid=='DetachedAppearance'then visual.Parent=nil
    elseif invalid=='LegacyProfile'then canonicalState.profile='LegacyGeneratedGreen'
    elseif invalid=='MissingWrist'then wrist.Parent=nil
    elseif invalid=='WrongWristClass'then wrist.ClassName='StringValue'
    elseif invalid=='DetachedHand'then hand.Parent=nil end
    assert(gripWorld:equipClub('canonical-grip',1),'Invalid cosmetics must preserve the established R6 grip')
    local arm=gripHero.model['Right Arm']
    assertGrip(arm,arm.CFrame.Position+vector(0,-1.05,0))
    assert(gripWorld:unequipClub('canonical-grip'))
end
gripHero.appearance=nil
assert(gripWorld:equipClub('canonical-grip',1));assertGrip(gripHero.model['Right Arm'],vector(20,8.95,30))
assert(gripWorld:unequipClub('canonical-grip'))
gripWorld:clearActors()
print('PASS stale detached malformed and legacy cosmetics retain the established R6 club grip and authority cleanup')
