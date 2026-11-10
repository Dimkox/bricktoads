-- Run only in Studio's Play server. One owner input must expire in native physics.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),'Requires a running Studio Play server')
local Http,Lighting=game:GetService('HttpService'),game:GetService('Lighting')
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
    fixture='Prepared seed41 stages5/8/10/11/13; real Session, CampaignDirector and native GameWorld; synthetic boss owner',
    limitations='Real Heartbeat and Humanoid physics. Synthetic roster/owner, cleared ordinary gates, finished traversal and prepared arena stances. No real Players, network, keyboard/touch or natural course-clear claim.'}
local created,ownedWorldNames={},{}
local originalFolders={};for _,item in ipairs(workspace:GetChildren()) do originalFolders[item]=true end
local lightingBefore={}
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
local OWNER=900199
local ticks=0
local function check(label,condition) assert(condition,label);result.checks[#result.checks+1]=label end
local function flatDistance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function track(f)
    if f.world then for _,body in pairs(f.world.actors) do f.models[body.model]=true end end
end
local function begin(index)
    local definition=definitions.build(index,41)
    local config=require(G.GameConfig)(require(R.Config),definition)
    local worldName='BrickToadsBossDeadlineQA_'..Http:GenerateGUID(false)
    ownedWorldNames[worldName]=true
    -- Register before either constructor so partial failures retain cleanup scope.
    local f={definition=definition,config=config,worldName=worldName,ownedFolders={},models={},seq=0,
        prefix='stage '..index,offsetSeconds=3.1,now=workspace:GetServerTimeNow()}
    created[#created+1]=f
    local beforeConstructor={};for _,item in ipairs(workspace:GetChildren()) do beforeConstructor[item]=true end
    local success,world=xpcall(function()
        return World.new(require(R.RobloxWorld),config,{name=worldName,
            offset={x=0,y=32,z=16384+(#created-1)*512},characterAppearance=require(G.CharacterAppearance),
            guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    end,debug.traceback)
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and not beforeConstructor[item] and item:IsA('Folder')
            and (item.Name==worldName or item.Name=='CombatStandWorld') then f.ownedFolders[item]=true end
    end
    if not success then error(world,0) end
    f.world=world;f.ownedFolders[world.folder]=true
    f.session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'}},
        'native-boss-deadline-'..Http:GenerateGUID(false),world,nil,{groupId='native-boss-deadline-fixture',levelId=definition.id})
    check(f.prefix..' initial native hero spawn',f.session:step(f.now)=='OK')
    -- Expire the finite spawn shield through Session's clock, without resource writes.
    f.now=workspace:GetServerTimeNow()+f.offsetSeconds
    check(f.prefix..' normal spawn shield expiry',f.session:step(f.now)=='OK' and f.session.state.heroes[1].shield==nil)
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    f.director.ownerNames[OWNER]='Synthetic deadline acceptance owner'
    f.director.bossGate=function() return {state='Human',userId=OWNER} end
    for id,enemy in pairs(f.director.ordinary.enemies) do
        if not enemy.dead then f.director.ordinary:_kill(id,'AcceptancePreparedClear') end
    end
    f.director.modes.complete=true
    for _,slot in ipairs(f.session.order) do
        local actor=f.director.modes.actors[slot]
        if actor then actor.finished=true end
        world:campaignRelease(slot)
    end
    check(f.prefix..' completed traversal releases native hero',not world.actors[1].campaignControl
        and not world.actors[1].root.Anchored)
    check(f.prefix..' prepared human boss gate',f.director:_startBoss(f.now,false))
    f.boss=f.director.boss;track(f)
    check(f.prefix..' existing native human boss',f.boss:controlled(OWNER).enemyId==-99 and f.boss.state=='Ready'
        and world.actors[-99].model:IsDescendantOf(workspace))
    local p=definition.boss.platform
    check(f.prefix..' prepared distant hero stance',world:placeActor(1,{x=p.x-20,y=definition.boss.position.y,z=p.z-22}))
    local hero=f.session.state.heroes[1]
    f.heroBefore={actorId=hero.actorId,attempt=hero.attempt,respawns=hero.respawns,model=world.actors[1].model,
        rawLife=f.session.combat[1].rawLife}
    return f
end
local function moveOnce(f)
    local role=f.boss:controlled(OWNER);f.seq+=1
    local packet={kind='Move',x=1,z=0,run=false,runId=f.session.state.runId,actorId=role.actorId,attempt=role.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=role.connectionEpoch,seq=f.seq}
    check(f.prefix..' accepts owner Move '..f.seq,f.director:command(OWNER,packet,f.now,Session.validIntent)=='OK')
    return f.now
end
local function frame(f)
    local dt=RunService.Heartbeat:Wait()
    f.now=workspace:GetServerTimeNow()+f.offsetSeconds
    assert(f.session:step(f.now)=='OK',f.prefix..' rejected Session heartbeat')
    f.director.now=f.now;f.director.ordinary.now=f.now
    assert(f.boss:step(f.now,dt)=='OK',f.prefix..' rejected boss heartbeat')
    f.world:updatePresentation(f.session,dt,f.director.enemies);track(f);ticks+=1
end
local function advanceTo(f,deadline)
    local wallDeadline=workspace:GetServerTimeNow()+4
    repeat
        assert(workspace:GetServerTimeNow()<wallDeadline,f.prefix..' Heartbeat deadline timeout')
        frame(f)
    until f.now>=deadline
end
local function nativeDeadline(f)
    local timeout=f.config.MoveTimeout
    check(f.prefix..' finite movement deadline',type(timeout)=='number' and timeout>0 and timeout<1)
    advanceTo(f,f.now+.3)
    local body=f.world.actors[-99];local model,root=body.model,body.root
    local boss=f.boss.enemies[-99]
    local actorId,rawLife,progress=boss.actorId,boss.rawLife,boss.progress
    local before=f.world:position(-99)
    local started=moveOnce(f)
    check(f.prefix..' owner Move records its own deadline',f.boss.lastMove==started)
    advanceTo(f,started+timeout*.5)
    local moving=f.world:position(-99)
    check(f.prefix..' one input moves actual Humanoid before timeout',moving.x>before.x+.5 and math.abs(moving.z-before.z)<.3)
    advanceTo(f,started+timeout+.3)
    local stopped=f.world:position(-99)
    check(f.prefix..' boss clears expired owner Move',f.boss.lastMove==nil)
    check(f.prefix..' native Humanoid direction stops',body.humanoid.MoveDirection.Magnitude<.001)
    local stoppedAt=f.now
    advanceTo(f,stoppedAt+.3)
    local later=f.world:position(-99)
    local drift=flatDistance(stopped,later)
    check(f.prefix..' native boss stays stopped after timeout',drift<=.3 and body.humanoid.MoveDirection.Magnitude<.001)
    local resumedAt=moveOnce(f)
    advanceTo(f,resumedAt+timeout*.5)
    local resumed=f.world:position(-99)
    check(f.prefix..' a fresh owner Move resumes native walking',resumed.x>later.x+.5 and body.humanoid.MoveDirection.X>.9)
    check(f.prefix..' same unanchored boss model root and identity',f.world.actors[-99]==body and body.model==model
        and body.root==root and root.Parent~=nil and not root.Anchored and boss.actorId==actorId)
    check(f.prefix..' walking preserves boss Life and progress',boss.rawLife==rawLife and boss.progress==progress and not boss.dead)
    local hero=f.session.state.heroes[1]
    check(f.prefix..' walking preserves native hero resources and body',hero.actorId==f.heroBefore.actorId
        and hero.attempt==f.heroBefore.attempt and hero.respawns==f.heroBefore.respawns
        and f.session.combat[1].rawLife==f.heroBefore.rawLife and f.world.actors[1].model==f.heroBefore.model)
    result.cases[#result.cases+1]={stage=f.definition.campaignIndex,boss=f.boss.kind,ownerMoveCount=f.seq,
        timeout=timeout,firstMoveAt=started,stoppedAt=stoppedAt,lateSampleAt=resumedAt,
        before=before,moving=moving,stopped=stopped,later=later,resumed=resumed,lateDrift=drift,
        actorId=actorId,rawLife=rawLife,progress=progress,walkSpeed=body.humanoid.WalkSpeed,preparedGates=true}
end
local success,message=xpcall(function()
    -- GameWorld removes blank-place defaults. Preserve the exact original Instances.
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    for _,index in ipairs({5,8,10,11,13}) do nativeDeadline(begin(index)) end
    result.status='PASS'
end,debug.traceback)
if not success then result.status='FAIL';result.error=tostring(message) end
for _,f in ipairs(created) do
    local row={stage=f.definition.campaignIndex,errors={}}
    local function teardown(name,callback)
        local ok,err=pcall(callback);if not ok then row.errors[#row.errors+1]=name..': '..tostring(err) end
    end
    if f.world then
        teardown('remember native bodies',function() track(f) end)
        if f.director then teardown('director close',function() f.director:close('AcceptanceClosed') end) end
        teardown('actor clear including partial mode construction',function() f.world:clearActors() end)
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
    local ok,err=pcall(callback);if not ok then restoration.errors[#restoration.errors+1]=name..': '..tostring(err) end
end
for key,value in pairs(lightingBefore) do restore('Lighting.'..key,function() Lighting[key]=value end) end
if atmosphere then
    for key,value in pairs(atmosphereBefore) do restore('CausewayAtmosphere.'..key,function() atmosphere[key]=value end) end
end
for _,item in ipairs(Lighting:GetChildren()) do
    if not originalLightingChildren[item] and item.Name=='CausewayAtmosphere' and item:IsA('Atmosphere') then
        restore('remove fixture atmosphere',function() item:Destroy() end)
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
result.heartbeatTicks=ticks
_G.BrickToadsBossDeadlineAcceptance=result
return Http:JSONEncode(result)
