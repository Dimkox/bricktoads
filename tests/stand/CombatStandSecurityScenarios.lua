-- Test-only module injected beside the guarded Studio acceptance runner.
-- All adversarial commands originate on a real client; observer never handles them.
return function(ctx)
    assert(game:GetService("RunService"):IsStudio(), "Studio only")
    local service = game:GetService("StudioTestService")
    assert(service:GetTestArgs().tag == "CombatStandAcceptance", "Acceptance test only")
    local Players = game:GetService("Players")
    local intent = game:GetService("ReplicatedStorage").CombatStand.Intent
    local check, waitFor, dump = ctx.check, ctx.waitFor, ctx.dump
    local results, slots = ctx.results, ctx.slots
    local received, receipts = {}, {}
    local handlerErrors = {}
    results.handlerErrors = handlerErrors
    local errorListener = game:GetService("ScriptContext").Error:Connect(function(message, trace, source)
        handlerErrors[#handlerErrors + 1] = {message = tostring(message), trace = tostring(trace),
            source = source and source:GetFullName() or "unknown"}
    end)
    local listener = intent.OnServerEvent:Connect(function(player, payload)
        received[player] = (received[player] or 0) + 1
        local row = {player = player.UserId, at = workspace:GetServerTimeNow(), wireType = typeof(payload)}
        if type(payload) == "table" then
            row.kind = type(payload.kind) == "string" and payload.kind or typeof(payload.kind)
            if type(payload.seq) == "number" then
                row.seq = payload.seq == payload.seq and math.abs(payload.seq) < math.huge
                    and payload.seq or "non-finite"
            end
        end
        receipts[#receipts + 1] = row
    end)
    results.securityReceipts = receipts
    local seq = 0
    local function effectCounts(d)
        local counts = {0, 0, 0, 0, 0}
        local kinds = {AttackAccepted = 1, Hit = 2, ConfirmedDeath = 3, CommitSpawn = 4, SetHealth = 5}
        for _, row in ipairs(d.events) do
            local index = kinds[row.kind]
            if index then counts[index] = counts[index] + 1 end
        end
        return game:GetService("HttpService"):JSONEncode(counts)
    end
    local function packet(slot, kind, extras)
        local s = dump().snapshot
        local h = ctx.hero(s, slot)
        seq = seq + 1
        local p = {kind = kind or "Attack", runId = s.runId, actorId = h.actorId,
            attempt = h.attempt, levelEpoch = s.levelEpoch, connectionEpoch = h.connectionEpoch,
            seq = seq}
        if p.kind == "Attack" then p.attack = "Punch" end
        for key, value in pairs(extras or {}) do p[key] = value end
        return p
    end
    local function fingerprint(d)
        -- Ordered arrays avoid depending on JSON dictionary iteration order.
        local rows = {d.snapshot.runId, d.snapshot.levelEpoch, d.snapshot.status, {}}
        for _, h in ipairs(d.snapshot.heroes) do
            rows[4][#rows[4] + 1] = {h.slot, h.actorId or false, h.attempt,
                h.rawLife, h.respawns, h.status, h.connectionEpoch, h.connected, h.dying,
                h.shield or false, h.shieldUntil or false}
        end
        return game:GetService("HttpService"):JSONEncode(rows)
    end
    local function wire(name, player, payload, options, expectedCode, unchanged)
        local before = dump()
        local count = received[player] or 0
        local extra = {payload = payload}
        for k, v in pairs(options or {}) do extra[k] = v end
        ctx.send(player, "Raw", extra)
        waitFor(name .. " real server receipt", 5, function()
            return (received[player] or 0) > count, received[player] or 0
        end)
        local receivedAt = receipts[#receipts].at
        local driver = waitFor(name .. " authoritative State after processing", 5, function()
            local state = ctx.drivers[player] and ctx.drivers[player].state
            local snapshot = state and state.snapshot
            return snapshot and snapshot.now > receivedAt + 0.04, state
        end)
        local after = dump()
        if expectedCode then
            check(name .. " server rejection", expectedCode, driver.snapshot.notice,
                (expectedCode == "OK" and driver.snapshot.notice == nil)
                    or (expectedCode ~= "OK" and driver.snapshot.notice == expectedCode))
        end
        if unchanged ~= false then
            check(name .. " preserves authoritative resources and identity", fingerprint(before),
                fingerprint(after), fingerprint(before) == fingerprint(after))
            if expectedCode ~= "OK" then
                check(name .. " cannot produce accepted combat/spawn effects", effectCounts(before),
                    effectCounts(after), effectCounts(before) == effectCounts(after))
            end
        end
        check(name .. " no RemoteEvent handler error", 0, #handlerErrors, #handlerErrors == 0)
        results.scenarios[#results.scenarios + 1] = {name = name, expectedCode = expectedCode,
            observedNotice = driver.snapshot.notice, receipt = receipts[#receipts],
            before = before.snapshot, after = after.snapshot}
        return after
    end
    local function newRun(name)
        ctx.diagnostics:Invoke("Reset")
        ctx.send(ctx.host, "Start")
        waitFor(name .. " starts", 10, function()
            local ok, d = pcall(dump)
            return ok and d.snapshot.status == "Active" and #d.snapshot.heroes == 2, ok and d.snapshot
        end)
        ctx.idle(name)
        seq = 0
        for slot = 1, 2 do ctx.syncActor(slot, dump().snapshot) end
    end
    local function fanout(kind)
        -- Client 2 has no permission to Start. Neither Sync nor rejected Start
        -- needs a full-state fanout to unrelated client 1.
        task.wait(1.1) -- refill the existing bucket; bounded probe, not a load test
        local before = ctx.send(slots[1], "Inspect").state.stateReceived
        local startedAt = os.clock()
        local beforeDump = dump()
        local count = received[slots[2]] or 0
        ctx.send(slots[2], "Burst", {payload = {kind = kind}, count = 30})
        waitFor(kind .. " burst actually reached server", 5, function()
            return (received[slots[2]] or 0) >= count + 30, received[slots[2]] or 0
        end)
        task.wait(0.45)
        local after = ctx.send(slots[1], "Inspect").state.stateReceived
        local elapsed = os.clock() - startedAt
        local limit = math.ceil(elapsed / 0.1) + 6 -- periodic heartbeat + bounded queue/polling slack
        local row = {name = kind .. " no global amplification", received = after - before,
            elapsed = elapsed, periodicBudget = limit, sent = 30, before = beforeDump.snapshot,
            after = dump().snapshot}
        results.scenarios[#results.scenarios + 1] = row
        check(row.name, "unrelated client State count <= " .. limit, row, after - before <= limit)
        check(kind .. " burst cannot change run/resources", fingerprint(beforeDump),
            fingerprint(dump()), fingerprint(beforeDump) == fingerprint(dump()))
    end

    ctx.idle("security initial")
    fanout("Sync")
    fanout("Start")
    if ctx.phase == "fanout" then listener:Disconnect(); errorListener:Disconnect(); return end

    newRun("malformed inputs")
    local malformed = {
        {"string instead of table", "Attack"}, {"boolean instead of table", false},
        {"number instead of table", 47}, {"nil instead of table", false, {mode = "nil"}},
        {"Instance instead of table", false, {mode = "instance"}},
        {"missing kind", {}}, {"nested kind", {kind = {attack = "Punch"}}},
        {"unknown kind", {kind = "SetHealth", health = 5}},
        {"Start with forged health", {kind = "Start", health = 5}},
        {"Sync with extra data", {kind = "Sync", target = 1}},
    }
    for _, case in ipairs(malformed) do wire(case[1], slots[1], case[2], case[3]) end
    local cases = {
        {"nested field", {attack = {name = "Punch"}}, "INVALID_INTENT"},
        {"forged damage and target", {damage = 999, target = 2}, "INVALID_INTENT"},
        {"forged owner", {userId = 2}, "INVALID_INTENT"},
        {"client timestamp", {now = 0}, "INVALID_INTENT"},
        {"unknown attack", {attack = "Kill"}, "INVALID_INTENT"},
        {"oversize run", {runId = string.rep("x", 161)}, "INVALID_INTENT"},
        {"oversize actor", {actorId = string.rep("x", 161)}, "INVALID_INTENT"},
        {"wrong run", {runId = "forged-run"}, "WRONG_RUN"},
        {"other actor identity", {actorId = ctx.hero(dump().snapshot, 2).actorId}, "STALE_ACTOR"},
        {"stale attempt", {attempt = 99}, "STALE_ACTOR"},
        {"stale level", {levelEpoch = 99}, "STALE_ACTOR"},
        {"stale connection", {connectionEpoch = 99}, "STALE_CONNECTION"},
        {"negative sequence", {seq = -1}, "INVALID_INTENT"},
        {"fractional sequence", {seq = 1.5}, "INVALID_INTENT"},
        {"string sequence", {seq = "1"}, "INVALID_INTENT"},
        {"oversize sequence", {seq = 1000000001}, "INVALID_INTENT"},
    }
    for _, case in ipairs(cases) do wire(case[1], slots[1], packet(1, "Attack", case[2]), nil, case[3]) end
    for _, mode in ipairs({"nan", "infinity"}) do
        wire(mode .. " sequence", slots[1], packet(1), {mode = mode, field = "seq"}, "INVALID_INTENT")
        wire(mode .. " movement", slots[1], packet(1, "Move", {x = 0, z = 0}),
            {mode = mode, field = "x"}, "INVALID_INTENT")
    end
    wire("oversize movement", slots[1], packet(1, "Move", {x = 2, z = 0}), nil, "INVALID_INTENT")
    local missing = packet(1); missing.actorId = nil
    wire("missing actor", slots[1], missing, nil, "INVALID_INTENT")
    -- The actual sender is client 2; a complete stolen client 1 packet must fail.
    wire("cross-owner packet", slots[2], packet(1), nil, "STALE_ACTOR")
    wire("valid packet after malformed traffic in same run", slots[1],
        packet(1, "Move", {x = 0, z = 0}), nil, "OK")

    newRun("replay ordering")
    ctx.diagnostics:Invoke("Case", "Safe", 1, 2)
    local original = packet(1)
    wire("valid attack after invalid traffic", slots[1], original, nil, nil, false)
    waitFor("first accepted physical Hit", 5, function()
        local d = dump(); local count = 0
        for _, e in ipairs(d.events) do if e.kind == "Hit" then count = count + 1 end end
        return count == 1, d.snapshot
    end)
    ctx.idle("replay after cooldown")
    local eventCount = #dump().events
    wire("duplicate accepted attack after cooldown", slots[1], original, nil, "STALE_SEQUENCE")
    check("replay emits no second effect", eventCount, #dump().events, #dump().events == eventCount)
    local newest = packet(1, "Move", {x = 0, z = 0}); newest.seq = 100
    wire("newer movement accepted", slots[1], newest, nil, "OK")
    local older = packet(1); older.seq = 99
    wire("out of order attack", slots[1], older, nil, "STALE_SEQUENCE")
    local recovery = packet(1, "Move", {x = 0, z = 0}); recovery.seq = 101
    wire("valid sequence recovery", slots[1], recovery, nil, "OK")

    newRun("cooldown and limiter")
    ctx.diagnostics:Invoke("Case", "Safe", 1, 2)
    local before = dump()
    local burstReceiptCount = received[slots[1]] or 0
    ctx.send(slots[1], "Burst", {payload = packet(1), count = 120, increment = true})
    waitFor("all 120 Attack packets reached actual server", 5, function()
        return (received[slots[1]] or 0) >= burstReceiptCount + 120, received[slots[1]] or 0
    end)
    waitFor("burst has exactly one accepted attack", 5, function()
        local d = dump(); local accepted, hits = 0, 0
        for _, e in ipairs(d.events) do
            if e.kind == "AttackAccepted" then accepted = accepted + 1 end
            if e.kind == "Hit" then hits = hits + 1 end
        end
        return accepted == 1 and hits == 1, {accepted = accepted, hits = hits}
    end)
    local after = ctx.idle("limiter recovery")
    local accepted, hits = 0, 0
    for _, e in ipairs(after.events) do
        if e.kind == "AttackAccepted" then accepted = accepted + 1 end
        if e.kind == "Hit" then hits = hits + 1 end
    end
    check("complete attack burst has one effect after recovery", {accepted = 1, hits = 1},
        {accepted = accepted, hits = hits}, accepted == 1 and hits == 1)
    check("burst preserves identities/reserves and recovers Life", fingerprint(before),
        fingerprint(after), fingerprint(before) == fingerprint(after))
    task.wait(1.1)
    local valid = packet(1, "Move", {x = 0, z = 0}); valid.seq = 200
    wire("legitimate packet after burst", slots[1], valid, nil, "OK")
    check("burst recovery has no stale/cooldown/rate notice", "nil",
        ctx.drivers[slots[1]].state.snapshot.notice or "nil",
        ctx.drivers[slots[1]].state.snapshot.notice == nil)

    task.wait(1.1)
    local stateBefore = ctx.send(slots[2], "Inspect").state.stateReceived
    local probeStart = os.clock()
    local receiptBefore = received[slots[2]] or 0
    ctx.send(slots[2], "Burst", {payload = {kind = "Sync"}, count = 120})
    waitFor("all 120 Sync packets reached actual server", 5, function()
        return (received[slots[2]] or 0) >= receiptBefore + 120, received[slots[2]] or 0
    end)
    task.wait(0.25)
    local stateAfter = ctx.send(slots[2], "Inspect").state.stateReceived
    local elapsed = os.clock() - probeStart
    local maxDeliveries = 40 + math.ceil(elapsed * 50) + 6 -- 40/s bucket + 10/s heartbeat
    local probe = {sent = 120, receivedStates = stateAfter - stateBefore,
        elapsed = elapsed, limit = maxDeliveries}
    results.scenarios[#results.scenarios + 1] = {name = "Sync gateway rate limit", measurement = probe}
    check("Sync rate probe fast enough to distinguish rejection", "budget below 120", probe, maxDeliveries < 120)
    check("Sync flooding is bounded before response work", "State deliveries <= token/heartbeat budget", probe,
        stateAfter - stateBefore <= maxDeliveries)
    task.wait(1.1)

    -- Initial appearances are free and unshielded; cause a real Fall/respawn
    -- to obtain a genuine Normal shield, then try to cancel it with a bad command.
    local oldActor = ctx.hero(dump().snapshot, 1).actorId
    local genuineOldActor = packet(1)
    ctx.diagnostics:Invoke("Pose", 1, -12, -45, 0, 0)
    waitFor("new protected run", 10, function()
        local ok, d = pcall(dump)
        local h = ok and ctx.hero(d.snapshot, 1)
        return h and h.actorId ~= oldActor and h.shield == "Normal", ok and d.snapshot
    end)
    seq = 0
    wire("invalid attack cannot cancel Normal shield", slots[1], packet(1, "Attack", {attack = "Kill"}), nil, "INVALID_INTENT")
    wire("genuine previous actor packet after actual respawn", slots[1], genuineOldActor, nil, "STALE_ACTOR")
    local genuineOldRun = packet(1)

    -- Remove a real hero and add a genuinely new account; a fabricated member ID cannot enroll it.
    newRun("spectator authority")
    wire("genuine previous run packet after new game", slots[1], genuineOldRun, nil, "WRONG_RUN")
    local departing = slots[2]
    assert(departing.UserId < 0, "Only synthetic Studio clients may be removed")
    departing:Kick("BT-58 synthetic test client departure")
    waitFor("departing Player actually removed", 10, function()
        return departing.Parent ~= Players, #Players:GetPlayers()
    end)
    service:AddPlayers(1)
    local spectator
    waitFor("new spectator has real State", 25, function()
        for _, player in ipairs(Players:GetPlayers()) do
            local state = ctx.drivers[player] and ctx.drivers[player].state
            if player ~= slots[1] and player.UserId ~= departing.UserId and state and state.snapshot then
                spectator = player
                return state.slot == nil, {userId = player.UserId, name = player.Name}
            end
        end
        return false, "waiting for new account"
    end)
    wire("spectator cannot drive old owner", spectator, packet(2))
    wire("spectator cannot reset active run", spectator, {kind = "Start"}, nil, "HOST_ONLY")
    check("entire remote security run has no handler errors", 0, #handlerErrors, #handlerErrors == 0)
    listener:Disconnect()
    errorListener:Disconnect()
end
