-- Studio-only prepared native crossings, not a route clear or device/network test.
-- Synthetic roster; authored stages, course phases, hero/block stances and rat
-- contact pose are explicit. Session alone writes health, attempts and stock.
assert(game:GetService('RunService'):IsStudio(),'Studio acceptance only')
local Http=game:GetService('HttpService')
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
    fixture='Prepared authored stages4/8/9/10/11; real Session intents, CampaignDirector, GameWorld, CampaignWorld and native Models',
    limitations='Synthetic server roster; ordinary AI unstepped; selected poses/phases; no actual Players, rejoin, network, keyboard, touch or full-route claim'}
local created={};local DT=1/60;local ticks=0
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
local function object(f,id) return assert(f.world.campaignWorld.objects[id],'Missing native object '..id).part end
local function coherent(f,id,label)
    local a,b=f.modes.actors[id],f.world.actors[id]
    check(label..' native Model',b.model:IsA('Model') and b.model:IsDescendantOf(workspace) and b.root.Anchored)
    check(label..' logical/native pose',(b.root.Position-f.world.offset-vec(a.position)).Magnitude<.001)
end
local function begin(index,order)
    local d=definitions.build(index,11939);local config=require(G.GameConfig)(require(R.Config),d)
    local world=World.new(require(R.RobloxWorld),config,{name='BrickToadsRemainingCourseQA_'..Http:GenerateGUID(false),
        offset={x=0,y=32,z=4096+#created*512},characterAppearance=require(G.CharacterAppearance),
        guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    local f={definition=d,config=config,world=world,now=workspace:GetServerTimeNow(),seq={},models={}}
    created[#created+1]=f
    local roster={};for _,id in ipairs(order or {1}) do roster[#roster+1]={userId=id,template=id==1 and 'Mr. Green' or 'Mr. Yellow'} end
    f.session=Session.new(require(project.RunLifecycle),Combat,config,roster,'native-course-'..Http:GenerateGUID(false),world,nil,
        {groupId='native-course-fixture',levelId=d.id})
    check('stage '..index..' initial spawn '..table.concat(order or {1},','),f.session:step(f.now)=='OK')
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.session.contextualAttack=function(slot,now,action) return f.director:interact(slot,now,action) end
    f.modes=f.director.modes;f.modes:_slice(0)
    for _,body in pairs(world.actors) do f.models[body.model]=true end
    return f
end
local function move(f,id,x,z)
    local h=f.session.state.heroes[id];f.seq[id]=(f.seq[id] or 0)+1
    assert(f.session:intent(id,{kind='Move',runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=f.seq[id],x=x,z=z,run=false},f.now)=='OK','Session Move rejected')
end
local function tick(f)
    f.now+=DT;assert(f.session:step(f.now)=='OK','Session slice rejected');f.modes:step(f.now,DT)
    for _,body in pairs(f.world.actors) do f.models[body.model]=true end
    ticks+=1;if ticks%60==0 then task.wait() end
end
local function prepare(f,id,p,grounded)
    -- A single explicit starting stance for each isolated crossing.
    local a=f.modes.actors[id]
    a.position=table.clone(p);a.previous=table.clone(p);a.velocity={x=0,y=0,z=0}
    a.input={x=0,z=0,run=false,at=f.modes.now};a.grounded=false;a.support=nil;a.airSpeed=nil;a.external=nil
    if grounded then f.modes:_ground(a,a.previous,0);assert(a.grounded,'Prepared stance has no authored support') end
    assert(f.world:campaignPose(id,a.position,f.definition.mode,a.velocity),'Native pose preparation rejected')
    return a
end
local function physicalFall(f,id)
    -- Native physical fall is detected by the real Session hazard pass.
    local p=table.clone(f.definition.spawn);p.y=f.definition.bounds.minY-30
    f.world:campaignRelease(id);assert(f.world:placeActor(id,p),'Fall pose rejected')
    f.now+=DT;assert(f.session:step(f.now)=='OK','Fall Session slice rejected')
    check('stage '..f.definition.campaignIndex..' ordinary physical death',f.session.state.heroes[id].status=='AwaitingRespawn')
end
local function ice(order)
    local f=begin(4,order);local b=f.modes.blocks[1];local p,def=b.position,b.definition
    local before1,before2=resources(f,1),resources(f,2)
    check('Ice fresh resources '..table.concat(order,','),before1.rawLife==47 and before2.rawLife==47
        and before1.attempt==1 and before2.attempt==1 and before1.respawns==3 and before2.respawns==3)
    local rider=prepare(f,2,{x=p.x,y=p.y+def.h/2+3,z=p.z},true)
    prepare(f,1,{x=p.x-def.w/2-1.6,y=p.y-def.h/2+3,z=p.z},true)
    local oldBlock,oldRider=p.x,rider.position.x;local model=f.world.actors[2].model
    for n=1,80 do if n%6==1 then move(f,1,1,0) end;tick(f) end
    local shift=p.x-oldBlock
    check('Ice block pushed '..table.concat(order,','),shift>.1)
    check('Ice rider carried independent of order '..table.concat(order,','),near(rider.position.x-oldRider,shift)
        and rider.grounded and rider.support==b.id and f.world.actors[2].model==model)
    coherent(f,1,'Ice pusher');coherent(f,2,'Ice rider')
    check('Ice native block pose '..table.concat(order,','),(object(f,b.id).Position-f.world.offset-vec(p)).Magnitude<.001)
    unchanged(f,1,before1,'Ice pusher');unchanged(f,2,before2,'Ice rider')
    result.cases[#result.cases+1]={case='Ice co-op push',order=order,blockShift=shift,riderShift=rider.position.x-oldRider}
    for _,side in ipairs({-1,1}) do
        local blockX,blockZ=p.x,p.z
        prepare(f,1,{x=p.x,y=p.y-def.h/2+3,z=p.z+side*(def.d/2+1.3)},true)
        for n=1,24 do
            if n%6==1 then move(f,1,0,-side) end;tick(f)
            assert((f.modes.actors[1].position.z-p.z)*side>=def.d/2+1.2-.001,'Ice Z face penetrated')
        end
        check('Ice solid Z face '..side..' order '..table.concat(order,','),near(p.x,blockX) and near(p.z,blockZ))
        coherent(f,1,'Ice Z face '..side)
    end
    unchanged(f,1,before1,'Ice Z collisions');unchanged(f,2,before2,'Ice standing rider')
end
local function ascent()
    local f=begin(8);local before=resources(f,1);local lift=f.modes.supports[1]
    local a=prepare(f,1,{x=lift.position.x,y=lift.position.y+3.5,z=lift.position.z},true)
    local peak=a.position.y
    for _=1,450 do
        tick(f);peak=math.max(peak,a.position.y)
        assert(a.grounded and a.support==lift.id and near(a.position.y,lift.position.y+3.5),'Native lift lost rider')
    end
    check('Ascent lift traverses both endpoints',peak>37 and lift.position.y<18)
    coherent(f,1,'Ascent lift');check('Ascent native lift pose',(object(f,lift.id).Position-f.world.offset-vec(lift.position)).Magnitude<.001)
    local fan=f.definition.course.fans[1]
    a=prepare(f,1,{x=fan.x,y=27,z=0},true);local start=a.position.y
    for _=1,60 do tick(f) end
    check('Ascent fan raises native body',a.position.y>start+5 and a.velocity.y>0)
    coherent(f,1,'Ascent fan');unchanged(f,1,before,'Ascent lift/fan')
    result.cases[#result.cases+1]={case='Ascent lift and fan',liftPeak=peak,fanRise=a.position.y-start,springPower=f.definition.course.springs[1].power}
    check('Ascent retains spring power68',f.definition.course.springs[1].power==68)
end
local function tubes()
    local f=begin(9);local before=resources(f,1)
    local a=prepare(f,1,{x=60,y=-10,z=0},false)
    for _=1,30 do tick(f) end
    check('Tubes current is physical drift',a.medium=='Water' and a.velocity.x<0 and a.position.x<60 and a.input.x==0)
    local oldY=a.position.y;move(f,1,0,-1);tick(f)
    check('Tubes Session swim steering',a.position.y>oldY and a.velocity.y>0);coherent(f,1,'Tubes swim')
    unchanged(f,1,before,'Tubes current/swim')
    prepare(f,1,f.definition.spawn,true);tick(f)
    check('Tubes dry breach restores oxygen',a.medium=='Dry' and a.oxygen==f.definition.course.oxygenSeconds)
    prepare(f,1,{x=60,y=-10,z=0},false)
    local frames=0
    while f.session.state.heroes[1].status=='Alive' and frames<1140 do
        if frames%6==0 then move(f,1,5/28,.9) end
        tick(f);frames+=1
    end
    local after=resources(f,1)
    check('Tubes oxygen expiry awaits real respawn',after.status=='AwaitingRespawn' and after.rawLife==0
        and after.actorId==nil and after.attempt==1 and after.respawns==3)
    local reason;for _,row in ipairs(f.session.logs) do if row.kind=='ConfirmedDeath' then reason=row.data.reason end end
    check('Tubes death reason is drowning',reason=='CampaignDrowned')
    result.cases[#result.cases+1]={case='Tubes oxygen death',frames=frames,before=before,after=after,reason=reason}
end
local function race()
    local f=begin(10);local r=f.modes.race;local before=resources(f,1);local rival=f.world.actors[-98]
    local bomb=f.definition.course.bombs[1]
    -- Explicit rat phase/contact preparation on the actual authored first bomb.
    r.position=table.clone(bomb.position);r.previous=table.clone(r.position);r.velocity={x=0,y=0,z=0};r.introRemaining=0;r:_pose()
    physicalFall(f,1)
    local pending=resources(f,1);f.modes:step(f.now,DT)
    check('Race bomb physically contacts after same-frame ordinary death',r.failed and r.failedAttempts[1]==pending.attempt)
    check('Race does not charge stock at explosion',pending.status=='AwaitingRespawn' and pending.respawns==3 and pending.attempt==1)
    tick(f)
    local after=resources(f,1)
    check('Race committed retry spends one reserve',after.status=='Alive' and after.attempt==2 and after.respawns==2 and after.rawLife==47
        and after.actorId~=before.actorId)
    check('Race resets from previously pending cohort',not r.failed and r.bombIndex==1 and r.failedAttempts==nil and r.introRemaining>0)
    check('Race rival native body retained',f.world.actors[-98]==rival and rival.model:IsDescendantOf(workspace))
    coherent(f,1,'Race committed retry')
    result.cases[#result.cases+1]={case='Race pending death bomb contact and committed retry',before=before,pending=pending,after=after}
end
local function clinger()
    local f=begin(11)
    check('Clinger prepared actual Buzzball chase',f.director:_startBoss(f.now,true))
    local boss=f.director.boss;local body=f.world.actors[-99];local life=boss.enemies[-99].rawLife
    physicalFall(f,1);tick(f)
    local h=f.session.state.heroes[1]
    check('Clinger retry has ordinary Normal shield',h.attempt==2 and h.respawns==2 and h.shield and h.shield.kind=='Normal')
    local heroActor,heroModel=h.actorId,f.world.actors[1].model
    local total=0;for _,segment in ipairs(f.definition.course.path) do total+=segment.length end
    local frames=math.ceil((total/f.definition.course.chaseSpeed+2)*60)
    local shieldOvertake=false
    for n=1,frames do
        tick(f);local hero=f.session.state.heroes[1]
        if hero.shield and f.now<hero.shield.deadline and f.modes.chaseProgress>f.modes.actors[1].progress+3 then shieldOvertake=true end
        assert(hero.status=='Alive','Clinger protected overtake fixture died before endpoint catch')
    end
    check('Clinger shield permits physical overtake',shieldOvertake)
    check('Clinger pursuer stops at route endpoint',near(f.modes.chaseProgress,total) and not f.modes.chaseFinished)
    check('Clinger living hero retains committed actor/body',f.session.state.heroes[1].actorId==heroActor and f.world.actors[1].model==heroModel)
    local a=f.modes.actors[1];local chaseBody=body.model
    for n=1,1800 do
        if f.session.state.heroes[1].status~='Alive' then break end
        if n%6==1 then local segment=f.definition.course.path[a.segment];assert(segment,'Hero passed endpoint uncaught');move(f,1,segment.direction.x,segment.direction.z) end
        -- Resend immediately on authored corners rather than holding a stale direction.
        local segment=f.definition.course.path[a.segment]
        if segment and (a.input.x~=segment.direction.x or a.input.z~=segment.direction.z) then move(f,1,segment.direction.x,segment.direction.z) end
        tick(f)
    end
    local after=resources(f,1)
    check('Clinger endpoint catches hero before completion',after.status=='AwaitingRespawn' and after.attempt==2 and after.respawns==2
        and after.actorId==nil and after.rawLife==0 and not a.finished and not f.modes.complete and math.abs(a.progress-total)<=3.5)
    check('Clinger keeps actual boss body and Life207',f.world.actors[-99]==body and body.model==chaseBody and life==207
        and boss.enemies[-99].rawLife==207 and f.modes.chaseLife==207 and not boss.enemies[-99].dead)
    result.cases[#result.cases+1]={case='Clinger shield overtake and endpoint catch',routeLength=total,heroProgress=a.progress,chaseProgress=f.modes.chaseProgress,bossLife=life,after=after}
end
local ok,err=xpcall(function() ice({1,2});ice({2,1});ascent();tubes();race();clinger();result.status='PASS' end,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
for _,f in ipairs(created) do
    local row={stage=f.definition.campaignIndex,errors={}}
    local function teardown(name,callback) local success,message=pcall(callback);if not success then row.errors[#row.errors+1]=name..': '..tostring(message) end end
    if f.director then teardown('director close',function() f.director:close('AcceptanceClosed') end) end
    teardown('actor clear',function() f.world:clearActors() end)
    teardown('world destroy',function() f.world.folder:Destroy() end)
    row.worldRemoved=f.world.folder.Parent==nil;row.actorRegistryEmpty=next(f.world.actors)==nil;row.nativeBodiesRemoved=true
    for model in pairs(f.models) do if model.Parent~=nil then row.nativeBodiesRemoved=false end end
    row.pass=#row.errors==0 and row.worldRemoved and row.actorRegistryEmpty and row.nativeBodiesRemoved
    result.cleanup[#result.cleanup+1]=row;if not row.pass then result.status='FAIL';result.cleanupFailed=true end
end
result.fixedTicks=ticks
_G.BrickToadsRemainingCourseAcceptance=result
return Http:JSONEncode(result)
