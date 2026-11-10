-- Studio-only prepared Causeway Guardian phase acceptance using native Models.
-- Fixed virtual ticks exercise phase objects, production queries and Session
-- effects; they do not demonstrate Humanoid movement or a natural route clear.
assert(game:GetService('RunService'):IsStudio(),'Studio acceptance only')
local Http=game:GetService('HttpService')
local Lighting=game:GetService('Lighting')
local project=assert(game:GetService('ServerScriptService'):FindFirstChild('BrickToads'),'BrickToads project missing')
local G,R=project.gameplay,project.CombatRuntime
local World=require(G.GameWorld)
require(G.BossIntroWorld)(World)
local Session,Combat=require(R.Session),require(R.Combat)
local Level=require(G.LevelDefinition)
local Config=require(G.GameConfig)(require(R.Config),Level)
local Director,Pattern=require(G.LevelDirector),require(G.GuardianPattern)
local Intro=require(G.BossIntro)(require(G.CanonicalAnimation))
local result={sourceSha256=require(project.BuildInfo).sourceSha256,checks={},phases={},cleanup={},
    fixture='First Causeway; real Session, LevelDirector, GuardianPattern and native GameWorld with authored route geometry',
    preparation='One synthetic hero and boss owner. Ordinary rows are explicitly defeated and the hero is placed at each authored zone exit. Prepared arena stances X604/Y3/Z0 and X624/Y3/Z0. One disclosed physical fall obtains a real paid respawn shield after the first Heavy lands.',
    limitations='Fixed virtual time and prepared positions; native Models, target queries, ground raycasts and exit volume only. No actual Players, queue transport, natural traversal, Humanoid locomotion, device input or network claim.'}
local DT=1/60
local OWNER=900098
local created={}
local ticks=0
local originalFolders={};for _,item in ipairs(workspace:GetChildren()) do originalFolders[item]=true end
local ownedWorldNames={}
local lightingBefore={}
for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do
    lightingBefore[key]=Lighting[key]
end
local originalLightingChildren={};for _,item in ipairs(Lighting:GetChildren()) do originalLightingChildren[item]=true end
local atmosphere=Lighting:FindFirstChild('CausewayAtmosphere')
local atmosphereBefore={}
if atmosphere then
    for _,key in ipairs({'Name','Parent','Density','Offset','Color','Decay','Glare','Haze'}) do atmosphereBefore[key]=atmosphere[key] end
end
local defaults={}
for _,item in ipairs(workspace:GetChildren()) do
    if (item.Name=='Baseplate' and item:IsA('BasePart')) or (item.Name=='SpawnLocation' and item:IsA('SpawnLocation')) then
        defaults[#defaults+1]={original=item,parent=item.Parent}
    end
end
local function check(label,condition) assert(condition,label);result.checks[#result.checks+1]=label end
local function near(a,b) return math.abs(a-b)<.001 end
local function resources(f)
    local h,c=f.session.state.heroes[1],f.session.combat[1]
    return {actorId=h.actorId,attempt=h.attempt,respawns=h.respawns,health=h.health,
        rawLife=c.rawLife,status=h.status,connectionEpoch=h.connectionEpoch}
end
local function unchanged(f,before,label)
    local after=resources(f)
    for key,value in pairs(before) do assert(after[key]==value,label..' changed '..key) end
    check(label,true);return after
end
local function track(f)
    if f.world then for _,body in pairs(f.world.actors) do f.models[body.model]=true end end
    for folder in pairs(f.ownedFolders) do
        for _,item in ipairs(folder:GetDescendants()) do if item:IsA('Model') then f.models[item]=true end end
    end
end
local function sameBoss(f)
    if not f.bossModel then return end
    assert(f.world.actors[-99].model==f.bossModel and f.director.enemies[-99].actorId==f.bossActorId
        and f.bossModel:IsDescendantOf(workspace),'Guardian body or logical actor changed')
end
local function frame(f,delta)
    delta=delta or DT;assert(delta>=0 and delta<=.1,'Unbounded virtual step')
    f.now+=delta
    assert(f.session:step(f.now)=='OK','Session virtual tick rejected')
    f.director:step(f.now,delta)
    sameBoss(f);track(f);ticks+=1
end
local function untilAt(f,deadline)
    assert(deadline>=f.now,'Virtual deadline reversed')
    while f.now<deadline-1e-8 do frame(f,math.min(DT,deadline-f.now)) end
end
local function untilCondition(f,predicate,seconds,label)
    local deadline=f.now+seconds
    while not predicate() do
        assert(f.now<deadline,label..' timed out')
        frame(f,math.min(DT,deadline-f.now))
    end
end
local function heroPrimary(f)
    local h=f.session.state.heroes[1];f.heroSeq+=1
    return f.session:intent(1,{kind='Attack',attack='Punch',runId=f.session.state.runId,
        actorId=h.actorId,attempt=h.attempt,levelEpoch=f.session.state.levelEpoch,
        connectionEpoch=h.connectionEpoch,seq=f.heroSeq},f.now)
end
local function ownerCommand(f,kind,fields,epoch)
    local role=f.director:controlled(OWNER);f.ownerSeq+=1
    local packet={kind=kind,runId=f.session.state.runId,actorId=role.actorId,attempt=role.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=epoch or role.connectionEpoch,seq=f.ownerSeq}
    for key,value in pairs(fields or {}) do packet[key]=value end
    return f.director:command(OWNER,packet,f.now,Session.validIntent)
end
local function projectile(f,mode)
    for id,p in pairs(f.director.projectiles) do if p.mode==mode then return id,p end end
end
local function nativeProjectile(f,id,mode)
    local body=f.world.actors[id]
    return body and body.model:IsDescendantOf(workspace) and body.model:GetAttribute('ProjectileMode')==mode
end
local function phase(name,data)
    data=data or {};data.phase=name;result.phases[#result.phases+1]=data
end
local function begin()
    local worldName='BrickToadsGuardianPhaseQA_'..Http:GenerateGUID(false)
    ownedWorldNames[worldName]=true
    -- Register ownership before either constructor can partially create objects.
    local f={worldName=worldName,ownedFolders={},models={},heroSeq=0,ownerSeq=0,now=workspace:GetServerTimeNow()}
    created[#created+1]=f
    local constructorFolders={};for _,item in ipairs(workspace:GetChildren()) do constructorFolders[item]=true end
    local ok,world=xpcall(function()
        return World.new(require(R.RobloxWorld),Config,{name=worldName,offset={x=0,y=32,z=15360},
            characterAppearance=require(G.CharacterAppearance),guardianAppearance=require(G.GuardianAppearance)})
    end,debug.traceback)
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and not constructorFolders[item] and item:IsA('Folder')
            and (item.Name==worldName or item.Name=='CombatStandWorld') then f.ownedFolders[item]=true end
    end
    if not ok then error(world,0) end
    f.world=world;f.ownedFolders[world.folder]=true
    f.session=Session.new(require(project.RunLifecycle),Combat,Config,{{userId=1,template='Mr. Green'}},
        'native-guardian-phase-'..Http:GenerateGUID(false),world,nil,{groupId='guardian-phase-fixture',levelId=Level.id})
    check('initial native hero commits without resource preparation',f.session:step(f.now)=='OK'
        and f.session.state.heroes[1].status=='Alive' and f.session.combat[1].rawLife==47)
    f.director=Director.new(f.session,world,Combat,Config,Pattern,nil,nil,nil,nil,Intro)
    local originalHit=f.session._hit
    f.session._hit=function(session,attacker,target,action,tuning)
        if type(target)=='number' and target<0 then return f.director:hit(attacker,target,action,tuning) end
        return originalHit(session,attacker,target,action,tuning)
    end
    f.session.contextualAttack=function(slot,now,action) return f.director:interact(slot,now,action) end
    require(G.SourceCombat).bind(f.session,f.director,Config)
    f.director.ownerNames[OWNER]='Synthetic Guardian phase owner'
    f.gateState='Waiting'
    f.director.bossGate=function() return {state=f.gateState,userId=OWNER} end
    track(f);return f
end
local function preparedAssignment(f)
    for index,zone in ipairs(Level.zones) do
        assert(f.director.zoneIndex==index,'Prepared route index differs')
        for id,e in pairs(f.director.enemies) do
            if not e.dead then f.director:_kill(id,'AcceptancePreparedClear') end
        end
        local box=zone.exit
        check('prepared authored zone exit '..index,f.world:placeActor(1,
            {x=(box.minX+box.maxX)/2,y=(box.minY+box.maxY)/2,z=(box.minZ+box.maxZ)/2}))
        frame(f)
    end
    check('assignment waits before native Guardian or pattern exists',f.director.stage=='BossReady'
        and f.world.actors[-99]==nil and f.director.guardian==nil)
    local before=resources(f)
    f.gateState='Human';frame(f)
    check('human assignment begins finite native intro',f.director.stage=='BossIntro'
        and f.world.bossIntroFolder and f.world.bossIntroFolder.Parent==f.world.folder
        and f.world.actors[-99]==nil and f.director.guardian==nil)
    local introStarted=f.director.bossIntro.state.startedAt
    untilAt(f,introStarted+4.25+DT)
    check('finite intro activates native human Guardian once',f.director.stage=='Boss'
        and f.director.guardian and f.director:controlled(OWNER).enemyId==-99
        and f.world.bossIntroFolder==nil)
    unchanged(f,before,'intro preserves hero identity resources and health')
    f.bossModel=f.world.actors[-99].model;f.bossActorId=f.director.enemies[-99].actorId
    f.activeAt=f.director.guardian.nextBall-Config.Boss.ballInterval
    sameBoss(f)
    check('native authored arena supports Guardian',f.world:groundPosition(f.world:position(-99))~=nil)
    phase('AssignmentIntro',{stage=f.director.stage,seconds=f.now-introStarted,ownerUserId=OWNER,
        actorId=f.bossActorId,rawLife=f.director.enemies[-99].rawLife})
end
local function shieldedMelee(f)
    check('prepared native melee stance',f.world:placeActor(1,{x=624,y=3,z=0}))
    f.world:face(1,-99)
    local targets=f.world:targets(1,Config.Attacks.Punch)
    check('production target query contains Guardian first',targets[1]==-99)
    local before=resources(f)
    check('Session accepts ordinary primary against Guardian',heroPrimary(f)=='OK' and f.session.combat[1].attack~=nil)
    untilAt(f,f.now+.15)
    local shielded=false
    for _,row in ipairs(f.session.logs) do if row.kind=='BossShielded' then shielded=true end end
    check('resolved ordinary primary remains shielded',shielded and f.director.bossHits==0
        and f.director.enemies[-99].rawLife==47 and f.director.enemies[-99].health==3)
    unchanged(f,before,'ordinary primary preserves hero resources')
    phase('OrdinaryShield',{nativeTargets=targets,bossRawLife=47,bossHits=0})
end
local function acceptedOfflineBullet(f)
    check('prepared native Bullet contact stance',f.world:placeActor(1,{x=604,y=3,z=0}))
    untilAt(f,f.director.nextShot)
    local origin=f.world:position(-99)
    check('human Move accepts aim without moving Guardian',ownerCommand(f,'Move',{x=-1,z=0,run=false})=='OK'
        and near(f.world:position(-99).x,origin.x) and near(f.world:position(-99).z,origin.z))
    check('human ordinary Bullet accepts at real cooldown deadline',ownerCommand(f,'Attack',{attack='Punch'})=='OK')
    local id,p=projectile(f,'Bullet');assert(id,'Accepted Bullet missing')
    check('accepted Bullet has native phase Model',nativeProjectile(f,id,'Bullet'))
    local before=resources(f);local startX=p.position.x
    local epoch=f.director:controlled(OWNER).connectionEpoch
    check('human owner disconnects without replacement',f.director:connection(OWNER,false)=='OK')
    check('new offline fire is rejected',ownerCommand(f,'Attack',{attack='Punch'})=='OFFLINE')
    untilCondition(f,function() return f.session.combat[1].rawLife<before.rawLife end,4,'accepted offline Bullet contact')
    check('accepted offline Bullet damages through actual Session',p.position.x<startX
        and f.session.combat[1].rawLife==31 and f.director.projectiles[id]==nil and f.world.actors[id]==nil)
    check('Bullet retains hero actor and stocks',f.session.state.heroes[1].actorId==before.actorId
        and f.session.state.heroes[1].attempt==before.attempt and f.session.state.heroes[1].respawns==before.respawns)
    check('same wounded encounter reconnects',f.director:connection(OWNER,true)=='OK'
        and f.director:controlled(OWNER).hearts==3)
    check('old owner connection epoch is rejected',ownerCommand(f,'Attack',{attack='Punch'},epoch)=='STALE_CONNECTION')
    check('owner disconnected for finite Heavy proof',f.director:connection(OWNER,false)=='OK')
    sameBoss(f)
    phase('AcceptedOfflineBullet',{projectileId=id,heroBefore=before.rawLife,heroAfter=31,ownerEpoch=epoch,
        bossRawLife=f.director.enemies[-99].rawLife})
end
local function realRespawnShield(f)
    local before=resources(f)
    -- Native fall geometry is the only preparation for this shield. Session
    -- observes Fall, commits Death, then pays its ordinary next-frame spawn.
    check('prepared physical fall below native plane',f.world:placeActor(1,{x=604,y=Config.FallY-10,z=0})
        and f.world:hazard(1)=='Fall')
    frame(f)
    check('Session commits physical fall without paying stock at death',f.session.state.heroes[1].status=='AwaitingRespawn'
        and f.session.state.heroes[1].respawns==before.respawns and f.session.state.heroes[1].actorId==nil)
    frame(f)
    local h=f.session.state.heroes[1]
    check('Session creates paid body and legitimate Normal shield',h.status=='Alive' and h.attempt==before.attempt+1
        and h.respawns==before.respawns-1 and h.actorId~=before.actorId and h.shield and h.shield.kind=='Normal'
        and f.session.combat[1].rawLife==47)
    f.heroSeq=0
    check('prepared respawned native pickup stance',f.world:placeActor(1,{x=604,y=3,z=0}))
    phase('PhysicalPaidRespawn',{before=before,after=resources(f),shieldUntil=h.shield.deadline})
end
local function returnCycle(f,index,wantRaw)
    check('prepared native Heavy target stance '..index,f.world:placeActor(1,{x=604,y=3,z=0}))
    local deadline=f.director.guardian.nextBall
    untilAt(f,deadline-.001)
    check('Heavy deadline has not fired early '..index,projectile(f,'Heavy')==nil)
    untilAt(f,deadline+DT)
    local id,p=projectile(f,'Heavy');assert(id,'Finite Heavy missing')
    check('real finite Heavy has native phase Model '..index,nativeProjectile(f,id,'Heavy')
        and p.created>=deadline-1e-6 and not f.director.enemies[-99].connected)
    local destination=table.clone(p.direction)
    local ground=f.world:groundPosition(f.world:position(1))
    check('Heavy destination comes from native authored ground ray '..index,ground
        and near(ground.x,destination.x) and near(ground.y,destination.y) and near(ground.z,destination.z))
    untilCondition(f,function() return p.mode=='Ground' end,5,'Heavy landing '..index)
    check('same projectile lands as native Ground '..index,f.director.projectiles[id]==p
        and nativeProjectile(f,id,'Ground') and near(p.position.y,destination.y))
    if index==1 then realRespawnShield(f) end
    local before=resources(f);local shield=f.session.state.heroes[1].shield
    check('native Ground is offered to primary '..index,f.director:interaction(1).available
        and not f.director:interaction(1).carrying)
    check('Session primary picks up actual Ground '..index,heroPrimary(f)=='OK'
        and p.mode=='Carried' and nativeProjectile(f,id,'Carried') and p.holder==1)
    unchanged(f,before,'carrying preserves hero resources '..index)
    check('pickup preserves current shield '..index,f.session.state.heroes[1].shield==shield)
    untilAt(f,f.now+Config.Attacks.Punch.cooldown+DT)
    if index==1 then check('legitimate shield remains before accepted throw',f.session.state.heroes[1].shield==shield) end
    check('Session primary accepts actual throw '..index,heroPrimary(f)=='OK'
        and p.mode=='Thrown' and nativeProjectile(f,id,'Thrown') and p.holder==nil)
    check('accepted throw commits shield and hold transition '..index,f.session.state.heroes[1].shield==nil
        and not f.world.actors[1].root.Anchored and f.director.guardian.carriers[1]==nil)
    unchanged(f,before,'throw preserves hero resources '..index)
    untilCondition(f,function() return f.director.bossHits==index end,4,'returned ball impact '..index)
    check('real returned impact changes boss Life '..index,f.director.enemies[-99].rawLife==wantRaw
        and f.director.enemies[-99].health==3-index and f.director.projectiles[id]==nil and f.world.actors[id]==nil)
    unchanged(f,before,'return flight preserves hero resources '..index)
    sameBoss(f)
    check('no result before authored exit '..index,f.director.result==nil)
    phase('ReturnCycle'..index,{projectileId=id,deadline=deadline,ground=destination,
        bossBefore=wantRaw==31 and 47 or wantRaw==15 and 31 or 15,bossAfter=wantRaw,
        bossHearts=3-index,hero=resources(f),stage=f.director.stage})
end
local function exitProof(f)
    check('third real return defeats same Guardian and clears every projectile',f.director.stage=='Exit'
        and f.director.enemies[-99].dead and f.director:controlled(OWNER).status=='Dead'
        and next(f.director.projectiles)==nil and next(f.director.guardian.carriers)==nil)
    check('native exit gate opens without immediate win',not f.world.exitGate.beam.CanCollide
        and f.director.result==nil and not f.world:atExit(1))
    local before=resources(f);local box=Level.boss.exit
    check('prepared stance immediately before authored exit',f.world:placeActor(1,{x=box.minX-.01,y=3,z=0}))
    frame(f);check('native exit excludes preceding X',not f.world:atExit(1) and f.director.result==nil)
    check('prepared stance immediately outside authored exit width',f.world:placeActor(1,{x=box.minX,y=3,z=box.maxZ+.01}))
    frame(f);check('native exit excludes outside Z',not f.world:atExit(1) and f.director.result==nil)
    check('prepared stance at authored exit boundary',f.world:placeActor(1,{x=box.minX,y=3,z=box.maxZ}))
    check('production exit volume includes its boundary',f.world:atExit(1))
    frame(f);check('Director wins only after native exit contact',f.director.result=='Won' and f.director.stage=='Won')
    unchanged(f,before,'exit completion preserves hero resources')
    phase('Exit',{minX=box.minX,maxZ=box.maxZ,result=f.director.result,bossActorId=f.bossActorId,hero=resources(f)})
end
local ok,err=xpcall(function()
    -- Preserve exact default instances: GameWorld.new otherwise destroys them.
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    local f=begin()
    preparedAssignment(f);shieldedMelee(f);acceptedOfflineBullet(f)
    for index,want in ipairs({31,15,0}) do returnCycle(f,index,want) end
    exitProof(f)
    result.status='PASS'
end,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
-- Finally: teardown is independent of which constructor or phase failed.
for _,f in ipairs(created) do
    local row={world=f.worldName,errors={}}
    local function teardown(name,callback)
        local success,message=pcall(callback);if not success then row.errors[#row.errors+1]=name..': '..tostring(message) end
    end
    teardown('remember all native bodies',function() track(f) end)
    if f.director then
        teardown('cancel finite intro',function() f.director:cancelBossIntro('AcceptanceClosed') end)
        if f.director.guardian then teardown('clear Guardian phase objects',function() f.director.guardian:_clear() end) end
    end
    if f.world then teardown('actor clear',function() f.world:clearActors() end) end
    for folder in pairs(f.ownedFolders) do teardown('owned world destroy',function() folder:Destroy() end) end
    row.worldRemoved=true;for folder in pairs(f.ownedFolders) do if folder.Parent~=nil then row.worldRemoved=false end end
    row.actorRegistryEmpty=not f.world or next(f.world.actors)==nil
    row.nativeBodiesRemoved=true;for model in pairs(f.models) do if model.Parent~=nil then row.nativeBodiesRemoved=false end end
    row.pass=#row.errors==0 and row.worldRemoved and row.actorRegistryEmpty and row.nativeBodiesRemoved
    result.cleanup[#result.cleanup+1]=row;if not row.pass then result.status='FAIL';result.cleanupFailed=true end
end
local restoration={scope='shared world side effects',errors={}}
local function restore(name,callback)
    local success,message=pcall(callback)
    if not success then restoration.errors[#restoration.errors+1]=name..': '..tostring(message) end
end
for key,value in pairs(lightingBefore) do restore('Lighting.'..key,function() Lighting[key]=value end) end
if atmosphere then
    for key,value in pairs(atmosphereBefore) do restore('CausewayAtmosphere.'..key,function() atmosphere[key]=value end) end
end
for _,item in ipairs(Lighting:GetChildren()) do
    if not originalLightingChildren[item] and item.Name=='CausewayAtmosphere' and item:IsA('Atmosphere') then
        restore('remove created atmosphere',function() item:Destroy() end)
    end
end
for _,row in ipairs(defaults) do restore('restore original '..row.original.Name,function() row.original.Parent=row.parent end) end
restoration.lightingRestored=true
for key,value in pairs(lightingBefore) do
    restore('verify Lighting.'..key,function() if Lighting[key]~=value then restoration.lightingRestored=false;error('value differs') end end)
end
restoration.atmosphereRestored=true
if atmosphere then
    for key,value in pairs(atmosphereBefore) do
        restore('verify CausewayAtmosphere.'..key,function() if atmosphere[key]~=value then restoration.atmosphereRestored=false;error('value differs') end end)
    end
else restoration.atmosphereRestored=Lighting:FindFirstChild('CausewayAtmosphere')==nil end
restoration.defaultsRestored=true
for _,row in ipairs(defaults) do if row.original.Parent~=row.parent then restoration.defaultsRestored=false end end
restoration.ownedWorldsRemoved=true
for _,item in ipairs(workspace:GetChildren()) do
    if not originalFolders[item] and item:IsA('Folder') and ownedWorldNames[item.Name] then restoration.ownedWorldsRemoved=false end
end
restoration.pass=#restoration.errors==0 and restoration.lightingRestored and restoration.atmosphereRestored
    and restoration.defaultsRestored and restoration.ownedWorldsRemoved
result.cleanup[#result.cleanup+1]=restoration
if not restoration.pass then result.status='FAIL';result.cleanupFailed=true end
result.fixedTicks=ticks;result.fixedDelta=DT
_G.BrickToadsGuardianPhaseAcceptance=result
return Http:JSONEncode(result)
