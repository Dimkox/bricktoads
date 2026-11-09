-- Prepared engine acceptance only. Never included in the production source tree.
-- Calls real Session/Director/World; controlled time/roster selection is explicit.
local F={}
local S=game:GetService('ServerScriptService').BrickToads
local G=S.gameplay
local R=S.CombatRuntime
local definitions=require(G.CampaignDefinition)
local deps={CampaignDefinition=definitions,CampaignModes=require(G.CampaignModes),CampaignBoss=require(G.CampaignBoss),
    CampaignEnemies=require(G.CampaignEnemies),Director=require(G.LevelDirector),GuardianPattern=require(G.GuardianPattern),
    HealingFlies=require(G.HealingFlies),EnemyCarry=require(G.EnemyCarry),WalkerClubs=require(G.WalkerClubs),
    DragonFlight=require(G.DragonFlight),BossIntro=require(G.BossIntro)}
local World=require(G.GameWorld)
require(G.DragonWorld)(World)
local function v(p) return {x=p.X,y=p.Y,z=p.Z} end
local function live(slot)
    local h=F.session.state.heroes[slot]
    return h and h.status=='Alive' and not F.session.combat[slot].deathAt
end
function F.close()
    if F.director then F.director:close('AcceptanceClosed');F.director=nil end
    if F.world then F.world:clearActors();F.world.folder:Destroy();F.world=nil end
end
function F.begin(index,count,seed)
    F.close()
    local definition=definitions.build(index,seed or 11939)
    local config=require(G.GameConfig)(require(R.Config),definition)
    local world=World.new(require(R.RobloxWorld),config,{name='BrickToadsCampaignAcceptance',offset={x=0,y=0,z=4096},
        characterAppearance=require(G.CharacterAppearance),guardianAppearance=require(G.GuardianAppearance),
        campaignWorld=require(G.CampaignWorld)})
    local roster={}
    for slot=1,(count or 1) do roster[slot]={userId=slot,template=slot==2 and 'Mr. Yellow' or 'Mr. Green'} end
    local session=require(R.Session).new(require(S.RunLifecycle),require(R.Combat),config,roster,
        'campaign-native-'..index,world,nil,{groupId='native-campaign',levelId=definition.id})
    F.world=world;F.session=session;F.config=config;F.definition=definition;F.now=workspace:GetServerTimeNow();F.seq={}
    session:step(F.now)
    local director=require(G.CampaignDirector).new(session,world,require(R.Combat),config,deps)
    F.director=director
    require(G.SourceCombat).bind(session,director,config)
    session.contextualAttack=function(slot,now,action) return director:interact(slot,now,action) end
    local originalHit=session._hit
    session._hit=function(self,attacker,target,action,tuning)
        if target<0 then return director:hit(attacker,target,action,tuning) end
        return originalHit(self,attacker,target,action,tuning)
    end
    return F.status()
end
function F.input(slot,kind,fields)
    F.seq[slot]=(F.seq[slot] or 0)+1
    local hero=F.session.state.heroes[slot]
    local packet={kind=kind,runId=F.session.state.runId,actorId=hero.actorId,attempt=hero.attempt,
        levelEpoch=F.session.state.levelEpoch,connectionEpoch=hero.connectionEpoch,seq=F.seq[slot]}
    for key,value in pairs(fields or {}) do packet[key]=value end
    return F.session:intent(slot,packet,F.now)
end
function F.tick(seconds,inputs)
    local steps=math.ceil((seconds or .1)*60)
    for n=1,steps do
        F.now+=1/60
        if n%6==1 then
            for slot,m in pairs(inputs or {}) do if live(slot) then F.input(slot,'Move',{x=m.x,z=m.z,run=m.run==true}) end end
        end
        F.session:step(F.now);F.director:step(F.now,1/60)
        F.world:updatePresentation(F.session,1/60,F.director.enemies)
        if n%12==0 then task.wait() end
    end
    return F.status()
end
function F.realtime(seconds,inputs)
    local deadline=workspace:GetServerTimeNow()+seconds
    local lastInput=-math.huge
    repeat
        local now=workspace:GetServerTimeNow();local dt=math.max(0,now-F.now);F.now=now
        if now-lastInput>=.1 then
            for slot,m in pairs(inputs or {}) do if live(slot) then F.input(slot,'Move',{x=m.x,z=m.z,run=m.run==true}) end end
            lastInput=now
        end
        F.session:step(now);F.director:step(now,dt);F.world:updatePresentation(F.session,dt,F.director.enemies)
        task.wait(1/60)
    until workspace:GetServerTimeNow()>=deadline
    return F.status()
end
function F.roleProbe()
    F.begin(4,1,11939)
    assert(F.director:claim(999,-1)=='OK')
    local role=F.director:controlled(999)
    local actor=F.world.actors[-1]
    local result=F.director:command(999,{kind='Move',runId=F.session.state.runId,actorId=role.actorId,
        attempt=1,levelEpoch=1,connectionEpoch=role.connectionEpoch,seq=1,x=1,z=0},F.now,require(R.Session).validIntent)
    assert(result=='OK',result)
    local moving=actor.humanoid.WalkSpeed
    local cached=actor.locomotion and actor.locomotion.walkSpeed
    F.world:setReaction(-1,true);F.world:setReaction(-1,false)
    assert(moving==4 and actor.humanoid.WalkSpeed==4 and cached==4)
    return {claimedBeforeFirstStep=true,kind=F.director.enemies[-1].kind,move=result,speed=moving,
        recoverySpeed=actor.humanoid.WalkSpeed,cachedBeforeReaction=cached,
        sameBody=actor==F.world.actors[-1],owner=tostring(actor.root:GetNetworkOwner())}
end
function F.bossProbe(index)
    F.begin(index,1,11939)
    F.director.modes:close('PreparedBossArena')
    local p=F.definition.boss.position
    F.world:placeActor(1,{x=p.x-25,y=p.y,z=p.z+24})
    F.director.bossGate=function() return {state='Human',userId=999} end
    F.director.ownerConnections[999]=true
    assert(F.director:_startBoss(F.now,false))
    local boss=F.director.boss
    local before=boss:snapshot()
    local body=F.world.actors[-99]
    local action=boss:command('Punch',{x=-1,z=0},F.now)
    assert(action=='OK',action)
    local accepted=boss:snapshot()
    F.tick(3,{[1]={x=0,z=0}})
    local after=boss:snapshot()
    assert(after.bossState=='Ready' and body==F.world.actors[-99])
    return {index=index,before=before,accepted=accepted,after=after,
        bodyKind=body.model:GetAttribute('BossKind'),position=F.world:position(-99),
        sameBody=body==F.world.actors[-99],owner=tostring(body.root:GetNetworkOwner()),hero=F.session:snapshot().heroes[1]}
end
function F.castProbe()
    F.begin(4,1,11939)
    local clear=F.world:campaignProjectileBlocked({x=0,y=3,z=0},{x=20,y=3,z=0})
    local wall=Instance.new('Part');wall.Name='AcceptanceCastWall';wall.Size=Vector3.new(.2,6,12)
    wall.CFrame=CFrame.new(10,3,4096);wall.Anchored=true;wall.Parent=F.world.geometry
    local blocked=F.world:campaignProjectileBlocked({x=0,y=3,z=0},{x=20,y=3,z=0})
    local startingInside=F.world:campaignProjectileBlocked({x=10,y=3,z=0},{x=20,y=3,z=0})
    wall:Destroy()
    assert(not clear and blocked and startingInside,'Native cast must stop at thin geometry and initial overlaps')
    return {clear=clear,blocked=blocked,startingInside=startingInside}
end
function F.transitionProbe()
    F.begin(4,3,11939)
    local ids={};for _,slot in ipairs(F.session.order) do ids[slot]=F.session.state.heroes[slot].actorId end
    F.session.combat[1].rawLife=37
    F.session:_event('SetHealth',1,{health=require(R.Combat).hearts(37)})
    F.session:connection(2,false,F.now)
    for _=1,4 do
        F.session:_die(3,'PreparedAcceptanceDeath');F.now+=.6
        F.session:step(F.now);F.director:step(F.now,0)
    end
    local before=F.session:snapshot()
    F.director:close('LevelAdvanced')
    local nextDefinition=definitions.build(5,11939)
    assert(F.world:advanceGeometry(nextDefinition))
    local code=F.session:advanceLevel(nextDefinition.id,F.now,{prerequisitesMet=true})
    assert(code=='OK',code)
    local after=F.session:snapshot()
    assert(after.levelEpoch==2 and after.runId==before.runId)
    assert(after.heroes[1].rawLife==47 and after.heroes[1].actorId==ids[1] and after.heroes[1].respawns==3)
    assert(after.heroes[2].rawLife==47 and after.heroes[2].actorId==ids[2] and not after.heroes[2].connected)
    assert(after.heroes[3].status=='Eliminated' and after.heroes[3].respawns==0)
    local stale=F.session:intent(1,{kind='Move',runId=after.runId,actorId=ids[1],attempt=1,levelEpoch=1,
        connectionEpoch=after.heroes[1].connectionEpoch,seq=1,x=1,z=0},F.now)
    assert(stale=='STALE_ACTOR',stale)
    local positions={};for _,slot in ipairs({1,2}) do
        positions[slot]={position=F.world:position(slot),anchored=F.world.actors[slot].root.Anchored,
            owner=tostring(F.world.actors[slot].root:GetNetworkOwner())}
    end
    return {before=before,after=after,positions=positions,oldEpoch=stale}
end
function F.status()
    local actors={}
    for _,slot in ipairs(F.session.order) do
        local hero=F.session.state.heroes[slot]
        local actor=F.world.actors[slot]
        actors[#actors+1]={slot=slot,status=hero.status,actorId=hero.actorId,attempt=hero.attempt,respawns=hero.respawns,
            health=hero.health,rawLife=F.session.combat[slot].rawLife,position=F.world:position(slot),
            anchored=actor and actor.root.Anchored,assembly=actor and actor.root.AssemblyRootPart==actor.root,
            networkOwner=actor and not actor.root.Anchored and tostring(actor.root:GetNetworkOwner()) or 'anchored',
            movement=F.world:movementMode(slot)}
    end
    return {mode=F.definition.mode,index=F.definition.campaignIndex,stage=F.director.stage,
        levelEpoch=F.session.state.levelEpoch,state=F.session.state.status,
        source=require(S.BuildInfo).sourceSha256,actors=actors,modeState=F.director.modes:snapshot(),
        supportCount=#F.world.allFloors,geometryCount=#F.world.geometry:GetDescendants()}
end
function F.finalVictoryProbe()
    F.begin(13,1,11939)
    F.director.bossGate=function() return {state='Human',userId=999} end
    F.director.ownerConnections[999]=true
    F.world:placeActor(1,F.definition.course.finishPoint);F.tick(.05)
    assert(F.director.boss,'Final entrance must create the real boss')
    local boss=F.director.boss;local body=F.world.actors[-99]
    local before=F.status();local statuses={};local accepted=0
    for i=1,600 do
        local p=F.world:position(-99)
        -- Explicit prepared stance, never a gameplay navigator or Life write.
        F.world:placeActor(1,{x=p.x-4,y=p.y,z=p.z});F.world:aim(1,1,0)
        F.now+=.1
        local code=F.input(1,'Attack',{attack='Punch'})
        statuses[code]=(statuses[code] or 0)+1;if code=='OK' then accepted+=1 end
        F.session:step(F.now);F.director:step(F.now,.1)
        F.world:updatePresentation(F.session,.1,F.director.enemies)
        if i%6==0 then task.wait() end
        if F.director.result then break end
    end
    assert(F.director.result=='Won' and boss.defeated)
    assert(boss:snapshot().bossProgress==240 and body==F.world.actors[-99])
    assert(F.session.state.heroes[1].respawns==3 and F.session.combat[1].rawLife==47)
    return {source=before.source,prepared=true,
        preparation='Entrance and stance positions only; real validated attacks; no Life/progress/death writes',
        before=before,after=F.status(),boss=boss:snapshot(),result=F.director.result,
        sameBossBody=body==F.world.actors[-99],accepted=accepted,statuses=statuses}
end
function F.vehicleProbe()
    F.begin(3,2,11939)
    -- Isolate the actual transport/hazard boundary from the entry foot fight.
    for id in pairs(F.director.ordinary.enemies) do F.director.ordinary:_kill(id,'PreparedCourseEntry') end
    local bodies={F.world.actors[1],F.world.actors[2]}
    for slot=1,2 do
        F.world:placeActor(slot,F.definition.course.mount)
        assert(F.input(slot,'Attack',{attack='Punch'})=='OK')
        assert(F.director.modes.actors[slot].mounted)
    end
    local before=F.status();local modes=F.director.modes
    local hazard=F.definition.course.hazards[1]
    modes.actors[1].position={x=hazard.x-2,y=hazard.y,z=hazard.z}
    F.tick(1/60);local stopped=F.status()
    assert(modes.vehicleGroup.phase=='Stopped')
    F.tick(1.3,{[1]={x=.1,z=0},[2]={x=.1,z=0}})
    local after=F.status()
    assert(modes.vehicleGroup.phase=='Riding' and modes.vehicleGroup.serial==1)
    assert(F.session.state.heroes[1].attempt==2 and F.session.state.heroes[1].respawns==2)
    assert(F.session.state.heroes[2].actorId==before.actors[2].actorId)
    assert(F.session.state.heroes[2].attempt==1 and F.session.state.heroes[2].respawns==3)
    assert(F.session.combat[2].rawLife==47 and bodies[2]==F.world.actors[2])
    return {source=before.source,prepared=true,
        preparation='Entry actors removed; boarding uses real validated Punch; first rider positioned at an existing course hazard',
        before=before,stopped=stopped,after=after,survivorSameBody=bodies[2]==F.world.actors[2],
        collidedBodyReplaced=bodies[1]~=F.world.actors[1]}
end
return F
