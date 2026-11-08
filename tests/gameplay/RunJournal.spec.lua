return function(Journal,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function journal(capacity) return Journal.new({runId='r',groupId='g',build='sha',rules='D01-D10-v1'},capacity) end
    local function row(kind,now,data) return {kind=kind,now=now,runId='r',groupId='g',levelEpoch=1,userId=1,
        actorId='a',attempt=1,respawns=3,rawLife=47,data=data or {}} end
    test('bounded journal overwrites oldest rows and preserves exact context and event order',function()
        local j=journal(3)
        for i=1,5 do assert(j:record(row('Hit',i,{action='HeroJab',attacker=2,profile=18}))) end
        local s=j:snapshot();assert(s.schema==1 and s.build=='sha' and s.rules=='D01-D10-v1')
        assert(s.runId=='r' and s.groupId=='g' and s.dropped==2 and #s.events==3)
        assert(s.events[1].seq==3 and s.events[3].seq==5 and s.events[3].respawns==3)
    end)
    test('external mutation and duplicate event receipt cannot alter retained evidence',function()
        local j=journal();local r=row('CommitSpawn',1,{eventId='s-1',code='OK',nested={value=1}})
        assert(j:record(r));r.data.nested.value=99
        assert(not j:record(row('CommitSpawn',2,{eventId='s-1',code='OK'})))
        local s=j:snapshot();assert(#s.events==1 and s.events[1].data.nested.value==1)
        s.events[1].data.nested.value=12;assert(j:snapshot().events[1].data.nested.value==1)
    end)
    test('malformed rows foreign identity and unbounded nested data stay bounded and JSON-safe',function()
        local j=journal();assert(not j:record(row('Hit',0/0)))
        assert(not j:record(row('Hit',1,true)))
        local wrong=row('Hit',1);wrong.runId='other';assert(not j:record(wrong))
        local deep={};deep.self=deep;deep.bad=math.huge;deep.text=string.rep('Ж',200)
        for i=1,1000 do deep['k'..i]={nested={also={value='x'}}} end
        assert(j:record(row('Hit',2,deep)))
        local function count(t)
            local n=0
            for _,v in pairs(t) do n+=1;if type(v)=='table' then n+=count(v)
                elseif type(v)=='string' then assert(#v<=160 and utf8.len(v)~=nil)
                elseif type(v)=='number' then assert(v==v and v~=math.huge) end end
            return n
        end
        assert(count(j:snapshot().events[1].data)<=64)
    end)
    test('client projection is allowlisted bounded and excludes private diagnostic data',function()
        local j=journal()
        for i=1,20 do j:record(row('Hit',i,{attacker=2,action='HeroJab',blocked=false,privateToken='hidden',
            observed={position={1,2,3}}})) end
        j:record(row('Connection',21,{code='OK'}))
        local feed=j:feedback();assert(feed.latestSeq==21 and #feed.events==12)
        for _,e in ipairs(feed.events) do assert(e.kind=='Hit' and e.data==nil and e.privateToken==nil and e.observed==nil) end
        feed.events[1].kind='changed';assert(j:feedback().events[1].kind=='Hit')
    end)
    test('diagnostic logger failures cannot abort successful spawn damage or later simulation',function()
        local w=FakeWorld.new()
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'r',w,
            function() error('controlled sink failure') end)
        assert(s:step(0)=='OK' and s.state.heroes[1].status=='Alive')
        assert(s:_hit(2,1,'Punch') and s.combat[1].rawLife==43)
        assert(s:step(1)=='OK' and s.combat[1].rawLife==47 and s.loggerFailures>0)
    end)
    test('late timestamps remain visible while seq orders the observation stream',function()
        local j=journal();assert(j:record(row('Hit',2)));assert(j:record(row('EnemyHit',1)))
        local s=j:snapshot();assert(s.events[2].seq==2 and s.events[2].now==1 and s.events[2].late==true)
    end)
    test('actual respawn records retain shield kind deadline resource and connection state',function()
        local j=journal();local w=FakeWorld.new()
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'}},'r',w,
            function(row) assert(j:record(row)) end,{groupId='g'})
        s:step(0);local actor=s.state.heroes[1].actorId;s:_die(1,'fixture');w.safe=false;s:step(.1)
        local death
        local spawn
        for _,event in ipairs(j:snapshot().events) do
            if event.kind=='CommitSpawn' and event.attempt==2 then spawn=event end
            if event.kind=='ConfirmedDeath' then death=event end
        end
        assert(spawn and spawn.shieldKind=='Emergency' and spawn.shieldUntil==10.1 and spawn.respawns==2
            and spawn.status=='Alive' and spawn.connected==true)
        assert(death and death.actorId==actor and death.data.observed.actor==actor)
    end)
    test('Dragon confirmations project bounded public feedback without private owner data',function()
        local j=journal()
        for i,kind in ipairs({'DragonMounted','DragonCaptured','DragonReleased','DragonFireHit'}) do
            assert(j:record(row(kind,i,{enemyId=-9,ownerUserId=123456})))
        end
        local f=j:feedback();assert(#f.events==4 and f.events[1].kind=='DragonMounted')
        assert(f.events[1].ownerUserId==nil and f.events[1].enemyId==nil)
    end)
    print('RunJournal: '..passed..' PASS')
end
