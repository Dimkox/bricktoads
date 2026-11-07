-- Fake objects exercise connection identity and Session contracts, not Roblox login/transport.
return function(Registry, Core, Combat, Session, Config, World)
    local passed, failed = 0, 0
    local function eq(actual, expected)
        assert(rawequal(actual, expected), tostring(actual) .. " ~= " .. tostring(expected))
    end
    local function test(name, fn)
        local ok, failure = pcall(fn)
        if ok then passed = passed + 1; print("PASS " .. name)
        else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(failure)) end
    end
    local function player(userId) return {UserId = userId} end

    test("unknown objects have no connection authority", function()
        local r = Registry.new()
        eq(r:isCurrent(player(42)), false)
        eq(r:isCurrent(nil), false)
        eq(r:remove(player(42)), false)
        eq(r:remove(nil), false)
    end)
    test("first join is current and duplicate join is a no-op", function()
        local r, a = Registry.new(), player(42)
        local changed, previous = r:join(a)
        eq(changed, true); eq(previous, nil); eq(r:isCurrent(a), true)
        changed, previous = r:join(a)
        eq(changed, false); eq(previous, nil); eq(r:isCurrent(a), true)
    end)
    test("a fresh object replaces the same account's current object", function()
        local r, a, b = Registry.new(), player(42), player(42)
        r:join(a)
        local changed, previous = r:join(b)
        eq(changed, true); eq(previous, a)
        eq(r:isCurrent(a), false); eq(r:isCurrent(b), true)
    end)
    test("superseded object's removal cannot disconnect the replacement", function()
        local r, a, b = Registry.new(), player(42), player(42)
        r:join(a); r:join(b)
        eq(r:remove(a), false); eq(r:isCurrent(b), true)
        eq(r:remove(a), false); eq(r:isCurrent(b), true)
    end)
    test("current removal changes authority exactly once", function()
        local r, a = Registry.new(), player(42)
        r:join(a)
        eq(r:remove(a), true); eq(r:isCurrent(a), false)
        eq(r:remove(a), false)
    end)
    test("departing replacement never falls back to old object", function()
        local r, a, b = Registry.new(), player(42), player(42)
        r:join(a); r:join(b); r:remove(b)
        eq(r:isCurrent(a), false); eq(r:isCurrent(b), false)
        eq(#r:online({a, b}), 0)
    end)
    test("known superseded or removed objects never revive through add replay", function()
        local r, a, b = Registry.new(), player(42), player(42)
        r:join(a); r:join(b)
        eq(r:join(a), false); eq(r:isCurrent(b), true)
        r:remove(b)
        eq(r:join(b), false); eq(r:join(a), false)
        eq(r:isCurrent(a), false); eq(r:isCurrent(b), false)
    end)
    test("a genuinely new object can return after all old objects leave", function()
        local r, a, b, c = Registry.new(), player(42), player(42), player(42)
        r:join(a); r:join(b); r:remove(b)
        local changed, previous = r:join(c)
        eq(changed, true); eq(previous, nil)
        eq(r:isCurrent(c), true); eq(r:isCurrent(a), false); eq(r:isCurrent(b), false)
    end)
    test("different accounts including Studio negative IDs are independent", function()
        local r, a, b, replacement = Registry.new(), player(-1), player(-2), player(-1)
        r:join(a); r:join(b); r:join(replacement)
        eq(r:isCurrent(b), true); eq(r:isCurrent(replacement), true); eq(r:isCurrent(a), false)
        r:remove(replacement); eq(r:isCurrent(b), true)
    end)
    test("authority uses exact object identity even for equal fake objects", function()
        local meta = {__eq = function() return true end}
        local a, b = setmetatable(player(42), meta), setmetatable(player(42), meta)
        local r = Registry.new()
        r:join(a)
        eq(r:isCurrent(b), false); eq(r:remove(b), false)
        r:join(b); eq(r:isCurrent(a), false); eq(r:isCurrent(b), true)
    end)
    test("online filters stale/unknown duplicates and sorts without changing input", function()
        local r, a, b, c, newer = Registry.new(), player(1), player(2), player(3), player(1)
        r:join(a); r:join(b); r:join(c); r:join(newer)
        local unknown = player(8)
        local input = {newer, c, b, a, newer, unknown}
        local result = r:online(input)
        eq(#result, 3); eq(result[1], b); eq(result[2], c); eq(result[3], newer)
        eq(#input, 6); eq(input[1], newer); eq(input[2], c); eq(input[3], b)
        eq(input[4], a); eq(input[5], newer); eq(input[6], unknown)
    end)
    test("online only returns current objects present in the supplied population", function()
        local r, a, b = Registry.new(), player(1), player(2)
        r:join(a); r:join(b)
        eq(#r:online({}), 0)
        local list = r:online({b}); eq(#list, 1); eq(list[1], b)
    end)
    test("late new account is online without replacing an existing account", function()
        local r, a, late = Registry.new(), player(1), player(99)
        r:join(a); local changed, previous = r:join(late)
        eq(changed, true); eq(previous, nil); eq(r:isCurrent(a), true)
        local list = r:online({late, a}); eq(list[1], a); eq(list[2], late)
    end)
    test("separate registries do not share object lifecycle", function()
        local r1, r2, a = Registry.new(), Registry.new(), player(42)
        r1:join(a); eq(r2:isCurrent(a), false)
        eq(r2:join(a), true); r1:remove(a); eq(r2:isCurrent(a), true)
    end)

    -- Small binding fixture uses the real Session/Core. It makes no claim about
    -- executing Stand.server.lua or actual PlayerAdded/Removing transport.
    local function binding()
        local r, world, a = Registry.new(), World.new(), player(42)
        local session = Session.new(Core, Combat, Config, {{userId = 1, template = "Mr. Green"}}, "run", world)
        session:step(0); r:join(a)
        local function joined(p, now)
            local changed = r:join(p)
            if changed and p.UserId == 42 then
                if session.state.heroes[1].connected then session:connection(1, false, now) end
                session:connection(1, true, now)
            end
            return changed
        end
        local function removed(p, now)
            local changed = r:remove(p)
            if changed and p.UserId == 42 then session:connection(1, false, now) end
            return changed
        end
        local function intent(p, payload, now)
            if not r:isCurrent(p) then return "STALE_PLAYER" end
            return session:intent(1, payload, now)
        end
        return r, session, world, a, joined, removed, intent
    end
    local function movePacket(session)
        local h = session.state.heroes[1]
        return {kind = "Move", runId = session.state.runId, actorId = h.actorId,
            attempt = h.attempt, levelEpoch = session.state.levelEpoch,
            connectionEpoch = h.connectionEpoch, seq = (session.lastSeq[1] or 0) + 1, x = 0, z = 0}
    end
    test("binding returns a damaged live hero without healing or a new appearance", function()
        local r, s, w, a, joined = binding()
        s.combat[1].rawLife = 31
        eq(s:_event("SetHealth", 1, {health = Combat.hearts(31)}), "OK")
        local actor = s.state.heroes[1].actorId
        joined(player(42), 0.1)
        local h = s.state.heroes[1]
        eq(h.actorId, actor); eq(h.attempt, 1); eq(h.respawns, 3)
        eq(h.health, Combat.hearts(31)); eq(s.combat[1].rawLife, 31)
        eq(h.shield, nil); eq(w.spawns, 1)
    end)
    test("binding replacement does not cancel an already accepted attack", function()
        local r, s, w, a, joined, removed, intent = binding()
        local payload = movePacket(s); payload.kind = "Attack"; payload.x = nil; payload.z = nil; payload.attack = "Punch"
        eq(intent(a, payload, 0), "OK")
        local pending, cooldown = s.combat[1].attack, s.combat[1].nextAttack
        local b = player(42); joined(b, 0.05); removed(a, 0.05)
        eq(s.combat[1].attack, pending); eq(s.combat[1].nextAttack, cooldown)
        eq(intent(a, movePacket(s), 0.06), "STALE_PLAYER")
        eq(intent(b, movePacket(s), 0.06), "OK")
        eq(s.combat[1].attack, pending)
        s:step(0.1); eq(s.combat[1].attack, nil)
        local accepted = 0
        for _, row in ipairs(s.logs) do if row.kind == "AttackAccepted" then accepted = accepted + 1 end end
        eq(accepted, 1)
    end)
    test("binding preserves current life, actor, reserve and both shield deadlines", function()
        for _, emergency in ipairs({false, true}) do
            local r, s, w, a, joined, removed, intent = binding()
            w.hazards[1] = "Fall"; s:step(0.1); w.safe = not emergency; s:step(0.2)
            local before = s.state.heroes[1]
            local actor, attempt, reserves, deadline = before.actorId, before.attempt, before.respawns, before.shield.deadline
            local epoch, life, held = before.connectionEpoch, s.combat[1].rawLife, w.actors[1].held
            eq(joined(a, 0.25), false); eq(s.state.heroes[1].connectionEpoch, epoch)
            local b = player(42); eq(joined(b, 0.3), true)
            local h = s.state.heroes[1]
            eq(h.actorId, actor); eq(h.attempt, attempt); eq(h.respawns, reserves)
            eq(h.shield.deadline, deadline); eq(s.combat[1].rawLife, life); eq(w.actors[1].held, held)
            eq(h.connectionEpoch, epoch + 2)
            local currentPacket = movePacket(s)
            eq(intent(a, currentPacket, 0.4), "STALE_PLAYER")
            eq(intent(b, currentPacket, 0.4), "OK")
            eq(removed(a, 0.5), false); eq(s.state.heroes[1].connected, true)
        end
    end)
    test("binding reconnects an offline dead hero with exactly one successful respawn", function()
        local r, s, w, a, joined, removed = binding()
        eq(removed(a, 0.1), true)
        w.hazards[1] = "Fall"; s:step(0.2); s:step(1)
        eq(s.state.heroes[1].status, "AwaitingRespawn"); eq(w.spawns, 1)
        eq(s.state.heroes[1].respawns, 3)
        local b = player(42); eq(joined(b, 1.1), true); s:step(1.2)
        eq(w.spawns, 2); eq(s.state.heroes[1].respawns, 2)
        eq(joined(b, 1.3), false); eq(removed(a, 1.3), false); s:step(1.4)
        eq(w.spawns, 2); eq(s.state.heroes[1].respawns, 2)
    end)

    print("ConnectionRegistry tests: " .. passed .. " PASS, " .. failed .. " FAIL")
    assert(failed == 0, "ConnectionRegistry contracts failed")
    return passed
end
