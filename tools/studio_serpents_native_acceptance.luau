-- Studio-only prepared Serpents checks; not a natural route or device/network run.
-- The synthetic pair starts on authored segments in explicit lanes, then one
-- starts immediately before vault1's existing exit. Session alone owns health,
-- identity, attempts and reserves. Authored spike rows remain active throughout.
assert(game:GetService('RunService'):IsStudio(),'Studio acceptance only')
local Http=game:GetService('HttpService')
local Lighting=game:GetService('Lighting')
local project=game:GetService('ServerScriptService'):WaitForChild('BrickToads')
local G,R=project.gameplay,project.CombatRuntime
local World=require(G.GameWorld);require(G.DragonWorld)(World)
local BaseWorld=require(R.RobloxWorld)
local CharacterAppearance,GuardianAppearance,CampaignWorld=require(G.CharacterAppearance),require(G.GuardianAppearance),require(G.CampaignWorld)
local Session,Combat=require(R.Session),require(R.Combat)
local definitions=require(G.CampaignDefinition)
local deps={CampaignDefinition=definitions,CampaignModes=require(G.CampaignModes),CampaignBoss=require(G.CampaignBoss),
    CampaignEnemies=require(G.CampaignEnemies),Director=require(G.LevelDirector),GuardianPattern=require(G.GuardianPattern),
    HealingFlies=require(G.HealingFlies),EnemyCarry=require(G.EnemyCarry),WalkerClubs=require(G.WalkerClubs),
    DragonFlight=require(G.DragonFlight),BossIntro=require(G.BossIntro)}
local result={sourceSha256=require(project.BuildInfo).sourceSha256,checks={},cases={},cleanup={},
    fixture='Prepared stage6 seed8125; two synthetic heroes; real Session, CampaignDirector, GameWorld, CampaignWorld and native Models',
    preparation='World offset Z4096/Y32; initial phase0; hero1 on serpent1 head at Z+5 and hero2 on segment3 at Z-5. Later hero1 starts X65.9/Y9/Z-2 on vault1 exit ledge and hero2 X0/Y3/Z2 on arrival. Real physical fall is prepared below the native FallY.',
    limitations='Synthetic server roster, explicit starting poses and initial phase; no actual Players, natural route clear, keyboard/touch, network, reconnect or physical-device claim'}
local created={};local DT=1/60;local ticks=0
local worldName='BrickToadsSerpentsQA_'..Http:GenerateGUID(false)
local ownedNames={[worldName]=true}
local originalFolders={};for _,item in ipairs(workspace:GetChildren()) do originalFolders[item]=true end
local lightingBefore={}
for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do
    lightingBefore[key]=Lighting[key]
end
local atmosphere=Lighting:FindFirstChild('CausewayAtmosphere');local atmosphereBefore={}
if atmosphere then for _,key in ipairs({'Density','Offset','Color','Decay','Glare','Haze'}) do atmosphereBefore[key]=atmosphere[key] end end
local defaults={}
for _,item in ipairs(workspace:GetChildren()) do
    if (item.Name=='Baseplate' and item:IsA('BasePart')) or (item.Name=='SpawnLocation' and item:IsA('SpawnLocation')) then
        defaults[#defaults+1]={original=item,copy=assert(item:Clone(),'Cannot snapshot blank-place default '..item.Name)}
    end
end
local function check(label,condition) assert(condition,label);result.checks[#result.checks+1]=label end
local function near(a,b) return math.abs(a-b)<.001 end
local function vec(p) return Vector3.new(p.x,p.y,p.z) end
local function resources(f,id)
    local h=f.session.state.heroes[id]
    return {actorId=h.actorId,attempt=h.attempt,rawLife=f.session.combat[id].rawLife,respawns=h.respawns,status=h.status}
end
local function unchanged(f,id,before,label)
    local after=resources(f,id)
    for key,value in pairs(before) do check(label..' preserves '..key,after[key]==value) end
    return after
end
local function coherent(f,id,label)
    local a,b=f.modes.actors[id],f.world.actors[id]
    check(label..' native Model',b.model:IsA('Model') and b.model:IsDescendantOf(workspace) and b.root.Anchored)
    check(label..' local/native pose',(b.root.Position-f.world.offset-vec(a.position)).Magnitude<.001)
end
local function begin()
    local d=definitions.build(6,8125);local config=require(G.GameConfig)(require(R.Config),d)
    -- Register ownership before any constructor side effect. World.new does not
    -- yield, so a newly added exact-name Folder belongs to this construction.
    local f={definition=d,config=config,now=workspace:GetServerTimeNow(),seq={},models={},parts={},constructorFolders={}}
    created[#created+1]=f
    for _,item in ipairs(workspace:GetChildren()) do f.constructorFolders[item]=true end
    f.constructorStarted=true
    f.world=World.new(BaseWorld,config,{name=worldName,
        offset={x=0,y=32,z=4096},characterAppearance=CharacterAppearance,
        guardianAppearance=GuardianAppearance,campaignWorld=CampaignWorld})
    local world=f.world
    f.session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'},
        {userId=2,template='Mr. Yellow'}},'native-serpents-'..Http:GenerateGUID(false),world,nil,
        {groupId='native-serpents-fixture',levelId=d.id})
    check('Serpents initial pair spawn',f.session:step(f.now)=='OK')
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.session.contextualAttack=function(slot,now,action) return f.director:interact(slot,now,action) end
    f.modes=f.director.modes;f.modes:_slice(0)
    f.hazardRows=d.course.hazards
    for _,body in pairs(world.actors) do f.models[body.model]=true end
    for _,row in pairs(world.campaignWorld.objects) do f.parts[row.part]=true end
    return f
end
local function move(f,id,x,z)
    local h=f.session.state.heroes[id];f.seq[id]=(f.seq[id] or 0)+1
    assert(f.session:intent(id,{kind='Move',runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=f.seq[id],x=x,z=z,run=false},f.now)=='OK',
        'Session Move rejected')
end
local function tick(f)
    f.now+=DT;assert(f.session:step(f.now)=='OK','Session slice rejected');f.director:step(f.now,DT)
    for _,body in pairs(f.world.actors) do f.models[body.model]=true end
    for _,row in pairs(f.world.campaignWorld.objects) do f.parts[row.part]=true end
    ticks+=1;if ticks%60==0 then task.wait() end
end
local function prepare(f,id,p,grounded)
    -- Explicit starting stance only. No route, jump or safe-point steering.
    local a=f.modes.actors[id]
    a.position=table.clone(p);a.previous=table.clone(p);a.velocity={x=0,y=0,z=0}
    a.input={x=0,z=0,run=false,at=f.modes.now};a.grounded=false;a.support=nil;a.airSpeed=nil;a.external=nil
    if grounded then f.modes:_ground(a,a.previous,0);assert(a.grounded,'Prepared stance has no authored support') end
    assert(f.world:campaignPose(id,a.position,f.definition.mode,a.velocity),'Native pose preparation rejected')
    return a
end
local function activeSpikes(f,label)
    check(label..' authored spike rows retained',f.definition.course.hazards==f.hazardRows and #f.hazardRows==4)
    local active=0
    for _,hazard in ipairs(f.modes.hazards) do
        if hazard.kind=='Spike' and hazard.active~=false then active+=1 end
    end
    check(label..' four active spikes',active==4)
end
local function supportObjects(f,label)
    check(label..' all sixteen serpent segments',#f.modes.supports==16)
    for _,support in ipairs(f.modes.supports) do
        local row=assert(f.world.campaignWorld.objects[support.id],'Missing native segment '..support.id)
        local p,def=row.part,support.definition
        assert(p:IsA('BasePart') and p.Parent and p.CanCollide,'Missing solid native segment '..support.id)
        assert((p.Position-f.world.offset-vec(support.position)).Magnitude<.001,'Segment native/local pose '..support.id)
        assert(near(p.Size.X,def.w) and near(p.Size.Y,def.h) and near(p.Size.Z,def.d),'Segment dimensions '..support.id)
    end
    check(label..' native segments match authored pose and size',true)
end
local function run()
    local f=begin();local m=f.modes;local before1,before2=resources(f,1),resources(f,2)
    check('Serpents fresh pair resources',before1.rawLife==47 and before2.rawLife==47 and before1.attempt==1
        and before2.attempt==1 and before1.respawns==3 and before2.respawns==3)
    check('Serpents prepared planar first coil',f.definition.variation.sectionChoices[1]==2)
    activeSpikes(f,'Before carry');supportObjects(f,'Before carry')
    local head=m.supports[1];local tail=m.supports[3]
    local a=prepare(f,1,{x=head.position.x,y=head.position.y+3.5,z=5},true)
    local b=prepare(f,2,{x=tail.position.x,y=tail.position.y+3.5,z=-5},true)
    local models={[1]=f.world.actors[1].model,[2]=f.world.actors[2].model}
    local start={table.clone(a.position),table.clone(b.position)}
    local directions={[1]={positive=false,negative=false},[2]={positive=false,negative=false}}
    local visited={[1]={},[2]={}};local minX,maxX=math.huge,-math.huge
    for frame=1,960 do
        local oldX={[1]=a.position.x,[2]=b.position.x}
        tick(f);minX=math.min(minX,head.position.x);maxX=math.max(maxX,head.position.x)
        for _,id in ipairs({1,2}) do
            local actor=m.actors[id];local h=f.session.state.heroes[id]
            assert(h.status=='Alive' and actor.grounded and actor.support
                and string.sub(actor.support,1,9)=='serpent-1','Standing native rider lost first-coil support at frame '..frame)
            assert(f.world.actors[id].model==models[id],'Carry replaced native hero Model')
            assert((f.world.actors[id].root.Position-f.world.offset-vec(actor.position)).Magnitude<.001,'Carry local/native mismatch')
            local matched
            for _,support in ipairs(m.supports) do if support.id==actor.support then
                assert(near(actor.position.y,support.position.y+3.5),'Rider support-top mismatch')
                matched=true
            end end
            assert(matched,'Rider support missing from native segments')
            assert(actor.input.x==0 and actor.input.z==0,'Carry supplied steering input')
            visited[id][actor.support]=true
            local delta=actor.position.x-oldX[id]
            if delta>.0001 then directions[id].positive=true elseif delta<-.0001 then directions[id].negative=true end
        end
    end
    check('Serpents head crosses outbound and returning ends',minX<19.2 and maxX>54.8)
    for _,id in ipairs({1,2}) do
        local count=0;for _ in pairs(visited[id]) do count+=1 end
        check('Serpents rider '..id..' carried through both directions',directions[id].positive and directions[id].negative)
        check('Serpents rider '..id..' remains on same native Model',f.world.actors[id].model==models[id])
        coherent(f,id,'Serpents carried rider '..id)
        result.cases[#result.cases+1]={case='Stationary segment rider',hero=id,start=start[id],finish=table.clone(m.actors[id].position),
            elapsed=m.elapsed,distinctSupports=count,directions=directions[id]}
    end
    unchanged(f,1,before1,'Serpents first carried rider');unchanged(f,2,before2,'Serpents second carried rider')
    supportObjects(f,'After reversals');activeSpikes(f,'After reversals')
    prepare(f,1,{x=65.9,y=9,z=-2},true);prepare(f,2,{x=0,y=3,z=2},true)
    local trailingStart=table.clone(m.actors[2].position);move(f,1,1,0);tick(f)
    check('Serpents ordinary walk crosses first room exit',m.room==2 and not m.complete and not f.director.result)
    check('Serpents first exit opens shared second checkpoint',m.actors[1].checkpoint==2 and m.actors[2].checkpoint==2)
    check('Serpents trailing body stays on its ledge',(vec(m.actors[2].position)-vec(trailingStart)).Magnitude<.001
        and f.world.actors[2].model==models[2])
    unchanged(f,1,before1,'Serpents exit walker');unchanged(f,2,before2,'Serpents trailing checkpoint hero')
    coherent(f,1,'Serpents first exit');coherent(f,2,'Serpents trailing checkpoint')
    -- A native body below FallY is consumed by Session's ordinary hazard pass.
    local falling=f.world.actors[2];local oldModel=falling.model
    f.world:campaignRelease(2)
    check('Serpents physical fall pose prepared',f.world:placeActor(2,{x=0,y=f.definition.bounds.minY-30,z=2}))
    f.now+=DT;check('Serpents physical fall Session step',f.session:step(f.now)=='OK')
    local pending=resources(f,2)
    check('Serpents ordinary fall awaits respawn',pending.status=='AwaitingRespawn' and pending.actorId==nil
        and pending.attempt==1 and pending.respawns==3 and pending.rawLife==0)
    local reason;for _,row in ipairs(f.session.logs) do if row.kind=='ConfirmedDeath' and row.userId==2 then reason=row.data.reason end end
    check('Serpents confirmed native death reason Fall',reason=='Fall')
    tick(f)
    local after=resources(f,2);local cp=f.definition.course.checkpoints[2]
    check('Serpents ordinary retry spends exactly one reserve',after.status=='Alive' and after.attempt==2 and after.respawns==2
        and after.rawLife==47 and after.actorId~=before2.actorId)
    check('Serpents retry replaces only dead Model',f.world.actors[2].model~=oldModel and f.world.actors[1].model==models[1])
    check('Serpents paid retry uses opened room ledge',near(m.actors[2].position.x,cp.position.x)
        and near(m.actors[2].position.y,cp.position.y) and near(m.actors[2].position.z,2) and m.actors[2].checkpoint==2
        and m.actors[2].grounded and not (f.session.state.heroes[2].shield and f.session.state.heroes[2].shield.kind=='Emergency'))
    coherent(f,2,'Serpents paid checkpoint retry');unchanged(f,1,before1,'Serpents surviving walker')
    activeSpikes(f,'After checkpoint retry')
    check('Serpents prepared acceptance does not claim course clear',m.room==2 and not m.complete and not f.director.result)
    result.cases[#result.cases+1]={case='First exit shared checkpoint and real native fall retry',trailingStart=trailingStart,
        pending=pending,after=after,checkpoint=cp.position,spawn=table.clone(m.actors[2].position),deathReason=reason}
end
local ok,err=xpcall(function() run();result.status='PASS' end,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
local cleanup={stage=6,errors={},worldRemoved=true,actorRegistryEmpty=true,nativeBodiesRemoved=true,nativeObjectsRemoved=true}
local function teardown(name,callback)
    local success,message=pcall(callback)
    if not success then cleanup.errors[#cleanup.errors+1]=name..': '..tostring(message) end
end
for _,f in ipairs(created) do
    if f.world then
        teardown('remember created native objects',function()
            for _,body in pairs(f.world.actors) do f.models[body.model]=true end
            if f.world.campaignWorld then for _,row in pairs(f.world.campaignWorld.objects) do f.parts[row.part]=true end end
        end)
        if f.director then teardown('director close',function() f.director:close('AcceptanceClosed') end) end
        teardown('actor clear',function() f.world:clearActors() end)
        teardown('world destroy',function() f.world.folder:Destroy() end)
        cleanup.worldRemoved=cleanup.worldRemoved and f.world.folder.Parent==nil
        cleanup.actorRegistryEmpty=cleanup.actorRegistryEmpty and next(f.world.actors)==nil
        for model in pairs(f.models) do if model.Parent~=nil then cleanup.nativeBodiesRemoved=false end end
        for part in pairs(f.parts) do if part.Parent~=nil then cleanup.nativeObjectsRemoved=false end end
    elseif f.constructorStarted then
        -- Also cover BaseWorld.new failing before its CombatStandWorld Folder is
        -- returned and renamed. Preserve every Folder present before the call.
        for _,item in ipairs(workspace:GetChildren()) do
            if not originalFolders[item] and not f.constructorFolders[item] and item:IsA('Folder')
                and (ownedNames[item.Name] or item.Name=='CombatStandWorld') then
                teardown('partial constructor world destroy',function() item:Destroy() end)
                cleanup.worldRemoved=cleanup.worldRemoved and item.Parent==nil
            end
        end
    end
end
for _,item in ipairs(workspace:GetChildren()) do
    if not originalFolders[item] and item:IsA('Folder') and ownedNames[item.Name] then cleanup.worldRemoved=false end
end
for key,value in pairs(lightingBefore) do teardown('restore Lighting.'..key,function() Lighting[key]=value end) end
if atmosphere then
    for key,value in pairs(atmosphereBefore) do teardown('restore CausewayAtmosphere.'..key,function() atmosphere[key]=value end) end
else
    teardown('remove fixture atmosphere',function()
        local added=Lighting:FindFirstChild('CausewayAtmosphere');if added then added:Destroy() end
    end)
end
teardown('verify native lighting restoration',function()
    for key,value in pairs(lightingBefore) do assert(Lighting[key]==value,'Lighting.'..key..' differs from snapshot') end
    if atmosphere then
        assert(Lighting:FindFirstChild('CausewayAtmosphere')==atmosphere,'Original atmosphere replaced')
        for key,value in pairs(atmosphereBefore) do assert(atmosphere[key]==value,'CausewayAtmosphere.'..key..' differs from snapshot') end
    else assert(not Lighting:FindFirstChild('CausewayAtmosphere'),'Fixture atmosphere remains') end
    cleanup.lightingRestored=true
end)
cleanup.blankPlaceDefaultsRestored=true
for _,row in ipairs(defaults) do
    teardown('restore blank-place default '..row.original.Name,function()
        local restored=row.original
        if row.original.Parent==nil then restored=row.copy;row.copy.Parent=workspace else row.copy:Destroy() end
        assert(restored.Parent==workspace,'Blank-place default was not restored')
        row.restored=true
    end)
    if not row.restored then cleanup.blankPlaceDefaultsRestored=false end
end
cleanup.pass=#cleanup.errors==0 and cleanup.worldRemoved and cleanup.actorRegistryEmpty and cleanup.nativeBodiesRemoved
    and cleanup.nativeObjectsRemoved and cleanup.lightingRestored==true and cleanup.blankPlaceDefaultsRestored
result.cleanup[1]=cleanup
if not cleanup.pass then result.status='FAIL';result.cleanupFailed=true end
result.fixedTicks=ticks
_G.BrickToadsSerpentsNativeAcceptance=result
return Http:JSONEncode(result)
