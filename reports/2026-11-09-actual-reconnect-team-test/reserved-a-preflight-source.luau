-- PRIVATE transport preflight only. No game body or reconnect-gameplay PASS.
local PLACE, UNIVERSE, OWNER = 117412694427208, 10775039796, 11946162891
if game.PlaceId ~= PLACE or game.GameId ~= UNIVERSE then return end
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Teleport = game:GetService("TeleportService")
local TAG = "BrickToadsTeamTestTransport20261109"
local marker, started, finished = Http:GenerateGUID(false), nil, false
local folder = Instance.new("Folder")
folder.Name = "BrickToadsTeamTestTransport"; folder.Parent = game:GetService("ReplicatedStorage")
local resultValue = Instance.new("StringValue")
resultValue.Name = "Result"; resultValue.Parent = folder
local command = Instance.new("RemoteEvent")
command.Name = "Command"; command.Parent = folder
local private = Instance.new("Folder")
private.Name = "TeamTestTransportPrivate"; private.Parent = game:GetService("ServerStorage")
local result = {status = "ORIGIN_READY", scope = "Transport only; dummy server instance, no game character/resources",
    serverMarker = marker, placeId = game.PlaceId, gameId = game.GameId, jobId = game.JobId,
    privateServerId = game.PrivateServerId, studioVersion = version(), heartbeat = 0,
    joins = {}, removals = {}, teleports = {}, failures = {}}
local arena, currentRole, activated = nil, "Origin", false
local seen = setmetatable({}, {__mode = "k"})
local function save()
    folder:SetAttribute("Status", result.status)
    resultValue.Value = Http:JSONEncode(result)
end
local function finish(status, failure)
    if finished then return end
    finished = true; result.status, result.error = status, failure
    result.elapsedSeconds = started and os.clock() - started or 0
    save(); print("[BT-TEAM-TRANSPORT] " .. status .. (failure and " " .. failure or ""))
end
local function activate()
    if activated then return end
    activated, started = true, os.clock()
    task.delay(120, function() if not finished then finish("FAIL", "Transport watchdog expired") end end)
end
local function actual(player)
    return player.Parent == Players and Players:GetPlayerByUserId(OWNER) == player and player.UserId == OWNER
end
local function route(data, stage)
    return {tag = TAG, nonce = data.nonce, arenaServerId = data.arenaServerId,
        transitServerId = data.transitServerId, stage = stage}
end
local function teleport(player, target, data, status)
    if finished or not actual(player) then return end
    local row = {at = workspace:GetServerTimeNow(), userId = player.UserId, target = target, stage = data.stage}
    result.teleports[#result.teleports + 1] = row; result.status = status; save()
    local ok, returned = pcall(function()
        local options = Instance.new("TeleportOptions")
        options.ReservedServerId = target; options:SetTeleportData(data)
        return Teleport:TeleportAsync(PLACE, {player}, options)
    end)
    row.callReturned, row.returnedAt = ok, workspace:GetServerTimeNow()
    if ok then row.returnedPrivateServerId = returned and returned.PrivateServerId; save()
    else finish("FAIL", "TeleportAsync: " .. string.sub(tostring(returned), 1, 500)) end
end
local function valid(data)
    if type(data) ~= "table" or data.tag ~= TAG then return false end
    for key in pairs(data) do
        if key ~= "tag" and key ~= "nonce" and key ~= "arenaServerId" and key ~= "transitServerId" and key ~= "stage" then return false end
    end
    for _, key in ipairs({"nonce", "arenaServerId", "transitServerId"}) do
        if type(data[key]) ~= "string" or #data[key] ~= 36 then return false end
    end
    return data.arenaServerId ~= data.transitServerId
end
local function joined(player)
    if finished or seen[player] or not actual(player) then return end
    seen[player] = true
    local ok, data = pcall(function() return player:GetJoinData().TeleportData end)
    result.joins[#result.joins + 1] = {at = workspace:GetServerTimeNow(), userId = player.UserId,
        joinDataOK = ok, tag = ok and type(data) == "table" and data.tag or nil,
        stage = ok and type(data) == "table" and data.stage or nil}
    if not ok then finish("FAIL", "GetJoinData failed"); return end
    if type(data) ~= "table" or data.tag ~= TAG then save(); return end
    activate()
    if not valid(data) then finish("FAIL", "Invalid routing-only teleport envelope"); return end
    result.nonce = data.nonce
    if data.stage == "Arena" then
        if arena then finish("FAIL", "Arena arm would replace existing server state"); return end
        currentRole = "Arena"
        local probe = Instance.new("Folder"); probe.Name = "ArenaProbe"
        probe:SetAttribute("Marker", marker); probe.Parent = private
        arena = {player = player, probe = probe, marker = marker, nonce = data.nonce,
            armedAt = workspace:GetServerTimeNow(), heartbeat = result.heartbeat}
        result.status = "ARENA_ARMED"; result.arenaMarker = marker; save()
        task.delay(2, function() teleport(player, data.transitServerId, route(data, "Transit"), "ARENA_TO_TRANSIT_REQUESTED") end)
    elseif data.stage == "Transit" then
        currentRole = "Transit"; result.status = "TRANSIT_READY"; save()
        task.delay(2, function() teleport(player, data.arenaServerId, route(data, "ReturnArena"), "TRANSIT_TO_ORIGINAL_A_REQUESTED") end)
    elseif data.stage == "ReturnArena" then
        currentRole = "ReturnArena"
        local a = arena
        result.checks = {originalArenaRAM = a ~= nil, originalRemoval = a ~= nil and a.removedAt ~= nil,
            sameUserId = a ~= nil and player.UserId == a.player.UserId,
            newPlayerObject = a ~= nil and player ~= a.player,
            originalPlayerRemoved = a ~= nil and a.player.Parent ~= Players,
            originalServerMarker = a ~= nil and marker == a.marker,
            originalProbeInstance = a ~= nil and private:FindFirstChild("ArenaProbe") == a.probe
                and a.probe.Parent == private and a.probe:GetAttribute("Marker") == a.marker,
            sameNonce = a ~= nil and data.nonce == a.nonce,
            heartbeatAdvancedWhileAway = a ~= nil and (a.awayHeartbeats or 0) > 0,
            actualCurrentPlayer = actual(player)}
        local passed, failed = 0, 0
        for _, value in pairs(result.checks) do if value then passed += 1 else failed += 1 end end
        result.summary = {passed = passed, failed = failed}; result.returnedAt = workspace:GetServerTimeNow()
        result.awayHeartbeats = a and a.awayHeartbeats or 0
        finish(failed == 0 and "PASS" or "FAIL", failed > 0 and "Return lacks original live arena RAM/removal/identity proof" or nil)
    else finish("FAIL", "Unknown transport stage") end
end
RunService.Heartbeat:Connect(function()
    result.heartbeat += 1
    if arena and arena.removedAt and Players:GetPlayerByUserId(OWNER) == nil then
        arena.awayHeartbeats = (arena.awayHeartbeats or 0) + 1
    end
end)
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    if player.UserId ~= OWNER then return end
    local now = workspace:GetServerTimeNow()
    result.removals[#result.removals + 1] = {at = now, userId = player.UserId, role = currentRole}
    if arena and player == arena.player then
        arena.removedAt, arena.heartbeatAtRemoval = now, result.heartbeat
        result.status = "ARENA_AWAY"; result.ownerRemovedAt = now
    elseif currentRole == "Origin" or currentRole == "Transit" then
        result.status = currentRole == "Origin" and "ORIGIN_DEPARTED" or "TRANSIT_DEPARTED"
        finished = true -- This leg ended, not an overall PASS.
    end
    save()
end)
Teleport.TeleportInitFailed:Connect(function(player, code, message, placeId)
    if player.UserId ~= OWNER or finished then return end
    result.failures[#result.failures + 1] = {at = workspace:GetServerTimeNow(), code = tostring(code),
        message = string.sub(tostring(message), 1, 500), placeId = placeId}
    finish("FAIL", "TeleportInitFailed: " .. tostring(code))
end)
command.OnServerEvent:Connect(function(player, payload)
    if finished or activated or not actual(player) or type(payload) ~= "table" or payload.kind ~= "Start" then return end
    for key in pairs(payload) do if key ~= "kind" then return end end
    activate()
    local data = {nonce = Http:GenerateGUID(false), arenaServerId = Http:GenerateGUID(false), transitServerId = Http:GenerateGUID(false)}
    result.nonce = data.nonce
    task.spawn(function() teleport(player, data.arenaServerId, route(data, "Arena"), "ORIGIN_TO_A_REQUESTED") end)
end)
save()
for _, player in ipairs(Players:GetPlayers()) do task.defer(joined, player) end
