-- Group selection changes the observed world; membership and role eligibility stay server-owned.
local GroupPanel = {}
GroupPanel.__index = GroupPanel
local function sourceText(source,args)
    return (source:gsub('{([%w_]+):?[%w_]*}',function(key) return tostring(args and args[key] or '') end))
end

local statusNames = {Lobby = "Forming team", Active = "Playing", Won = "Victory", Lost = "Game over", Faulted = "Party stopped"}
local reasons = {
    ROLE_ACTIVE = "Finish playing your living character first.",
    ACTIVE_ROLE = "Finish playing your living character first.",
    ROLE_RESERVED = "Cancel your accepted boss invitation first.",
    GROUP_FULL = "This team has no free places.",
    GROUP_LIMIT = "The team limit has been reached.",
    UNKNOWN_GROUP = "This team is no longer available.",
    STALE_GROUP = "The selected team changed. Refreshing the list.",
    WRONG_GROUP = "The selected team changed. Refreshing the list.",
    HERO_LOCKED = "You cannot select another enemy role in this team.",
}

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

function GroupPanel.new(menuParent, spectatorParent, safeParent, sendIntent, colors, onToggle, translate, groupName)
    local self = setmetatable({sendIntent = sendIntent, colors = colors, onToggle = onToggle, rows = {},
        translate=translate,groupName=groupName}, GroupPanel)
    local function round(item, radius)
        make("UICorner", "Corner", item, {CornerRadius = UDim.new(0, radius or 12)})
        return item
    end
    local function text(parent, name, size, color, bold)
        return make("TextLabel", name, parent, {
            BackgroundTransparency = 1, Text = "", TextColor3 = color, TextSize = size,
            Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true, ZIndex = 73,
        })
    end
    local function button(parent, name, title, callback, zIndex)
        local item = round(make("TextButton", name, parent, {
            BackgroundColor3 = colors.card, BorderSizePixel = 0, Text = title,
            TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 14,
            TextWrapped = true, AutoButtonColor = false, ZIndex = zIndex or 73,
        }))
        item.Activated:Connect(callback)
        return item
    end
    self.menuCard = round(make("Frame", "Groups", menuParent, {
        BackgroundColor3 = colors.panel, BorderSizePixel = 0, LayoutOrder = 8, Visible = false,
    }))
    self.menuHeading = text(self.menuCard, "GroupHeading", 12, colors.lime, true)
    self.menuHeading.Text = "YOUR TEAM"
    self.menuCurrent = text(self.menuCard, "CurrentGroup", 18, colors.text, true)
    self.menuHelp = text(self.menuCard, "GroupHelp", 13, colors.muted, false)
    self.menuHelp.Text = "Other teams keep playing their games. You enter an active game as a spectator."
    self.menuButton = button(self.menuCard, "ChooseGroup", "Choose team", function() self:_setOpen(true) end, 1)
    self.hudButton = button(spectatorParent, "GroupsButton", "Groups", function() self:_setOpen(true) end, 2)
    self.hudButton.Visible = false

    self.overlay = make("Frame", "GroupSelector", safeParent, {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Active = true, ZIndex = 70,
    })
    self.backdrop = button(self.overlay, "GroupBackdrop", "", function() self:_setOpen(false) end, 70)
    self.backdrop.Size = UDim2.fromScale(1, 1)
    self.backdrop.BackgroundColor3, self.backdrop.BackgroundTransparency = colors.ink, 0.08
    self.backdrop.Modal = true
    self.shell = round(make("Frame", "GroupSelectorCard", self.overlay, {
        BackgroundColor3 = colors.panel, BorderSizePixel = 0, Active = true, ZIndex = 71,
    }), 16)
    self.title = text(self.shell, "GroupSelectorTitle", 21, colors.text, true)
    self.title.Text = "GROUPS"
    self.current = text(self.shell, "GroupSelectorCurrent", 14, colors.lime, true)
    self.close = button(self.shell, "CloseGroups", "Close", function() self:_setOpen(false) end)
    self.help = text(self.shell, "GroupSelectorHelp", 13, colors.muted, false)
    self.help.Text = "Join an active game as a spectator. Its heroes are already locked in."
    self.list = make("ScrollingFrame", "GroupList", self.shell, {
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
        ScrollBarImageColor3 = colors.muted, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 72,
    })
    make("UIListLayout", "GroupListLayout", self.list, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
    make("UIPadding", "GroupListPadding", self.list, {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)})
    self.empty = text(self.list, "NoOtherGroups", 14, colors.muted, false)
    self.empty.Text, self.empty.Size = "No other teams yet. Create your own.", UDim2.new(1, 0, 0, 64)
    self.create = button(self.shell, "CreateGroup", "Create team", function() self:_create() end)
    self.notice = text(self.shell, "GroupSelectorNotice", 12, colors.yellow, false)
    return self
end

function GroupPanel:isOpen()
    return self.overlay.Visible
end

function GroupPanel:_setOpen(open)
    if open and (not self.data or (not self.menuCard.Visible and not self.hudButton.Visible)) then return end
    self.overlay.Visible = open
    if self.onToggle then self.onToggle() end
end

function GroupPanel:_join(targetId)
    if not self.overlay.Visible or self.pending or not self.data then return end
    for _, group in ipairs(self.data.groups or {}) do
        if group.id == targetId and group.id ~= self.data.groupId and group.canJoin == true then
            self.pending, self.pendingAt = targetId, os.clock()
            self.sendIntent({kind = "JoinGroup", targetGroupId = targetId})
            self:_draw()
            return
        end
    end
end

function GroupPanel:_create()
    if not self.overlay.Visible or self.pending or not self.data or self.data.canCreateGroup ~= true then return end
    self.createRequestId = self.createRequestId or game:GetService("HttpService"):GenerateGUID(false)
    self.pending, self.pendingAt = "Create", os.clock()
    self.sendIntent({kind = "CreateGroup", requestId = self.createRequestId})
    self:_draw()
end

function GroupPanel:_draw()
    local data, seen, count = self.data, {}, 0
    if not data then return end
    local T=self.translate or sourceText
    local groupName=self.groupName or function(name) return T(name or 'Team') end
    local transfer = type(data.serverTransfer) == "table" and data.serverTransfer.state
    local serverPending, transferFailed = transfer == "Pending", transfer == "Failed"
    local currentName = groupName(data.groupName or "Current team",data.groupId)
    self.menuCurrent.Text, self.current.Text = currentName, T("Current: {team}", {team=currentName})
    self.menuButton.Text = self.pending and "Joining…" or "Choose team"
    for _, group in ipairs(data.groups or {}) do
        if group.id ~= data.groupId then
            count += 1
            seen[group.id] = true
            local row = self.rows[group.id]
            if not row then
                local targetId = group.id
                row = make("TextButton", "JoinGroup_" .. targetId, self.list, {
                    BackgroundColor3 = self.colors.card, BorderSizePixel = 0,
                    Text = "", TextColor3 = self.colors.text, Font = Enum.Font.Gotham,
                    TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 82), ZIndex = 73,
                })
                make("UICorner", "Corner", row, {CornerRadius = UDim.new(0, 10)})
                make("UIPadding", "TextPadding", row, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
                row.Activated:Connect(function() self:_join(targetId) end)
                self.rows[targetId] = row
            end
            local enabled = group.canJoin == true and not self.pending
            local action = group.status == "Active" and "Watch" or "Join team"
            if group.canJoin ~= true then action = reasons[group.reason] or "You cannot switch right now." end
            if self.pending == group.id then action = "Joining…" end
            row.Text = T("{team} · {status}\nHeroes: {heroes:int} · players: {players:int}\n{action}", {
                team=groupName(group.name or "Team",group.id),status=T(statusNames[group.status] or "Waiting"),
                heroes=group.heroes or 0,players=group.players or 0,action=T(action)})
            row.LayoutOrder, row.Active, row.Selectable = count, enabled, enabled
            row.TextColor3 = group.canJoin == true and self.colors.text or self.colors.muted
        end
    end
    for id, row in pairs(self.rows) do if not seen[id] then row:Destroy(); self.rows[id] = nil end end
    self.empty.Visible = count == 0
    self.create.Active = data.canCreateGroup == true and not self.pending
    self.create.Selectable = self.create.Active
    self.create.BackgroundColor3 = self.create.Active and self.colors.lime or self.colors.card
    self.create.TextColor3 = self.create.Active and self.colors.ink or self.colors.muted
    self.create.Text = serverPending and "Joining…" or (self.pending == "Create" and "Creating…"
        or (transferFailed and "Try again" or "Create team"))
    self.notice.Text = serverPending and "Moving to a new server…"
        or (self.pending and "Waiting for transfer confirmation…")
        or (transferFailed and "Could not move. Try again.")
        or (reasons[data.notice] or (data.canCreateGroup == false and "Team creation is currently unavailable." or ""))
end

function GroupPanel:update(data, hero)
    local changed = self.data and data and self.data.groupId ~= data.groupId
    local transfer = data and type(data.serverTransfer) == "table" and data.serverTransfer.state
    if changed then
        self.pending, self.createRequestId = nil, nil
        self.overlay.Visible = false
        self.list.CanvasPosition = Vector2.zero
    elseif transfer == "Pending" then
        self.pending = "Server"
    elseif transfer == "Failed" then
        self.pending, self.createRequestId = nil, nil
    elseif self.pending == "Server" then
        self.pending = nil
    elseif self.pending and data and data.notice then
        self.pending = nil
    end
    self.data = data
    local available = data ~= nil and type(data.groups) == "table"
    local active = data and data.status == "Active"
    local personalMenu = active and data.view == "Menu"
    local livingHero = hero and hero.status ~= "Eliminated"
    local livingEnemy = data and data.enemyRole and data.enemyRole.status ~= "Dead"
    self.menuCard.Visible = available and (not active or personalMenu == true)
    self.hudButton.Visible = available and active == true and not personalMenu and not livingHero and not livingEnemy
    if not self.menuCard.Visible and not self.hudButton.Visible then self.overlay.Visible = false end
    self:_draw()
end

function GroupPanel:step()
    if self.pending and self.pending ~= "Server" and os.clock() - self.pendingAt > 4 then
        self.pending = nil
        self.sendIntent({kind = "Sync"})
        self:_draw()
    end
end

function GroupPanel:layout(menuWidth, width, height, spectatorWidth)
    self.menuCard.Size = UDim2.new(1, 0, 0, menuWidth < 420 and 170 or 152)
    position(self.menuHeading, 14, 10, menuWidth - 28, 18)
    position(self.menuCurrent, 14, 32, menuWidth - 28, 24)
    position(self.menuHelp, 14, 60, menuWidth - 28, menuWidth < 420 and 49 or 31)
    position(self.menuButton, 14, menuWidth < 420 and 116 or 98, menuWidth - 28, 44)
    position(self.hudButton, spectatorWidth - 114, 5, 100, 44)
    local margin = width < 500 and 12 or 18
    local shellWidth, shellHeight = math.min(640, width - margin * 2), math.min(590, height - margin * 2)
    position(self.shell, (width - shellWidth) / 2, (height - shellHeight) / 2, shellWidth, shellHeight)
    local shallow = shellHeight < 380
    position(self.title, 14, 10, shellWidth - 126, 28)
    position(self.close, shellWidth - 104, 10, 90, 44)
    position(self.current, 14, 42, shellWidth - 126, shallow and 23 or 27)
    position(self.help, 14, shallow and 68 or 77, shellWidth - 28, shallow and 30 or 42)
    local listY = shallow and 104 or 128
    position(self.list, 14, listY, shellWidth - 28, math.max(42, shellHeight - listY - 83))
    position(self.create, 14, shellHeight - 76, shellWidth - 28, 44)
    position(self.notice, 14, shellHeight - 29, shellWidth - 28, 23)
end

return GroupPanel
