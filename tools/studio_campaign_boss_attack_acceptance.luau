-- Studio Play-server acceptance: native Humanoid walking and prepared boss attacks.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),'Requires a running Studio Play server')
local Http=game:GetService('HttpService')
local Lighting=game:GetService('Lighting')
local project=game:GetService('ServerScriptService'):WaitForChild('BrickToads')
local G,R=project.gameplay,project.CombatRuntime
local World=require(G.GameWorld);require(G.DragonWorld)(World)
local Session,Combat=require(R.Session),require(R.Combat)
local definitions=require(G.CampaignDefinition)
local deps={CampaignDefinition=definitions,CampaignModes=require(G.CampaignModes),CampaignBoss=require(G.CampaignBoss),
    CampaignEnemies=require(G.CampaignEnemies),Director=require(G.LevelDirector),GuardianPattern=require(G.GuardianPattern),
    HealingFlies=require(G.HealingFlies),EnemyCarry=require(G.EnemyCarry),WalkerClubs=require(G.WalkerClubs),
    DragonFlight=require(G.DragonFlight),BossIntro=require(G.BossIntro)}
local result={sourceSha256=require(project.BuildInfo).sourceSha256,checks={},cases={},cleanup={},
    fixture='Prepared seed41 stages5/8/10/11/13; real Session, CampaignDirector, synthetic owner and fresh native GameWorld Models',
    limitations='Requires Studio Play server. Synthetic roster and owner; explicitly cleared ordinary gates and traversal, prepared arena stances, ordinary AI unstepped. No real Players, network, keyboard, touch or natural course-clear claim.'}
local created={};local DT=1/60;local ticks=0
local originalFolders={};for _,item in ipairs(workspace:GetChildren()) do originalFolders[item]=true end
local ownedWorldNames={};local lightingBefore={}
for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do
    lightingBefore[key]=Lighting[key]
end
local originalLightingChildren={};for _,item in ipairs(Lighting:GetChildren()) do originalLightingChildren[item]=true end
local atmosphere=Lighting:FindFirstChild('CausewayAtmosphere');local atmosphereBefore={}
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

local function track(f)
    if f.world then for _,body in pairs(f.world.actors) do f.models[body.model]=true end end
end
local OWNER=900099
local function begin(index)
    local d=definitions.build(index,41);local config=require(G.GameConfig)(require(R.Config),d)
    local worldName='BrickToadsBossAttackQA_'..Http:GenerateGUID(false)
    ownedWorldNames[worldName]=true
    local f={definition=d,config=config,worldName=worldName,ownedFolders={},seq=0,models={},
        prefix='stage '..index,offsetSeconds=3.1,now=workspace:GetServerTimeNow()}
    created[#created+1]=f
    local constructorFolders={};for _,item in ipairs(workspace:GetChildren()) do constructorFolders[item]=true end
    local ok,world=xpcall(function()
        return World.new(require(R.RobloxWorld),config,{name=worldName,
            offset={x=0,y=32,z=12288+(#created-1)*512},characterAppearance=require(G.CharacterAppearance),
            guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    end,debug.traceback)
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and not constructorFolders[item] and item:IsA('Folder')
            and (item.Name==worldName or item.Name=='CombatStandWorld') then f.ownedFolders[item]=true end
    end
    if not ok then error(world,0) end
    f.world=world;f.ownedFolders[world.folder]=true
    f.session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'}},
        'native-boss-attack-'..Http:GenerateGUID(false),world,nil,{groupId='native-boss-attack-fixture',levelId=d.id})
    check(f.prefix..' initial spawn',f.session:step(f.now)=='OK')
    -- Explicit clock-only expiry before constructing combat actors. Subsequent
    -- frames use the same offset and real Heartbeat deltas, never a fast loop.
    f.now=workspace:GetServerTimeNow()+f.offsetSeconds
    check(f.prefix..' spawn shield expiry',f.session:step(f.now)=='OK' and f.session.state.heroes[1].shield==nil)
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.director.ownerNames[OWNER]='Synthetic acceptance owner'
    f.director.bossGate=function() return {state='Human',userId=OWNER} end
    -- Prepared gates are stated fixture setup, not earned traversal evidence.
    for id,e in pairs(f.director.ordinary.enemies) do
        if not e.dead then f.director.ordinary:_kill(id,'AcceptancePreparedClear') end
    end
    f.director.modes.complete=true
    for _,slot in ipairs(f.session.order) do
        local actor=f.director.modes.actors[slot]
        if actor then actor.finished=true end
        world:campaignRelease(slot)
    end
    check(f.prefix..' prepared traversal releases native hero',not world.actors[1].campaignControl
        and not world.actors[1].root.Anchored)
    check(f.prefix..' prepared human boss gate',f.director:_startBoss(f.now,false))
    f.boss=f.director.boss;track(f)
    check(f.prefix..' human owns the same native boss',f.boss:controlled(OWNER).enemyId==-99
        and f.boss.state=='Ready' and world.actors[-99].model:IsDescendantOf(workspace))
    f.heroBefore={actorId=f.session.state.heroes[1].actorId,attempt=f.session.state.heroes[1].attempt,
        respawns=f.session.state.heroes[1].respawns,model=world.actors[1].model}
    local p=d.boss.platform
    check(f.prefix..' prepared hero stance',world:placeActor(1,{x=p.x-20,y=d.boss.position.y,z=p.z-22}))
    return f
end
local function command(f,kind,fields)
    local role=f.boss:controlled(OWNER);f.seq+=1
    local p={kind=kind,runId=f.session.state.runId,actorId=role.actorId,attempt=role.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=role.connectionEpoch,seq=f.seq}
    for key,value in pairs(fields or {}) do p[key]=value end
    local code=f.director:command(OWNER,p,f.now,Session.validIntent)
    assert(code=='OK',f.prefix..' rejected owner '..kind..': '..tostring(code))
    if kind=='Attack' then check(f.prefix..' accepted owner Attack',true) end
end
local function frame(f)
    local dt=game:GetService('RunService').Heartbeat:Wait()
    f.now=workspace:GetServerTimeNow()+f.offsetSeconds
    assert(f.session:step(f.now)=='OK',f.prefix..' rejected Session heartbeat')
    f.director.now=f.now;f.director.ordinary.now=f.now
    assert(f.boss:step(f.now,dt)=='OK',f.prefix..' rejected boss heartbeat')
    f.world:updatePresentation(f.session,dt,f.director.enemies);track(f);ticks+=1
end
local function untilCondition(f,predicate,seconds)
    local deadline=workspace:GetServerTimeNow()+seconds
    while not predicate() do
        assert(workspace:GetServerTimeNow()<deadline,f.prefix..' native condition timeout')
        frame(f)
    end
end
local function movement(f)
    local body=f.world.actors[-99];local model=body.model;local before=f.world:position(-99)
    local started=workspace:GetServerTimeNow();local deadline=started+.65
    repeat command(f,'Move',{x=1,z=0,run=false});frame(f) until workspace:GetServerTimeNow()>=deadline
    command(f,'Move',{x=0,z=0,run=false})
    local after=f.world:position(-99)
    check(f.prefix..' actual Humanoid Ready walk',after.x>before.x+1 and math.abs(after.z-before.z)<2)
    check(f.prefix..' configured movement cap',body.humanoid.WalkSpeed==f.config.Enemy.speed)
    check(f.prefix..' same boss body after walking',body.model==model and not body.root.Anchored)
    f.moveEvidence={before=before,after=after,walkSpeed=body.humanoid.WalkSpeed,elapsed=workspace:GetServerTimeNow()-started,
        actorId=f.boss.enemies[-99].actorId,unanchored=not body.root.Anchored}
end
local function ordinaryFirstAttack(f)
    local kind=f.boss.kind;local before=f.world:position(-99)
    local reach=kind=='DarkQueen' and 5 or kind=='GeneralSlaughter' and 10 or 12
    local target={x=before.x+reach,y=f.definition.boss.position.y,z=before.z}
    check(f.prefix..' prepared first attack stance',f.world:placeActor(1,target))
    command(f,'Move',{x=1,z=0,run=false});command(f,'Attack',{attack='Punch'})
    local want=({BigBlag='Hop',GeneralSlaughter='Charge',Buzzball='Roll',DarkQueen='Sweep'})[kind]
    check(f.prefix..' normal first attack',f.boss.attack and f.boss.attack.name==want)
    local attackId=f.boss.attack.serial
    untilCondition(f,function() return f.session.combat[1].rawLife<47 end,4)
    local raw=f.session.combat[1].rawLife
    check(f.prefix..' production attack damages native hero',raw==31)
    check(f.prefix..' hero stocks and body preserved',f.session.state.heroes[1].actorId==f.heroBefore.actorId
        and f.session.state.heroes[1].attempt==f.heroBefore.attempt
        and f.session.state.heroes[1].respawns==f.heroBefore.respawns and f.world.actors[1].model==f.heroBefore.model)
    result.cases[#result.cases+1]={stage=f.definition.campaignIndex,boss=kind,movement=f.moveEvidence,
        attack=want,attackSerial=attackId,heroBefore=47,heroAfter=raw,target=target,preparedGates=true}
end
local function roboProjectile(f)
    local p=f.definition.boss.platform;local origin={x=p.x-30,y=f.definition.boss.position.y,z=p.z}
    local target={x=origin.x+60,y=origin.y,z=origin.z}
    check(f.prefix..' prepared long bolt stance',f.world:placeActor(-99,origin) and f.world:placeActor(1,target))
    local originalImpulse=f.world.impulse
    function f.world:impulse(id,attacker,tuning,profile,direction)
        if id==1 and attacker==-99 then
            f.shotResponse={profile=profile,direction=direction and table.clone(direction),
                facing={x=self.actors[-99].root.CFrame.LookVector.X,z=self.actors[-99].root.CFrame.LookVector.Z}}
        end
        return originalImpulse(self,id,attacker,tuning,profile,direction)
    end
    command(f,'Move',{x=1,z=0,run=false});command(f,'Attack',{attack='Punch'})
    check(f.prefix..' normal first Burst',f.boss.attack and f.boss.attack.name=='Burst')
    untilCondition(f,function() return f.boss.state=='Ready' end,4)
    check(f.prefix..' distant bolt still in flight',f.session.combat[1].rawLife==47 and next(f.boss.projectiles)~=nil)
    command(f,'Move',{x=0,z=-1,run=false});command(f,'Attack',{attack='Dash'})
    check(f.prefix..' later Jump faces -Z',f.world.actors[-99].root.CFrame.LookVector.Z<-.99)
    untilCondition(f,function() return f.session.combat[1].rawLife<47 end,2)
    local response=f.shotResponse
    check(f.prefix..' native collision retains +X shot direction',response and response.direction
        and math.abs(response.direction.x-1)<1e-6 and math.abs(response.direction.z)<1e-6)
    check(f.prefix..' actual boss facing differs at bolt contact',response.facing.z<-.99)
    frame(f)
    local velocity=f.world.actors[1].root.AssemblyLinearVelocity
    check(f.prefix..' native bolt knockback follows +X',velocity.X>8 and math.abs(velocity.Z)<velocity.X*.25)
    check(f.prefix..' bolt does not spend hero stocks',f.session.combat[1].rawLife==31
        and f.session.state.heroes[1].respawns==f.heroBefore.respawns
        and f.session.state.heroes[1].actorId==f.heroBefore.actorId)
    result.cases[#result.cases+1]={stage=8,boss='RoboManus',movement=f.moveEvidence,attack='Burst',laterAttack='Jump',
        heroBefore=47,heroAfter=f.session.combat[1].rawLife,shotResponse=response,
        observedVelocity={x=velocity.X,y=velocity.Y,z=velocity.Z},origin=origin,target=target,preparedGates=true}
end
local ok,err=xpcall(function()
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    for _,index in ipairs({5,8,10,11,13}) do
        local f=begin(index);movement(f)
        if index==8 then roboProjectile(f) else ordinaryFirstAttack(f) end
    end
    result.status='PASS'
end,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
for _,f in ipairs(created) do
    local row={stage=f.definition.campaignIndex,errors={}}
    local function teardown(name,callback) local success,message=pcall(callback);if not success then row.errors[#row.errors+1]=name..': '..tostring(message) end end
    if f.world then
        teardown('remember native bodies',function() track(f) end)
        if f.director then teardown('director close',function() f.director:close('AcceptanceClosed') end) end
        teardown('actor clear',function() f.world:clearActors() end)
    end
    for folder in pairs(f.ownedFolders) do teardown('owned world destroy',function() folder:Destroy() end) end
    row.worldRemoved=true;for folder in pairs(f.ownedFolders) do if folder.Parent~=nil then row.worldRemoved=false end end
    row.actorRegistryEmpty=not f.world or next(f.world.actors)==nil;row.nativeBodiesRemoved=true
    for model in pairs(f.models) do if model.Parent~=nil then row.nativeBodiesRemoved=false end end
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
else
    restoration.atmosphereRestored=Lighting:FindFirstChild('CausewayAtmosphere')==nil
end
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
result.fixedTicks=ticks
_G.BrickToadsCampaignBossAttackAcceptance=result
return Http:JSONEncode(result)
