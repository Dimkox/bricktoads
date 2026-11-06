-- Inject into ServerScriptService ONLY for StudioTestService:ExecuteMultiplayerTestAsync.
-- Launch args: {tag="CombatStandAcceptance", players=2|3, emergency=false,
--     protectionOnly=false, edgeDisconnectOnly=false, timeoutSeconds=180}.
-- Scene preparation is trusted Diagnostics; every Start/Attack goes through a real client's Intent.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local StudioTestService = game:GetService("StudioTestService")
local argsOK, args = pcall(function() return StudioTestService:GetTestArgs() end)
if not argsOK or type(args) ~= "table" or args.tag ~= "CombatStandAcceptance" then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local started = os.clock()
local timeout = math.clamp(tonumber(args.timeoutSeconds) or 180, 60, 240)
local results = {tag = args.tag, status = "RUNNING", players = args.players,
    mode = "Real Studio multiplayer RemoteEvent and physics; no human keyboard/touch automation",
    checks = {}, scenarios = {}, roundTrips = {}, skipped = {
        "Actual mobile/touch and human keyboard UI",
        "Same-user reconnect into the same live server",
        "Forged, replayed and out-of-order Intent beyond the single-Hit invariant (pure Session suite covers)",
        "Late-join spectator",
        "Dedicated wall/danger-surface and camera scenario matrix",
    }}
results.networkProfile = "Configured externally by launcher; measured real-client Command/Reply RTT is in roundTrips"
local finished = false
local diagnostics
local lastDump
local drivers, replies = {}, {}
local commandSerial = 0
local bridge = Instance.new("Folder")
bridge.Name = "CombatStandStudioAcceptance"
bridge.Parent = ReplicatedStorage
local command = Instance.new("RemoteEvent")
command.Name = "Command"; command.Parent = bridge
local reply = Instance.new("RemoteEvent")
reply.Name = "Reply"; reply.Parent = bridge

reply.OnServerEvent:Connect(function(player, message)
    if type(message) ~= "table" then return end
    if message.type == "Ready" and type(message.state) == "table" then
        drivers[player] = {state = message.state, receivedAt = workspace:GetServerTimeNow()}
    elseif message.type == "Reply" and type(message.id) == "number" then
        replies[message.id] = {player = player, message = message}
        if type(message.state) == "table" then
            drivers[player] = {state = message.state, receivedAt = workspace:GetServerTimeNow()}
        end
    end
end)

local function dump()
    lastDump = HttpService:JSONDecode(diagnostics:Invoke("Dump"))
    -- Diagnostics returns Session:snapshot(), which deliberately has no entry-point fault field.
    -- The real State remote adds that field; inspect the driver's latest received State instead.
    for _, player in ipairs(Players:GetPlayers()) do
        local driver = drivers[player]
        local snapshot = driver and driver.state and driver.state.snapshot
        if snapshot and snapshot.fault then
            error("Stand fault received by " .. player.Name .. ": " .. tostring(snapshot.fault))
        end
    end
    return lastDump
end

local function finish(status, failure)
    if finished then return end
    finished = true
    if diagnostics then
        local finalOK, finalFailure = pcall(dump)
        results.checks[#results.checks + 1] = {name = "final dump and client State fault check",
            expected = "readable dump and no fault in any connected driver's State snapshot",
            observed = finalOK and {runId = lastDump.snapshot.runId, status = lastDump.snapshot.status}
                or tostring(finalFailure), pass = finalOK, at = workspace:GetServerTimeNow()}
        if not finalOK then
            status = "FAIL"
            failure = (failure and tostring(failure) .. "\n" or "") .. "Final verification: " .. tostring(finalFailure)
        end
    end
    results.status = status
    results.error = failure
    results.elapsedSeconds = os.clock() - started
    results.lastDump = lastDump
    local passed, failed = 0, 0
    for _, row in ipairs(results.checks) do
        if row.pass then passed = passed + 1 else failed = failed + 1 end
    end
    results.summary = {passed = passed, failed = failed, scenarios = #results.scenarios}
    print("[BT-ACCEPTANCE] " .. status .. " " .. HttpService:JSONEncode(results.summary))
    StudioTestService:EndTest(results)
end

task.delay(timeout, function()
    if not finished then
        results.checks[#results.checks + 1] = {name = "overall watchdog", pass = false,
            expected = "complete within " .. timeout .. " seconds", observed = os.clock() - started}
        finish("FAIL", "Overall watchdog expired")
    end
end)

local function compact(value, depth)
    if type(value) ~= "table" then return value end
    depth = depth or 0
    if depth > 7 then return "[nested evidence retained in scenario/dump]" end
    local result = {}
    for key, item in pairs(value) do
        if key == "events" and type(item) == "table" then
            result.eventCount = #item
            local tail = {}
            for i = math.max(1, #item - 5), #item do tail[#tail + 1] = compact(item[i], depth + 1) end
            result.tailEvents = tail
        else result[key] = compact(item, depth + 1) end
    end
    return result
end

local function check(name, expected, observed, pass)
    if finished then error("Test already ended") end
    results.checks[#results.checks + 1] = {name = name, expected = expected,
        observed = compact(observed), pass = pass == true, at = workspace:GetServerTimeNow()}
    if not pass then error(name .. ": expected " .. HttpService:JSONEncode(expected)
        .. "; observed " .. HttpService:JSONEncode(observed), 2) end
end

local function waitFor(name, seconds, predicate, expected)
    local deadline = os.clock() + seconds
    local observed
    repeat
        if finished then error("Test already ended") end
        local ok, value = predicate()
        observed = value
        if ok then
            check(name, expected or "condition reached before timeout", value, true)
            return value
        end
        task.wait(0.04)
    until os.clock() >= deadline
    check(name, expected or "condition reached within " .. seconds .. " seconds", observed or "nil", false)
end

local function hero(snapshot, slot)
    for _, value in ipairs(snapshot.heroes) do if value.slot == slot then return value end end
    return nil
end

local function body(slot)
    local world = workspace:FindFirstChild("CombatStandWorld")
    local actors = world and world:FindFirstChild("Actors")
    if not actors then return nil end
    for _, model in ipairs(actors:GetChildren()) do
        if model:GetAttribute("Slot") == slot then
            local root = model:FindFirstChild("HumanoidRootPart")
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if root and humanoid then return model, root, humanoid end
        end
    end
    return nil
end

local function physical(slot)
    local model, root, humanoid = body(slot)
    if not model then return {slot = slot, missing = true} end
    local p, v = root.Position, root.AssemblyLinearVelocity
    local ownerOK, owner = pcall(function() return root:GetNetworkOwner() end)
    return {slot = slot, actorId = model:GetAttribute("ActorId"), model = model:GetFullName(),
        position = {p.X, p.Y, p.Z}, velocity = {v.X, v.Y, v.Z},
        anchored = root.Anchored, serverOwned = ownerOK and owner == nil,
        owner = ownerOK and (owner and owner.UserId or "server") or "unavailable while anchored",
        platformStand = humanoid.PlatformStand, humanoidHealth = humanoid.Health,
        humanoidState = humanoid:GetState().Name, floorMaterial = humanoid.FloorMaterial.Name,
        serverTime = workspace:GetServerTimeNow()}
end

local function allPhysical(snapshot)
    local rows = {}
    for _, h in ipairs(snapshot.heroes) do rows[#rows + 1] = physical(h.slot) end
    return rows
end

local function send(player, kind, extra)
    commandSerial = commandSerial + 1
    local id = commandSerial
    local message = {id = id, kind = kind}
    for key, value in pairs(extra or {}) do message[key] = value end
    local sentAt = os.clock()
    command:FireClient(player, message)
    local ack = waitFor("client command " .. id .. " " .. kind, 8, function()
        local received = replies[id]
        return received ~= nil, received and received.message
    end, "real client reply")
    check("command " .. id .. " sender", player.UserId,
        replies[id].player.UserId, replies[id].player == player)
    replies[id] = nil
    check("command " .. id .. " sent", true, {ok = ack.ok, error = ack.error, packet = ack.packet}, ack.ok == true)
    results.roundTrips[#results.roundTrips + 1] = {command = kind, id = id,
        playerUserId = player.UserId, seconds = os.clock() - sentAt,
        measurement = "server Command to real client Reply, including polling resolution"}
    return ack
end

local rosterPlayers, slotPlayers, host = {}, {}, nil
local expectedPlayers = tonumber(args.players)
local function freshStart(name)
    send(host, "Start")
    local d = waitFor(name .. " initial bodies", 15, function()
        -- Reply and Intent are separate remotes; observing the reply must not assume Start was handled first.
        local ready, state = pcall(dump)
        if not ready then return false, {waitingForStart = tostring(state)} end
        if state.snapshot.status ~= "Active" or #state.snapshot.heroes ~= expectedPlayers then return false, state end
        for _, h in ipairs(state.snapshot.heroes) do
            if h.status ~= "Alive" or not h.actorId then return false, state end
        end
        return true, state
    end)
    waitFor(name .. " actual slot mappings", 10, function()
        local mapped, detail = {}, {}
        for _, player in ipairs(rosterPlayers) do
            local row = drivers[player]
            local state = row and row.state
            local snap = state and state.snapshot
            detail[#detail + 1] = {userId = player.UserId, slot = state and state.slot,
                runId = snap and snap.runId, host = state and state.host}
            if not state or not snap or snap.runId ~= d.snapshot.runId or not state.slot
                or state.host ~= host.UserId or mapped[state.slot] then return false, detail end
            mapped[state.slot] = player
        end
        slotPlayers = mapped
        for slot = 1, expectedPlayers do if not mapped[slot] then return false, detail end end
        return true, detail
    end)
    return d
end

local function afterMarker(row, marker)
    return row.now >= marker.now and row.revision > marker.revision
end

local function idle(name)
    return waitFor(name .. " alive idle without shields", 12, function()
        local d = dump()
        local now = workspace:GetServerTimeNow()
        for _, h in ipairs(d.snapshot.heroes) do
            local p = physical(h.slot)
            if h.status ~= "Alive" or h.shield or h.dying or p.missing or p.platformStand then return false, d end
        end
        -- Diagnostics also checks c.attack/reactionEnd; cooldown is not exposed in snapshots.
        for _, event in ipairs(d.events) do
            if event.kind == "AttackAccepted" then
                local cooldown = event.data.action == "Dash" and 1 or 0.55
                if now < event.now + cooldown + 0.05 then return false, d end
            end
        end
        return true, d
    end)
end

local function syncActor(slot, snapshot)
    local wanted = hero(snapshot, slot)
    return waitFor("P" .. slot .. " current client actor identity", 8, function()
        local row = drivers[slotPlayers[slot]]
        local data = row and row.state.snapshot
        local h = data and hero(data, slot)
        local matches = h and data.runId == snapshot.runId and data.levelEpoch == snapshot.levelEpoch
            and h.actorId == wanted.actorId and h.attempt == wanted.attempt
            and h.connectionEpoch == wanted.connectionEpoch
        return matches == true, h
    end)
end

local function eventList(d, marker, predicate)
    local rows = {}
    for _, event in ipairs(d.events) do
        if afterMarker(event, marker) and predicate(event) then rows[#rows + 1] = event end
    end
    return rows
end

local function runPair(attacker, target, caseName, action, profile, before, after, dying)
    local name = "P" .. attacker .. "->P" .. target .. " " .. caseName .. " " .. action
    idle(name)
    for slot = 1, expectedPlayers do
        if slot ~= attacker and slot ~= target then diagnostics:Invoke("Pose", slot, -20, 3, -8, 0) end
    end
    local preparation = diagnostics:Invoke("Case", caseName, attacker, target)
    check(name .. " trusted preparation", "OK", preparation, preparation == "OK")
    -- Allow one physics step after server-side pose, then read actual scene/identity.
    task.wait(0.08)
    local prepared = dump()
    local old = hero(prepared.snapshot, target)
    local last = prepared.events[#prepared.events]
    local marker = {now = prepared.snapshot.now, revision = last.revision}
    local scene = {name = name, attacker = attacker, target = target, case = caseName,
        before = prepared.snapshot, beforeBodies = allPhysical(prepared.snapshot), marker = marker}
    results.scenarios[#results.scenarios + 1] = scene
    check(name .. " initial raw Life", before, old.rawLife, old.rawLife == before)
    syncActor(attacker, prepared.snapshot)
    local ack = send(slotPlayers[attacker], "Attack", {attack = action})
    scene.intent = ack.packet
    local hitEvidence = waitFor(name .. " real Hit", 4, function()
        local d = dump()
        local hits = eventList(d, marker, function(e)
            return e.kind == "Hit" and e.userId == target and e.data.attacker == attacker and e.data.action == action
        end)
        if #hits > 0 then return true, {hit = hits[1], snapshot = d.snapshot, physical = physical(target)} end
        return false, {snapshot = d.snapshot, events = d.events}
    end)
    scene.hit = hitEvidence.hit
    scene.hitSnapshot = hitEvidence.snapshot
    local data = hitEvidence.hit.data
    check(name .. " combat result", {profile = profile, before = before, after = after,
        dying = dying, blocked = false, impulse = true}, data,
        data.profile == profile and data.before == before and data.after == after
        and data.dying == dying and data.blocked == false and data.impulse == true)
    check(name .. " hit actor identity", old.actorId, hitEvidence.hit.actorId,
        hitEvidence.hit.actorId == old.actorId)
    local observed = data.observed
    check(name .. " observed real body", "position/velocity vectors and unheld body", observed,
        type(observed) == "table" and type(observed.position) == "table" and #observed.position == 3
        and type(observed.velocity) == "table" and #observed.velocity == 3 and observed.held == false)
    scene.bodySamples = {hitEvidence.physical}
    for _ = 1, 5 do task.wait(0.025); scene.bodySamples[#scene.bodySamples + 1] = physical(target) end
    local maxHorizontal, maxUpward = 0, -math.huge
    for _, p in ipairs(scene.bodySamples) do
        if not p.missing and p.actorId == old.actorId then
            maxHorizontal = math.max(maxHorizontal, math.sqrt(p.velocity[1]^2 + p.velocity[3]^2))
            maxUpward = math.max(maxUpward, p.velocity[2])
        end
    end
    check(name .. " physical impulse motion", "horizontal speed >0.1; Dash upward speed >0.1",
        {maxHorizontal = maxHorizontal, maxUpward = maxUpward},
        maxHorizontal > 0.1 and (action ~= "Dash" or maxUpward > 0.1))
    check(name .. " server physical ownership", true, hitEvidence.physical,
        hitEvidence.physical.serverOwned == true and hitEvidence.physical.actorId == old.actorId)
    if dying then
        local during = hero(hitEvidence.snapshot, target)
        check(name .. " delayed death stage", {status = "Alive", rawLife = 0, dying = true}, during,
            during.status == "Alive" and during.rawLife == 0 and during.dying == true)
        local respawn = waitFor(name .. " confirmed death and ordinary respawn", 6, function()
            local d = dump()
            local h = hero(d.snapshot, target)
            local deaths = eventList(d, marker, function(e)
                return e.kind == "ConfirmedDeath" and e.userId == target and e.data.reason == "CombatUnderflow"
            end)
            return h.status == "Alive" and h.actorId ~= old.actorId and #deaths > 0,
                {hero = h, deaths = deaths, snapshot = d.snapshot, events = d.events}
        end)
        scene.respawn = {hero = respawn.hero, deaths = respawn.deaths, snapshot = respawn.snapshot}
        local h = respawn.hero
        check(name .. " exactly one reserve spent", old.respawns - 1, h.respawns, h.respawns == old.respawns - 1)
        check(name .. " one new actor attempt", old.attempt + 1, h,
            h.attempt == old.attempt + 1 and h.actorId ~= old.actorId)
        check(name .. " ordinary shield and restored raw Life", {shield = "Normal", rawLife = 47}, h,
            h.shield == "Normal" and h.rawLife == 47 and h.shieldUntil > respawn.snapshot.now)
        check(name .. " one confirmed death", 1, #respawn.deaths, #respawn.deaths == 1)
        local commit
        for _, e in ipairs(respawn.events) do
            if afterMarker(e, marker) and e.kind == "CommitSpawn" and e.userId == target then commit = e end
        end
        check(name .. " ordinary shield duration", 2,
            commit and h.shieldUntil - commit.now or "missing CommitSpawn",
            commit ~= nil and math.abs(h.shieldUntil - commit.now - 2) < 0.01)
    end
    local settled = idle(name .. " settle")
    scene.after = settled.snapshot
    scene.afterBodies = allPhysical(settled.snapshot)
    local h = hero(settled.snapshot, target)
    if not dying then
        local expectedLife = action == "Punch" and 47 or after
        check(name .. " settled raw Life and unchanged resources", {rawLife = expectedLife,
            actorId = old.actorId, attempt = old.attempt, respawns = old.respawns}, h,
            h.rawLife == expectedLife and h.actorId == old.actorId
            and h.attempt == old.attempt and h.respawns == old.respawns)
    end
    local hits = eventList(settled, marker, function(e) return e.kind == "Hit" end)
    scene.actionEvents = eventList(settled, marker, function() return true end)
    check(name .. " single Hit for single attack", 1, hits, #hits == 1
        and hits[1].userId == target and hits[1].data.attacker == attacker)
    print("[BT-ACCEPTANCE] scenario PASS " .. name)
end

local function resetAndStart(name)
    local reset = diagnostics:Invoke("Reset")
    check(name .. " diagnostic reset", "LOBBY", reset, reset == "LOBBY")
    return freshStart(name)
end

local function edgeDisconnectScenarios()
    local function markerOf(d)
        return {now = d.snapshot.now, revision = d.events[#d.events].revision}
    end
    local function parkThird()
        for slot = 3, expectedPlayers do diagnostics:Invoke("Pose", slot, -20, 3, -8, 0) end
    end
    local edge = {name = "Unmodified Edge scene: stable target, real Punch and actual Fall"}
    results.scenarios[#results.scenarios + 1] = edge
    -- An experimental edge-scene failure must remain FAIL, but should not hide the
    -- independent disconnect test. Reset below prepares that next scenario even on failure.
    local edgeOK, edgeFailure = xpcall(function()
        idle("Edge preparation")
        parkThird()
        local preparedCode = diagnostics:Invoke("Case", "Edge", 1, 2)
        check("Edge trusted unmodified scene", "OK", preparedCode, preparedCode == "OK")
        local prepared = dump()
        local prior = hero(prepared.snapshot, 2)
        local marker = markerOf(prepared)
        edge.before = {snapshot = prepared.snapshot, bodies = allPhysical(prepared.snapshot)}
        edge.preparation = {kind = "Diagnostics Case", case = "Edge", attacker = 1, target = 2,
            geometryAdjusted = false}
        task.wait(0.4)
        local stable = dump()
        local target, targetBody = hero(stable.snapshot, 2), physical(2)
        local prematureDeaths = eventList(stable, marker, function(e)
            return e.userId == 2 and (e.kind == "Death" or e.kind == "ConfirmedDeath")
        end)
        edge.stableBeforeAttack = {snapshot = stable.snapshot, body = targetBody, deaths = prematureDeaths}
        check("Edge target stable for0.4sec before attack", "same alive actor, rootY>0, no death", edge.stableBeforeAttack,
            target.status == "Alive" and target.actorId == prior.actorId and not targetBody.missing
            and targetBody.position[2] > 0 and #prematureDeaths == 0)
        syncActor(1, stable.snapshot)
        edge.intent = send(slotPlayers[1], "Attack", {attack = "Punch"}).packet
        local contact = waitFor("Edge actual Punch Hit", 3, function()
            local d = dump()
            local hits = eventList(d, marker, function(e)
                return e.kind == "Hit" and e.userId == 2 and e.data.attacker == 1 and e.data.action == "Punch"
            end)
            return #hits > 0, {hit = hits[1], snapshot = d.snapshot, body = physical(2), events = d.events}
        end)
        edge.hit = contact.hit
        edge.hitSnapshot = contact.snapshot
        edge.hitBody = contact.body
        local data = contact.hit.data
        check("Edge profile18 real raw47->43", {profile = 18, before = 47, after = 43, blocked = false, impulse = true},
            data, data.profile == 18 and data.before == 47 and data.after == 43
                and data.blocked == false and data.impulse == true)
        local fall = waitFor("Edge actual Fall and respawn within4sec after contact", 4, function()
            local d = dump()
            local h = hero(d.snapshot, 2)
            local falls = eventList(d, marker, function(e)
                return e.kind == "ConfirmedDeath" and e.userId == 2 and e.data.reason == "Fall"
                    and e.now > contact.hit.now
            end)
            return #falls == 1 and h.status == "Alive" and h.actorId ~= prior.actorId,
                {hero = h, falls = falls, snapshot = d.snapshot, body = physical(2), events = d.events}
        end)
        edge.fallAndRespawn = {hero = fall.hero, falls = fall.falls, snapshot = fall.snapshot, body = fall.body}
        edge.actionEvents = eventList({events = fall.events}, marker, function() return true end)
        check("Edge actual Fall costs exactly one reserve", {respawns = prior.respawns - 1, attempt = prior.attempt + 1},
            fall.hero, fall.hero.respawns == prior.respawns - 1 and fall.hero.attempt == prior.attempt + 1
                and fall.hero.actorId ~= prior.actorId and fall.hero.shield == "Normal")
    end, debug.traceback)
    edge.status = edgeOK and "PASS" or "FAIL"
    edge.error = not edgeOK and tostring(edgeFailure) or nil

    local initial = resetAndStart("real disconnect")
    idle("real disconnect preparation")
    parkThird()
    local preparation = diagnostics:Invoke("Case", "Safe", 2, 1)
    check("disconnect trusted scene P2 attacks P1", "OK", preparation, preparation == "OK")
    task.wait(0.08)
    local prepared = dump()
    local marker = markerOf(prepared)
    local oldOffline = hero(prepared.snapshot, 2)
    local departing = slotPlayers[2]
    local scene = {name = "Real synthetic Studio P2 removal and pending attack timing",
        before = {snapshot = prepared.snapshot, bodies = allPhysical(prepared.snapshot)},
        departingActualPlayer = {userId = departing.UserId, name = departing.Name}, initialRunId = initial.snapshot.runId}
    results.scenarios[#results.scenarios + 1] = scene
    check("Kick fixture limited to synthetic Studio client", true,
        {isStudio = RunService:IsStudio(), userId = departing.UserId, tag = args.tag},
        RunService:IsStudio() and departing.UserId < 0 and args.tag == "CombatStandAcceptance")
    syncActor(2, prepared.snapshot)
    local attackReply = send(departing, "Attack", {attack = "Punch"})
    scene.intent = attackReply.packet
    local acceptedBeforeKick = waitFor("P2 real Punch accepted before synthetic-client Kick", 2, function()
        local d = dump()
        local accepted = eventList(d, marker, function(e)
            return e.kind == "AttackAccepted" and e.userId == 2 and e.data.action == "Punch"
        end)
        return #accepted == 1, {accepted = accepted, snapshot = d.snapshot}
    end)
    scene.acceptedBeforeKick = acceptedBeforeKick
    scene.removal = {method = "server-initiated Kick of syntheticStudio client",
        calledAt = workspace:GetServerTimeNow(), playerUserId = departing.UserId,
        reason = "CombatStand Studio acceptance", runtimeWindupChanged = false}
    departing:Kick("CombatStand Studio acceptance")
    local disconnected = waitFor("real P2 Player removal and offline hero body", 8, function()
        local d = dump()
        local h, b = hero(d.snapshot, 2), physical(2)
        local present = false
        local playerRows = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player == departing then present = true end
            playerRows[#playerRows + 1] = {userId = player.UserId, name = player.Name}
        end
        local connections = eventList(d, marker, function(e)
            return e.kind == "Connection" and e.userId == 2 and e.data.code == "OK"
        end)
        return not present and h.connected == false and #connections == 1 and b.actorId == oldOffline.actorId,
            {hero = h, body = b, connections = connections, snapshot = d.snapshot, players = playerRows, events = d.events}
    end)
    scene.disconnected = {hero = disconnected.hero, body = disconnected.body,
        connections = disconnected.connections, snapshot = disconnected.snapshot, players = disconnected.players}
    local connection = disconnected.connections[1]
    check("offline P2 retained actor attempt reserve and Life", oldOffline, scene.disconnected,
        disconnected.hero.actorId == oldOffline.actorId and disconnected.hero.attempt == oldOffline.attempt
        and disconnected.hero.respawns == oldOffline.respawns and disconnected.hero.rawLife == oldOffline.rawLife
        and disconnected.hero.connectionEpoch == oldOffline.connectionEpoch + 1
        and disconnected.hero.status == "Alive" and disconnected.body.serverOwned == true)
    local delayed = waitFor("P2 actual Punch Hit and acceptance timestamps", 3, function()
        local d = dump()
        local hits = eventList(d, marker, function(e)
            return e.kind == "Hit" and e.userId == 1 and e.data.attacker == 2 and e.data.action == "Punch"
        end)
        local accepted = eventList(d, marker, function(e)
            return e.kind == "AttackAccepted" and e.userId == 2 and e.data.action == "Punch"
        end)
        return #hits == 1 and #accepted == 1, {hits = hits, accepted = accepted,
            snapshot = d.snapshot, offlineBody = physical(2), targetBody = physical(1), events = d.events}
    end)
    scene.delayedHit = {hits = delayed.hits, accepted = delayed.accepted, snapshot = delayed.snapshot,
        offlineBody = delayed.offlineBody, targetBody = delayed.targetBody}
    local hit = delayed.hits[1]
    local windowMet = delayed.accepted[1].now <= connection.now and connection.now < hit.now
    scene.timing = {attackAccepted = delayed.accepted[1].now, kickCalled = scene.removal.calledAt,
        actualConnection = connection.now, actualHit = hit.now, pendingAttackPreconditionMet = windowMet}
    -- A slow Studio removal is a fixture limitation. Preserve its failed precondition,
    -- then execute the independent offline-target damage case before returning FAIL.
    local pendingOK, pendingFailure = xpcall(function()
        check("delayed real Punch resolves after actual disconnect", "accept<=disconnect<Hit; same offline actor",
            {timing = scene.timing, hit = scene.delayedHit}, windowMet
            and delayed.accepted[1].actorId == oldOffline.actorId and delayed.offlineBody.actorId == oldOffline.actorId
            and hit.data.profile == 18 and hit.data.before == 47 and hit.data.after == 43
            and hit.data.blocked == false and hit.data.impulse == true)
    end, debug.traceback)
    scene.pendingAttackStatus = pendingOK and "PASS" or (windowMet and "FAIL" or "NOT RUN: Studio removal missed pending-hit window")
    scene.status = pendingOK and "PASS" or "FAIL"
    scene.error = not pendingOK and tostring(pendingFailure) or nil
    if not windowMet then
        results.skipped[#results.skipped + 1] = "Pending attack after actual disconnect: Studio removal did not precede real Hit"
    end
    local offlineScene = {name = "Real P1 Punch damages retained offline P2 body",
        offlineHeroBefore = disconnected.hero, removal = scene.removal}
    results.scenarios[#results.scenarios + 1] = offlineScene
    idle("offline body follow-up preparation")
    preparation = diagnostics:Invoke("Case", "Safe", 1, 2)
    check("trusted scene may position existing offline target", "OK", preparation, preparation == "OK")
    prepared = dump()
    marker = markerOf(prepared)
    local beforeHit = hero(prepared.snapshot, 2)
    check("offline target has no new actor or healing before follow-up", oldOffline, beforeHit,
        beforeHit.connected == false and beforeHit.actorId == oldOffline.actorId
        and beforeHit.attempt == oldOffline.attempt and beforeHit.respawns == oldOffline.respawns
        and beforeHit.rawLife == oldOffline.rawLife)
    syncActor(1, prepared.snapshot)
    offlineScene.intent = send(slotPlayers[1], "Attack", {attack = "Punch"}).packet
    local damaged = waitFor("real P1 Punch damages offline P2 body", 3, function()
        local d = dump()
        local hits = eventList(d, marker, function(e)
            return e.kind == "Hit" and e.userId == 2 and e.data.attacker == 1 and e.data.action == "Punch"
        end)
        return #hits == 1, {hits = hits, hero = hero(d.snapshot, 2), snapshot = d.snapshot,
            body = physical(2), events = d.events}
    end)
    offlineScene.offlineDamage = {hits = damaged.hits, hero = damaged.hero, snapshot = damaged.snapshot, body = damaged.body}
    local data = damaged.hits[1].data
    check("offline P2 actually takes raw47->43 with same body and resources", {rawLife = 43, connected = false,
        actorId = oldOffline.actorId, attempt = oldOffline.attempt, respawns = oldOffline.respawns}, offlineScene.offlineDamage,
        data.profile == 18 and data.before == 47 and data.after == 43 and data.blocked == false and data.impulse == true
        and damaged.hero.rawLife == 43 and damaged.hero.connected == false and damaged.hero.actorId == oldOffline.actorId
        and damaged.hero.attempt == oldOffline.attempt and damaged.hero.respawns == oldOffline.respawns
        and damaged.body.actorId == oldOffline.actorId and damaged.body.serverOwned == true)
    offlineScene.actionEvents = eventList({events = damaged.events}, marker, function() return true end)
    local activePlayers = Players:GetPlayers()
    local originalPlayers, playerRows, noNewPlayer = {}, {}, true
    for _, player in ipairs(rosterPlayers) do originalPlayers[player] = true end
    for _, player in ipairs(activePlayers) do
        playerRows[#playerRows + 1] = {userId = player.UserId, name = player.Name}
        if player == departing or not originalPlayers[player] then noNewPlayer = false end
    end
    check("disconnect run retains fixed roster without new Player", {players = expectedPlayers - 1, heroes = expectedPlayers},
        {players = playerRows, snapshot = damaged.snapshot}, #activePlayers == expectedPlayers - 1
        and #damaged.snapshot.heroes == expectedPlayers and noNewPlayer)
    offlineScene.status = "PASS"
    idle("actual AddPlayers capability preparation")
    local lifePreparation = diagnostics:Invoke("Life", 2, 31)
    check("trusted offline P2 raw31 before actual AddPlayers", "OK", lifePreparation, lifePreparation == "OK")
    local beforeAdd = dump()
    local preserved = hero(beforeAdd.snapshot, 2)
    check("AddPlayers precondition is existing offline injured actor", {connected = false, rawLife = 31}, preserved,
        preserved.connected == false and preserved.rawLife == 31 and preserved.status == "Alive"
        and preserved.actorId == oldOffline.actorId and preserved.attempt == oldOffline.attempt
        and preserved.respawns == oldOffline.respawns)
    local addScene = {name = "Actual Studio AddPlayers identity and fixed-roster capability",
        identityScope = "Real Studio synthetic Players; registered-account reconnect and public-server routing are not exercised",
        preparation = {kind = "Diagnostics Life", slot = 2, rawLife = 31},
        before = {snapshot = beforeAdd.snapshot, bodies = allPhysical(beforeAdd.snapshot)},
        departedUserId = departing.UserId,
        invocation = {method = "StudioTestService:AddPlayers(1)", calledAt = workspace:GetServerTimeNow()}}
    results.scenarios[#results.scenarios + 1] = addScene
    local beforePlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do beforePlayers[player] = true end
    local addOutcome = {complete = false}
    task.spawn(function()
        local called, value = pcall(function() return StudioTestService:AddPlayers(1) end)
        addOutcome.complete = true
        addOutcome.ok = called
        addOutcome.returnType = typeof(value)
        addOutcome.value = value == nil and "nil" or tostring(value)
        addOutcome.completedAt = workspace:GetServerTimeNow()
    end)
    local addedPlayer
    local actualJoin = waitFor("actual AddPlayers creates one real new Player", 60, function()
        if addOutcome.complete and not addOutcome.ok then error("Studio AddPlayers failed: " .. addOutcome.value) end
        local additions, details = {}, {}
        for _, player in ipairs(Players:GetPlayers()) do
            if not beforePlayers[player] then additions[#additions + 1] = player end
            details[#details + 1] = {userId = player.UserId, name = player.Name}
        end
        if #additions == 1 then addedPlayer = additions[1] end
        return #additions == 1, {players = details, newPlayerCount = #additions,
            addedUserId = addedPlayer and addedPlayer.UserId, observedAt = workspace:GetServerTimeNow(), invocation = addOutcome}
    end)
    addScene.actualJoin = actualJoin
    addScene.invocationResult = addOutcome
    local driver = waitFor("actual added Player driver receives current State", 30, function()
        local row = drivers[addedPlayer]
        local state = row and row.state
        local snapshot = state and state.snapshot
        return snapshot ~= nil and snapshot.runId == beforeAdd.snapshot.runId and state.presentationDisabled == true,
            {userId = addedPlayer.UserId, name = addedPlayer.Name, driver = state}
    end)
    addScene.driver = driver
    local afterAdd = dump()
    local afterHero = hero(afterAdd.snapshot, 2)
    addScene.after = {snapshot = afterAdd.snapshot, bodies = allPhysical(afterAdd.snapshot)}
    local sameActorResources = afterHero.actorId == preserved.actorId and afterHero.attempt == preserved.attempt
        and afterHero.respawns == preserved.respawns and afterHero.rawLife == 31
    check("AddPlayers preserves fixed hero roster", expectedPlayers, afterAdd.snapshot,
        #afterAdd.snapshot.heroes == expectedPlayers and #Players:GetPlayers() == expectedPlayers)
    local function removeSkip(text)
        for i = #results.skipped, 1, -1 do
            if results.skipped[i] == text then table.remove(results.skipped, i) end
        end
    end
    if addedPlayer.UserId == departing.UserId then
        check("actual same-user rejoin preserves injured actor and resources", preserved,
            {hero = afterHero, driver = driver}, sameActorResources and afterHero.connected == true
                and afterHero.connectionEpoch == preserved.connectionEpoch + 1
                and driver.driver.slot == 2 and driver.driver.snapshot.mine == 2)
        addScene.sameUserRejoin = {status = "PASS", actualUserId = addedPlayer.UserId,
            departedUserId = departing.UserId, hero = afterHero}
        addScene.lateJoinSpectator = {status = "NOT RUN", reason = "AddPlayers reused the departed owner's actual UserId"}
        removeSkip("Same-user reconnect into the same live server")
    else
        check("actual new-user late join remains spectator", {mine = "nil", heroes = expectedPlayers}, driver,
            driver.driver.slot == nil and driver.driver.snapshot.mine == nil
                and #driver.driver.snapshot.heroes == expectedPlayers)
        check("late join preserves original offline injured actor", preserved, afterHero,
            sameActorResources and afterHero.connected == false
                and afterHero.connectionEpoch == preserved.connectionEpoch)
        addScene.lateJoinSpectator = {status = "PASS", actualNewUserId = addedPlayer.UserId,
            departedUserId = departing.UserId, originalOfflineHero = afterHero}
        addScene.sameUserRejoin = {status = "NOT RUN", reason = "AddPlayers supplied a different actual UserId",
            actualNewUserId = addedPlayer.UserId, departedUserId = departing.UserId}
        removeSkip("Late-join spectator")
    end
    addScene.status = "PASS"
    results.edgeDisconnectFinalDump = dump()
    if not pendingOK then error("Pending-attack disconnect fixture did not pass; independent offline-body damage executed: " .. tostring(pendingFailure)) end
    if not edgeOK then error("Unmodified Edge scene failed; independent disconnect scenario executed: " .. tostring(edgeFailure)) end
end

local function protectionScenarios()
    local function markerOf(d)
        local last = d.events[#d.events]
        return {now = d.snapshot.now, revision = last.revision}
    end
    local function sameResources(a, b)
        return a.actorId == b.actorId and a.attempt == b.attempt and a.respawns == b.respawns
            and a.rawLife == b.rawLife
    end
    local function protectedHit(name, marker)
        return waitFor(name .. " actual protected Hit", 3, function()
            local d = dump()
            local rows = eventList(d, marker, function(e)
                return e.kind == "Hit" and e.userId == 2 and e.data.attacker == 1 and e.data.action == "Punch"
            end)
            return #rows > 0, {hit = rows[1], snapshot = d.snapshot, body = physical(2), events = d.events}
        end)
    end

    local initial = resetAndStart("Normal protection")
    idle("Normal protection preparation")
    for slot = 3, expectedPlayers do diagnostics:Invoke("Pose", slot, -20, 3, -8, 0) end
    local prior = hero(initial.snapshot, 2)
    local dangerMarker = markerOf(initial)
    local prep = diagnostics:Invoke("Pose", 2, -8, 3, 12, 0)
    check("Normal protection trusted danger pose", "OK", prep, prep == "OK")
    local respawn = waitFor("Normal protection actual surface death and respawn", 8, function()
        local d = dump()
        local h = hero(d.snapshot, 2)
        local deaths = eventList(d, dangerMarker, function(e)
            return e.kind == "ConfirmedDeath" and e.userId == 2 and e.data.reason == "Surface"
        end)
        return h.status == "Alive" and h.shield == "Normal" and h.actorId ~= prior.actorId and #deaths == 1,
            {hero = h, snapshot = d.snapshot, body = physical(2), deaths = deaths, events = d.events}
    end)
    local normal = {name = "Normal protected target and own attack shield cancellation",
        preparation = {kind = "Diagnostics Pose", slot = 2, position = {-8, 3, 12}, yaw = 0},
        respawn = {hero = respawn.hero, body = respawn.body, snapshot = respawn.snapshot, deaths = respawn.deaths}}
    results.scenarios[#results.scenarios + 1] = normal
    check("Normal protection real respawn resources", {rawLife = 47, reserve = prior.respawns - 1,
        attempt = prior.attempt + 1}, respawn.hero,
        respawn.hero.rawLife == 47 and respawn.hero.respawns == prior.respawns - 1
        and respawn.hero.attempt == prior.attempt + 1)
    local p = respawn.body.position
    -- The attacker remains idle and unshielded, so only its pose uses Diagnostics.
    prep = diagnostics:Invoke("Pose", 1, p[1] - 5, 3, p[3], -90)
    check("Normal protection trusted attacker pose", "OK", prep, prep == "OK")
    local prepared = dump()
    normal.beforeHit = {snapshot = prepared.snapshot, bodies = allPhysical(prepared.snapshot)}
    local marker = markerOf(prepared)
    syncActor(1, prepared.snapshot)
    normal.intent = send(slotPlayers[1], "Attack", {attack = "Punch"}).packet
    local hit = protectedHit("Normal protection", marker)
    normal.hit = hit.hit
    normal.hitSnapshot = hit.snapshot
    normal.bodySamples = {hit.body}
    local data = hit.hit.data
    check("Normal protected hit blocks damage and permits impulse",
        {profile = 18, before = 47, after = 47, blocked = true, impulse = true, dying = false}, data,
        data.profile == 18 and data.before == 47 and data.after == 47 and data.blocked == true
        and data.impulse == true and data.dying == false)
    local hitHero = hero(hit.snapshot, 2)
    check("Normal protected hit retains target actor and reserves", respawn.hero, hitHero,
        sameResources(respawn.hero, hitHero) and hitHero.shield == "Normal"
        and hit.body.actorId == respawn.hero.actorId and hit.body.anchored == false and hit.body.serverOwned == true)
    for _ = 1, 3 do task.wait(0.025); normal.bodySamples[#normal.bodySamples + 1] = physical(2) end
    local maxHorizontal = 0
    for _, sample in ipairs(normal.bodySamples) do
        if sample.velocity then
            maxHorizontal = math.max(maxHorizontal, math.sqrt(sample.velocity[1]^2 + sample.velocity[3]^2))
        end
    end
    check("Normal protected target actual impulse motion", "horizontal speed >0.1", maxHorizontal, maxHorizontal > 0.1)
    local ready = waitFor("Normal target reaction ends before shield deadline", 1.5, function()
        local d = dump()
        local h, b = hero(d.snapshot, 2), physical(2)
        return h.status == "Alive" and h.shield == "Normal" and not b.platformStand
            and workspace:GetServerTimeNow() < respawn.hero.shieldUntil,
            {snapshot = d.snapshot, hero = h, body = b, events = d.events}
    end)
    marker = markerOf(ready)
    syncActor(2, ready.snapshot)
    normal.ownIntent = send(slotPlayers[2], "Attack", {attack = "Punch"}).packet
    local cancelled = waitFor("Normal target own real attack clears shield", 2, function()
        local d = dump()
        local h = hero(d.snapshot, 2)
        local attacks = eventList(d, marker, function(e)
            return e.kind == "AttackAccepted" and e.userId == 2 and e.data.action == "Punch"
        end)
        return #attacks == 1 and not h.shield, {hero = h, snapshot = d.snapshot,
            attacks = attacks, body = physical(2), events = d.events}
    end)
    normal.cancelled = {hero = cancelled.hero, snapshot = cancelled.snapshot,
        attacks = cancelled.attacks, body = cancelled.body}
    check("Normal own attack cancels before expiry without actor or reserve change", respawn.hero, normal.cancelled,
        sameResources(respawn.hero, cancelled.hero) and not cancelled.hero.shield
        and cancelled.attacks[1].now < respawn.hero.shieldUntil)
    normal.actionEvents = eventList({events = cancelled.events}, dangerMarker, function() return true end)

    initial = resetAndStart("Emergency protection")
    idle("Emergency protection preparation")
    diagnostics:Invoke("NoSafe", true)
    local held = waitFor("Emergency protection all real bodies held", 8, function()
        local d = dump()
        for _, h in ipairs(d.snapshot.heroes) do
            if h.status ~= "Alive" or h.shield ~= "Emergency" or not physical(h.slot).anchored then return false, d end
        end
        return true, d
    end)
    local emergency = {name = "Emergency protected target and safe relocation", heldSnapshot = held.snapshot,
        heldBodies = allPhysical(held.snapshot), trustedPhysicalPreparation = {}}
    results.scenarios[#results.scenarios + 1] = emergency
    local targetBefore = hero(held.snapshot, 2)
    local attackerBefore = hero(held.snapshot, 1)
    -- Diagnostics Pose intentionally rejects protected actors. This explicit trusted test-only
    -- physical preparation positions existing anchored models; it changes no Session state.
    for slot = 1, expectedPlayers do
        local model, root = body(slot)
        local x, z, yaw = slot == 1 and -5 or 0, 0, slot == 1 and -90 or 90
        if slot > 2 then x, z, yaw = -20, -8, 0 end
        local beforeBody = physical(slot)
        check("Emergency trusted preparation P" .. slot .. " already held", true, beforeBody,
            model ~= nil and root.Anchored == true)
        model:PivotTo(CFrame.new(x, 3, z) * CFrame.Angles(0, math.rad(yaw), 0))
        root.AssemblyLinearVelocity = Vector3.new()
        root.AssemblyAngularVelocity = Vector3.new()
        emergency.trustedPhysicalPreparation[#emergency.trustedPhysicalPreparation + 1] = {
            kind = "Studio acceptance model PivotTo; no combat/lifecycle mutation", slot = slot,
            position = {x, 3, z}, yaw = yaw, beforeBody = beforeBody, afterBody = physical(slot)}
    end
    prepared = dump()
    marker = markerOf(prepared)
    syncActor(1, prepared.snapshot)
    emergency.intent = send(slotPlayers[1], "Attack", {attack = "Punch"}).packet
    hit = protectedHit("Emergency protection", marker)
    emergency.hit = hit.hit
    emergency.hitSnapshot = hit.snapshot
    emergency.hitBodies = allPhysical(hit.snapshot)
    data = hit.hit.data
    check("Emergency protected hit blocks damage and impulse",
        {profile = 18, before = 47, after = 47, blocked = true, impulse = false, dying = false}, data,
        data.profile == 18 and data.before == 47 and data.after == 47 and data.blocked == true
        and data.impulse == false and data.dying == false)
    hitHero = hero(hit.snapshot, 2)
    check("Emergency protected target retains held actor Life and reserves", targetBefore, {hero = hitHero, body = hit.body},
        sameResources(targetBefore, hitHero) and hitHero.shield == "Emergency" and hit.body.anchored == true
        and hit.body.actorId == targetBefore.actorId and math.abs(hit.body.velocity[1]) < 0.01
        and math.abs(hit.body.velocity[2]) < 0.01 and math.abs(hit.body.velocity[3]) < 0.01)
    local attackerAfter, attackerBody = hero(hit.snapshot, 1), physical(1)
    emergency.attackerAfterOwnAttack = {hero = attackerAfter, body = attackerBody}
    check("Emergency attacker own real attack clears its hold", attackerBefore, emergency.attackerAfterOwnAttack,
        sameResources(attackerBefore, attackerAfter) and not attackerAfter.shield
        and attackerBody.actorId == attackerBefore.actorId and attackerBody.anchored == false)
    diagnostics:Invoke("NoSafe", false)
    local relocated = waitFor("Emergency protected target safe relocation", 8, function()
        local d = dump()
        local h, b = hero(d.snapshot, 2), physical(2)
        local relocations = eventList(d, marker, function(e)
            return e.kind == "RelocateToSafety" and e.userId == 2 and e.actorId == targetBefore.actorId
                and e.data.code == "OK"
        end)
        return #relocations == 1 and h.status == "Alive" and not h.shield and b.anchored == false,
            {hero = h, snapshot = d.snapshot, body = b, relocations = relocations, events = d.events}
    end)
    emergency.relocated = {hero = relocated.hero, snapshot = relocated.snapshot, body = relocated.body,
        relocations = relocated.relocations}
    emergency.actionEvents = eventList({events = relocated.events}, marker, function() return true end)
    check("Emergency relocation preserves actor attempt reserve and raw Life without Normal shield",
        targetBefore, emergency.relocated, sameResources(targetBefore, relocated.hero)
        and not relocated.hero.shield and relocated.body.serverOwned == true)
    local hits = eventList({events = relocated.events}, marker, function(e) return e.kind == "Hit" end)
    check("Emergency one actual protected Hit", 1, hits, #hits == 1 and hits[1].userId == 2)
    results.protectionFinalDump = dump()
end

local function emergencyScenarios()
    local initial = resetAndStart("emergency relocation")
    idle("emergency relocation preparation")
    local before = hero(initial.snapshot, 1)
    diagnostics:Invoke("NoSafe", true)
    local held = waitFor("NoSafe real fall and emergency hold", 8, function()
        local d = dump()
        local h, p = hero(d.snapshot, 1), physical(1)
        return h.status == "Alive" and h.shield == "Emergency" and p.anchored == true,
            {snapshot = d.snapshot, hero = h, body = p, events = d.events}
    end)
    local scene = {name = "NoSafe emergency hold and safe relocation", before = initial,
        held = held, bodies = allPhysical(held.snapshot)}
    results.scenarios[#results.scenarios + 1] = scene
    check("emergency fall spends one reserve", before.respawns - 1, held.hero.respawns,
        held.hero.respawns == before.respawns - 1)
    task.wait(0.35)
    local stable = {hero = hero(dump().snapshot, 1), body = physical(1)}
    scene.stable = stable
    check("emergency body actually held", {sameActor = true, stableY = true, rawLife = 47}, stable,
        stable.hero.actorId == held.hero.actorId and stable.hero.respawns == held.hero.respawns
        and stable.hero.rawLife == 47 and stable.body.anchored == true
        and math.abs(stable.body.position[2] - held.body.position[2]) < 0.01)
    diagnostics:Invoke("NoSafe", false)
    local relocated = waitFor("emergency safe relocation", 8, function()
        local d = dump()
        local h, p = hero(d.snapshot, 1), physical(1)
        return h.status == "Alive" and not h.shield and p.anchored == false,
            {snapshot = d.snapshot, hero = h, body = p, events = d.events}
    end)
    scene.relocated = relocated
    check("relocation preserves identity attempt reserve Life", held.hero, relocated.hero,
        relocated.hero.actorId == held.hero.actorId and relocated.hero.attempt == held.hero.attempt
        and relocated.hero.respawns == held.hero.respawns and relocated.hero.rawLife == held.hero.rawLife
        and not relocated.hero.shield and relocated.body.serverOwned == true)
    local relocationEvent
    for _, e in ipairs(relocated.events) do
        if e.kind == "RelocateToSafety" and e.userId == 1 and e.actorId == held.hero.actorId then relocationEvent = e end
    end
    check("actual relocation event", "RelocateToSafety OK", relocationEvent,
        relocationEvent ~= nil and relocationEvent.data.code == "OK")

    initial = resetAndStart("emergency timeout")
    idle("emergency timeout preparation")
    local sequence = {name = "NoSafe real timeout reserves 3->2->1->0", stages = {
        {serverTime = initial.snapshot.now, snapshot = initial.snapshot, bodies = allPhysical(initial.snapshot)}
    }}
    results.scenarios[#results.scenarios + 1] = sequence
    for _, h in ipairs(initial.snapshot.heroes) do
        check("timeout P" .. h.slot .. " starts with three reserves", 3, h.respawns, h.respawns == 3)
    end
    diagnostics:Invoke("NoSafe", true)
    local previous = initial.snapshot
    for remaining = 2, 0, -1 do
        local stage = waitFor("NoSafe actual reserves " .. remaining, remaining == 2 and 8 or 14, function()
            local d = dump()
            local complete = true
            for _, h in ipairs(d.snapshot.heroes) do
                local p = physical(h.slot)
                if h.status ~= "Alive" or h.shield ~= "Emergency" or h.respawns ~= remaining
                    or not p.anchored then complete = false end
            end
            return complete, {serverTime = workspace:GetServerTimeNow(), snapshot = d.snapshot,
                bodies = allPhysical(d.snapshot), events = d.events}
        end)
        sequence.stages[#sequence.stages + 1] = stage
        for _, h in ipairs(stage.snapshot.heroes) do
            local old = hero(previous, h.slot)
            check("timeout P" .. h.slot .. " reserve " .. remaining .. " new actor", old.attempt + 1, h,
                h.attempt == old.attempt + 1 and h.actorId ~= old.actorId and h.rawLife == 47)
            local committed
            for _, e in ipairs(stage.events) do
                if e.kind == "CommitSpawn" and e.userId == h.slot and e.actorId == h.actorId then committed = e end
            end
            check("timeout P" .. h.slot .. " reserve " .. remaining .. " deadline", 10,
                committed and h.shieldUntil - committed.now or "missing CommitSpawn",
                committed ~= nil and math.abs(h.shieldUntil - committed.now - 10) < 0.01)
            if remaining < 2 then
                check("timeout P" .. h.slot .. " waits for prior server deadline", old.shieldUntil,
                    committed and committed.now or "missing CommitSpawn",
                    committed ~= nil and committed.now >= old.shieldUntil and committed.now - old.shieldUntil < 1)
            end
        end
        previous = stage.snapshot
    end
    task.wait(0.3)
    local zero = dump()
    check("zero reserve does not itself kill held living actor", "all Alive, raw47, reserve0", zero.snapshot,
        (function()
            for _, h in ipairs(zero.snapshot.heroes) do
                if h.status ~= "Alive" or h.respawns ~= 0 or h.rawLife ~= 47 then return false end
            end
            return true
        end)())
    local exhausted = waitFor("zero reserve emergency expires then actual fall defeats roster", 14, function()
        local d = dump()
        return d.snapshot.status == "Lost", {snapshot = d.snapshot, events = d.events,
            serverTime = workspace:GetServerTimeNow(), bodies = allPhysical(d.snapshot)}
    end)
    sequence.exhausted = exhausted
    for _, h in ipairs(exhausted.snapshot.heroes) do
        local old = hero(previous, h.slot)
        check("zero reserve P" .. h.slot .. " no extra spawn", {status = "Eliminated", attempt = old.attempt, respawns = 0}, h,
            h.status == "Eliminated" and h.attempt == old.attempt and h.respawns == 0)
        local death
        for _, e in ipairs(exhausted.events) do
            if e.kind == "ConfirmedDeath" and e.userId == h.slot and e.now >= old.shieldUntil then death = e end
        end
        check("zero reserve P" .. h.slot .. " actual fall after deadline", "Fall", death,
            death ~= nil and death.data.reason == "Fall")
    end
    diagnostics:Invoke("NoSafe", false)
end

local ok, failure = xpcall(function()
    check("launch player count", "2 or 3", args.players, expectedPlayers == 2 or expectedPlayers == 3)
    waitFor("real multiplayer roster and drivers", 60, function()
        local list = Players:GetPlayers()
        local ready = #list == expectedPlayers
        local detail = {}
        for _, player in ipairs(list) do
            local state = drivers[player] and drivers[player].state
            detail[#detail + 1] = {userId = player.UserId, name = player.Name, driver = state ~= nil,
                presentationDisabled = state and state.presentationDisabled, host = state and state.host}
            if not state or not state.snapshot or not state.host or not state.presentationDisabled then ready = false end
        end
        if ready then rosterPlayers = list end
        return ready, detail
    end)
    local hostId = drivers[rosterPlayers[1]].state.host
    for _, player in ipairs(rosterPlayers) do
        if player.UserId == hostId then host = player end
        check("P driver " .. player.UserId .. " presentation disabled", true,
            drivers[player].state, drivers[player].state.presentationDisabled == true)
        check("P driver " .. player.UserId .. " agrees actual host", hostId,
            drivers[player].state.host, drivers[player].state.host == hostId)
    end
    check("actual host selected", hostId, host and host.UserId or "none", host ~= nil)
    local folder = ServerScriptService:WaitForChild("CombatStand", 15)
    check("server CombatStand exists", true, folder ~= nil, folder ~= nil)
    diagnostics = folder:WaitForChild("Diagnostics", 15)
    check("Studio-only trusted Diagnostics exists", "BindableFunction", diagnostics and diagnostics.ClassName,
        diagnostics ~= nil and diagnostics:IsA("BindableFunction"))
    local initial = freshStart("core")
    results.initialDump = initial
    local unique, roster = {}, {}
    check("fixed initial hero roster", expectedPlayers, #initial.snapshot.heroes, #initial.snapshot.heroes == expectedPlayers)
    for _, h in ipairs(initial.snapshot.heroes) do
        local p = physical(h.slot)
        roster[#roster + 1] = {hero = h, body = p, actualPlayerUserId = slotPlayers[h.slot].UserId}
        check("initial P" .. h.slot .. " actor resources and server ownership",
            {rawLife = 47, respawns = 3, status = "Alive", connected = true, serverOwned = true, uniqueActor = true},
            {hero = h, body = p}, h.rawLife == 47 and h.respawns == 3 and h.status == "Alive"
            and h.connected == true and p.serverOwned == true and p.actorId == h.actorId and not unique[h.actorId])
        unique[h.actorId] = true
    end
    results.initialRoster = roster
    if args.edgeDisconnectOnly == true then
        results.mode = "Real Studio multiplayer Edge, actual departure, offline-body damage and AddPlayers identity capability"
        results.skipped[#results.skipped + 1] = "Ordered-pair core matrix (edgeDisconnectOnly launch mode)"
        results.skipped[#results.skipped + 1] = "Protected-target suite and long NoSafe timeout exhaustion (separate launch modes)"
        edgeDisconnectScenarios()
        return
    end
    if args.protectionOnly == true then
        results.mode = "Real Studio multiplayer protected-target tests; trusted scene preparation; no human keyboard/touch automation"
        results.skipped[#results.skipped + 1] = "Ordered-pair core matrix (protectionOnly launch mode)"
        results.skipped[#results.skipped + 1] = "Long NoSafe timeout exhaustion (protectionOnly launch mode)"
        results.skipped[#results.skipped + 1] = "Unmodified Edge scene and real client departure/offline-body damage (edgeDisconnectOnly launch mode)"
        protectionScenarios()
        return
    end
    results.skipped[#results.skipped + 1] = "Unmodified Edge scene and real client departure/offline-body damage (edgeDisconnectOnly launch mode)"
    for attacker = 1, expectedPlayers do
        for target = 1, expectedPlayers do
            if target ~= attacker then
                runPair(attacker, target, "Safe", "Punch", 18, 47, 43, false)
                runPair(attacker, target, "Safe", "Dash", 22, 47, 31, false)
                runPair(attacker, target, "Dash16", "Dash", 22, 16, 15, false)
                runPair(attacker, target, "Dash15", "Dash", 21, 15, 0, true)
            end
        end
    end
    local finalCore = dump()
    results.coreFinalDump = finalCore
    check("roster remains fixed after complete pair matrix", expectedPlayers,
        #finalCore.snapshot.heroes, #finalCore.snapshot.heroes == expectedPlayers)
    for _, h in ipairs(finalCore.snapshot.heroes) do
        check("P" .. h.slot .. " exactly ordered-pair lethal spends", 3 - (expectedPlayers - 1), h.respawns,
            h.respawns == 3 - (expectedPlayers - 1))
    end
    if args.emergency == true then emergencyScenarios()
    else results.skipped[#results.skipped + 1] = "NoSafe emergency hold, relocation and timeout (launch emergency=true to execute)" end
end, debug.traceback)
if ok then finish("PASS") else finish("FAIL", tostring(failure)) end
