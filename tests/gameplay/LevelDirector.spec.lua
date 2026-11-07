return function(Director)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture()
        local world={actors={},positions={[1]={x=-65,y=3,z=0}},spawns=0,hits=0}
        function world:spawnEnemy(id,kind,p) self.actors[id]={kind=kind}; self.positions[id]=table.clone(p); self.spawns+=1; return true end
        function world:position(id) return self.positions[id] end
        function world:stage(stage) self.currentStage=stage end
        function world:face() end
        function world:enemyMove() end
        function world:enemyHealth(id,value) self.actors[id].health=value end
        function world:cue() end
        function world:kill(id) self.actors[id].dead=true end
        function world:move() end
        function world:setReaction() end
        function world:impulse() end
        function world:hazard() return nil end
        function world:atExit(id) return self.positions[id].x>=108 end
        function world:projectile(id,p,reflected) self.positions[id]=table.clone(p); self.actors[id]={projectile=true,reflected=reflected} end
        function world:removeProjectile(id) self.positions[id]=nil; self.actors[id]=nil end
        local session={state={status='Active',heroes={[1]={status='Alive',connected=true}}},order={1},combat={[1]={}},now=0}
        function session:_hit(a,t,action) world.hits+=1; world.lastHit={a,t,action}; return true end
        local cfg={Enemy={hearts=3,punchDamage=1,dashDamage=2,speed=9,range=5,windup=.65,cooldown=1.6,reaction=.35,attack='Dash'},Boss={hits=3,interval=2.4,projectileSpeed=12,returnSpeed=26,projectileLife=12,aggroRange=200}}
        return Director.new(session,world,{},cfg),world,session
    end
    local function clearWave(d)
        local ids={}; for id,e in pairs(d.enemies) do if not e.dead then ids[#ids+1]=id end end
        for _,id in ipairs(ids) do for _=1,3 do d:hit(1,id,'Punch'); d:step(d.now+.4,.1) end end
    end
    test('ordinary enemies are weaker and die once without respawning',function()
        local d,w=fixture(); local id=-1
        assert(w.actors[id].health==3)
        d:hit(1,id,'Dash'); assert(d.enemies[id].health==1)
        d:step(.4,.1); d:hit(1,id,'Punch')
        assert(d.enemies[id].dead and w.actors[id].dead)
        assert(d:hit(1,id,'Dash')==false)
    end)
    test('encounters unlock in order and never from walking directly to exit',function()
        local d,w=fixture(); w.positions[1].x=112; d:step(.1,.1)
        assert(d.result==nil and d.stage=='Approach')
        clearWave(d); assert(d.stage=='Courtyard')
        clearWave(d); assert(d.stage=='Boss' and d.bossHits==0)
    end)
    test('boss body is protected and only reflected projectiles count',function()
        local d=fixture(); clearWave(d); clearWave(d)
        assert(d:hit(1,-99,'Dash')==true and d.bossHits==0)
    end)
    test('three reflected balls open exit; one living hero completes exactly once',function()
        local d,w=fixture(); clearWave(d); clearWave(d)
        w.positions[1]={x=68,y=3,z=0}
        for n=1,3 do
            d:step(d.now+3,.1)
            local id; for key,p in pairs(d.projectiles) do if not p.reflected then id=key; break end end
            assert(id,'Boss must fire a real projectile')
            assert(d:hit(1,id,'Punch'))
            assert(not d:hit(1,id,'Punch'),'Same ball cannot reflect twice')
            for _=1,80 do d:step(d.now+.1,.1) end
        end
        assert(d.bossHits==3 and d.stage=='Exit')
        w.positions[1].x=112; d:step(d.now+.1,.1)
        assert(d.result=='Won' and d.stage=='Won')
        local spawns=w.spawns; d:step(d.now+1,.1); assert(w.spawns==spawns)
    end)
    test('NPC attack has a windup and resolves against the actual hero once',function()
        local d,w=fixture(); w.positions[1]={x=-25,y=3,z=-6}
        d:step(.1,.1); assert(w.hits==0 and d.enemies[-1].windup)
        d:step(.8,.1); assert(w.hits>=1 and w.lastHit[3]=='Dash')
        local hits=w.hits; d:step(.81,.01); assert(w.hits==hits)
    end)
    test('a late reflection has time to return instead of inheriting outbound expiry',function()
        local d,w=fixture(); clearWave(d); clearWave(d)
        w.positions[1]={x=10,y=3,z=0}; d:step(d.now+3,.1)
        local id,p=next(d.projectiles); assert(id)
        p.created=d.now-11; p.position={x=10,y=3,z=0}; w:projectile(id,p.position,false)
        assert(d:hit(1,id,'Punch'))
        for _=1,35 do d:step(d.now+.1,.1) end
        assert(d.bossHits==1,'Reflected projectile must reach the boss')
    end)
    test('offline living bodies remain targets without an NPC replacing ownership',function()
        local d,w,s=fixture(); s.state.heroes[1].connected=false; w.positions[1]={x=-25,y=3,z=-6}
        d:step(.1,.1); d:step(.8,.1); assert(w.hits>=1)
    end)
    test('lost run closes encounter and cannot be won at exit',function()
        local d,w,s=fixture(); s.state.status='Lost'; w.positions[1].x=112
        d:step(1,.1); assert(d.result=='Lost' and d.stage=='Lost')
    end)
    test('lethal delayed death cannot turn into victory at the exit',function()
        local d,w,s=fixture(); d.stage='Exit'; w.positions[1].x=112; s.combat[1].deathAt=1
        d:step(.1,.1); assert(d.result==nil,'Lethally struck hero cannot win')
    end)
    test('guardian waits for a hero to enter its arena before firing',function()
        local d,w=fixture(); clearWave(d); clearWave(d); d.config.Boss.aggroRange=45
        w.positions[1]={x=-65,y=3,z=0}; d:step(d.now+3,.1)
        assert(next(d.projectiles)==nil,'Guardian cannot fire across the whole level')
        w.positions[1].x=68; d:step(d.now+3,.1); assert(next(d.projectiles)~=nil)
    end)
    print('LevelDirector: '..passed..' PASS')
end
