return function(Definition,Modes)
    local passed=0
    local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS '..name) end
    local function fixture(index,seed,cohort)
        local d=Definition.build(index,seed or 41)
        local w={points={},objects={},released={},poses=0}
        function w:position(id) return self.points[id] end
        function w:campaignPose(id,p,mode,velocity) self.points[id]=table.clone(p);self.poses+=1 end
        function w:campaignObject(id,kind,p,size,metadata) self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata} end
        function w:campaignRemove(id) self.objects[id]=nil end
        function w:campaignRelease(id) self.released[id]=true end
        function w:spawnEnemy(id,kind,p) self.points[id]=table.clone(p);return true end
        function w:enemyIdentity() end
        function w:kill(id) self.points[id]=nil end
        local s={now=0,order={101},state={status='Active',runId='mode-test',levelEpoch=1,heroes={
            [101]={actorId='hero-original',attempt=1,status='Alive',connected=true,respawns=3}}},combat={[101]={}}}
        function s:_die(id,reason) self.state.heroes[id].status='AwaitingRespawn';self.deaths=(self.deaths or 0)+1;self.deathReason=reason end
        function s:_hit(attacker,id,action) self.hits=(self.hits or 0)+1;self.lastHit=action;return true end
        function s:_record() end
        w.points[101]=table.clone(d.spawn)
        for n=2,cohort or 1 do local slot=100+n
            s.order[#s.order+1]=slot;s.state.heroes[slot]={actorId='hero-'..n,attempt=1,status='Alive',connected=true,respawns=3}
            s.combat[slot]={};w.points[slot]=table.clone(d.spawn);w.points[slot].z=(n-1)*4
        end
        local m=Modes.new(s,w,d)
        local now=0
        local function step(dt) now+=dt;s.now=now;m:step(now,dt) end
        return d,s,w,m,step
    end
    test('rope is attached descent with controllable swing and same-body checkpoint respawn',function()
        local d,s,w,m,step=fixture(2)
        assert(m:move(101,1,0,false)==true)
        for _=1,60 do step(1/60) end
        local p=w:position(101);assert(p.y<d.spawn.y and p.x>d.spawn.x and not m.complete)
        local old=m:snapshot().actors[1].checkpoint
        assert(old>=1)
        s.state.heroes[101].status='AwaitingRespawn';step(.1)
        s.state.heroes[101].attempt=2;s.state.heroes[101].status='Alive';w.points[101]={x=999,y=-999,z=999};step(1/60)
        assert(w:position(101).y>0 and s.state.heroes[101].actorId=='hero-original' and s.state.heroes[101].respawns==3)
    end)
    test('vehicle must be mounted and lane input cannot skip a wall during a long frame',function()
        local d,s,w,m,step=fixture(3)
        assert(m:move(101,1,0,false)==false and m:interact(101,0,'Punch')=='NO_INTERACTION')
        w.points[101]=table.clone(d.course.mount);step(1/60)
        assert(m:interaction(101).available and m:interact(101,s.now,'Punch')=='OK')
        local h=d.course.hazards[1]
        m.actors[101].position={x=h.x-2,y=h.y,z=h.z};w.points[101]=table.clone(m.actors[101].position)
        step(2)
        assert(s.deaths==1 and not m.complete,'crash must be swept through intermediate geometry')
        assert(m:snapshot().discardedSeconds>=1.4)
    end)
    test('ice accelerates and retains momentum after release while jump requires support',function()
        local _,_,w,m,step=fixture(4)
        assert(m:move(101,1,0,false))
        for _=1,10 do step(1/60) end
        local a=w:position(101).x;m:move(101,0,0,false);step(1/60)
        assert(w:position(101).x>a,'ice must coast instead of using ordinary walk')
        assert(m:jump(101));local y=w:position(101).y;step(1/60);assert(w:position(101).y>y)
        local vy=m.actors[101].velocity.y;m:jump(101);assert(m.actors[101].velocity.y==vy,'cannot air-jump')
    end)
    test('serpent support carries standing bodies and room exit must be reached in order',function()
        local d,_,w,m,step=fixture(6)
        step(1/60)
        local support=m.supports[1]
        m.actors[101].position={x=support.position.x,y=support.position.y+3.5,z=support.position.z}
        m.actors[101].grounded=true;m.actors[101].support=support.id
        local old=m.actors[101].position.x
        step(1/60);assert(w:position(101).x~=old)
        local finish=d.course.rooms[4].exit
        m.actors[101].position={x=(finish.minX+finish.maxX)/2,y=(finish.minY+finish.maxY)/2,z=0}
        step(1/60);assert(not m.complete and m:snapshot().room==1)
    end)
    test('tube environment switches to swimming and returns to dry movement',function()
        local d,_,w,m,step=fixture(9)
        local water=d.course.media[1]
        m.actors[101].position={x=water.minX+6,y=water.minY+6,z=0};w.points[101]=table.clone(m.actors[101].position)
        step(1/60);assert(m:snapshot().actors[1].medium=='Water')
        m:move(101,0,-1,false);local y=w:position(101).y;step(1/60);assert(w:position(101).y>y)
        m.actors[101].position=table.clone(d.spawn);step(1/60)
        assert(m:snapshot().actors[1].medium=='Dry')
    end)
    test('race cannot finish without every bomb and a rat win kills rather than grants victory',function()
        local d,s,w,m,step=fixture(10)
        w.points[101]=table.clone(d.course.finishPoint);m.actors[101].position=table.clone(w.points[101]);step(1/60)
        assert(not m.complete and m:snapshot().bombIndex==1)
        for _=1,100 do step(.5);if s.deaths then break end end
        assert(s.deaths==1 and not m.complete)
    end)
    test('clinger follows the current path direction and wrong input lets the chase catch up',function()
        local d,s,_,m,step=fixture(11)
        local direction=d.course.path[1].direction
        m:move(101,-direction.x,-direction.z,false)
        for _=1,100 do step(.5);if s.deaths then break end end
        assert(s.deaths==1 and not m.complete and m:snapshot().chaseLife==207)
    end)
    test('offline roles never reuse held human input and closed modes release all bodies',function()
        local _,s,w,m,step=fixture(2)
        m:move(101,1,0,false);s.state.heroes[101].connected=false;step(.1)
        assert(m.actors[101].input.x==0,'offline body continues physical descent without stale steering')
        local x=w:position(101).x;m:close('Transition');step(.5)
        assert(w.released[101] and w:position(101).x==x and m:move(101,1,0,false)==false)
    end)
    test('walk modes cannot win from elapsed time and finale requires the arena entrance',function()
        for _,index in ipairs({8,12,13}) do
            local _,_,_,m,step=fixture(index)
            for _=1,5 do step(.5) end
            assert(not m.complete)
        end
    end)
    test('boarding waits for the intro patrol and mounted attacks cannot schedule ground strikes',function()
        local d,_,w,m,step=fixture(3)
        w.points[101]=table.clone(d.course.mount);step(1/60);m.canBoard=function() return false end
        assert(not m:interaction(101).available and m:interact(101,0,'Punch')=='ENEMIES_REMAIN')
        m.canBoard=function() return true end
        assert(m:interact(101,0,'Punch')=='OK')
        assert(m:interact(101,0,'Punch')=='HANDS_FULL')
    end)
    test('inactive electrical hazards do no damage while active hits use Session combat',function()
        local d,s,_,m,step=fixture(2)
        d.course.hazards={{id='probe',kind='ElectricTrap',x=0,y=240,z=0,w=8,h=8,d=8,motion={phase=-2}}}
        step(1/60);assert(not s.hits)
        d.course.hazards[1].motion.phase=1;step(1/60)
        assert(s.hits==1 and s.lastHit=='Dash')
    end)
    test('spawn shield blocks a crash without granting completion or extending its deadline',function()
        local d,s,w,m,step=fixture(3)
        s.state.heroes[101].shield={kind='Ordinary',deadline=4}
        w.points[101]=table.clone(d.course.mount);step(1/60);m:interact(101,0,'Punch')
        local h=d.course.hazards[1];m.actors[101].position={x=h.x-2,y=h.y,z=h.z}
        step(.1);assert(not s.deaths and not m.complete and s.state.heroes[101].shield.deadline==4)
    end)
    test('kinematic combat knockback moves the actual body and prevents input during reaction',function()
        local _,s,w,m,step=fixture(4)
        assert(m:impulse(101,{x=20,y=18,z=0}))
        s.combat[101].reactionEnd=1;m:move(101,-1,0,false)
        local x=w.points[101].x;step(1/60)
        assert(w.points[101].x>x and m.actors[101].input.x==0)
    end)
    test('rope primary kick removes only a nearby breakable hazard',function()
        local d,s,_,m,step=fixture(2)
        d.course.hazards={{id='near',kind='Raven',x=4,y=240,z=0,w=3,h=3,d=3},
            {id='far',kind='Raven',x=16,y=240,z=0,w=3,h=3,d=3}}
        assert(m:interact(101,0,'Punch')=='OK');step(1/60)
        assert(m.broken.near and not m.broken.far and not s.hits)
    end)
    test('every race bomb requires a fresh near action and all three unlock the arena',function()
        local d,s,_,m,step=fixture(10)
        for n,bomb in ipairs(d.course.bombs) do
            m.actors[101].position=table.clone(bomb.position);step(1/60)
            assert(m:interact(101,s.now,'Punch')=='OK' and m:snapshot().bombIndex==n+1)
        end
        step(1/60);assert(m.complete)
    end)
    test('holding the correct clinger direction traverses every real corner before the boss',function()
        local d,_,w,m,step=fixture(11)
        local iterations=0
        while not m.complete and iterations<5000 do
            local segment=d.course.path[m.actors[101].segment]
            if segment then m:move(101,segment.direction.x,segment.direction.z,false) end
            step(1/60);iterations+=1
        end
        assert(m.complete and iterations>100 and w.released[101])
    end)
    test('top rotating support unlocks tower exit in its current orientation',function()
        local d,_,w,m,step=fixture(12)
        step(.5)
        local top=d.course.towerPlatforms[#d.course.towerPlatforms];local a=top.angle+m.rotation
        m.actors[101].position={x=math.cos(a)*top.radius,y=top.y+3,z=math.sin(a)*top.radius}
        m.actors[101].grounded=true;m.actors[101].support='tower-'..#d.course.towerPlatforms
        step(1/60)
        assert(m.complete and w.released[101])
    end)
    test('human chase controls the same shared orb and disconnect never enables NPC pursuit',function()
        local _,s,_,m,step=fixture(11)
        local poses=0;m.chaseActor=function(p) assert(p.x==p.x);poses+=1 end
        m:setChaseController(501,true)
        step(.1);local p=m.chaseProgress
        assert(m:chaseCommand(1,0,s.now)=='OK');step(.1);assert(m.chaseProgress>p and poses>0)
        m:chaseConnection(false);local offline=m.chaseProgress;step(.5)
        assert(m.chaseProgress==offline and m:chaseCommand(1,0,s.now)=='OFFLINE')
    end)
    test('a physical speeder ramp launches once on crossing and cannot grant air jumps',function()
        local d,s,w,m,step=fixture(3)
        d.course.hazards={};d.course.ramps={{id='ramp-probe',x=60,y=1,z=0,w=8,h=2,d=12,launchSpeed=48}}
        w.points[101]=table.clone(d.course.mount);step(1/60);m:interact(101,s.now,'Punch')
        m.actors[101].position={x=59.8,y=3,z=0};step(1/60)
        assert(m.actors[101].velocity.y>40 and w.points[101].y>3)
        local vy=m.actors[101].velocity.y;m:jump(101);assert(m.actors[101].velocity.y==vy)
    end)
    test('nearby shaft blasters fire finite swept projectiles rather than decorative objects',function()
        local d,s,_,m,step=fixture(2)
        d.course.hazards={};d.course.emitters={{id='gun',kind='RetroBlaster',position={x=4,y=240,z=0},interval=.4,speed=20,life=2}}
        for _=1,30 do step(1/60) end
        assert(s.hits and s.hits>=1)
        local count=0;for _ in pairs(m.projectiles) do count+=1 end;assert(count<=6)
    end)
    test('jet directions separate throttle from altitude and preserve the flight lane',function()
        local d,s,w,m,step=fixture(7)
        d.course.hazards={};w.points[101]=table.clone(d.course.mount);step(1/60);m:interact(101,s.now,'Punch')
        m:move(101,1,0,false);local y=w.points[101].y;step(.1)
        assert(w.points[101].y==y,'forward throttle must not descend')
        m:move(101,0,-1,false);step(.1)
        assert(w.points[101].y>y and w.points[101].z==0,'up must climb without depth steering')
    end)
    test('a pedestrian reaching the vehicle finish cannot bypass boarding',function()
        for _,level in ipairs({3,5,7}) do
            local d,_,w,m,step=fixture(level)
            w.points[101]=table.clone(d.course.finishPoint);step(1/60)
            assert(not m.complete)
        end
    end)
    test('tower checkpoint respawn follows the actual support rotation',function()
        local d,_,_,m,step=fixture(12)
        m.actors[101].checkpoint=2;step(.5)
        local p=m:respawnPosition(101);local support=d.course.towerPlatforms[10]
        assert(math.abs(p.x-math.cos(support.angle+m.rotation)*support.radius)<.001)
        assert(math.abs(p.z-math.sin(support.angle+m.rotation)*support.radius)<.001)
    end)
    test('both tower springs launch from their rotating supports and reject airborne repeats',function()
        local d,_,_,m=fixture(12)
        for _,rotation in ipairs({math.pi/2,.37,math.pi*1.3}) do
            m.rotation=rotation;m.elapsed=rotation/d.course.rotationSpeed;m:_objects(0)
            for n,spring in ipairs(d.course.springs) do
                local index=({8,15})[n];local support=d.course.towerPlatforms[index]
                local angle=support.angle+rotation;local a=m.actors[101]
                a.position={x=math.cos(angle)*support.radius,y=spring.y,z=math.sin(angle)*support.radius}
                a.velocity={x=0,y=-1,z=0}
                m:_ground(a,{x=a.position.x,y=a.position.y+.1,z=a.position.z},1/60)
                assert(a.grounded and a.support=='tower-'..index,'spring stance must use its real rotated support')
                assert(m:jump(101))
                assert(a.velocity.y==spring.power,'spring '..n..' at rotation '..rotation..' must launch '..spring.power..', got '..a.velocity.y)
                assert(spring.towerPlatform==index,'spring must explicitly identify its tower support')
                local vy=a.velocity.y;m:jump(101)
                assert(a.velocity.y==vy and not a.grounded,'spring cannot grant an airborne repeat')
            end
        end
    end)
    test('tower spring graphics remain aligned with their rotating support frames',function()
        local d,_,w,m=fixture(12)
        for _,rotation in ipairs({.37,math.pi/2,math.pi*1.3}) do
            m.rotation=rotation;m.elapsed=rotation/d.course.rotationSpeed;m:_objects(0)
            for n,spring in ipairs(d.course.springs) do
                local index=({8,15})[n];local platform=w.objects['tower-'..index];local pad=w.objects['spring-'..n]
                assert(math.abs(pad.position.x-platform.position.x)<1e-7 and math.abs(pad.position.z-platform.position.z)<1e-7,
                    'spring graphic must travel with support '..index)
                assert(pad.position.y==spring.y and math.abs(pad.metadata.yaw-platform.metadata.yaw)<1e-7,
                    'spring graphic must retain its height and support yaw')
            end
        end
    end)
    test('rotated spring footprints retain pad edges and reject supported off-pad jumps',function()
        local d,_,_,m=fixture(12)
        for _,rotation in ipairs({.37,math.pi/2}) do
            m.rotation=rotation
            for n,spring in ipairs(d.course.springs) do
                local index=({8,15})[n];local support=d.course.towerPlatforms[index];local angle=support.angle+rotation
                local cx,cz=math.cos(angle)*support.radius,math.sin(angle)*support.radius
                for _,probe in ipairs({{x=3.999,z=3.999,boost=true},{x=-3.999,z=-3.999,boost=true},
                    {x=4.999,z=0,boost=true},{x=5.01,z=0,boost=false},{x=0,z=4.01,boost=false}}) do
                    local a=m.actors[101]
                    a.position={x=cx+math.cos(angle)*probe.x-math.sin(angle)*probe.z,y=spring.y,
                        z=cz+math.sin(angle)*probe.x+math.cos(angle)*probe.z}
                    a.velocity={x=0,y=-1,z=0}
                    m:_ground(a,{x=a.position.x,y=a.position.y+.1,z=a.position.z},1/60)
                    assert(a.grounded and a.support=='tower-'..index,'off-pad checks must still stand on actual floor')
                    m:jump(101)
                    assert(a.velocity.y==(probe.boost and spring.power or d.course.jumpSpeed),
                        'spring footprint must rotate with the visible pad, including its existing launch allowance')
                end
            end
        end
    end)
    test('ascent springs retain their static graphics and launch power',function()
        local d,_,w,m=fixture(8);local spring=d.course.springs[1];local a=m.actors[101]
        m.rotation=math.pi/2;m:_objects(0)
        local pad=w.objects['spring-1']
        assert(pad.position.x==spring.x and pad.position.y==spring.y and pad.position.z==spring.z)
        a.position={x=spring.x,y=spring.y,z=spring.z};a.velocity={x=0,y=-1,z=0}
        m:_ground(a,{x=a.position.x,y=a.position.y+.1,z=a.position.z},1/60)
        assert(a.grounded);m:jump(101);assert(a.velocity.y==spring.power)
        local vy=a.velocity.y;m:jump(101);assert(a.velocity.y==vy)
    end)
    test('first trio finisher releases only that body while remaining riders retain control',function()
        local d,s,w,m,step=fixture(5,41,3)
        d.course.hazards={};d.course.emitters={}
        for _,slot in ipairs(s.order) do w.points[slot]=table.clone(d.course.mount);m:interact(slot,0,'Punch') end
        m.actors[101].position=table.clone(d.course.finishPoint);step(1/60)
        assert(m.complete and m.actors[101].finished and w.released[101])
        assert(not w.released[102] and not w.released[103] and m:move(102,0,1,false))
        local x=w.points[102].x;step(1/60);assert(w.points[102].x>x and not s.deaths)
        assert(m:snapshot().actors[1].finished and not m:snapshot().actors[2].finished)
    end)
    test('solo clinger retry resets chase position while preserving shared boss Life',function()
        local _,s,w,m,step=fixture(11)
        for _=1,120 do step(1/60);if s.deaths then break end end
        assert(s.deaths==1)
        s.state.heroes[101].status='Alive';s.state.heroes[101].attempt=2;w.points[101]={x=0,y=3,z=0};step(1/60)
        assert(m.chaseProgress<0 and s.deaths==1 and m.chaseLife==207)
    end)
    test('jump accepts the takeoff run cap and cannot gain it from a midair toggle',function()
        local _,_,_,m,step=fixture(8)
        m:move(101,1,0,false);m:jump(101);m:move(101,1,0,true);step(1/60)
        assert(m.actors[101].velocity.x<=16.001)
    end)
    test('run qualification requires accepted supported travel and ends in the air',function()
        local _,_,_,m,step=fixture(8)
        m:move(101,1,0,true);assert(not m:isRunning(101));step(1/60)
        assert(m:isRunning(101));m:jump(101);assert(not m:isRunning(101))
    end)
    test('ice blocks move under a grounded push and keep their physical side boundary',function()
        local _,_,w,m,step=fixture(4)
        local b=m.blocks[1];local start=b.position.x
        m.actors[101].position={x=start-b.definition.w/2-2,y=b.position.y-b.definition.h/2+3,z=b.position.z}
        m.actors[101].grounded=true;w.points[101]=table.clone(m.actors[101].position)
        for _=1,30 do m:move(101,1,0,false);step(1/60) end
        assert(b.position.x>start)
        assert(w.points[101].x<=b.position.x-b.definition.w/2-1.59)
    end)
    test('ice block pushes carry every supported hero once regardless of cohort order',function()
        local failures={}
        for _,setup in ipairs({{pusher=101,cohort=2},{pusher=102,cohort=2},{pusher=102,cohort=3}}) do
            local ok,err=pcall(function()
                local _,s,w,m,step=fixture(4,41,setup.cohort)
                local block=m.blocks[1];local start=block.position.x;local riders={}
                for _,slot in ipairs(s.order) do
                    local a=m.actors[slot]
                    a.position={x=start,y=block.position.y+block.definition.h/2+3,z=block.position.z}
                    a.velocity={x=0,y=0,z=0};a.grounded=true;a.support=block.id
                    if slot==setup.pusher then
                        a.position.x=start-block.definition.w/2-1.6;a.position.y-=block.definition.h;a.support='floor-2'
                    else riders[#riders+1]=slot end
                    w.points[slot]=table.clone(a.position)
                end
                for _=1,80 do
                    m:move(setup.pusher,1,0,false);step(1/60)
                    local delta=block.position.x-start
                    for _,slot in ipairs(riders) do local a=m.actors[slot]
                        assert(math.abs(a.position.x-start-delta)<1e-7,
                            'pusher '..setup.pusher..' rider '..slot..' must receive accepted block movement once: block='..delta..', rider='..(a.position.x-start))
                        assert(a.grounded and a.support==block.id and a.position.y==block.position.y+block.definition.h/2+3,
                            'the moving block must retain its standing riders')
                        assert(math.abs(w.points[slot].x-a.position.x)<1e-7 and w.points[slot].y==a.position.y and w.points[slot].z==a.position.z,
                            'logical and published native rider poses must agree after every push')
                    end
                    assert(w.objects[block.id].position.x==block.position.x,'native block must publish the same accepted displacement')
                end
                assert(block.position.x>start,'ordinary grounded input must move the real ice block')
                assert(not s.deaths)
            end)
            if not ok then failures[#failures+1]=tostring(err) end
        end
        assert(#failures==0,table.concat(failures,'; '))
    end)
    test('ice blocks retain both solid depth faces across a long accepted frame',function()
        local failures={}
        for _,direction in ipairs({-1,1}) do
            local ok,err=pcall(function()
                local _,s,w,m,step=fixture(4,41)
                local block=m.blocks[1];local a=m.actors[101];local depth=block.definition.d/2+1.2
                a.position={x=block.position.x,y=block.position.y-block.definition.h/2+3,z=block.position.z-direction*(depth+.2)}
                a.velocity={x=0,y=0,z=direction*25};a.grounded=true;a.support='floor-2';w.points[101]=table.clone(a.position)
                local blockX,blockZ=block.position.x,block.position.z
                for _=1,4 do
                    m:move(101,0,direction,false);step(.5)
                    assert((a.position.z-blockZ)*direction<=-depth+1e-7,
                        'depth face '..direction..' must stop the actor: z='..a.position.z..', face='..(blockZ-direction*depth))
                    assert(w.points[101].z==a.position.z,'native pose must remain outside the same depth face')
                end
                assert(block.position.x==blockX and block.position.z==blockZ,'depth steering cannot push an authored X-only block')
                assert(not s.deaths)
            end)
            if not ok then failures[#failures+1]=tostring(err) end
        end
        assert(#failures==0,table.concat(failures,'; '))
    end)
    test('ice block X pushes stop at authored limits without carrying riders farther',function()
        for _,direction in ipairs({-1,1}) do
            local _,_,w,m,step=fixture(4,41,2)
            local block=m.blocks[1];local limit=direction==1 and block.definition.maxX or block.definition.minX
            block.position.x=limit-direction*.05
            local start=block.position.x;local rider=m.actors[101];local pusher=m.actors[102]
            rider.position={x=start,y=block.position.y+block.definition.h/2+3,z=block.position.z}
            rider.velocity={x=0,y=0,z=0};rider.grounded=true;rider.support=block.id
            pusher.position={x=start-direction*(block.definition.w/2+1.6),y=block.position.y-block.definition.h/2+3,z=block.position.z}
            pusher.velocity={x=0,y=0,z=0};pusher.grounded=true;pusher.support='floor-2'
            w.points[101]=table.clone(rider.position);w.points[102]=table.clone(pusher.position)
            for _=1,80 do m:move(102,direction,0,false);step(1/60) end
            assert(math.abs(block.position.x-limit)<1e-7,'X pushing must reach and respect the authored limit')
            assert(math.abs(rider.position.x-limit)<1e-7 and w.points[101].x==rider.position.x,
                'standing hero receives only the displacement accepted before the X limit')
            assert((pusher.position.x-block.position.x)*direction<=-block.definition.w/2-1.6+1e-7,
                'the limited block retains its physical X side boundary')
        end
    end)
    test('emergency unsafe-spawn hold is preserved until Session authorizes safe control',function()
        local _,s,w,m,step=fixture(2)
        local count=w.poses
        s.state.heroes[101].attempt=2;s.state.heroes[101].actorId='new-held-body'
        s.state.heroes[101].shield={kind='Emergency',deadline=5};w.points[101]={x=0,y=3,z=0}
        step(.1)
        assert(w.poses==count and w.points[101].y==3,'mode cannot release or relocate an emergency-held actor')
        s.state.heroes[101].shield={kind='Ordinary',deadline=5};step(.1)
        assert(w.poses>count and m.actors[101].actorId=='new-held-body')
    end)
    test('trio boarding and checkpoint replay keep distinct controlled bodies in separate lanes',function()
        local d,s,w,m,step=fixture(7,41,3)
        for _,slot in ipairs(s.order) do w.points[slot]=table.clone(d.course.mount);m:interact(slot,0,'Punch') end
        assert(w.points[101].z<w.points[102].z and w.points[102].z<w.points[103].z)
        local a,b=m:respawnPosition(101),m:respawnPosition(103)
        assert(a.z<b.z)
    end)
    test('shared chase actor starts physically behind the riders with the same measured gap',function()
        local _,_,_,m,step=fixture(11)
        local orb;m.chaseActor=function(p) orb=p end;step(1/60)
        assert(orb.x<-30 and orb.y==3 and orb.z==0)
    end)
    test('trailing clinger riders cannot collide with a phantom pursuer after its battle transition',function()
        local _,s,_,m,step=fixture(11)
        m.chaseFinished=true;m.chaseProgress=0;m:move(101,1,0,false);step(1/60)
        assert(not s.deaths)
    end)
    test('rotated tower support accepts visible tips and rejects invisible square corners',function()
        local _,_,w,m=fixture(12)
        local angle=math.pi/4;local cx,cz=math.cos(angle)*23,math.sin(angle)*23
        m.course.towerPlatforms={{angle=angle,radius=23,y=0,w=18,d=18}};m.rotation=0;m:_objects(0)
        local a=m.actors[101];a.velocity.y=-1
        a.position={x=cx+11,y=2.95,z=cz};m:_ground(a,{x=cx+11,y=3.1,z=cz},1/60)
        assert(a.grounded and a.position.y==3,'actual rotated visible tip must support the body')
        a.position={x=cx+8.5,y=2.95,z=cz+8.5};m:_ground(a,{x=cx+8.5,y=3.1,z=cz+8.5},1/60)
        assert(not a.grounded,'unrotated corner outside the rendered floor must not support the body')
        assert(math.abs(w.objects['tower-1'].metadata.yaw+angle)<1e-7)
    end)
    test('all four serpent rooms can be crossed with ordinary steering and timed jumps',function()
        for _,seed in ipairs({1,2,7,41,8125}) do
        local d,s,_,m,step=fixture(6,seed)
        local stage='Approach';local lastRoom=1;local count=0;local lastSupport='none'
        while not m.complete and not s.deaths and count<12000 do
            local a=m.actors[101];local room=m.room;local base=(room-1)*80
            if room~=lastRoom then stage='Approach';lastRoom=room end
            local spike=d.course.hazards[room];local safeZ=spike.z==0 and 4.6 or 0
            local dz=safeZ-a.position.z;local iz=math.abs(dz)>.3 and (dz>0 and 1 or -1) or 0
            local ix=0
            if stage=='Approach' then
                if math.abs(dz)>.3 then ix=0
                elseif a.position.x<base+9.2 then ix=1
                else stage='Wait' end
            elseif stage=='Wait' then
                for _,support in ipairs(m.supports) do
                    if support.definition.room==room and support.position.x<=base+22 and support.position.y<((room-1)*6)+2.6 then
                        m:move(101,1,0,false);m:jump(101);stage='Board';ix=1;break
                    end
                end
            elseif stage=='Board' then
                ix=1
                if a.grounded and a.support and string.sub(a.support,1,8)=='serpent-' then stage='Ride' end
            elseif stage=='Ride' then
                ix=1
                if a.grounded then lastSupport='x='..a.position.x..', y='..a.position.y..', support='..tostring(a.support) end
                if a.support=='serpent-'..room then for _,head in ipairs(m.supports) do
                    if head.id==a.support and head.position.x<base+48 and a.position.x>head.position.x+3 then ix=0 end
                end end
                if a.position.x>=base+53 and a.grounded then m:jump(101);stage='Exit' end
            elseif stage=='Exit' then ix=1 end
            m:move(101,ix,iz,false);step(1/60);count+=1
        end
        local a=m.actors[101]
        assert(m.complete and not s.deaths,'normal controls must reach all rooms: seed='..seed..', room='..m.room..', stage='..stage..', x='..a.position.x..', y='..a.position.y..', z='..a.position.z..', deaths='..tostring(s.deaths)..', count='..count..', last='..lastSupport)
        end
    end)
    test('tower core stops inward motion while outward steering can still leave support',function()
        local _,s,_,m,step=fixture(12)
        for _=1,120 do m:move(101,0,-1,false);step(1/60) end
        local a=m.actors[101];assert(math.sqrt(a.position.x^2+a.position.z^2)>=15.599)
        for _=1,720 do m:move(101,0,1,false);step(1/60);if s.deaths then break end end
        assert(s.deaths==1,'core collision cannot provide automatic safety at outer gaps')
    end)
    test('a vehicle collision stops and rewinds surviving bodies without changing their resources',function()
        local d,s,w,m,step=fixture(3,41,3)
        for _,slot in ipairs(s.order) do
            local hero=s.state.heroes[slot];hero.rawLife=31;hero.respawns=2
            w.points[slot]=table.clone(d.course.mount);assert(m:interact(slot,0,'Punch')=='OK')
        end
        local survivor=m.actors[102];local hero=s.state.heroes[102]
        local id,attempt,stock=hero.actorId,hero.attempt,hero.respawns
        m:move(102,1,1,false)
        local h=d.course.hazards[1];m.actors[101].position={x=h.x-2,y=h.y,z=h.z}
        step(1/60)
        assert(s.deaths==1 and m.vehicleGroup and m.vehicleGroup.phase=='Stopped')
        assert(survivor.velocity.x==0 and survivor.input.x==0 and survivor.input.z==0)
        local stopped=survivor.position.x;step(.1);assert(survivor.position.x==stopped)
        for _=1,60 do step(1/60) end
        assert(m.vehicleGroup.phase=='Riding' and m.vehicleGroup.serial==1)
        assert(survivor.position.x<d.course.hazards[1].x and survivor.actorId==id)
        assert(hero.actorId==id and hero.attempt==attempt and hero.respawns==stock and hero.rawLife==31)
        assert(s.state.heroes[101].status=='AwaitingRespawn','mode must not revive the collided body')
        assert(m:snapshot().camera.rewindSerial==1)
    end)
    test('shared vehicle checkpoint is used by every survivor and a fully dead cohort never auto retries',function()
        local d,s,w,m,step=fixture(3,41,2)
        d.course.hazards={}
        for _,slot in ipairs(s.order) do w.points[slot]=table.clone(d.course.mount);m:interact(slot,0,'Punch') end
        local cp=d.course.checkpoints[2]
        m.actors[101].progress=cp.progress;m:_checkpoint(m.actors[101])
        assert(m.actors[102].checkpoint==2 and m:respawnPosition(102).x==cp.position.x)
        m:_die(m.actors[101],'CampaignCrash');assert(m.vehicleGroup.phase=='Stopped')
        m:_die(m.actors[102],'CampaignCrash')
        s.state.heroes[101].status='Eliminated';s.state.heroes[102].status='Eliminated'
        for _=1,80 do step(1/60) end
        assert(m.vehicleGroup.phase=='Lost' and s.deaths==2 and not m.complete)
    end)
    test('ride encounter fires once after progress and has no entry patrol rat',function()
        local d,_,w,m,step=fixture(3)
        for _,foe in ipairs(d.zones[1].enemies) do assert(foe.kind~='RocketRat') end
        assert(d.course.encounters and #d.course.encounters>0)
        local events={};m.spawnEncounter=function(event) events[#events+1]=event;return true end
        w.points[101]=table.clone(d.course.mount);m:interact(101,0,'Punch')
        local event=d.course.encounters[1];m.actors[101].progress=event.progress-1
        m:_encounters();assert(#events==0)
        m.actors[101].progress=event.progress;m:_encounters();m:_encounters()
        assert(#events==1 and events[1].kind=='RocketRat' and events[1].trajectory and events[1].allowedDrop)
    end)
    test('tube water currents apply physical velocity without supplying steering input',function()
        local d,_,w,m,step=fixture(9)
        local water=d.course.media[1];assert(water.current and water.current.x~=0)
        m.actors[101].position={x=water.minX+8,y=-6,z=0};w.points[101]=table.clone(m.actors[101].position)
        m:move(101,0,0,false);step(.1)
        assert(m.actors[101].velocity.x*water.current.x>0 and m.actors[101].input.x==0)
    end)
    test('moving ice walls physically stop a crossing while shuttle supports carry the actual body',function()
        local _,_,w,m,step=fixture(4)
        local wall=m.walls[1];local actor=m.actors[101]
        local old={x=wall.x-wall.w/2-2,y=wall.y,z=wall.z}
        actor.position={x=wall.x,y=wall.y,z=wall.z};actor.velocity={x=20,y=0,z=0}
        m:_wallCollision(actor,old)
        assert(actor.position.x<wall.x-wall.w/2 and actor.velocity.x==0)
        local shuttle=m.supports[1]
        actor.position={x=shuttle.position.x,y=shuttle.position.y+shuttle.definition.h/2+3,z=shuttle.position.z}
        actor.grounded=true;actor.support=shuttle.id;local z=actor.position.z
        step(1/60)
        assert(w.points[101].z~=z and w.objects[wall.id].metadata.collidable)
    end)
    test('vehicle stop consumes fresh input and checkpoint replay triggers only eligible scripted encounters',function()
        local d,_,w,m,step=fixture(3,41,2)
        for _,slot in ipairs({101,102}) do w.points[slot]=table.clone(d.course.mount);m:interact(slot,0,'Punch') end
        local events=0;local reset;m.spawnEncounter=function() events+=1 end;m.resetEncounters=function(value) reset=value end
        local event=d.course.encounters[1];m.actors[101].progress=event.progress;m:_encounters();assert(events==1)
        m:_die(m.actors[101],'CampaignCrash');assert(reset and reset.replayIds[1]==event.id)
        local a=m.actors[102];m:move(102,1,1,true);m:jump(102)
        assert(a.input.x==0 and a.input.z==0 and a.velocity.y==0)
        assert(m:impulse(102,{x=40,y=30,z=20}) and a.velocity.y==0 and not a.external)
        m:_encounters();assert(events==1)
        for _=1,60 do step(1/60) end
        a.progress=event.progress;m:_encounters();assert(events==2)
        a.progress=d.course.checkpoints[2].progress;m:_checkpoint(a)
        m:_die(a,'CampaignCrash');assert(reset and #reset.replayIds==0)
    end)
    test('rope kick delegates actual enemy damage through the director callback',function()
        local _,_,_,m=fixture(2);local calls=0
        m.ropeKick=function(slot,now) assert(slot==101 and now==0);calls+=1;return 'OK' end
        assert(m:interact(101,0,'Punch')=='OK' and calls==1)
        assert(m:interact(101,0,'Punch')=='COOLDOWN' and calls==1)
    end)
    test('an emergency-held last rider waits safely and resumes after release without a new life',function()
        local d,s,w,m,step=fixture(3,41,2)
        d.course.hazards={}
        for _,slot in ipairs(s.order) do w.points[slot]=table.clone(d.course.mount);m:interact(slot,0,'Punch') end
        local held=s.state.heroes[102];local actor,attempt,stock=held.actorId,held.attempt,held.respawns
        held.shield={kind='Emergency',deadline=20};w.points[102]={x=7,y=35,z=6}
        m:_die(m.actors[101],'CampaignCrash');s.state.heroes[101].status='Eliminated'
        local poses=w.poses
        for _=1,30 do step(1/60) end
        assert(m.vehicleGroup.phase=='AwaitingRespawn','an alive held hero keeps the cohort pending')
        assert(w.poses==poses and w.points[102].x==7 and w.points[102].y==35,'active emergency hold cannot be relocated')
        held.shield={kind='Ordinary',deadline=20}
        for _=1,80 do step(1/60) end
        assert(m.vehicleGroup.phase=='Riding' and m.vehicleGroup.speed>0)
        assert(held.actorId==actor and held.attempt==attempt and held.respawns==stock and not m.complete)
        assert(s.state.heroes[101].status=='Eliminated' and s.deaths==1)
    end)
    test('Session-owned mounted death starts one group rewind even when a new attempt already exists',function()
        local d,s,w,m,step=fixture(3,41,2)
        d.course.hazards={}
        for _,slot in ipairs(s.order) do w.points[slot]=table.clone(d.course.mount);m:interact(slot,0,'Punch') end
        for _,slot in ipairs(s.order) do m.actors[slot].position.x=100 end
        m:move(102,1,1,true)
        -- Model Session's synchronous death and next accepted paid spawn before
        -- the mode's next observation. The mode must not charge/kill it again.
        s:_die(101,'EngineDeath');s.state.heroes[101].status='Alive'
        s.state.heroes[101].actorId='respawn-from-session';s.state.heroes[101].attempt=2;s.state.heroes[101].respawns=2
        w.points[101]=m:respawnPosition(101)
        step(1/60)
        assert(m.vehicleGroup.phase=='Stopped' and m.vehicleGroup.serial==1)
        assert(m.actors[102].input.x==0 and m.actors[102].velocity.x==0)
        for _=1,80 do step(1/60) end
        assert(m.vehicleGroup.phase=='Riding' and m.vehicleGroup.serial==1 and s.deaths==1)
        assert(s.state.heroes[101].attempt==2 and s.state.heroes[101].respawns==2)
        assert(s.state.heroes[102].attempt==1 and s.state.heroes[102].respawns==3)
    end)
    print('CampaignModes: '..passed..' passed')
end
