-- README / run instructions:
-- Studio server only; install this file as a NEW Script while the existing game keeps running.
-- Requires ServerScriptService.BrickToads with the exact BuildInfo receipt below.
-- Poll ServerStorage.DragonTransportAcceptance_<guid> attributes Status and its Result StringValue.
-- Set Script attribute FixtureSourceSha256 to the externally computed SHA256 of this file if available.
-- This prepared fixture owns one world at Z8192, logical hero1 and two separately claimed enemies.
-- It does not control Players, the main hub, live characters, Play state or the normal run.
-- Prepared positions, a direct surviving Dragon heavy hit and a direct hero heavy hit are disclosed.
-- Capture preparation samples one actual physics Heartbeat before resetting the knocked hero's position/velocity.
-- Capture uses beginCapture plus its real delayed geometry; mount/fire/steer/dismount use public Session intents.
-- It never calls dragonLink directly, replaces hit geometry, seeds raw Life or manufactures a pass.
-- Maximum14 seconds of Heartbeats; cleanup destroys only this fixture's world. Studio NOT RUN by author.
local RunService=game:GetService('RunService')
if not RunService:IsStudio() or not RunService:IsServer() then return end
local HttpService=game:GetService('HttpService')
local ServerStorage=game:GetService('ServerStorage')
local EXPECTED_SOURCE='111e5acea788db6c93dc5dc011c291ea974604ca4fe60c08b69f3bf733ea5eac'
local offset=Vector3.new(0,0,8192)
local folder=Instance.new('Folder');folder.Name='DragonTransportAcceptance_'..HttpService:GenerateGUID(false);folder.Parent=ServerStorage
local output=Instance.new('StringValue');output.Name='Result';output.Parent=folder
folder:SetAttribute('Status','running')
local result={schema=1,status='running',scenario='isolated_same_body_dragon_transport',checks={},intents={},
    sourceSha256=EXPECTED_SOURCE,fixtureSourceSha256=script:GetAttribute('FixtureSourceSha256'),
    placeId=game.PlaceId,placeVersion=game.PlaceVersion,studioVersion=version(),
    preparation={isolatedWorld=true,offsetZ=8192,dragonId=-10,dragonInitialRawLife=47,pigId=-11,pigInitialRawLife=31,
        realUnanchoredBodies=true,directDragonHeavyHit=true,directHeroHeavyHit=true,
        preparedPositionChanges=true,captureImpulseSampleBeforeReposition=true,
        captureUsesRealDelayedGeometry=true,publicMountMoveFireJump=true},
    limits={'Prepared engine fixture, not natural progression','No real player/network/device acceptance',
        'Receipt assumes production ModuleScript sources match their embedded BuildInfo'}}
local started=workspace:GetServerTimeNow()
local world,session,director,hero,dragon,pig
local function check(name,condition,observed)
    result.checks[#result.checks+1]={name=name,passed=condition==true,observed=observed}
    assert(condition,name)
end
local function vec(v) return {x=v.X,y=v.Y,z=v.Z} end
local function state()
    if not session then return {} end
    local h,c=session.state.heroes[1],session.combat[1]
    local e=director and director.enemies[-10]
    local row=director and director.dragons and director.dragons.states[-10]
    return {now=session.now,actorId=h.actorId,attempt=h.attempt,respawns=h.respawns,rawLife=c.rawLife,
        heroPosition=vec(hero.root.Position-offset),heroVelocity=vec(hero.root.AssemblyLinearVelocity),
        heroMove=vec(hero.humanoid.MoveDirection),heroAnchored=hero.root.Anchored,
        heroESM=hero.humanoid.EvaluateStateMachine,heroPlatformStand=hero.humanoid.PlatformStand,
        heroState=hero.humanoid:GetState().Name,heroLink=hero.model:GetAttribute('DragonLink'),
        dragonPosition=dragon and vec(dragon.root.Position-offset),dragonVelocity=dragon and vec(dragon.root.AssemblyLinearVelocity),
        dragonAnchored=dragon and dragon.root.Anchored,dragonRawLife=e and e.rawLife,
        dragonState=dragon and dragon.humanoid:GetState().Name,dragonESM=dragon and dragon.humanoid.EvaluateStateMachine,
        dragonPlatformStand=dragon and dragon.humanoid.PlatformStand,dragonUp=dragon and vec(dragon.root.CFrame.UpVector),
        dragonFloor=dragon and world:dragonFloor(-10),dragonGrounded=dragon and world:dragonGrounded(-10),
        dragonActorId=e and e.actorId,dragonMode=row and row.mode}
end
local function frame()
    local dt=RunService.Heartbeat:Wait()
    local now=workspace:GetServerTimeNow()-started
    assert(now<14,'Fixture exceeded its14-second deadline')
    director.now=now
    assert(session:step(now)=='OK','Fixture Session stopped')
    director:step(now,dt);world:updatePresentation(session,dt,director.enemies)
    result.lastFrame=state()
end
local function waitFor(seconds,predicate,name)
    local deadline=workspace:GetServerTimeNow()+seconds
    while not predicate() do
        assert(workspace:GetServerTimeNow()<deadline,name)
        frame()
    end
end
local function advance(seconds)
    local untilTime=session.now+seconds
    waitFor(seconds+.3,function() return session.now>=untilTime end,'Timed observation did not advance')
end
local seq=0
local function intent(kind,x,z)
    seq+=1
    local h=session.state.heroes[1]
    local p={kind=kind,runId=session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
    if kind=='Move' then p.x=x;p.z=z elseif kind=='Attack' then p.attack='Punch' end
    local code=session:intent(1,p,session.now)
    result.intents[#result.intents+1]={now=session.now,kind=kind,x=x,z=z,code=code,
        selectedAction=session.combat[1].attack and session.combat[1].attack.action}
    return code
end
local function preparePosition(actor,p,direction)
    local at=Vector3.new(p.x,p.y,p.z)+offset
    actor.model:PivotTo(CFrame.lookAt(at,at+Vector3.new(direction or 1,0,0)))
    actor.root.AssemblyLinearVelocity=Vector3.zero;actor.root.AssemblyAngularVelocity=Vector3.zero
end
local function latest(kind,action)
    for i=#session.logs,1,-1 do
        local row=session.logs[i]
        if row.kind==kind and row.data and row.data.action==action then return row end
    end
end
local function grounded(actor)
    return actor.humanoid.FloorMaterial~=Enum.Material.Air and not actor.root.Anchored
        and not actor.humanoid.PlatformStand and math.abs(actor.root.AssemblyLinearVelocity.Y)<2
        and world:dragonGrounded(1)
end
local ok,err=xpcall(function()
    local project=game:GetService('ServerScriptService'):WaitForChild('BrickToads',1)
    check('production source receipt matches',require(project.BuildInfo).sourceSha256==EXPECTED_SOURCE)
    local runtime,gameplay=project.CombatRuntime,project.gameplay
    local Core,Combat,Session=require(project.RunLifecycle),require(runtime.Combat),require(runtime.Session)
    local level=require(gameplay.LevelDefinition)
    local fixtureLevel=table.clone(level);local zone=table.clone(level.zones[1])
    local dragonRecord=table.clone(level.zones[4].enemies[2]);dragonRecord.x=-40;dragonRecord.y=3;dragonRecord.z=0
    local pigRecord=table.clone(level.zones[5].enemies[1]);pigRecord.x=-12;pigRecord.y=3;pigRecord.z=0
    zone.enemies={dragonRecord,pigRecord};fixtureLevel.zones={zone}
    check('prepared actors retain their actual source profiles',dragonRecord.id==-10 and dragonRecord.rawLife==47
        and pigRecord.id==-11 and pigRecord.rawLife==31)
    local config=require(gameplay.GameConfig)(require(runtime.Config),fixtureLevel)
    local World=require(gameplay.GameWorld);require(gameplay.DragonWorld)(World)
    -- The real constructor writes shared lighting synchronously. Restore it before yielding.
    -- Refuse to let its blank-place migration remove user geometry.
    for _,name in ipairs({'Baseplate','SpawnLocation'}) do
        check('no shared blank-place migration: '..name,workspace:FindFirstChild(name)==nil)
    end
    local lighting=game:GetService('Lighting');local savedLighting={}
    for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do savedLighting[key]=lighting[key] end
    local atmosphere=lighting:FindFirstChild('CausewayAtmosphere');local savedAtmosphere={}
    if atmosphere then for _,key in ipairs({'Density','Offset','Color','Decay','Glare','Haze'}) do savedAtmosphere[key]=atmosphere[key] end end
    local made,created=pcall(World.new,require(runtime.RobloxWorld),config,{name=folder.Name,offset={x=0,y=0,z=8192}})
    for key,value in pairs(savedLighting) do lighting[key]=value end
    if atmosphere then for key,value in pairs(savedAtmosphere) do atmosphere[key]=value end
    else local created=lighting:FindFirstChild('CausewayAtmosphere');if created then created:Destroy() end end
    assert(made,created);world=created
    session=Session.new(Core,Combat,config,{{userId=1,template='Mr. Green'}},folder.Name,world)
    check('isolated hero spawn commits',session:step(0)=='OK' and session.state.heroes[1].status=='Alive')
    hero=world.actors[1];preparePosition(hero,{x=-45,y=3,z=0})
    director=require(gameplay.LevelDirector).new(session,world,Combat,config,nil,nil,nil,nil,require(gameplay.DragonFlight))
    require(gameplay.SourceCombat).bind(session,director,config)
    session.contextualAttack=function(slot,now,action) return director:interact(slot,now,action) end
    local hit=session._hit
    session._hit=function(self,a,t,action,tuning) if t<0 then return director:hit(a,t,action,tuning) end;return hit(self,a,t,action,tuning) end
    dragon,pig=world.actors[-10],world.actors[-11]
    check('fixture claims preserve two separate actors',director:claim(98700010,-10)=='OK' and director:claim(98700011,-11)=='OK')
    local heroId,dragonId=session.state.heroes[1].actorId,director.enemies[-10].actorId
    advance(.2)
    local force=world.dragonFlights[-10] and world.dragonFlights[-10].force
    check('real unanchored Dragon rises under an actual lift force',force and force.Parent==dragon.root
        and force.Force.Y>0 and dragon.model:GetAttribute('DragonFlight')==true and not dragon.root.Anchored
        and not hero.root.Anchored and dragon.root.Position.Y>3.1,state())
    check('prepared surviving heavy hit disables this same flying body',director:hit(1,-10,'HeroUppercut')
        and director.enemies[-10].rawLife==31 and director.dragons.states[-10].mode=='Disabled')
    -- One near-zero velocity sample can be the lying body's last frame before
    -- the Humanoid's automatic get-up impulse. Wait for upright resting height.
    local stableFrames,stableSince,lastStableSample=0,nil,nil
    waitFor(3,function()
        if lastStableSample==session.now then return false end
        lastStableSample=session.now
        local floor=world:dragonFloor(-10)
        local stable=not director.enemies[-10].reactionUntil and world:dragonGrounded(-10)
            and floor and math.abs(world:position(-10).y-floor)<.35
            and not dragon.humanoid.PlatformStand and dragon.humanoid.EvaluateStateMachine
            and dragon.root.CFrame.UpVector.Y>.95
        if stable then stableFrames+=1;stableSince=stableSince or session.now
        else stableFrames=0;stableSince=nil end
        return stableFrames>=3 and session.now-stableSince>=.08
    end,'Disabled Dragon did not reach stable upright ground')
    result.stableDisabled=state()
    check('heavy interruption removes lift before mounting',force.Parent==nil and world.dragonFlights[-10]==nil,state())
    local p=world:position(-10);preparePosition(hero,{x=p.x-3,y=3,z=p.z})
    waitFor(1,function() return grounded(hero) end,'Prepared rider did not reach actual ground')
    check('public walk primes a real movement command',intent('Move',1,0)=='OK')
    frame()
    check('movement is present before mount',hero.humanoid.MoveDirection.Magnitude>.5,state())
    result.mountAvailabilityBefore=director.dragons:interaction(1)
    check('actual mount availability remains valid after priming movement',result.mountAvailabilityBefore.available==true,state())
    local collisions={};for _,part in ipairs(hero.model:GetDescendants()) do if part:IsA('BasePart') then collisions[part]=part.CanCollide end end
    local mountCode=intent('Attack');result.mountReturnCode=mountCode
    check('public primary mounts the existing disabled Dragon',mountCode=='OK'
        and director.dragons:isMounted(-10) and hero.model:GetAttribute('DragonLink')=='Mounted'
        and hero.root.Anchored and not hero.humanoid.EvaluateStateMachine,state())
    check('physical link discards pre-mount walking',hero.humanoid.MoveDirection.Magnitude<.01,state())
    local startX=dragon.root.Position.X
    check('public mounted steering accepts',intent('Move',1,0)=='OK');advance(.18)
    check('same unanchored body moves under rider control',dragon.root.Position.X>startX+.4 and not dragon.root.Anchored,state())
    check('public mounted stop accepts',intent('Move',0,0)=='OK');advance(.08)
    check('mounted stop halts horizontal flight',Vector3.new(dragon.root.AssemblyLinearVelocity.X,0,dragon.root.AssemblyLinearVelocity.Z).Magnitude<.2,state())
    waitFor(1,function() return session.now>=session.combat[1].nextAttack end,'Mount input cooldown did not expire')
    check('public mounted fire creates a real projectile',intent('Attack')=='OK' and next(world.dragonFires)~=nil,state())
    check('turn after accepted fire uses public steering',intent('Move',-1,0)=='OK');advance(.05);intent('Move',0,0)
    waitFor(1.5,function() return latest('EnemyHit','DragonFire')~=nil end,'Real swept fire missed the prepared Pig')
    local fireHit=latest('EnemyHit','DragonFire')
    result.fireVelocityAtHit=vec(pig.root.AssemblyLinearVelocity)
    -- ApplyImpulse is submitted during this Heartbeat; sample its real physical
    -- response after the next integration rather than treating same-tick0 as failure.
    local submittedAt=session.now
    waitFor(.3,function() return session.now>submittedAt and math.abs(pig.root.AssemblyLinearVelocity.X)>.1 end,
        'Fire produced no observed horizontal engine response')
    local fireHits=0
    for _,row in ipairs(session.logs) do if row.kind=='EnemyHit' and row.userId==-11 and row.data.action=='DragonFire' then fireHits+=1 end end
    check('real fire keeps source damage and forward response after rider turns',fireHit.userId==-11 and fireHit.data.profile==4
        and fireHit.data.before==31 and fireHit.data.after==15 and director.enemies[-11].rawLife==15 and fireHits==1
        and pig.root.AssemblyLinearVelocity.X>0 and hero.root.CFrame.LookVector.X<0,
        {hit=fireHit,hitCount=fireHits,pigVelocity=vec(pig.root.AssemblyLinearVelocity),riderFacing=vec(hero.root.CFrame.LookVector)})
    check('public jump dismounts',intent('Jump')=='OK' and not director.dragons:isMounted(-10)
        and not hero.root.Anchored and hero.humanoid.EvaluateStateMachine and not hero.humanoid.PlatformStand,state())
    for part,value in pairs(collisions) do check('collision restored: '..part.Name,part.CanCollide==value) end
    check('dismount cannot replay the old walk',hero.humanoid.MoveDirection.Magnitude<.01,state())
    -- Fresh public sidestep avoids using the Dragon's head as a landing surface.
    check('fresh walking remains accepted after dismount',intent('Move',0,1)=='OK');advance(.2);intent('Move',0,0)
    waitFor(2,function() return grounded(hero) end,'Dismounted hero did not physically recover')
    check('mount and fire neither heal nor spend appearances',session.state.heroes[1].actorId==heroId
        and session.state.heroes[1].attempt==1 and session.state.heroes[1].respawns==3 and session.combat[1].rawLife==47
        and world.actors[-10]==dragon and director.enemies[-10].actorId==dragonId
        and director.enemies[-10].ownerUserId==98700010 and director.enemies[-10].rawLife==31,state())
    -- Disclosed capture preparation: one real heavy hit, followed by position/velocity setup.
    p=world:position(-10);preparePosition(hero,{x=p.x+3,y=3,z=p.z});world:face(-10,1)
    check('prepared hero heavy reaction is real',session:_hit(-10,1,'DragonHeadbutt')
        and session.combat[1].heavyReaction==true and session.combat[1].rawLife==31,state())
    -- Consume the submitted physical impulse before the disclosed capture reset;
    -- otherwise its queued motion can correctly carry the target out of reach.
    frame();result.captureImpulseApplied=state()
    p=world:position(-10)
    preparePosition(hero,{x=p.x+3,y=3,z=p.z})
    result.captureRepositioned=state()
    check('capture accepts through its real interface',director.dragons:beginCapture(-10,director.enemies[-10],1))
    waitFor(.65,function() return hero.model:GetAttribute('DragonLink')=='Captured' end,'Delayed capture did not link the real hero')
    check('actual captured body is held without a second hit',hero.root.Anchored and not hero.humanoid.EvaluateStateMachine
        and session.combat[1].rawLife==31 and intent('Move',1,0)=='HELD',state())
    waitFor(2,function() return hero.model:GetAttribute('DragonLink')==nil end,'Finite capture did not release')
    check('capture releases normal locomotion and no stale movement',not hero.root.Anchored and hero.humanoid.EvaluateStateMachine
        and not hero.humanoid.PlatformStand and hero.humanoid.MoveDirection.Magnitude<.01
        and session.combat[1].rawLife==31 and session.state.heroes[1].actorId==heroId
        and session.state.heroes[1].attempt==1 and session.state.heroes[1].respawns==3,state())
    local lastForce=world.dragonFlights[-10] and world.dragonFlights[-10].force
    director.dragons:close()
    check('closing only this transport releases all temporary physics',lastForce and lastForce.Parent==nil
        and next(world.dragonFlights)==nil and next(world.dragonLinks)==nil and next(world.dragonFires)==nil
        and next(director.dragons.shots)==nil and not dragon.root.Anchored and dragon.humanoid.EvaluateStateMachine
        and not dragon.humanoid.PlatformStand,state())
    result.final=state();result.events=session.logs
end,debug.traceback)
result.elapsed=workspace:GetServerTimeNow()-started;result.status=ok and 'pass' or 'fail'
if not ok then result.error=tostring(err) end
if director and director.dragons then pcall(function() director.dragons:close() end) end
if world then world.folder:Destroy() end
output.Value=HttpService:JSONEncode(result);folder:SetAttribute('Status',result.status)
if ok then print('[BT-DRAGON-ACCEPTANCE] '..output.Value) else warn('[BT-DRAGON-ACCEPTANCE] '..output.Value) end
