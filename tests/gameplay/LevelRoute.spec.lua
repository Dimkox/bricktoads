return function(Director,Definition,Config,Flies)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture()
        local w={actors={[1]={}},positions={[1]={x=-65,y=3,z=0}},spawns={},hazards={},impulses=0}
        function w:spawnEnemy(id,kind,p) self.actors[id]={};self.positions[id]=table.clone(p);self.spawns[#self.spawns+1]={id=id,kind=kind,p=table.clone(p)};return true end
        function w:enemyIdentity(id,identity) self.actors[id].identity=identity end
        function w:enemyHealth(id,n) self.actors[id].hearts=n end
        function w:progress(i,complete) self.zone=i;self.complete=complete end
        function w:stage(s) self.stageName=s end
        function w:position(id) return self.positions[id] end
        function w:hazard(id) return self.hazards[id] end
        function w:move() end
        function w:enemyMove() end
        function w:face() end
        function w:cue() end
        function w:healingFly(id,p) self.food=self.food or {};self.food[id]=p and table.clone(p) or nil end
        function w:canCatchFly() return true end
        function w:setReaction() end
        function w:impulse() self.impulses+=1 end
        function w:kill(id) self.actors[id].dead=true end
        function w:targets() return {} end
        function w:reached(id,b)
            local p=self.positions[id]
            return p and p.x>=b.minX and p.x<=b.maxX and p.y>=b.minY and p.y<=b.maxY and p.z>=b.minZ and p.z<=b.maxZ
        end
        function w:atExit(id) return self:reached(id,Definition.boss.exit) end
        function w:projectile(id,p) self.positions[id]=table.clone(p);self.actors[id]={} end
        function w:removeProjectile(id) self.positions[id]=nil;self.actors[id]=nil end
        local s={state={runId='route-run',levelEpoch=1,status='Active',heroes={[1]={status='Alive',connected=true}}},order={1},combat={[1]={}},now=0}
        local pattern={new=function(d)
            return {step=function() end,hit=function(_,_,target) return target==-99 end,
                interaction=function() return {available=false} end,interact=function() return 'NO_INTERACTION' end}
        end}
        return Director.new(s,w,{},Config,pattern,Flies),w,s
    end
    local function clear(d)
        local ids={};for id,e in pairs(d.enemies) do if not e.dead and not e.boss then ids[#ids+1]=id end end
        for _,id in ipairs(ids) do d:_kill(id) end
    end
    local function reach(w,box)
        w.positions[1]={x=(box.minX+box.maxX)/2,y=(box.minY+box.maxY)/2,z=(box.minZ+box.maxZ)/2}
    end
    test('route contains the classified13 actors in unique source order across6 districts',function()
        assert(#Definition.zones==6)
        local count,kinds,ids=0,{Pig=0,Walker=0,Dragon=0},{}
        for _,z in ipairs(Definition.zones) do for _,e in ipairs(z.enemies) do
            assert(not ids[e.id] and e.id<0 and e.id~=-99);ids[e.id]=true;count+=1;kinds[e.kind]+=1
        end end
        assert(count==13 and kinds.Pig==9 and kinds.Walker==2 and kinds.Dragon==2)
        assert(Definition.boss.position.x>600 and Definition.boss.exit.minX>Definition.boss.position.x)
    end)
    test('initial district alone spawns and distant exit cannot skip living encounters',function()
        local d,w=fixture();assert(d.stage=='Route' and d.zoneIndex==1 and #w.spawns==3)
        reach(w,Definition.boss.exit);d:step(.1,.1)
        assert(d.zoneIndex==1 and not d.result and #w.spawns==3)
    end)
    test('clearing enemies still requires physically reaching that districts far side',function()
        local d,w=fixture();clear(d);d:step(.1,.1)
        assert(d.zoneIndex==1 and w.complete==true and #w.spawns==3)
        reach(w,Definition.zones[1].exit);d:step(.2,.1)
        assert(d.zoneIndex==2 and #w.spawns==6)
        local snap=d:snapshot();assert(snap.zoneIndex==2 and snap.zoneCount==6 and snap.zoneName==Definition.zones[2].name)
    end)
    test('eliminated or dying bodies cannot advance a district',function()
        local d,w,s=fixture();clear(d);reach(w,Definition.zones[1].exit)
        s.state.heroes[1].status='Eliminated';d:step(.1,.1);assert(d.zoneIndex==1)
        s.state.heroes[1].status='Alive';s.combat[1].deathAt=1;d:step(.2,.1);assert(d.zoneIndex==1)
    end)
    test('every district requires its own exit and raised enemies preserve configured height',function()
        local d,w=fixture()
        for i,z in ipairs(Definition.zones) do
            assert(d.zoneIndex==i);clear(d)
            w.positions[1]={x=-65,y=3,z=0};d:step(i,.1);assert(d.zoneIndex==i)
            reach(w,z.exit);d:step(i+.1,.1)
        end
        assert(d.stage=='Boss' and #w.spawns==14 and w.positions[-99].x==628)
        assert(w.positions[-9].y==5 and w.positions[-10].y==7)
        local seen={};for _,spawn in ipairs(w.spawns) do assert(not seen[spawn.id]);seen[spawn.id]=true end
    end)
    test('modern flying shots cannot be reflected and final exit needs guardian defeat',function()
        local d,w=fixture()
        for i,z in ipairs(Definition.zones) do clear(d);reach(w,z.exit);d:step(i,.1) end
        d.projectiles[-1001]={mode='Bullet',position={x=600,y=3,z=0}}
        assert(d:hit(1,-1001,'Punch')==false and not d.projectiles[-1001].reflected)
        assert(d:hit(1,-99,'Dash')==true and w.impulses==0,'Protected modern body must not inherit legacy melee knockback')
        reach(w,Definition.boss.exit);d:step(8,.1);assert(not d.result)
        d:_kill(-99);d:step(8.1,.1);assert(d.result=='Won')
    end)
    test('lost run closes the route before later districts spawn',function()
        local d,w,s=fixture();s.state.status='Lost';clear(d);reach(w,Definition.zones[1].exit);d:step(1,.1)
        assert(d.result=='Lost' and #w.spawns==3)
    end)
    test('route activates its two then four flies and clears them on closure',function()
        local d,w,s=fixture()
        assert(d.flies and d:snapshot().healingFlies.total==6,'production route must compose food mechanics')
        assert(not w.food or next(w.food)==nil)
        for i=1,2 do clear(d);reach(w,Definition.zones[i].exit);d:step(i,.1) end
        assert(d:snapshot().healingFlies.active==2 and w.food['courtyard-fly-1'])
        for i=3,5 do clear(d);reach(w,Definition.zones[i].exit);d:step(i,.1) end
        assert(d:snapshot().healingFlies.active==6 and w.food['bridge-fly-4'])
        s.state.status='Lost';d:step(7,.1)
        assert(next(w.food)==nil and d:snapshot().healingFlies.active==0)
    end)
    print('LevelRoute: '..passed..' passed')
end
