-- TEST ONLY. Inject into an owned Studio helper, never into the production build.
-- Starts exclusively under StudioTestService's tagged multiplayer session.
local Acceptance = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

function Acceptance.install(hub)
    if not RunService:IsStudio() or not RunService:IsServer() then return false end
    local argsOK, args = pcall(function() return StudioTestService:GetTestArgs() end)
    if not argsOK or type(args) ~= "table" or args.tag ~= "BrickToadsScooterNetworkTest" then return false end
    assert(not ReplicatedStorage:FindFirstChild("BrickToadsScooterNetworkTest"), "Acceptance already installed")
    local started, finished, serial = os.clock(), false, 0
    local timeout = math.clamp(tonumber(args.timeoutSeconds) or 180, 60, 180)
    local results = {tag = args.tag, status = "RUNNING", scenario = args.scenario or "Heroes",
        seed = args.seed or 41, players = args.players or 3, sourceId = hub.deps.BuildId,
        expectedSourceId = args.expectedSourceId,
        preparation = "Real clients select roles/heroes and Start; server selects seed and advances twice to stage 3.",
        scope = "Actual Studio Players, production Intent/State, all-hero mounted progress, and the production first-finisher team transition.",
        startup = {windowSeconds = 90,
            reason = "First cold Studio run launched three clients but client scripts began after the prior 45-second deadline.",
            players = {}},
        checks = {}, commands = {}, roundTrips = {}, trace = {}, clientHeartbeats = {}, skipped = {
            "Physical mobile hardware, human touch/UI and measured device performance",
            "Same-account reconnect into the same live server",
            "Other client-count courses, deliberate crash/restart and human RocketRat control (separate scenarios)",
        }}
    local bridge = Instance.new("Folder")
    bridge.Name = "BrickToadsScooterNetworkTest"
    bridge:SetAttribute("SourceId", hub.deps.BuildId or "unknown")
    bridge:SetAttribute("Tag", args.tag)
    bridge.Parent = ReplicatedStorage
    local command = Instance.new("RemoteEvent")
    command.Name, command.Parent = "Command", bridge
    local reply = Instance.new("RemoteEvent")
    reply.Name, reply.Parent = "Reply", bridge
    local ready, pending, latest, arrivals, lastSeen, heartbeats = {}, {}, {}, {}, {}, {}
    local participants, group, controller
    local observeCourse, courseConnection

    local function isReal(player)
        return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
            and Players:GetPlayerByUserId(player.UserId) == player
    end
    local function arrival(player)
        if arrivals[player] then return arrivals[player] end
        local row = {name = player.Name, userId = player.UserId, ready = false,
            joinedAt = workspace:GetServerTimeNow(), joinedElapsedSeconds = os.clock() - started}
        arrivals[player] = row
        results.startup.players[#results.startup.players + 1] = row
        return row
    end
    Players.PlayerAdded:Connect(arrival)
    for _, player in ipairs(Players:GetPlayers()) do arrival(player) end
    Players.PlayerRemoving:Connect(function(player)
        local row = arrival(player)
        row.departedAt, row.departedElapsedSeconds = workspace:GetServerTimeNow(), os.clock() - started
    end)
    local function serverState()
        if not controller then return nil end
        local session = controller.current
        local heroes = {}
        for _, slot in ipairs(session and session.order or {}) do
            local hero, actor = session.state.heroes[slot], controller.world.actors[slot]
            local root = actor and actor.root
            local anchored = root ~= nil and root.Parent ~= nil and root.Anchored
            local ownerOK, owner = false, nil
            if root and root.Parent and not anchored then
                ownerOK, owner = pcall(function() return root:GetNetworkOwner() end)
            end
            heroes[#heroes + 1] = {slot = slot, actorId = hero.actorId, attempt = hero.attempt,
                status = hero.status, connected = hero.connected, connectionEpoch = hero.connectionEpoch,
                respawns = hero.respawns, rawLife = session.combat[slot].rawLife,
                position = controller.world:position(slot),
                bodyActorId = actor and actor.model:GetAttribute("ActorId"),
                modelIsInstance = actor ~= nil and typeof(actor.model) == "Instance" and actor.model:IsA("Model"),
                bodyInWorkspace = root ~= nil and root:IsDescendantOf(workspace),
                anchored = anchored, ownershipKind = anchored and "AnchoredServerPose"
                    or (ownerOK and (owner == nil and "MeasuredServerOwner" or "MeasuredClientOwner") or "Unavailable"),
                networkOwnerRead = ownerOK, serverOwned = anchored or (ownerOK and owner == nil),
                networkOwnerUserId = owner and owner.UserId or nil}
        end
        return {at = workspace:GetServerTimeNow(), groupId = group.id, worldName = controller.world.folder.Name,
            sourceId = hub.deps.BuildId, campaignIndex = controller.campaignIndex,
            runId = session and session.state.runId, levelEpoch = session and session.state.levelEpoch,
            status = session and session.state.status, faulted = controller.faulted == true,
            stage = controller.director and controller.director.stage, heroes = heroes,
            mode = controller.director and controller.director.modes and controller.director.modes:snapshot()}
    end
    local function finish(status, failure)
        if finished then return end
        finished = true
        if courseConnection then courseConnection:Disconnect() end
        if observeCourse then observeCourse() end
        results.status, results.error, results.elapsedSeconds = status, failure, os.clock() - started
        local ok, final = pcall(serverState)
        if ok then results.final = final else results.finalReadError = tostring(final) end
        if controller and participants then
            results.authoritativeLobby = {}
            for _, player in ipairs(participants) do
                results.authoritativeLobby[#results.authoritativeLobby + 1] = {name = player.Name, userId = player.UserId,
                    preference = controller.preferences[player.UserId], selectedHero = controller.choices[player.UserId],
                    notice = controller.notices[player], currentInstance = isReal(player)}
            end
        end
        if controller and controller.journal then
            local journalOK, journal = pcall(function() return controller.journal:snapshot() end)
            if journalOK then results.journal = journal end
        end
        local passed, failed = 0, 0
        for _, check in ipairs(results.checks) do
            if check.pass then passed += 1 else failed += 1 end
        end
        results.summary = {passed = passed, failed = failed, samples = #results.trace, roundTrips = #results.roundTrips}
        print("[BT-SCOOTER-NETWORK] " .. status .. " " .. game:GetService("HttpService"):JSONEncode(results.summary))
        local endOK, endError = pcall(function() StudioTestService:EndTest(results) end)
        if not endOK then warn("[BT-SCOOTER-NETWORK] EndTest failed: " .. tostring(endError)) end
    end
    -- Install the watchdog before waiting for clients or preparing the scenario.
    task.delay(timeout, function()
        if not finished then
            results.checks[#results.checks + 1] = {name = "Overall watchdog", pass = false,
                expected = "Complete within " .. timeout .. " seconds", observed = os.clock() - started}
            finish("FAIL", "Overall watchdog expired")
        end
    end)
    reply.OnServerEvent:Connect(function(player, message)
        if finished or not isReal(player) or type(message) ~= "table" then return end
        local receivedAt = workspace:GetServerTimeNow()
        lastSeen[player] = {at = receivedAt, type = message.type, id = message.id}
        if message.type == "Ready" and type(message.state) == "table" then
            latest[player] = message.state
            local row = arrival(player)
            row.commandListenerReady = message.state.commandListenerReady == true
            row.renderFrameCount = message.state.renderFrameCount
            row.readySignalReceivedAt = workspace:GetServerTimeNow()
            if not row.commandListenerReady or type(row.renderFrameCount) ~= "number" or row.renderFrameCount < 2 then return end
            ready[player] = true
            if not row.ready then
                row.ready, row.readyAt, row.readyElapsedSeconds = true, workspace:GetServerTimeNow(), os.clock() - started
                row.sourceId = message.state.sourceId
                row.snapshotCount = message.state.snapshotCount
                row.groupId = message.state.snapshot and message.state.snapshot.groupId
            end
        elseif message.type == "Heartbeat" and type(message.state) == "table" then
            local previous = heartbeats[player]
            local heartbeat = {name = player.Name, userId = player.UserId, receivedAt = receivedAt,
                arrivalGapSeconds = previous and receivedAt - previous.receivedAt,
                clientAt = message.clientAt, state = message.state}
            heartbeats[player], latest[player] = heartbeat, message.state
            local row = arrival(player)
            row.heartbeatCount = (row.heartbeatCount or 0) + 1
            row.lastHeartbeatAt = receivedAt
            if row.heartbeatCount <= 180 then results.clientHeartbeats[#results.clientHeartbeats + 1] = heartbeat end
        elseif message.type == "Reply" and type(message.id) == "string" then
            local request = pending[message.id]
            if request and request.player == player and not request.response then
                request.response, request.receivedAt = message, workspace:GetServerTimeNow()
                local evidence = request.evidence
                evidence.replied, evidence.replyUserId, evidence.replyName = true, player.UserId, player.Name
                evidence.ok, evidence.receivedAt = message.ok == true, request.receivedAt
                evidence.roundTripSeconds = request.receivedAt - request.sentAt
                if not message.ok then evidence.error = tostring(message.result) end
                results.roundTrips[#results.roundTrips + 1] = {id = request.id, kind = request.kind,
                    userId = player.UserId, seconds = evidence.roundTripSeconds, ok = message.ok == true}
                if message.ok and type(message.result) == "table" then
                    latest[player] = request.kind == "Status" and message.result or message.result.state
                    local state = latest[player]
                    local snapshot = state and state.snapshot
                    evidence.client = state and {userId = state.userId, name = state.name, sourceId = state.sourceId,
                        snapshotCount = state.snapshotCount, presentationDisabled = state.presentationDisabled,
                        commandListenerReady = state.commandListenerReady, receivedCommands = state.receivedCommands,
                        renderFrameCount = state.renderFrameCount,
                        repliesSent = state.repliesSent, lastCommand = state.lastCommand, lastReply = state.lastReply,
                        groupId = snapshot and snapshot.groupId, snapshotSeq = snapshot and snapshot.snapshotSeq,
                        runId = snapshot and snapshot.runId, levelEpoch = snapshot and snapshot.levelEpoch}
                end
            end
        end
    end)
    local function check(name, expected, observed, pass)
        results.checks[#results.checks + 1] = {name = name, expected = expected, observed = observed,
            pass = pass == true, at = workspace:GetServerTimeNow()}
        if not pass then error(name, 0) end
    end
    local function waitFor(name, seconds, predicate)
        local untilTime, observed = os.clock() + seconds, nil
        repeat
            if finished then error("Acceptance session ended", 0) end
            local ok, value = predicate()
            observed = value
            if ok then return value end
            task.wait(0.05)
        until os.clock() >= untilTime
        check(name, "Condition observed within " .. seconds .. " seconds", observed, false)
    end
    local function requests(list, kind, fields)
        local active = {}
        for index, player in ipairs(list) do
            assert(isReal(player), "Commands require the actual current Player instance")
            serial += 1
            local id = tostring(serial)
            local packet = type(fields) == "function" and fields(player, index) or fields or {}
            local request = {id = id, player = player, kind = kind, sentAt = workspace:GetServerTimeNow()}
            local joined = arrivals[player]
            request.evidence = {id = id, kind = kind, userId = player.UserId, name = player.Name,
                sentAt = request.sentAt, replied = false, timedOut = false,
                actualInstanceAtSend = isReal(player), readyAtSend = ready[player] == true,
                readyAt = joined and joined.readyAt,
                args = kind == "Drive" and {mode = packet.mode, timeout = packet.timeout, fighterSlot = packet.fighterSlot} or packet}
            pending[id], active[index] = request, request
            results.commands[#results.commands + 1] = request.evidence
            command:FireClient(player, {id = id, kind = kind, args = packet})
        end
        local waitOK, waitFailure = pcall(function()
            waitFor("Client " .. kind .. " replies", 10, function()
                local count, details = 0, {}
                for _, request in ipairs(active) do
                    if request.response then count += 1 end
                    details[#details + 1] = request.evidence
                end
                return count == #active, {received = count, expected = #active, requests = details}
            end)
        end)
        if not waitOK then
            for _, request in ipairs(active) do
                if not request.response then
                    request.evidence.timedOut = true
                    request.evidence.actualInstanceAtTimeout = isReal(request.player)
                    request.evidence.waitedSeconds = workspace:GetServerTimeNow() - request.sentAt
                    request.evidence.lastSeen = lastSeen[request.player]
                    request.evidence.lastHeartbeat = heartbeats[request.player]
                    request.evidence.latestClientState = latest[request.player]
                end
            end
            error(waitFailure, 0)
        end
        local states = {}
        for index, request in ipairs(active) do
            local response = request.response
            pending[request.id] = nil
            check("Client " .. request.player.Name .. " " .. kind .. " executed", true,
                response.ok == true and true or tostring(response.result), response.ok == true)
            states[index] = kind == "Status" and response.result or response.result.state
            latest[request.player] = states[index]
        end
        return states
    end
    local function clientReadbacks(expectedEpoch, expectedIndex)
        local states = requests(participants, "Status")
        local valid = true
        for index, state in ipairs(states) do
            local snapshot = state.snapshot
            valid = valid and state.userId == participants[index].UserId and state.sourceId == hub.deps.BuildId
                and state.presentationDisabled == true and type(snapshot) == "table"
                and snapshot.groupId == group.id and snapshot.worldName == controller.world.folder.Name
                and snapshot.runId == controller.current.state.runId and snapshot.levelEpoch == expectedEpoch
                and snapshot.campaign and snapshot.campaign.index == expectedIndex and not snapshot.fault
                and #snapshot.heroes == #controller.current.order
            if expectedIndex == 4 then
                valid = valid and state.pilot ~= nil and state.pilot.active == false and state.pilot.result == "StageChanged"
            end
        end
        return valid == true, states
    end
    local function sample(states)
        if #results.trace >= 100 then return end
        results.trace[#results.trace + 1] = {server = serverState(), clients = states}
    end

    task.spawn(function()
        local ok, failure = xpcall(function()
            check("Supported initial scenario", "Heroes", results.scenario, results.scenario == "Heroes")
            local playerCount = results.players
            check("Requested actual client count", "Integer 1..3", playerCount,
                type(playerCount) == "number" and playerCount % 1 == 0 and playerCount >= 1 and playerCount <= 3)
            check("Build source identity supplied", "Nonempty BuildId", hub.deps.BuildId,
                type(hub.deps.BuildId) == "string" and #hub.deps.BuildId > 0)
            check("Exact expected runtime source identity", args.expectedSourceId, hub.deps.BuildId,
                type(args.expectedSourceId) == "string" and #args.expectedSourceId > 0 and args.expectedSourceId == hub.deps.BuildId)
            participants = waitFor(tostring(playerCount) .. " actual clients ready after cold startup", 90, function()
                local actual = Players:GetPlayers()
                local count, identities = 0, {}
                for _, player in ipairs(actual) do
                    local row = arrival(player)
                    local real, hasReady = isReal(player), ready[player] == true
                    if real and hasReady then count += 1 end
                    identities[#identities + 1] = {name = player.Name, userId = player.UserId,
                        actualInstance = real, ready = hasReady, joinedAt = row.joinedAt,
                        commandListenerReady = row.commandListenerReady, readySignalReceivedAt = row.readySignalReceivedAt,
                        renderFrameCount = row.renderFrameCount,
                        joinedElapsedSeconds = row.joinedElapsedSeconds, readyAt = row.readyAt,
                        readyElapsedSeconds = row.readyElapsedSeconds}
                end
                return #actual == playerCount and count == playerCount,
                    #actual == playerCount and count == playerCount and actual
                    or {actual = #actual, ready = count, expected = playerCount, players = identities,
                        elapsedSeconds = os.clock() - started, startupWindowSeconds = 90}
            end)
            group = assert(hub:selected(participants[1]), "First real player has no selected group")
            participants = hub:members(group.id, Players:GetPlayers())
            controller = group.controller
            local proof = {}
            for _, player in ipairs(participants) do
                proof[#proof + 1] = {name = player.Name, userId = player.UserId,
                    typeof = typeof(player), className = player.ClassName,
                    parentIsPlayers = player.Parent == Players, currentInstance = Players:GetPlayerByUserId(player.UserId) == player,
                    registryCurrent = hub.connections:isCurrent(player), groupId = hub:selected(player).id}
            end
            check("Actual Player instances share one group", playerCount, proof, #participants == playerCount)
            check("Fresh lobby", "No active session", controller.current == nil, controller.current == nil)
            requests(participants, "Menu", {kind = "SelectRole", role = "Hero"})
            waitFor("Production role preferences accepted", 8, function()
                local all = true
                for _, player in ipairs(participants) do all = all and controller.preferences[player.UserId] == "Hero" end
                return all, {accepted = all}
            end)
            local templates = {"Mr. Green", "Mr. Yellow", "Mr. Brown"}
            requests(participants, "Menu", function(_, index) return {kind = "SelectHero", template = templates[index]} end)
            waitFor("Production hero selections accepted", 8, function()
                local all = true
                for index, player in ipairs(participants) do all = all and controller.choices[player.UserId] == templates[index] end
                return all, {accepted = all}
            end)
            local host
            for _, player in ipairs(participants) do
                if controller:snapshot(player, participants).canStart then host = player; break end
            end
            assert(host, "No actual client owns Start")
            requests({host}, "Menu", {kind = "Start"})
            waitFor("Production Start created " .. playerCount .. " actual-client heroes", 12, function()
                local session = controller.current
                return session ~= nil and session.state.status == "Active" and #session.order == playerCount,
                    {active = session ~= nil, heroes = session and #session.order, expected = playerCount}
            end)
            results.started = serverState()
            controller.campaignSeed = results.seed
            controller:_advanceCampaign(workspace:GetServerTimeNow())
            controller:_advanceCampaign(workspace:GetServerTimeNow())
            check("Explicit preparation selects scooter stage", 3, controller.campaignIndex, controller.campaignIndex == 3)
            results.initial = serverState()
            local initialBySlot, ownerIds = {}, {}
            for _, hero in ipairs(results.initial.heroes) do
                initialBySlot[hero.slot] = hero
                check("Initial physical server body slot " .. hero.slot, hero.actorId, hero.bodyActorId,
                    hero.modelIsInstance and hero.bodyInWorkspace and hero.actorId == hero.bodyActorId
                        and not hero.anchored and hero.networkOwnerRead and hero.serverOwned)
            end
            for _, player in ipairs(participants) do ownerIds[player.UserId] = controller.ownerSlots[player.UserId] end
            results.ownerSlots = ownerIds
            local stageEpoch = controller.current.state.levelEpoch
            local readbacks = waitFor("All clients receive actual stage 3", 15, function()
                return clientReadbacks(stageEpoch, 3)
            end)
            results.initialClients = readbacks
            local course = controller.director.definition.course
            results.course = course
            local courseModes, courseSession = controller.director.modes, controller.current
            local requiredX = assert(course.finishPoint and course.finishPoint.x, "Course finish point is required") - 45
            local ridingBySlot = {}
            results.riding = {requiredX = requiredX,
                scope = "Every real hero must board and reach within 45 studs of the finish. Production advances the team when its first finisher clears.",
                sequenceMeaning = "High-water Session.lastSeq is a consumed validated envelope, not proof every action succeeded.",
                heroes = {}}
            for _, slot in ipairs(courseSession.order) do
                local owner = controller.owners[slot]
                local row = {slot = slot, userId = owner.userId, actorId = courseSession.state.heroes[slot].actorId,
                    mounted = false, samples = 0, modeInputsObserved = 0, steeringObserved = false,
                    maxX = -1000000, maxProgress = 0, maxCheckpoint = 0, sequenceHighWater = 0, trace = {}}
                ridingBySlot[slot] = row
                results.riding.heroes[#results.riding.heroes + 1] = row
            end
            observeCourse = function()
                local now = workspace:GetServerTimeNow()
                for _, slot in ipairs(courseSession.order) do
                    local actor, row = courseModes.actors[slot], ridingBySlot[slot]
                    if actor then
                        row.samples += 1
                        row.sequenceHighWater = math.max(row.sequenceHighWater, courseSession.lastSeq[slot] or 0)
                        if actor.mounted then
                            if not row.mounted then row.mounted, row.mountedAt = true, now end
                            row.maxX = math.max(row.maxX, actor.position.x)
                            row.maxProgress = math.max(row.maxProgress, actor.progress or 0)
                            row.maxCheckpoint = math.max(row.maxCheckpoint, actor.checkpoint or 0)
                            row.finished = row.finished or actor.finished == true
                            if actor.position.x >= requiredX then row.nearFinishAt = row.nearFinishAt or now end
                            local input = actor.input
                            if input and type(input.at) == "number" and input.at == input.at
                                and input.at > -math.huge and input.at < math.huge and input.at ~= row.lastModeInputAt then
                                row.lastModeInputAt = input.at
                                row.modeInputsObserved += 1
                                row.lastModeInput = {x = input.x, z = input.z, run = input.run, at = input.at}
                                if math.abs(input.z or 0) > 0.05 then row.steeringObserved = true end
                            end
                            if (not row.lastTraceAt or now - row.lastTraceAt >= 0.25) and #row.trace < 240 then
                                row.lastTraceAt = now
                                row.trace[#row.trace + 1] = {at = now, x = actor.position.x, y = actor.position.y,
                                    z = actor.position.z, progress = actor.progress, checkpoint = actor.checkpoint,
                                    grounded = actor.grounded, finished = actor.finished, input = row.lastModeInput,
                                    sequenceHighWater = row.sequenceHighWater}
                            end
                        end
                    end
                end
            end
            courseConnection = RunService.Heartbeat:Connect(observeCourse)
            requests(participants, "Drive", {course = course, mode = "Course", fighterSlot = 1, timeout = 60})
            local routeStarted = os.clock()
            while controller.campaignIndex == 3 and os.clock() - routeStarted < 65 do
                if finished then return end
                local states = requests(participants, "Status")
                sample(states)
                assert(not controller.faulted, "Production controller faulted")
                assert(controller.current.state.status == "Active", "Production run is no longer active")
                for _, state in ipairs(states) do
                    assert(not state.snapshot.fault, "Client received production fault")
                    assert(not (state.pilot and state.pilot.fault), "Client pilot fault: " .. tostring(state.pilot and state.pilot.fault))
                    local packet = state.lastPacket
                    assert(not packet or packet.groupId == group.id, "Production input group envelope mismatch")
                end
                task.wait(0.5)
            end
            observeCourse()
            check("Course earns next stage through real client input", 4, controller.campaignIndex, controller.campaignIndex == 4)
            if controller.journal then
                local journal = controller.journal:snapshot()
                results.riding.events = {}
                for _, event in ipairs(journal.events) do
                    if event.levelEpoch == stageEpoch and (event.kind == "CampaignMounted" or event.kind == "CampaignJump"
                        or event.kind == "CampaignCheckpoint" or event.kind == "CampaignCourseCleared"
                        or event.kind == "CampaignGroupStopped" or event.kind == "CampaignGroupRewound") then
                        results.riding.events[#results.riding.events + 1] = event
                        local row = ridingBySlot[event.userId]
                        if row and event.kind == "CampaignJump" then row.acceptedJumpEvents = (row.acceptedJumpEvents or 0) + 1 end
                    end
                end
            end
            for _, row in ipairs(results.riding.heroes) do
                check("Real hero slot " .. row.slot .. " boards and progresses before first-finisher transition",
                    {mounted = true, minX = requiredX, observedModeInputs = true}, row,
                    row.mounted and row.maxX >= requiredX and row.modeInputsObserved > 0)
            end
            local finalStates = waitFor("All clients receive earned stage 4", 12, function()
                return clientReadbacks(controller.current.state.levelEpoch, 4)
            end)
            results.finalClients = finalStates
            sample(finalStates)
            local final = serverState()
            for _, hero in ipairs(final.heroes) do
                local before = initialBySlot[hero.slot]
                check("Slot " .. hero.slot .. " actor identity and stock survive earned transition",
                    {actorId = before.actorId, attempt = before.attempt, respawns = before.respawns}, hero,
                    hero.actorId == before.actorId and hero.bodyActorId == before.bodyActorId
                        and hero.attempt == before.attempt and hero.respawns == before.respawns
                        and hero.status == "Alive" and hero.connected and hero.serverOwned and hero.bodyInWorkspace)
            end
            for index, state in ipairs(finalStates) do
                local slot = controller.ownerSlots[participants[index].UserId]
                local actual, snapshotHero = initialBySlot[slot], nil
                for _, hero in ipairs(state.snapshot.heroes) do if hero.slot == slot then snapshotHero = hero; break end end
                check("Client " .. index .. " sees own preserved physical actor", actual.actorId, state.body,
                    state.snapshot.mine == slot and state.body and state.body.actorId == actual.actorId
                        and snapshotHero and snapshotHero.actorId == actual.actorId
                        and snapshotHero.respawns == actual.respawns and state.snapshotCount > 1)
            end
            requests(participants, "Stop")
            finish("PASS")
        end, debug.traceback)
        if not ok then finish("FAIL", tostring(failure)) end
    end)
    return true
end

return Acceptance
