-- All entry metrics share the server join timestamp across group changes and restarts.
local FirstMinute = {}
FirstMinute.__index = FirstMinute

local starter = "FirstMinute"
local gameplay = "FirstMinuteGameplay"
local challenge = "FirstMinuteProgress"
local challenge120 = "EntryProgress120s"
local retention = "EntryRetention120s"
local manual120 = "EntryStart120s"
local windows = {[challenge120]=120, [manual120]=120}
local milestones = {"Joined", "Hero spawned", "First challenge engaged", "First challenge cleared"}
local labels = {
    [starter]={"Joined", "Pressed Start", "Hero spawned", "Damaged enemy", "Defeated enemy"},
    [gameplay]={"Joined", "Hero spawned", "Damaged enemy", "Defeated enemy"},
    [challenge]=milestones, [challenge120]=milestones,
    [manual120]={"Joined", "Pressed Start"},
    [retention]={"Joined", "Still here at 30s", "Still here at 60s", "Still here at 120s"},
}

function FirstMinute.new(clock, guid, log, reportError, schedule)
    return setmetatable({clock=clock, guid=guid, log=log, reportError=reportError or warn, schedule=schedule,
        visits={}, lastWarning={}}, FirstMinute)
end

function FirstMinute:_step(player, funnel, step)
    local visit = self.visits[player]
    if not visit or not visit[funnel] then return end
    if funnel ~= retention and self.clock() - visit.joined > (windows[funnel] or 60) then return end
    local progress = visit[funnel]
    -- Roblox fills skipped steps automatically. Only submit a step after its actual predecessor.
    if step > progress.observed + 1 then return end
    progress.observed = math.max(progress.observed, step)
    -- A later action can retry delivery of already observed steps, in order.
    while progress.sent < progress.observed do
        local nextStep = progress.sent + 1
        if not pcall(self.log, player, funnel, visit.id, nextStep, labels[funnel][nextStep], visit.route) then
            local now = self.clock()
            if now - (self.lastWarning[funnel] or -math.huge) >= 60 then
                self.lastWarning[funnel] = now
                self.reportError(("[BrickToads] Analytics delivery failed: %s step %d"):format(funnel, nextStep))
            end
            return
        end
        progress.sent = nextStep
    end
end

function FirstMinute:_measurePresence(player, visit)
    if self.visits[player] ~= visit then return end
    local elapsed = self.clock() - visit.joined
    if elapsed >= 30 then self:_step(player, retention, 2) end
    if elapsed >= 60 then self:_step(player, retention, 3) end
    if elapsed >= 120 then self:_step(player, retention, 4) end
end

function FirstMinute:join(player)
    local existing = self.visits[player]
    if existing then return existing.route end
    local joined = self.clock()
    local ok, data = pcall(function() return player:GetJoinData() end)
    local route = ok and type(data) == "table" and data.LaunchData == "speeder" and "speeder" or "untagged"
    local visit = {joined=joined, id=self.guid(), route=route}
    self.visits[player] = visit
    for funnel in pairs(labels) do
        if funnel ~= manual120 or route == "untagged" then
            visit[funnel] = {observed=0, sent=0}
            self:_step(player, funnel, 1)
        end
    end
    if self.schedule then
        local function measure() self:_measurePresence(player, visit) end
        for _, threshold in ipairs({30, 60, 120}) do
            self.schedule(math.max(0, joined + threshold - self.clock()), measure)
        end
    end
    return route
end

function FirstMinute:leave(player)
    local visit = self.visits[player]
    if visit then self:_measurePresence(player, visit) end
    self.visits[player] = nil
end

function FirstMinute:startPressed(player)
    self:_step(player, starter, 2)
    self:_step(player, manual120, 2)
end

function FirstMinute:_challenge(player, step, route)
    local visit = self.visits[player]
    if visit and (not route or visit.route == route) then
        self:_step(player, challenge, step)
        self:_step(player, challenge120, step)
    end
end

function FirstMinute:spawned(player)
    self:_step(player, starter, 3)
    self:_step(player, gameplay, 2)
    self:_challenge(player, 2)
end

function FirstMinute:enemyHit(player, defeated)
    self:_step(player, starter, 4)
    self:_step(player, gameplay, 3)
    self:_challenge(player, 3, "untagged")
    if defeated then self:enemyDefeated(player) end
end

function FirstMinute:enemyDefeated(player)
    self:_step(player, starter, 5)
    self:_step(player, gameplay, 4)
    self:_challenge(player, 4, "untagged")
end

function FirstMinute:boarded(player)
    self:_challenge(player, 3, "speeder")
end

function FirstMinute:passedFirstWall(player)
    self:_challenge(player, 4, "speeder")
end

return FirstMinute
