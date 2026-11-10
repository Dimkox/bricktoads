-- Studio-only isolated ownership callbacks, not actual Player reconnection.
-- Authored seed41 enemies use native Models and the real Session/Director.
-- Only the selected owned enemy's family step is advanced; other AI is idle.
assert(game:GetService('RunService'):IsStudio(),'Studio acceptance only')
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
    fixture='Isolated authored seed41 stage9 Electrofish and stage12 Swellcheeks; native GameWorld Models, real Session and CampaignDirector owner commands',
    limitations='Synthetic server roster/owner; selected family and hero modes stepped, other ordinary AI idle; no actual Players, rejoin, network, keyboard, touch or full-route claim'}
local created={};local DT=1/60;local ticks=0;local OWNER=900099
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
local function near(a,b) return math.abs(a-b)<.001 end
local function track(f) for _,body in pairs(f.world.actors) do f.models[body.model]=true end end
local function resources(f)
    local h=f.session.state.heroes[1]
    return {actorId=h.actorId,attempt=h.attempt,rawLife=f.session.combat[1].rawLife,respawns=h.respawns,status=h.status}
end
local function unchanged(f,before)
    local after=resources(f)
    for key,value in pairs(before) do check(f.prefix..' preserves hero '..key,after[key]==value) end
    return after
end
local function begin(index,kind)
    local d=definitions.build(index,41);local config=require(G.GameConfig)(require(R.Config),d)
    local worldName='BrickToadsLateEnemyConnectionQA_'..Http:GenerateGUID(false)
    ownedWorldNames[worldName]=true
    -- Register before construction so partial constructors are cleaned as well.
    local f={definition=d,config=config,worldName=worldName,ownedFolders={},now=workspace:GetServerTimeNow(),models={},prefix=kind}
    created[#created+1]=f
    local constructorFolders={};for _,item in ipairs(workspace:GetChildren()) do constructorFolders[item]=true end
    local ok,world=xpcall(function()
        return World.new(require(R.RobloxWorld),config,{name=worldName,
            offset={x=0,y=32,z=11264+(#created-1)*512},characterAppearance=require(G.CharacterAppearance),
            guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    end,debug.traceback)
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and not constructorFolders[item] and item:IsA('Folder')
            and (item.Name==worldName or item.Name=='CombatStandWorld') then f.ownedFolders[item]=true end
    end
    if not ok then error(world,0) end
    f.world=world;f.ownedFolders[world.folder]=true
    f.session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'}},
        'native-enemy-connection-'..Http:GenerateGUID(false),world,nil,{groupId='native-enemy-connection-fixture',levelId=d.id})
    check(kind..' initial spawn',f.session:step(f.now)=='OK')
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.modes=f.director.modes;f.modes:_slice(0);track(f)
    for _,row in ipairs(d.zones[1].enemies) do if row.kind==kind then f.id=row.id;break end end
    assert(f.id,'Missing authored '..kind)
    f.enemy=f.director.ordinary.enemies[f.id]
    check(kind..' normal one-life claim',f.director:claim(OWNER,f.id)=='OK')
    return f
end
local function command(f,x,epoch)
    local role=f.director:controlled(OWNER)
    local e=f.enemy
    return f.director:command(OWNER,{kind='Move',x=x,z=0,runId=f.session.state.runId,actorId=role.actorId,
        attempt=role.attempt,levelEpoch=f.session.state.levelEpoch,connectionEpoch=epoch or role.connectionEpoch,
        seq=e.lastSeq+1},f.now,Session.validIntent)
end
local function tick(f)
    f.now+=DT;assert(f.session:step(f.now)=='OK','Session slice rejected')
    f.modes:step(f.now,DT)
    f.director.now=f.now;f.director.ordinary.now=f.now
    f.director.campaignEnemies:enemyStep(f.id,f.enemy,DT)
    assert(f.director.campaignEnemies:step(f.now,DT)=='OK','Family slice rejected')
    track(f);ticks+=1;if ticks%60==0 then task.wait() end
end
local function run(index,kind)
    local f=begin(index,kind);local before=resources(f)
    local body=f.world.actors[f.id];local model,actorId,life=body.model,f.enemy.actorId,f.enemy.rawLife
    local heroModel=f.world.actors[1].model;local oldEpoch=f.enemy.connectionEpoch
    local start=body.root.Position.X
    check(kind..' initial Move accepted',command(f,1)=='OK')
    for _=1,6 do tick(f) end
    local moving=body.root.Position.X
    check(kind..' native same body moves from accepted input',moving>start+.5 and body.root.Anchored and model:IsDescendantOf(workspace))
    check(kind..' disconnect callback accepted',f.director:connection(OWNER,false)=='OK')
    for _=1,6 do tick(f) end
    local stopped=body.root.Position.X
    check(kind..' offline horizontal input stops',near(stopped,moving))
    check(kind..' offline command rejected',command(f,-1)=='OFFLINE')
    check(kind..' reconnect callback accepted',f.director:connection(OWNER,true)=='OK')
    -- This exceeds MoveTimeout without accepting any fresh movement intent.
    for _=1,65 do tick(f) end
    local afterIdle=body.root.Position.X
    check(kind..' reconnect stays stopped until new input',near(afterIdle,stopped))
    check(kind..' previous epoch rejected',command(f,-1,oldEpoch)=='STALE_CONNECTION')
    for _=1,6 do tick(f) end
    check(kind..' rejected command leaves native body stopped',near(body.root.Position.X,stopped))
    check(kind..' fresh connection Move accepted',command(f,1)=='OK')
    for _=1,6 do tick(f) end
    check(kind..' fresh input resumes native movement',body.root.Position.X>stopped+.5)
    check(kind..' enemy identity Life and owner unchanged',f.world.actors[f.id]==body and body.model==model
        and f.enemy.actorId==actorId and f.enemy.rawLife==life and f.enemy.ownerUserId==OWNER and not f.enemy.dead)
    check(kind..' other user cannot claim owned body',f.director:claim(OWNER+1,f.id)=='ENEMY_OCCUPIED')
    check(kind..' same native hero Model',f.world.actors[1].model==heroModel)
    local after=unchanged(f,before)
    check(kind..' isolated fixture never clears course',not f.modes.complete)
    result.cases[#result.cases+1]={stage=index,kind=kind,enemyId=f.id,actorId=actorId,rawLife=life,ownerUserId=OWNER,
        startNativeX=start,movingNativeX=moving,offlineNativeX=stopped,reconnectedIdleNativeX=afterIdle,
        freshNativeX=body.root.Position.X,oldConnectionEpoch=oldEpoch,newConnectionEpoch=f.enemy.connectionEpoch,
        heroBefore=before,heroAfter=after}
end
local ok,err=xpcall(function()
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    run(9,'Electrofish');run(12,'Swellcheeks');result.status='PASS'
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
result.fixedTicks=ticks
_G.BrickToadsLateEnemyConnectionAcceptance=result
return Http:JSONEncode(result)
