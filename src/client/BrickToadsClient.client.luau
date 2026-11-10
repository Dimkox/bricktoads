-- Presentation and input only. The server owns the run, actors and combat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local sharedText = ReplicatedStorage:WaitForChild("BrickToads")
local heroPortraitAssets = require(sharedText:WaitForChild("HeroPortraits"))
local localizationService = game:GetService("LocalizationService")
local localization = require(sharedText:WaitForChild("TextLocalization")).new(
    require(sharedText:WaitForChild("TextCatalog")), localizationService, Instance.new)
local function T(source, args) return localization:text(source, args) end
local function teamName(name, id) return localization:groupName(name, id) end
local remotes = ReplicatedStorage:WaitForChild("BrickToadsGame")
local intent = remotes:WaitForChild("Intent")
local stateRemote = remotes:WaitForChild("State")
local SpectatorCamera = require(script.Parent:WaitForChild("SpectatorCamera"))
local BossQueuePanel = require(script.Parent:WaitForChild("BossQueuePanel"))
local GroupPanel = require(script.Parent:WaitForChild("GroupPanel"))
local CombatFeedback = require(script.Parent:WaitForChild("CombatFeedback"))
local GameAudio = require(script.Parent:WaitForChild("GameAudio"))
local CastAssetVisibility = require(script.Parent:WaitForChild("CastAssetVisibility"))
local MovementInput = require(script.Parent:WaitForChild("MovementInput"))
local RobloxInputBindings = require(script.Parent:WaitForChild("RobloxInputBindings"))
local spectatorCamera = SpectatorCamera.new()
local combatFeedback = CombatFeedback.new()
local gameAudio = GameAudio.new()
local castAssetVisibility = CastAssetVisibility.new()
local soundMuted, musicMuted = false, false
local audioOpen = false
gameAudio:setReducedFlash(true)
script.Destroying:Connect(function() gameAudio:destroy(); castAssetVisibility:destroy() end)
local movementInput = MovementInput.new()
local gameplayBindings
local windowFocused = true
local lastReactionEpoch
local lastHeldContext
local vehicleRewindSerial
local sendMovement, syncGameplayContext
local feedbackUntil = 0
local feedbackActionId

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
local snapshot, mine, controlled, identity = nil, nil, nil, nil
local sequence = 0
local pendingTemplate, pendingAt = nil, 0
local pendingRole, pendingRoleAt = nil, 0
local pendingEnemy, pendingEnemyAt = nil, 0
local choosingEnemy = true
local pendingView, pendingViewAt = nil, 0
local cameraDragging, cameraStickInput = false, nil
local cameraHolds = {}
local actionPending, actionAt = false, 0
local width, height = 900, 650
local render, layout
local mobileExpanded

local function sendIntent(packet)
    local envelope = table.clone(packet)
    if snapshot then
        if type(snapshot.groupId) ~= "string" or snapshot.groupId == "" then return end
        envelope.groupId = snapshot.groupId
    elseif envelope.kind ~= "Sync" then return end
    intent:FireServer(envelope)
end

local function chooseView(view)
    if not snapshot or snapshot.status ~= "Active" or not snapshot.canChooseView or pendingView then return end
    if snapshot.view == view then return end
    pendingView, pendingViewAt = view, os.clock()
    sendIntent({kind = "ChooseView", runId = snapshot.runId, levelEpoch = snapshot.levelEpoch, view = view})
end

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
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
    if callback then item.Activated:Connect(callback) end
    return item
end
local function position(item, x, y, w, h)
    item.Position, item.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
end

local gui = make("ScreenGui", "BrickToadsGameUI", player:WaitForChild("PlayerGui"), {
    ResetOnSpawn = false, DisplayOrder = 20, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    ClipToDeviceSafeArea = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
localization:bind(gui)
localization:bindWorld(workspace)
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
local title = label(header, "Title", "Flooded Causeway", 35, C.text, true)
local intro = label(header, "Intro", "Guard weapons, grabs and a Guardian. Cross the causeway together.", 16, C.muted)
local resultBanner = frame(scroll, "Result", C.card)
resultBanner.LayoutOrder, resultBanner.Visible = 2, false
corner(resultBanner, 16)
local resultAccent = frame(resultBanner, "Accent", C.lime)
corner(resultAccent, 3)
local resultTitle = label(resultBanner, "ResultTitle", "CAUSEWAY CLEARED", 23, C.lime, true)
local resultDetail = label(resultBanner, "ResultDetail", "", 15, C.text)
local rolePicker = frame(scroll, "RolePreference", C.panel)
rolePicker.LayoutOrder = 3
corner(rolePicker, 16)
local roleTitle = label(rolePicker, "Heading", "YOUR ROLE", 13, C.lime, true)
local roleNote = label(rolePicker, "Help", "", 13, C.muted)
local roleButtons = {}
for i, choice in ipairs({{role = "Hero", text = "Hero"}, {role = "Enemy", text = "Enemy"}, {role = "Spectator", text = "Watch"}}) do
    local role = choice.role
    local item = button(rolePicker, role, choice.text, C.card, function()
        if not snapshot or snapshot.status == "Active" or snapshot.canSelect == false or pendingRole then return end
        if (snapshot.preference or "Hero") == role then return end
        pendingRole, pendingRoleAt = role, os.clock()
        sendIntent({kind = "SelectRole", role = role})
    end)
    roleButtons[i] = {button = item, role = role, text = choice.text, outline = stroke(item, C.line, 1)}
end
local selectionHeading = frame(scroll, "ChooseHero")
selectionHeading.LayoutOrder, selectionHeading.BackgroundTransparency = 4, 1
local chooseTitle = label(selectionHeading, "Heading", "CHOOSE YOUR HERO", 13, C.lime, true)
local chooseNote = label(selectionHeading, "EqualAbilities", "Equal abilities. Teammates may choose the same hero.", 14, C.muted)
local cardsContainer = frame(scroll, "HeroCards")
cardsContainer.LayoutOrder, cardsContainer.BackgroundTransparency = 5, 1
local heroCards = {}

-- Local portraits cover loading/failure; loaded thumbnails show the real model.
local function toadPortrait(parent, color, template)
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
    local assetId = heroPortraitAssets[template]
    if assetId then
        local portrait = Instance.new("ImageLabel")
        portrait.Name = "ModelPortrait"
        portrait.Size, portrait.BackgroundTransparency = UDim2.fromScale(1, 1), 1
        portrait.ScaleType, portrait.ZIndex = Enum.ScaleType.Fit, 2
        portrait.Visible = false
        portrait.Image = "rbxthumb://type=Asset&id=" .. assetId .. "&w=420&h=420"
        portrait.Parent = art
        local function loaded()
            if not portrait.Parent then return end
            for _, child in ipairs(art:GetChildren()) do
                if child:IsA("GuiObject") and child ~= portrait then child.Visible = false end
            end
            portrait.Visible = true
        end
        task.spawn(function()
            local fetched = false
            local ok = pcall(function()
                game:GetService("ContentProvider"):PreloadAsync({portrait.Image}, function(_, status)
                    fetched = status == Enum.AssetFetchStatus.Success
                end)
            end)
            -- Hidden or scrolled-out images can keep IsLoaded=false despite a
            -- successful fetch. Show the fetched image as a single replacement.
            if ok and fetched then loaded() end
        end)
    end
    return art
end
for i, template in ipairs(templates) do
    local card = button(cardsContainer, "Hero" .. i, "", C.card, function()
        if not snapshot or not snapshot.canSelect or (snapshot.preference or "Hero") ~= "Hero" or pendingTemplate then return end
        if snapshot.selectedTemplate == template then return end
        pendingTemplate, pendingAt = template, os.clock()
        sendIntent({kind = "SelectHero", template = template})
    end)
    card.ClipsDescendants = true
    heroCards[i] = {
        button = card, outline = stroke(card, C.line, 1),
        accent = frame(card, "Accent", heroColors[template]),
        art = toadPortrait(card, heroColors[template], template), template = template,
        name = label(card, "HeroName", template, 21, C.text, true),
        choice = label(card, "Selection", "SELECT", 12, C.muted, true),
        detail = label(card, "Detail", "Strike · rush · jump", 13, C.muted),
    }
end
local party = frame(scroll, "Party", C.panel)
party.LayoutOrder = 6
corner(party, 16)
local partyTitle = label(party, "PartyTitle", "PLAYERS", 13, C.muted, true)
local partyCount = label(party, "PartyCount", "", 13, C.lime, true)
partyCount.TextXAlignment = Enum.TextXAlignment.Right
local partyRows = {}
local function addPartyRow(i)
    local dot = frame(party, "PlayerColor" .. i, C.line)
    corner(dot, 4)
    local owner = label(party, "Owner" .. i, "", 15, C.text, true)
    owner.AutoLocalize = false
    owner.TextWrapped, owner.TextTruncate = false, Enum.TextTruncate.AtEnd
    local choice = label(party, "Template" .. i, "", 13, C.muted)
    choice.TextWrapped, choice.TextTruncate = false, Enum.TextTruncate.AtEnd
    partyRows[i] = {dot = dot, owner = owner, choice = choice}
end
for i = 1, 3 do addPartyRow(i) end
local partyNote = label(party, "PartyNote", "", 13, C.muted)
local audioSettings = frame(scroll, "AudioSettings")
audioSettings.BackgroundTransparency, audioSettings.LayoutOrder = 1, 8
local soundToggle = button(audioSettings, "SoundToggle", "Sound: On", C.card, function()
    soundMuted = not soundMuted; gameAudio:setMuted(soundMuted); render()
end)
local musicToggle = button(audioSettings, "MusicToggle", "Music: On", C.card, function()
    musicMuted = not musicMuted; gameAudio:setMusicMuted(musicMuted); render()
end)
-- The primary action stays visible while the hero choices scroll on phones.
local footer = frame(shell, "StartArea", C.ink)
footer.AnchorPoint, footer.Position = Vector2.new(0, 1), UDim2.fromScale(0, 1)
local startButton = button(footer, "Start", "Connecting…", C.line, function()
    if not snapshot or not snapshot.canStart or actionPending then return end
    actionPending, actionAt = true, os.clock()
    sendIntent({kind = "Start"})
end)
startButton.TextSize = 19
local returnToWatch = button(footer, "ReturnToObservation", "Return to watching", C.green, function()
    choosingEnemy = false
    chooseView("Spectating")
end)
returnToWatch.TextColor3, returnToWatch.Visible = C.ink, false
local waitLabel = label(footer, "HostWait", "Waiting for the game…", 14, C.muted)
waitLabel.TextXAlignment = Enum.TextXAlignment.Center
local menuNotice = label(footer, "Notice", "", 14, C.yellow)
menuNotice.TextXAlignment = Enum.TextXAlignment.Center

local hud = frame(safe, "HUD")
hud.BackgroundTransparency, hud.Size, hud.Visible = 1, UDim2.fromScale(1, 1), false
local bossQueue = BossQueuePanel.new(scroll, hud, sendIntent, C, T, teamName)
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
    owner.AutoLocalize = false
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
local enemyStatus = frame(hud, "EnemyStatus", C.ink)
enemyStatus.BackgroundTransparency, enemyStatus.Visible = 0.12, false
corner(enemyStatus, 12)
local enemyStripe = frame(enemyStatus, "EnemyColor", C.red)
corner(enemyStripe, 3)
local enemyOwner = label(enemyStatus, "Owner", "", 14, C.text, true)
enemyOwner.AutoLocalize = false
enemyOwner.TextWrapped, enemyOwner.TextTruncate = false, Enum.TextTruncate.AtEnd
local enemyLife = label(enemyStatus, "OneLife", "One life", 12, C.muted)
local enemyHearts = {}
for i = 1, 3 do
    local heart = label(enemyStatus, "Heart" .. i, "♥", 23, C.line)
    local clip = frame(heart, "FillClip")
    clip.BackgroundTransparency, clip.ClipsDescendants = 1, true
    clip.Size = UDim2.fromScale(1, 1)
    local fill = label(clip, "Fill", "♥", 23, C.red)
    fill.Size = UDim2.fromOffset(24, 27)
    enemyHearts[i] = {heart = heart, clip = clip, fill = fill}
end
local objective = frame(hud, "Objective", C.ink)
objective.BackgroundTransparency = 0.1
corner(objective, 14)
local stageLabel = label(objective, "Stage", "FLOODED CAUSEWAY", 12, C.lime, true)
local objectiveLabel = label(objective, "Task", "Reach the gate", 17, C.text, true)
local bossLabel = label(objective, "BossHits", "", 13, C.yellow)
local feedbackLabel = label(objective, "ConfirmedFeedback", "", 12, C.muted, true)
local function toggleMobileDetails(section)
    if UserInputService.TouchEnabled and bossQueue.card.Visible and bossQueue.compact then return end
    mobileExpanded = mobileExpanded ~= section and section or nil
    if render then render(); layout() end
end
local mobileStatus = button(hud, "MobileStatus", "", C.ink, function() toggleMobileDetails("Team") end)
mobileStatus.BackgroundTransparency, mobileStatus.Visible = 0.12, false
local mobileStatusTitle = label(mobileStatus, "Title", "", 14, C.text, true)
local mobileStatusDetail = label(mobileStatus, "State", "", 12, C.muted)
local mobileReturns = label(mobileStatus, "Respawns", "", 12, C.text, true)
mobileReturns.TextXAlignment = Enum.TextXAlignment.Right
local mobileStatusArrow = label(mobileStatus, "Expand", "+", 15, C.muted)
local mobileHearts = {}
for i = 1, 5 do
    local heart = label(mobileStatus, "Heart" .. i, "♥", 20, C.line)
    local clip = frame(heart, "FillClip")
    clip.BackgroundTransparency, clip.ClipsDescendants, clip.Size = 1, true, UDim2.fromScale(1, 1)
    local fill = label(clip, "Fill", "♥", 20, C.red)
    fill.Size = UDim2.fromOffset(18, 22)
    mobileHearts[i] = {heart = heart, clip = clip, fill = fill}
end
local mobileGoal = button(hud, "MobileGoal", "", C.ink, function() toggleMobileDetails("Goal") end)
mobileGoal.BackgroundTransparency, mobileGoal.Visible = 0.12, false
local mobileGoalTitle = label(mobileGoal, "Stage", "", 13, C.lime, true)
local mobileGoalDetail = label(mobileGoal, "Summary", "", 13, C.text)
local mobileGoalArrow = label(mobileGoal, "Expand", "+", 15, C.muted)
for _, item in ipairs({mobileStatusTitle, mobileStatusDetail, mobileGoalTitle, mobileGoalDetail}) do
    item.TextWrapped, item.TextTruncate = false, Enum.TextTruncate.AtEnd
end
local mobileDetails = frame(hud, "MobileDetails", C.ink)
mobileDetails.BackgroundTransparency, mobileDetails.Visible = 0.08, false
corner(mobileDetails, 14)
local mobileDetailsTitle = label(mobileDetails, "Heading", "Team", 14, C.text, true)
local mobileCollapse = button(mobileDetails, "Collapse", "COLLAPSE ↑", C.card, function() toggleMobileDetails(mobileExpanded) end)
mobileCollapse.TextSize = 12
local mobileDetailsScroll = make("ScrollingFrame", "Details", mobileDetails, {
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.muted, ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(), ClipsDescendants = true,
})
-- Audio controls: begin
local audioButton = button(hud, "AudioButton", "Audio", C.card, function()
    audioOpen = not audioOpen
    if audioOpen then mobileExpanded = nil end
    if render then render(); layout() end
end)
audioButton.TextSize, audioButton.ZIndex = 11, 20
local audioPopup = frame(hud, "AudioPopup", C.ink)
audioPopup.Visible, audioPopup.ZIndex = false, 30
corner(audioPopup, 12)
local audioTitle = label(audioPopup, "Heading", "Audio settings", 14, C.text, true)
local audioClose = button(audioPopup, "Close", "Close", C.card, function()
    audioOpen = false
    if render then render(); layout() end
end)
audioClose.TextSize = 10
local function syncAudioSettings(inGame)
    if not inGame then audioOpen = false end
    audioButton.Visible, audioPopup.Visible = inGame, inGame and audioOpen
    audioButton.Text, audioTitle.Text, audioClose.Text = T("Audio"), T("Audio settings"), T("Close")
    audioSettings.Parent = inGame and audioPopup or scroll
    audioSettings.Visible = not inGame or audioOpen
end
local function layoutAudioSettings(viewWidth,viewHeight,touch,hudBottom,inset,objectiveHeight,contentWidth)
    local edge = touch and (viewWidth < 500 and 8 or 12) or inset
    local buttonY = touch and edge or inset + objectiveHeight + 8
    position(audioButton, viewWidth-edge-44, buttonY, 44, 44)
    local popupWidth = math.min(286,viewWidth-edge*2)
    local popupY = math.min((touch and (hudBottom or edge+44) or buttonY+44)+8,viewHeight-edge-112)
    position(audioPopup,viewWidth-edge-popupWidth,math.max(edge,popupY),popupWidth,112)
    position(audioTitle,12,8,popupWidth-76,36)
    position(audioClose,popupWidth-52,4,44,44)
    if audioSettings.Parent == audioPopup then
        position(audioSettings,8,60,popupWidth-16,44)
        position(soundToggle,0,0,(popupWidth-24)/2,44)
        position(musicToggle,(popupWidth-24)/2+8,0,(popupWidth-24)/2,44)
    else
        audioSettings.Position, audioSettings.Size = UDim2.new(), UDim2.new(1,0,0,44)
        position(soundToggle,0,0,(contentWidth-10)/2,44)
        position(musicToggle,(contentWidth+10)/2,0,(contentWidth-10)/2,44)
    end
end
-- Audio controls: end
local spectator = frame(hud, "Spectator", C.ink)
spectator.BackgroundTransparency, spectator.AnchorPoint = 0.08, Vector2.new(0.5, 1)
corner(spectator, 14)
local spectatorText = label(spectator, "Message", "You are watching · this run's heroes are already locked in.", 14, C.text)
spectatorText.TextXAlignment = Enum.TextXAlignment.Center
local enemyChoiceTitle = label(spectator, "EnemyChoiceTitle", "CHOOSE AN ENEMY", 13, C.red, true)
local enemyChoiceNote = label(spectator, "EnemyChoiceNote", "", 12, C.muted)
local enemyOffers = make("ScrollingFrame", "EnemyOffers", spectator, {
    BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.muted, ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIListLayout", "OfferLayout", enemyOffers, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
make("UIPadding", "OfferPadding", enemyOffers, {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 3)})
local offerButtons = {}
local watchButton = button(spectator, "Watch", "Watch", C.card, function()
    choosingEnemy = false
    chooseView("Spectating")
    render()
    layout()
end)
local chooseEnemyButton = button(spectator, "ChooseEnemy", "Choose an enemy", C.card, function()
    choosingEnemy = true
    render()
    layout()
end)
local personalMenuButton = button(spectator, "PersonalMenu", "Menu", C.card, function()
    chooseView("Menu")
end)
local nextHeroButton = button(spectator, "NextHero", "Next hero", C.card, function()
    spectatorCamera:refreshTargets()
    spectatorCamera:nextHero()
    render()
    layout()
end)
local freeCameraButton = button(spectator, "FreeCamera", "Free camera", C.card, function()
    spectatorCamera:toggleFree(workspace.CurrentCamera)
    render()
    layout()
end)
local groupPanel = GroupPanel.new(scroll, spectator, safe, sendIntent, C, function()
    if render then render(); layout() end
end, T, teamName)
local controls = frame(hud, "Controls")
controls.BackgroundTransparency, controls.Size = 1, UDim2.fromScale(1, 1)
local function playable()
    return snapshot and snapshot.status == "Active" and controlled and controlled.status == "Alive"
        and controlled.connected == true and not controlled.dying and not snapshot.fault
        and (snapshot.view == nil or snapshot.view == "Playing") and not spectatorCamera:isFree()
end
local function send(kind, extra)
    if not playable() or not snapshot.runId or not controlled.actorId then return end
    if snapshot.enemyRole and kind == "Attack" and extra and extra.attack ~= "Punch" then return end
    if snapshot.enemyRole and snapshot.enemyRole.template == "Boss" and kind == "Jump" then return end
    if snapshot.interaction and snapshot.interaction.carrying and kind == "Attack" and extra and extra.attack == "Dash" then return end
    sequence += 1
    local packet = {kind = kind, runId = snapshot.runId, actorId = controlled.actorId,
        attempt = controlled.attempt, levelEpoch = snapshot.levelEpoch,
        connectionEpoch = controlled.connectionEpoch, seq = sequence}
    for key, value in pairs(extra or {}) do packet[key] = value end
    sendIntent(packet)
end
local actions = frame(controls, "Actions")
actions.BackgroundTransparency, actions.AnchorPoint = 1, Vector2.new(1, 1)
local punch = button(actions, "Punch", "ATTACK\nF", C.card)
local dash = button(actions, "Dash", "MEGA\nR · WHILE RUNNING", C.card)
local jump = button(actions, "Jump", "JUMP · SPACE", C.lime)
jump.TextColor3 = C.ink
stroke(punch, C.muted, 1)
stroke(dash, C.muted, 1)
local pad = frame(controls, "DirectionPad", C.ink)
pad.BackgroundTransparency, pad.AnchorPoint = 1, Vector2.new(0, 1)
local directionButtons = {}
for _, definition in ipairs({{"Forward", "↑"}, {"Left", "←"}, {"Backward", "↓"}, {"Right", "→"}}) do
    local item = button(pad, definition[1], definition[2], C.card)
    item.TextSize = 25
    stroke(item, C.muted, 1)
    directionButtons[definition[1]] = item
end
local runHint = label(pad, "RunHint", "2×\nRUN", 11, C.muted, true)
runHint.TextXAlignment = Enum.TextXAlignment.Center
local keyboardHint = label(controls, "KeyboardHint", "W A S D  ·  move", 13, C.text)
keyboardHint.AnchorPoint = Vector2.new(0, 1)
keyboardHint.BackgroundColor3, keyboardHint.BackgroundTransparency = C.ink, 0.15
corner(keyboardHint, 10)
keyboardHint.TextXAlignment = Enum.TextXAlignment.Center
local cameraControls = frame(hud, "CameraControls")
cameraControls.BackgroundTransparency, cameraControls.Size, cameraControls.Visible = 1, UDim2.fromScale(1, 1), false
local cameraPad = frame(cameraControls, "MoveStick", C.ink)
cameraPad.BackgroundTransparency, cameraPad.Active, cameraPad.AnchorPoint = 0.15, true, Vector2.new(0, 1)
corner(cameraPad, 100)
stroke(cameraPad, C.muted, 2)
local cameraKnob = frame(cameraPad, "Knob", C.lime)
cameraKnob.AnchorPoint, cameraKnob.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
cameraKnob.Size = UDim2.fromScale(0.34, 0.34)
corner(cameraKnob, 100)
local cameraAxes = frame(cameraControls, "HeightAndYaw")
cameraAxes.BackgroundTransparency, cameraAxes.AnchorPoint = 1, Vector2.new(1, 1)
local cameraButtons = {}
for _, definition in ipairs({{key = "Up", text = "UP"}, {key = "Down", text = "DOWN"},
    {key = "Left", text = "LEFT"}, {key = "Right", text = "RIGHT"}}) do
    local cameraKey = definition.key
    local item = button(cameraAxes, cameraKey, definition.text, C.card, function() end)
    item.InputBegan:Connect(function(input)
        if not spectatorCamera.enabled or not spectatorCamera:isFree() then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            cameraHolds[input] = cameraKey
            spectatorCamera:setKey(cameraKey, true)
        end
    end)
    cameraButtons[cameraKey] = item
end
local cameraHint = label(cameraControls, "KeyboardHint", "WASD · fly   Q/E · height   right mouse · turn", 13, C.text)
cameraHint.AnchorPoint, cameraHint.TextXAlignment = Vector2.new(0.5, 1), Enum.TextXAlignment.Center
cameraHint.BackgroundColor3, cameraHint.BackgroundTransparency = C.ink, 0.12
corner(cameraHint, 10)
local fault = frame(safe, "GameMessage", C.ink)
fault.AnchorPoint, fault.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
fault.Size, fault.Visible = UDim2.new(1, -36, 0, 92), false
corner(fault, 16)
make("UISizeConstraint", "MaxWidth", fault, {MaxSize = Vector2.new(540, 92)})
local faultText = label(fault, "Message", "Game paused. Waiting for recovery…", 17, C.text, true)
faultText.Position, faultText.Size = UDim2.fromOffset(18, 12), UDim2.new(1, -36, 1, -24)
faultText.TextXAlignment = Enum.TextXAlignment.Center

local function resetInput()
    if gameplayBindings then gameplayBindings:setEnabled(false) end
    movementInput:reset()
    for _, item in pairs(directionButtons) do item.BackgroundColor3 = C.card end
    spectatorCamera:resetInput()
    cameraDragging, cameraStickInput, cameraHolds = false, nil, {}
    cameraKnob.Position = UDim2.fromScale(0.5, 0.5)
end
sendMovement = function()
    local camera = workspace.CurrentCamera
    local forward = camera and camera.CFrame.LookVector
    local mode=snapshot and snapshot.level and snapshot.level.modeState
    local localAxes=false
    for _,actor in ipairs(mode and mode.actors or {}) do
        if actor.slot==snapshot.mine and not actor.finished and mode.mode~='Finale' then
            local vehicle=mode.mode=='Speeder' or mode.mode=='Surf' or mode.mode=='Jet'
            localAxes=not vehicle or actor.mounted==true
            break
        end
    end
    if snapshot and snapshot.enemyRole and snapshot.enemyRole.movementKind=='Swim' then localAxes=true end
    local value = movementInput:vector(forward and {x = forward.X, z = forward.Z},localAxes)
    if (snapshot and snapshot.interaction and snapshot.interaction.carrying) or (controlled and controlled.carryState) then
        value.run = false
    end
    if not gameplayBindings or not gameplayBindings.enabled then value = {x = 0, z = 0, run = false} end
    send("Move", value)
end
syncGameplayContext = function()
    if not gameplayBindings then return end
    local enabled = playable() == true and windowFocused and UserInputService:GetFocusedTextBox() == nil
    if enabled ~= gameplayBindings.enabled then
        movementInput:reset()
        for _, item in pairs(directionButtons) do item.BackgroundColor3 = C.card end
        gameplayBindings:setEnabled(enabled)
        if not enabled then sendMovement() end
    end
end
local localInputs = make("Folder", "BrickToadsInputs", player:WaitForChild("PlayerScripts"))
gameplayBindings = RobloxInputBindings.new(localInputs, {
    Forward = directionButtons.Forward, Backward = directionButtons.Backward,
    Left = directionButtons.Left, Right = directionButtons.Right, Jump = jump, Attack = punch, Mega = dash,
}, {
    press = function(direction)
        if movementInput:press(direction, os.clock()) then
            directionButtons[direction].BackgroundColor3 = C.line
            sendMovement()
        end
    end,
    release = function(direction)
        if movementInput:release(direction) then
            directionButtons[direction].BackgroundColor3 = C.card
            sendMovement()
        end
    end,
    action = function(action)
        sendMovement()
        if action == "Jump" then send("Jump")
        else send("Attack", {attack = action == "Mega" and "Dash" or "Punch"}) end
    end,
})
script.Destroying:Connect(function()
    gameplayBindings:destroy()
    localInputs:Destroy()
    localization:destroy()
end)
local function heroName(hero)
    return hero.displayName or hero.username or T("Player {index}", {index=hero.slot or ""})
end
local function hostName()
    for _, owner in ipairs(snapshot and snapshot.lobby or {}) do
        if owner.userId == snapshot.host then return owner.displayName or owner.username or T("host") end
    end
    return T("host")
end
local noticeMessages = {
    NOT_HOST = "The team host starts the game.", HOST_ONLY = "The team host starts the game.",
    BAD_TEMPLATE = "Choose one of the three heroes.", INVALID_TEMPLATE = "Choose one of the three heroes.",
    UNKNOWN_TEMPLATE = "Choose one of the three heroes.",
    RUN_ACTIVE = "Change your hero before the next game.",
    ACTIVE_RUN = "Change your hero before the next game.", ALREADY_ACTIVE = "The game has already started.",
    ROSTER_FULL = "The team is full. You can watch the game.", NO_PLAYERS = "Waiting for teammates.",
    START_FAILED = "Could not start the game. Try again.",
    BAD_ROLE = "Choose your role before the game starts.",
    HERO_LOCKED = "You are a hero in this run. Change roles before a new game.",
    ENEMY_LIFE_SPENT = "Your only life is over. Watch until the next game.",
    RUN_CLOSED = "Enemy selection is closed. Change roles before a new game.",
    NO_ENEMY_AVAILABLE = "No guards are available. Guards already in combat cannot be selected.",
    ENEMY_ENGAGED = "This guard is already in combat. Choose another from the list.",
    ENEMY_OCCUPIED = "Another player already controls this guard.",
    ENEMY_DEAD = "This guard has died. Choose another from the list.",
    UNKNOWN_ENEMY = "This guard is no longer available. Choose another from the list.",
    ENEMY_ALREADY_OWNED = "You already chose a guard. It has one life.",
    INELIGIBLE = "The Guardian queue is unavailable for your current role.",
    ROLE_ACTIVE = "You already control a living enemy.",
    ROLE_RESERVED = "You accepted a Guardian invitation. Cancel it in the queue first.",
    STALE_OFFER = "This invitation is no longer available. Refreshing the queue.",
    HELD = "A hero is holding you. Control returns after release.",
    THROWN = "You were thrown. Wait until you recover.",
    HANDS_FULL = "Your hands are full. Throw what you are holding first.",
    NOT_RUNNING = "Double-tap a direction and keep running to use a mega strike.",
}
local function enemyChoiceAllowed()
    local reason = snapshot and snapshot.enemyUnavailableReason
    local queue = snapshot and snapshot.bossQueue
    local reserved = queue and (queue.state == "Accepted" or queue.state == "Ready" or queue.state == "Active")
    return snapshot and snapshot.status == "Active" and not mine and not snapshot.enemyRole
        and not reserved and (reason == nil or reason == "NO_ENEMY_AVAILABLE")
end
local function renderOffers()
    local seen = {}
    for i, offer in ipairs(snapshot and snapshot.enemyOffers or {}) do
        local id, actorId = offer.enemyId, offer.actorId
        local key = tostring(id) .. ":" .. tostring(actorId)
        seen[key] = true
        local item = offerButtons[key]
        if not item then
            item = button(enemyOffers, "ClaimEnemy" .. tostring(id), "", C.card, function()
                if not enemyChoiceAllowed() or snapshot.enemyUnavailableReason or pendingEnemy then return end
                for _, current in ipairs(snapshot.enemyOffers or {}) do
                    if current.enemyId == id and current.actorId == actorId then
                        pendingEnemy, pendingEnemyAt = id, os.clock()
                        sendIntent({kind = "ClaimEnemy", runId = snapshot.runId,
                            levelEpoch = snapshot.levelEpoch, enemyId = id})
                        render()
                        return
                    end
                end
            end)
            item.TextSize = 14
            item.Size = UDim2.new(1, 0, 0, 44)
            offerButtons[key] = item
        end
        item.LayoutOrder = i
        local resource=offer.resourceKind=='CourseRival' and T('Rival') or
            (tostring(offer.hearts or 0)..'/'..tostring(offer.maxHearts or 3)..' ♥')
        item.Text = T(offer.name or "Guard") .. " · " .. resource .. " · " .. T(pendingEnemy == id and "Selecting…" or "Select")
        item.TextColor3 = pendingEnemy and C.muted or C.text
        item.Selectable = enemyChoiceAllowed() == true and not snapshot.enemyUnavailableReason and not pendingEnemy
    end
    for key, item in pairs(offerButtons) do
        if not seen[key] then item:Destroy(); offerButtons[key] = nil end
    end
end
local function renderSelection()
    local preference = snapshot and snapshot.preference or "Hero"
    local personalMenu = snapshot and snapshot.status == "Active" and snapshot.view == "Menu"
    local stopped = snapshot and snapshot.status == "Faulted"
    rolePicker.Visible = not personalMenu and not stopped
    selectionHeading.Visible, cardsContainer.Visible = not personalMenu and not stopped and preference == "Hero",
        not personalMenu and not stopped and preference == "Hero"
    roleNote.Text = preference == "Enemy" and "After the start, choose an available guard before its first fight. Three hearts, one life."
        or (preference == "Spectator" and "Watch the heroes. You may choose an available guard during the game."
            or "A team has 1–3 heroes. The first hero starts the game.")
    for _, choice in ipairs(roleButtons) do
        local selected = preference == choice.role
        choice.outline.Color = selected and C.lime or C.line
        choice.outline.Thickness, choice.outline.Transparency = selected and 2 or 1, selected and 0 or 0.55
        choice.button.BackgroundColor3 = selected and Color3.fromRGB(43, 63, 65) or C.card
        choice.button.TextColor3 = selected and C.lime or C.text
        choice.button.Text = (selected and "✓ " or "") .. T(choice.text) .. (pendingRole == choice.role and "…" or "")
        choice.button.Selectable = snapshot ~= nil and snapshot.status ~= "Active" and snapshot.canSelect ~= false and not pendingRole
    end
    for _, card in ipairs(heroCards) do
        local selected = snapshot and snapshot.selectedTemplate == card.template
        card.outline.Color = selected and heroColors[card.template] or C.line
        card.outline.Thickness, card.outline.Transparency = selected and 2 or 1, selected and 0 or 0.55
        card.button.BackgroundColor3 = selected and Color3.fromRGB(43, 63, 65) or C.card
        card.choice.TextColor3 = selected and heroColors[card.template] or C.muted
        card.choice.Text = selected and "✓ SELECTED" or "SELECT"
        if pendingTemplate == card.template then card.choice.Text = "SELECTING…" end
        if snapshot and not snapshot.canSelect and not selected then card.choice.Text = "SELECTION CLOSED" end
        card.button.Selectable = snapshot ~= nil and snapshot.canSelect == true
    end
end
local function remainingEnemies(level)
    return CombatFeedback.remainingEnemies(level)
end
local function visualHealth(personal,count)
    local raw=personal and tonumber(personal.hearts) or 0
    if personal and personal.bossType then return math.clamp(raw/math.max(1,personal.maxHearts or 1)*count,0,count) end
    return raw
end
local function campaignDetail(level)
    if level.bossType and level.boss then
        local boss=level.boss
        if boss.maxProgress then
            return T("Phase {phase:int} · progress {count:int}/{maximum:int}",
                {phase=boss.bossPhase or 1,count=boss.progress or 0,maximum=boss.maxProgress})
        end
        return T("Phase {phase:int} · Life {count:int}/{maximum:int}",
            {phase=boss.bossPhase or 1,count=boss.rawLife or 0,maximum=boss.maxRawLife or 1})
    end
    local mode=level.modeState
    for _,actor in ipairs(mode and mode.actors or {}) do
        if actor.slot==(snapshot and snapshot.mine) and actor.medium=='Water' and not actor.finished then
            return T("Air: {seconds:int} s",{seconds=math.max(0,math.ceil(actor.oxygen or 0))})
        end
    end
    if mode and mode.raceTime then return T("Bomb {count:int}/{maximum:int} · rival ~{seconds:int} s",
        {count=mode.bombIndex or 1,maximum=mode.bombCount or 3,seconds=math.ceil(mode.raceTime)}) end
    if mode and mode.room and level.mode=='Serpents' then return T("Vault {count:int}/4",{count=mode.room}) end
    return T("Enemies: {count:int}",{count=remainingEnemies(level)})
end
local function renderMobileSummary(level, enemy, isBoss)
    local personal = mine or enemy
    local rival=enemy and enemy.resourceKind=='CourseRival'
    local maximum = rival and 0 or (enemy and (enemy.bossType and 5 or tonumber(enemy.maxHearts) or 3) or 5)
    local hp = visualHealth(personal,maximum)
    mobileStatusTitle.Visible = personal == nil or rival==true
    mobileStatusTitle.Text = rival and T('Rival') or T("Heroes: {count:int}", {count=CombatFeedback.aliveHeroes(snapshot and snapshot.heroes)})
    mobileReturns.Visible = personal ~= nil
    mobileReturns.Text = rival and T('RACE') or enemy and T("1 life")
        or personal and personal.infiniteLives and T("∞ resp.") or T("{count:int} resp.", {count=personal and personal.respawns or 0})
    for n, heart in ipairs(mobileHearts) do
        heart.heart.Visible = personal ~= nil and n <= maximum
        heart.clip.Size = UDim2.fromScale(math.clamp(hp - n + 1, 0, 1), 1)
    end
    local state = "Team"
    if personal then
        if not personal.connected then state = "Disconnected"
        elseif personal.status == "Eliminated" or personal.status == "Dead" then state = "You are out"
        elseif personal.status ~= "Alive" or personal.dying then state = "Returning…"
        elseif personal.carryState then state = personal.carryState == "Carried" and "Held" or "Thrown"
        elseif personal.shield then state = "Protected"
        elseif personal.movementMode == "Run" then state = "Running · team"
        elseif enemy then state = "One life"
        else state = "In combat · team" end
    end
    mobileStatusDetail.Text = state
    mobileStatusArrow.Text = mobileExpanded == "Team" and "-" or "+"
    mobileGoalArrow.Text = mobileExpanded == "Goal" and "-" or "+"
    local shortZones = {"Gate", "Aqueduct", "Courtyard", "Ledges", "Forge", "Bridge"}
    if level.campaignIndex and level.campaignIndex>1 then
        mobileGoalTitle.Text=tostring(level.campaignIndex)..'/13 · '..T(level.levelName or level.mode)
    elseif level.stage == "Route" then
        mobileGoalTitle.Text = tostring(level.zoneIndex or 1) .. "/" .. tostring(level.zoneCount or 6)
            .. " · " .. T(shortZones[level.zoneIndex or 1] or level.zoneName or "Causeway")
    elseif level.stage == "Exit" then mobileGoalTitle.Text = "EXIT OPEN"
    else mobileGoalTitle.Text = isBoss and "CAUSEWAY GUARDIAN" or "FLOODED CAUSEWAY" end
    if enemy then mobileGoalDetail.Text = T("Heroes: {count:int}", {count=CombatFeedback.aliveHeroes(snapshot.heroes)})
    elseif level.campaignIndex and level.campaignIndex>1 then mobileGoalDetail.Text=campaignDetail(level)
    elseif level.stage == "BossReady" then mobileGoalDetail.Text = "Waiting for Guardian"
    elseif level.stage == "Exit" then mobileGoalDetail.Text = "Reach the exit"
    elseif isBoss then mobileGoalDetail.Text = T("Hits: {count:int}/{maximum:int}", {count=level.bossHits or 0,maximum=level.bossMax or 3})
    else mobileGoalDetail.Text = T("Enemies: {count:int}", {count=remainingEnemies(level)}) end
    mobileGoalDetail.TextColor3 = C.text
    if feedbackUntil > os.clock() and feedbackLabel.Text ~= "" then
        mobileGoalDetail.Text, mobileGoalDetail.TextColor3 = feedbackLabel.Text, feedbackLabel.TextColor3
    end
    mobileDetailsTitle.Text = mobileExpanded == "Goal" and "Objective" or "Team"
end
render = function()
    local active = snapshot and snapshot.status == "Active"
    local stopped = snapshot and snapshot.status == "Faulted"
    local completed = snapshot and (snapshot.status == "Won" or snapshot.status == "Lost")
    local personalMenu = active and snapshot.view == "Menu"
    local level = snapshot and snapshot.level or {}
    local modern = level.bossMechanic == "PickupThrow"
    overlay.Visible, hud.Visible, controls.Visible = not active or personalMenu == true, active == true and not personalMenu, playable() == true
    syncAudioSettings(active == true and not personalMenu)
    fault.Visible = snapshot ~= nil and snapshot.fault ~= nil and snapshot.fault ~= false and not stopped
    resultBanner.Visible = completed == true or stopped == true
    if stopped then
        resultTitle.Text, resultTitle.TextColor3 = "PARTY STOPPED", C.yellow
        resultAccent.BackgroundColor3 = C.yellow
        resultDetail.Text = "An error stopped this party. The host can start a new game manually."
        intro.Text, chooseTitle.Text = "A new party starts only when you press “Start again”.", "NEW PARTY"
    elseif completed then
        local won = snapshot.status == "Won"
        local enemyPerspective = snapshot.enemyRole ~= nil
        local success = (enemyPerspective and not won) or (not enemyPerspective and won)
        resultTitle.Text = enemyPerspective and (won and "HEROES CLEARED THE CAUSEWAY" or "HEROES STOPPED")
            or (won and "CAUSEWAY CLEARED!" or "TEAM ELIMINATED")
        resultTitle.TextColor3, resultAccent.BackgroundColor3 = success and C.lime or C.red, success and C.lime or C.red
        if enemyPerspective then
            resultDetail.Text = modern and (won and "The heroes crossed six districts, defeated the Guardian and opened the exit."
                or "The heroes were stopped on the causeway. The next attempt starts in the first district.")
                or (won and "The heroes defeated the Guardian and opened the gate. Choose a role for the next game."
                    or "The heroes used all their respawns. The causeway is still guarded.")
        else
            resultDetail.Text = modern and (won and "Six districts cleared. The Guardian fell to heavy balls — the exit is open."
                or "The team did not reach the exit. The districts and Guardian await another attempt.")
                or (won and "The Guardian is defeated. The gate is open — the team reached the exit."
                    or "The heroes have no respawns left. Choose roles and try the causeway again.")
        end
        intro.Text, chooseTitle.Text = "Press “New game” to start the next attempt.", "HERO FOR THE NEXT GAME"
    elseif personalMenu then
        intro.Text = snapshot.enemyRole and snapshot.enemyRole.status == "Dead"
            and (snapshot.enemyRole.template == "Boss" and "The Guardian is defeated. You can keep watching this game."
                or "Your only life is over. You can keep watching this game.")
            or "You can return to watching this same game."
    else
        intro.Text, chooseTitle.Text = "Guard weapons, grabs and a Guardian. Cross the causeway together.", "CHOOSE YOUR HERO"
    end
    title.Text = stopped and "Party stopped" or (personalMenu and "The team is still playing" or "Flooded Causeway")
    renderSelection()
    bossQueue:update(snapshot, mine)
    groupPanel:update(snapshot, mine)
    local owners = snapshot and snapshot.lobby or {}
    local heroOnline = 0
    for _, owner in ipairs(owners) do if (owner.preference or "Hero") == "Hero" then heroOnline += 1 end end
    heroOnline = snapshot and snapshot.heroOnline or heroOnline
    partyCount.Text = snapshot and T("{count:int} / 3 heroes", {count=math.min(heroOnline, 3)}) or ""
    for i = #partyRows + 1, #owners do addPartyRow(i) end
    for i, row in ipairs(partyRows) do
        local owner = owners[i]
        row.dot.Visible, row.owner.Visible, row.choice.Visible = owner ~= nil, owner ~= nil, owner ~= nil
        if owner then
            local preference = owner.preference or "Hero"
            row.dot.BackgroundColor3 = preference == "Enemy" and C.red
                or (preference == "Spectator" and C.muted or heroColors[owner.template] or C.green)
            row.owner.Text = (owner.displayName or owner.username or T("Player")) .. (owner.userId == player.UserId and T(" · you") or "")
            row.choice.Text = preference == "Enemy" and "Enemy · choose after start"
                or (preference == "Spectator" and "Spectator" or (owner.template or "Mr. Green"))
        end
    end
    partyNote.Text = snapshot and (heroOnline == 0 and "At least one hero is needed to start the game."
        or "Heroes are locked in at the start. Enemies choose a guard during the game.") or "Connecting to the game…"
    if personalMenu then partyNote.Text = "The team is still playing. Returning to watch does not grant another life." end
    if stopped then partyNote.Text = "The previous party has ended. Only the host starts a new game." end
    startButton.Visible = not personalMenu and (not snapshot or snapshot.canStart == true)
    returnToWatch.Visible = personalMenu == true and snapshot.canChooseView == true
    returnToWatch.Text = pendingView == "Spectating" and "Returning…" or "Return to watching"
    returnToWatch.Selectable = pendingView == nil
    startButton.BackgroundColor3, startButton.TextColor3 = snapshot and snapshot.canStart and C.lime or C.line,
        snapshot and snapshot.canStart and C.ink or C.text
    startButton.Text = actionPending and "Starting…" or (stopped and "Start again" or (completed and "New game" or "Start game"))
    if not snapshot then startButton.Text = "Connecting…" end
    waitLabel.Text = not snapshot and "Waiting for the game…" or (snapshot.canStart
        and "Play solo or with two or three heroes." or (snapshot.host == nil
            and "Choose the hero role to start the game." or T("Waiting for {host} to start the game.", {host=hostName()})))
    if personalMenu then waitLabel.Text = "You will return to the same game." end
    if stopped then
        waitLabel.Text = snapshot.canStart and "Start a new party when you are ready."
            or T("Waiting for {host} to start a new party.", {host=hostName()})
    end
    menuNotice.Text = snapshot and (noticeMessages[snapshot.notice] or "") or ""
    soundToggle.Text = T(soundMuted and "Sound: Off" or "Sound: On")
    musicToggle.Text = T(musicMuted and "Music: Off" or "Music: On")
    for i, row in ipairs(heroRows) do
        local hero = snapshot and snapshot.heroes and snapshot.heroes[i]
        row.row.Visible = hero ~= nil
        if hero then
            row.owner.Text = heroName(hero) .. (hero.slot == snapshot.mine and T(" · you") or "")
            row.owner.TextColor3 = hero.slot == snapshot.mine and C.lime or C.text
            row.stripe.BackgroundColor3 = heroColors[hero.template] or C.green
            row.returns.Text = "↻ " .. (hero.infiniteLives and "∞" or tostring(hero.respawns or 0))
            local detail = T(hero.template or "Mr. Green")
            if not hero.connected then detail = T("Disconnected")
            elseif hero.status == "Eliminated" then detail = T("Out")
            elseif hero.status ~= "Alive" or hero.dying then detail = T("Returning…")
            elseif hero.shield then detail ..= T(" · protected") end
            if hero.slot==snapshot.mine and snapshot.weapon then detail ..= T(" · club") end
            if hero.infiniteLives then detail ..= T(" · God Mode") end
            row.status.Text = detail
            local hp = tonumber(hero.hearts) or 0
            for n, heart in ipairs(row.fills) do heart.clip.Size = UDim2.fromScale(math.clamp(hp - n + 1, 0, 1), 1) end
        end
    end
    local enemy = snapshot and snapshot.enemyRole
    local controlledBoss = enemy and enemy.template == "Boss"
    roster.Visible, enemyStatus.Visible = enemy == nil, enemy ~= nil
    if enemy then
        enemyOwner.Text = controlledBoss and (T(enemy.name or "Causeway Guardian") .. T(" · you")) or (player.DisplayName .. T(" · enemy"))
        enemyLife.Text = enemy.resourceKind=='CourseRival' and T('Rival · move and jump') or enemy.bossType and (enemy.status=='Dead' and 'Boss defeated' or
            T("Phase {phase:int} · Life {count:int}/{maximum:int}",
                {phase=enemy.bossPhase or 1,count=enemy.rawLife or 0,maximum=enemy.maxHearts or 1}))
            or controlledBoss and (enemy.status == "Dead" and "Guardian defeated"
            or (enemy.connected and (tostring(enemy.hearts or 0) .. " / " .. tostring(enemy.maxHearts or 3) .. " ♥") or "Guardian · disconnected"))
            or (enemy.status == "Dead" and "One life · out" or (enemy.connected and "One life" or "One life · disconnected"))
        enemyLife.TextColor3 = enemy.status == "Dead" and C.red or C.muted
        if enemy.status == "Alive" and enemy.carryState then
            enemyLife.Text = enemy.carryState == "Carried" and "You are held · wait for release" or "Thrown · recovering control"
        end
        for n, heart in ipairs(enemyHearts) do
            heart.heart.Visible=enemy.resourceKind~='CourseRival'
            heart.clip.Size = UDim2.fromScale(math.clamp(visualHealth(enemy,3) - n + 1, 0, 1), 1)
        end
    end
    local interaction = snapshot and snapshot.interaction
    local carrying = interaction and interaction.carrying == true
    local interactionLabel = not enemy and interaction and interaction.available == true and interaction.label
    local course=snapshot and snapshot.level and snapshot.level.modeState
    local courseRide
    if not enemy and controlled and course then
        for _,actor in ipairs(course.actors or {}) do
            if actor.slot==snapshot.mine and actor.actorId==controlled.actorId and not actor.finished then
                if actor.mounted and (course.mode=='Speeder' or course.mode=='Surf' or course.mode=='Jet')
                    or course.mode=='Clinger' then courseRide=course.mode end
                break
            end
        end
    end
    dash.Visible = not UserInputService.TouchEnabled and enemy == nil and not carrying and not courseRide
    jump.Visible = courseRide~='Clinger' and not controlledBoss
        and not (enemy and (enemy.movementKind=='Swim' or enemy.movementKind=='Ride' or enemy.movementKind=='Wall'))
    punch.Visible=not courseRide and not (enemy and enemy.resourceKind=='CourseRival')
    runHint.Visible=not courseRide
    keyboardHint.Text = courseRide and CombatFeedback.hint(snapshot,T)
        or enemy and enemy.resourceKind=='CourseRival' and T('MOVE · JUMP: race to the bomb')
        or enemy and enemy.movementKind=='Ride' and T('SCRIPTED FLIGHT · ATTACK: drop one obstacle')
        or enemy and enemy.movementKind=='Wall' and T('AIM · ATTACK: defend the wall')
        or controlledBoss and (enemy.bossType and 'W A S D · aim · F · attack' or "W A S D · aim · F · fire")
        or (carrying and interactionLabel and ("F · " .. T(interactionLabel)))
        or (not carrying and controlled and controlled.movementMode == "Run" and "RUNNING · F · MEGA")
        or (interactionLabel and ("F · " .. T(interactionLabel)))
        or "WASD · walk · double-tap direction · run · F · attack"
    local isBoss = string.find(string.lower(tostring(level.stage or "")), "boss", 1, true) ~= nil
    stageLabel.Text = isBoss and "CAUSEWAY GUARDIAN" or "FLOODED CAUSEWAY"
    if level.campaignIndex and level.campaignIndex>1 then
        stageLabel.Text=tostring(level.campaignIndex)..'/13 · '..T(level.levelName or level.mode)
    elseif modern and level.stage == "Route" then
        stageLabel.Text = tostring(level.zoneIndex or 1) .. "/" .. tostring(level.zoneCount or 6) .. " · " .. T(level.zoneName or "Flooded Causeway")
    elseif modern and level.stage == "Exit" then stageLabel.Text = "EXIT OPEN" end
    objectiveLabel.Text = enemy and "Stop the heroes" or (level.objective or "Cross the causeway and reach the gate.")
    if modern and isBoss and not enemy then
        objectiveLabel.Text = "Dodge. Pick up a heavy ball and throw it at the Guardian."
    end
    local hits = tonumber(level.bossHits) or 0
    if enemy then
        local aliveHeroes = CombatFeedback.aliveHeroes(snapshot.heroes)
        bossLabel.Text = T("Heroes in combat: {count:int}", {count=aliveHeroes})
    elseif level.campaignIndex and level.campaignIndex>1 then bossLabel.Text=campaignDetail(level)
    elseif modern and (isBoss or level.stage == "Exit" or hits > 0) then
        bossLabel.Text = T("Ball hits: {count:int} / {maximum:int}", {count=hits,maximum=level.bossMax or 3})
    elseif modern then
        bossLabel.Text = T("Enemies in district: {count:int}", {count=remainingEnemies(level)})
    elseif isBoss or hits > 0 then
        bossLabel.Text = T("Shots reflected: {count:int} / {maximum:int}", {count=hits,maximum=level.bossMax or 3})
    else
        local alive = remainingEnemies(level)
        bossLabel.Text = alive > 0 and T("Enemies ahead: {count:int}", {count=alive}) or "Strike the Guardian's projectile to reflect it."
    end
    spectator.Visible = active == true and not personalMenu and not playable()
    local canChoose = enemyChoiceAllowed()
    local choice = active and snapshot.view == "Choice"
    local expanded = canChoose and choosingEnemy and not choice and not personalMenu
    local enemyDead = enemy and enemy.status == "Dead"
    local canObserve = active and snapshot.canChooseView == true and snapshot.view == "Spectating" and not expanded and not groupPanel:isOpen()
    spectatorCamera:setEnabled(canObserve == true)
    if not canObserve then
        cameraDragging, cameraStickInput, cameraHolds = false, nil, {}
        cameraKnob.Position = UDim2.fromScale(0.5, 0.5)
    end
    cameraControls.Visible = canObserve == true and spectatorCamera:isFree()
    nextHeroButton.Visible, freeCameraButton.Visible = canObserve == true, canObserve == true
    freeCameraButton.Text = spectatorCamera:isFree() and "Follow hero" or "Free camera"
    freeCameraButton.BackgroundColor3 = spectatorCamera:isFree() and C.lime or C.card
    freeCameraButton.TextColor3 = spectatorCamera:isFree() and C.ink or C.text
    personalMenuButton.Visible = active == true and not personalMenu and snapshot.canChooseView == true
    personalMenuButton.Text = pendingView == "Menu" and "Opening…" or "Menu"
    personalMenuButton.Selectable = pendingView == nil
    enemyChoiceTitle.Visible, enemyChoiceNote.Visible, enemyOffers.Visible = expanded == true, expanded == true, expanded == true
    watchButton.Visible = expanded == true or choice == true
    watchButton.Text = pendingView == "Spectating" and "Opening…" or "Watch"
    watchButton.Selectable = pendingView == nil
    chooseEnemyButton.Visible = canChoose == true and not choosingEnemy and not choice and not personalMenu
    if enemyDead then
        spectatorText.Text = snapshot.view == "Spectating" and "You are watching. Choose a new role before the next game."
            or (controlledBoss and "The Guardian is defeated. You can watch the ongoing game." or noticeMessages.ENEMY_LIFE_SPENT)
    elseif choice then
        spectatorText.Text = "You are out. The team is still playing — watch or open the menu?"
    elseif mine then
        spectatorText.Text = mine.status ~= "Eliminated" and mine.connected and "Hero returning…"
            or (snapshot.view == "Spectating" and "You are watching the ongoing game."
                or (noticeMessages[snapshot.enemyUnavailableReason] or noticeMessages.HERO_LOCKED))
    elseif enemy then
        spectatorText.Text = controlledBoss and "Restoring the Guardian connection…" or "Restoring the guard connection…"
    elseif expanded then
        spectatorText.Text = "Three hearts · one life · no respawns"
    else
        spectatorText.Text = noticeMessages[snapshot and snapshot.enemyUnavailableReason] or "You are watching the game."
    end
    enemyChoiceNote.Text = snapshot and (noticeMessages[snapshot.notice] or noticeMessages[snapshot.enemyUnavailableReason])
        or "You control this guard until its life ends."
    renderMobileSummary(level, enemy, isBoss)
    renderOffers()
end

layout = function()
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
    rolePicker.Size = UDim2.new(1, 0, 0, shortLandscape and 104 or (compact and 132 or 116))
    position(roleTitle, 14, shortLandscape and 6 or 9, contentWidth - 28, 18)
    local roleWidth = (contentWidth - 40) / 3
    for i, choice in ipairs(roleButtons) do
        position(choice.button, 14 + (i - 1) * (roleWidth + 6), shortLandscape and 28 or 34,
            roleWidth, shortLandscape and 34 or 40)
        choice.button.TextSize = width < 360 and 11 or (compact and 13 or 14)
    end
    position(roleNote, 14, shortLandscape and 67 or 80, contentWidth - 28, shortLandscape and 30 or (compact and 44 or 28))
    roleNote.TextSize = shortLandscape and 12 or 13
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
    local owners = snapshot and #(snapshot.lobby or {}) or 1
    local rowHeight, noteHeight = compact and 42 or 35, compact and 52 or 38
    party.Size = UDim2.new(1, 0, 0, 48 + math.max(owners, 1) * rowHeight + noteHeight)
    position(partyTitle, 16, 12, contentWidth - 156, 20)
    partyTitle.TextSize = width < 350 and 11 or 13
    position(partyCount, contentWidth - 136, 12, 120, 20)
    for i, row in ipairs(partyRows) do
        local y = 42 + (i - 1) * rowHeight
        position(row.dot, 16, y + 7, 8, 8)
        if compact then
            position(row.owner, 34, y, contentWidth - 50, 20)
            position(row.choice, 34, y + 20, contentWidth - 50, 17)
        else
            position(row.owner, 34, y, contentWidth - 260, 24)
            position(row.choice, contentWidth - 222, y, 206, 24)
        end
        row.choice.TextXAlignment = compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    end
    position(partyNote, 16, 43 + math.max(owners, 1) * rowHeight, contentWidth - 32, noteHeight)
    footer.Size = UDim2.new(1, 0, 0, 108)
    position(startButton, 3, 0, contentWidth, 52)
    position(returnToWatch, 3, 0, contentWidth, 52)
    position(waitLabel, 3, 56, contentWidth, 31)
    position(menuNotice, 3, 88, contentWidth, 20)
    if snapshot and snapshot.canStart == false and not returnToWatch.Visible then position(waitLabel, 3, 8, contentWidth, 47) end
    if shortLandscape then
        footer.Size = UDim2.new(1, 0, 0, 84)
        position(startButton, 3, 0, contentWidth, 44)
        position(returnToWatch, 3, 0, contentWidth, 44)
        position(waitLabel, 3, 46, contentWidth, 20)
        position(menuNotice, 3, 68, contentWidth, 16)
        waitLabel.TextSize, menuNotice.TextSize = 12, 12
        if snapshot and snapshot.canStart == false and not returnToWatch.Visible then position(waitLabel, 3, 8, contentWidth, 38) end
    else waitLabel.TextSize, menuNotice.TextSize = 14, 14 end

    local inset, short = width < 500 and 12 or 18, height < 480
    local isTouch = UserInputService.TouchEnabled
    local mobileHudBottom
    stageLabel.Visible = not isTouch
    objectiveLabel.TextYAlignment = isTouch and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    -- An actionable compact queue owns this space until its invitation/context ends.
    local queuePriority = isTouch and bossQueue.card.Visible and bossQueue.compact
    if queuePriority then mobileExpanded = nil end
    roster.Parent = isTouch and mobileDetailsScroll or hud
    enemyStatus.Parent = isTouch and mobileDetailsScroll or hud
    objective.Parent = isTouch and mobileDetailsScroll or hud
    mobileStatus.Visible, mobileGoal.Visible = isTouch, isTouch
    mobileDetails.Visible = isTouch and mobileExpanded ~= nil
    mobileStatusArrow.Visible, mobileGoalArrow.Visible = not queuePriority, not queuePriority
    if queuePriority then mobileGoalDetail.Text = "Guardian queue · below" end
    local rosterWidth = portrait and (width - inset * 2) or math.min(292, width * 0.43)
    local rowHeightHUD, gap = short and 45 or 62, short and 5 or 7
    local count = snapshot and math.min(#(snapshot.heroes or {}), 3) or 1
    local enemy = snapshot and snapshot.enemyRole
    local controlledBoss = enemy and enemy.template == "Boss"
    local interaction = snapshot and snapshot.interaction
    local carrying = interaction and interaction.carrying == true
    local enemyStatusHeight = short and 57 or 72
    local rosterHeight = enemy and (enemyStatusHeight + gap) or count * (rowHeightHUD + gap)
    if not enemy and enemyChoiceAllowed() and choosingEnemy and height < 620 then
        roster.Visible, rosterHeight = false, 0
    elseif not enemy then roster.Visible = true end
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
    position(enemyStatus, inset, inset, rosterWidth, enemyStatusHeight)
    position(enemyStripe, 0, 9, 3, enemyStatusHeight - 18)
    position(enemyOwner, 11, short and 3 or 6, rosterWidth - 22, 20)
    enemyOwner.TextSize = short and 12 or 14
    position(enemyLife, 94, short and 28 or 35, rosterWidth - 106, 22)
    enemyLife.TextSize = short and 11 or 12
    for n, heart in ipairs(enemyHearts) do
        position(heart.heart, 10 + (n - 1) * 25, short and 26 or 32, 24, 27)
        heart.heart.TextSize, heart.fill.TextSize = short and 21 or 23, short and 21 or 23
    end
    objective.Visible = true
    if portrait then
        position(objective, inset, inset + rosterHeight + 2, width - inset * 2, 120)
    else
        local objectiveWidth = math.min(420, width - rosterWidth - inset * 3)
        position(objective, width - inset - objectiveWidth, inset, objectiveWidth, short and 112 or 126)
    end
    stageLabel.Position, stageLabel.Size = UDim2.fromOffset(13, 9), UDim2.new(1, -26, 0, 17)
    objectiveLabel.Position, objectiveLabel.Size = UDim2.fromOffset(13, 29), UDim2.new(1, -26, 0, short and 33 or 40)
    objectiveLabel.TextSize = short and 14 or 16
    bossLabel.Position, bossLabel.Size = UDim2.new(0, 13, 1, -49), UDim2.new(1, -26, 0, 24)
    bossLabel.TextSize = short and 11 or 12
    feedbackLabel.Position, feedbackLabel.Size = UDim2.new(0, 13, 1, -26), UDim2.new(1, -26, 0, 20)
    feedbackLabel.TextSize = short and 11 or 12
    local bottom, controlWidth = short and 12 or 20, width < 360 and 146 or 162
    local actionHeight, topHeight = short and (isTouch and 108 or 105) or 128, short and 56 or 70
    actions.Position, actions.Size = UDim2.new(1, -inset, 1, -bottom), UDim2.fromOffset(controlWidth, controlledBoss and topHeight or actionHeight)
    local half = (controlWidth - 8) / 2
    position(punch, 0, 0, (isTouch or enemy or carrying) and controlWidth or half, topHeight)
    position(dash, half + 8, 0, half, topHeight)
    position(jump, 0, topHeight + 8, controlWidth, short and (isTouch and 44 or 41) or 50)
    punch.TextSize, dash.TextSize, jump.TextSize = short and 13 or 15, short and 13 or 15, short and 12 or 14
    local primaryLabel = controlledBoss and not enemy.bossType and "FIRE" or "ATTACK"
    if enemy and enemy.movementKind=='Ride' then primaryLabel='DROP OBSTACLE' end
    if not carrying and not controlledBoss and controlled and controlled.movementMode == "Run" then
        primaryLabel = "MEGA STRIKE"
    elseif not enemy and interaction and interaction.available == true and type(interaction.label) == "string" then
        primaryLabel = interaction.label
    end
    punch.Text = isTouch and T(primaryLabel) or (T(primaryLabel) .. "\nF")
    dash.Text = "MEGA\nR · WHILE RUNNING"
    local flyer=snapshot and snapshot.enemyRole and snapshot.enemyRole.movementKind=='Fly'
    jump.Text = flyer and (isTouch and T('FLAP') or T('FLAP · SPACE')) or (isTouch and "JUMP" or "JUMP · SPACE")
    local padSize = short and 144 or (width < 360 and 146 or 164)
    pad.Position, pad.Size = UDim2.new(0, inset + 2, 1, -bottom), UDim2.fromOffset(padSize, padSize)
    pad.Visible, keyboardHint.Visible = isTouch, not isTouch
    local cell = (padSize - 8) / 3
    position(directionButtons.Forward, cell + 4, 0, cell, cell)
    position(directionButtons.Left, 0, cell + 4, cell, cell)
    position(directionButtons.Right, (cell + 4) * 2, cell + 4, cell, cell)
    position(directionButtons.Backward, cell + 4, (cell + 4) * 2, cell, cell)
    position(runHint, cell + 4, cell + 4, cell, cell)
    keyboardHint.Position, keyboardHint.Size = UDim2.new(0, inset, 1, -bottom), UDim2.fromOffset(260, 42)
    if isTouch then
        local mobileInset, cardGap = width < 500 and 8 or 12, 8
        local statusWidth, goalWidth = math.min(172, width - mobileInset * 2), math.min(260, width - mobileInset * 2)
        local twoRows = statusWidth + goalWidth + cardGap + 52 > width - mobileInset * 2
        local goalY = mobileInset + (twoRows and 52 or 0)
        position(mobileStatus, mobileInset, mobileInset, statusWidth, 44)
        position(mobileGoal, width - mobileInset - goalWidth - (twoRows and 0 or 52), goalY, goalWidth, 44)
        mobileHudBottom = goalY + 44
        position(mobileStatusTitle, 8, 1, statusWidth - 32, 21)
        position(mobileStatusDetail, 8, 23, statusWidth - 32, 17)
        position(mobileReturns, statusWidth - 78, 2, 54, 20)
        position(mobileStatusArrow, statusWidth - 22, 23, 15, 17)
        for n, heart in ipairs(mobileHearts) do position(heart.heart, 8 + (n - 1) * 18, 0, 18, 22) end
        position(mobileGoalTitle, 10, 2, goalWidth - 34, 18)
        position(mobileGoalDetail, 10, 22, goalWidth - 34, 18)
        position(mobileGoalArrow, goalWidth - 23, 12, 15, 20)
        local detailsWidth = math.min(344, width - mobileInset * 2)
        local detailsY = mobileHudBottom + 8
        local controlsTop = height - bottom - math.max(padSize, controlledBoss and topHeight or actionHeight)
        local desiredHeight = mobileExpanded == "Goal" and 252 or (60 + count * 64 + (enemy and 72 or 0))
        local availableHeight = controlsTop - detailsY - 8
        local detailsHeight = math.max(52, math.min(desiredHeight, availableHeight))
        local detailsX = mobileExpanded == "Goal" and (width - mobileInset - detailsWidth) or mobileInset
        if availableHeight < 112 then
            -- An explicitly opened panel may use the centre, leaving both control corners free.
            local middleLeft = inset + 2 + padSize + 8
            local middleRight = width - inset - controlWidth - 8
            local middleWidth = middleRight - middleLeft
            if middleWidth >= 144 then
                detailsWidth = math.min(344, middleWidth)
                detailsX = middleLeft + (middleWidth - detailsWidth) / 2
                detailsHeight = math.min(desiredHeight, height - bottom - detailsY)
            end
        end
        position(mobileDetails, detailsX, detailsY, detailsWidth, detailsHeight)
        position(mobileDetailsTitle, 12, 0, detailsWidth - 144, 44)
        position(mobileCollapse, detailsWidth - 130, 0, 122, 44)
        position(mobileDetailsScroll, 8, 44, detailsWidth - 16, detailsHeight - 52)
        local innerWidth, teamTop = detailsWidth - 16, enemy and 72 or 0
        roster.Visible, enemyStatus.Visible, objective.Visible = mobileExpanded == "Team",
            mobileExpanded == "Team" and enemy ~= nil, mobileExpanded == "Goal"
        position(enemyStatus, 0, 0, innerWidth, 64)
        position(enemyStripe, 0, 9, 3, 46)
        position(enemyOwner, 11, 3, innerWidth - 22, 20)
        enemyOwner.TextSize, enemyLife.TextSize = 14, 12
        position(enemyLife, 94, 30, innerWidth - 106, 24)
        for n, heart in ipairs(enemyHearts) do position(heart.heart, 10 + (n - 1) * 25, 29, 24, 27) end
        position(roster, 0, teamTop, innerWidth, count * 64)
        for i, row in ipairs(heroRows) do
            position(row.row, 0, (i - 1) * 64, innerWidth, 58)
            position(row.stripe, 0, 9, 3, 40)
            position(row.owner, 11, 3, innerWidth - 63, 20)
            row.owner.TextSize = 14
            position(row.status, 126, 32, innerWidth - 137, 18)
            position(row.returns, innerWidth - 45, 4, 34, 18)
            for n, heart in ipairs(row.fills) do position(heart.heart, 10 + (n - 1) * 22, 28, 22, 25) end
        end
        position(objective, 0, 0, innerWidth, 168)
        position(stageLabel, 12, 8, innerWidth - 24, 18)
        position(objectiveLabel, 12, 0, innerWidth - 24, 72)
        objectiveLabel.TextSize = 16
        position(bossLabel, 12, 80, innerWidth - 24, 24)
        bossLabel.TextSize = 13
        position(feedbackLabel, 12, 108, innerWidth - 24, 50)
        feedbackLabel.TextSize = 13
        mobileDetailsScroll.CanvasSize = UDim2.fromOffset(0, mobileExpanded == "Goal" and 168 or (teamTop + count * 64))
    end
    local expanded = enemyChoiceAllowed() and choosingEnemy and snapshot.view ~= "Choice"
    local spectatorWidth = math.min(500, width - inset * 2)
    local hasCameraButtons = nextHeroButton.Visible
    local hasViewButtons = watchButton.Visible or personalMenuButton.Visible or chooseEnemyButton.Visible
    local spectatorHeight = expanded and (short and 224 or 274) or (hasCameraButtons and 158 or (hasViewButtons and 116 or 74))
    local cameraPadSize = short and 104 or (width < 360 and 106 or 116)
    local compactCameraPanel = not portrait and short and isTouch and cameraControls.Visible and hasCameraButtons and not expanded
    if compactCameraPanel then
        spectatorWidth = math.min(spectatorWidth, width - 2 * (inset + cameraPadSize + 12))
        spectatorHeight = groupPanel.hudButton.Visible and 144 or 122
    end
    local cameraBottom = isTouch and cameraControls.Visible and not compactCameraPanel and (cameraPadSize + 12) or 0
    if bossQueue.card.Visible then
        if bossQueue.compact then
            local queueX = isTouch and mobileGoal.Position.X.Offset or objective.Position.X.Offset
            local queueWidth = isTouch and mobileGoal.Size.X.Offset or objective.Size.X.Offset
            local queueY = isTouch and (mobileHudBottom + 8) or (objective.Position.Y.Offset + objective.Size.Y.Offset + 8)
            local spectatorTop = height - bottom - cameraBottom - spectatorHeight
            if not isTouch and portrait and queueY + 108 > spectatorTop then
                -- The observer queue replaces the tall roster when a phone needs that space.
                roster.Visible = false
                position(objective, inset, inset, width - inset * 2, short and 112 or 120)
                queueY = inset + objective.Size.Y.Offset + 8
            end
            if queueY + 108 > spectatorTop then
                -- On very shallow windows retain the queue and its invitation buttons above observation.
                if not isTouch then objective.Visible = false end
                queueY = isTouch and (mobileHudBottom + 8) or inset
                local available = height - bottom - cameraBottom - queueY - 108
                spectatorHeight = math.min(spectatorHeight, math.max(150, available))
            end
            bossQueue:layout(queueWidth, true, queueX, queueY)
        else
            bossQueue:layout(contentWidth, false)
        end
    end
    spectator.Position = UDim2.new(0.5, 0, 1, -bottom - cameraBottom)
    spectator.Size = UDim2.fromOffset(spectatorWidth, spectatorHeight)
    cameraPad.Position, cameraPad.Size = UDim2.new(0, inset, 1, -bottom), UDim2.fromOffset(cameraPadSize, cameraPadSize)
    cameraPad.Visible, cameraAxes.Visible, cameraHint.Visible = isTouch, isTouch, not isTouch
    cameraAxes.Position, cameraAxes.Size = UDim2.new(1, -inset, 1, -bottom), UDim2.fromOffset(108, 108)
    position(cameraButtons.Up, 0, 0, 50, 50)
    position(cameraButtons.Down, 58, 0, 50, 50)
    position(cameraButtons.Left, 0, 58, 50, 50)
    position(cameraButtons.Right, 58, 58, 50, 50)
    cameraButtons.Up.TextSize, cameraButtons.Down.TextSize = 11, 11
    cameraButtons.Left.TextSize, cameraButtons.Right.TextSize = 11, 11
    cameraHint.Position = UDim2.new(0.5, 0, 1, -bottom - spectatorHeight - 10)
    cameraHint.Size = UDim2.fromOffset(math.min(620, width - inset * 2), 40)
    local innerWidth, gapButtons = spectatorWidth - 28, 8
    local halfButton = (innerWidth - gapButtons) / 2
    local bottomRow = spectatorHeight - 54
    spectatorText.Visible = true
    if expanded then
        position(enemyChoiceTitle, 14, 9, spectatorWidth - 28, 19)
        position(spectatorText, 14, 31, spectatorWidth - 28, 19)
        position(enemyChoiceNote, 14, 52, spectatorWidth - 28, short and 32 or 38)
        position(enemyOffers, 14, short and 88 or 95, spectatorWidth - 28, spectatorHeight - (short and 150 or 157))
        position(watchButton, 14, bottomRow, personalMenuButton.Visible and halfButton or innerWidth, 44)
        position(personalMenuButton, 14 + halfButton + gapButtons, bottomRow, halfButton, 44)
        spectatorText.TextSize = short and 12 or 13
        if spectatorHeight < 200 then
            spectatorText.Visible = false
            position(enemyChoiceNote, 14, 30, spectatorWidth - 28, 25)
            position(enemyOffers, 14, 59, spectatorWidth - 28, spectatorHeight - 121)
        end
    else
        position(spectatorText, 14, 7, spectatorWidth - 28, hasViewButtons and 44 or 60)
        position(nextHeroButton, 14, 55, halfButton, 44)
        position(freeCameraButton, 14 + halfButton + gapButtons, 55, halfButton, 44)
        local paired = personalMenuButton.Visible and (watchButton.Visible or chooseEnemyButton.Visible)
        local viewButtonHeight = 44
        if compactCameraPanel then
            position(spectatorText, 14, 7, spectatorWidth - 28, 18)
            local cameraRowY = groupPanel.hudButton.Visible and 51 or 29
            position(nextHeroButton, 14, cameraRowY, halfButton, 44)
            position(freeCameraButton, 14 + halfButton + gapButtons, cameraRowY, halfButton, 44)
            bottomRow, viewButtonHeight = cameraRowY + 52, 34
        end
        position(watchButton, 14, bottomRow, paired and halfButton or innerWidth, viewButtonHeight)
        position(chooseEnemyButton, 14, bottomRow, paired and halfButton or innerWidth, viewButtonHeight)
        position(personalMenuButton, paired and (14 + halfButton + gapButtons) or 14,
            bottomRow, paired and halfButton or innerWidth, viewButtonHeight)
        spectatorText.TextSize = short and 12 or 14
    end
    spectatorText.TextWrapped = not compactCameraPanel
    spectatorText.TextTruncate = compactCameraPanel and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    nextHeroButton.TextSize, freeCameraButton.TextSize = compact and 13 or 15, compact and 13 or 15
    if groupPanel.hudButton.Visible then
        -- Share the spectator heading row without obscuring ordinary offers or camera buttons.
        spectatorText.Size = UDim2.fromOffset(spectatorWidth - 140, spectatorText.Size.Y.Offset)
        if expanded then
            enemyChoiceTitle.Size = UDim2.fromOffset(spectatorWidth - 140, 19)
            if spectatorHeight < 200 then enemyChoiceNote.Size = UDim2.fromOffset(spectatorWidth - 140, 25) end
        end
    end
    layoutAudioSettings(width,height,isTouch,mobileHudBottom,inset,short and 112 or 126,contentWidth)
    groupPanel:layout(contentWidth, width, height, spectatorWidth)
end

local function dragCameraTo(input)
    if not spectatorCamera.enabled or not spectatorCamera:isFree() then return end
    local center = cameraPad.AbsolutePosition + cameraPad.AbsoluteSize / 2
    local radius = math.max(1, cameraPad.AbsoluteSize.X * 0.34)
    local delta = (Vector2.new(input.Position.X, input.Position.Y) - center) / radius
    if delta.Magnitude > 1 then delta = delta.Unit end
    if delta.Magnitude < 0.12 then delta = Vector2.zero end
    spectatorCamera:setTouch(delta.X, delta.Y)
    cameraKnob.Position = UDim2.new(0.5, delta.X * radius, 0.5, delta.Y * radius)
end
cameraPad.InputBegan:Connect(function(input)
    if cameraStickInput or not spectatorCamera.enabled or not spectatorCamera:isFree() then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        cameraStickInput = input
        dragCameraTo(input)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if cameraStickInput and (input == cameraStickInput or (cameraStickInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement)) then dragCameraTo(input) end
    if cameraDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        spectatorCamera:rotate(-input.Delta.X * 0.005)
    end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    local key = input.KeyCode
    if spectatorCamera.enabled and spectatorCamera:isFree() then
        if input.UserInputType == Enum.UserInputType.MouseButton2 then cameraDragging = true end
        if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
            or key == Enum.KeyCode.Q or key == Enum.KeyCode.E then spectatorCamera:setKey(key.Name, true) end
        return
    end
end)
UserInputService.InputEnded:Connect(function(input)
    spectatorCamera:setKey(input.KeyCode.Name, false)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then cameraDragging = false end
    for held, key in pairs(cameraHolds) do
        if held == input or (held.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1) then
            spectatorCamera:setKey(key, false)
            cameraHolds[held] = nil
        end
    end
    if cameraStickInput and (input == cameraStickInput or (cameraStickInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        cameraStickInput = nil
        spectatorCamera:setTouch(0, 0)
        cameraKnob.Position = UDim2.fromScale(0.5, 0.5)
    end
end)
UserInputService.WindowFocusReleased:Connect(function()
    windowFocused = false
    resetInput()
    sendMovement()
end)
UserInputService.WindowFocused:Connect(function() windowFocused = true; syncGameplayContext() end)
UserInputService.TextBoxFocused:Connect(function() syncGameplayContext() end)
UserInputService.TextBoxFocusReleased:Connect(function() syncGameplayContext() end)

stateRemote.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then return end
    local confirmed, accepted = combatFeedback:sync(data, workspace:GetServerTimeNow())
    if accepted == false then return end
    gameAudio:sync(data)
    local wasPlayable = playable()
    local previousStatus = snapshot and snapshot.status
    local previousGroupId = snapshot and snapshot.groupId
    local previousRunId = snapshot and snapshot.runId
    local previousLevelEpoch = snapshot and snapshot.levelEpoch
    local previousView = snapshot and snapshot.view
    snapshot, mine = data, nil
    for _, hero in ipairs(data.heroes or {}) do if hero.slot == data.mine then mine = hero; break end end
    controlled = mine or data.enemyRole
    spectatorCamera:sync(data, controlled)
    local rewind=data.level and data.level.modeState and data.level.modeState.camera
    local serial=rewind and rewind.rewindSerial
    if previousGroupId~=data.groupId or previousRunId~=data.runId or previousLevelEpoch~=data.levelEpoch then vehicleRewindSerial=nil end
    if serial~=nil and vehicleRewindSerial~=nil and serial~=vehicleRewindSerial and controlled then
        movementInput:reset(gameplayBindings and gameplayBindings:heldDirections() or {})
        sendMovement()
    end
    vehicleRewindSerial=serial
    local nextIdentity = controlled and table.concat({tostring(data.groupId), tostring(data.runId), tostring(data.levelEpoch),
        tostring(controlled.actorId), tostring(controlled.attempt), tostring(controlled.connectionEpoch)}, ":") or nil
    local nextHeldContext = tostring(data.interaction ~= nil and data.interaction.carrying == true) .. ":" .. tostring(controlled and controlled.carryState)
    if nextIdentity ~= identity or previousStatus ~= data.status or previousView ~= data.view
        or previousGroupId ~= data.groupId or previousRunId ~= data.runId or previousLevelEpoch ~= data.levelEpoch then
        mobileExpanded = nil
    end
    if nextIdentity ~= identity then identity, sequence = nextIdentity, 0; feedbackUntil = 0; feedbackActionId = nil; resetInput()
    elseif wasPlayable and not playable() then resetInput()
    elseif controlled and ((lastReactionEpoch ~= nil and controlled.reactionEpoch ~= lastReactionEpoch)
        or (lastHeldContext ~= nil and nextHeldContext ~= lastHeldContext)) then
        movementInput:reset(gameplayBindings:heldDirections())
        sendMovement()
    end
    lastReactionEpoch = controlled and controlled.reactionEpoch
    lastHeldContext = nextHeldContext
    if previousGroupId ~= data.groupId or previousRunId ~= data.runId or previousLevelEpoch ~= data.levelEpoch then
        choosingEnemy = data.preference ~= "Spectator"
        pendingTemplate, pendingRole = nil, nil
        pendingEnemy = nil
        pendingView = nil
        resetInput()
    end
    if pendingTemplate and (data.selectedTemplate == pendingTemplate or data.notice) then pendingTemplate = nil end
    if pendingRole and (data.preference == pendingRole or data.notice) then pendingRole = nil end
    if pendingEnemy and (data.enemyRole or data.notice) then pendingEnemy = nil end
    if pendingView and (data.view == pendingView or data.notice or data.status ~= "Active") then pendingView = nil end
    if previousGroupId ~= data.groupId or previousStatus ~= data.status then scroll.CanvasPosition = Vector2.zero end
    actionPending = false
    if feedbackActionId and (type(data.actionFeedback) ~= "table" or data.actionFeedback.id ~= feedbackActionId) then
        feedbackUntil, feedbackActionId = 0, nil
    end
    if os.clock() >= feedbackUntil then
        feedbackLabel.Text, feedbackLabel.TextColor3 = T(CombatFeedback.hint(data,T)), C.muted
    end
    if #confirmed > 0 then
        local latest = confirmed[#confirmed]
        feedbackLabel.Text = T(latest.text)
        feedbackLabel.TextColor3 = ({damage=C.red,shield=C.yellow,success=C.lime})[latest.style] or C.text
        feedbackActionId = latest.kind == "ActionResult" and latest.actionId or nil
        feedbackUntil = os.clock() + math.min(1.4, latest.duration or 1.4)
    end
    render()
    layout()
    syncGameplayContext()
end)
safe:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
localizationService:GetPropertyChangedSignal("RobloxLocaleId"):Connect(function()
    feedbackUntil,feedbackActionId=0,nil
    feedbackLabel.Text=T(CombatFeedback.hint(snapshot,T))
    render();layout()
end)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function() mobileExpanded = nil; layout() end)
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
local moveElapsed, syncElapsed = 0, 0
RunService.RenderStepped:Connect(function(dt)
    syncGameplayContext()
    if feedbackUntil > 0 and os.clock() >= feedbackUntil then
        feedbackUntil = 0
        feedbackLabel.Text, feedbackLabel.TextColor3 = T(CombatFeedback.hint(snapshot,T)), C.muted
    end
    bossQueue:step()
    groupPanel:step()
    moveElapsed, syncElapsed = moveElapsed + dt, syncElapsed + dt
    if syncElapsed >= 2 then
        syncElapsed = 0
        if not snapshot then sendIntent({kind = "Sync"}) end
        if pendingTemplate and os.clock() - pendingAt > 4 then
            pendingTemplate = nil
            sendIntent({kind = "Sync"})
            renderSelection()
        end
        if pendingRole and os.clock() - pendingRoleAt > 4 then
            pendingRole = nil
            sendIntent({kind = "Sync"})
            renderSelection()
        end
        if pendingEnemy and os.clock() - pendingEnemyAt > 4 then
            pendingEnemy = nil
            sendIntent({kind = "Sync"})
            render()
        end
        if pendingView and os.clock() - pendingViewAt > 4 then
            pendingView = nil
            sendIntent({kind = "Sync"})
            render()
        end
        if actionPending and os.clock() - actionAt > 4 then actionPending = false; render() end
    end
    local camera = workspace.CurrentCamera
    spectatorCamera:step(dt, camera)
    if moveElapsed >= 0.1 then
        moveElapsed = 0
        if playable() then
            sendMovement()
        end
    end
end)
render()
layout()
sendIntent({kind = "Sync"})
