-- Inject only into a tagged Studio multiplayer acceptance place. The server owns
-- the bridge, all real Player instances, course preparation and acceptance checks.
-- This client only observes replication and sends the production Intent remote.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
-- GetTestArgs is deliberately server-only: it is not reliable in test clients.
local bridge = ReplicatedStorage:WaitForChild("BrickToadsScooterNetworkTest", 60)
if not bridge then return end
local command = bridge:WaitForChild("Command", 60)
local reply = bridge:WaitForChild("Reply", 60)
assert(command and command:IsA("RemoteEvent") and reply and reply:IsA("RemoteEvent"), "Missing test bridge remotes")

local playerScripts = player:WaitForChild("PlayerScripts", 60)
assert(playerScripts, "Missing PlayerScripts")
local disabled = {}
local function disablePresentation(instance)
    if instance:IsA("LocalScript") and instance.Name == "BrickToadsClient"
        and instance.Parent and instance.Parent.Name == "BrickToads"
        and instance.Parent.Parent == playerScripts then
        instance.Enabled = false
        disabled[instance] = true
    end
end
playerScripts.DescendantAdded:Connect(disablePresentation)
for _, instance in ipairs(playerScripts:GetDescendants()) do disablePresentation(instance) end

local remotes = ReplicatedStorage:WaitForChild("BrickToadsGame", 60)
assert(remotes, "Missing production remotes")
local intent = remotes:WaitForChild("Intent", 60)
local stateRemote = remotes:WaitForChild("State", 60)
assert(intent and stateRemote, "Missing production Intent/State")
local snapshot, mine, controlled, identity, pilot
local controlIdentity, previousControlIdentity, previousIdentitySequence
local identityTransitionCount = 0
local sequence, snapshotCount, receivedCount, rejectedSnapshots = 0, 0, 0, 0
local sentCount, sentKinds, lastPacket, lastSentAt = 0, {}, nil, nil
local lastSnapshotAt, readySent = nil, false
local commandListenerReady = false
local renderFrameCount = 0
local heartbeatCount, lastHeartbeatAt, lastFrameAt, largestFrameGap = 0, nil, nil, 0
local windowFocused, lastFocusAt
UserInputService.WindowFocused:Connect(function()
    windowFocused, lastFocusAt = true, workspace:GetServerTimeNow()
end)
UserInputService.WindowFocusReleased:Connect(function()
    windowFocused, lastFocusAt = false, workspace:GetServerTimeNow()
end)
local receivedCommands, repliesSent, invalidCommands = 0, 0, 0
local lastCommand, lastReply, bridgeSendFailure
local diagnosticLines = 0
local function diagnostic(message)
    if diagnosticLines >= 120 then return end
    diagnosticLines += 1
    print("[BT-SCOOTER-NETWORK-CLIENT] " .. player.Name .. " " .. message)
end
local function sendBridge(message)
    local ok, failure = pcall(function() reply:FireServer(message) end)
    if not ok then
        bridgeSendFailure = tostring(failure)
        warn("[BT-SCOOTER-NETWORK-CLIENT] " .. player.Name .. " bridge send failed: " .. tostring(failure))
        return false
    end
    if message.type == "Reply" then
        repliesSent += 1
        lastReply = {id = message.id, ok = message.ok, at = workspace:GetServerTimeNow()}
        diagnostic("ReplySent id=" .. message.id .. " ok=" .. tostring(message.ok))
    end
    return true
end

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function point(vector) return {x = vector.X, y = vector.Y, z = vector.Z} end
local function modeState() return snapshot and snapshot.level and snapshot.level.modeState end
local function modeActor(slot)
    local mode = modeState()
    for _, actor in ipairs(mode and mode.actors or {}) do
        if actor.slot == slot then return actor end
    end
end
local function actorFolder()
    if not snapshot or type(snapshot.worldName) ~= "string" then return nil end
    local world = workspace:FindFirstChild(snapshot.worldName)
    if not world or world:GetAttribute("GroupId") ~= snapshot.groupId then return nil end
    return world:FindFirstChild("Actors")
end
local function actorRoot(actorId, slot, enemyId)
    local folder = actorFolder()
    if not folder then return nil end
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and ((actorId ~= nil and model:GetAttribute("ActorId") == actorId)
            or (slot ~= nil and model:GetAttribute("Slot") == slot)
            -- GameWorld clears enemy Slot; BaseWorld's name retains the logical id.
            or (enemyId ~= nil and model.Name == "Actor_" .. tostring(enemyId))) then
            local root = model:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then return root end
        end
    end
end
local function controlledRoot()
    if not controlled then return nil end
    return actorRoot(controlled.actorId, mine and mine.slot, snapshot.enemyRole and snapshot.enemyRole.enemyId)
end
local function describeIdentity(data, actor, hero)
    if not actor then return nil end
    -- Copy primitives now: later snapshots must not rewrite continuity evidence.
    return table.freeze({groupId = data.groupId, runId = data.runId, levelEpoch = data.levelEpoch,
        actorId = actor.actorId, attempt = actor.attempt, connectionEpoch = actor.connectionEpoch,
        role = hero and "Hero" or "Enemy", slot = hero and hero.slot, enemyId = not hero and actor.enemyId or nil,
        snapshotSeq = data.snapshotSeq, at = workspace:GetServerTimeNow()})
end
local function enemyBodies()
    local rows, seen = {}, {}
    local function append(enemyId, offerActorId)
        if enemyId == nil or seen[enemyId] or #rows >= 24 then return end
        seen[enemyId] = true
        local root = actorRoot(offerActorId, nil, enemyId)
        local model = root and root.Parent
        rows[#rows + 1] = {enemyId = enemyId, offerActorId = offerActorId,
            bodyActorId = model and model:GetAttribute("ActorId"), bodyName = model and model.Name,
            enemyKind = model and model:GetAttribute("EnemyKind"),
            controlledByPlayer = model and model:GetAttribute("ControlledByPlayer"),
            position = root and point(root.Position)}
    end
    for _, offer in ipairs(snapshot and snapshot.enemyOffers or {}) do append(offer.enemyId, offer.actorId) end
    local enemy = snapshot and snapshot.enemyRole
    if enemy then append(enemy.enemyId, enemy.actorId) end
    return rows
end
local function playable()
    return snapshot and snapshot.status == "Active" and controlled and controlled.status == "Alive"
        and controlled.connected == true and not controlled.dying and not snapshot.fault
        and (snapshot.view == nil or snapshot.view == "Playing")
end
local function sendIntent(packet)
    local envelope = table.clone(packet)
    if snapshot then
        assert(type(snapshot.groupId) == "string" and snapshot.groupId ~= "", "Missing snapshot groupId")
        envelope.groupId = snapshot.groupId
    else
        assert(envelope.kind == "Sync", "Only Sync can precede a snapshot")
    end
    intent:FireServer(envelope)
    sentCount += 1
    sentKinds[envelope.kind] = (sentKinds[envelope.kind] or 0) + 1
    lastPacket, lastSentAt = envelope, workspace:GetServerTimeNow()
    -- RemoteEvent delivery has no immediate server acceptance result.
    return {sent = true, serverAcceptance = "Unknown", packet = envelope}
end
local function actorIntent(kind, extra)
    assert(kind == "Move" or kind == "Attack" or kind == "Jump", "Unknown actor action")
    assert(playable() and snapshot.runId and controlled.actorId, "No connected, alive controlled actor")
    local fields = {}
    if kind == "Move" then
        assert(finite(extra.x) and finite(extra.z) and math.abs(extra.x) <= 1 and math.abs(extra.z) <= 1, "Invalid movement")
        assert(extra.run == nil or type(extra.run) == "boolean", "Invalid run flag")
        fields = {x = extra.x, z = extra.z, run = extra.run == true}
    elseif kind == "Attack" then
        assert(extra.attack == "Punch" or extra.attack == "Dash", "Invalid attack")
        assert(not snapshot.enemyRole or extra.attack == "Punch", "Enemy role only supports Punch")
        assert(not (snapshot.interaction and snapshot.interaction.carrying and extra.attack == "Dash"), "Cannot Dash while carrying")
        fields.attack = extra.attack
    elseif snapshot.enemyRole then
        assert(snapshot.enemyRole.template ~= "Boss", "Boss role cannot Jump")
    end
    sequence += 1
    local packet = {kind = kind, runId = snapshot.runId, actorId = controlled.actorId,
        attempt = controlled.attempt, levelEpoch = snapshot.levelEpoch,
        connectionEpoch = controlled.connectionEpoch, seq = sequence}
    for key, value in pairs(fields) do packet[key] = value end
    return sendIntent(packet)
end
local function zeroMove()
    if playable() then return actorIntent("Move", {x = 0, z = 0, run = false}) end
    return {sent = false, reason = "NoPlayableActor", serverAcceptance = "Unknown"}
end
local function compactSnapshot()
    if not snapshot then return nil end
    local result = {}
    for _, key in ipairs({"groupId", "groupName", "worldName", "runId", "levelEpoch", "status", "fault", "mine", "host",
        "view", "preference", "canStart", "canSelect", "selectedTemplate", "heroes", "lobby", "enemyRole", "enemyOffers",
        "enemyUnavailableReason", "interaction", "campaign", "snapshotSeq", "serverNow", "now", "notice", "actionFeedback"}) do
        result[key] = snapshot[key]
    end
    if snapshot.level then
        result.level = {}
        for _, key in ipairs({"stage", "mode", "modeState", "enemies", "result", "objective", "campaignIndex", "levelName"}) do
            result.level[key] = snapshot.level[key]
        end
    end
    return result
end
local function status()
    local disabledCount, allDisabled = 0, true
    for instance in pairs(disabled) do
        if instance.Parent then
            disabledCount += 1
            if instance.Enabled then allDisabled = false end
        end
    end
    local root = controlledRoot()
    return {name = player.Name, userId = player.UserId, sourceId = bridge:GetAttribute("SourceId"),
        snapshot = compactSnapshot(), snapshotCount = snapshotCount, receivedCount = receivedCount,
        rejectedSnapshots = rejectedSnapshots, lastSnapshotAt = lastSnapshotAt,
        body = root and {name = root.Parent.Name, actorId = root.Parent:GetAttribute("ActorId"),
            enemyKind = root.Parent:GetAttribute("EnemyKind"), controlledByPlayer = root.Parent:GetAttribute("ControlledByPlayer"),
            position = point(root.Position), velocity = point(root.AssemblyLinearVelocity)} or nil,
        modeActor = mine and modeActor(mine.slot), identity = identity, sequence = sequence,
        controlIdentity = controlIdentity, previousControlIdentity = previousControlIdentity,
        previousIdentitySequence = previousIdentitySequence, identityTransitionCount = identityTransitionCount,
        enemyBodies = enemyBodies(),
        disabledPresentationScripts = disabledCount, presentationDisabled = disabledCount > 0 and allDisabled,
        sentCount = sentCount, sentKinds = table.clone(sentKinds), lastPacket = lastPacket, lastSentAt = lastSentAt,
        commandListenerReady = commandListenerReady, receivedCommands = receivedCommands, repliesSent = repliesSent,
        invalidCommands = invalidCommands, lastCommand = lastCommand, lastReply = lastReply, bridgeSendFailure = bridgeSendFailure,
        renderFrameCount = renderFrameCount, heartbeatCount = heartbeatCount, lastHeartbeatAt = lastHeartbeatAt,
        windowFocused = windowFocused, lastFocusAt = lastFocusAt,
        serverAcceptance = "Unknown", -- The server harness independently records accepted commands.
        pilot = pilot and {active = pilot.active, mode = pilot.mode, phase = pilot.phase, result = pilot.result,
            startedAt = pilot.startedAt, elapsed = (pilot.endedAt or workspace:GetServerTimeNow()) - pilot.startedAt,
            fault = pilot.fault, targetLane = pilot.targetLane, fighterSlot = pilot.fighterSlot,
            attackCount = pilot.attackCount, jumpCount = pilot.jumpCount} or nil}
end
local function publishReady()
    if readySent or not snapshot or not commandListenerReady or renderFrameCount < 2 then return end
    -- A first queued State may be delivered while this script is still setting
    -- up. Readiness promises that the Command listener is already connected.
    if sendBridge({type = "Ready", state = status()}) then
        readySent = true
        diagnostic("ReadySent commandListenerReady=true renderFrameCount=" .. tostring(renderFrameCount))
    end
end

stateRemote.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    receivedCount += 1
    -- Match CombatFeedback's production snapshot ordering before resetting identity.
    if not finite(data.snapshotSeq) or data.snapshotSeq % 1 ~= 0 or data.snapshotSeq < 1
        or (snapshot and data.snapshotSeq <= snapshot.snapshotSeq) then
        rejectedSnapshots += 1
        return
    end
    snapshotCount += 1
    snapshot, mine = data, nil
    lastSnapshotAt = workspace:GetServerTimeNow()
    for _, hero in ipairs(data.heroes or {}) do if hero.slot == data.mine then mine = hero; break end end
    controlled = mine or data.enemyRole
    local nextIdentity = controlled and table.concat({tostring(data.groupId), tostring(data.runId), tostring(data.levelEpoch),
        tostring(controlled.actorId), tostring(controlled.attempt), tostring(controlled.connectionEpoch)}, ":") or nil
    if nextIdentity ~= identity then
        if controlIdentity then previousControlIdentity = controlIdentity end
        previousIdentitySequence = sequence
        controlIdentity = describeIdentity(data, controlled, mine)
        identityTransitionCount += 1
        identity, sequence = nextIdentity, 0
    end
    publishReady()
end)

local function lanePlan(course)
    local hazards = table.clone(course.hazards or {})
    table.sort(hazards, function(a, b) return a.x < b.x end)
    local groups = {}
    for _, hazard in ipairs(hazards) do
        if hazard.d < 40 or hazard.kind == "Overhead" then
            local group = groups[#groups]
            if not group or hazard.x - group.lastX > 40 then
                group = {hazards = {}, lastX = hazard.x}
                groups[#groups + 1] = group
            end
            group.hazards[#group.hazards + 1] = hazard
            group.lastX = hazard.x
        end
    end
    local lanes, costs = {-14, 0, 14}, {}
    for gi = #groups, 1, -1 do
        costs[gi] = {}
        for li, lane in ipairs(lanes) do
            local valid = true
            for _, hazard in ipairs(groups[gi].hazards) do
                if math.abs(lane - hazard.z) <= hazard.d / 2 + 1.3 then valid = false end
            end
            if valid then
                local future = 0
                if costs[gi + 1] then
                    future = math.huge
                    for ni, nextLane in ipairs(lanes) do
                        future = math.min(future, (costs[gi + 1][ni] or math.huge) + math.abs(nextLane - lane))
                    end
                end
                costs[gi][li] = future
            end
        end
    end
    local previous = 0
    for gi, group in ipairs(groups) do
        local best = math.huge
        for li, lane in ipairs(lanes) do
            local score = (costs[gi][li] or math.huge) + math.abs(lane - previous)
            if score < best then best, group.lane = score, lane end
        end
        assert(group.lane, "Course has no safe planned lane")
        previous = group.lane
    end
    return groups
end
local function stopPilot(reason)
    if pilot then
        pilot.active, pilot.result, pilot.endedAt = false, reason, workspace:GetServerTimeNow()
        pilot.phase = "Stopped"
    end
    return zeroMove()
end
local function startPilot(args)
    assert(snapshot and snapshot.status == "Active" and mine, "Drive requires a real active hero")
    local mode = args.mode or "Course"
    assert(mode == "Course" or mode == "Hold" or mode == "Crash", "Unknown drive mode")
    assert(type(args.course) == "table" and type(args.course.mount) == "table", "Drive requires actual course definition")
    local timeout = args.timeout or 60
    assert(finite(timeout) and timeout >= 1 and timeout <= 60, "Drive timeout must be 1..60 seconds")
    local fighterSlot = args.fighterSlot or 1
    assert(finite(fighterSlot) and fighterSlot % 1 == 0 and fighterSlot >= 1 and fighterSlot <= 3, "Invalid fighterSlot")
    if pilot then stopPilot("Replaced") end
    pilot = {active = true, mode = mode, course = args.course, groups = lanePlan(args.course),
        groupId = snapshot.groupId, runId = snapshot.runId, levelEpoch = snapshot.levelEpoch,
        fighterSlot = fighterSlot, timeout = timeout, startedAt = workspace:GetServerTimeNow(),
        lastInputAt = -math.huge, lastAttackAt = -math.huge, lastJumpAt = -math.huge,
        attackCount = 0, jumpCount = 0, phase = mode == "Hold" and "Holding" or "EntryCombat",
        crashHazardId = args.crashHazardId}
    return {started = true, state = status()}
end
local function punch(now)
    if now - pilot.lastAttackAt < 0.55 then return end
    pilot.lastAttackAt = now
    actorIntent("Attack", {attack = "Punch"})
    pilot.attackCount += 1
end
local function movement(x, z) actorIntent("Move", {x = x, z = z, run = false}) end
local function pilotStep(now)
    if snapshot.groupId ~= pilot.groupId or snapshot.runId ~= pilot.runId or snapshot.levelEpoch ~= pilot.levelEpoch then
        stopPilot("StageChanged"); return
    end
    if snapshot.fault or snapshot.status ~= "Active" then stopPilot("RunStopped"); return end
    if now - pilot.startedAt >= pilot.timeout then stopPilot("Timeout"); return end
    if now - pilot.lastInputAt < 0.1 then return end
    pilot.lastInputAt = now
    if not playable() then pilot.phase = "WaitingForActor"; return end
    if pilot.mode == "Hold" then pilot.phase = "Holding"; zeroMove(); return end
    local own = modeActor(mine.slot)
    if not own then pilot.phase = "WaitingForModeSnapshot"; zeroMove(); return end
    if own.finished then pilot.phase = "Finished"; zeroMove(); return end
    local course = pilot.course
    if not own.mounted then
        local entry
        for _, enemy in ipairs(snapshot.level.enemies or {}) do
            if not enemy.dead and enemy.kind == "Invader" then entry = enemy; break end
        end
        if entry then
            pilot.phase = "EntryCombat"
            if mine.slot ~= pilot.fighterSlot then zeroMove(); return end
            local root, target = controlledRoot(), actorRoot(entry.actorId, nil, entry.id)
            if not root or not target then pilot.phase = "WaitingForEntryReplication"; zeroMove(); return end
            local delta = target.Position - root.Position
            local distance = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
            local scale = distance > 3.2 and 1 or 0.1
            movement(delta.X / math.max(distance, 1) * scale, delta.Z / math.max(distance, 1) * scale)
            if distance <= 3.2 then punch(now) end
            return
        end
        pilot.phase = "Boarding"
        local position = own.position
        local dx, dz = course.mount.x - position.x, course.mount.z - position.z
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > 3.5 then movement(dx / math.max(distance, 1), dz / math.max(distance, 1)); return end
        zeroMove()
        local allNear = true
        for _, hero in ipairs(snapshot.heroes or {}) do
            if hero.status == "Alive" and hero.connected then
                local actor = modeActor(hero.slot)
                if not actor then allNear = false
                elseif not actor.mounted then
                    local p = actor.position
                    if math.sqrt((p.x - course.mount.x)^2 + (p.z - course.mount.z)^2) > 4 then allNear = false end
                end
            end
        end
        if allNear then punch(now) end
        return
    end
    pilot.phase = pilot.mode == "Crash" and "Crashing" or "Riding"
    local position, targetLane = own.position, 0
    if pilot.mode == "Crash" then
        for _, hazard in ipairs(course.hazards or {}) do
            if hazard.x > position.x - 3 and (pilot.crashHazardId == hazard.id
                or (pilot.crashHazardId == nil and hazard.kind == "Wall")) then
                targetLane = hazard.z; break
            end
        end
    else
        for _, group in ipairs(pilot.groups) do
            if position.x <= group.lastX + 4 then targetLane = group.lane; break end
        end
        if course.finishPoint and position.x > course.finishPoint.x - 30 then targetLane = 0 end
    end
    pilot.targetLane = targetLane
    -- A bounded proportional steer avoids a delayed full-speed oscillation.
    local error = targetLane - position.z
    movement(0, math.abs(error) < 0.45 and 0 or math.clamp(error * 0.7, -1, 1))
    if pilot.mode == "Course" and own.grounded and now - pilot.lastJumpAt >= 0.45 then
        for _, hazard in ipairs(course.hazards or {}) do
            local ahead = hazard.x - position.x
            if hazard.kind == "LowBarrier" and ahead <= 20 and ahead > 3 then
                pilot.lastJumpAt = now
                actorIntent("Jump", {})
                pilot.jumpCount += 1
                break
            end
        end
    end
end

command.OnClientEvent:Connect(function(message)
    if type(message) ~= "table" or type(message.id) ~= "string" or type(message.kind) ~= "string" then
        invalidCommands += 1
        diagnostic("InvalidCommand")
        return
    end
    receivedCommands += 1
    lastCommand = {id = message.id, kind = message.kind, at = workspace:GetServerTimeNow()}
    diagnostic("CommandReceived id=" .. message.id .. " kind=" .. message.kind)
    local shouldLeave = false
    local ok, result = xpcall(function()
        local args = type(message.args) == "table" and message.args or {}
        if message.kind == "Status" then return status()
        elseif message.kind == "Menu" then
            assert(type(args.kind) == "string", "Menu requires a raw menu intent")
            assert(args.kind ~= "Move" and args.kind ~= "Attack" and args.kind ~= "Jump", "Actor actions require Actor command")
            return {transmission = sendIntent(args), state = status()}
        elseif message.kind == "Actor" then
            return {transmission = actorIntent(args.kind, args), state = status()}
        elseif message.kind == "Drive" then return startPilot(args)
        elseif message.kind == "Stop" then return {transmission = stopPilot("Commanded"), state = status()}
        elseif message.kind == "Leave" then
            assert(StudioTestService:CanLeaveTest(), "This real Studio test client cannot LeaveTest")
            if pilot then stopPilot("Leaving") end
            shouldLeave = true
            return {leaving = true, state = status()}
        end
        error("Unknown test command: " .. message.kind)
    end, debug.traceback)
    sendBridge({type = "Reply", id = message.id, ok = ok, result = result})
    if ok and shouldLeave then
        -- Send the reply before the actual test client disconnects.
        task.delay(0.15, function()
            if StudioTestService:CanLeaveTest() then StudioTestService:LeaveTest() end
        end)
    end
end)
commandListenerReady = true
publishReady()

RunService.Heartbeat:Connect(function()
    local now = workspace:GetServerTimeNow()
    if lastFrameAt then largestFrameGap = math.max(largestFrameGap, now - lastFrameAt) end
    lastFrameAt = now
    -- This small unsolicited record keeps the scheduler/replication evidence
    -- available even while rendering has not reached the readiness barrier.
    if snapshot and commandListenerReady and heartbeatCount < 180
        and (not lastHeartbeatAt or now - lastHeartbeatAt >= 1) then
        heartbeatCount += 1
        local state = {name = player.Name, userId = player.UserId, sourceId = bridge:GetAttribute("SourceId"),
            at = now, heartbeatCount = heartbeatCount, schedulerGapSeconds = largestFrameGap,
            commandListenerReady = commandListenerReady, renderFrameCount = renderFrameCount, readySent = readySent,
            snapshotCount = snapshotCount, snapshotSeq = snapshot.snapshotSeq, lastSnapshotAt = lastSnapshotAt,
            receivedCommands = receivedCommands, repliesSent = repliesSent, invalidCommands = invalidCommands,
            lastCommand = lastCommand, lastReply = lastReply, bridgeSendFailure = bridgeSendFailure,
            sentCount = sentCount, lastSentAt = lastSentAt, groupId = snapshot.groupId,
            windowFocused = windowFocused, lastFocusAt = lastFocusAt,
            scriptEnabled = script.Enabled, scriptParented = script.Parent ~= nil,
            scriptPath = script:GetFullName()}
        lastHeartbeatAt, largestFrameGap = now, 0
        sendBridge({type = "Heartbeat", state = state})
    end
    if not pilot or not pilot.active or not snapshot then return end
    local ok, failure = xpcall(function() pilotStep(now) end, debug.traceback)
    if not ok then
        pilot.active, pilot.result, pilot.phase = false, "ClientFault", "Stopped"
        pilot.endedAt, pilot.fault = workspace:GetServerTimeNow(), tostring(failure)
        pcall(zeroMove)
    end
end)
RunService.RenderStepped:Connect(function()
    renderFrameCount += 1
    publishReady()
end)
task.spawn(function()
    local deadline = os.clock() + 60
    while not snapshot and bridge.Parent and os.clock() < deadline do
        sendIntent({kind = "Sync"})
        task.wait(0.5)
    end
end)
