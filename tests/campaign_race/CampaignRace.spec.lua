return function(Race,Definition,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function test(name,fn)
        local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed+=1;print('PASS '..name)
    end
    local function point(x,y,z) return {x=x,y=y,z=z or 0} end
    local function flat()
        return {mode='Race',spawn=point(-20,3,10),bounds={minX=-80,maxX=100,minY=-40,maxY=70,minZ=-30,maxZ=30},
            course={gravity=150,ratSpeed=9,ratIntroSeconds=0,ratJumpSpeed=29,ratStunSeconds=.55,
                platforms={{x=0,y=-1,z=0,w=160,h=2,d=40}},
                bombs={{id='bomb-1',position=point(30,3),ratStart=point(-20,3),radius=7,deadline=.1}}}}
    end
    local function fixture(def,count,at)
        def=def or flat();local world=FakeWorld.new();world.points={};world.enemySpawns=0;world.enemyIdentities={};world.objects={}
        function world:position(id) return self.points[id] end
        function world:findSafe() return {position=at or def.spawn} end
        local spawn=world.spawn
        function world:spawn(id,actorId,p,held)
            local ok=spawn(self,id,actorId,p,held);if ok then self.points[id]=table.clone(p.position) end;return ok
        end
        function world:spawnEnemy(id,kind,p)
            assert(id>-1000 and id<0);self.enemySpawns+=1;self.actors[id]={id=id,kind=kind,alive=true};self.points[id]=table.clone(p);return true
        end
        function world:enemyIdentity(id,actorId) self.enemyIdentities[id]=actorId end
        function world:campaignPose(id,p) self.points[id]=table.clone(p) end
        function world:campaignRelease(id) self.released=id end
        function world:campaignObject(id,kind,p,size,metadata) self.objects[id]={kind=kind,position=table.clone(p),metadata=metadata} end
        function world:campaignRemove(id) self.objects[id]=nil end
        local roster={};for id=1,count or 1 do roster[id]={userId=id,template='Mr. Green'} end
        local session=Session.new(Core,Combat,Config,roster,'real-race-session',world,nil,{levelId='race'});session:step(0)
        local race=Race.new(session,world,def);local now=0
        local function step(dt)
            now+=dt;session:step(now);race:step(now,dt)
        end
        return race,session,world,step,def
    end
    local function packet(race,session,kind,extra)
        local role=race:controlled(501)
        local p={kind=kind,runId=session.state.runId,actorId=role.actorId,attempt=1,levelEpoch=session.state.levelEpoch,
            connectionEpoch=role.connectionEpoch,seq=1}
        for k,v in pairs(extra or {}) do p[k]=v end;return p
    end
    test('a real rival actor is claimable before its first movement without spawning or inventing health',function()
        local d=flat();d.course.ratIntroSeconds=2;local race,session,w,step=fixture(d)
        assert(w.actors[race.enemyId] and w.actors[race.enemyId].kind=='RacingRat' and w.enemySpawns==1)
        assert(not w.objects['race-rat'] and #race:available(501)==1)
        local actor=w.enemyIdentities[race.enemyId];local p=table.clone(w.points[race.enemyId])
        assert(race:claim(501,race.enemyId)=='OK' and w.enemySpawns==1 and w.enemyIdentities[race.enemyId]==actor)
        assert(w.points[race.enemyId].x==p.x and w.points[race.enemyId].y==p.y)
        local role=race:controlled(501);assert(role.resourceKind=='CourseRival' and role.hearts==0 and role.maxHearts==0)
        assert(role.actorId==actor and role.attempt==1 and not race.completeBombs and session.state.heroes[1].respawns==3)
        step(.1);assert(not race.enemy.engaged)
    end)
    test('elapsed deadlines cannot decide an obstructed physical race or award victory',function()
        local d=flat();d.course.raceObstacles={{id='wall',x=0,y=9,z=0,w=2,h=20,d=40}}
        local race,s,w,step=fixture(d)
        for _=1,150 do step(.1) end
        assert(w.points[race.enemyId].x<=-2.29 and not race.failed and not race.completeBombs)
        assert(s.state.heroes[1].status=='Alive' and s.state.heroes[1].respawns==3)
        assert(race:claim(501,race.enemyId)=='ENEMY_ENGAGED')
    end)
    test('rat body contact explodes the bomb through Session death without spending a respawn early',function()
        local race,s,w,step=fixture(nil,3)
        for _=1,200 do step(.05);if race.failed then break end end
        assert(race.failed and race.bombIndex==1 and not race.completeBombs)
        assert(w.points[race.enemyId].x>=26,'contact must be reached by real motion')
        for _,id in ipairs(s.order) do
            assert(s.state.heroes[id].status=='AwaitingRespawn' and s.state.heroes[id].respawns==3 and s.combat[id].rawLife==0)
        end
        local deaths=0;for _,row in ipairs(s.logs) do if row.kind=='ConfirmedDeath' then deaths+=1;assert(row.data.reason=='CampaignRatWon') end end
        assert(deaths==3 and w.enemySpawns==1)
    end)
    test('fresh nearby actions defuse only the current bomb and cannot finish by waiting',function()
        local d=flat();d.course.bombs[2]={id='bomb-2',position=point(60,3),ratStart=point(40,3),radius=7,deadline=.1}
        local race,s,w,step=fixture(d,1,point(30,3))
        assert(race:interact(1,0,'Dash')=='NO_INTERACTION')
        assert(race:interact(1,0,'Punch')=='OK' and race.bombIndex==2 and not race.completeBombs)
        assert(race:interact(1,0,'Punch')=='NO_INTERACTION' and race.bombIndex==2)
        assert(w.objects['bomb-1'].metadata.role=='Defused' and s.state.heroes[1].respawns==3)
        assert(not race:interaction(1).available)
        step(.05);assert(not race.completeBombs)
    end)
    test('a nonlethal hit interrupts the real rival motor and recovery retains identity and ownership',function()
        local d=flat();d.course.ratIntroSeconds=0
        local race,s,w,step=fixture(d,1,point(-24,3))
        assert(race:claim(501,race.enemyId)=='OK');local role=race:controlled(501)
        assert(race:command(501,packet(race,s,'Move',{x=1,z=0}),0,Session.validIntent)=='OK')
        step(.1);local before=w.points[race.enemyId].x
        assert(race:hit(1,race.enemyId,'Punch',{reaction=.5,responses={[0]={horizontal=8,vertical=0,profile=0}},impulseDirection={x=-1,z=0}}))
        step(.1);assert(w.points[race.enemyId].x<before and race:controlled(501).actorId==role.actorId)
        assert(race:command(501,packet(race,s,'Move',{x=1,z=0,seq=2}),s.now,Session.validIntent)=='REACTION')
        for _=1,10 do step(.1) end
        assert(not race.enemy.dead and not race:controlled(501).dying and race:controlled(501).hearts==0)
        assert(race:command(501,packet(race,s,'Move',{x=1,z=0,seq=3}),s.now,Session.validIntent)=='OK')
    end)
    test('offline ownership never enables NPC steering and stale connection commands cannot move the body',function()
        local race,s,w,step=fixture()
        assert(race:claim(501,race.enemyId)=='OK');local old=packet(race,s,'Move',{x=1,z=0})
        assert(race:command(501,old,0,Session.validIntent)=='OK');step(.1)
        assert(race:connection(501,false)=='OK');local x=w.points[race.enemyId].x
        for _=1,15 do step(.1) end
        assert(math.abs(w.points[race.enemyId].x-x)<.001 and not race.failed)
        assert(race:command(501,old,s.now,Session.validIntent)=='OFFLINE')
        assert(race:connection(501,true)=='OK')
        assert(race:command(501,old,s.now,Session.validIntent)=='STALE_CONNECTION')
        assert(race:claim(502,race.enemyId)=='ENEMY_OCCUPIED' and w.enemySpawns==1)
    end)
    test('targeting the rival permanently closes its transfer window even when the attack misses',function()
        local d=flat();d.course.ratIntroSeconds=3;local race=fixture(d)
        race:closeTargetForAttack({race.enemyId})
        assert(#race:available(501)==0 and race:claim(501,race.enemyId)=='ENEMY_ENGAGED')
    end)
    test('an NPC hit can stun the rival without taking its still open human role',function()
        local d=flat();d.course.ratIntroSeconds=3;local race,_,w=fixture(d)
        assert(race:hit(-1,race.enemyId,'Punch'))
        assert(not race.enemy.engaged and #race:available(501)==1)
        local p=table.clone(w.points[race.enemyId]);assert(race:claim(501,race.enemyId)=='OK')
        assert(w.points[race.enemyId].x==p.x and race.stunnedUntil and w.enemySpawns==1)
    end)
    test('the initial claim window does not suspend an already accepted physical hit',function()
        local d=flat();d.course.ratIntroSeconds=3;local race,_,w,step=fixture(d)
        local x=w.points[race.enemyId].x
        assert(race:hit(-1,race.enemyId,'Punch',{reaction=.5,responses={[0]={horizontal=8,vertical=0,profile=0}},impulseDirection={x=-1,z=0}}))
        step(.1)
        assert(w.points[race.enemyId].x<x and not race.enemy.engaged,'a physical hit must continue during initial role selection')
    end)
    test('untrusted racer packets cannot teleport or bypass an old actor and sequence',function()
        local race,s,w,step=fixture();assert(race:claim(501,race.enemyId)=='OK')
        local old=packet(race,s,'Move',{x=1,z=0,actorId='old-rival',seq=900})
        assert(race:command(501,old,0,Session.validIntent)=='STALE_ACTOR')
        local p=packet(race,s,'Move',{x=1,z=0,position=point(30,3)})
        assert(race:command(501,p,0,Session.validIntent)=='INVALID_INTENT')
        p=packet(race,s,'Move',{x=1,z=0});assert(race:command(501,p,0,Session.validIntent)=='OK')
        assert(race:command(501,p,0,Session.validIntent)=='STALE_SEQUENCE')
        step(.1);assert(w.points[race.enemyId].x<0 and not race.failed and w.enemySpawns==1)
    end)
    test('an airborne rival above the bomb cannot explode it through a flat distance check',function()
        local d=flat();d.course.bombs[1].ratStart=point(30,30)
        d.course.platforms[2]={x=30,y=26,z=0,w=12,h=2,d=12}
        local race,s,w,step=fixture(d)
        assert(race:claim(501,race.enemyId)=='OK')
        for _=1,80 do step(.1) end
        assert(not race.failed and not race.completeBombs and w.points[race.enemyId].y>20)
        assert(s.state.heroes[1].status=='Alive')
    end)
    test('physical retry waits for a newly committed Session attempt and spends only that attempt',function()
        local race,s,w,step=fixture()
        for _=1,200 do step(.05);if race.failed then break end end
        local actor=race.enemy.actorId;assert(race.failed and s.state.heroes[1].attempt==1)
        step(.05)
        assert(not race.failed and race.elapsed<.1 and s.state.heroes[1].attempt==2 and s.state.heroes[1].respawns==2)
        assert(race.enemy.actorId==actor and w.enemySpawns==1 and w.points[race.enemyId].x<0)
    end)
    test('a bomb loss during an existing death accepts only the later committed hero attempt',function()
        for _,cause in ipairs({'Pending','Dying'}) do
            local race,s,w,step=fixture(nil,1,point(30,3))
            for _=1,800 do if race.position.x>26.8 then break end;step(.01) end
            assert(not race.failed and race.position.x>26.8)
            local actor=race.enemy.actorId
            if cause=='Pending' then w.hazards[1]='ActorMissing'
            else assert(s:_hit(-1,1,'HeroPowerPunch',{reaction=.4,deathDelay=.1})) end
            step(.05)
            assert(race.failed and s.state.heroes[1].attempt==1 and s.state.heroes[1].respawns==3)
            if cause=='Dying' then
                assert(s.combat[1].deathAt and s.state.heroes[1].status=='Alive')
                step(.05)
                assert(race.failed and s.state.heroes[1].status=='AwaitingRespawn','a pending death cannot authorize a retry')
            end
            step(.05)
            local hero=s.state.heroes[1]
            assert(not race.failed and hero.status=='Alive' and hero.attempt==2 and hero.respawns==2,
                cause..' death must accept the already authorized committed respawn')
            assert(s.combat[1].rawLife==47 and race.enemy.actorId==actor and w.enemySpawns==1)
            assert(race:interact(1,s.now,'Punch')=='OK' and race.completeBombs,
                'the paid retry must restore the nearby bomb action')
        end
    end)
    test('an already pending offline hero cannot restart a failed race or spend a reserve',function()
        local race,s,w,step=fixture()
        for _=1,800 do if race.position.x>26.8 then break end;step(.01) end
        assert(s:connection(1,false,s.now)=='OK');w.hazards[1]='ActorMissing';step(.05)
        assert(race.failed and s.state.heroes[1].status=='AwaitingRespawn')
        for _=1,20 do step(.05) end
        local hero=s.state.heroes[1]
        assert(race.failed and hero.attempt==1 and hero.respawns==3 and hero.status=='AwaitingRespawn')
        assert(w.spawns==1 and w.enemySpawns==1 and race:interact(1,s.now,'Punch')=='NO_INTERACTION')
    end)
    test('an exhausted fixed cohort cannot create another race retry',function()
        local d=flat();d.course.ratIntroSeconds=20
        local race,s,w,step=fixture(d)
        for spent=1,3 do
            w.hazards[1]='ActorMissing';step(.05);step(.05)
            assert(s.state.heroes[1].attempt==spent+1 and s.state.heroes[1].respawns==3-spent)
        end
        w.hazards[1]='ActorMissing';step(.05)
        assert(s.state.status=='Lost' and s.state.heroes[1].status=='Eliminated' and race.closed)
        for _=1,10 do step(.1) end
        assert(s.state.heroes[1].attempt==4 and s.state.heroes[1].respawns==0 and w.spawns==4 and w.enemySpawns==1)
    end)
    test('a trio retry never spends an offline fallen owners reserve or creates a replacement',function()
        local race,s,w,step=fixture(nil,3)
        assert(s:connection(2,false,0)=='OK')
        for _=1,200 do step(.05);if race.failed then break end end
        assert(race.failed and s.state.heroes[2].status=='AwaitingRespawn')
        step(.05)
        assert(not race.failed and s.state.heroes[1].attempt==2 and s.state.heroes[3].attempt==2)
        assert(s.state.heroes[2].attempt==1 and s.state.heroes[2].respawns==3 and s.state.heroes[2].status=='AwaitingRespawn')
        assert(w.spawns==5 and w.enemySpawns==1 and #s.order==3)
    end)
    test('a claimed rival has a supported jump and never gains an airborne double jump',function()
        local race,s,w,step=fixture();assert(race:claim(501,race.enemyId)=='OK')
        assert(race:command(501,packet(race,s,'Jump'),0,Session.validIntent)=='OK');step(1/60)
        local y=w.points[race.enemyId].y;assert(y>3)
        assert(race:command(501,packet(race,s,'Jump',{seq=2}),s.now,Session.validIntent)=='NO_JUMP')
        assert(race:command(501,packet(race,s,'Attack',{attack='Punch',seq=3}),s.now,Session.validIntent)=='NO_ACTION')
    end)
    test('authored descending courses require support and real rat travel before bomb contact',function()
        for _,seed in ipairs({1,2,41,8125}) do
            for round=1,3 do
            local d=Definition.build(10,seed);d.course.ratIntroSeconds=0
            -- Select a round before construction; the motor still traverses its
            -- complete original physical floors, without test position writes.
            d.course.bombs={d.course.bombs[round]}
            local race,s,w,step=fixture(d);local start=table.clone(w.points[race.enemyId]);local airborne=false
            for _=1,3000 do step(1/60);if not race.grounded then airborne=true end;if race.failed then break end end
            local p=w.points[race.enemyId]
            assert(race.failed and airborne and p.y<start.y and math.abs(p.y-d.course.bombs[1].position.y)<4,
                'seed='..seed..', round='..round..', x='..p.x..', y='..p.y..', support='..tostring(race.support))
            assert(s.state.heroes[1].status=='AwaitingRespawn')
            end
        end
    end)
    test('close and an old level epoch prevent retained commands, movement and bomb effects',function()
        local race,s,w,step=fixture();assert(race:claim(501,race.enemyId)=='OK')
        local p=packet(race,s,'Move',{x=1,z=0});s.state.levelEpoch+=1;step(.1)
        local x=w.points[race.enemyId].x;assert(race.closed and race:command(501,p,s.now,Session.validIntent)=='RUN_CLOSED')
        step(2);assert(w.points[race.enemyId].x==x and not race.failed and w.actors[race.enemyId].alive==false)
        race:close('Again');assert(w.enemySpawns==1)
    end)
    print('CampaignRace: '..passed..' passed')
end
