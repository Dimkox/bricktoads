-- Studio-only prepared final attacks and real native EngineDeath contacts.
-- Session alone commits deaths, paid respawns and terminal loss. Synthetic
-- owners and prepared completion/health are explicit; no route/device claim.
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
deps.Core=require(project.RunLifecycle);deps.Combat=Combat;deps.Session=Session
deps.Registry=require(R.ConnectionRegistry);deps.BossQueue=require(G.BossQueue)
deps.CampaignDirector=require(G.CampaignDirector);deps.SourceCombat=require(G.SourceCombat)
local Controller=require(G.GameController)
local result={sourceSha256=require(project.BuildInfo).sourceSha256,checks={},cases={},cleanup={},
    fixture='Prepared seed51 stages8/13 solo/duo; real Controller, Session, campaign boss, queue and native GameWorld Models',
    limitations='Synthetic owner tables; earned course completion, contact positions and final hero/boss vulnerability prepared; actual accepted hero/drone attacks, native projectile collision, native humanoid EngineDeath and committed paid spawns; no actual Players, network, keyboard, touch or route-clear claim'}
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

local function track(f) for _,body in pairs(f.world.actors) do f.models[body.model]=true end end
local function begin(index,count,claimDrone)
    local d=definitions.build(index,51);local config=require(G.GameConfig)(require(R.Config),d)
    local worldName='BrickToadsBossVictoryQA_'..Http:GenerateGUID(false);ownedWorldNames[worldName]=true
    local f={definition=d,config=config,worldName=worldName,ownedFolders={},now=workspace:GetServerTimeNow(),
        players={},models={},prefix='stage '..index..' '..count..' heroes'}
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
    local configured=table.clone(deps);configured.Config=config
    configured.clock=function() return f.now end;configured.guid=function() return 'native-victory-replacement' end
    local c=Controller.new(configured,world);f.controller=c
    local roster={}
    for slot=1,count do
        local player={UserId=7100+slot,DisplayName='Victory owner '..slot,Name='VictoryOwner'..slot,Parent=true}
        f.players[slot]=player;c:join(player);c.ownerSlots[player.UserId]=slot
        c.owners[slot]={userId=player.UserId,displayName=player.DisplayName,username=player.Name,template='Mr. Green'}
        roster[slot]={userId=slot,template='Mr. Green'}
    end
    f.session=Session.new(deps.Core,Combat,config,roster,'native-victory-'..Http:GenerateGUID(false),world,nil,
        {groupId='native-victory-fixture',levelId=d.id})
    c.current=f.session;check(f.prefix..' initial committed bodies',f.session:step(f.now)=='OK')
    c.campaignIndex=index;c.campaignSeed=51;c.baseSessionHooks={}
    local originalHit=f.session._hit
    f.session._hit=function(session,attacker,target,action,tuning)
        if target<0 then return c.director:hit(attacker,target,action,tuning) end
        return originalHit(session,attacker,target,action,tuning)
    end
    c:_createDirector(f.now);f.director=c.director;f.modes=f.director.modes;f.bossSlot=c.bossSlot
    if claimDrone then check(f.prefix..' claim actual sentry body',f.director:claim(7191,-1)=='OK') end
    check(f.prefix..' select boss owner',c.bossQueue:select(7190,d.boss.kind,f.now)=='OK')
    local offer=c.bossQueue:view(7190,f.now)
    check(f.prefix..' accept boss offer',c.bossQueue:reply(7190,offer.offerId,true,f.now)=='OK')
    check(f.prefix..' connect boss owner',c.bossQueue:connect(7190,offer.offerId,f.now)=='OK')
    for slot=1,count do f.modes.actors[slot].finished=true end
    f.modes.complete=true;f.director:step(f.now,0)
    check(f.prefix..' actual human boss body',f.director.boss and f.director.boss:controlled(7190).status=='Alive')
    local e=f.director.boss.enemies[-99];e.rawLife=1;if e.progress then e.progress=240 end
    f.director.boss:_health()
    for slot=1,count do
        world:campaignRelease(slot)
        check(f.prefix..' prepared arena contact '..slot,world:placeActor(slot,{x=d.boss.position.x-4,
            y=d.boss.position.y,z=d.boss.position.z+(slot-1)*3}))
        world:face(slot,-99)
    end
    track(f);return f
end
local function tick(f,delta)
    f.now+=delta;f.controller:step(f.now,delta);track(f);ticks+=1
end
local function snapshot(f)
    local rows={};for slot=1,#f.players do local h=f.session.state.heroes[slot]
        rows[slot]={actorId=h.actorId,attempt=h.attempt,respawns=h.respawns,status=h.status,rawLife=f.session.combat[slot].rawLife}
    end;return rows
end
local function prepareLastAttempt(f)
    for _=1,3 do
        for slot=1,#f.players do
            f.world:campaignRelease(slot)
            check(f.prefix..' prepare actual physical stock loss',f.world:placeActor(slot,
                {x=f.definition.spawn.x,y=f.definition.bounds.minY-40,z=f.definition.spawn.z}))
        end
        f.now+=DT;check(f.prefix..' physical death commit',f.session:step(f.now)=='OK')
        for slot=1,#f.players do check(f.prefix..' pending stock obligation',f.session.state.heroes[slot].status=='AwaitingRespawn') end
        f.now+=DT;check(f.prefix..' committed paid stock',f.session:step(f.now)=='OK');f.modes:_syncActors();track(f)
    end
    for slot=1,#f.players do
        local h=f.session.state.heroes[slot]
        check(f.prefix..' ordinary exhausted final attempt',h.attempt==4 and h.respawns==0 and h.status=='Alive')
        f.world:campaignRelease(slot)
        assert(f.world:placeActor(slot,{x=f.definition.boss.position.x-4,y=f.definition.boss.position.y,
            z=f.definition.boss.position.z+(slot-1)*3}));f.world:face(slot,-99)
    end
end
local function finalContact(f)
    local h=f.session.state.heroes[1]
    local packet={kind='Attack',attack='Punch',runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=1}
    check(f.prefix..' accepted real final hero attack',f.session:intent(1,packet,f.now)=='OK')
    check(f.prefix..' final attack remains due',f.session.combat[1].attack~=nil and not f.director.boss.defeated)
    -- Prepare actual native engine deaths while roots still exist, then let
    -- Session resolve its due strike before its ordinary EngineDeath observation.
    -- This is an isolated final-contact fixture, not a natural route playthrough.
    for slot=1,#f.players do
        f.world.actors[slot].humanoid.Health=0
        check(f.prefix..' native EngineDeath observed '..slot,f.world:hazard(slot)=='EngineDeath')
    end
    tick(f,.15)
    check(f.prefix..' due effect defeated actual boss',f.director.boss.defeated)
end
local function pending(index,count)
    local f=begin(index,count);local before=snapshot(f);finalContact(f)
    check(f.prefix..' victory waits before geometry or teardown',f.controller.director==f.director
        and not f.director.closed and not f.controller.finished and f.session.state.levelEpoch==1
        and f.world.config.Level.campaignIndex==index and f.controller.bossQueue.slots[f.bossSlot].state=='Human')
    local dead=snapshot(f)
    for slot=1,count do check(f.prefix..' death spends no stock '..slot,dead[slot].status=='AwaitingRespawn'
        and dead[slot].actorId==nil and dead[slot].attempt==before[slot].attempt and dead[slot].respawns==before[slot].respawns) end
    local view=f.controller:snapshot(f.players[1],f.players)
    check(f.prefix..' pending final status is active',view.status=='Active' and not view.canStart and not view.campaign.complete)
    check(f.prefix..' explicit Start cannot replace pending campaign',f.controller:handle(f.players[1],{kind='Start'},f.players)=='RUN_ACTIVE')
    for _,player in ipairs(f.players) do f.controller:leave(player) end
    tick(f,.6)
    for slot=1,count do local h=f.session.state.heroes[slot]
        check(f.prefix..' offline pending retry stays unpaid '..slot,not h.connected and h.status=='AwaitingRespawn'
            and h.respawns==before[slot].respawns and h.actorId==nil) end
    check(f.prefix..' offline wait retains won director',f.controller.director==f.director and not f.director.closed and not f.controller.finished)
    -- Real reconnects supply fresh Player instances with the same identity;
    -- departed instances remain tombstoned by the connection registry.
    for slot,player in ipairs(f.players) do
        f.players[slot]=table.clone(player);f.controller:join(f.players[slot])
    end
    tick(f,.1)
    local paid=snapshot(f)
    for slot=1,count do check(f.prefix..' next native spawn pays one stock '..slot,paid[slot].status=='Alive'
        and paid[slot].attempt==before[slot].attempt+1 and paid[slot].respawns==before[slot].respawns-1
        and paid[slot].actorId~=before[slot].actorId and f.world.actors[slot].model:IsDescendantOf(workspace)) end
    if index<13 then check(f.prefix..' ordinary advance after paid survivor',f.session.state.levelEpoch==2
        and f.controller.campaignIndex==index+1 and f.world.config.Level.campaignIndex==index+1 and f.director.closed)
    else check(f.prefix..' final victory after paid survivor',f.session.state.levelEpoch==1 and f.controller.finished
        and f.controller.director.result=='Won') end
    check(f.prefix..' boss assignment closed only at completion',f.controller.bossQueue.slots[f.bossSlot].state=='Closed')
    result.cases[#result.cases+1]={case='native final contact waits for offline paid retry',stage=index,count=count,
        before=before,dead=dead,paid=paid,levelEpoch=f.session.state.levelEpoch,campaignIndex=f.controller.campaignIndex}
end
local function terminal(index)
    local f=begin(index,1);prepareLastAttempt(f);finalContact(f)
    check(f.prefix..' terminal Session loss wins',f.session.state.status=='Lost' and f.controller.finished
        and f.controller.director.result=='Lost' and f.session.state.levelEpoch==1 and f.world.config.Level.campaignIndex==index)
    check(f.prefix..' lost owner remains eliminated',f.session.state.heroes[1].status=='Eliminated'
        and f.session.state.heroes[1].actorId==nil and f.session.state.heroes[1].respawns==0)
    result.cases[#result.cases+1]={case='actual exhausted native death remains Lost',stage=index,resources=snapshot(f),levelEpoch=f.session.state.levelEpoch}
end
local function lethalProjectile()
    local f=begin(8,1,true);local before=snapshot(f);local c=f.controller
    local heroPosition=f.world:position(1)
    check(f.prefix..' prepared claimed sentry contact',f.world:placeActor(-1,
        {x=heroPosition.x-1,y=heroPosition.y,z=heroPosition.z}))
    f.world:aim(-1,1,0)
    local role=f.director:controlled(7191)
    local shot={kind='Attack',attack='Punch',runId=f.session.state.runId,actorId=role.actorId,attempt=1,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=role.connectionEpoch,seq=1}
    check(f.prefix..' actual sentry accepted shot',f.director:command(7191,shot,f.now,Session.validIntent)=='OK')
    local effectAt=f.director.campaignEnemies.states[-1].attack.at
    f.now=effectAt-f.config.Attacks.HeroPowerPunch.windup
    local h=f.session.state.heroes[1]
    local attack={kind='Attack',attack='Punch',runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=1}
    check(f.prefix..' actual final attack accepted before sentry effect',f.session:intent(1,attack,f.now)=='OK')
    check(f.prefix..' prepared one-hit hero vulnerability',f.session:_event('SetHealth',1,{health=0})=='OK')
    f.session.combat[1].rawLife=0
    tick(f,effectAt-f.now+.001)
    local deadline=f.session.combat[1].deathAt
    check(f.prefix..' native projectile accepted lethal deadline after boss defeat',f.director.boss.defeated
        and deadline and deadline>f.now and f.session.state.heroes[1].status=='Alive'
        and f.session.combat[1].rawLife==0 and not c.finished and not f.director.closed and f.session.state.levelEpoch==1)
    local acceptedHit=false
    for _,row in ipairs(f.session.logs) do
        if row.kind=='Hit' and row.userId==1 and row.data.attacker==-1 and row.data.action=='DragonFire' and row.data.dying then acceptedHit=true end
    end
    check(f.prefix..' logged actual sentry projectile damage',acceptedHit)
    local remaining=0;for _ in pairs(f.director.campaignEnemies.projectiles) do remaining+=1 end
    -- TwinBolt creates two accepted shots. One delivers the lethal contact;
    -- the other keeps its ordinary lifetime while the stage waits for Session.
    check(f.prefix..' lethal contact consumes one twin without cancelling the other',remaining==1)
    local alive=f.world.actors[1]
    check(f.prefix..' dying native body remains live until deadline',alive.humanoid.Health>0
        and f.session.state.heroes[1].actorId==before[1].actorId and f.session.state.heroes[1].respawns==before[1].respawns)
    tick(f,deadline-f.now)
    check(f.prefix..' accepted deadline commits normal death',f.session.state.heroes[1].status=='AwaitingRespawn'
        and f.session.state.heroes[1].actorId==nil and f.session.state.heroes[1].respawns==before[1].respawns
        and not f.director.closed and f.session.state.levelEpoch==1)
    tick(f,DT)
    local paid=snapshot(f)
    check(f.prefix..' projectile loss buys actual one-stock retry before advance',paid[1].status=='Alive'
        and paid[1].attempt==before[1].attempt+1 and paid[1].respawns==before[1].respawns-1
        and paid[1].actorId~=before[1].actorId and f.session.state.levelEpoch==2 and c.campaignIndex==9 and f.director.closed)
    result.cases[#result.cases+1]={case='accepted native sentry projectile after due final hero strike',stage=8,
        before=before,deadline=deadline,paid=paid,acceptedProjectileHit=acceptedHit,
        remainingAcceptedShots=remaining,levelEpoch=f.session.state.levelEpoch}
end
local ok,err=xpcall(function()
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    lethalProjectile()
    for _,index in ipairs({8,13}) do pending(index,1);pending(index,2);terminal(index) end
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
return Http:JSONEncode(result)
