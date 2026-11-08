-- Deterministic service/transport doubles around the unmodified Stand entry point.
-- This proves gateway contracts, never authentication or real Roblox reconnect.
return function(boot, modules)
    local ctx = {time = 0, objects = {}, outbound = {}, instances = {}}
    local function signal()
        local handlers = {}
        return {Connect = function(_, fn) handlers[#handlers + 1] = fn end,
            Fire = function(_, ...) for _, fn in ipairs(handlers) do fn(...) end end}
    end
    local function clone(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for key, item in pairs(value) do copy[key] = clone(item) end
        return copy
    end
    local players = {PlayerAdded = signal(), PlayerRemoving = signal()}
    function players:GetPlayers() return table.clone(ctx.objects) end
    local run = {Heartbeat = signal(), IsStudio = function() return false end}
    local serial = 0
    local http = {GenerateGUID = function()
        serial = serial + 1; return "gateway-run-" .. serial
    end, JSONEncode = function() return "[fixture log]" end}
    local services = {Players = players, RunService = run, ReplicatedStorage = {}, HttpService = http}
    local game = {GetService = function(_, name) return assert(services[name], name) end}
    local instance = {new = function(className)
        local object = {ClassName = className, OnServerEvent = signal()}
        function object:FireClient(player, snapshot)
            ctx.outbound[#ctx.outbound + 1] = {player = player, snapshot = clone(snapshot)}
        end
        ctx.instances[#ctx.instances + 1] = object
        return object
    end}
    local world = modules.FakeWorld.new()
    world.names = {}
    function world:clearActors() self.actors = {} end
    function world:cue() end
    ctx.world = world
    local sessionFactory = {new = function(...)
        ctx.session = modules.Session.new(...)
        return ctx.session
    end}
    local dependency = {Config = modules.Config, RunLifecycle = modules.Core,
        Combat = modules.Combat, Session = sessionFactory,
        RobloxWorld = {new = function() return world end}, ConnectionRegistry = modules.Registry}
    local parent = {}; for name in pairs(dependency) do parent[name] = name end
    local function resolver(name) return assert(dependency[name], "Unknown module " .. tostring(name)) end
    boot(game, instance, resolver, {GetServerTimeNow = function() return ctx.time end},
        {Parent = parent}, function() end, function(message) error(message) end)

    function ctx:player(userId, name)
        return {UserId = userId, Name = name, DisplayName = name}
    end
    function ctx:add(player)
        player.Parent = players
        self.objects[#self.objects + 1] = player
        players.PlayerAdded:Fire(player)
    end
    function ctx:repeatAdded(player) players.PlayerAdded:Fire(player) end
    function ctx:remove(player)
        for i = #self.objects, 1, -1 do if self.objects[i] == player then table.remove(self.objects, i) end end
        player.Parent = nil
        players.PlayerRemoving:Fire(player)
    end
    function ctx:intent(player, payload)
        for _, object in ipairs(self.instances) do
            if object.Name == "Intent" then object.OnServerEvent:Fire(player, clone(payload)); return end
        end
        error("Intent remote missing")
    end
    function ctx:tick(seconds)
        self.time = self.time + (seconds or 0.1)
        run.Heartbeat:Fire()
    end
    function ctx:packet(slot, extra)
        local h = self.session.state.heroes[slot]
        local p = {kind = "Attack", attack = "Punch", runId = self.session.state.runId,
            actorId = h.actorId, attempt = h.attempt, levelEpoch = self.session.state.levelEpoch,
            connectionEpoch = h.connectionEpoch, seq = (self.session.lastSeq[slot] or 0) + 1}
        for key, value in pairs(extra or {}) do p[key] = value end
        if p.kind ~= "Attack" then p.attack = nil end
        return p
    end
    function ctx:latest(player)
        for i = #self.outbound, 1, -1 do
            if self.outbound[i].player == player then return self.outbound[i].snapshot end
        end
    end
    return ctx
end
