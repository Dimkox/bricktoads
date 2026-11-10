-- Studio-only prepared contacts and late boarding; no full-route/device claim.
-- Real Session owns all health, stock, identities and deaths. Native authored
-- models, the entry-patrol defeat and isolated starting poses are explicit.
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
    fixture='Prepared seed41 stages3/5/7; real Session, CampaignDirector, authored swept hazards and native GameWorld Models',
    limitations='Synthetic server roster; prepared positions and accepted entry-patrol defeat; ordinary AI unstepped; no actual Players, network, keyboard, touch or route-clear claim'}
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
local function resources(f,id)
    local h=f.session.state.heroes[id]
    return {actorId=h.actorId,attempt=h.attempt,rawLife=f.session.combat[id].rawLife,respawns=h.respawns,status=h.status}
end
local function unchanged(f,id,before,label)
    local after=resources(f,id)
    for key,value in pairs(before) do check(label..' preserves '..key,after[key]==value) end
    return after
end
local function track(f) for _,body in pairs(f.world.actors) do f.models[body.model]=true end end
local function coherent(f,id,label)
    local a,b=f.modes.actors[id],f.world.actors[id]
    check(label..' native Model',b.model:IsA('Model') and b.model:IsDescendantOf(workspace) and b.root.Anchored)
    check(label..' logical/native pose',(b.root.Position-f.world.offset-Vector3.new(a.position.x,a.position.y,a.position.z)).Magnitude<.001)
end
local function begin(index,count)
    local d=definitions.build(index,41);local config=require(G.GameConfig)(require(R.Config),d)
    local worldName='BrickToadsRidingQA_'..Http:GenerateGUID(false)
    ownedWorldNames[worldName]=true
    local f={definition=d,config=config,worldName=worldName,ownedFolders={},now=workspace:GetServerTimeNow(),seq={},models={},prefix='stage '..index}
    created[#created+1]=f
    local constructorFolders={};for _,item in ipairs(workspace:GetChildren()) do constructorFolders[item]=true end
    local ok,world=xpcall(function()
        return World.new(require(R.RobloxWorld),config,{name=worldName,
            offset={x=0,y=32,z=8192+(#created-1)*512},characterAppearance=require(G.CharacterAppearance),
            guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    end,debug.traceback)
    -- BaseWorld starts with CombatStandWorld before GameWorld assigns its unique
    -- name. Retain only new roots from this synchronous constructor invocation.
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and not constructorFolders[item] and item:IsA('Folder')
            and (item.Name==worldName or item.Name=='CombatStandWorld') then f.ownedFolders[item]=true end
    end
    if not ok then error(world,0) end
    f.world=world;f.ownedFolders[world.folder]=true
    local roster={{userId=1,template='Mr. Green'}}
    if count==2 then roster[2]={userId=2,template='Mr. Yellow'} end
    f.session=Session.new(require(project.RunLifecycle),Combat,config,roster,'native-riding-'..Http:GenerateGUID(false),world,nil,
        {groupId='native-riding-fixture',levelId=d.id})
    check(f.prefix..' initial spawn',f.session:step(f.now)=='OK')
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.session.contextualAttack=function(slot,now,action) return f.director:interact(slot,now,action) end
    f.modes=f.director.modes;f.modes:_slice(0);track(f)
    -- Explicit combat preparation clears the actual authored boarding gate.
    check(f.prefix..' patrol initially blocks boarding',not f.modes.canBoard())
    for id,e in pairs(f.director.ordinary.enemies) do
        if not e.dead and not e.encounter then
            check(f.prefix..' accepted patrol defeat '..id,f.director.ordinary:hit(1,id,'HeroPowerPunch',config.Attacks.HeroPowerPunch) and e.dead)
        end
    end
    check(f.prefix..' actual boarding gate cleared',f.modes.canBoard())
    return f
end
local function intent(f,id,kind,fields)
    local h=f.session.state.heroes[id];f.seq[id]=(f.seq[id] or 0)+1
    local p={kind=kind,runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=f.seq[id]}
    for key,value in pairs(fields or {}) do p[key]=value end
    check(f.prefix..' accepted '..kind..' '..id,f.session:intent(id,p,f.now)=='OK')
end
local function tick(f)
    f.now+=DT;assert(f.session:step(f.now)=='OK','Session slice rejected');f.modes:step(f.now,DT);track(f)
    ticks+=1;if ticks%60==0 then task.wait() end
end
local function physicalFall(f,id)
    local p=table.clone(f.definition.spawn);p.y=f.definition.bounds.minY-30
    f.world:campaignRelease(id);assert(f.world:placeActor(id,p),'Fall preparation rejected')
    f.now+=DT;assert(f.session:step(f.now)=='OK','Fall Session slice rejected');track(f)
    check(f.prefix..' native physical fall awaits respawn',f.session.state.heroes[id].status=='AwaitingRespawn')
end
local function board(f,id)
    assert(f.world:placeActor(id,f.definition.course.mount),'Boarding stance preparation rejected')
    check(f.prefix..' late board interaction available '..id,f.modes:interaction(id).available)
    intent(f,id,'Attack',{attack='Punch'})
    check(f.prefix..' actor mounted '..id,f.modes.actors[id].mounted)
    coherent(f,id,f.prefix..' boarded '..id)
end
local function finalCrash(f)
    for _=1,3 do physicalFall(f,1);tick(f) end
    local ready=resources(f,1)
    check(f.prefix..' actual final paid attempt',ready.attempt==4 and ready.respawns==0 and ready.rawLife==47 and ready.status=='Alive')
    -- Clock-only expiry while still on foot; no route simulation or stock write.
    f.now+=3;assert(f.session:step(f.now)=='OK');f.modes:step(f.now,0)
    check(f.prefix..' final spawn shield expired',f.session.state.heroes[1].shield==nil)
    board(f,1)
    local a=f.modes.actors[1];local h=f.definition.course.hazards[1]
    a.position={x=h.x-2,y=h.y,z=h.z};a.previous=table.clone(a.position)
    assert(f.world:campaignPose(1,a.position,f.definition.mode,a.velocity),'Crash stance rejected')
    tick(f)
    local dead=resources(f,1);local reason
    for _,row in ipairs(f.session.logs) do if row.kind=='ConfirmedDeath' and row.userId==1 then reason=row.data.reason end end
    check(f.prefix..' authored mounted crash eliminates exhausted rider',dead.status=='Eliminated' and dead.actorId==nil
        and dead.attempt==4 and dead.respawns==0 and dead.rawLife==0 and reason=='CampaignCrash')
    return dead
end
local function lateBoarder(index)
    local f=begin(index,2);local untouched=resources(f,2);local footModel=f.world.actors[2].model
    local dead=finalCrash(f)
    check(f.prefix..' living foot teammate keeps cohort pending',f.session.state.status=='Active'
        and f.modes.vehicleGroup.phase=='AwaitingRespawn' and not f.modes.actors[2].mounted and not f.modes.complete)
    unchanged(f,2,untouched,f.prefix..' waiting foot teammate')
    board(f,2);local start=f.modes.actors[2].position.x
    for _=1,65 do tick(f) end
    local a=f.modes.actors[2]
    check(f.prefix..' existing rewind restarts late boarder',f.modes.vehicleGroup.phase=='Riding'
        and f.modes.vehicleGroup.speed>0 and a.position.x>start)
    check(f.prefix..' same native teammate body',f.world.actors[2].model==footModel)
    coherent(f,2,f.prefix..' restarted')
    local oldY,oldZ=a.position.y,a.position.z
    intent(f,2,'Move',{x=0,z=index==7 and -1 or 1,run=false})
    for _=1,10 do tick(f) end
    check(f.prefix..' manual '..(index==7 and 'height' or 'lane')..' input moves native body',
        index==7 and a.position.y>oldY+.2 or index~=7 and a.position.z>oldZ+1)
    local beforeLift=a.velocity.y;intent(f,2,'Jump');tick(f)
    check(f.prefix..' accepted '..(index==7 and 'lift' or 'jump')..' raises velocity',a.velocity.y>beforeLift+1)
    coherent(f,2,f.prefix..' controlled')
    local after=unchanged(f,2,untouched,f.prefix..' late board restart/controls')
    unchanged(f,1,dead,f.prefix..' eliminated rider')
    check(f.prefix..' isolated acceptance never clears course',not f.modes.complete)
    result.cases[#result.cases+1]={case='late boarding and isolated manual controls',stage=index,
        eliminated=dead,before=untouched,after=after,phase=f.modes.vehicleGroup.phase,position=table.clone(a.position),rewindSerial=f.modes.vehicleGroup.serial}
end
local function trueLost(index)
    local f=begin(index,1);local dead=finalCrash(f);local phase=f.modes.vehicleGroup.phase
    check(f.prefix..' no living cohort is truly Lost',f.session.state.status=='Lost')
    for _=1,65 do f.now+=DT;f.modes:step(f.now,DT) end
    unchanged(f,1,dead,f.prefix..' genuinely Lost rider')
    check(f.prefix..' Lost Session cannot restart or complete',f.session.state.status=='Lost'
        and f.modes.vehicleGroup.phase==phase and not f.modes.complete and not f.modes:interaction(1).available)
    result.cases[#result.cases+1]={case='genuinely Lost cohort remains Lost',stage=index,eliminated=dead,phase=phase}
end
local ok,err=xpcall(function()
    -- Preserve the exact original root instances while GameWorld removes named
    -- blank-place defaults. Cleanup reparents these same instances on failure too.
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    for _,index in ipairs({5,7,3}) do lateBoarder(index);trueLost(index) end
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
_G.BrickToadsRidingNativeAcceptance=result
return Http:JSONEncode(result)
