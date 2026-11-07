return function(setup)
    local passed, failed = 0, 0
    local function eq(actual, expected) assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected)) end
    local function test(name, fn)
        local ok, err = pcall(fn)
        if ok then passed = passed + 1; print("PASS " .. name)
        else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
    end
    local function active()
        local c = setup()
        local a, teammate = c:player(42, "old"), c:player(73, "teammate")
        c:add(a); c:add(teammate); c:intent(a, {kind = "Start"})
        return c, a, teammate
    end
    test("duplicate PlayerAdded cannot reset connection epoch or sequence", function()
        local c, a = active()
        c:intent(a, c:packet(1, {kind = "Move", attack = nil, x = 0, z = 0}))
        eq(c.session.lastSeq[1], 1)
        local epoch, revision = c.session.state.heroes[1].connectionEpoch, c.session.state.revision
        c:repeatAdded(a)
        eq(c.session.state.heroes[1].connectionEpoch, epoch)
        eq(c.session.state.revision, revision)
        eq(c.session.lastSeq[1], 1)
    end)
    test("superseded Player cannot use the replacements current actor and epoch", function()
        local c, a = active(); local b = c:player(42, "replacement"); c:add(b)
        local revision = c.session.state.revision
        c:intent(a, c:packet(1))
        eq(c.session.state.revision, revision); eq(c.session.combat[1].attack, nil)
    end)
    test("superseded Player receives no role State or Sync reply", function()
        local c, a = active(); c:add(c:player(42, "replacement"))
        c.outbound = {}; c:intent(a, {kind = "Sync"}); c:tick()
        eq(c:latest(a), nil)
    end)
    test("current replacement removal never revives old host", function()
        local c, a, teammate = active(); local b = c:player(42, "replacement"); c:add(b)
        c:remove(b); c.outbound = {}; c:tick()
        eq(c:latest(teammate).host, teammate.UserId); eq(c:latest(a), nil)
    end)
    test("roster contains one owner per UserId during overlap", function()
        local c = setup(); local a, b, teammate = c:player(42,"old"), c:player(42,"new"), c:player(73,"team")
        c:add(a); c:add(b); c:add(teammate)
        c:intent(b, {kind = "Start"}); c:tick()
        assert(c.session, "replacement must be eligible host")
        eq(#c.session.order, 2)
        eq(c:latest(b).mine, 1); eq(c:latest(teammate).mine, 2)
    end)
    test("late removal and repeated current removal cannot disconnect twice", function()
        local c, a = active(); local b = c:player(42,"replacement"); c:add(b)
        local epoch = c.session.state.heroes[1].connectionEpoch
        c:remove(a); eq(c.session.state.heroes[1].connected, true)
        eq(c.session.state.heroes[1].connectionEpoch, epoch)
        c:remove(b); local revision = c.session.state.revision
        c:remove(b); eq(c.session.state.revision, revision)
    end)
    test("delayed join callback for an already removed unknown object is ignored", function()
        local c = setup(); local a = c:player(42, "departed before callback")
        c:remove(a); c:repeatAdded(a); c:intent(a, {kind = "Sync"})
        eq(c:latest(a), nil)
    end)
    test("departed current object cannot command before its removal callback", function()
        local c, a = active(); a.Parent = nil
        local revision = c.session.state.revision
        c:intent(a, c:packet(1)); eq(c.session.state.revision, revision)
    end)
    test("replacement uses current Life without new actor healing or reserve", function()
        local c, a, teammate = active()
        c.world.targetsFor[2] = {1}
        c:intent(teammate, c:packet(2, {attack = "Dash"})); c:tick(0.18)
        eq(c.session.combat[1].rawLife, 31)
        local before, spawns = c.session.state.heroes[1], c.world.spawns
        local b = c:player(42, "returned"); c:add(b); c:tick(0.1)
        local h = c.session.state.heroes[1]
        eq(h.actorId, before.actorId); eq(h.attempt, before.attempt)
        eq(h.respawns, before.respawns); eq(c.session.combat[1].rawLife, 31)
        eq(h.shield, nil); eq(c.world.spawns, spawns); eq(c:latest(b).mine, 1)
    end)
    test("both protection deadlines and hold survive replacement without renewal", function()
        for _, emergency in ipairs({false, true}) do
            local c, a = active()
            c.world.hazards[1] = "Fall"; c:tick(0.1)
            c.world.safe = not emergency; c:tick(0.1)
            local before = c.session.state.heroes[1]
            local shield, deadline, held = before.shield.kind, before.shield.deadline, c.world.actors[1].held
            c:add(c:player(42, "returned"))
            local h = c.session.state.heroes[1]
            eq(h.actorId, before.actorId); eq(h.attempt, before.attempt); eq(h.respawns, before.respawns)
            eq(h.shield.kind, shield); eq(h.shield.deadline, deadline); eq(c.world.actors[1].held, held)
        end
    end)
    test("already accepted attack survives owner replacement and resolves once", function()
        local c, a = active(); c.world.targetsFor[1] = {2}
        c:intent(a, c:packet(1)); c:add(c:player(42,"returned")); c:tick(0.1); c:tick(0.1)
        local hits = 0
        for _, e in ipairs(c.session.logs) do if e.kind == "Hit" then hits = hits + 1 end end
        eq(hits, 1); eq(c.world.impulses, 1); eq(c.session.combat[2].rawLife, 43)
    end)
    test("offline death waits and returns with exactly one successful respawn", function()
        local c, a = active(); c:remove(a)
        local spawns = c.world.spawns
        c.world.hazards[1] = "Fall"; c:tick(0.1); c:tick(1)
        eq(c.session.state.heroes[1].status, "AwaitingRespawn")
        eq(c.world.spawns, spawns); eq(c.session.state.heroes[1].respawns, 3)
        local b = c:player(42,"returned"); c:add(b); c:tick(0.1)
        eq(c.world.spawns, spawns + 1); eq(c.session.state.heroes[1].respawns, 2)
        eq(c.session.combat[1].rawLife, 47)
        c:repeatAdded(b); c:remove(a); c:tick(0.1)
        eq(c.world.spawns, spawns + 1); eq(c.session.state.heroes[1].respawns, 2)
    end)
    test("new owner receives new epoch and rejects the prior epoch", function()
        local c, a = active()
        local old = c:packet(1, {kind = "Move", x = 0, z = 0})
        local b = c:player(42,"returned"); c:add(b); c:intent(b, old); c:tick()
        eq(c:latest(b).notice, "STALE_CONNECTION")
        local current = c:packet(1, {kind = "Move", x = 0, z = 0})
        c:intent(b, current); c:tick()
        eq(c:latest(b).notice, nil); eq(c.session.lastSeq[1], 1)
    end)
    test("late different user is a spectator without a replacement role", function()
        local c = active(); local late = c:player(99,"late"); c:add(late); c:intent(late,{kind="Sync"})
        eq(c:latest(late).mine, nil); eq(#c.session.order, 2)
        local revision = c.session.state.revision
        c:intent(late,c:packet(1)); eq(c.session.state.revision, revision)
    end)
    print("Gateway contracts: " .. passed .. " PASS, " .. failed .. " FAIL; fake transport, NOT real reconnect")
    assert(failed == 0, "Gateway contract failures")
end
