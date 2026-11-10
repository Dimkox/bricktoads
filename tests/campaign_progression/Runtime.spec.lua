-- Native modules together, with only engine actor presentation replaced.
return function(Definition,Modes,Boss,Director,CampaignDirector,Session,Core,Combat,GameConfig,BaseConfig,FakeWorld,SourceCombat,CampaignEnemies)
    local function fixture(index)
        local route=Definition.build(index,51)
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
        function world:campaignPose(id,point) self.positions[id]=table.clone(point) end
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
