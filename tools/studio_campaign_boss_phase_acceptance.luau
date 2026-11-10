-- Studio Play-server acceptance: native Humanoid walking and prepared boss attacks.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer(),'Requires a Studio server context')
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
local result={sourceSha256=require(project.BuildInfo).sourceSha256,checks={},cases={},cleanup={},phaseMatrix={},movement={},
    fixture='Prepared seed41 stages5/8/10/11/13 x Human/NPC; real Session normal Punch input, CampaignDirector and native Models',
    limitations='Synthetic roster and owner; prepared gates and native poses, virtual fixed time, roots held for arithmetic and attack-path matrix, ordinary AI unstepped. No real Players, network, keyboard, touch, natural course clear or full physical boss-fight claim.'}
local created={};local DT=1/60;local ticks=0
local closeFixture
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

local function count(t) local n=0;for _ in pairs(t) do n+=1 end;return n end
local function begin(index,human)
    local d=definitions.build(index,41);local config=require(G.GameConfig)(require(R.Config),d)
    local worldName='BrickToadsBossPhaseQA_'..Http:GenerateGUID(false)
    ownedWorldNames[worldName]=true
    local f={definition=d,config=config,worldName=worldName,ownedFolders={},seq=0,heroSeq=0,models={},human=human,
        prefix='stage '..index..' '..(human and 'Human' or 'NPC'),offsetSeconds=3.1,now=workspace:GetServerTimeNow(),
        acceptedPunches=0,landedPunches=0,actionCounts={},phases={},visited={}}
    created[#created+1]=f
    local folders={};for _,item in ipairs(workspace:GetChildren()) do folders[item]=true end
    local ok,world=xpcall(function()
        return World.new(require(R.RobloxWorld),config,{name=worldName,offset={x=0,y=32,z=16384},
            characterAppearance=require(G.CharacterAppearance),guardianAppearance=require(G.GuardianAppearance),
            campaignWorld=require(G.CampaignWorld)})
    end,debug.traceback)
    for _,item in ipairs(workspace:GetChildren()) do
        if not originalFolders[item] and not folders[item] and item:IsA('Folder')
            and (item.Name==worldName or item.Name=='CombatStandWorld') then f.ownedFolders[item]=true end
    end
    if not ok then error(world,0) end
    f.world=world;f.ownedFolders[world.folder]=true
    f.session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'}},
        'native-boss-phase-'..Http:GenerateGUID(false),world,function(row)
            if row.kind=='AttackAccepted' and row.userId==1 then f.acceptedPunches+=1 end
            if row.kind=='CampaignBossHit' and row.data.attacker==1 then
                f.landedPunches+=1;local action=row.data.action
                f.actionCounts[action]=(f.actionCounts[action] or 0)+1
            end
        end,{groupId='native-boss-phase-fixture',levelId=d.id})
    check(f.prefix..' initial spawn',f.session:step(f.now)=='OK')
    f.now=workspace:GetServerTimeNow()+f.offsetSeconds
    check(f.prefix..' ordinary spawn shield expires',f.session:step(f.now)=='OK' and not f.session.state.heroes[1].shield)
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    local originalHit=f.session._hit
    f.session._hit=function(session,attacker,target,action,tuning)
        if target<0 then return f.director:hit(attacker,target,action,tuning) end
        return originalHit(session,attacker,target,action,tuning)
    end
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.director.ownerNames[OWNER]='Synthetic phase acceptance owner'
    f.director.bossGate=function() return human and {state='Human',userId=OWNER} or {state='NPC'} end
    for id,e in pairs(f.director.ordinary.enemies) do if not e.dead then f.director.ordinary:_kill(id,'AcceptancePreparedClear') end end
    f.director.modes.complete=true
    for _,actor in pairs(f.director.modes.actors) do actor.finished=true end
    world:campaignRelease(1)
    check(f.prefix..' prepared boss gate',f.director:_startBoss(f.now,index==11))
    f.boss=f.director.boss;track(f)
    local e=f.boss.enemies[-99]
    f.identity={actorId=e.actorId,model=world.actors[-99].model,heroActorId=f.session.state.heroes[1].actorId,
        heroModel=world.actors[1].model,attempt=f.session.state.heroes[1].attempt,respawns=f.session.state.heroes[1].respawns}
    if index==11 then
        check(f.prefix..' Chase rejects incoming hit',f.boss.state=='Chase' and not f.boss:hit(1,-99,'HeroUppercut'))
        local raw,actor=e.rawLife,e.actorId
        check(f.prefix..' Chase same-body battle handoff',f.boss:finishChase()=='OK' and e.rawLife==raw and raw==207 and e.actorId==actor)
    end
    check(f.prefix..' initial human NPC ownership',human and f.boss:controlled(OWNER)~=nil or not human and f.boss:controlled(OWNER)==nil)
    return f
end
local function command(f,kind,fields,epoch)
    local role=f.boss:controlled(OWNER);assert(role,'Human control fixture required');f.seq+=1
    local p={kind=kind,runId=f.session.state.runId,actorId=role.actorId,attempt=role.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=epoch or role.connectionEpoch,seq=f.seq}
    for key,value in pairs(fields or {}) do p[key]=value end
    return f.director:command(OWNER,p,f.now,Session.validIntent)
end
local function slice(f,to)
    assert(to>=f.now,'Fixture time reversed');local dt=to-f.now;f.now=to;f.director.now=to;f.director.ordinary.now=to
    assert(f.session:step(to)=='OK',f.prefix..' Session slice rejected')
    assert(f.boss:step(to,dt)=='OK',f.prefix..' boss slice rejected')
    ticks+=1
    if ticks%240==0 then task.wait() end
end
local function advance(f,to)
    while f.now<to-1e-8 do slice(f,math.min(to,f.now+DT)) end
end
local function stance(f,near)
    local origin=f.definition.boss.position
    assert(f.world:placeActor(-99,origin),'Boss native pose missing')
    local p={x=origin.x-3,y=origin.y+(near and 0 or 100),z=origin.z}
    assert(f.world:placeActor(1,p),'Hero native pose missing')
    f.world:hold(1,true);f.world:hold(-99,true)
    f.world:aim(1,1,0)
end
local function ready(f)
    stance(f,false)
    if f.boss.state=='Reaction' then advance(f,f.boss.reactionUntil+.0001) end
    if f.boss.attack then advance(f,f.boss.attack.recoveryUntil+.0001) end
    if count(f.boss.projectiles)>0 then advance(f,f.now+3) end
    assert(f.boss.state=='Ready',f.prefix..' failed finite Ready recovery')
end
local function phaseKey(f)
    local e=f.boss.enemies[-99]
    if e.progress~=nil then
        if e.progress==0 then return 'progress0' end
        if e.progress==108 or e.progress==120 or e.progress==228 or e.progress==240 then return 'progress'..e.progress end
        return nil
    end
    return 'phase'..f.boss:_phase()
end
local function attacksAtPhase(f,key)
    ready(f);local e=f.boss.enemies[-99];local phase=f.boss:_phase()
    local phaseRow={boss=f.boss.kind,controller=f.human and 'Human' or 'NPC',key=key,phase=phase,rawLife=e.rawLife,progress=e.progress,
        actorId=e.actorId,acceptedHeroPunches=f.acceptedPunches,attacks={}}
    for attempt=1,2 do
        stance(f,false)
        local origin=f.definition.boss.position
        -- A fresh ordinary native body receives real production collision damage.
        -- Hero resources stay isolated while the enemy-to-enemy path is exercised.
        f.colliderSerial=(f.colliderSerial or 0)+1
        local collider=-700-f.colliderSerial
        local expected=f.boss:_chooseAttack('Punch')
        local offset=expected=='Burst' and {x=20,z=0} or expected=='Spin' and {x=8,z=4}
            or (expected=='Sweep' or expected=='Headbutt') and {x=5,z=0} or {x=12,z=0}
        track(f)
        f.director.ordinary:_wave('AcceptanceCollider',{{id=collider,kind='Pig',rawLife=31,
            x=origin.x+offset.x,y=origin.y,z=origin.z+offset.z}})
        local target=f.director.ordinary.enemies[collider]
        f.director.enemies[collider]=target;track(f);f.world:hold(collider,true)
        if f.human then
            assert(command(f,'Move',{x=1,z=0})=='OK');assert(command(f,'Attack',{attack='Punch'})=='OK')
        else
            advance(f,math.max(f.now,f.boss.readyAt)+.0001)
        end
        local a=f.boss.attack;assert(a and f.boss.state=='Tell','Boss must accept ordinary Punch decision')
        local name=a.name;stance(f,false)
        check(f.prefix..' '..key..' '..name..' Tell armor',not f.boss:hit(1,-99,'HeroJab') and not f.boss:snapshot().bossVulnerable)
        advance(f,a.tellAt+.0001)
        check(f.prefix..' '..key..' '..name..' Active armor',f.boss.state=='Active' and not f.boss:snapshot().bossVulnerable)
        local maxBolts=count(f.boss.projectiles);local maxY=f.world:position(-99).y
        while f.now<a.activeUntil-1e-8 do
            slice(f,math.min(a.activeUntil,f.now+DT));maxBolts=math.max(maxBolts,count(f.boss.projectiles));maxY=math.max(maxY,f.world:position(-99).y)
        end
        check(f.prefix..' '..key..' '..name..' Recovery vulnerable',f.boss.state=='Recovery' and f.boss:snapshot().bossVulnerable)
        local endpoint=f.world:position(-99)
        if name=='Burst' then check(f.prefix..' '..key..' Burst emits three native bolts',a.shots==3 and maxBolts==3) end
        if name=='Hop' or name=='BellyDrop' or name=='Jump' or name=='Bounce' then
            check(f.prefix..' '..key..' '..name..' native lift and landing',maxY>origin.y+3 and math.abs(endpoint.y-origin.y)<.01)
        end
        local raw,progress=e.rawLife,e.progress
        advance(f,a.recoveryUntil+.0001)
        check(f.prefix..' '..key..' '..name..' finite Ready',f.boss.state=='Ready' and e.rawLife==raw and e.progress==progress)
        if count(f.boss.projectiles)>0 then advance(f,f.now+3) end
        check(f.prefix..' '..key..' '..name..' native body collision damages ordinary Life',target.dead or target.rawLife<31)
        phaseRow.attacks[#phaseRow.attacks+1]={name=name,serial=a.serial,tell=a.move.tell,active=a.move.active,recovery=a.move.recovery,
            maxNativeY=maxY,endpoint=endpoint,shots=a.shots,maxProjectiles=maxBolts,
            ordinaryTarget={actorId=target.actorId,before=31,after=target.rawLife,dead=target.dead}}
        if not target.dead then f.director.ordinary:_kill(collider,'AcceptanceColliderClosed') end
    end
    local names={};for _,row in ipairs(phaseRow.attacks) do names[row.name]=true end
    local first=f.boss.profile.first;local second=f.boss.profile.second
    if f.boss.kind=='BigBlag' and phase==1 then
        check(f.prefix..' '..key..' ordinary Punch retains phase1 Hop',names.Hop and not names.BellyDrop)
    else check(f.prefix..' '..key..' both ordinary Punch moves',names[first] and names[second]) end
    result.phaseMatrix[#result.phaseMatrix+1]=phaseRow;f.visited[key]=true
end
local function normalPunch(f)
    if f.now<f.session.combat[1].nextAttack then advance(f,f.session.combat[1].nextAttack) end
    stance(f,true);local h=f.session.state.heroes[1];f.heroSeq+=1
    local before=f.landedPunches
    local code=f.session:intent(1,{kind='Attack',attack='Punch',runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=f.heroSeq},f.now)
    assert(code=='OK',f.prefix..' rejected normal hero Punch: '..code)
    local a=f.session.combat[1].attack;assert(a,'Accepted normal Punch must schedule source action')
    f.world:hold(1,true)
    -- Session resolves the scheduled hit before the director decision, matching
    -- Controller ordering in a coarse valid frame inside this attack window.
    slice(f,a.at+.0001)
    assert(f.landedPunches==before+1,f.prefix..' accepted normal Punch must hit this native boss')
end
local function run(index,human)
    local f=begin(index,human)

    stance(f,false)
    local guard=0
    while not f.boss.defeated do
        local key=phaseKey(f)
        if key and not f.visited[key] then attacksAtPhase(f,key) end
        normalPunch(f);guard+=1;assert(guard<=600,'Normal source Punch progression failed to terminate')
    end
    local e=f.boss.enemies[-99];local h=f.session.state.heroes[1]
    check(f.prefix..' defeat requires accepted normal hero attacks',f.acceptedPunches==f.landedPunches and f.acceptedPunches>0 and e.dead and e.rawLife==0)
    check(f.prefix..' same boss and hero identities',e.actorId==f.identity.actorId and f.world.actors[-99].model==f.identity.model
        and h.actorId==f.identity.heroActorId and f.world.actors[1].model==f.identity.heroModel
        and h.attempt==f.identity.attempt and h.respawns==f.identity.respawns and f.session.combat[1].rawLife==47)
    if e.progress~=nil then
        check(f.prefix..' progress F0 is nonterminal until next underflow',f.visited.progress240 and e.progress==240
            and f.visited.progress0 and f.visited.progress108 and f.visited.progress120 and f.visited.progress228)
    elseif f.boss.kind=='BigBlag' then check(f.prefix..' all BigBlag Life phases',f.visited.phase1 and f.visited.phase2 and f.visited.phase3)
    else check(f.prefix..' both Buzzball Life phases',f.visited.phase1 and f.visited.phase2) end
    result.cases[#result.cases+1]={stage=index,boss=f.boss.kind,controller=human and 'Human' or 'NPC',acceptedHeroPunches=f.acceptedPunches,
        landedHeroPunches=f.landedPunches,sourceActionCounts=f.actionCounts,rawLife=e.rawLife,progress=e.progress,
        state=f.boss.state,actorId=e.actorId,heroRespawns=h.respawns,heroRawLife=f.session.combat[1].rawLife}
    closeFixture(f)
end

closeFixture=function(f)
    if f.cleaned then return end
    f.cleaned=true
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


local ok,err=xpcall(function()
    for _,row in ipairs(defaults) do row.original.Parent=nil end
    for _,index in ipairs({5,8,10,11,13}) do run(index,true);run(index,false) end
    result.status='PASS'
end,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
for _,f in ipairs(created) do closeFixture(f) end
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
if result.cleanupFailed then result.status='FAIL' end
_G.BrickToadsCampaignBossPhaseAcceptance=result
return Http:JSONEncode(result)
