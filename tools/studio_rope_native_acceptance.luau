-- Studio-only prepared stage2 acceptance. Execute this chunk on the server.
-- Synthetic two-hero roster, safe shaft lanes, one fall pose and one Raven contact
-- pose are explicit. Native Session alone changes health, identity and resources.
-- Ordinary AI is unstepped; this is not network, device or full-route acceptance.
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
    fixture='Prepared stage2, seed11939, two synthetic heroes; real Session intents, CampaignDirector, GameWorld, CampaignWorld and native Models',
    limitations='Ordinary AI unstepped; safe shaft lanes, fall and Raven contact poses selected explicitly; no actual Players, rejoin, network, keyboard, touch or full-route claim'}
local DT=1/60;local ticks=0;local f
local worldName='BrickToadsRopeQA_'..Http:GenerateGUID(false)
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
        defaults[#defaults+1]={original=item,parent=item.Parent}
        item.Parent=nil
    end
end
local function check(label,condition) assert(condition,label);result.checks[#result.checks+1]=label end
local function vec(p) return Vector3.new(p.x,p.y,p.z) end
local function near(a,b) return math.abs(a-b)<.001 end
local function resources(id)
    local h=f.session.state.heroes[id]
    return {runId=f.session.state.runId,levelEpoch=f.session.state.levelEpoch,actorId=h.actorId,
        attempt=h.attempt,rawLife=f.session.combat[id].rawLife,respawns=h.respawns,status=h.status}
end
local function unchanged(id,before,label)
    local after=resources(id)
    for key,value in pairs(before) do check(label..' preserves '..key,after[key]==value) end
    return after
end
local function remember()
    if not f or not f.world then return end
    for _,body in pairs(f.world.actors) do f.models[body.model]=true end
    for _,row in pairs(f.world.campaignWorld.objects) do f.parts[row.part]=true end
end
local function coherent(id,label)
    local h,a,b=f.session.state.heroes[id],f.modes.actors[id],f.world.actors[id]
    check(label..' native live anchored Model',b.model:IsA('Model') and b.model:IsDescendantOf(workspace)
        and b.humanoid.Health>0 and b.root.Anchored and b.campaignControl==true)
    check(label..' Session/mode/Model actor identity',a.actorId==h.actorId and a.attempt==h.attempt
        and b.model:GetAttribute('ActorId')==h.actorId)
    check(label..' logical/native pose',(b.root.Position-f.world.offset-vec(a.position)).Magnitude<.001)
    local row=assert(f.world.campaignWorld.objects['rope-'..id],'Missing native rope')
    local rope=row.part;local anchor=vec(f.definition.course.anchor)+f.world.offset
    local endpoint=vec(a.position)+f.world.offset
    check(label..' native rope exists',row.kind=='Rope' and rope:IsA('BasePart') and rope:IsDescendantOf(f.world.geometry))
    check(label..' rope endpoints match anchor/body',(rope.Position-rope.CFrame.LookVector*rope.Size.Z/2-anchor).Magnitude<.001
        and (rope.Position+rope.CFrame.LookVector*rope.Size.Z/2-endpoint).Magnitude<.001)
    check(label..' rope stays noncollidable',not rope.CanCollide and not rope.CanQuery)
end
local function prepare(id,p)
    -- Explicit isolated starting stance; no health, identity or resource writes.
    local a=f.modes.actors[id]
    a.position=table.clone(p);a.previous=table.clone(p);a.velocity={x=0,y=0,z=0}
    a.input={x=0,z=0,run=false,at=f.modes.now};a.grounded=false;a.support=nil;a.external=nil
    assert(f.world:campaignPose(id,a.position,'Rope',a.velocity),'Prepared native pose rejected')
    return a
end
local function intent(id,kind,fields)
    local h=f.session.state.heroes[id];f.seq[id]=(f.seq[id] or 0)+1
    local packet={kind=kind,runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=f.seq[id]}
    for key,value in pairs(fields or {}) do packet[key]=value end
    return f.session:intent(id,packet,f.now)
end
local function tick()
    f.now+=DT;assert(f.session:step(f.now)=='OK','Session slice rejected');f.modes:step(f.now,DT)
    remember();ticks+=1;if ticks%60==0 then task.wait() end
end
local function main()
    local d=definitions.build(2,11939);local config=require(G.GameConfig)(require(R.Config),d)
    f={definition=d,config=config,now=workspace:GetServerTimeNow(),seq={},models={},parts={}}
    f.world=World.new(require(R.RobloxWorld),config,{name=worldName,offset={x=0,y=32,z=4096},
        characterAppearance=require(G.CharacterAppearance),guardianAppearance=require(G.GuardianAppearance),
        campaignWorld=require(G.CampaignWorld)})
    f.session=Session.new(require(project.RunLifecycle),Combat,config,
        {{userId=1,template='Mr. Green'},{userId=2,template='Mr. Yellow'}},'native-rope-'..Http:GenerateGUID(false),f.world,nil,
        {groupId='native-rope-fixture',levelId=d.id})
    check('Rope two-hero initial Session spawn',f.session:step(f.now)=='OK'
        and f.session.state.heroes[1].status=='Alive' and f.session.state.heroes[2].status=='Alive')
    f.director=require(G.CampaignDirector).new(f.session,f.world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.session.contextualAttack=function(id,now,action) return f.director:interact(id,now,action) end
    f.modes=f.director.modes;remember()
    local before1,before2=resources(1),resources(2)
    local body1,body2=f.world.actors[1],f.world.actors[2]
    check('Rope fresh canonical resources',before1.attempt==1 and before2.attempt==1 and before1.respawns==3
        and before2.respawns==3 and before1.rawLife==47 and before2.rawLife==47)
    local a=prepare(1,{x=0,y=d.spawn.y,z=16});prepare(2,{x=0,y=d.spawn.y,z=-16})
    -- Inputs pass through Session and the native World adapter, not Modes:move.
    for n=1,60 do
        if n%6==1 then assert(intent(1,'Move',{x=1,z=0,run=false})=='OK','Swing Move rejected') end
        tick()
    end
    check('Rope accepted steering produces physical swing',a.position.x>5 and a.position.x<=d.course.swingLimit
        and near(a.position.y,d.spawn.y-d.course.descentSpeed) and a.input.x==1)
    coherent(1,'Rope swing hero1');coherent(2,'Rope swing hero2')
    local swing={x=a.position.x,y=a.position.y,z=a.position.z}
    assert(intent(1,'Move',{x=0,z=0,run=false})=='OK','Swing release rejected')
    local cp=d.course.checkpoints[2];local frames=60
    while a.progress<cp.progress+3 do tick();frames+=1;assert(frames<900,'Checkpoint descent exceeded bound') end
    check('Rope descent unlocks real checkpoint2',a.checkpoint==2 and f.modes.actors[2].checkpoint==2 and not f.modes.complete)
    check('Rope native Models retained during descent',f.world.actors[1]==body1 and f.world.actors[2]==body2)
    coherent(1,'Rope checkpoint hero1');coherent(2,'Rope checkpoint hero2')
    unchanged(1,before1,'Rope swing/descent hero1');unchanged(2,before2,'Rope swing/descent hero2')
    result.cases[#result.cases+1]={case='Prepared two-hero swing and descent',seed=11939,frames=frames,swing=swing,
        descent=a.progress,checkpoint=a.checkpoint,checkpointProgress=cp.progress,safeLanes={16,-16}}

    -- Release one native body and move it below the real fall plane. Session's
    -- own hazard pass confirms death; no direct _die/health/stock/identity writes.
    local survivorBefore=resources(2);local originalModel=body1.model
    f.world:campaignRelease(1)
    assert(f.world:placeActor(1,{x=0,y=d.bounds.minY-30,z=16}),'Prepared fall pose rejected')
    f.now+=DT;assert(f.session:step(f.now)=='OK','Physical fall Session slice rejected');remember()
    local pending=resources(1)
    check('Rope native physical fall awaits paid respawn',pending.status=='AwaitingRespawn' and pending.actorId==nil
        and pending.attempt==before1.attempt and pending.respawns==before1.respawns and pending.rawLife==0)
    local deaths,reason=0,nil
    for _,row in ipairs(f.session.logs) do if row.kind=='ConfirmedDeath' and row.userId==1 then deaths+=1;reason=row.data.reason end end
    check('Rope Session confirms exactly one Fall death',deaths==1 and reason=='Fall')
    unchanged(2,survivorBefore,'Rope fall survivor')
    f.modes:step(f.now,DT);tick()
    local after=resources(1);local replacement=f.world.actors[1]
    check('Rope paid respawn spends exactly one reserve',after.status=='Alive' and after.attempt==before1.attempt+1
        and after.respawns==before1.respawns-1 and after.rawLife==47 and after.actorId~=before1.actorId)
    check('Rope replacement retains run and level',after.runId==before1.runId and after.levelEpoch==before1.levelEpoch)
    check('Rope respawn replaces only the dead native Model',replacement~=body1 and replacement.model~=originalModel
        and originalModel.Parent==nil and f.world.actors[2]==body2)
    check('Rope respawn returns to unlocked checkpoint2',f.modes.actors[1].checkpoint==2
        and near(f.modes.actors[1].position.x,cp.position.x)
        and near(f.modes.actors[1].position.y,cp.position.y-DT*d.course.descentSpeed))
    coherent(1,'Rope paid respawn');coherent(2,'Rope survivor after retry')
    for _=1,18 do tick() end
    unchanged(1,after,'Rope resumed descent');unchanged(2,survivorBefore,'Rope retry survivor')
    coherent(1,'Rope resumed descent')
    local commits=0;for _,row in ipairs(f.session.logs) do if row.kind=='CommitSpawn' and row.data.code=='OK' then commits+=1 end end
    check('Rope Session has two initial spawns and one paid commit',commits==3)
    result.cases[#result.cases+1]={case='Native physical fall and checkpoint retry',before=before1,pending=pending,after=after,
        deathReason=reason,confirmedDeaths=deaths,committedSpawns=commits,checkpoint=f.modes.actors[1].checkpoint}

    -- One authored Raven is posed four studs in front of the hero in an empty
    -- shaft slice. World:targets still performs its native hitbox/raycast query.
    local ravenId,raven
    for id,e in pairs(f.director.ordinary.enemies) do if e.kind=='Raven' and not e.dead then ravenId,raven=id,e;break end end
    assert(ravenId,'Authored Rope roster has no live Raven')
    local enemyActor=raven.actorId;local enemyBody=f.world.actors[ravenId];local raw=raven.rawLife
    prepare(1,{x=0,y=150,z=16});f.world:aim(1,1,0)
    assert(f.world:campaignPose(ravenId,{x=4,y=150,z=16},'EnemyFly',{x=-1,y=0,z=0}),'Raven native pose rejected')
    local found=false;for _,id in ipairs(f.world:targets(1,config.Attacks.RopeStrike)) do if id==ravenId then found=true end end
    check('Rope contextual target uses actual Raven Model and native query',found and raw==79
        and enemyBody.model:IsDescendantOf(workspace) and enemyBody.model:GetAttribute('ActorId')==enemyActor)
    local kickBefore=resources(1);local otherBefore=resources(2)
    f.now+=DT;assert(intent(1,'Attack',{attack='Punch'})=='OK','Session contextual Rope kick rejected');remember()
    check('Rope Session primary spends the actual Raven life',raven.dead and raven.actorId==enemyActor
        and f.world.actors[ravenId]==enemyBody and enemyBody.humanoid.Health==0 and f.session.combat[1].attack==nil)
    local hit,accepted,death
    for _,row in ipairs(f.session.logs) do
        if row.kind=='EnemyHit' and row.data.target==ravenId then hit=row.data end
        if row.kind=='AttackAccepted' and row.userId==1 and row.data.context=='Rope' then accepted=row.data end
        if row.kind=='EnemyDeath' and row.userId==ravenId then death=row.data end
    end
    check('Rope accepted kick logs real source damage and Raven reaction',hit and hit.action=='RopeStrike' and hit.profile==7
        and hit.before==79 and hit.after==71 and accepted and accepted.action=='RopeStrike' and death and death.cause=='RavenReaction')
    unchanged(1,kickBefore,'Rope contextual kick hero');unchanged(2,otherBefore,'Rope contextual kick survivor')
    tick();coherent(1,'Rope after contextual kick')
    result.cases[#result.cases+1]={case='Prepared native contextual Raven kick',enemyId=ravenId,enemyActorId=enemyActor,
        action=hit.action,profile=hit.profile,before=hit.before,afterHit=hit.after,deathCause=death.cause}
    result.status='PASS'
end
local ok,err=xpcall(main,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
local cleanup={stage=2,errors={}}
local function teardown(name,callback) local success,message=pcall(callback);if not success then cleanup.errors[#cleanup.errors+1]=name..': '..tostring(message) end end
if f and f.world then
    teardown('remember created native objects',remember)
    if f.director then teardown('director close',function() f.director:close('AcceptanceClosed') end) end
    teardown('actor clear',function() f.world:clearActors() end)
    teardown('world destroy',function() f.world.folder:Destroy() end)
    cleanup.worldRemoved=f.world.folder.Parent==nil;cleanup.actorRegistryEmpty=next(f.world.actors)==nil
    cleanup.nativeBodiesRemoved=true;for model in pairs(f.models) do if model.Parent~=nil then cleanup.nativeBodiesRemoved=false end end
    cleanup.nativeObjectsRemoved=true;for part in pairs(f.parts) do if part.Parent~=nil then cleanup.nativeObjectsRemoved=false end end
else
    -- The constructor names its owned Folder before building stage geometry.
    -- Also cover a partial BaseWorld constructor before that rename occurs.
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and item:IsA('Folder') and (item.Name==worldName or item.Name=='CombatStandWorld') then
            teardown('partial world destroy',function() item:Destroy() end)
        end
    end
    cleanup.worldRemoved=workspace:FindFirstChild(worldName)==nil
    cleanup.actorRegistryEmpty=true;cleanup.nativeBodiesRemoved=true;cleanup.nativeObjectsRemoved=true
end
teardown('restore native world lighting',function()
    for key,value in pairs(lightingBefore) do Lighting[key]=value end
    if atmosphere then for key,value in pairs(atmosphereBefore) do atmosphere[key]=value end
    else local createdAtmosphere=Lighting:FindFirstChild('CausewayAtmosphere');if createdAtmosphere then createdAtmosphere:Destroy() end end
end)
teardown('restore blank-place defaults',function()
    for _,row in ipairs(defaults) do row.original.Parent=row.parent end
end)
cleanup.lightingRestored=true
for key,value in pairs(lightingBefore) do if Lighting[key]~=value then cleanup.lightingRestored=false end end
cleanup.atmosphereRestored=Lighting:FindFirstChild('CausewayAtmosphere')==atmosphere
if atmosphere then for key,value in pairs(atmosphereBefore) do
    if atmosphere[key]~=value then cleanup.atmosphereRestored=false end
end end
cleanup.defaultsRestored=true
for _,row in ipairs(defaults) do if row.original.Parent~=row.parent then cleanup.defaultsRestored=false end end
cleanup.pass=#cleanup.errors==0 and cleanup.worldRemoved and cleanup.actorRegistryEmpty
    and cleanup.nativeBodiesRemoved and cleanup.nativeObjectsRemoved and cleanup.lightingRestored
    and cleanup.atmosphereRestored and cleanup.defaultsRestored
result.cleanup[1]=cleanup
if not cleanup.pass then result.status='FAIL';result.cleanupFailed=true end
result.fixedTicks=ticks
_G.BrickToadsRopeAcceptance=result
return Http:JSONEncode(result)
