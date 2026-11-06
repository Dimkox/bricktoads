-- Inject into StarterPlayerScripts ONLY for a StudioTestService test session.
-- This driver exercises the real Intent RemoteEvent. It does not simulate keyboard/touch UI.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local StudioTestService = game:GetService("StudioTestService")
local argsOK, args = pcall(function() return StudioTestService:GetTestArgs() end)
if not argsOK or type(args) ~= "table" or args.tag ~= "CombatStandAcceptance" then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts", 60)
if not playerScripts then error("Acceptance client: PlayerScripts timeout") end

-- Prevent the presentation client's periodic Move packets from sharing our sequence space.
local disabled = {}
local function disablePresentation(instance)
    if instance:IsA("LocalScript") and instance.Name == "CombatStandClient" then
        instance.Enabled = false
        disabled[instance] = true
    end
end
playerScripts.DescendantAdded:Connect(disablePresentation)
for _, instance in ipairs(playerScripts:GetDescendants()) do disablePresentation(instance) end

local function required(parent, name)
    local instance = parent:WaitForChild(name, 60)
    if not instance then error("Acceptance client: missing " .. name) end
    return instance
end
local remotes = required(ReplicatedStorage, "CombatStand")
local intent = required(remotes, "Intent")
local stateRemote = required(remotes, "State")
local bridge = required(ReplicatedStorage, "CombatStandStudioAcceptance")
local command = required(bridge, "Command")
local reply = required(bridge, "Reply")
local snapshot, mine, identity = nil, nil, nil
local sequence = 0

local function status()
    local count = 0
    local allDisabled = true
    for instance in pairs(disabled) do
        if instance.Parent then
            count = count + 1
            if instance.Enabled then allDisabled = false end
        end
    end
    return {
        userId = player.UserId,
        name = player.Name,
        slot = snapshot and snapshot.mine,
        host = snapshot and snapshot.host,
        snapshot = snapshot,
        disabledPresentationScripts = count,
        presentationDisabled = count > 0 and allDisabled,
        sequence = sequence,
        identity = identity,
    }
end

local function ready()
    reply:FireServer({type = "Ready", state = status()})
end

stateRemote.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    snapshot, mine = data, nil
    for _, hero in ipairs(data.heroes or {}) do
        if hero.slot == data.mine then mine = hero; break end
    end
    -- Actor/attempt changes reset the server sequence on spawn; connections reset it too.
    local token = mine and table.concat({tostring(data.runId), tostring(data.levelEpoch),
        tostring(mine.actorId), tostring(mine.attempt), tostring(mine.connectionEpoch)}, ":") or nil
    if token ~= identity then identity, sequence = token, 0 end
    ready()
end)

local function actorIntent(kind, extra)
    if not snapshot or not mine or mine.status ~= "Alive" or not mine.connected then
        error("Acceptance client has no connected alive actor snapshot")
    end
    sequence = sequence + 1
    local payload = {kind = kind, runId = snapshot.runId, actorId = mine.actorId,
        attempt = mine.attempt, levelEpoch = snapshot.levelEpoch,
        connectionEpoch = mine.connectionEpoch, seq = sequence}
    for key, value in pairs(extra or {}) do payload[key] = value end
    intent:FireServer(payload)
    return payload
end

command.OnClientEvent:Connect(function(message)
    if type(message) ~= "table" or type(message.id) ~= "number" then return end
    local packet, leaveScheduled
    local ok, failure = xpcall(function()
        if message.kind == "Start" or message.kind == "Sync" then
            packet = {kind = message.kind}
            intent:FireServer(packet)
        elseif message.kind == "Attack" then
            if message.attack ~= "Punch" and message.attack ~= "Dash" then error("Unknown attack") end
            packet = actorIntent("Attack", {attack = message.attack})
        elseif message.kind == "AttackThenLeave" then
            if message.attack ~= "Punch" then error("AttackThenLeave requires Punch") end
            if not StudioTestService:CanLeaveTest() then error("This test client cannot LeaveTest") end
            packet = actorIntent("Attack", {attack = "Punch"})
            leaveScheduled = true
            -- Reply is sent by the common handler immediately; the server does not require it
            -- because a real client departure can discard the reply in transit.
            task.delay(0.03, function()
                local left, leaveFailure = xpcall(function()
                    if not StudioTestService:CanLeaveTest() then error("CanLeaveTest became false") end
                    StudioTestService:LeaveTest()
                end, debug.traceback)
                if not left then
                    reply:FireServer({type = "Reply", id = message.id, ok = false,
                        error = tostring(leaveFailure), packet = packet, state = status()})
                end
            end)
        elseif message.kind == "Move" then
            packet = actorIntent("Move", {x = message.x, z = message.z})
        elseif message.kind == "Jump" then
            packet = actorIntent("Jump")
        elseif message.kind == "Leave" then
            if not StudioTestService:CanLeaveTest() then error("This test client cannot LeaveTest") end
            reply:FireServer({type = "Reply", id = message.id, ok = true, state = status(), leaving = true})
            StudioTestService:LeaveTest()
            return
        else
            error("Unknown acceptance command: " .. tostring(message.kind))
        end
    end, debug.traceback)
    reply:FireServer({type = "Reply", id = message.id, ok = ok,
        error = not ok and tostring(failure) or nil, packet = packet,
        leaveScheduled = leaveScheduled, state = status()})
end)

-- Both the server listener and first State packet can arrive after this script starts.
-- Repeated readiness plus Sync makes that race bounded without inventing a player mapping.
task.spawn(function()
    while script.Parent and bridge.Parent do
        if not snapshot then intent:FireServer({kind = "Sync"}) end
        ready()
        task.wait(0.5)
    end
end)
