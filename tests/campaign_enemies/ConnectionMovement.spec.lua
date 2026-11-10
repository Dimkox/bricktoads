return function(Enemies,Director,Session,Core,Combat,Config,FakeWorld,Definition)
    local function eq(actual,expected,label)
        assert(actual==expected,label..' expected '..tostring(expected)..', got '..tostring(actual))
    end
    local function near(actual,expected,label)
        assert(math.abs(actual-expected)<1e-8,label..' expected '..expected..', got '..actual)
    end
    local function fixture(index,kind)
        local definition=Definition.build(index,41)
        local authored
        for _,row in ipairs(definition.zones[1].enemies) do
            if row.kind==kind then authored=table.clone(row);break end
        end
        assert(authored,'Missing authored '..kind)
        definition.zones[1].enemies={authored}
        local world=FakeWorld.new()
        world.positions={[1]=table.clone(definition.spawn)}
        function world:position(id) return self.positions[id] end
        function world:spawnEnemy(id,name,p)
            self.positions[id]=table.clone(p);self.actors[id]={alive=true,kind=name};return true
        end
        function world:enemyIdentity() end
        function world:enemyHealth() end
        function world:progress() end
        function world:stage() end
        function world:reached() return false end
        function world:face() end
        function world:aim() end
        function world:cue() end
        function world:campaignWalkSpeed() end
        function world:campaignPose(id,p,mode)
            self.positions[id]=table.clone(p);self.actors[id].campaignControl=mode
        end
        function world:campaignRelease(id) self.actors[id].campaignControl=nil end
        function world:projectile() end
        function world:removeProjectile() end
        local config=table.clone(Config);config.Level=definition
        local session=Session.new(Core,Combat,config,{{userId=1,template='Mr. Green'}},'connection-'..kind,world)
        eq(session:step(0),'OK','Initial spawn')
        local director=Director.new(session,world,Combat,config)
        local enemies=Enemies.new(director);director.campaignEnemies=enemies
        local id=authored.id
        local function step(now,dt)
            eq(session:step(now),'OK','Session step');director:step(now,dt);eq(enemies:step(now,dt),'OK','Family step')
        end
        local function move(now,x,epoch)
            local enemy=director.enemies[id]
            return director:command(99,{kind='Move',x=x,z=0,runId=session.state.runId,actorId=enemy.actorId,
                attempt=1,levelEpoch=session.state.levelEpoch,connectionEpoch=epoch or enemy.connectionEpoch,
                seq=enemy.lastSeq+1},now,Session.validIntent)
        end
        return director,world,session,id,step,move
    end

    local failures={}
    for _,case in ipairs({{9,'Electrofish'},{12,'Swellcheeks'}}) do
        local ok,err=pcall(function()
            local director,world,session,id,step,move=fixture(case[1],case[2])
            eq(director:claim(99,id),'OK','Claim authored '..case[2])
            local enemy=director.enemies[id]
            local actorId,body,rawLife=enemy.actorId,world.actors[id],enemy.rawLife
            local heroActor=session.state.heroes[1].actorId
            local oldEpoch=enemy.connectionEpoch
            local start=world:position(id).x
            eq(move(.1,1),'OK','Initial movement');step(.2,.1)
            local moved=world:position(id).x
            assert(moved>start,'Initial movement must move the existing body')
            eq(director:connection(99,false),'OK','Disconnect')
            step(.3,.1);near(world:position(id).x,moved,'Offline horizontal movement stops')
            eq(director:connection(99,true),'OK','Reconnect')
            for n=1,10 do step(.3+n*.1,.1) end
            near(world:position(id).x,moved,case[2]..' reconnect needs fresh movement after timeout')
            eq(move(1.31,-1,oldEpoch),'STALE_CONNECTION','Previous connection cannot steer')
            step(1.4,.1);near(world:position(id).x,moved,'Rejected movement leaves body stopped')
            eq(move(1.5,1),'OK','Fresh connection may steer');step(1.6,.1)
            assert(world:position(id).x>moved,'Fresh movement resumes the same body')
            eq(world.actors[id],body,'Native boundary body identity');eq(enemy.actorId,actorId,'Enemy actor identity')
            eq(enemy.rawLife,rawLife,'Enemy Life');eq(enemy.ownerUserId,99,'Same one-life owner')
            eq(director:claim(100,id),'ENEMY_OCCUPIED','Other owner cannot take the body')
            local hero=session.state.heroes[1]
            eq(hero.actorId,heroActor,'Hero actor identity');eq(hero.attempt,1,'Hero attempt');eq(hero.respawns,3,'Hero stock')
            eq(session.combat[1].rawLife,47,'Hero Life')
            print('PASS '..case[2]..' reconnect discards held movement until a fresh connection intent')
        end)
        if not ok then failures[#failures+1]=case[2]..': '..tostring(err) end
    end
    assert(#failures==0,table.concat(failures,'\n'))
end
