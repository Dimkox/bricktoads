-- Private queue presentation. Joining never creates a body; the server owns the offer and role.
local BossQueuePanel = {}
BossQueuePanel.__index = BossQueuePanel
local bosses={
    {id='CausewayGuardian',name='Causeway Guardian'}, {id='BigBlag',name='Big Blag'},
    {id='RoboManus',name='Robo-Manus'}, {id='GeneralSlaughter',name='General Slaughter'},
    {id='Buzzball',name='Buzzball'}, {id='DarkQueen',name='Dark Queen'},
}
local function sourceText(source,args)
    return (source:gsub('{([%w_]+):?[%w_]*}',function(key) return tostring(args and args[key] or '') end))
end

local function make(className, name, parent, properties)
    local item = Instance.new(className)
    item.Name = name
    for key, value in pairs(properties or {}) do item[key] = value end
    item.Parent = parent
    return item
end

local function position(item, x, y, width, height)
    item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
end

function BossQueuePanel.new(menuParent, hudParent, sendIntent, colors, translate, groupName)
    local self = setmetatable({menuParent = menuParent, hudParent = hudParent,
        sendIntent = sendIntent, colors = colors, compact = false, translate=translate, groupName=groupName}, BossQueuePanel)
    self.card = make("Frame", "BossQueue", menuParent, {
        BackgroundColor3 = colors.panel, BorderSizePixel = 0, LayoutOrder = 7, Visible = false,
    })
    make("UICorner", "Corner", self.card, {CornerRadius = UDim.new(0, 14)})
    local function text(name, size, color, bold)
        return make("TextLabel", name, self.card, {
            BackgroundTransparency = 1, Text = "", TextColor3 = color,
            Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = size,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true,
        })
    end
    self.heading = text("Heading", 12, colors.yellow, true)
    self.heading.Text = "BOSS QUEUE"
    self.name = make('TextButton','BossChoice',self.card,{
        BackgroundTransparency=1,TextColor3=colors.text,TextSize=19,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutoButtonColor=false,
    })
    self.name.Text = "Causeway Guardian"
    self.selectedBoss=1
    self.name.Activated:Connect(function()
        if not self.pending and self.queue and self.queue.state=='None' then
            self.selectedBoss=self.selectedBoss%#bosses+1;self:_draw()
        end
    end)
    self.status = text("QueueStatus", 13, colors.yellow, true)
    self.status.TextXAlignment = Enum.TextXAlignment.Right
    self.detail = text("Detail", 13, colors.muted, false)
    self.note = text("RoleNote", 12, colors.muted, false)
    self.note.Text = "Tap the boss name to choose. Joining the queue does not assign a role immediately."
    local function action(name, callback)
        local item = make("TextButton", name, self.card, {
            BackgroundColor3 = colors.card, BorderSizePixel = 0, Text = "",
            TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 14,
            TextWrapped = true, AutoButtonColor = false,
        })
        make("UICorner", "Corner", item, {CornerRadius = UDim.new(0, 10)})
        item.Activated:Connect(callback)
        return item
    end
    self.primary = action("QueueAction", function() self:_activate(true) end)
    self.secondary = action("DeclineInvitation", function() self:_activate(false) end)
    return self
end

function BossQueuePanel:_remaining()
    return math.max(0, math.ceil((tonumber(self.queue and self.queue.deadline) or 0) - workspace:GetServerTimeNow()))
end

function BossQueuePanel:_activate(primary)
    if not self.card.Visible or self.pending or not self.queue then return end
    local state, packet = self.queue.state, nil
    if state == "Invited" and self.queue.offerId and self:_remaining() > 0 then
        packet = {kind = "ReplyBoss", offerId = self.queue.offerId, accepted = primary}
    elseif primary and state == "None" and self.queue.available == true then
        packet = {kind = "QueueBoss", bossId = bosses[self.selectedBoss].id}
    elseif primary and (state == "Queued" or state == "Accepted" or state == "Ready") then
        packet = {kind = "CancelBossQueue"}
    end
    if not packet then return end
    self.pending, self.pendingAt = state, os.clock()
    self.sendIntent(packet)
    self:_draw()
end

function BossQueuePanel:update(data, hero)
    local old = self.queue
    if data and self.groupId ~= data.groupId then
        self.pending, self.ackOffer, self.expiredOffer = nil, nil, nil
    end
    self.groupId = data and data.groupId
    self.queue = data and data.bossQueue
    local queue, active = self.queue, data and data.status == "Active"
    local livingEnemy = data and data.enemyRole and data.enemyRole.status ~= "Dead"
    local eligibleContext = data ~= nil and (not active or (not hero and not livingEnemy))
    self.card.Visible = queue ~= nil and eligibleContext
    self.compact = active == true and data.view ~= "Menu"
    self.card.Parent = self.compact and self.hudParent or self.menuParent
    if not queue or not old or old.state ~= queue.state or old.offerId ~= queue.offerId then
        self.pending = nil
    end
    if not queue or queue.offerId ~= self.ackOffer then
        self.ackOffer, self.ackCount, self.ackAt = queue and queue.offerId, 0, nil
        self.expiredOffer = nil
    end
    self:step()
end

function BossQueuePanel:_draw()
    local queue = self.queue
    if not queue then return end
    local state, colors = queue.state, self.colors
    local T=self.translate or sourceText
    local selected=bosses[self.selectedBoss]
    for _,boss in ipairs(bosses) do if queue.bossId==boss.id then selected=boss end end
    self.name.Text=T(selected.name)..(state=='None' and '  ›' or '')
    self.name.Active=state=='None' and not self.pending
    self.name.Selectable=self.name.Active
    local seconds = self:_remaining()
    local timed = state == "Invited" or state == "Accepted"
    local enabled, primaryText = false, "Unavailable"
    self.secondary.Visible = state == "Invited"
    if state == "Queued" then
        self.status.Text = queue.position and T("Queued · #{position:int}", {position=queue.position}) or T("Queued")
        self.detail.Text = "Choosing a regular enemy leaves the queue."
        primaryText, enabled = "Leave queue", true
    elseif state == "Invited" then
        self.status.Text = T("Invitation · {seconds:int} s", {seconds=seconds})
        local target = queue.groupName and ((self.groupName and self.groupName(queue.groupName,queue.groupId) or queue.groupName) .. " · ") or ""
        self.detail.Text = self.compact and (target .. T("Accept before time runs out."))
            or (target .. T("Accept the invitation before time runs out."))
        primaryText, enabled = "Accept", seconds > 0
    elseif state == "Accepted" then
        self.status.Text = T("Connecting · {seconds:int} s", {seconds=seconds})
        self.detail.Text = "Connecting automatically… your role is reserved."
        primaryText, enabled = "Cancel", true
    elseif state == "Ready" then
        self.status.Text = "Ready to fight"
        self.detail.Text = "Your boss role is reserved. Waiting for the encounter."
        primaryText, enabled = "Cancel", true
    elseif state == "Active" then
        self.status.Text = "In combat"
        self.detail.Text = T("You control {boss}.",{boss=T(selected.name)})
        primaryText = "Role assigned"
    else
        self.status.Text = queue.available == true and "Queue available" or "Unavailable"
        self.detail.Text = queue.available == true and "Wait for an invitation before this boss encounter."
            or "The queue is unavailable for your current role."
        primaryText, enabled = "Queue for boss", queue.available == true
    end
    if timed and seconds == 0 then
        self.status.Text, self.detail.Text = "Time expired", "Waiting for server confirmation…"
        enabled = false
    end
    if self.pending then primaryText = "Sending…" end
    enabled = enabled and not self.pending
    self.primary.Text, self.primary.Active, self.primary.Selectable = primaryText, enabled, enabled
    self.primary.BackgroundColor3 = enabled and colors.yellow or colors.card
    self.primary.TextColor3 = enabled and colors.ink or colors.muted
    self.secondary.Text = "Decline"
    self.secondary.Active, self.secondary.Selectable = enabled, enabled
    self.secondary.TextColor3 = enabled and colors.text or colors.muted
end

function BossQueuePanel:step()
    local queue = self.queue
    if not queue then return end
    if self.pending and os.clock() - self.pendingAt > 4 then
        self.pending = nil
        self.sendIntent({kind = "Sync"})
    end
    if queue.state == "Accepted" and not self.pending and queue.offerId and self:_remaining() > 0
        and (self.ackCount or 0) < 3 and (not self.ackAt or os.clock() - self.ackAt >= 2) then
        self.ackCount, self.ackAt = (self.ackCount or 0) + 1, os.clock()
        self.sendIntent({kind = "ConnectBoss", offerId = queue.offerId})
    end
    if (queue.state == "Invited" or queue.state == "Accepted") and self:_remaining() == 0
        and queue.offerId and self.expiredOffer ~= queue.offerId then
        self.expiredOffer = queue.offerId
        self.sendIntent({kind = "Sync"})
    end
    -- Only text and interaction state change each frame; geometry is owned by the main layout.
    if self.card.Visible then self:_draw() end
end

function BossQueuePanel:layout(width, compact, x, y)
    if not self.card.Visible then return 0 end
    self.compact = compact
    self.heading.Visible, self.note.Visible = not compact, not compact
    local height = compact and 100 or (width < 420 and 202 or 178)
    if compact then
        position(self.card, x or 0, y or 0, width, height)
        position(self.name, 12, 6, width * 0.43, 23)
        self.name.TextSize = width < 360 and 13 or 15
        position(self.status, width * 0.43 + 12, 6, width * 0.57 - 24, 23)
        self.status.TextSize = width < 360 and 11 or 12
        position(self.detail, 12, 29, width - 24, 22)
        self.detail.TextSize = width < 360 and 11 or 12
    else
        self.card.Size = UDim2.new(1, 0, 0, height)
        position(self.heading, 14, 10, width - 28, 18)
        position(self.name, 14, 31, width - 28, 25)
        self.name.TextSize = 19
        position(self.status, 14, 57, width - 28, 20)
        self.status.TextSize = 13
        self.status.TextXAlignment = Enum.TextXAlignment.Left
        position(self.detail, 14, 80, width - 28, width < 420 and 38 or 22)
        self.detail.TextSize = 13
        position(self.note, 14, width < 420 and 120 or 104, width - 28, width < 420 and 30 or 20)
    end
    if compact then self.status.TextXAlignment = Enum.TextXAlignment.Right end
    local inset, gap, buttonHeight = compact and 12 or 14, 8, compact and 40 or 42
    local innerWidth = width - inset * 2
    local half = (innerWidth - gap) / 2
    position(self.primary, inset, height - buttonHeight - 9, self.secondary.Visible and half or innerWidth, buttonHeight)
    position(self.secondary, inset + half + gap, height - buttonHeight - 9, half, buttonHeight)
    self.primary.TextSize, self.secondary.TextSize = compact and 13 or 14, compact and 13 or 14
    return height
end

return BossQueuePanel
