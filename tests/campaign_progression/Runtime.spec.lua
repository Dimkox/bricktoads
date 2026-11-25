-- Native modules together, with only engine actor presentation replaced.
return function(Definition,Modes,Boss,Director,CampaignDirector,Session,Core,Combat,GameConfig,BaseConfig,FakeWorld,SourceCombat,CampaignEnemies)
    local function nativeWorld(route)
        local world=FakeWorld.new();world.names={};world.positions={};world.objects={}
        function world:position(id) return self.positions[id] end
        local originalSpawn=world.spawn
        function world:spawn(id,actorId,...)
            local spawned=originalSpawn(self,id,actorId,...)
            if spawned then self.positions[id]=table.clone(route.spawn) end
            return spawned
        end
        function world:spawnEnemy(id,kind,point)
            local spawned=originalSpawn(self,id,'enemy-'..id,nil,false)
            if spawned then self.positions[id]=table.clone(point) end
            return spawned
        end
        function world:campaignPose(id,point)
            if self.rejectPose then return false end
            self.positions[id]=table.clone(point);return true
        end
        function world:campaignRelease() end
        function world:campaignObject(id,kind,point) self.objects[id]={kind=kind,position=table.clone(point)} end
        function world:campaignRemove(id) self.objects[id]=nil end
        function world:stage(value) self.stageName=value end
        function world:progress() end
        function world:reached() return false end
        function world:atExit() return false end
        function world:enemyIdentity(id,actorId) self.actors[id].id=actorId end
        function world:enemyHealth() end
        function world:enemyMove() end
        function world:face() end
        function world:aim() end
        function world:cue() end
        function world:projectile() end
        function world:removeProjectile() end
        function world:placeActor(id,point) self.positions[id]=table.clone(point);return true end
        function world:clearActors() self.actors={};self.positions={} end
        function world:rebuildLevel(nextRoute) route=nextRoute;return true end
        function world:advanceGeometry(nextRoute) route=nextRoute;return true end
        return world
    end
    local function fixture(index)
        local route=Definition.build(index,51)
        local world=nativeWorld(route)
        local config=GameConfig(BaseConfig,route)
        local session=Session.new(Core,Combat,config,{{userId=1,template='Mr. Green'}},'native-campaign-'..index,world)
        session:step(0)
        local director=CampaignDirector.new(session,world,Combat,config,{Director=Director,
            CampaignModes=Modes,CampaignBoss=Boss,CampaignDefinition=Definition,CampaignEnemies=CampaignEnemies})
        local originalHit=session._hit
        session._hit=function(self,attacker,target,action,tuning)
            if target<0 then return director:hit(attacker,target,action,tuning) end
            return originalHit(self,attacker,target,action,tuning)
        end
        SourceCombat.bind(session,director,config)
        return session,world,director,route
    end
    for index=2,13 do
        local session,world,director,route=fixture(index)
        director:step(1/60,1/60)
        local snapshot=director:snapshot()
        assert(snapshot.mode==route.mode and snapshot.modeState.mode==route.mode and snapshot.campaignIndex==index)
        assert(session.state.heroes[1].attempt==1 and session.state.heroes[1].respawns==3
            and world.spawns==1+#route.zones[1].enemies+(director.boss and 1 or 0)+(route.mode=='Race' and 1 or 0))
        if index==11 then
            assert(director.modes.chaseProgress>-route.course.chaseGap,'The NPC chase must move without a human controller')
        end
        director:close('TestComplete');assert(world.campaignModes==nil)
    end
    print('PASS every authored native mode constructs and steps with real Session and family combat')
    local function speederEntry(delayed,hitWall)
        local startingRoute=Definition.build(1,51)
        local world=nativeWorld(startingRoute)
        local player={UserId=89,Name='Rider',DisplayName='Rider',Parent=true}
        local events={}
        local telemetry={}
        for _,event in ipairs({'spawned','boarded','passedFirstWall','startPressed'}) do
            telemetry[event]=function(_,owner) assert(owner==player);table.insert(events,event) end
        end
        local clock=0
        local controller=require('../../src/server/gameplay/GameController').new({
            Registry=require('../../src/stand/server/ConnectionRegistry'),Core=Core,Combat=Combat,Session=Session,
            Config=GameConfig(BaseConfig,startingRoute),Director=Director,CampaignDirector=CampaignDirector,
            CampaignModes=Modes,CampaignDefinition=Definition,FirstMinute=telemetry,GroupId='entry',
            clock=function() return clock end,guid=function() return 'entry-run' end
        },world)
        controller:join(player)
        world.safe=not delayed;world.rejectPose=delayed
        assert(controller:startSpeederEntry(player,{player})=='OK')
        local modes=controller.director.modes
        local function step(dt) clock+=dt;controller:step(clock,dt) end
        if delayed then
            assert(controller.current.state.heroes[1].status=='AwaitingInitial' and #events==0)
            assert(controller:releaseSpeederEntry(player,'entry-run')=='ENTRY_NOT_BOARDED')
            world.safe=true;step(1)
            assert(table.concat(events,',')=='spawned' and not modes.actors[1].mounted)
            assert(controller:releaseSpeederEntry(player,'entry-run')=='ENTRY_NOT_BOARDED')
            world.rejectPose=false;step(1/60)
        end
        assert(table.concat(events,',')=='spawned,boarded' and modes.actors[1].mounted)
        assert(world.objects['vehicle-1'].kind=='Speeder' and controller.current.state.levelId=='campaign-3')
        assert(controller.campaignIndex==3 and not next(controller.director.enemies))
        assert(controller:startSpeederEntry(player,{player})=='RUN_ACTIVE')
        local rider=modes.actors[1]
        local wall=modes.course.hazards[1]
        assert(wall.kind=='Wall' and modes.vehicleGroup.phase=='AwaitingEntryView')
        local origin=table.clone(rider.position)
        for _=1,210 do step(1/60) end
        assert(modes.elapsed==0 and modes.vehicleGroup.speed==0 and rider.progress==0)
        assert(rider.position.x==origin.x and rider.position.z==origin.z and world:position(1).x==origin.x)
        assert(table.concat(events,',')=='spawned,boarded')
        assert(controller:releaseSpeederEntry(player,'old-run')=='WRONG_RUN')
        assert(controller:releaseSpeederEntry(table.clone(player),'entry-run')=='STALE_CONNECTION')
        local other={UserId=32,Name='Other',DisplayName='Other',Parent=true}
        controller:join(other)
        assert(controller:releaseSpeederEntry(other,'entry-run')=='NOT_OWNER')
        controller:leave(other)
        assert(modes.vehicleGroup.phase=='AwaitingEntryView')
        assert(controller:releaseSpeederEntry(player,'entry-run')=='OK')
        assert(modes.vehicleGroup.phase=='Riding' and modes.vehicleGroup.speed==modes.course.speed)
        step(1/60)
        local speed=modes.vehicleGroup.speed
        assert(controller:releaseSpeederEntry(player,'entry-run')=='OK' and speed==modes.vehicleGroup.speed)
        -- Start just before the actual obstacle and cross it through real course physics.
        rider.position.x=wall.x-6;rider.position.z=hitWall and wall.z or (wall.z<=0 and 16 or -16)
        for _=1,21 do step(1/60) end
        if hitWall then
            assert(controller.current.state.heroes[1].attempt==2,'First collision must consume a real retry')
            for _=1,120 do
                if modes.vehicleGroup.phase=='Riding' then break end
                step(1/60)
            end
            local hero=controller.current.state.heroes[1]
            local retry=modes.actors[1]
            assert(modes.vehicleGroup.phase=='Riding' and hero.shield and hero.shield.deadline>clock+.7)
            retry.position.x=wall.x-6;retry.position.z=wall.z
            for _=1,40 do step(1/60) end
            assert(hero.attempt==controller.current.state.heroes[1].attempt and retry.position.x>wall.x+4)
            for _,event in ipairs(events) do assert(event~='passedFirstWall','A collision cannot earn a pass') end
        else
            assert(table.concat(events,',')=='spawned,boarded,passedFirstWall')
            local oldHero=controller.current.state.heroes[1].actorId
            rider.position=table.clone(modes.course.finishPoint)
            step(1/60)
            assert(controller.campaignIndex==4 and controller.current.state.levelId=='campaign-4')
            assert(controller.current.state.heroes[1].actorId==oldHero and not controller.director.definition.speederEntry)
        end
    end
    speederEntry(false,false);speederEntry(true,true)
    print('PASS ad entry boards a physical speeder, waits for its owner to see it, credits a cleared wall and advances to level 4')
    local session,world,director,route=fixture(13)
    director.bossGate=function() return {state='Human',userId=90} end
    world.positions[1]=table.clone(route.course.finishPoint)
    director:step(.1,.1)
    assert(director.modes.complete and director.boss and not director.result)
    local bossActor=director.boss.enemies[-99].actorId
    world.positions[1]={x=route.boss.position.x-4,y=route.boss.position.y,z=route.boss.position.z}
    world.targetsFor[1]={-99}
    local now=.1;local seq=0
    for _=1,600 do
        seq+=1;now+=.1
        local hero=session.state.heroes[1]
        session:intent(1,{kind='Attack',attack='Punch',runId=session.state.runId,actorId=hero.actorId,
            attempt=hero.attempt,levelEpoch=session.state.levelEpoch,connectionEpoch=hero.connectionEpoch,seq=seq},now)
        director.now=now;session:step(now);director:step(now,.1)
        if director.result then break end
    end
    assert(director.result=='Won' and director.boss.defeated,'Campaign victory must come from real accepted attacks and boss progress')
    assert(director.boss.enemies[-99].actorId==bossActor and session.state.heroes[1].respawns==3)
    assert(director:snapshot().bossProgress>=240)
    print('PASS final mode entrance and real hero attack lifecycle defeat the final boss before campaign victory')
    local raceSession,raceWorld,raceDirector=fixture(10)
    local offer
    for _,candidate in ipairs(raceDirector:available(999)) do if candidate.resourceKind=='CourseRival' then offer=candidate end end
    assert(offer and offer.enemyId==-98 and offer.maxHearts==0)
    local rivalBody=raceWorld.actors[-98]
    assert(raceDirector:claim(999,-98)=='OK')
    local role=raceDirector:controlled(999)
    assert(role.resourceKind=='CourseRival' and role.template=='Racer' and role.actorId==offer.actorId)
    local packet={kind='Move',runId=raceSession.state.runId,actorId=role.actorId,attempt=1,levelEpoch=1,
        connectionEpoch=role.connectionEpoch,seq=1,x=1,z=0}
    assert(raceDirector:command(999,packet,.01,Session.validIntent)=='OK')
    assert(raceWorld.actors[-98]==rivalBody and raceDirector:connection(999,false)=='OK')
    assert(not raceDirector:controlled(999).connected)
    raceDirector:close('TestComplete')
    print('PASS campaign routes the actual rival offer, same-body claim, input and disconnect without fake hearts')

    local rideSession,rideWorld,rideDirector,rideDefinition=fixture(3)
    rideDirector.ordinary:_kill(-1,'PreparedEntryClear')
    local event=rideDefinition.course.encounters[1]
    local first=rideDirector.modes.spawnEncounter(event)
    local firstActor=rideDirector.enemies[first].actorId
    assert(first<0 and first>-1000 and rideDirector.enemies[first].encounter and rideDirector.modes.canBoard())
    assert(rideDirector:claim(888,first)=='OK')
    rideDirector.modes.resetEncounters({replayIds={}})
    assert(rideDirector.enemies[first].dead and rideDirector:controlled(888).status=='Dead')
    local replay=rideDirector.modes.spawnEncounter(event)
    assert(replay~=first and rideDirector.enemies[replay].actorId~=firstActor
        and not rideDirector.enemies[replay].ownerUserId and rideDirector:controlled(888).status=='Dead')
    rideDirector:close('TestComplete')
    print('PASS scripted ride replay creates a fresh unclaimed actor and retains the spent prior human life')
end
