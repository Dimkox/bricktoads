-- Authority belongs to the current Player object, not merely its UserId.
local Registry = {}
Registry.__index = Registry

function Registry.new()
    return setmetatable({
        -- Tombstones prevent repeated add/remove events reviving an old object.
        -- Values contain no Player reference; departed objects can be collected.
        _seen = setmetatable({}, {__mode = "k"}),
        _current = {},
        _serial = 0,
    }, Registry)
end

function Registry:join(player)
    if self._seen[player] then return false, nil end
    local userId = player.UserId
    assert(userId ~= nil, "Connection requires Player.UserId")
    local previous = self._current[userId]
    if previous then self._seen[previous].active = false end
    self._serial = self._serial + 1
    self._seen[player] = {userId = userId, arrival = self._serial, active = true}
    self._current[userId] = player
    return true, previous
end

function Registry:isCurrent(player)
    local entry = self._seen[player]
    return entry ~= nil and entry.active and rawequal(self._current[entry.userId], player)
end

function Registry:remove(player)
    if not self:isCurrent(player) then return false end
    local entry = self._seen[player]
    entry.active = false
    self._current[entry.userId] = nil
    return true
end

function Registry:online(players)
    local result, included = {}, {}
    for _, player in ipairs(players) do
        if self:isCurrent(player) and not included[player] then
            included[player] = true
            result[#result + 1] = player
        end
    end
    table.sort(result, function(a, b)
        return self._seen[a].arrival < self._seen[b].arrival
    end)
    return result
end

return Registry
