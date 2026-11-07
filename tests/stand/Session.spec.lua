return function(Core, Combat, Session, Config, World)
    assert(type(Session.new) == "function", "Session.new must be implemented")
    local passed, failed = 0, 0
    local function eq(a,b) assert(a == b, tostring(a).." ~= "..tostring(b)) end
    local function test(name, fn)
        local ok, err=pcall(fn)
        if ok then passed=passed+1; print("PASS "..name)
        else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
    end
    local function setup(count)
        local roster={}
        for i=1,count or 2 do roster[i]={userId=i,template="Mr. Green"} end
        local w=World.new()
        local s=Session.new(Core,Combat,Config,roster,"run",w)
        s:step(0)
        return s,w
    end
    local function packet(s, uid, kind, extra)
        local h=s.state.heroes[uid]
        local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=(s.lastSeq[uid] or 0)+1}
        for k,v in pairs(extra or {}) do p[k]=v end
        return p
    end
    local function attack(s,w,uid,target,at,kind)
        w.targetsFor[uid]=target and {target} or {}
        local a=kind or "Punch"
        eq(s:intent(uid,packet(s,uid,"Attack",{attack=a}),at),"OK")
        s:step(at+Config.Attacks[a].windup)
    end
    local function death(s,w,uid,at)
        w.hazards[uid]="Fall"; s:step(at)
        eq(s.state.heroes[uid].status,"AwaitingRespawn")
    end
    test("one two three heroes have independent actors and reserves",function()
        for n=1,3 do
            local s,w=setup(n); eq(w.spawns,n)
            for i=1,n do eq(s.state.heroes[i].respawns,3); eq(s.state.heroes[i].attempt,1) end
            eq(s:intent(4,{},0),"UNKNOWN_HERO")
        end
    end)
    test("all six ordered trio attack pairs use the same profile",function()
        for a=1,3 do for b=1,3 do if a~=b then
            local s,w=setup(3); attack(s,w,a,b,0)
            eq(s.combat[b].rawLife,43); eq(w.impulses,1)
            s:step(1); eq(s.combat[b].rawLife,47)
        end end end
    end)
    test("duplicate and reordered attack cannot replay damage or impulse",function()
        local s,w=setup(); w.targetsFor[1]={2}
        local p=packet(s,1,"Attack",{attack="Punch"})
        eq(s:intent(1,p,0),"OK"); eq(s:intent(1,p,0.01),"STALE_SEQUENCE")
        s:step(0.1); s:step(0.11); eq(w.impulses,1)
        eq(s:intent(1,p,2),"STALE_SEQUENCE"); eq(w.impulses,1)
    end)
    test("payload cannot supply target health position time or NaN",function()
        for _,key in ipairs({"target","health","position","now","safe","userId"}) do
            local s,w=setup(); local p=packet(s,1,"Attack",{attack="Punch"}); p[key]=1
            eq(s:intent(1,p,0),"INVALID_INTENT"); eq(w.impulses,0)
        end
        local s=setup()
        eq(s:intent(1,packet(s,1,"Move",{x=0/0,z=0}),0),"INVALID_INTENT")
        eq(s:intent(1,packet(s,1,"Move",{x=100,z=0}),0),"INVALID_INTENT")
        eq(s:intent(1,packet(s,1,"Attack",{attack="KillAll"}),0),"INVALID_INTENT")
    end)
    test("stale actor packet does not poison new sequence",function()
        local s,w=setup(); local old=packet(s,1,"Attack",{attack="Dash",seq=999999})
        death(s,w,1,0.1); s:step(0.2)
        eq(s:intent(1,old,0.3),"STALE_ACTOR")
        eq(s:intent(1,packet(s,1,"Move",{x=1,z=0}),0.3),"OK")
    end)
    test("failed physical spawn spends no resource",function()
        local s,w=setup(); death(s,w,1,0.1); w.spawnFails=true; s:step(0.2)
        eq(s.state.heroes[1].respawns,3); eq(s.state.heroes[1].pending,nil)
        w.spawnFails=false; s:step(1); eq(s.state.heroes[1].respawns,2)
    end)
    test("safe point race aborts without spending",function()
        local s,w=setup(); death(s,w,1,0.1); w.raceUnsafe=true; s:step(0.2)
        eq(s.state.heroes[1].respawns,3); eq(s.state.heroes[1].status,"AwaitingRespawn")
    end)
    test("unsafe initial spawn is not a free emergency attempt",function()
        local w=World.new(); w.safe=false
        local s=Session.new(Core,Combat,Config,{{userId=1,template="Mr. Green"}},"run",w)
        s:step(0); eq(w.spawns,0); eq(s.state.heroes[1].attempt,0)
    end)
    test("normal shield blocks health but not unproven impulse immunity",function()
        local s,w=setup(); death(s,w,2,0.1); s:step(0.2)
        eq(s.state.heroes[2].shield.deadline,2.2)
        attack(s,w,1,2,0.3); eq(s.combat[2].rawLife,47); eq(w.impulses,1)
    end)
    test("missed own attack cancels normal shield before impact",function()
        local s,w=setup(); death(s,w,1,0.1); s:step(0.2)
        eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0.3),"OK")
        eq(s.state.heroes[1].shield,nil)
    end)
    test("normal movement retains shield and expires without input",function()
        local s,w=setup(); death(s,w,1,0.1); s:step(0.2)
        eq(s:intent(1,packet(s,1,"Move",{x=1,z=0}),0.3),"OK")
        assert(s.state.heroes[1].shield)
        s:step(0.7); eq(w.lastMove[2],0); eq(w.lastMove[3],0)
        s:step(2.2); eq(s.state.heroes[1].shield,nil)
    end)
    test("emergency cycles consume exactly three respawns then release live body",function()
        local s,w=setup(1); death(s,w,1,0.1); w.safe=false; s:step(0.2)
        eq(s.state.heroes[1].respawns,2); eq(w.actors[1].held,true)
        s:step(10.2); eq(s.state.heroes[1].respawns,1)
        s:step(20.2); eq(s.state.heroes[1].respawns,0)
        s:step(30.2); eq(s.state.heroes[1].status,"Alive"); eq(w.actors[1].held,false)
        w.hazards[1]="Fall"; s:step(30.3); eq(s.state.status,"Lost"); eq(w.spawns,4)
    end)
    test("safe relocation beats simultaneous timeout without new life or healing",function()
        local s,w=setup(); death(s,w,1,0.1); w.safe=false; s:step(0.2)
        local id=s.state.heroes[1].actorId; w.safe=true; s:step(10.2)
        eq(s.state.heroes[1].actorId,id); eq(s.state.heroes[1].respawns,2)
        eq(w.relocations,1); eq(w.spawns,3); eq(w.actors[1].held,false)
    end)
    test("emergency attack releases hold even when it misses",function()
        local s,w=setup(); death(s,w,1,0.1); w.safe=false; s:step(0.2)
        eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0.3),"OK")
        eq(w.actors[1].held,false); eq(s.state.heroes[1].shield,nil)
        s:step(11); eq(s.state.heroes[1].respawns,2)
    end)
    test("emergency protection prevents health and impulse",function()
        local s,w=setup(); death(s,w,2,0.1); w.safe=false; s:step(0.2)
        attack(s,w,1,2,0.3,"Dash"); eq(w.impulses,0); eq(s.combat[2].rawLife,47)
    end)
    test("offline body remains target while new commands are rejected",function()
        local s,w=setup(); eq(s:connection(2,false,0.1),"OK")
        eq(s:intent(2,packet(s,2,"Attack",{attack="Punch"}),0.2),"OFFLINE")
        attack(s,w,1,2,0.3,"Dash"); eq(s.combat[2].rawLife,31); eq(w.impulses,1)
        local id=s.state.heroes[2].actorId; eq(s:connection(2,true,0.6),"OK")
        eq(s.state.heroes[2].actorId,id); eq(s.combat[2].rawLife,31)
    end)
    test("already accepted attack resolves after disconnect",function()
        local s,w=setup(); w.targetsFor[1]={2}
        eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0),"OK")
        s:connection(1,false,0.05); s:step(0.1); eq(w.impulses,1)
    end)
    test("old connection cannot control returned actor",function()
        local s=setup(); local p=packet(s,1,"Move",{x=1,z=0})
        s:connection(1,false,0); s:connection(1,true,0.1)
        eq(s:intent(1,p,0.2),"STALE_CONNECTION")
    end)
    test("offline emergency timeout cannot consume another reserve",function()
        local s,w=setup(); death(s,w,1,0.1); w.safe=false; s:step(0.2)
        s:connection(1,false,0.3); s:step(10.2)
        eq(s.state.heroes[1].respawns,2); eq(w.actors[1].held,false)
        w.hazards[1]="Fall"; s:step(10.3); s:step(11)
        eq(s.state.heroes[1].status,"AwaitingRespawn"); eq(w.spawns,3)
        s:connection(1,true,11.1); s:step(11.2); eq(s.state.heroes[1].respawns,1)
    end)
    test("lethal dash begins dying state before one confirmed death",function()
        local s,w=setup(); s.combat[2].rawLife=15
        attack(s,w,1,2,0,"Dash")
        eq(s.combat[2].rawLife,0); eq(s.state.heroes[2].status,"Alive")
        s:step(1); eq(s.state.heroes[2].status,"AwaitingRespawn"); eq(w.kills,1)
        s:step(1.1); eq(s.state.heroes[2].respawns,2); eq(w.kills,1)
    end)
    test("exact arithmetic zero alone is not lethal",function()
        local s,w=setup(); s.combat[2].rawLife=4
        attack(s,w,1,2,0); eq(s.combat[2].rawLife,0)
        s:step(0.7); eq(s.combat[2].rawLife,7); eq(w.kills,0)
    end)
    test("server stall does not deliver an expired hit window",function()
        local s,w=setup(); w.targetsFor[1]={2}
        s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0)
        s:step(5); eq(w.impulses,0); eq(s.combat[2].rawLife,47)
    end)
    test("backward time and wrong run do not mutate state",function()
        local s=setup(); s:step(1)
        eq(s:step(0),"TIME_REVERSED")
        local p=packet(s,1,"Move",{x=1,z=0}); p.runId="other"
        eq(s:intent(1,p,1),"WRONG_RUN")
    end)
    test("one hit chooses one target and does not hit self",function()
        local s,w=setup(3); w.targetsFor[1]={1,2,3}
        s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0); s:step(0.1)
        eq(w.impulses,1); eq(s.combat[2].rawLife,43); eq(s.combat[3].rawLife,47)
    end)
    test("physical response keeps the selected hero profile",function()
        for _,case in ipairs({{47,"Punch",18},{47,"Dash",22},{15,"Dash",21}}) do
            local s,w=setup(); s.combat[2].rawLife=case[1]
            attack(s,w,1,2,0,case[2]); eq(w.lastProfile,case[3])
            assert(Config.Impulses[case[3]],"Each source profile needs explicit stand calibration")
            eq(w.lastCalibration,Config.Impulses[case[3]])
        end
    end)
    test("rate limit is bounded and recovers with server time",function()
        local s=setup()
        for _=1,Config.MaxIntentRate do
            eq(s:intent(1,packet(s,1,"Move",{x=0,z=0}),0),"OK")
        end
        eq(s:intent(1,packet(s,1,"Move",{x=0,z=0}),0),"RATE_LIMIT")
        eq(s:intent(1,packet(s,1,"Move",{x=0,z=0}),1),"OK")
    end)
    test("failed emergency replacement preserves the current living actor",function()
        local s,w=setup(); death(s,w,1,0.1); w.safe=false; s:step(0.2)
        local id=s.state.heroes[1].actorId; w.spawnFails=true; s:step(10.2)
        eq(s.state.heroes[1].actorId,id); eq(s.state.heroes[1].status,"Alive")
        eq(s.state.heroes[1].respawns,2); eq(w.actors[1].held,false)
        w.spawnFails=false; s:step(10.8)
        eq(s.state.heroes[1].respawns,1); eq(w.actors[1].held,true)
    end)
    test("safe relocation preserves an intermediate combat state",function()
        local s,w=setup(); death(s,w,1,0.1); w.safe=false; s:step(0.2)
        s.combat[1].rawLife=31
        s.state.heroes[1].health=Combat.hearts(31)
        w.safe=true; s:step(1)
        eq(s.combat[1].rawLife,31); eq(s.state.heroes[1].health,Combat.hearts(31)); eq(s.state.heroes[1].respawns,2)
        eq(s.state.heroes[1].shield,nil)
    end)
    test("acceptance order not slot number decides simultaneous attacks",function()
        local s,w=setup(); w.targetsFor[1]={2}; w.targetsFor[2]={1}
        eq(s:intent(2,packet(s,2,"Attack",{attack="Punch"}),0),"OK")
        eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0),"OK")
        s:step(0.1); eq(w.impulses,1); eq(s.combat[1].rawLife,43); eq(s.combat[2].rawLife,47)
    end)
    test("missing identity and non-scalar input is rejected",function()
        local s=setup()
        for _,k in ipairs({"runId","actorId","attempt","levelEpoch","connectionEpoch","seq"}) do
            local p=packet(s,1,"Jump"); p[k]=nil
            eq(s:intent(1,p,0),"INVALID_INTENT")
        end
        for _,v in ipairs({false,{},-1,1.5,math.huge}) do
            eq(s:intent(1,packet(s,1,"Jump",{seq=v}),0),"INVALID_INTENT")
        end
    end)
    test("malformed identity types and non-finite counters cannot mutate the session",function()
        local s,w=setup()
        local revision,logs=s.state.revision,#s.logs
        for _,key in ipairs({"attempt","levelEpoch","connectionEpoch","seq"}) do
            for _,value in ipairs({0,-1,1.5,math.huge,-math.huge,0/0,1000000001,false,{}}) do
                local p=packet(s,1,"Jump"); p[key]=value
                eq(s:intent(1,p,100),"INVALID_INTENT")
            end
        end
        for _,key in ipairs({"runId","actorId"}) do
            for _,value in ipairs({false,1,{},string.rep("x",161)}) do
                local p=packet(s,1,"Jump"); p[key]=value
                eq(s:intent(1,p,100),"INVALID_INTENT")
            end
        end
        eq(s.state.revision,revision); eq(#s.logs,logs); eq(s.now,0)
        eq(s.lastSeq[1],0); eq(s.buckets[1],nil); eq(w.lastJump,nil)
        eq(s:intent(1,packet(s,1,"Jump"),0),"OK")
    end)
    test("non-table packets and unknown schema are harmless rejections",function()
        local s,w=setup()
        eq(s:intent(1,nil,0),"INVALID_INTENT")
        for _,value in ipairs({false,1,"Attack",{},{kind=false},{kind={}},
            {kind=0/0},{kind=string.rep("x",161)}}) do
            eq(s:intent(1,value,0),"INVALID_INTENT")
        end
        for _,extra in ipairs({{[1]="extra"},{[false]="extra"},
            {target={actorId="other"}},{health=5},{safe=true},{now=999}}) do
            eq(s:intent(1,packet(s,1,"Jump",extra),0),"INVALID_INTENT")
        end
        eq(s.lastSeq[1],0); eq(w.lastJump,nil)
        eq(s:intent(1,packet(s,1,"Jump"),0),"OK")
    end)
    test("non-finite and oversized movement never reaches the world",function()
        local s,w=setup(); local moves=w.moves
        for _,key in ipairs({"x","z"}) do
            for _,value in ipairs({math.huge,-math.huge,0/0,1.01,-1.01,false,{}}) do
                local p=packet(s,1,"Move",{x=0,z=0}); p[key]=value
                eq(s:intent(1,p,0),"INVALID_INTENT")
            end
        end
        eq(s:intent(1,packet(s,1,"Move",{x=0.8,z=0.8}),0),"INVALID_INTENT")
        eq(w.moves,moves); eq(s.lastSeq[1],0)
        eq(s:intent(1,packet(s,1,"Move",{x=0.6,z=0.8}),0),"OK")
        eq(w.moves,moves+1); eq(w.lastMove[2],0.6); eq(w.lastMove[3],0.8)
    end)
    test("forged context and foreign actor cannot poison the owners sequence",function()
        local s,w=setup(); local revision=s.state.revision
        local cases={
            {runId="foreign",expected="WRONG_RUN"},
            {actorId=s.state.heroes[2].actorId,expected="STALE_ACTOR"},
            {attempt=2,expected="STALE_ACTOR"},
            {levelEpoch=2,expected="STALE_ACTOR"},
            {connectionEpoch=2,expected="STALE_CONNECTION"},
        }
        for _,case in ipairs(cases) do
            local p=packet(s,1,"Attack",{attack="Punch",seq=1000000000})
            for key,value in pairs(case) do if key~="expected" then p[key]=value end end
            eq(s:intent(1,p,100),case.expected)
        end
        eq(s.lastSeq[1],0); eq(s.buckets[1],nil); eq(s.now,0)
        eq(s.state.revision,revision); eq(w.impulses,0); eq(s.combat[2].rawLife,47)
        eq(s:intent(1,packet(s,1,"Jump"),0),"OK")
    end)
    test("an overtaken attack cannot cancel protection or replay after a newer move",function()
        local s,w=setup(); death(s,w,1,0.1); s:step(0.2)
        local old=packet(s,1,"Attack",{attack="Punch",seq=1})
        eq(s:intent(1,packet(s,1,"Move",{x=0,z=0,seq=2}),0.3),"OK")
        local shield=s.state.heroes[1].shield
        eq(s:intent(1,old,0.31),"STALE_SEQUENCE")
        eq(s.state.heroes[1].shield,shield); eq(s.combat[1].attack,nil)
        eq(s.lastSeq[1],2); eq(w.impulses,0)
        eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0.32),"OK")
        eq(s.state.heroes[1].shield,nil)
    end)
    test("a new sequence during cooldown cannot replace an accepted attack",function()
        local s,w=setup(); w.targetsFor[1]={2}
        eq(s:intent(1,packet(s,1,"Attack",{attack="Dash"}),0),"OK")
        local pending=s.combat[1].attack
        eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0.01),"COOLDOWN")
        eq(s.combat[1].attack,pending)
        s:step(Config.Attacks.Dash.windup); s:step(0.2)
        eq(w.impulses,1); eq(s.combat[2].rawLife,31)
        local accepted=0
        for _,row in ipairs(s.logs) do if row.kind=="AttackAccepted" then accepted=accepted+1 end end
        eq(accepted,1)
    end)
    test("rate-limited attacks cannot cancel normal or emergency protection",function()
        for _,emergency in ipairs({false,true}) do
            local s,w=setup(); death(s,w,1,0.1); w.safe=not emergency; s:step(0.2)
            local shield=s.state.heroes[1].shield
            for _=1,Config.MaxIntentRate do
                eq(s:intent(1,packet(s,1,"Move",{x=0,z=0}),0.3),"OK")
            end
            eq(s:intent(1,packet(s,1,"Attack",{attack="Punch"}),0.3),"RATE_LIMIT")
            eq(s.state.heroes[1].shield,shield); eq(w.actors[1].held,emergency)
            eq(s.combat[1].attack,nil); eq(s.state.heroes[1].respawns,2)
        end
    end)
    test("snapshot exposes eliminated view without changing lives or the continuing teammate",function()
        local s,w=setup(2)
        for i=1,4 do w.hazards[1]='Fall'; s:step(i*.3); s:step(i*.3+.1) end
        eq(s.state.status,'Active'); eq(s.state.heroes[1].status,'Eliminated')
        eq(s:snapshot().heroes[1].view,'Choice')
        local spawns=w.spawns; local teammate=s.state.heroes[2].actorId
        s:_clock(1.5)
        eq(s:_event('ChooseView',1,{view='Menu',connectionEpoch=s.state.heroes[1].connectionEpoch}),'OK')
        eq(s:snapshot().heroes[1].view,'Menu'); eq(s.state.heroes[1].respawns,0)
        eq(w.spawns,spawns); eq(s.state.heroes[2].actorId,teammate)
    end)
    print("Session tests: "..passed.." PASS, "..failed.." FAIL")
    assert(failed==0, "Session contracts failed")
    return passed
end
