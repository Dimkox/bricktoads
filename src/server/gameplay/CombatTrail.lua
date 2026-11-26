-- BT-127. Replicated visual ribbons. The caller owns every action and its timing.
local RunService = game:GetService("RunService")
local CombatTrail = {}

-- Relative width, lifetime in seconds, maximum length in studs, near/far colors.
local function palette(width, life, length, near, far)
    return {width=width, life=life, length=length, near=Color3.fromHex(near), far=Color3.fromHex(far)}
end
local styles = {
    strike   = palette(.88, .16, 5, "FFF4B7", "FF8D42"),
    rush     = palette(.86, .23, 8, "FFED88", "F16C4B"),
    gas      = palette(.84, .31, 6, "DAF99A", "6A9D52"),
    electric = palette(.61, .16, 7, "D8FAFF", "6085FF"),
    fire     = palette(.80, .24, 8, "FFF09C", "FC5841"),
    swim     = palette(.70, .29, 7, "C9FFFA", "459ACC"),
    spin     = palette(.77, .21, 6, "F6D5FF", "AE79DF"),
    dash     = palette(.74, .19, 8, "F4FFF7", "58C3D1"),
    dust     = palette(.86, .26, 6, "FFE6BC", "B88866"),
    metal    = palette(.59, .15, 6, "EDF7FF", "889AAE"),
}

local outerTexture = "rbxassetid://131809614576042"
local function curve(start, middle, finish)
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0,start),
        NumberSequenceKeypoint.new(.48,middle),
        NumberSequenceKeypoint.new(1,finish),
    })
end
local edgeAlpha, centerAlpha = curve(.26,.58,1), curve(.12,.48,1)
local edgeWidth, centerWidth = curve(1,.72,0), curve(.25,.13,0)

local byOwner = {}
local heartbeat

local function layer(state, outer)
    local trail = Instance.new("Trail")
    trail.Name = outer and "CombatTrailSoftEdge" or "CombatTrailCore"
    trail.Attachment0, trail.Attachment1 = state.top, state.bottom
    trail.Color = ColorSequence.new(outer and state.profile.near or Color3.new(1,1,1),state.profile.far)
    trail.WidthScale = outer and edgeWidth or centerWidth
    trail.Transparency = outer and edgeAlpha or centerAlpha
    trail.FaceCamera = true
    trail.LightEmission = outer and .48 or .82
    trail.LightInfluence = .15
    trail.Lifetime = state.profile.life * (outer and 1 or .78)
    trail.MinLength = .025
    trail.MaxLength = state.profile.length
    if outer then
        trail.Texture = outerTexture
        trail.TextureMode = Enum.TextureMode.Stretch
    end
    trail.Enabled = true
    trail.Parent = state.part
    return trail
end

local function discard(state)
    state.edge:Destroy()
    state.core:Destroy()
    state.top:Destroy()
    state.bottom:Destroy()
    byOwner[state.owner] = nil
end

local function attachment(part, name, offset)
    local point = Instance.new("Attachment")
    point.Name = name
    point.Position = offset
    point.Parent = part
    return point
end

local function update(state, dt)
    if not state.owner.Parent or not state.part:IsDescendantOf(workspace) then
        discard(state)
        return
    end
    if state.fade then
        state.fade -= dt
        if state.fade <= 0 then discard(state) end
        return
    end

    local position = state.part.Position
    local distance = (position - state.lastPosition).Magnitude
    state.lastPosition = position
    if distance > state.profile.length then
        -- A fresh replicated Instance also drops the history on observing clients.
        state.edge:Destroy()
        state.core:Destroy()
        state.edge = layer(state,true)
        state.core = layer(state,false)
    end

    if state.sampleTime then
        -- Both hero and enemy run attacks can halt the physical actor before
        -- the hit. Prefer motion of the visible limb, including its rotation.
        state.sampleTime += dt
        if (state.top.WorldPosition - state.startPoint).Magnitude > .065 then
            state.sampleTime = nil
        elseif state.sampleTime >= .045 then
            state.sampleTime = nil
            state.swing = 0
        end
    end
    if state.swing then
        state.swing = math.min(.18,state.swing + dt)
        local phase = state.swing / .18
        local shift = Vector3.new(math.sin(phase*math.pi)*.34, .12*math.sin(phase*math.pi), -state.reach*phase)
        state.top.Position = state.half + shift
        state.bottom.Position = -state.half + shift
        if phase == 1 then state.swing = nil end
    end
end

local function watch()
    if heartbeat then return end
    heartbeat = RunService.Heartbeat:Connect(function(dt)
        for _,state in pairs(byOwner) do update(state,dt) end
        if not next(byOwner) then
            heartbeat:Disconnect()
            heartbeat = nil
        end
    end)
end

-- A nil part/style on release matches the owner's current ribbon.
function CombatTrail.set(owner, movingPart, style, active)
    if not owner then return false end
    local current = byOwner[owner]
    if not active then
        if current and not current.fade and (not movingPart or current.part == movingPart)
                and (not style or current.style == style) then
            current.edge.Enabled = false
            current.core.Enabled = false
            current.fade = current.profile.life
        end
        return false
    end
    local profile = styles[style]
    if not profile or not movingPart or not movingPart:IsA("BasePart") then return false end
    if current and not current.fade and current.part == movingPart and current.style == style then return true end
    if current then discard(current) end

    local size = movingPart.Size
    local width = math.clamp(math.max(size.X,size.Y)*profile.width,.42,3.6)
    local half = Vector3.new(0,width*.5,0)
    local state = {owner=owner,part=movingPart,style=style,profile=profile,half=half,lastPosition=movingPart.Position}
    -- Sample the rim of a turning gear even when its center stays in place.
    local center = style == "spin" and Vector3.new(size.X*.31,0,size.Z*.24) or Vector3.new()
    state.top = attachment(movingPart,"CombatTrailTop",center + half)
    state.bottom = attachment(movingPart,"CombatTrailBottom",center - half)
    state.edge = layer(state,true)
    state.core = layer(state,false)
    local actorSwing = owner ~= movingPart and (style == "strike" or style == "rush" or style == "dash")
    if actorSwing or (style == "strike" and movingPart.Anchored) then
        state.reach = math.clamp(width*.55+.5,.72,1.8)
        state.sampleTime = 0
        state.startPoint = state.top.WorldPosition
    end
    byOwner[owner] = state
    watch()
    return true
end

return CombatTrail
