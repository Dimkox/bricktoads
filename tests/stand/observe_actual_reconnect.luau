-- Evaluate on the live reserved arena SERVER via Studio MCP.
-- This observer never starts a run and never reconstructs an actor on return.
return function(options)
    assert(game:GetService("RunService"):IsStudio(), "Studio only")
    assert(type(options) == "table" and type(options.nonce) == "string", "Explicit test nonce required")
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local RunService = game:GetService("RunService")
    local storage = game:GetService("ServerStorage")
    assert(not storage:FindFirstChild("ActualReconnectObserver"), "Observer already exists")
    local owner = assert(Players:GetPlayers()[1], "Current actual owner required")
    assert(#Players:GetPlayers() == 1, "This probe is scoped to one real Studio user")
    local diagnostics = game.ServerScriptService.CombatStand.Diagnostics
    local function dump() return HttpService:JSONDecode(diagnostics:Invoke("Dump")) end
    local before = dump().snapshot
    local hero = before.heroes[1]
    assert(hero.status == "Alive" and hero.connected and hero.rawLife == 31
        and hero.respawns == 2 and hero.attempt == 2 and not hero.shield, "Prepare the explicit test state first")
    local actor
    for _, model in ipairs(workspace.CombatStandWorld.Actors:GetChildren()) do
        if model:GetAttribute("ActorId") == hero.actorId then actor = model end
    end
    assert(actor, "Original physical actor required")
    local root = assert(actor:FindFirstChild("HumanoidRootPart"))
    local join = owner:GetJoinData().TeleportData
    assert(join and join.arenaServerId == options.arenaServerId, "Current reserved arena identity required")
    local record = {status = "ARMED", nonce = options.nonce, marker = HttpService:GenerateGUID(false),
        ownerUserId = owner.UserId, arenaServerId = options.arenaServerId,
        placeId = game.PlaceId, gameId = game.GameId, before = before,
        scope = "One actual Studio user; no production empty-server lifetime claim",
        preparation = "Real Fall/respawn; trusted DiagnosticLife31 after Normal expiry",
        heartbeatCount = 0, checks = {}}
    local observer = Instance.new("BindableFunction")
    observer.Name = "ActualReconnectObserver"
    observer:SetAttribute("Marker", record.marker)
    observer.Parent = storage
    local value = Instance.new("StringValue")
    value.Name = "Result"; value.Parent = observer
    local function save()
        observer:SetAttribute("Status", record.status)
        value.Value = HttpService:JSONEncode(record)
    end
    observer.OnInvoke = function() save(); return value.Value end
    RunService.Heartbeat:Connect(function() record.heartbeatCount = record.heartbeatCount + 1 end)
    Players.PlayerRemoving:Connect(function(player)
        if player ~= owner then return end
        record.removalObserved = true
        record.removedAt = workspace:GetServerTimeNow()
        record.heartbeatAtRemoval = record.heartbeatCount
        record.status = "AWAY"
        save()
        task.spawn(function()
            local deadline = os.clock() + 5
            repeat
                local d = dump().snapshot
                if not d.heroes[1].connected then
                    record.offline = d
                    record.heartbeatOffline = record.heartbeatCount
                    save(); return
                end
                task.wait(0.04)
            until os.clock() >= deadline
            record.offlineObservationError = "Gateway did not observe offline owner within five seconds"
            save()
        end)
    end)
    Players.PlayerAdded:Connect(function(player)
        if player.UserId ~= owner.UserId then return end
        task.spawn(function()
            local deadline = os.clock() + 10
            local after
            repeat
                after = dump().snapshot
                if after.heroes[1].connected and after.heroes[1].connectionEpoch == hero.connectionEpoch + 2 then break end
                task.wait(0.04)
            until os.clock() >= deadline
            local current = after.heroes[1]
            local data = player:GetJoinData().TeleportData
            record.after = after
            record.returnedAt = workspace:GetServerTimeNow()
            record.heartbeatAtReturn = record.heartbeatCount
            record.returnJoinData = player:GetJoinData()
            record.checks = {
                actualRemoval = record.removalObserved == true,
                offlineStateObserved = record.offline ~= nil and not record.offline.heroes[1].connected,
                sameUserId = player.UserId == owner.UserId,
                newPlayerObject = player ~= owner,
                oldPlayerRemoved = owner.Parent ~= Players,
                originalObserverAlive = observer.Parent == storage and observer:GetAttribute("Marker") == record.marker,
                sameActorInstance = actor.Parent == workspace.CombatStandWorld.Actors
                    and actor:GetAttribute("ActorId") == hero.actorId,
                sameRootInstance = root.Parent == actor and actor:FindFirstChild("HumanoidRootPart") == root,
                sameRun = after.runId == before.runId,
                sameActorId = current.actorId == hero.actorId,
                sameAttempt = current.attempt == hero.attempt,
                sameReserves = current.respawns == hero.respawns,
                sameCurrentLife = current.rawLife == hero.rawLife,
                noNewProtection = current.shield == nil,
                newConnectionEpoch = current.connectionEpoch == hero.connectionEpoch + 2,
                returnEnvelope = data ~= nil and data.tag == "BrickToadsActualReturn" and data.nonce == record.nonce,
            }
            local passed, failed = 0, 0
            for _, ok in pairs(record.checks) do if ok then passed = passed + 1 else failed = failed + 1 end end
            record.summary = {passed = passed, failed = failed}
            record.status = failed == 0 and "PASS" or "FAIL"
            save()
            print("[BT-ACTUAL-RECONNECT] " .. record.status .. " " .. HttpService:JSONEncode(record.summary))
        end)
    end)
    save()
    return {marker = record.marker, before = before, nonce = record.nonce, status = record.status}
end
