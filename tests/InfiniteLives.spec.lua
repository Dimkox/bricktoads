-- Trusted infinite-respawn contracts; this suite does not simulate Roblox physics.
return function(Core, Combat, Session, Config, World)
    local passed, failed, serial = 0, 0, 0
    local function eq(actual, expected)
        assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
    local function test(name, body)
        local ok, problem = pcall(body)
        if ok then passed += 1; print("PASS infinite lives: " .. name)
        else failed += 1; print("FAIL infinite lives: " .. name .. ": " .. tostring(problem)) end
    end
    local function domain(count)
        local roster = {}
        for uid = 1, count or 1 do roster[uid] = {userId=uid,template="Mr. Green"} end
        return Core.new("infinite-domain", "test", roster, "first")
    end
    local function event(state, kind, fields)
        serial += 1
        local e = {id="infinite-"..serial,runId=state.runId,expectedRevision=state.revision,
            now=state.time,kind=kind}
        for key, value in pairs(fields) do e[key]=value end
        return e
    end
    local function send(state, kind, fields, expected)
        local nextState, code, ack = Core.apply(state, event(state, kind, fields))
        eq(code, expected or "OK")
        if code ~= "OK" and code ~= "REPLAY" then eq(nextState,state) end
        return nextState, ack
    end
    local function identity(state, uid, fields)
        local hero=state.heroes[uid]
        local out={userId=uid,actorId=hero.actorId,attempt=hero.attempt,levelEpoch=state.levelEpoch}
        for key,value in pairs(fields or {}) do out[key]=value end
        return out
    end
    local function spawn(state, uid, safe)
        state=send(state,"ReserveSpawn",{userId=uid,connectionEpoch=state.heroes[uid].connectionEpoch})
        serial += 1
        return send(state,"CommitSpawn",{userId=uid,token=state.heroes[uid].pending.token,
            actorId="infinite-actor-"..serial,safe=safe~=false})
    end
    local function death(state, uid)
        return send(state,"Death",identity(state,uid))
    end
    local function toggle(state, uid, enabled)
        return send(state,"SetInfiniteLives",{userId=uid,enabled=enabled})
    end
    local function spent(state, uid)
        for _=1,3 do state=spawn(death(state,uid),uid) end
        eq(state.heroes[uid].respawns,0)
        return state
    end
    local function session(enabled, count)
        local cfg=table.clone(Config)
        cfg.Development={allowInfiniteLives=enabled==true}
        cfg.MaxLogEntries=1000
        local roster={}
        for uid=1,count or 1 do roster[uid]={userId=uid,template="Mr. Green"} end
        local world=World.new()
        local s=Session.new(Core,Combat,cfg,roster,"infinite-session",world)
        eq(s:step(0),"OK")
        return s,world
    end
    local function fall(s, world)
        world.hazards[1]="Fall"
        eq(s:step(s.now+.1),"OK")
        eq(s.combat[1].rawLife,0)
        if s.state.status=="Active" then eq(s:step(s.now+.1),"OK") end
    end
    local function countLogs(s,kind)
        local count=0
        for _,row in ipairs(s.logs) do if row.kind==kind then count+=1 end end
        return count
    end

    test("default is finite for every hero",function()
        local state=domain(3)
        for uid=1,3 do eq(state.heroes[uid].infiniteLives,false) end
        local s=session(true)
        eq(s:snapshot().infiniteLives,false)
        eq(s:snapshot().heroes[1].infiniteLives,false)
    end)
    test("trusted option is strictly boolean and cannot smuggle client fields",function()
        local state=domain()
        for _,value in ipairs({0,1,"true"}) do
            state=send(state,"SetInfiniteLives",{userId=1,enabled=value},"INVALID_EVENT")
        end
        state=send(state,"SetInfiniteLives",{userId=1},"INVALID_EVENT")
        state=send(state,"SetInfiniteLives",{userId=1,enabled=true,respawns=99},"UNKNOWN_FIELD")
    end)
    test("trusted toggle is per hero and receipt replay is inert",function()
        local state=domain(2)
        local e=event(state,"SetInfiniteLives",{userId=1,enabled=true})
        local nextState,code=Core.apply(state,e);eq(code,"OK")
        eq(nextState.heroes[1].infiniteLives,true);eq(nextState.heroes[2].infiniteLives,false)
        local replay,replayCode=Core.apply(nextState,e);eq(replayCode,"REPLAY");eq(replay,nextState)
        state=nextState
        state=send(state,"SetInfiniteLives",{userId=1,enabled=true},"NO_CHANGE")
    end)
    test("six deaths retain finite reserve, unique actors, attempts and shields",function()
        local state=toggle(spawn(domain(),1),1,true)
        local actors={[state.heroes[1].actorId]=true}
        for i=1,6 do
            state=death(state,1);eq(state.heroes[1].status,"AwaitingRespawn")
            state=spawn(state,1)
            local hero=state.heroes[1]
            eq(hero.respawns,3);eq(hero.attempt,i+1);eq(hero.health,5)
            eq(hero.shield.kind,"Normal");eq(hero.shield.deadline,state.time+2)
            eq(actors[hero.actorId],nil);actors[hero.actorId]=true
        end
    end)
    test("zero finite reserve still permits normal infinite respawns",function()
        local state=toggle(spent(spawn(domain(),1),1),1,true)
        for _=1,5 do state=spawn(death(state,1),1);eq(state.heroes[1].respawns,0) end
        eq(state.heroes[1].attempt,9);eq(state.status,"Active")
    end)
    test("zero reserve emergency retries retain ordinary deadlines and new identities",function()
        local state=toggle(spent(spawn(domain(),1),1),1,true)
        state=spawn(death(state,1),1,false)
        for _=1,5 do
            local old=state.heroes[1].actorId
            local deadline=state.heroes[1].shield.deadline
            state=send(state,"ExpireShield",identity(state,1,{now=deadline}))
            eq(state.heroes[1].retryReady,true)
            state=spawn(state,1,false)
            eq(state.heroes[1].respawns,0);assert(state.heroes[1].actorId~=old)
            eq(state.heroes[1].shield.kind,"Emergency")
            eq(state.heroes[1].shield.deadline,deadline+10)
        end
    end)
    test("turning off preserves unspent reserves and normal finite defeat",function()
        local state=spawn(death(spawn(domain(),1),1),1)
        eq(state.heroes[1].respawns,2)
        state=toggle(state,1,true)
        for _=1,5 do state=spawn(death(state,1),1) end
        state=toggle(state,1,false);eq(state.heroes[1].respawns,2)
        for remaining=1,0,-1 do state=spawn(death(state,1),1);eq(state.heroes[1].respawns,remaining) end
        state=death(state,1);eq(state.status,"Lost");eq(state.heroes[1].status,"Eliminated")
    end)
    test("turning off a zero reserve living hero neither heals nor kills it",function()
        local state=toggle(spent(spawn(domain(),1),1),1,true)
        state=send(state,"ExpireShield",identity(state,1,{now=state.heroes[1].shield.deadline}))
        state=send(state,"SetHealth",identity(state,1,{health=2}))
        local actor=state.heroes[1].actorId
        state=toggle(state,1,false)
        eq(state.heroes[1].status,"Alive");eq(state.heroes[1].actorId,actor);eq(state.heroes[1].health,2)
        state=death(state,1);eq(state.status,"Lost")
    end)
    test("turning off a zero reserve dead hero settles defeat instead of a ghost",function()
        local state=toggle(spent(spawn(domain(),1),1),1,true)
        state=death(state,1)
        state=send(state,"ReserveSpawn",{userId=1,connectionEpoch=1})
        local token=state.heroes[1].pending.token
        state=toggle(state,1,false)
        eq(state.status,"Lost");eq(state.heroes[1].status,"Eliminated")
        eq(state.heroes[1].actorId,nil);eq(state.heroes[1].pending,nil);eq(state.heroes[1].view,"Menu")
        state=send(state,"CommitSpawn",{userId=1,token=token,actorId="late-actor",safe=true},"RUN_CLOSED")
    end)
    test("turning off clears an unaffordable living emergency retry without losing its body",function()
        local state=toggle(spent(spawn(domain(),1),1),1,true)
        state=spawn(death(state,1),1,false)
        state=send(state,"ExpireShield",identity(state,1,{now=state.heroes[1].shield.deadline}))
        state=send(state,"ReserveSpawn",{userId=1,connectionEpoch=1})
        local actor=state.heroes[1].actorId
        state=toggle(state,1,false)
        eq(state.heroes[1].actorId,actor);eq(state.heroes[1].status,"Alive")
        eq(state.heroes[1].pending,nil);eq(state.heroes[1].retryReady,false)
    end)
    test("eliminated heroes and closed runs cannot be revived by toggling",function()
        local state=domain(2);state=spawn(state,1);state=spawn(state,2)
        state=death(spent(state,1),1)
        state=send(state,"SetInfiniteLives",{userId=1,enabled=true},"ELIMINATED")
        eq(state.heroes[1].infiniteLives,false);eq(state.heroes[1].status,"Eliminated")
        state=death(spent(state,2),2)
        state=send(state,"SetInfiniteLives",{userId=2,enabled=true},"RUN_CLOSED")
    end)
    test("enabling during a reservation preserves exactly one normal commit",function()
        local state=death(spawn(domain(),1),1)
        state=send(state,"ReserveSpawn",{userId=1,connectionEpoch=1})
        local token=state.heroes[1].pending.token
        state=toggle(state,1,true)
        state=send(state,"CommitSpawn",{userId=1,token=token,actorId="reserved-god",safe=true})
        eq(state.heroes[1].respawns,3);eq(state.heroes[1].attempt,2)
        state=send(state,"CommitSpawn",{userId=1,token=token,actorId="duplicate-god",safe=true},"STALE_RESERVATION")
    end)
    test("offline zero reserve hero cannot spawn until its normal reconnect",function()
        local state=toggle(spent(spawn(domain(),1),1),1,true)
        state=send(state,"Connection",{userId=1,connectionEpoch=1,connected=false})
        state=death(state,1)
        state=send(state,"ReserveSpawn",{userId=1,connectionEpoch=2},"OFFLINE")
        state=send(state,"Connection",{userId=1,connectionEpoch=2,connected=true})
        state=spawn(state,1);eq(state.heroes[1].respawns,0);eq(state.heroes[1].infiniteLives,true)
    end)
    test("level progression preserves the option and each finite reserve",function()
        local state=domain(2);state=spawn(state,1);state=spawn(state,2)
        state=spawn(death(state,1),1);state=toggle(state,1,true)
        state=send(state,"AdvanceLevel",identity(state,1,{levelId="second",destinationSafe=true,prerequisitesMet=true}))
        eq(state.heroes[1].infiniteLives,true);eq(state.heroes[1].respawns,2)
        eq(state.heroes[2].infiniteLives,false);eq(state.heroes[2].respawns,3)
        state=spawn(death(state,1),1);eq(state.heroes[1].respawns,2)
    end)
    test("server setter requires the explicit development gate",function()
        for _,development in ipairs({false,true,{},{allowInfiniteLives=1}}) do
            local s=session(false)
            s.config.Development=development~=false and development or nil
            local revision=s.state.revision
            eq(s:setInfiniteLives(true),"DEVELOPMENT_ONLY")
            eq(s.state.revision,revision);eq(s.state.heroes[1].infiniteLives,false)
        end
    end)
    test("setter is boolean, server only, and idempotent without actor effects",function()
        local s,w=session(true,3)
        eq(s:setInfiniteLives("true"),"INVALID_OPTION")
        local spawns,kills=w.spawns,w.kills
        eq(s:setInfiniteLives(true),"OK")
        local revision=s.state.revision
        eq(s:setInfiniteLives(true),"OK");eq(s.state.revision,revision)
        eq(w.spawns,spawns);eq(w.kills,kills)
        local snapshot=s:snapshot();eq(snapshot.infiniteLives,true)
        for _,hero in ipairs(snapshot.heroes) do eq(hero.infiniteLives,true) end
        eq(Session.validIntent({kind="SetInfiniteLives",enabled=true}),false)
        local h=s.state.heroes[1]
        eq(Session.validIntent({kind="Move",runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=1,x=0,z=0,infiniteLives=true}),false)
    end)
    test("server may configure before the first ordinary appearance without spawning early",function()
        local cfg=table.clone(Config);cfg.Development={allowInfiniteLives=true}
        local w=World.new()
        local s=Session.new(Core,Combat,cfg,{{userId=1,template="Mr. Green"}},"before-initial",w)
        eq(s:setInfiniteLives(true),"OK");eq(w.spawns,0)
        eq(s.state.heroes[1].status,"AwaitingInitial");eq(s.state.heroes[1].attempt,0)
        eq(s:step(0),"OK");eq(w.spawns,1);eq(s.state.heroes[1].respawns,3)
        eq(s.state.heroes[1].shield,nil);eq(s:snapshot().infiniteLives,true)
    end)
    test("real Session performs seven normal deaths without consuming reserves or duplicating actors",function()
        local s,w=session(true);eq(s:setInfiniteLives(true),"OK")
        local actors={[s.state.heroes[1].actorId]=true}
        for i=1,7 do
            fall(s,w)
            local h=s.state.heroes[1]
            eq(h.status,"Alive");eq(h.attempt,i+1);eq(h.respawns,3)
            eq(h.shield.kind,"Normal");eq(h.shield.deadline,s.now+2)
            eq(s.combat[1].rawLife,47);eq(actors[h.actorId],nil);actors[h.actorId]=true
        end
        eq(w.spawns,8);eq(w.kills,7);eq(countLogs(s,"ConfirmedDeath"),7)
        eq(s:step(s.now),"OK");eq(w.spawns,8)
    end)
    test("real Session can enable at zero and disable back to an ordinary final death",function()
        local s,w=session(true)
        for _=1,3 do fall(s,w) end
        eq(s.state.heroes[1].respawns,0);eq(s:setInfiniteLives(true),"OK")
        for _=1,5 do fall(s,w) end
        eq(s.state.heroes[1].respawns,0)
        eq(s:setInfiniteLives(false),"OK");fall(s,w)
        eq(s.state.status,"Lost");eq(w.spawns,9);eq(w.kills,9)
        eq(s:setInfiniteLives(true),"RUN_CLOSED");eq(s:step(s.now+.1),"RUN_CLOSED")
    end)
    test("infinite lives keeps ordinary damage, reaction, delayed death and respawn",function()
        local s,w=session(true);eq(s:setInfiniteLives(true),"OK")
        for i=1,3 do
            if s.state.heroes[1].shield then s:step(s.state.heroes[1].shield.deadline) end
            assert(s:_hit(-99,1,"Dash"))
            if i<3 then eq(s.combat[1].rawLife,47-i*16);s:step(s.now+1) end
        end
        eq(s.combat[1].rawLife,0);eq(s.state.heroes[1].status,"Alive")
        assert(s.combat[1].deathAt);eq(w.impulses,3)
        eq(s:step(s.combat[1].deathAt),"OK");eq(s.state.heroes[1].status,"AwaitingRespawn")
        eq(s:step(s.now+.1),"OK");eq(s.state.heroes[1].attempt,2);eq(s.state.heroes[1].respawns,3)
    end)
    test("real Session emergency fallback retries indefinitely at zero stock",function()
        local s,w=session(true)
        for _=1,3 do fall(s,w) end
        eq(s:setInfiniteLives(true),"OK");w.safe=false;fall(s,w)
        for _=1,5 do
            local h=s.state.heroes[1]
            eq(h.respawns,0);eq(h.shield.kind,"Emergency")
            local attempt=h.attempt
            eq(s:step(h.shield.deadline),"OK")
            eq(s.state.heroes[1].attempt,attempt+1)
        end
        eq(s.state.status,"Active")
    end)
    test("real Session disabling between zero stock death and step closes the run",function()
        local s,w=session(true)
        for _=1,3 do fall(s,w) end
        eq(s:setInfiniteLives(true),"OK");w.hazards[1]="Fall";s:step(s.now+.1)
        eq(s.state.heroes[1].status,"AwaitingRespawn")
        local spawns=w.spawns
        eq(s:setInfiniteLives(false),"OK");eq(s.state.status,"Lost")
        eq(s:step(s.now+.1),"RUN_CLOSED");eq(w.spawns,spawns)
    end)
    test("bulk setter skips an eliminated teammate without reviving it",function()
        local s,w=session(true,2)
        for i=1,4 do
            w.hazards[1]="Fall";s:step(i*3)
            if i<4 then s:step(i*3+.1) end
        end
        eq(s.state.heroes[1].status,"Eliminated")
        eq(s:setInfiniteLives(true),"OK")
        eq(s.state.heroes[1].infiniteLives,false);eq(s.state.heroes[2].infiniteLives,true)
        eq(s.state.heroes[1].status,"Eliminated")
    end)
    test("bulk disable settles all zero reserve dead heroes without partial-toggle ghosts",function()
        local s,w=session(true,3)
        for _=1,3 do
            for uid=1,3 do w.hazards[uid]="Fall" end
            s:step(s.now+.1);s:step(s.now+.1)
        end
        eq(s:setInfiniteLives(true),"OK")
        for uid=1,3 do w.hazards[uid]="Fall" end
        s:step(s.now+.1)
        eq(s:setInfiniteLives(false),"OK");eq(s.state.status,"Lost")
        for uid=1,3 do
            eq(s.state.heroes[uid].status,"Eliminated")
            eq(s.state.heroes[uid].infiniteLives,false)
            eq(s.state.heroes[uid].view,"Menu")
        end
        eq(s:snapshot().infiniteLives,false);eq(w.spawns,12);eq(w.kills,12)
    end)
    print(string.format("Infinite lives domain/session: %d passed, %d failed",passed,failed))
    assert(failed==0,"infinite lives contracts failed")
end
