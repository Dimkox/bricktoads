-- Presentation and input only. The server owns the run, actors and combat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrickToadsGame")
local intent = remotes:WaitForChild("Intent")
local stateRemote = remotes:WaitForChild("State")

local C = {
    ink = Color3.fromRGB(12, 20, 32), panel = Color3.fromRGB(22, 35, 49),
    card = Color3.fromRGB(31, 48, 61), line = Color3.fromRGB(72, 96, 107),
    text = Color3.fromRGB(244, 241, 224), muted = Color3.fromRGB(164, 185, 188),
    lime = Color3.fromRGB(195, 235, 104), red = Color3.fromRGB(250, 115, 107),
    green = Color3.fromRGB(126, 204, 124), yellow = Color3.fromRGB(241, 206, 103),
    brown = Color3.fromRGB(197, 146, 106),
}
local templates = {"Mr. Green", "Mr. Yellow", "Mr. Brown"}
local heroColors = {[templates[1]] = C.green, [templates[2]] = C.yellow, [templates[3]] = C.brown}
local snapshot, mine, identity = nil, nil, nil
local sequence = 0
local keys, touchVector, dragging = {}, Vector2.zero, nil
local pendingTemplate, pendingAt = nil, 0
local actionPending, actionAt = false, 0
local width, height = 900, 650

local function make(className, name, parent, props)
    local item = Instance.new(className)
    item.Name = name
    for key, value in pairs(props or {}) do item[key] = value end
    item.Parent = parent
    return item
end
local function corner(parent, radius)
    return make("UICorner", "Corner", parent, {CornerRadius = UDim.new(0, radius or 14)})
end
local function stroke(parent, color, thickness)
    return make("UIStroke", "Outline", parent, {
        Color = color or C.line, Thickness = thickness or 1, Transparency = 0.55,
    })
end
local function frame(parent, name, color)
    return make("Frame", name, parent, {BackgroundColor3 = color or C.panel, BorderSizePixel = 0})
end
local function label(parent, name, text, size, color, bold)
    return make("TextLabel", name, parent, {
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = size or 16, TextColor3 = color or C.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    })
end
local function button(parent, name, text, color, callback)
    local item = make("TextButton", name, parent, {
        BackgroundColor3 = color or C.card, BorderSizePixel = 0,
        Text = text, TextColor3 = C.text, Font = Enum.Font.GothamBold,
        TextSize = 16, TextWrapped = true, AutoButtonColor = false,
    })
    corner(item, 14)
    item.Activated:Connect(callback)
    return item
end
local function position(item, x, y, w, h)
    item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
end

local gui = make("ScreenGui", "BrickToadsGameUI", player:WaitForChild("PlayerGui"), {
    ResetOnSpawn = false, DisplayOrder = 20, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    ClipToDeviceSafeArea = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local safe = make("Frame", "SafeArea", gui, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)})
local overlay = frame(safe, "Menu", C.ink)
overlay.Size, overlay.BackgroundTransparency = UDim2.fromScale(1, 1), 0.18
make("UIGradient", "Atmosphere", overlay, {
    Color = ColorSequence.new(Color3.fromRGB(27, 49, 59), C.ink), Rotation = 110,
})
local shell = frame(overlay, "Shell", C.ink)
shell.BackgroundTransparency, shell.AnchorPoint = 1, Vector2.new(0.5, 0.5)
shell.Position = UDim2.fromScale(0.5, 0.5)
local scroll = make("ScrollingFrame", "SelectionContent", shell, {
    BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.muted, ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIPadding", "ScrollPadding", scroll, {
    PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 9),
    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14),
})
local menuLayout = make("UIListLayout", "MenuLayout", scroll, {
    FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 14),
})
local header = frame(scroll, "Header")
header.BackgroundTransparency, header.LayoutOrder = 1, 1
local brand = label(header, "Brand", "BRICK TOADS", 15, C.lime, true)
local title = label(header, "Title", "Затопленный тракт", 35, C.text, true)
local intro = label(header, "Intro", "Соберите команду, пройдите тракт и откройте ворота.", 16, C.muted)
local resultBanner = frame(scroll, "Result", C.card)
resultBanner.LayoutOrder, resultBanner.Visible = 2, false
corner(resultBanner, 16)
local resultAccent = frame(resultBanner, "Accent", C.lime)
corner(resultAccent, 3)
local resultTitle = label(resultBanner, "ResultTitle", "ТРАКТ ПРОЙДЕН", 23, C.lime, true)
local resultDetail = label(resultBanner, "ResultDetail", "", 15, C.text)
local selectionHeading = frame(scroll, "ChooseHero")
selectionHeading.LayoutOrder, selectionHeading.BackgroundTransparency = 3, 1
local chooseTitle = label(selectionHeading, "Heading", "ВЫБЕРИТЕ ГЕРОЯ", 13, C.lime, true)
local chooseNote = label(selectionHeading, "EqualAbilities", "Одинаковые способности. Можно выбрать одного героя всей командой.", 14, C.muted)
local cardsContainer = frame(scroll, "HeroCards")
cardsContainer.LayoutOrder, cardsContainer.BackgroundTransparency = 4, 1
local heroCards = {}

-- Original asset-free portraits remain readable at small phone sizes.
local function toadPortrait(parent, color)
    local art = frame(parent, "Portrait", C.ink)
    art.BackgroundTransparency, art.ClipsDescendants = 0.2, true
    corner(art, 18)
    local function shape(name, x, y, w, h, tint, radius)
        local item = frame(art, name, tint)
        item.Position, item.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
        corner(item, radius or 8)
    end
    shape("LeftArm", 0.1, 0.55, 0.18, 0.32, color)
    shape("RightArm", 0.72, 0.55, 0.18, 0.32, color)
    shape("Body", 0.25, 0.48, 0.5, 0.46, color, 14)
    shape("Belly", 0.35, 0.58, 0.3, 0.24, Color3.fromRGB(233, 221, 165))
    shape("Head", 0.19, 0.22, 0.62, 0.39, color, 18)
    for _, x in ipairs({0.26, 0.58}) do
        shape("Eye", x, 0.14, 0.17, 0.23, C.text, 10)
        shape("Pupil", x + 0.058, 0.2, 0.075, 0.105, C.ink, 8)
    end
    shape("Mouth", 0.36, 0.47, 0.28, 0.025, C.ink, 2)
    shape("Belt", 0.25, 0.81, 0.5, 0.06, C.ink, 2)
    return art
end
for i, template in ipairs(templates) do
    local card = button(cardsContainer, "Hero" .. i, "", C.card, function()
        if not snapshot or not snapshot.canSelect or pendingTemplate then return end
        if snapshot.selectedTemplate == template then return end
        pendingTemplate, pendingAt = template, os.clock()
        intent:FireServer({kind = "SelectHero", template = template})
    end)
    card.ClipsDescendants = true
    heroCards[i] = {
        button = card, outline = stroke(card, C.line, 1),
        accent = frame(card, "Accent", heroColors[template]),
        art = toadPortrait(card, heroColors[template]), template = template,
        name = label(card, "HeroName", template, 21, C.text, true),
        choice = label(card, "Selection", "ВЫБРАТЬ", 12, C.muted, true),
        detail = label(card, "Detail", "Удар · таран · прыжок", 13, C.muted),
    }
end
local party = frame(scroll, "Party", C.panel)
party.LayoutOrder = 5
corner(party, 16)
local partyTitle = label(party, "PartyTitle", "КОМАНДА · 1–3 ИГРОКА", 13, C.muted, true)
local partyCount = label(party, "PartyCount", "", 13, C.lime, true)
partyCount.TextXAlignment = Enum.TextXAlignment.Right
local partyRows = {}
for i = 1, 3 do
    local dot = frame(party, "PlayerColor" .. i, C.line)
    corner(dot, 4)
    local owner = label(party, "Owner" .. i, "", 15, C.text, true)
    owner.TextWrapped, owner.TextTruncate = false, Enum.TextTruncate.AtEnd
    local choice = label(party, "Template" .. i, "", 13, C.muted)
    choice.TextWrapped, choice.TextTruncate = false, Enum.TextTruncate.AtEnd
    partyRows[i] = {dot = dot, owner = owner, choice = choice}
end
local partyNote = label(party, "PartyNote", "", 13, C.muted)
-- The primary action stays visible while the hero choices scroll on phones.
local footer = frame(shell, "StartArea", C.ink)
footer.AnchorPoint, footer.Position = Vector2.new(0, 1), UDim2.fromScale(0, 1)
local startButton = button(footer, "Start", "Подключаемся…", C.line, function()
    if not snapshot or not snapshot.canStart or actionPending then return end
    actionPending, actionAt = true, os.clock()
    intent:FireServer({kind = "Start"})
end)
startButton.TextSize = 19
local waitLabel = label(footer, "HostWait", "Ждём ответ игры…", 14, C.muted)
waitLabel.TextXAlignment = Enum.TextXAlignment.Center
local menuNotice = label(footer, "Notice", "", 14, C.yellow)
menuNotice.TextXAlignment = Enum.TextXAlignment.Center

local hud = frame(safe, "HUD")
hud.BackgroundTransparency, hud.Size, hud.Visible = 1, UDim2.fromScale(1, 1), false
local roster = frame(hud, "HeroRoster")
roster.BackgroundTransparency = 1
local heroRows = {}
for slot = 1, 3 do
    local row = frame(roster, "Hero" .. slot, C.ink)
    row.BackgroundTransparency = 0.12
    corner(row, 12)
    local stripe = frame(row, "HeroColor", C.green)
    corner(stripe, 3)
    local owner = label(row, "Owner", "", 14, C.text, true)
    owner.TextWrapped, owner.TextTruncate = false, Enum.TextTruncate.AtEnd
    local status = label(row, "Status", "", 11, C.muted)
    status.TextWrapped, status.TextTruncate = false, Enum.TextTruncate.AtEnd
    local returns = label(row, "Respawns", "", 11, C.muted)
    returns.TextXAlignment, returns.TextWrapped = Enum.TextXAlignment.Right, false
    local fills = {}
    for i = 1, 5 do
        local heart = label(row, "Heart" .. i, "♥", 21, C.line)
        local clip = frame(heart, "FillClip")
        clip.BackgroundTransparency, clip.ClipsDescendants = 1, true
        clip.Size = UDim2.fromScale(1, 1)
        local fill = label(clip, "Fill", "♥", 21, C.red)
        fill.Size = UDim2.fromOffset(22, 25)
        fills[i] = {heart = heart, clip = clip, fill = fill}
    end
    heroRows[slot] = {row = row, stripe = stripe, owner = owner, status = status,
        returns = returns, fills = fills}
end
local objective = frame(hud, "Objective", C.ink)
objective.BackgroundTransparency = 0.1
corner(objective, 14)
local stageLabel = label(objective, "Stage", "ЗАТОПЛЕННЫЙ ТРАКТ", 12, C.lime, true)
local objectiveLabel = label(objective, "Task", "Доберитесь до ворот", 17, C.text, true)
local bossLabel = label(objective, "BossHits", "", 13, C.yellow)
local spectator = frame(hud, "Spectator", C.ink)
spectator.BackgroundTransparency, spectator.AnchorPoint = 0.08, Vector2.new(0.5, 1)
corner(spectator, 14)
local spectatorText = label(spectator, "Message", "Вы наблюдаете · состав этой игры уже закреплён.", 14, C.text)
spectatorText.TextXAlignment = Enum.TextXAlignment.Center
local controls = frame(hud, "Controls")
controls.BackgroundTransparency, controls.Size = 1, UDim2.fromScale(1, 1)
local function playable()
    return snapshot and snapshot.status == "Active" and mine and mine.status == "Alive"
        and mine.connected == true and not mine.dying and not snapshot.fault
end
local function send(kind, extra)
    if not playable() or not snapshot.runId or not mine.actorId then return end
    sequence += 1
    local packet = {kind = kind, runId = snapshot.runId, actorId = mine.actorId,
        attempt = mine.attempt, levelEpoch = snapshot.levelEpoch,
        connectionEpoch = mine.connectionEpoch, seq = sequence}
    for key, value in pairs(extra or {}) do packet[key] = value end
    intent:FireServer(packet)
end
local actions = frame(controls, "Actions")
actions.BackgroundTransparency, actions.AnchorPoint = 1, Vector2.new(1, 1)
local punch = button(actions, "Punch", "УДАР\nF", C.card, function() send("Attack", {attack = "Punch"}) end)
local dash = button(actions, "Dash", "ТАРАН\nR", C.card, function() send("Attack", {attack = "Dash"}) end)
local jump = button(actions, "Jump", "ПРЫЖОК · SPACE", C.lime, function() send("Jump") end)
jump.TextColor3 = C.ink
stroke(punch, C.muted, 1)
stroke(dash, C.muted, 1)
local pad = frame(controls, "MoveStick", C.ink)
pad.BackgroundTransparency, pad.Active, pad.AnchorPoint = 0.15, true, Vector2.new(0, 1)
corner(pad, 100)
stroke(pad, C.muted, 2)
local padRing = frame(pad, "InnerRing", C.card)
padRing.BackgroundTransparency = 0.2
padRing.Size, padRing.Position = UDim2.fromScale(0.68, 0.68), UDim2.fromScale(0.16, 0.16)
corner(padRing, 100)
local knob = frame(pad, "Knob", C.lime)
knob.AnchorPoint, knob.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
knob.Size = UDim2.fromScale(0.34, 0.34)
corner(knob, 100)
local keyboardHint = label(controls, "KeyboardHint", "W A S D  ·  движение", 13, C.text)
keyboardHint.AnchorPoint = Vector2.new(0, 1)
keyboardHint.BackgroundColor3, keyboardHint.BackgroundTransparency = C.ink, 0.15
corner(keyboardHint, 10)
keyboardHint.TextXAlignment = Enum.TextXAlignment.Center
local fault = frame(safe, "GameMessage", C.ink)
fault.AnchorPoint, fault.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
fault.Size, fault.Visible = UDim2.new(1, -36, 0, 92), false
corner(fault, 16)
make("UISizeConstraint", "MaxWidth", fault, {MaxSize = Vector2.new(540, 92)})
local faultText = label(fault, "Message", "Игра приостановлена. Ждём восстановления игры…", 17, C.text, true)
faultText.Position, faultText.Size = UDim2.fromOffset(18, 12), UDim2.new(1, -36, 1, -24)
faultText.TextXAlignment = Enum.TextXAlignment.Center

local function resetInput()
    keys, dragging, touchVector = {}, nil, Vector2.zero
    knob.Position = UDim2.fromScale(0.5, 0.5)
end
local function heroName(hero)
    return hero.displayName or hero.username or ("Игрок " .. tostring(hero.slot or ""))
end
local function hostName()
    for _, owner in ipairs(snapshot and snapshot.lobby or {}) do
        if owner.userId == snapshot.host then return owner.displayName or owner.username or "ведущий" end
    end
    return "ведущий"
end
local noticeMessages = {
    NOT_HOST = "Игру начинает ведущий команды.", HOST_ONLY = "Игру начинает ведущий команды.",
    BAD_TEMPLATE = "Выберите одного из трёх героев.", INVALID_TEMPLATE = "Выберите одного из трёх героев.",
    UNKNOWN_TEMPLATE = "Выберите одного из трёх героев.",
    RUN_ACTIVE = "Смена героя доступна перед следующей игрой.",
    ACTIVE_RUN = "Смена героя доступна перед следующей игрой.", ALREADY_ACTIVE = "Игра уже началась.",
    ROSTER_FULL = "Команда собрана. Можно наблюдать за игрой.", NO_PLAYERS = "Ждём участников команды.",
    START_FAILED = "Не удалось начать игру. Попробуйте ещё раз.",
}
local function renderSelection()
    for _, card in ipairs(heroCards) do
        local selected = snapshot and snapshot.selectedTemplate == card.template
        card.outline.Color = selected and heroColors[card.template] or C.line
        card.outline.Thickness, card.outline.Transparency = selected and 2 or 1, selected and 0 or 0.55
        card.button.BackgroundColor3 = selected and Color3.fromRGB(43, 63, 65) or C.card
        card.choice.TextColor3 = selected and heroColors[card.template] or C.muted
        card.choice.Text = selected and "✓ ВЫБРАН" or "ВЫБРАТЬ"
        if pendingTemplate == card.template then card.choice.Text = "ВЫБИРАЕМ…" end
        if snapshot and not snapshot.canSelect and not selected then card.choice.Text = "ВЫБОР ЗАКРЫТ" end
        card.button.Selectable = snapshot ~= nil and snapshot.canSelect == true
    end
end
local function render()
    local active = snapshot and snapshot.status == "Active"
    local completed = snapshot and (snapshot.status == "Won" or snapshot.status == "Lost")
    overlay.Visible, hud.Visible, controls.Visible = not active, active == true, playable() == true
    fault.Visible = snapshot ~= nil and snapshot.fault ~= nil and snapshot.fault ~= false
    resultBanner.Visible = completed == true
    if completed then
        local won = snapshot.status == "Won"
        resultTitle.Text = won and "ТРАКТ ПРОЙДЕН!" or "КОМАНДА ВЫБЫЛА"
        resultTitle.TextColor3, resultAccent.BackgroundColor3 = won and C.lime or C.red, won and C.lime or C.red
        resultDetail.Text = won and "Страж побеждён. Ворота открыты — команда добралась до выхода."
            or "Возвраты закончились. Выберите героев и попробуйте пройти тракт ещё раз."
        intro.Text, chooseTitle.Text = "Следующая попытка начинается по кнопке «Новая игра».", "ГЕРОЙ ДЛЯ СЛЕДУЮЩЕЙ ИГРЫ"
    else
        intro.Text, chooseTitle.Text = "Соберите команду, пройдите тракт и откройте ворота.", "ВЫБЕРИТЕ ГЕРОЯ"
    end
    renderSelection()
    local owners = snapshot and snapshot.lobby or {}
    partyCount.Text = snapshot and (tostring(math.min(#owners, 3)) .. " / 3") or ""
    for i, row in ipairs(partyRows) do
        local owner = owners[i]
        row.dot.Visible, row.owner.Visible, row.choice.Visible = owner ~= nil, owner ~= nil, owner ~= nil
        if owner then
            row.dot.BackgroundColor3 = heroColors[owner.template] or C.green
            row.owner.Text = (owner.displayName or owner.username or "Игрок") .. (owner.userId == player.UserId and " · вы" or "")
            row.choice.Text = owner.template or "Mr. Green"
        end
    end
    local online = snapshot and snapshot.online or 0
    partyNote.Text = online > 3 and ("Ещё наблюдают: " .. tostring(online - 3))
        or (snapshot and "После старта состав команды закрепляется до конца игры." or "Подключаемся к игре…")
    startButton.Visible = not snapshot or snapshot.canStart == true
    startButton.BackgroundColor3, startButton.TextColor3 = snapshot and snapshot.canStart and C.lime or C.line,
        snapshot and snapshot.canStart and C.ink or C.text
    startButton.Text = actionPending and "Начинаем…" or (completed and "Новая игра" or "Начать игру")
    if not snapshot then startButton.Text = "Подключаемся…" end
    waitLabel.Text = not snapshot and "Ждём ответ игры…" or (snapshot.canStart
        and "Можно играть одному, вдвоём или втроём." or ("Ожидаем: " .. hostName() .. " начнёт игру."))
    menuNotice.Text = snapshot and (noticeMessages[snapshot.notice] or "") or ""
    for i, row in ipairs(heroRows) do
        local hero = snapshot and snapshot.heroes and snapshot.heroes[i]
        row.row.Visible = hero ~= nil
        if hero then
            row.owner.Text = heroName(hero) .. (hero.slot == snapshot.mine and " · вы" or "")
            row.owner.TextColor3 = hero.slot == snapshot.mine and C.lime or C.text
            row.stripe.BackgroundColor3 = heroColors[hero.template] or C.green
            row.returns.Text = "↻ " .. tostring(hero.respawns or 0)
            local detail = hero.template or "Mr. Green"
            if not hero.connected then detail = "Нет связи"
            elseif hero.status == "Eliminated" then detail = "Выбыл"
            elseif hero.status ~= "Alive" or hero.dying then detail = "Возвращается…"
            elseif hero.shield then detail ..= " · защита" end
            row.status.Text = detail
            local hp = tonumber(hero.hearts) or 0
            for n, heart in ipairs(row.fills) do heart.clip.Size = UDim2.fromScale(math.clamp(hp - n + 1, 0, 1), 1) end
        end
    end
    local level = snapshot and snapshot.level or {}
    local isBoss = string.find(string.lower(tostring(level.stage or "")), "boss", 1, true) ~= nil
    stageLabel.Text = isBoss and "СТРАЖ ТРАКТА" or "ЗАТОПЛЕННЫЙ ТРАКТ"
    objectiveLabel.Text = level.objective or "Пройдите тракт и доберитесь до ворот."
    local hits = tonumber(level.bossHits) or 0
    if isBoss or hits > 0 then
        bossLabel.Text = "Отражено снарядов: " .. tostring(hits) .. " / " .. tostring(level.bossMax or 3)
    else
        local alive = 0
        for _, enemy in ipairs(level.enemies or {}) do
            if enemy.alive ~= false and enemy.status ~= "Eliminated" and (enemy.hearts == nil or enemy.hearts > 0) then alive += 1 end
        end
        bossLabel.Text = alive > 0 and ("Противников впереди: " .. tostring(alive)) or "Ударьте снаряд стража, чтобы отразить его."
    end
    spectator.Visible = active == true and not playable()
    spectatorText.Text = mine and mine.status ~= "Eliminated" and mine.connected
        and "Герой возвращается… Состав этой игры уже закреплён." or "Вы наблюдаете · состав этой игры уже закреплён."
end

local function layout()
    width, height = safe.AbsoluteSize.X, safe.AbsoluteSize.Y
    if width < 1 or height < 1 then return end
    local compact, portrait = width < 620, height > width
    local shortLandscape = width >= 620 and height < 560
    local margin = shortLandscape and 12 or (width < 500 and 14 or 24)
    local shellWidth = math.min(960, width - margin * 2)
    shell.Size = UDim2.fromOffset(shellWidth, height - margin * 2)
    local contentWidth = shellWidth - 12
    scroll.Size = UDim2.new(1, 0, 1, shortLandscape and -92 or -116)
    menuLayout.Padding = UDim.new(0, shortLandscape and 8 or 14)
    header.Size = UDim2.new(1, 0, 0, shortLandscape and 54 or (compact and 104 or 112))
    position(brand, 0, 0, contentWidth, 22)
    position(title, 0, 26, contentWidth, compact and 34 or 43)
    title.TextSize = compact and 27 or 35
    position(intro, 0, compact and 64 or 72, contentWidth, 38)
    intro.TextSize = compact and 14 or 16
    intro.Visible = not shortLandscape
    if shortLandscape then
        position(brand, 0, 0, contentWidth, 17)
        position(title, 0, 19, contentWidth, 31)
        brand.TextSize, title.TextSize = 12, 27
    else brand.TextSize = 15 end
    resultBanner.Size = UDim2.new(1, 0, 0, compact and 112 or 102)
    position(resultAccent, 0, 14, 4, compact and 84 or 74)
    position(resultTitle, 18, 10, contentWidth - 36, 34)
    resultTitle.TextSize = compact and 21 or 23
    position(resultDetail, 18, 47, contentWidth - 36, compact and 52 or 42)
    selectionHeading.Size = UDim2.new(1, 0, 0, shortLandscape and 34 or (compact and 64 or 49))
    position(chooseTitle, 0, 0, contentWidth, 20)
    position(chooseNote, 0, 24, contentWidth, compact and 38 or 22)
    if shortLandscape then
        position(chooseTitle, 0, 0, contentWidth, 16)
        position(chooseNote, 0, 18, contentWidth, 16)
    end
    chooseNote.TextSize = shortLandscape and 12 or 14
    local cardHeight = shortLandscape and 100 or (compact and 104 or 222)
    cardsContainer.Size = UDim2.new(1, 0, 0, compact and (cardHeight * 3 + 20) or cardHeight)
    local cardWidth = compact and contentWidth or (contentWidth - 24) / 3
    for i, card in ipairs(heroCards) do
        position(card.button, compact and 0 or (i - 1) * (cardWidth + 12), compact and (i - 1) * (cardHeight + 10) or 0, cardWidth, cardHeight)
        position(card.accent, 0, 0, 4, cardHeight)
        card.detail.Visible = not shortLandscape
        if shortLandscape then
            position(card.art, 13, 14, 50, 56)
            position(card.name, 75, 13, cardWidth - 85, 26)
            card.name.TextSize = width < 760 and 16 or 19
            position(card.choice, 75, 48, cardWidth - 85, 20)
        elseif compact then
            position(card.art, 14, 12, 76, 80)
            position(card.name, 104, 13, cardWidth - 115, 28)
            card.name.TextSize = width < 350 and 17 or 20
            position(card.detail, 104, 44, cardWidth - 115, 23)
            card.detail.TextSize = width < 350 and 11 or 12
            position(card.choice, 104, 73, cardWidth - 115, 19)
        else
            position(card.art, 16, 15, cardWidth - 32, 119)
            position(card.name, 16, 144, cardWidth - 32, 28)
            position(card.detail, 16, 175, cardWidth - 32, 20)
            position(card.choice, 16, 199, cardWidth - 32, 18)
            card.name.TextSize, card.detail.TextSize = 21, 13
        end
    end
    local owners = snapshot and math.min(#(snapshot.lobby or {}), 3) or 1
    local rowHeight, noteHeight = compact and 42 or 35, compact and 38 or 22
    party.Size = UDim2.new(1, 0, 0, 48 + math.max(owners, 1) * rowHeight + noteHeight)
    position(partyTitle, 16, 12, contentWidth - 90, 20)
    partyTitle.TextSize = width < 350 and 11 or 13
    position(partyCount, contentWidth - 66, 12, 48, 20)
    for i, row in ipairs(partyRows) do
        local y = 42 + (i - 1) * rowHeight
        position(row.dot, 16, y + 7, 8, 8)
        if compact then
            position(row.owner, 34, y, contentWidth - 50, 20)
            position(row.choice, 34, y + 20, contentWidth - 50, 17)
        else
            position(row.owner, 34, y, contentWidth - 200, 24)
            position(row.choice, contentWidth - 152, y, 136, 24)
        end
        row.choice.TextXAlignment = compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    end
    position(partyNote, 16, 43 + math.max(owners, 1) * rowHeight, contentWidth - 32, noteHeight)
    footer.Size = UDim2.new(1, 0, 0, 108)
    position(startButton, 3, 0, contentWidth, 52)
    position(waitLabel, 3, 56, contentWidth, 31)
    position(menuNotice, 3, 88, contentWidth, 20)
    if snapshot and snapshot.canStart == false then position(waitLabel, 3, 8, contentWidth, 47) end
    if shortLandscape then
        footer.Size = UDim2.new(1, 0, 0, 84)
        position(startButton, 3, 0, contentWidth, 44)
        position(waitLabel, 3, 46, contentWidth, 20)
        position(menuNotice, 3, 68, contentWidth, 16)
        waitLabel.TextSize, menuNotice.TextSize = 12, 12
        if snapshot and snapshot.canStart == false then position(waitLabel, 3, 8, contentWidth, 38) end
    else waitLabel.TextSize, menuNotice.TextSize = 14, 14 end

    local inset, short = width < 500 and 12 or 18, height < 480
    local rosterWidth = portrait and (width - inset * 2) or math.min(292, width * 0.43)
    local rowHeightHUD, gap = short and 45 or 62, short and 5 or 7
    local count = snapshot and math.min(#(snapshot.heroes or {}), 3) or 1
    local rosterHeight = count * (rowHeightHUD + gap)
    position(roster, inset, inset, rosterWidth, rosterHeight)
    for i, row in ipairs(heroRows) do
        position(row.row, 0, (i - 1) * (rowHeightHUD + gap), rosterWidth, rowHeightHUD)
        position(row.stripe, 0, 9, 3, rowHeightHUD - 18)
        position(row.owner, 11, short and 2 or 5, rosterWidth - 63, 20)
        row.owner.TextSize = short and 12 or 14
        position(row.status, 126, short and 23 or 34, rosterWidth - 137, 17)
        position(row.returns, rosterWidth - 45, short and 3 or 6, 34, 17)
        for n, heart in ipairs(row.fills) do
            position(heart.heart, 10 + (n - 1) * 22, short and 21 or 29, 22, 25)
            heart.heart.TextSize, heart.fill.TextSize = short and 19 or 21, short and 19 or 21
        end
    end
    if portrait then
        position(objective, inset, inset + rosterHeight + 2, width - inset * 2, 100)
    else
        local objectiveWidth = math.min(420, width - rosterWidth - inset * 3)
        position(objective, width - inset - objectiveWidth, inset, objectiveWidth, short and 92 or 106)
    end
    stageLabel.Position, stageLabel.Size = UDim2.fromOffset(13, 9), UDim2.new(1, -26, 0, 17)
    objectiveLabel.Position, objectiveLabel.Size = UDim2.fromOffset(13, 29), UDim2.new(1, -26, 0, short and 33 or 40)
    objectiveLabel.TextSize = short and 14 or 16
    bossLabel.Position, bossLabel.Size = UDim2.new(0, 13, 1, -29), UDim2.new(1, -26, 0, 24)
    bossLabel.TextSize = short and 11 or 12
    local bottom, controlWidth = short and 12 or 20, width < 360 and 146 or 162
    local actionHeight, topHeight = short and 105 or 128, short and 56 or 70
    actions.Position, actions.Size = UDim2.new(1, -inset, 1, -bottom), UDim2.fromOffset(controlWidth, actionHeight)
    local half = (controlWidth - 8) / 2
    position(punch, 0, 0, half, topHeight)
    position(dash, half + 8, 0, half, topHeight)
    position(jump, 0, topHeight + 8, controlWidth, short and 41 or 50)
    punch.TextSize, dash.TextSize, jump.TextSize = short and 13 or 15, short and 13 or 15, short and 12 or 14
    local isTouch = UserInputService.TouchEnabled
    punch.Text, dash.Text = isTouch and "УДАР" or "УДАР\nF", isTouch and "ТАРАН" or "ТАРАН\nR"
    jump.Text = isTouch and "ПРЫЖОК" or "ПРЫЖОК · SPACE"
    local padSize = short and 104 or (width < 360 and 106 or 122)
    pad.Position, pad.Size = UDim2.new(0, inset + 2, 1, -bottom), UDim2.fromOffset(padSize, padSize)
    pad.Visible, keyboardHint.Visible = isTouch, not isTouch
    keyboardHint.Position, keyboardHint.Size = UDim2.new(0, inset, 1, -bottom), UDim2.fromOffset(190, 36)
    spectator.Position = UDim2.new(0.5, 0, 1, -20)
    spectator.Size = UDim2.fromOffset(math.min(500, width - inset * 2), 64)
    spectatorText.Position, spectatorText.Size = UDim2.fromOffset(15, 6), UDim2.new(1, -30, 1, -12)
end

local function dragTo(input)
    if not playable() then return end
    local center = pad.AbsolutePosition + pad.AbsoluteSize / 2
    local radius = math.max(1, pad.AbsoluteSize.X * 0.34)
    local delta = (Vector2.new(input.Position.X, input.Position.Y) - center) / radius
    if delta.Magnitude > 1 then delta = delta.Unit end
    touchVector = delta.Magnitude < 0.12 and Vector2.zero or delta
    knob.Position = UDim2.new(0.5, touchVector.X * radius, 0.5, touchVector.Y * radius)
end
pad.InputBegan:Connect(function(input)
    if not playable() or dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = input
        dragTo(input)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input == dragging or (dragging.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement)) then dragTo(input) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not playable() or UserInputService:GetFocusedTextBox() then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D then keys[key] = true
    elseif key == Enum.KeyCode.Space then send("Jump")
    elseif key == Enum.KeyCode.F then send("Attack", {attack = "Punch"})
    elseif key == Enum.KeyCode.R then send("Attack", {attack = "Dash"}) end
end)
UserInputService.InputEnded:Connect(function(input)
    keys[input.KeyCode] = nil
    if input == dragging then
        dragging, touchVector = nil, Vector2.zero
        knob.Position = UDim2.fromScale(0.5, 0.5)
    end
end)
UserInputService.WindowFocusReleased:Connect(function()
    resetInput()
    send("Move", {x = 0, z = 0})
end)

local cameraActor, cameraPoint = nil, nil
local function findCameraActor()
    local world = workspace:FindFirstChild("BrickToadsWorld") or workspace:FindFirstChild("CombatStandWorld")
    local actors = world and world:FindFirstChild("Actors")
    if not actors then return nil end
    local byId = {}
    for _, model in ipairs(actors:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
            local id = model:GetAttribute("ActorId")
            if id then byId[id] = model end
        end
    end
    if mine and mine.status == "Alive" and byId[mine.actorId] then return byId[mine.actorId] end
    for _, hero in ipairs(snapshot and snapshot.heroes or {}) do
        if hero.status == "Alive" and hero.connected and byId[hero.actorId] then return byId[hero.actorId] end
    end
    for _, hero in ipairs(snapshot and snapshot.heroes or {}) do
        if byId[hero.actorId] then return byId[hero.actorId] end
    end
    return nil
end
stateRemote.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    local wasPlayable = playable()
    local previousStatus = snapshot and snapshot.status
    snapshot, mine = data, nil
    for _, hero in ipairs(data.heroes or {}) do if hero.slot == data.mine then mine = hero; break end end
    local nextIdentity = mine and table.concat({tostring(data.runId), tostring(data.levelEpoch),
        tostring(mine.actorId), tostring(mine.attempt), tostring(mine.connectionEpoch)}, ":") or nil
    if nextIdentity ~= identity then identity, sequence = nextIdentity, 0; resetInput()
    elseif wasPlayable and not playable() then resetInput() end
    if pendingTemplate and (data.selectedTemplate == pendingTemplate or data.notice) then pendingTemplate = nil end
    if previousStatus ~= data.status then scroll.CanvasPosition = Vector2.zero end
    actionPending = false
    cameraActor = findCameraActor()
    render()
    layout()
end)
safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(layout)
-- Gameplay drives server-owned bodies instead of a default Roblox character.
task.spawn(function()
    local scripts = player:WaitForChild("PlayerScripts")
    local playerModule = scripts:WaitForChild("PlayerModule", 8)
    if playerModule then
        local ok, module = pcall(require, playerModule)
        if ok and module.GetControls then module:GetControls():Disable() end
    end
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
end)
local moveElapsed, syncElapsed, actorElapsed = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
    moveElapsed, syncElapsed, actorElapsed = moveElapsed + dt, syncElapsed + dt, actorElapsed + dt
    if syncElapsed >= 2 then
        syncElapsed = 0
        if not snapshot then intent:FireServer({kind = "Sync"}) end
        if pendingTemplate and os.clock() - pendingAt > 4 then
            pendingTemplate = nil
            intent:FireServer({kind = "Sync"})
            renderSelection()
        end
        if actionPending and os.clock() - actionAt > 4 then actionPending = false; render() end
    end
    if actorElapsed >= 0.2 then actorElapsed = 0; cameraActor = findCameraActor() end
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Scriptable
        local root = cameraActor and cameraActor.Parent and cameraActor:FindFirstChild("HumanoidRootPart")
        if root then
            local target = root.Position + Vector3.new(0, 2, 0)
            cameraPoint = cameraPoint and cameraPoint:Lerp(target, 1 - math.exp(-dt * 7)) or target
            camera.CFrame = CFrame.lookAt(cameraPoint + Vector3.new(0, 23, 30), cameraPoint)
        elseif not cameraPoint then
            camera.CFrame = CFrame.lookAt(Vector3.new(-55, 30, 36), Vector3.new(-45, 2, 0))
        end
    end
    if moveElapsed >= 0.1 then
        moveElapsed = 0
        if playable() then
            local function down(key) return keys[key] and 1 or 0 end
            local x = down(Enum.KeyCode.D) - down(Enum.KeyCode.A) + touchVector.X
            local z = down(Enum.KeyCode.S) - down(Enum.KeyCode.W) + touchVector.Y
            if UserInputService:GetFocusedTextBox() then x, z = 0, 0 end
            local forward = camera and Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z) or Vector3.new(0, 0, -1)
            forward = forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0, 0, -1)
            local direction = Vector3.new(-forward.Z, 0, forward.X) * x - forward * z
            if direction.Magnitude > 1 then direction = direction.Unit end
            send("Move", {x = direction.X, z = direction.Z})
        end
    end
end)
render()
layout()
intent:FireServer({kind = "Sync"})
