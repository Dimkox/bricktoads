-- Capability probe only. Never included in the production place builder.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local argsOK, args = pcall(function() return StudioTestService:GetTestArgs() end)
local tag = "BrickToadsReconnectTransportProbe"
local tagged = argsOK and type(args) == "table" and args.tag == tag
if not tagged then
    local deadline = os.clock() + 15
    repeat
        for _, player in ipairs(Players:GetPlayers()) do
            local ok, data = pcall(function() return player:GetJoinData().TeleportData end)
            if ok and type(data) == "table" and data.tag == tag then tagged = true; break end
        end
        if tagged or #Players:GetPlayers() > 0 then break end
        task.wait(0.1)
    until os.clock() >= deadline
end
if not tagged then return end
local marker = HttpService:GenerateGUID(false)
local folder = Instance.new("Folder")
folder.Name = "ReconnectTransportProbe"
folder.Parent = game:GetService("ServerStorage")
local payload = Instance.new("StringValue")
payload.Name = "Result"; payload.Parent = folder
local result = {status = "WAITING", marker = marker, placeId = game.PlaceId,
    gameId = game.GameId, jobId = game.JobId, privateServerId = game.PrivateServerId,
    studioVersion = version(), getTestArgsOK = argsOK,
    args = argsOK and args or tostring(args), observations = {}}
local function save()
    folder:SetAttribute("Status", result.status)
    payload.Value = HttpService:JSONEncode(result)
end
save()
local finished = false
local function finish(status, failure)
    if finished then return end
    finished = true
    result.status, result.error = status, failure
    save()
    print("[BT-RECONNECT-PROBE] " .. result.status .. " " .. payload.Value)
    local ok, err = pcall(function() StudioTestService:EndTest(result) end)
    result.endTestReturned = ok
    result.endTestError = not ok and tostring(err) or nil
    save()
end
task.delay(120, function() finish("FAIL", "Transport capability probe timed out") end)
local function observe(player)
    local ok, data = pcall(function() return player:GetJoinData() end)
    return {userId = player.UserId, name = player.Name, joinDataOK = ok,
        joinData = ok and data or tostring(data)}
end
local ok, failure = xpcall(function()
    local deadline = os.clock() + 45
    local envelope
    repeat
        local list = Players:GetPlayers()
        for _, player in ipairs(list) do
            local observation = observe(player)
            local data = observation.joinDataOK and observation.joinData.TeleportData
            if type(data) == "table" and data.tag == tag then envelope = data; break end
        end
        if envelope and #list == 2 then break end
        if not envelope and argsOK and type(args) == "table" and args.tag == tag and #list == 2 then
            -- Give destination PlayerAdded/GetJoinData a chance before treating
            -- propagated test args as an origin launch.
            task.wait(0.3)
            for _, player in ipairs(Players:GetPlayers()) do
                local observation = observe(player)
                local data = observation.joinDataOK and observation.joinData.TeleportData
                if type(data) == "table" and data.tag == tag then envelope = data; break end
            end
            break
        end
        task.wait(0.1)
    until os.clock() >= deadline
    local list = Players:GetPlayers()
    assert(#list == 2, "Expected two real Studio clients")
    for _, player in ipairs(list) do result.observations[#result.observations + 1] = observe(player) end
    if envelope then
        result.role = "reserved destination"
        result.envelope = envelope
        assert(type(envelope.nonce) == "string" and #envelope.nonce == 36, "Missing nonce")
        assert(envelope.originMarker ~= marker, "Expected a distinct destination server marker")
        local actual, wanted = {}, {}
        for _, player in ipairs(list) do actual[#actual + 1] = player.UserId end
        for _, uid in ipairs(envelope.userIds) do wanted[#wanted + 1] = uid end
        table.sort(actual); table.sort(wanted)
        assert(#actual == #wanted, "Player count changed during teleport")
        for index, uid in ipairs(actual) do assert(uid == wanted[index], "Teleport changed UserId") end
        result.sameUserIds = true
        finish("PASS")
    else
        assert(argsOK and type(args) == "table" and args.tag == tag, "No tagged test args")
        assert(game.PlaceId > 0 and game.GameId > 0, "Use the private test experience")
        result.role = "origin"
        local userIds = {}; for _, player in ipairs(list) do userIds[#userIds + 1] = player.UserId end
        local options = Instance.new("TeleportOptions")
        options.ReservedServerId = HttpService:GenerateGUID(false)
        local data = {tag = tag, nonce = args.nonce, originMarker = marker,
            arenaServerId = options.ReservedServerId, userIds = userIds}
        options:SetTeleportData(data)
        result.envelope = data
        result.status = "TELEPORTING"; save()
        local teleported = TeleportService:TeleportAsync(game.PlaceId, list, options)
        result.teleportReturned = {privateServerId = teleported.PrivateServerId}
        result.status = "ORIGIN_SENT"; save()
    end
end, debug.traceback)
if not ok then finish("FAIL", tostring(failure)) end
