-- Original first-level presentation. Combat and hero physics stay in BaseWorld.
local World = {}

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local COLORS = {
    stone = Color3.fromRGB(71, 92, 89),
    dark = Color3.fromRGB(35, 54, 57),
    pale = Color3.fromRGB(159, 179, 151),
    moss = Color3.fromRGB(72, 115, 77),
    mint = Color3.fromRGB(134, 255, 194),
    amber = Color3.fromRGB(255, 184, 72),
    rust = Color3.fromRGB(178, 82, 47),
}

local function part(parent, name, size, frame, color, material, collidable)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = frame
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = collidable == true
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function ball(parent, name, size, frame, color, material)
    local p = part(parent, name, size, frame, color, material, false)
    p.Shape = Enum.PartType.Ball
    return p
end

local function cosmetic(model, limb, name, size, offset, color, shape, material)
    local p = part(model, name, size, limb.CFrame * offset, color, material, false)
    if shape then p.Shape = shape end
    p.Anchored = false
    p.Massless = true
    p.CanQuery = false
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = limb
    weld.Part1 = p
    weld.Parent = p
    return p
end

local function label(parent, text, size, offset)
    local board = Instance.new("BillboardGui")
    board.Name = "WorldLabel"
    board.Size = UDim2.fromOffset(size or 240, 44)
    board.StudsOffset = offset or Vector3.new(0, 3, 0)
    board.AlwaysOnTop = false
    board.MaxDistance = 120
    board.Parent = parent
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(226, 244, 211)
    textLabel.TextStrokeColor3 = Color3.fromRGB(20, 39, 37)
    textLabel.TextStrokeTransparency = 0.15
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 17
    textLabel.TextWrapped = true
    textLabel.Parent = board
    return textLabel
end

local function pointLight(parent, color, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range
    light.Brightness = brightness
    light.Shadows = false
    light.Parent = parent
    return light
end

local function hideRig(actor)
    for _,p in ipairs(actor.model:GetChildren()) do
        if p:IsA("BasePart") then p.Transparency = 1 end
    end
    -- The stand's small eye parts are also cosmetic and can be replaced safely.
    for _,p in ipairs(actor.model:GetChildren()) do
        if p.Name == "Eye" then p:Destroy() end
    end
end

local function toad(actor, template)
    hideRig(actor)
    local palettes = {
        ["Mr. Green"] = {Color3.fromRGB(94, 159, 102), Color3.fromRGB(188, 209, 122), Color3.fromRGB(41, 85, 65)},
        ["Mr. Yellow"] = {Color3.fromRGB(210, 169, 61), Color3.fromRGB(246, 224, 143), Color3.fromRGB(118, 83, 41)},
        ["Mr. Brown"] = {Color3.fromRGB(160, 112, 86), Color3.fromRGB(224, 186, 129), Color3.fromRGB(86, 61, 61)},
    }
    local palette = palettes[template] or palettes["Mr. Green"]
    local skin, belly, accent = palette[1], palette[2], palette[3]
    local model = actor.model
    local torso, head = model.Torso, model.Head
    cosmetic(model, torso, "ToadBody", Vector3.new(2.3, 2.05, 1.55), CFrame.new(), skin, Enum.PartType.Ball)
    cosmetic(model, torso, "Belly", Vector3.new(1.65, 1.65, 0.32), CFrame.new(0, -0.08, -0.7), belly, Enum.PartType.Ball)
    cosmetic(model, head, "ToadHead", Vector3.new(2.5, 1.55, 1.55), CFrame.new(0, 0.08, -0.05), skin, Enum.PartType.Ball)
    cosmetic(model, head, "LowerMuzzle", Vector3.new(2.12, 0.5, 1.1), CFrame.new(0, -0.35, -0.36), belly, Enum.PartType.Ball)
    cosmetic(model, head, "Mouth", Vector3.new(1.3, 0.055, 0.045), CFrame.new(0, -0.28, -0.91), accent)
    for _,side in ipairs({-1, 1}) do
        local x = side * 0.75
        cosmetic(model, head, "EyeRidge", Vector3.new(0.98, 0.98, 0.9), CFrame.new(x, 0.6, -0.27), skin, Enum.PartType.Ball)
        cosmetic(model, head, "EyeWhite", Vector3.new(0.71, 0.75, 0.39), CFrame.new(x, 0.63, -0.67), Color3.fromRGB(251, 245, 203), Enum.PartType.Ball)
        cosmetic(model, head, "Iris", Vector3.new(0.3, 0.43, 0.15), CFrame.new(x, 0.64, -0.88), accent, Enum.PartType.Ball)
        cosmetic(model, head, "EyeShine", Vector3.new(0.09, 0.12, 0.05), CFrame.new(x - 0.06, 0.74, -0.96), Color3.new(1, 1, 1), Enum.PartType.Ball)
        cosmetic(model, head, "Brow", Vector3.new(0.82, 0.16, 0.37), CFrame.new(x, 1, -0.6) * CFrame.Angles(0, 0, side * 0.12), accent, Enum.PartType.Ball)
        cosmetic(model, head, "Nostril", Vector3.new(0.12, 0.1, 0.06), CFrame.new(side * 0.27, -0.02, -0.81), accent, Enum.PartType.Ball)
        local arm = model[side == -1 and "Left Arm" or "Right Arm"]
        local leg = model[side == -1 and "Left Leg" or "Right Leg"]
        cosmetic(model, arm, "UpperArm", Vector3.new(0.9, 1.7, 0.95), CFrame.new(0, 0.1, 0), skin, Enum.PartType.Ball)
        cosmetic(model, arm, "Palm", Vector3.new(0.94, 0.65, 0.85), CFrame.new(0, -0.8, -0.08), skin, Enum.PartType.Ball)
        cosmetic(model, leg, "Haunch", Vector3.new(1.15, 1.4, 1.2), CFrame.new(0, 0.3, 0.12), skin, Enum.PartType.Ball)
        cosmetic(model, leg, "Foot", Vector3.new(1.1, 0.44, 1.5), CFrame.new(0, -0.8, -0.36), skin, Enum.PartType.Ball)
        for finger = -1, 1 do
            cosmetic(model, arm, "Finger", Vector3.new(0.22, 0.55, 0.25), CFrame.new(finger * 0.29, -1.1, -0.18), belly, Enum.PartType.Ball)
            cosmetic(model, leg, "Toe", Vector3.new(0.26, 0.3, 0.67), CFrame.new(finger * 0.3, -0.82, -1.02), belly, Enum.PartType.Ball)
        end
        for spot = 1, 2 do
            cosmetic(model, torso, "ToadSpot", Vector3.new(0.28, 0.35, 0.12), CFrame.new(side * 0.93, 0.3 - spot * 0.43, -0.42), accent, Enum.PartType.Ball)
        end
    end
    model:SetAttribute("Template", template or "Mr. Green")
    model:SetAttribute("Appearance", "OriginalToad")
end

local function drone(actor)
    hideRig(actor)
    local m = actor.model
    cosmetic(m, m.Torso, "RustHull", Vector3.new(2.35, 1.85, 1.55), CFrame.new(), COLORS.rust)
    cosmetic(m, m.Torso, "ChestGrille", Vector3.new(1.4, 0.95, 0.15), CFrame.new(0, -0.15, -0.84), COLORS.dark)
    for n = -1, 1 do
        cosmetic(m, m.Torso, "Vent", Vector3.new(1.1, 0.08, 0.07), CFrame.new(0, n * 0.25 - 0.1, -0.95), COLORS.pale)
        local arm = m[n == -1 and "Left Arm" or "Right Arm"]
        local leg = m[n == -1 and "Left Leg" or "Right Leg"]
        cosmetic(m, arm, "ToolArm", Vector3.new(0.72, 1.8, 0.72), CFrame.new(), COLORS.dark)
        cosmetic(m, arm, "Clamp", Vector3.new(1.05, 0.52, 1.08), CFrame.new(0, -0.8, -0.18), COLORS.rust)
        cosmetic(m, leg, "Strut", Vector3.new(0.56, 1.7, 0.62), CFrame.new(), COLORS.pale)
        cosmetic(m, leg, "TrackFoot", Vector3.new(0.9, 0.45, 1.5), CFrame.new(0, -0.8, -0.15), COLORS.dark)
    end
    cosmetic(m, m.Head, "SensorHousing", Vector3.new(1.5, 0.86, 1.4), CFrame.new(), COLORS.dark)
    cosmetic(m, m.Head, "SingleOptic", Vector3.new(0.68, 0.5, 0.25), CFrame.new(0, 0.02, -0.77), COLORS.amber, Enum.PartType.Ball, Enum.Material.Neon)
    cosmetic(m, m.Head, "Antenna", Vector3.new(0.12, 0.95, 0.12), CFrame.new(0.6, 0.7, 0.22) * CFrame.Angles(0, 0, -0.25), COLORS.pale)
    cosmetic(m, m.Head, "AntennaTip", Vector3.new(0.23, 0.23, 0.23), CFrame.new(0.72, 1.13, 0.22), COLORS.amber, Enum.PartType.Ball, Enum.Material.Neon)
end

local function boss(actor)
    hideRig(actor)
    local m, root = actor.model, actor.root
    local function c(name, size, offset, color, shape, material)
        return cosmetic(m, root, name, size, offset, color, shape, material)
    end
    c("GuardianBase", Vector3.new(7.6, 1.5, 6.3), CFrame.new(0, -2.1, 0), COLORS.dark)
    c("GuardianDrum", Vector3.new(5.6, 4.8, 4.8), CFrame.new(0, -0.1, 0), COLORS.rust, Enum.PartType.Ball)
    c("GuardianCrown", Vector3.new(6.4, 1.15, 4.8), CFrame.new(0, 2.5, 0.2), COLORS.dark)
    c("FacePlate", Vector3.new(3.8, 2.7, 0.7), CFrame.new(0, 0.9, -2.1), COLORS.pale)
    c("ReactorEye", Vector3.new(1.45, 1.45, 0.5), CFrame.new(0, 1.12, -2.56), COLORS.amber, Enum.PartType.Ball, Enum.Material.Neon)
    c("CannonHousing", Vector3.new(2.3, 1.7, 2.5), CFrame.new(0, -0.85, -2.05), COLORS.dark)
    c("CannonMouth", Vector3.new(1.6, 1.15, 0.25), CFrame.new(0, -0.85, -3.4), COLORS.amber, Enum.PartType.Ball, Enum.Material.Neon)
    for _,side in ipairs({-1, 1}) do
        c("AnchorPylon", Vector3.new(1.25, 4.6, 1.7), CFrame.new(side * 3, -0.55, 0.4) * CFrame.Angles(0, 0, side * 0.15), COLORS.dark)
        c("ShieldCoil", Vector3.new(1.1, 2.4, 1.1), CFrame.new(side * 3.6, 1.1, 0), COLORS.mint, Enum.PartType.Cylinder, Enum.Material.Neon)
        c("CrownFin", Vector3.new(0.7, 2, 1.8), CFrame.new(side * 2.1, 3.65, 0.6) * CFrame.Angles(0, 0, -side * 0.2), COLORS.rust)
    end
    pointLight(root, COLORS.amber, 16, 1.5)
end

local function buildGeometry(self)
    self.geometry:ClearAllChildren()
    self.floors = {}
    local g = self.geometry
    local floor = part(g, "FloodedCauseway", Vector3.new(206, 3.4, 42), CFrame.new(21, -1.7, 0), COLORS.stone, Enum.Material.Slate, true)
    floor:SetAttribute("SurfaceId", "Causeway")
    self.floors[1] = floor
    -- Large stone surfaces support respawn checks; shallow insets are visual only.
    for x = -76, 120, 7 do
        for z = -14, 14, 7 do
            local shade = ((math.floor(x / 7) + math.floor(z / 7)) % 3) * 6
            part(g, "PavingStone", Vector3.new(6.7, 0.1, 6.7), CFrame.new(x, 0.025, z), Color3.fromRGB(81 + shade, 105 + shade, 98 + shade), Enum.Material.Slate)
        end
    end
    part(g, "SubmergedFoundation", Vector3.new(208, 7, 44), CFrame.new(21, -5.1, 0), COLORS.dark, Enum.Material.Rock)
    local marsh = part(g, "MarshWater", Vector3.new(440, 0.4, 230), CFrame.new(20, -7.8, 0), Color3.fromRGB(34, 101, 96), Enum.Material.Glass)
    marsh.Transparency = 0.3
    marsh.Reflectance = 0.25
    local mist = part(g, "WaterDepth", Vector3.new(440, 12, 230), CFrame.new(20, -14, 0), Color3.fromRGB(22, 54, 61), Enum.Material.SmoothPlastic)
    mist.Transparency = 0.15
    -- The optional side pool is visibly separated from the wide, safe central path.
    self.danger = part(g, "BitterBogPool", Vector3.new(15, 0.24, 6), CFrame.new(10, 0.14, 15.5), Color3.fromRGB(195, 113, 44), Enum.Material.Neon, true)
    self.danger.Transparency = 0.2
    self.danger:SetAttribute("Hazard", true)
    self.danger:SetAttribute("SurfaceId", "Causeway")
    for _,z in ipairs({11.9, 19.1}) do
        part(g, "PoolRim", Vector3.new(16, 0.5, 0.45), CFrame.new(10, 0.25, z), COLORS.dark, Enum.Material.Rock)
    end
    for _,x in ipairs({2, 18}) do
        part(g, "PoolRim", Vector3.new(0.5, 0.5, 7.6), CFrame.new(x, 0.25, 15.5), COLORS.dark, Enum.Material.Rock)
    end
    local warning = part(g, "BogWarning", Vector3.new(0.4, 2.6, 0.4), CFrame.new(-1, 1.3, 12.5), COLORS.pale, Enum.Material.Wood)
    label(warning, "ОПАСНАЯ ТОПЬ", 160, Vector3.new(0, 2, 0)).TextColor3 = COLORS.amber

    -- Broken parapets leave readable edges while keeping the route open.
    for x = -76, 118, 12 do
        for _,side in ipairs({-1, 1}) do
            local z = side * 20
            part(g, "ParapetFoot", Vector3.new(2.2, 1.7, 2), CFrame.new(x, 0.85, z), COLORS.stone, Enum.Material.Rock, true)
            if (math.floor(x / 12) + side) % 3 ~= 0 then
                part(g, "BrokenParapet", Vector3.new(7.6, 1.35, 1.1), CFrame.new(x + 4.4, 0.68, z), COLORS.dark, Enum.Material.Rock, true)
            end
            local lamp = ball(g, "WayLight", Vector3.new(0.55, 0.55, 0.55), CFrame.new(x, 1.95, z), COLORS.mint, Enum.Material.Neon)
            pointLight(lamp, COLORS.mint, 9, 0.55)
        end
    end

    -- A ruined aqueduct silhouette, using only native primitives.
    local function arch(x, name, intact)
        local model = Instance.new("Model")
        model.Name = name
        model.Parent = g
        for _,side in ipairs({-1, 1}) do
            part(model, "PillarFoot", Vector3.new(5, 1.4, 5), CFrame.new(x, 0.7, side * 17), COLORS.dark, Enum.Material.Rock)
            part(model, "MossPillar", Vector3.new(2.7, 10.5, 3.2), CFrame.new(x, 6.6, side * 17), COLORS.stone, Enum.Material.Rock)
            part(model, "Capital", Vector3.new(3.9, 1.1, 4), CFrame.new(x, 12, side * 17), COLORS.pale, Enum.Material.Rock)
            for n = 1, 3 do
                local z = side * (17 - n * 2.5)
                part(model, "ArchVoussoir", Vector3.new(2.8, 2.3, 3.1), CFrame.new(x, 12.1 + n * 1.4, z) * CFrame.Angles(side * 0.12, 0, 0), COLORS.stone, Enum.Material.Rock)
            end
        end
        if intact then
            part(model, "Keystone", Vector3.new(3.1, 2.8, 15), CFrame.new(x, 17.3, 0), COLORS.dark, Enum.Material.Rock)
            local seal = ball(model, "AncientSeal", Vector3.new(0.5, 2.4, 2.4), CFrame.new(x - 1.8, 17.3, 0), COLORS.mint, Enum.Material.Neon)
            pointLight(seal, COLORS.mint, 18, 1)
        end
    end
    arch(-75, "WelcomeRuin", true)
    arch(42, "BrokenAqueduct", false)
    arch(107, "ExitArch", true)

    -- Reeds, lily pads, fallen masonry and distant trunks frame the linear level.
    for n = 1, 48 do
        local x = -95 + (n * 37 % 239)
        local side = n % 2 == 0 and 1 or -1
        local z = side * (27 + (n * 11 % 35))
        local y = -6.8
        ball(g, "MarshIsland", Vector3.new(9 + n % 5, 1.1, 7), CFrame.new(x, y - 0.1, z), COLORS.moss, Enum.Material.Grass)
        for reed = 1, 3 do
            local height = 2.4 + (n + reed) % 4
            part(g, "Reed", Vector3.new(0.19, height, 0.24), CFrame.new(x + reed * 0.6 - 1.2, y + height / 2, z) * CFrame.Angles(0.08, 0, (reed - 2) * 0.13), Color3.fromRGB(102, 141, 79), Enum.Material.Grass)
            ball(g, "SeedHead", Vector3.new(0.4, 1.05, 0.4), CFrame.new(x + reed * 0.6 - 1.2, y + height, z), Color3.fromRGB(109, 84, 64))
        end
        if n % 4 == 0 then
            part(g, "FallenMasonry", Vector3.new(6, 3, 4), CFrame.new(x, -5.8, z + side * 3) * CFrame.Angles(0.2, n, 0.35), COLORS.dark, Enum.Material.Rock)
        end
    end
    for n = 1, 16 do
        local side = n % 2 == 0 and 1 or -1
        local x, z = -98 + n * 16, side * (62 + n % 3 * 8)
        local height = 13 + n % 5 * 3
        part(g, "DrownedTrunk", Vector3.new(2.6, height, 2.7), CFrame.new(x, height / 2 - 8, z) * CFrame.Angles(0, 0, side * 0.1), Color3.fromRGB(42, 66, 62), Enum.Material.Wood)
        ball(g, "Canopy", Vector3.new(21, 9, 17), CFrame.new(x, height - 7, z), Color3.fromRGB(41, 82, 70), Enum.Material.Grass)
    end

    local start = part(g, "StartSign", Vector3.new(1, 0.5, 1), CFrame.new(-63, 4.6, -15), COLORS.dark)
    start.Transparency = 1
    label(start, "ЗАТОПЛЕННЫЙ ТРАКТ", 310, Vector3.new(0, 2.8, 0)).TextSize = 23
    label(start, "ВПЕРЁД  →", 200, Vector3.new(0, 0.8, 0)).TextColor3 = COLORS.mint

    self.gates = {}
    local function gate(x, title)
        local beam = part(g, "EncounterGate", Vector3.new(0.6, 7.5, 44), CFrame.new(x, 3.75, 0), COLORS.amber, Enum.Material.ForceField, true)
        beam.Transparency = 0.63
        local text = label(beam, title, 290, Vector3.new(0, 6, 0))
        local marker = ball(g, "ObjectiveBeacon", Vector3.new(1.8, 1.8, 1.8), CFrame.new(x, 11.4, 0), COLORS.amber, Enum.Material.Neon)
        local light = pointLight(marker, COLORS.amber, 17, 1.6)
        local record = {beam = beam, label = text, marker = marker, light = light}
        self.gates[#self.gates + 1] = record
        return record
    end
    gate(2, "I  ·  РАСЧИСТИТЕ ТРАКТ")
    gate(52, "II  ·  ЗАТОПЛЕННЫЙ ДВОР")
    self.exitGate = gate(108, "III  ·  СТРАЖ ПЕРЕПРАВЫ")
    local exitPad = part(g, "ExitPad", Vector3.new(12, 0.13, 20), CFrame.new(115, 0.09, 0), COLORS.mint, Enum.Material.Neon)
    exitPad.Transparency = 0.6
    self.exitPad = exitPad
    for x = -57, 101, 18 do
        local arrow = part(g, "RouteArrow", Vector3.new(2, 0.08, 0.45), CFrame.new(x, 0.12, 0), COLORS.pale, Enum.Material.Neon)
        arrow.Transparency = 0.45
        for _,side in ipairs({-1, 1}) do
            local wing = part(g, "RouteArrowWing", Vector3.new(1.15, 0.08, 0.3), CFrame.new(x + 0.45, 0.12, side * 0.35) * CFrame.Angles(0, side * 0.65, 0), COLORS.pale, Enum.Material.Neon)
            wing.Transparency = 0.45
        end
    end
end

function World.new(BaseWorld, config)
    -- Remove only the untouched blank-place defaults in this playable runtime.
    for _,object in ipairs(Workspace:GetChildren()) do
        if (object.Name == "Baseplate" and object:IsA("BasePart"))
            or (object.Name == "SpawnLocation" and object:IsA("SpawnLocation")) then
            object:Destroy()
        end
    end
    local previous = Workspace:FindFirstChild("BrickToadsWorld")
    if previous then previous:Destroy() end
    local self = BaseWorld.new(config)
    self._base = BaseWorld
    setmetatable(self, {__index = function(_, key) return World[key] or BaseWorld[key] end})
    self.folder.Name = "BrickToadsWorld"
    self.folder:SetAttribute("LevelName", "Затопленный тракт")
    self.folder:SetAttribute("OriginalArt", true)
    self.enemyKinds = {}
    self.origins = {
        [1] = Vector3.new(-65, 3, -7),
        [2] = Vector3.new(-65, 3, 0),
        [3] = Vector3.new(-65, 3, 7),
    }
    buildGeometry(self)
    Lighting.ClockTime = 16.5
    Lighting.Brightness = 2.2
    Lighting.Ambient = Color3.fromRGB(80, 109, 111)
    Lighting.OutdoorAmbient = Color3.fromRGB(119, 142, 132)
    Lighting.ColorShift_Top = Color3.fromRGB(255, 220, 170)
    Lighting.GlobalShadows = true
    Lighting.FogColor = Color3.fromRGB(112, 155, 151)
    Lighting.FogStart = 150
    Lighting.FogEnd = 380
    local atmosphere = Lighting:FindFirstChild("CausewayAtmosphere") or Instance.new("Atmosphere")
    atmosphere.Name = "CausewayAtmosphere"
    atmosphere.Density = 0.24
    atmosphere.Offset = 0.12
    atmosphere.Color = Color3.fromRGB(178, 207, 186)
    atmosphere.Decay = Color3.fromRGB(84, 123, 126)
    atmosphere.Glare = 0.12
    atmosphere.Haze = 1.5
    atmosphere.Parent = Lighting
    self:stage("Approach")
    return self
end

function World:spawn(uid, actorId, point, held, template)
    if not self.origins[uid] and uid > 0 then self.origins[uid] = Vector3.new(-65, 3, (uid - 2) * 7) end
    local ok = self._base.spawn(self, uid, actorId, point, held, template or "Mr. Green")
    if ok then
        self.actors[uid].model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        toad(self.actors[uid], template or "Mr. Green")
        local actor=self.actors[uid]
        actor.humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        local ownerName=label(actor.root,actor.humanoid.DisplayName,220,Vector3.new(0,4.2,0))
        ownerName.TextSize=14
        ownerName.Parent.Name='OwnerNameplate'
    end
    return ok
end

function World:spawnEnemy(id, kind, positionTable)
    if type(id) ~= "number" or id >= 0 or id <= -1000 or not positionTable then return false end
    local x, y, z = positionTable.x, positionTable.y, positionTable.z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return false end
    local isBoss = string.lower(tostring(kind)) == "boss"
    self.origins[id] = Vector3.new(x, y, z)
    self.names[id] = isBoss and "Страж переправы" or "Ржавый дозорный"
    if not self._base.spawn(self, id, id, nil, false, "Mr. Brown") then return false end
    local actor = self.actors[id]
    actor.model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    -- BaseWorld's ordinary spawn is deliberately y=3, so preserve the supplied
    -- world position explicitly for project/director callers.
    actor.model:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x - 1, y, z)))
    actor.model:SetAttribute("EnemyKind", kind)
    actor.model:SetAttribute("Template", nil)
    actor.model:SetAttribute("Slot", nil)
    actor.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    actor.humanoid.WalkSpeed = isBoss and 0 or 8
    self.enemyKinds[id] = isBoss and "Boss" or "Drone"
    if isBoss then boss(actor) else drone(actor) end
    actor.healthLabel = label(actor.root, "♥ ♥ ♥", isBoss and 270 or 160, Vector3.new(0, isBoss and 7.6 or 4.5, 0))
    actor.healthLabel.TextColor3 = isBoss and COLORS.amber or Color3.fromRGB(255, 164, 139)
    self:enemyHealth(id, 3, 3)
    return true
end

function World:position(id)
    local a = self.actors[id]
    if not a or not a.root.Parent then return nil end
    local p = a.root.Position
    return {x = p.X, y = p.Y, z = p.Z}
end

function World:cameraBounds()
    local minX,maxX,minZ,maxZ,top=math.huge,-math.huge,math.huge,-math.huge,-math.huge
    for _,floor in ipairs(self.floors) do
        minX=math.min(minX,floor.Position.X-floor.Size.X/2)
        maxX=math.max(maxX,floor.Position.X+floor.Size.X/2)
        minZ=math.min(minZ,floor.Position.Z-floor.Size.Z/2)
        maxZ=math.max(maxZ,floor.Position.Z+floor.Size.Z/2)
        top=math.max(top,floor.Position.Y+floor.Size.Y/2)
    end
    assert(minX<maxX and minZ<maxZ,'The current level has no camera bounds')
    return {minX=minX-12,maxX=maxX+12,minY=top+7,maxY=top+52,minZ=minZ-28,maxZ=maxZ+28}
end

function World:enemyIdentity(id,actorId,ownerName)
    local actor=self.actors[id]
    if not actor or (self.enemyKinds[id]~='Drone' and self.enemyKinds[id]~='Boss') then return end
    actor.model:SetAttribute('ActorId',actorId)
    actor.model:SetAttribute('ControlledByPlayer',ownerName~=nil)
    if ownerName then
        local board=actor.root:FindFirstChild('OwnerNameplate')
        if board then board.Text.Text=ownerName
        else
            local text=label(actor.root,ownerName,220,Vector3.new(0,self.enemyKinds[id]=='Boss' and 10.2 or 5.7,0))
            text.TextSize=14; text.TextColor3=COLORS.amber; text.Parent.Name='OwnerNameplate'
        end
    end
end

function World:move(id,x,z)
    local actor=self.actors[id]
    if actor and self.enemyKinds[id]=='Drone' and not actor.humanoid.PlatformStand then
        actor.humanoid.WalkSpeed=self.config.Enemy.speed
    end
    self._base.move(self,id,x,z)
end

function World:setReaction(id,active)
    self._base.setReaction(self,id,active)
    local actor=self.actors[id]
    if actor and self.enemyKinds[id]=='Drone' then actor.humanoid.WalkSpeed=active and 0 or self.config.Enemy.speed end
end

function World:face(id, targetId)
    local a, b = self.actors[id], self.actors[targetId]
    if not a or not b or not a.root.Parent or not b.root.Parent then return end
    local p, q = a.root.Position, b.root.Position
    local flat = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
    if flat.Magnitude > 0.05 then a.root.CFrame = CFrame.lookAt(p, p + flat) end
end

function World:aim(id,x,z)
    local actor=self.actors[id]
    if actor and actor.root.Parent and actor.humanoid.Health>0 and x*x+z*z>0 then
        local position=actor.root.Position
        actor.root.CFrame=CFrame.lookAt(position,position+Vector3.new(x,0,z))
    end
end

function World:enemyMove(id, targetId, speed)
    local a, b = self.actors[id], self.actors[targetId]
    if not a or not b or not a.root.Parent or not b.root.Parent or a.root.Anchored or a.humanoid.Health <= 0 then return end
    local delta = b.root.Position - a.root.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    a.humanoid.WalkSpeed = speed or 8
    local direction = flat.Magnitude > 0.2 and flat.Unit or Vector3.new()
    if direction.Magnitude > 0 then
        local ahead = a.root.Position + direction * 3
        local side = Vector3.new(-direction.Z, 0, direction.X) * 0.85
        for _,offset in ipairs({Vector3.new(), side, -side}) do
            local support = Workspace:Raycast(ahead + offset + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), self.ray)
            if not support or support.Normal.Y < 0.95 or support.Instance:GetAttribute("Hazard")
                or not support.Instance:GetAttribute("SurfaceId") then
                direction = Vector3.new()
                break
            end
        end
    end
    -- Stop voluntary pursuit at an unsafe edge. External impulses and gravity
    -- remain untouched, so combat can still knock a mechanical enemy off.
    a.humanoid:Move(direction, false)
end

function World:enemyHealth(id, raw, maximum)
    local a = self.actors[id]
    if not a then return end
    maximum = math.max(1, tonumber(maximum) or 3)
    local hearts = math.clamp(math.ceil(math.max(0, tonumber(raw) or 0) / maximum * 3), 0, 3)
    a.model:SetAttribute("Hearts", hearts)
    a.model:SetAttribute("HealthRaw", raw)
    a.model:SetAttribute("HealthMax", maximum)
    if a.healthLabel then
        local symbols = {}
        for n = 1, 3 do symbols[n] = n <= hearts and "♥" or "♡" end
        a.healthLabel.Text = (self.enemyKinds[id] == "Boss" and "СТРАЖ  ·  " or "") .. table.concat(symbols, " ")
    end
end

function World:stage(name)
    self.stageName = name
    self.folder:SetAttribute("Stage", name)
    local progress = ({Approach = 0, Courtyard = 1, BossReady = 1, Boss = 2, Exit = 3, Won = 3, Lost = -1})[name] or 0
    for index, gate in ipairs(self.gates) do
        local open = progress >= index
        gate.beam.CanCollide = not open
        gate.beam.Transparency = open and 1 or 0.63
        gate.marker.Color = open and COLORS.mint or COLORS.amber
        gate.marker.Transparency = open and 0.75 or 0
        gate.light.Color = gate.marker.Color
        gate.light.Brightness = open and 0.4 or 1.6
        gate.label.TextTransparency = open and 0.65 or 0
    end
    if name == "Exit" or name == "Won" then
        self.exitGate.label.Text = name == "Won" and "ТРАКТ ПРОЙДЕН!" or "ВЫХОД  →  ВСТАНЬТЕ НА ПЕЧАТЬ"
        self.exitGate.label.TextColor3 = COLORS.mint
        self.exitGate.label.TextTransparency = 0
    else
        self.exitGate.label.Text = "III  ·  СТРАЖ ПЕРЕПРАВЫ"
        self.exitGate.label.TextColor3 = Color3.fromRGB(226, 244, 211)
    end
    self.exitPad.Transparency = progress >= 3 and 0.12 or 0.78
end

function World:atExit(heroId)
    local a = self.actors[heroId]
    return a ~= nil and a.root.Parent ~= nil and a.humanoid.Health > 0
        and a.root.Position.X >= 108 and math.abs(a.root.Position.Z) <= 10
end

function World:projectile(id, positionTable, reflected)
    if type(id) ~= "number" or id > -1000 or not positionTable then return false end
    local p = Vector3.new(positionTable.x, positionTable.y, positionTable.z)
    local a = self.actors[id]
    if not a then
        local model = Instance.new("Model")
        model.Name = "BogBolt_" .. tostring(-id)
        local root = ball(model, "HumanoidRootPart", Vector3.new(1.55, 1.55, 1.55), CFrame.new(p), COLORS.amber, Enum.Material.Neon)
        root.CanQuery = false
        local halo = ball(model, "BoltAura", Vector3.new(2.1, 2.1, 2.1), CFrame.new(p), COLORS.amber, Enum.Material.ForceField)
        halo.Transparency = 0.55
        local humanoid = Instance.new("Humanoid")
        humanoid.Name = "Humanoid"
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
        humanoid.Parent = model
        model.PrimaryPart = root
        model:SetAttribute("ActorId", id)
        model:SetAttribute("Projectile", true)
        model.Parent = self.actorFolder
        a = {model = model, root = root, humanoid = humanoid, halo = halo, cue = 0}
        a.light = pointLight(root, COLORS.amber, 10, 1.2)
        self.actors[id] = a
    end
    local color = reflected and COLORS.mint or COLORS.amber
    a.root.CFrame = CFrame.new(p)
    a.halo.CFrame = CFrame.new(p)
    a.root.Color = color
    a.halo.Color = color
    a.light.Color = color
    a.model:SetAttribute("Reflected", reflected == true)
    return true
end

function World:removeProjectile(id)
    local a = self.actors[id]
    if a and id <= -1000 then
        a.model:Destroy()
        self.actors[id] = nil
    end
end

function World:updatePresentation(session, dt, enemies)
    dt = math.clamp(tonumber(dt) or 0, 0, 0.1)
    self.presentationTime = (self.presentationTime or 0) + dt
    local blend = 1 - math.exp(-dt * 18)
    for id, actor in pairs(self.actors) do
        if id > -1000 and actor.root.Parent and self.enemyKinds[id] ~= "Boss" then
            if not actor.poseMotors then
                actor.poseMotors = {}
                for _,joint in ipairs(actor.model:GetDescendants()) do
                    if joint:IsA("Motor6D") and (joint.Name == "Left Shoulder" or joint.Name == "Right Shoulder"
                        or joint.Name == "Left Hip" or joint.Name == "Right Hip") then
                        actor.poseMotors[joint.Name] = {joint = joint, base = joint.C0}
                    end
                end
            end
            local velocity = actor.root.AssemblyLinearVelocity
            local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
            local walking = not actor.root.Anchored and actor.humanoid.Health > 0
                and actor.humanoid.FloorMaterial ~= Enum.Material.Air
            actor.walkPhase = (actor.walkPhase or 0) + dt * math.min(speed, 20) * 0.8
            local stride = walking and math.sin(actor.walkPhase) * math.clamp(speed / 12, 0, 1) * 0.5 or 0
            local combat = session and session.combat and session.combat[id]
            local enemy = enemies and enemies[id]
            local attack = (combat and combat.attack) or (enemy and enemy.windup)
            if attack then
                actor.attackPoseUntil = self.presentationTime + 0.17
                actor.attackPoseAction = attack.action or 'Punch'
            end
            local attacking = actor.attackPoseUntil and self.presentationTime < actor.attackPoseUntil
            local reacting = (combat and combat.reactionEnd ~= nil) or (enemy and enemy.reactionUntil ~= nil)
            for name, motor in pairs(actor.poseMotors) do
                local shoulder = string.find(name, "Shoulder", 1, true) ~= nil
                local left = string.find(name, "Left", 1, true) ~= nil
                local angle = stride * (left and 1 or -1) * (shoulder and -1 or 1)
                local roll = 0
                if shoulder and reacting then
                    angle, roll = 0.65, left and -0.25 or 0.25
                elseif shoulder and attacking then
                    angle = actor.attackPoseAction == "Dash" and 1.5 or (left and 0.45 or 1.95)
                end
                motor.joint.C0 = motor.joint.C0:Lerp(motor.base * CFrame.Angles(angle, 0, roll), blend)
            end
        end
    end
end

function World:clearActors()
    self._base.clearActors(self)
    self.enemyKinds = {}
    self.origins = {
        [1] = Vector3.new(-65, 3, -7),
        [2] = Vector3.new(-65, 3, 0),
        [3] = Vector3.new(-65, 3, 7),
    }
    self:stage("Approach")
end

return World
