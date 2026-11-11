-- Original first-level presentation. Combat and hero physics stay in BaseWorld.
local World = {}

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local function ownCompletedRig(actor)
    local root=actor.root
    if root.Parent and not root.Anchored then
        local allowed,reason=root:CanSetNetworkOwnership()
        assert(allowed,reason or 'Cannot assign server ownership')
        root:SetNetworkOwner(nil)
    end
end

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
end

local function removeStandEyes(actor)
    -- The stand's small eye parts are also cosmetic and can be replaced safely.
    for _,p in ipairs(actor.model:GetChildren()) do
        if p.Name == "Eye" then p:Destroy() end
    end
end

local function toad(actor, template, appearance)
    removeStandEyes(actor)
    -- Canonical readiness uses the physical rig's original visible alpha.
    if appearance and appearance.attach(actor, template) then return end
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

local function drone(actor, kind)
    hideRig(actor)
    removeStandEyes(actor)
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
    -- Species silhouettes are original art; their shared combat remains prototype tuning.
    if kind == "Pig" then
        cosmetic(m, m.Head, "PigSnout", Vector3.new(1.5, 0.85, 1.1), CFrame.new(0, -0.05, -1), COLORS.rust, Enum.PartType.Ball)
        for _,side in ipairs({-1, 1}) do
            cosmetic(m, m.Head, "PigTusk", Vector3.new(0.22, 0.8, 0.25), CFrame.new(side * 0.66, -0.12, -1.35) * CFrame.Angles(0, 0, -side * 0.3), COLORS.pale)
            cosmetic(m, m.Head, "PigEar", Vector3.new(0.75, 0.8, 0.4), CFrame.new(side * 0.8, 0.85, 0), COLORS.rust)
        end
        cosmetic(m, m.Torso, "PigArmour", Vector3.new(2.85, 1.5, 1.7), CFrame.new(0, 0.1, 0.1), COLORS.rust, Enum.PartType.Ball)
    elseif kind == "Walker" then
        for _,side in ipairs({-1, 1}) do
            cosmetic(m, m.Torso, "WalkerShoulder", Vector3.new(1.25, 1.5, 1.7), CFrame.new(side * 1.65, 0.45, 0), COLORS.dark)
            cosmetic(m, m[side == -1 and "Left Leg" or "Right Leg"], "WalkerPiston", Vector3.new(0.9, 2.05, 0.9), CFrame.new(0, 0.1, 0.1), COLORS.amber)
        end
        cosmetic(m, m.Head, "WalkerCrest", Vector3.new(0.5, 1.5, 1.2), CFrame.new(0, 0.9, 0), COLORS.pale)
    elseif kind == "Dragon" then
        for _,side in ipairs({-1, 1}) do
            local offset=CFrame.new(side*2.3,.45,.45)*CFrame.Angles(0,0,side*.3)
            local wing=cosmetic(m,m.Torso,'DragonWing',Vector3.new(3.2,.28,2.1),offset,COLORS.moss)
            for _,joint in ipairs(wing:GetChildren()) do if joint:IsA('WeldConstraint') then joint:Destroy() end end
            local motor=Instance.new('Motor6D');motor.Name='DragonWingMotor';motor.Part0=m.Torso;motor.Part1=wing;motor.C0=offset;motor.Parent=wing
            actor.wingMotors=actor.wingMotors or {};actor.wingMotors[#actor.wingMotors+1]={joint=motor,base=offset,side=side}
            cosmetic(m, m.Head, "DragonHorn", Vector3.new(0.3, 1.4, 0.4), CFrame.new(side * 0.6, 0.9, 0.3) * CFrame.Angles(0.2, 0, -side * 0.2), COLORS.amber)
        end
        cosmetic(m, m.Torso, "DragonTail", Vector3.new(0.7, 0.65, 3.2), CFrame.new(0, -0.7, 2), COLORS.moss, Enum.PartType.Ball)
    end
end

local function boss(actor)
    hideRig(actor)
    removeStandEyes(actor)
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
    label(warning, "DANGEROUS MARSH", 160, Vector3.new(0, 2, 0)).TextColor3 = COLORS.amber

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
    label(start, "FLOODED CAUSEWAY", 310, Vector3.new(0, 2.8, 0)).TextSize = 23
    label(start, "FORWARD  →", 200, Vector3.new(0, 0.8, 0)).TextColor3 = COLORS.mint

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
    gate(2, "I  ·  CLEAR THE CAUSEWAY")
    gate(52, "II  ·  FLOODED COURTYARD")
    self.exitGate = gate(108, "III  ·  CAUSEWAY GUARDIAN")
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

local function gateState(gate, open)
    gate.beam.CanCollide = not open
    gate.beam.Transparency = open and 1 or 0.63
    gate.marker.Color = open and COLORS.mint or COLORS.amber
    gate.marker.Transparency = open and 0.75 or 0
    gate.light.Color, gate.light.Brightness = gate.marker.Color, open and 0.4 or 1.6
    gate.label.TextTransparency = open and 0.65 or 0
end

local function buildRoute(self, level)
    self.geometry:ClearAllChildren()
    self.allFloors, self.floors, self.gates = {}, {}, {}
    local g = self.geometry
    local function platform(data, zoneIndex, surfaceId)
        local p = part(g, "DistrictSupport", Vector3.new(data.w, data.h, data.d), CFrame.new(data.x, data.y, data.z),
            zoneIndex == 4 and COLORS.dark or COLORS.stone, Enum.Material.Slate, true)
        p:SetAttribute("SurfaceId", surfaceId)
        p:SetAttribute("ZoneIndex", zoneIndex)
        self.allFloors[#self.allFloors + 1] = p
        local top = data.y + data.h / 2
        -- Every paving stone belongs to one support; no decorative strip spans a gap.
        for x = data.x - data.w / 2 + 3.5, data.x + data.w / 2 - 3.5, 7 do
            for z = data.z - data.d / 2 + 3.5, data.z + data.d / 2 - 3.5, 7 do
                local tile = part(g, "RoutePaving", Vector3.new(6.5, 0.08, 6.5), CFrame.new(x, top + 0.04, z),
                    zoneIndex == 4 and COLORS.pale or Color3.fromRGB(91, 111, 103), Enum.Material.Slate)
                tile.Transparency = 0.28
            end
        end
        for _,side in ipairs({-1, 1}) do
            part(g, "PlatformEdge", Vector3.new(data.w, 0.18, 0.32), CFrame.new(data.x, top + 0.12, data.z + side * (data.d / 2 - 0.25)), COLORS.pale)
        end
        return top
    end
    local function gate(x, z, top, width, title)
        local beam = part(g, "DistrictGate", Vector3.new(0.7, 12, width + 8), CFrame.new(x, top + 6, z), COLORS.amber, Enum.Material.ForceField, true)
        local marker = ball(g, "DistrictBeacon", Vector3.new(1.7, 1.7, 1.7), CFrame.new(x, top + 14, z), COLORS.amber, Enum.Material.Neon)
        local result = {beam = beam, marker = marker, light = pointLight(marker, COLORS.amber, 20, 1.6),
            label = label(beam, title, 330, Vector3.new(0, 7.5, 0))}
        gateState(result, false)
        return result
    end
    for index, zone in ipairs(level.zones) do
        for _,data in ipairs(zone.platforms) do platform(data, index, zone.id) end
        for _,data in ipairs(zone.obstacles or {}) do
            if data.kind == 'StoneCover' then
                local cover = part(g, 'StoneCover', Vector3.new(data.w, data.h, data.d), CFrame.new(data.x, data.y, data.z), COLORS.stone, Enum.Material.Rock, true)
                -- A cover is physical support within its district, not a new
                -- respawn floor or an actor with its own life/ownership.
                cover:SetAttribute('SurfaceId', zone.id)
                cover:SetAttribute('ZoneIndex', index)
                part(g, 'CoverCrown', Vector3.new(data.w, .18, data.d), CFrame.new(data.x, data.y + data.h / 2, data.z), COLORS.pale, Enum.Material.Slate)
            end
        end
        local first, last = zone.platforms[1], zone.platforms[#zone.platforms]
        local x, y, z = first.x - first.w / 2 + 8, first.y + first.h / 2, first.z
        local sign = part(g, "DistrictSign", Vector3.new(0.8, 6, 0.8), CFrame.new(x, y + 3, z - first.d / 2 - 2), COLORS.dark, Enum.Material.Wood)
        label(sign, tostring(index) .. "  ·  " .. string.upper(zone.name), 350, Vector3.new(0, 5, 0)).TextSize = 21
        -- Large silhouettes identify districts from the moving camera without blocking jumps.
        for _,side in ipairs({-1, 1}) do
            local depth = z + side * (first.d / 2 + 4)
            if index == 1 or index == 2 then
                part(g, "AqueductTower", Vector3.new(5, 19 + index * 2, 5), CFrame.new(x + 13, y + 8, depth), COLORS.dark, Enum.Material.Rock)
                part(g, "TowerCrown", Vector3.new(8, 2, 8), CFrame.new(x + 13, y + 19, depth), COLORS.pale, Enum.Material.Slate)
            elseif index == 3 then
                local bowl = ball(g, "CourtyardBrazier", Vector3.new(4, 3, 4), CFrame.new(x + 24, y + 4, depth), COLORS.rust)
                ball(g, "BrazierGlow", Vector3.new(2, 3, 2), CFrame.new(x + 24, y + 6, depth), COLORS.amber, Enum.Material.Neon)
                pointLight(bowl, COLORS.amber, 22, 2)
            elseif index == 4 then
                part(g, "CliffNeedle", Vector3.new(6, 26, 7), CFrame.new(x + 11, y - 8, depth), COLORS.dark, Enum.Material.Rock)
                ball(g, "CliffMoss", Vector3.new(8, 3, 9), CFrame.new(x + 11, y + 5, depth), COLORS.moss, Enum.Material.Grass)
            elseif index == 5 then
                part(g, "ForgeChimney", Vector3.new(5, 24, 5), CFrame.new(x + 21, y + 10, depth), COLORS.rust, Enum.Material.Metal)
                local glow = part(g, "ForgeWindow", Vector3.new(3, 4, 0.3), CFrame.new(x + 21, y + 6, depth - side * 2.7), COLORS.amber, Enum.Material.Neon)
                pointLight(glow, COLORS.amber, 18, 1.8)
            else
                part(g, "BridgePylon", Vector3.new(3.5, 23, 4), CFrame.new(x + 15, y + 8, depth), COLORS.pale, Enum.Material.Slate)
                part(g, "BridgeBrace", Vector3.new(9, 2, 3), CFrame.new(x + 15, y + 19, depth), COLORS.dark)
            end
        end
        for _,gap in ipairs(zone.gaps or {}) do
            -- Marks stay entirely on the takeoff/landing edges, outside the empty air.
            local left, right = gap.minX, gap.maxX
            local before, after
            for _,data in ipairs(zone.platforms) do
                if math.abs(data.x + data.w / 2 - left) < .01 then before = data end
                if math.abs(data.x - data.w / 2 - right) < .01 then after = data end
            end
            for _,edge in ipairs({{x = left - .35, data = before}, {x = right + .35, data = after}}) do
                local data = edge.data
                if data then
                    local top = data.y + data.h / 2
                    part(g, "JumpEdge", Vector3.new(.45, .13, data.d - 1), CFrame.new(edge.x, top + .12, data.z), COLORS.amber, Enum.Material.Neon)
                    local marker = part(g, "JumpMarker", Vector3.new(1, .1, 1), CFrame.new(edge.x - 1, top + .15, data.z), COLORS.mint, Enum.Material.Neon)
                    label(marker, "JUMP  →", 210, Vector3.new(0, 3.2, 0)).TextColor3 = COLORS.amber
                end
            end
        end
        self.gates[index] = gate(zone.gateX, last.z, last.y + last.h / 2, last.d, tostring(index) .. "  ·  " .. zone.name)
    end
    local boss = level.boss
    platform(boss.platform, #level.zones + 1, "GuardianCourt")
    local bossTop = boss.platform.y + boss.platform.h / 2
    self.exitGate = gate(boss.gateX, boss.platform.z, bossTop, boss.platform.d, "CAUSEWAY GUARDIAN")
    self.exitPad = part(g, "ExitPad", Vector3.new(boss.pad.w, .13, boss.pad.d), CFrame.new(boss.pad.x, boss.pad.y, boss.pad.z), COLORS.mint, Enum.Material.Neon)
    self.exitPad.Transparency = .78
    for _,side in ipairs({-1, 1}) do
        local z = boss.platform.z + side * (boss.platform.d / 2 + 3)
        part(g, "GuardianObelisk", Vector3.new(5, 27, 5), CFrame.new(boss.position.x + 5, bossTop + 11, z), COLORS.dark, Enum.Material.Rock)
        local light = ball(g, "GuardianSigil", Vector3.new(3, 3, 3), CFrame.new(boss.position.x + 5, bossTop + 23, z), COLORS.mint, Enum.Material.Neon)
        pointLight(light, COLORS.mint, 24, 2)
    end
    local bounds = level.bounds
    local marsh = part(g, "RouteMarsh", Vector3.new(bounds.maxX - bounds.minX + 100, .4, bounds.maxZ - bounds.minZ + 60),
        CFrame.new((bounds.minX + bounds.maxX) / 2, -9, (bounds.minZ + bounds.maxZ) / 2), Color3.fromRGB(34, 101, 96), Enum.Material.Glass)
    marsh.Transparency, marsh.Reflectance = .34, .25
    local depth = part(g, "MarshDepth", Vector3.new(bounds.maxX - bounds.minX + 100, 9, bounds.maxZ - bounds.minZ + 60),
        CFrame.new((bounds.minX + bounds.maxX) / 2, -15, (bounds.minZ + bounds.maxZ) / 2), COLORS.dark)
    depth.Transparency = .22
    self:progress(1, false)
end

local function resetOrigins(self)
    local route=self.config.Level
    if route and route.campaignIndex and route.campaignIndex>1 then
        self.origins={}
        for slot=1,3 do
            local p=route.spawns and route.spawns[slot] or route.spawn or {x=0,y=3,z=0}
            self.origins[slot]=Vector3.new(p.x,p.y,p.z+(route.spawns and 0 or (slot-2)*6))+self.offset
        end
        return
    end
    local first = self.config.Level and self.config.Level.zones[1].platforms[1]
    local y, z = first and first.y + first.h / 2 + 3 or 3, first and first.z or 0
    self.origins = {
        [1] = Vector3.new(-65, y, z - 7) + self.offset,
        [2] = Vector3.new(-65, y, z) + self.offset,
        [3] = Vector3.new(-65, y, z + 7) + self.offset,
    }
end

local function translateGeometry(self)
    for _,object in ipairs(self.geometry:GetDescendants()) do
        if object:IsA('BasePart') then object.CFrame += self.offset end
    end
end

local function layoutAttributes(self)
    local variation = self.config.Level and self.config.Level.variation
    self.folder:SetAttribute('LayoutSeed', variation and variation.seed)
    self.folder:SetAttribute('LayoutVersion', variation and variation.version)
end

local function buildLevelGeometry(self,route)
    if self.campaignWorld then self.campaignWorld:close();self.campaignWorld=nil end
    if route and route.campaignIndex and route.campaignIndex>1 then
        assert(self.campaignWorldType,'Campaign world adapter is required')
        self.campaignWorld=self.campaignWorldType.new(self,route)
    else
        if self.baseFallY then self.config.FallY=self.baseFallY end
        if route then buildRoute(self,route) else buildGeometry(self) end
        translateGeometry(self)
    end
end

function World.new(BaseWorld, config, options)
    options = options or {}
    local worldName = options.name or "BrickToadsWorld"
    local offset = options.offset or {}
    local translation = Vector3.new(offset.x or 0, offset.y or 0, offset.z or 0)
    -- A newly created group must never replace an existing group's physical world.
    assert(not Workspace:FindFirstChild(worldName), "World already exists: " .. worldName)
    -- Remove only the untouched blank-place defaults in this playable runtime.
    for _,object in ipairs(Workspace:GetChildren()) do
        if (object.Name == "Baseplate" and object:IsA("BasePart"))
            or (object.Name == "SpawnLocation" and object:IsA("SpawnLocation")) then
            object:Destroy()
        end
    end
    local worldConfig = table.clone(config)
    worldConfig.FallY = config.FallY + translation.Y
    local self = BaseWorld.new(worldConfig)
    self.baseFallY=worldConfig.FallY
    self._base = BaseWorld
    self.characterAppearance = options.characterAppearance
    self.guardianAppearance = options.guardianAppearance
    self.castAppearance = options.castAppearance
    self.campaignWorldType = options.campaignWorld
    self.offset = translation
    setmetatable(self, {__index = function(_, key) return World[key] or BaseWorld[key] end})
    self.folder.Name = worldName
    self.folder:SetAttribute("LevelName", "Flooded Causeway")
    self.folder:SetAttribute("OriginalArt", true)
    self.enemyKinds = {}
    self.healingFlyFolder = Instance.new("Folder")
    self.healingFlyFolder.Name = "HealingFlies"
    self.healingFlyFolder.Parent = self.folder
    self.healingEffectFolder = Instance.new("Folder")
    self.healingEffectFolder.Name = "HealingEffects"
    self.healingEffectFolder.Parent = self.folder
    self.healingFlyVisuals, self.healingEffects = {}, {}
    self.enemyCarries = {}
    self.clubItemFolder = Instance.new('Folder')
    self.clubItemFolder.Name = 'ClubItems'
    self.clubItemFolder.Parent = self.folder
    self.clubItems, self.equippedClubs = {}, {}
    resetOrigins(self)
    buildLevelGeometry(self,config.Level)
    layoutAttributes(self)
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

function World:rebuildLevel(route)
    -- The caller must finish the old run's cleanup before any geometry or
    -- configuration changes; even a dead body still belongs to that old run.
    if next(self.actors) ~= nil then return false, 'ACTORS_PRESENT' end
    assert(type(route) == 'table' and type(route.zones) == 'table' and route.zones[1]
        and route.boss and route.bounds, 'A complete level route is required')
    self.config.Level = route
    self.blocked = false
    self.lastSupport, self.deathReason = {}, {}
    buildLevelGeometry(self,route)
    resetOrigins(self)
    layoutAttributes(self)
    self:stage('Approach')
    return true
end

function World:advanceGeometry(route)
    assert(type(route)=='table' and route.zones and route.boss and route.bounds,'A complete campaign route is required')
    if self.campaignModes then self.campaignModes:close('LevelTransition');self.campaignModes=nil end
    local remove={}
    for id,actor in pairs(self.actors) do
        if id<0 then remove[#remove+1]=id
        else
            self:campaignRelease(id)
            if actor.humanoid.Health>0 then self:hold(id,true) end
            self:resetLocomotion(id)
        end
    end
    for _,id in ipairs(remove) do
        local actor=self.actors[id]
        if self.guardianAppearance then self.guardianAppearance.detach(actor) end
        actor.model:Destroy();self.actors[id]=nil
    end
    for id in pairs(self.equippedClubs) do self:unequipClub(id) end
    self.healingFlyFolder:ClearAllChildren();self.healingEffectFolder:ClearAllChildren()
    self.clubItemFolder:ClearAllChildren()
    self.healingFlyVisuals,self.healingEffects,self.clubItems,self.equippedClubs={},{},{},{}
    self.enemyCarries={};self.enemyKinds={}
    self.config.Level=route;self.config.Calibration=route.calibration or self.config.Calibration
    self.blocked=false;self.lastSupport={};self.deathReason={}
    buildLevelGeometry(self,route);resetOrigins(self);layoutAttributes(self)
    self.transitionOrigins=table.clone(self.origins)
    self:stage(route.mode or 'Approach')
    return true
end

function World:finishLevelTransition()
    self.transitionOrigins=nil
    for id,actor in pairs(self.actors) do
        if id>0 and actor.humanoid.Health>0 then self:hold(id,false) end
    end
end

function World:campaignPose(id,point,mode,velocity,heading)
    local actor=self.actors[id]
    if not actor or not actor.root.Parent or actor.humanoid.Health<=0 then return false end
    actor.campaignControl=true
    actor.campaignVelocity=velocity and Vector3.new(velocity.x or 0,velocity.y or 0,velocity.z or 0) or Vector3.new()
    actor.root.Anchored=true
    actor.humanoid.AutoRotate=false
    local position=Vector3.new(point.x,point.y,point.z)+self.offset
    local direction=velocity and Vector3.new(velocity.x or 0,0,velocity.z or 0)
    if mode=='Clinger'and type(heading)=='table'then
        local x,z=heading.x,heading.z
        if type(x)=='number'and type(z)=='number'and x==x and z==z and math.abs(x)<=1 and math.abs(z)<=1 then
            local facing=Vector3.new(x,0,z)
            if facing.Magnitude>.001 then direction=facing end
        end
    end
    if not direction or direction.Magnitude<.001 then direction=actor.root.CFrame.LookVector end
    actor.model:PivotTo(CFrame.lookAt(position,position+direction))
    actor.root.AssemblyLinearVelocity=Vector3.new()
    actor.root.AssemblyAngularVelocity=Vector3.new()
    actor.model:SetAttribute('CampaignMode',mode)
    return true
end

function World:campaignRelease(id)
    local actor=self.actors[id]
    if not actor or not actor.campaignControl then return end
    actor.campaignControl=nil
    actor.campaignVelocity=nil
    actor.model:SetAttribute('CampaignMode',nil)
    actor.root.Anchored=false
    actor.humanoid.AutoRotate=true
    actor.humanoid.PlatformStand=false
    ownCompletedRig(actor)
end

function World:placeActor(id,point)
    local actor=self.actors[id]
    if not actor or not actor.root.Parent or actor.humanoid.Health<=0 then return false end
    local p=Vector3.new(point.x,point.y,point.z)+self.offset
    actor.model:PivotTo(CFrame.lookAt(p,p+actor.root.CFrame.LookVector))
    actor.root.AssemblyLinearVelocity=Vector3.new()
    actor.root.AssemblyAngularVelocity=Vector3.new()
    return true
end

function World:campaignGrounded(id)
    local actor=self.actors[id]
    if not actor or not actor.root.Parent then return false end
    local p=actor.root.Position
    local hit=Workspace:Raycast(p,Vector3.new(0,-3.7,0),self.ray)
    return hit~=nil and hit.Normal.Y>.8 and not hit.Instance:GetAttribute('Hazard')
end

function World:campaignObject(id,kind,point,size,metadata)
    if self.campaignWorld then return self.campaignWorld:object(id,kind,point,size,metadata) end
end

function World:campaignRemove(id)
    if self.campaignWorld then self.campaignWorld:remove(id) end
end

function World:campaignStage(mode,detail)
    self.folder:SetAttribute('CampaignMode',mode)
    self.folder:SetAttribute('CampaignDetail',detail)
end

function World:campaignImpulse(id,velocity)
    local actor=self.actors[id]
    if not actor or actor.root.Anchored or actor.humanoid.Health<=0 then return end
    actor.root.AssemblyLinearVelocity=Vector3.new(velocity.x or 0,velocity.y or 0,velocity.z or 0)
end

function World:campaignWalkSpeed(id,speed)
    if type(speed)~='number' or speed~=speed or speed<0 or speed>40 then return false end
    local actor=self.actors[id]
    if not actor then return false end
    actor.campaignWalkSpeed=speed
    if actor.locomotion then
        actor.locomotion.walkSpeed=speed
        if actor.locomotion.airSpeed~=nil then actor.locomotion.airSpeed=speed end
        if speed==0 then actor.locomotion.runRequested=false;actor.locomotion.groundRun=false end
    end
    if not actor.humanoid.PlatformStand then actor.humanoid.WalkSpeed=speed end
    return true
end

function World:courseRival(id,title)
    local actor=self.actors[id]
    if not actor then return end
    actor.model:SetAttribute('ResourceKind','CourseRival')
    actor.model:SetAttribute('Hearts',nil)
    local head=actor.model:FindFirstChild('Head')
    local torso=actor.model:FindFirstChild('Torso')
    if head then head.CanCollide=false end
    if torso then torso.Size=Vector3.new(2,2,2) end
    if actor.healthLabel then actor.healthLabel.Text=title or 'RACING RAT' end
end

function World:campaignClaw(id,equipped)
    local actor=self.actors[id]
    if not actor or not actor.root.Parent then return end
    local prior=actor.model:FindFirstChild('CampaignRavenClaw')
    if prior and not equipped then prior:Destroy();ownCompletedRig(actor);return end
    if prior or not equipped then return end
    local hand=actor.model:FindFirstChild('Right Arm')
    if not hand then return end
    local claw=part(actor.model,'CampaignRavenClaw',Vector3.new(.35,.35,3.8),hand.CFrame,Color3.fromRGB(230,218,176))
    claw.Anchored=false;claw.Massless=true;claw.CanQuery=false
    local joint=Instance.new('Motor6D');joint.Name='RavenClawGrip';joint.Part0=hand;joint.Part1=claw
    joint.C0=CFrame.new(0,-1.1,-1.3)*CFrame.Angles(.2,0,.15);joint.C1=CFrame.new();joint.Parent=claw
    ownCompletedRig(actor)
end

function World:campaignProjectileBlocked(from,to,radius)
    local origin=Vector3.new(from.x,from.y,from.z)+self.offset
    local destination=Vector3.new(to.x,to.y,to.z)+self.offset
    local delta=destination-origin
    if delta.Magnitude<.001 then return false end
    radius=radius or .6
    local overlaps=OverlapParams.new()
    overlaps.FilterType=Enum.RaycastFilterType.Include
    overlaps.FilterDescendantsInstances={self.geometry}
    overlaps.RespectCanCollide=true
    for _,p in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(origin),Vector3.new(radius*2,radius*2,radius*2),overlaps)) do
        if p.CanCollide then return true end
    end
    local hit=Workspace:Spherecast(origin,radius,delta,self.ray)
    return hit~=nil
end

function World:impulse(id,attacker,tuning,profile,impulseDirection)
    local actor=self.actors[id]
    if self.campaignModes and self.campaignModes.impulse and actor and actor.campaignControl then
        local direction
        if type(impulseDirection)=='table' and type(impulseDirection.x)=='number' and type(impulseDirection.z)=='number'
            and impulseDirection.x==impulseDirection.x and impulseDirection.z==impulseDirection.z
            and math.abs(impulseDirection.x)<math.huge and math.abs(impulseDirection.z)<math.huge then
            local scale=math.max(math.abs(impulseDirection.x),math.abs(impulseDirection.z))
            if scale>0 then direction=Vector3.new(impulseDirection.x/scale,0,impulseDirection.z/scale).Unit end
        end
        local source=self.actors[attacker]
        if not direction and source then
            local look=source.root.CFrame.LookVector
            direction=Vector3.new(look.X,0,look.Z)
            direction=direction.Magnitude>.001 and direction.Unit or Vector3.new(1,0,0)
        end
        if direction and self.campaignModes:impulse(id,{x=direction.X*tuning.horizontal,
            y=tuning.vertical,z=direction.Z*tuning.horizontal}) then return end
    end
    return self._base.impulse(self,id,attacker,tuning,profile,impulseDirection)
end

function World:bossTell(kind,point,radius,untilAt)
    if self.campaignWorld then
        local id='tell:'..kind..':'..tostring(untilAt)..':'..tostring(math.floor(point.x*2))..':'..tostring(math.floor(point.z*2))
        local floor={x=point.x,y=point.y-2.9,z=point.z}
        self.campaignWorld:object(id,'Telegraph',floor,{x=radius*2,y=.12,z=radius*2},
            {label='DODGE',alpha=.35,expiresAt=untilAt})
    end
end

function World:findSafe(uid)
    local target=self.transitionOrigins and self.transitionOrigins[uid]
    if not target and self.campaignModes and self.campaignModes.respawnPosition then
        local localPoint=self.campaignModes:respawnPosition(uid)
        if localPoint then target=Vector3.new(localPoint.x,localPoint.y,localPoint.z)+self.offset end
    end
    if not target then return self._base.findSafe(self,uid) end
    -- Only substitute the search origin; collision still excludes the real body.
    local actual=self.actors[uid]
    self.actors[uid]={root={Parent=true,Position=target},model=actual and actual.model}
    local ok,result=pcall(self._base.findSafe,self,uid)
    self.actors[uid]=actual
    if not ok then error(result) end
    return result
end

function World:spawn(uid, actorId, point, held, template)
    local previous=self.actors[uid]
    if not self.origins[uid] and uid > 0 then self.origins[uid] = Vector3.new(-65, 3, (uid - 2) * 7) + self.offset end
    local ok = self._base.spawn(self, uid, actorId, point, held, template or "Mr. Green")
    if ok then
        if previous then self:resetLocomotion(uid,previous) end
        -- BaseWorld places a spawn without a safe point at absolute Y=3.
        -- Keep that emergency-spawn rule relative to this arena's elevation.
        if not point and self.offset.Y ~= 0 then
            local actor = self.actors[uid]
            local p = Vector3.new(actor.root.Position.X, 3 + self.offset.Y, actor.root.Position.Z)
            actor.model:PivotTo(CFrame.lookAt(p, p + Vector3.new(1, 0, 0)))
            self.origins[uid] = p
        end
        self.actors[uid].model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        toad(self.actors[uid], template or "Mr. Green", self.characterAppearance)
        ownCompletedRig(self.actors[uid])
        local actor=self.actors[uid]
        actor.humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        local ownerName=label(actor.root,actor.humanoid.DisplayName,220,Vector3.new(0,4.2,0))
        ownerName.AutoLocalize=false;ownerName.Parent.AutoLocalize=false
        ownerName.TextSize=14
        ownerName.Parent.Name='OwnerNameplate'
    end
    return ok
end

function World:spawnEnemy(id, kind, positionTable)
    if type(id) ~= "number" or id >= 0 or id <= -1000 or not positionTable then return false end
    local x, y, z = positionTable.x, positionTable.y, positionTable.z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return false end
    local campaignBoss=self.campaignWorldType and self.campaignWorldType.bossNames[kind]
    local isBoss = string.lower(tostring(kind)) == "boss" or campaignBoss~=nil
    local position = Vector3.new(x, y, z) + self.offset
    self.origins[id] = position
    local speciesNames = {Pig = "Armored Boar", Walker = "Walking Guard", Dragon = "Winged Guard"}
    self.names[id] = campaignBoss or (isBoss and "Causeway Guardian" or speciesNames[kind]
        or (kind and (kind:gsub('(%l)(%u)','%1 %2'))) or "Rusty Guard")
    local previous=self.actors[id]
    if not self._base.spawn(self, id, id, nil, false, "Mr. Brown") then return false end
    if previous and self.guardianAppearance then self.guardianAppearance.detach(previous) end
    if previous then self:resetLocomotion(id,previous) end
    local actor = self.actors[id]
    actor.model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    -- BaseWorld's ordinary spawn is deliberately y=3, so preserve the supplied
    -- translated position explicitly for local project/director callers.
    actor.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(-1, 0, 0)))
    self.origins[id] = position
    actor.model:SetAttribute("EnemyKind", kind)
    actor.model:SetAttribute("Template", nil)
    actor.model:SetAttribute("Slot", nil)
    actor.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    actor.humanoid.WalkSpeed = isBoss and 0 or 8
    self.enemyKinds[id] = isBoss and "Boss" or "Drone"
    actor.castRequestedKind=kind~='Boss' and kind or nil
    local importedCast=self.castAppearance and actor.castRequestedKind and self.castAppearance.attach(actor,kind)
    if importedCast then
        actor.model:SetAttribute('BossKind',campaignBoss and kind or nil)
    elseif self.campaignWorld and self.campaignWorldType.decorateActor and (campaignBoss or not speciesNames[kind]) then
        self.campaignWorldType.decorateActor(actor,kind)
        actor.model:SetAttribute('BossKind',campaignBoss and kind or nil)
    elseif isBoss then
        local imported=self.guardianAppearance and self.guardianAppearance.attach(actor)
        if not imported then boss(actor) end
    else drone(actor, kind) end
    actor.healthLabel = label(actor.root, "♥ ♥ ♥", isBoss and 270 or 160, Vector3.new(0, isBoss and 7.6 or 4.5, 0))
    actor.healthLabel.TextColor3 = isBoss and COLORS.amber or Color3.fromRGB(255, 164, 139)
    self:enemyHealth(id, 3, 3)
    -- The species art changes the assembly after BaseWorld pinned its basic rig.
    ownCompletedRig(actor)
    return true
end

function World:position(id)
    local a = self.actors[id]
    if not a or not a.root.Parent then return nil end
    local p = a.root.Position - self.offset
    return {x = p.X, y = p.Y, z = p.Z}
end

function World:cameraBounds()
    if self.campaignWorld then
        local b=self.config.Level.bounds
        return {minX=b.minX+self.offset.X,maxX=b.maxX+self.offset.X,
            minY=(b.minY or -40)+self.offset.Y,maxY=(b.maxY or 180)+self.offset.Y,
            minZ=b.minZ+self.offset.Z,maxZ=b.maxZ+self.offset.Z}
    end
    local minX,maxX,minZ,maxZ,top,bottom=math.huge,-math.huge,math.huge,-math.huge,-math.huge,math.huge
    for _,floor in ipairs(self.allFloors or self.floors) do
        minX=math.min(minX,floor.Position.X-floor.Size.X/2)
        maxX=math.max(maxX,floor.Position.X+floor.Size.X/2)
        minZ=math.min(minZ,floor.Position.Z-floor.Size.Z/2)
        maxZ=math.max(maxZ,floor.Position.Z+floor.Size.Z/2)
        top=math.max(top,floor.Position.Y+floor.Size.Y/2)
        bottom=math.min(bottom,floor.Position.Y+floor.Size.Y/2)
    end
    assert(minX<maxX and minZ<maxZ,'The current level has no camera bounds')
    if self.config.Level then
        local bounds=self.config.Level.bounds
        return {minX=bounds.minX+self.offset.X,maxX=bounds.maxX+self.offset.X,minY=bottom+7,maxY=top+52,
            minZ=bounds.minZ+self.offset.Z,maxZ=bounds.maxZ+self.offset.Z}
    end
    return {minX=minX-12,maxX=maxX+12,minY=top+7,maxY=top+52,minZ=minZ-28,maxZ=maxZ+28}
end

function World:enemyIdentity(id,actorId,ownerName)
    local actor=self.actors[id]
    if not actor or (self.enemyKinds[id]~='Drone' and self.enemyKinds[id]~='Boss') then return end
    -- A logical player role still uses server-driven Humanoid movement.
    ownCompletedRig(actor)
    actor.model:SetAttribute('ActorId',actorId)
    actor.model:SetAttribute('ControlledByPlayer',ownerName~=nil)
    if ownerName then
        local board=actor.root:FindFirstChild('OwnerNameplate')
        if board then board.Text.Text=ownerName
        else
            local text=label(actor.root,ownerName,220,Vector3.new(0,self.enemyKinds[id]=='Boss' and 10.2 or 5.7,0))
            text.AutoLocalize=false;text.Parent.AutoLocalize=false
            text.TextSize=14; text.TextColor3=COLORS.amber; text.Parent.Name='OwnerNameplate'
        end
    end
end

-- Modern route jump grace uses only this body's server-observed support. A
-- delayed packet may arrive just beyond an edge while its client still sees floor.
local function jumpSupportAt(world,position)
    local hit=Workspace:Raycast(position,Vector3.new(0,-3.4,0),world.ray)
    return hit~=nil and hit.Normal.Y>=.95 and not hit.Instance:GetAttribute('Hazard')
        and hit.Instance:GetAttribute('SurfaceId')~=nil
end

local function hasJumpSupport(world,root)
    if jumpSupportAt(world,root.Position) then return true end
    -- This rig's root and physical torso have the same footprint. Its centre
    -- can pass an edge while the body still stands on it; cosmetic art must
    -- never enlarge the physical support test. Project the actual oriented
    -- half-extents horizontally, without adding a support margin.
    local cf,size=root.CFrame,root.Size
    local right=Vector3.new(cf.RightVector.X,0,cf.RightVector.Z)*(size.X/2)
    local forward=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z)*(size.Z/2)
    for _,offset in ipairs({forward,-forward,right,-right,
        right+forward,right-forward,-right+forward,-right-forward}) do
        if jumpSupportAt(world,root.Position+offset) then return true end
    end
    return false
end

local function sampleJumpSupport(world,actor,now)
    local root,humanoid=actor.root,actor.humanoid
    local state=actor.routeJumpSupport
    if not state then state={consumed=false}; actor.routeJumpSupport=state end
    local velocity=root.AssemblyLinearVelocity
    local grounded=false
    if humanoid.FloorMaterial~=Enum.Material.Air and velocity.Y<=1 then
        grounded=hasJumpSupport(world,root)
    end
    if state.consumed then
        -- FloorMaterial can retain its old value until the next physics step.
        -- A jump is rearmed only after observed upward flight and a real landing.
        if humanoid.FloorMaterial==Enum.Material.Air and
            (velocity.Y>1 or root.Position.Y>(state.launchY or root.Position.Y)+.1) then state.airborne=true end
        if grounded and state.airborne then state.consumed=false; state.airborne=false end
    end
    if grounded and not state.consumed then state.groundedAt=now; state.groundedY=root.Position.Y end
    return state,grounded
end

local function locomotionWalkSpeed(world,id)
    local actor=world.actors[id]
    if actor and actor.campaignWalkSpeed~=nil then return actor.campaignWalkSpeed end
    if world.enemyKinds[id]=='Boss' then return 0 end
    return world.enemyKinds[id]=='Drone' and world.config.Enemy.speed or world.config.WalkSpeed
end

local function locomotionRunSpeed(world,id)
    local actor=world.actors[id]
    if actor and actor.campaignWalkSpeed~=nil then return actor.campaignWalkSpeed end
    return world.enemyKinds[id]=='Drone' and world.config.Movement.enemyRunSpeed or world.config.Movement.heroRunSpeed
end

local function locomotionCanRun(world,id,a)
    return a and a.root.Parent and a.humanoid.Health>0 and not a.root.Anchored and not a.humanoid.PlatformStand
        and world.enemyKinds[id]~='Boss' and id>-1000 and not world.enemyCarries[id]
        and not (world.dragonLinks and world.dragonLinks[id]) and not (world.dragonFlights and world.dragonFlights[id])
        and not a.model:GetAttribute('DragonLink') and not a.model:GetAttribute('DragonFlight')
        and a.model:GetAttribute('EnemyKind')~='Dragon' and not a.model:GetAttribute('CarryingEnemy')
end

local function locomotionGrounded(world,a)
    return a.humanoid.FloorMaterial~=Enum.Material.Air and a.root.AssemblyLinearVelocity.Y<=1
        and hasJumpSupport(world,a.root)
end

local function locomotionFresh(world,row)
    return row and row.at and Workspace:GetServerTimeNow()<row.at+(world.config.MoveTimeout or .35)
end

local function locomotionQualifies(world,id,a,row)
    if not row or not row.runRequested or row.airSpeed or not locomotionFresh(world,row)
        or not locomotionCanRun(world,id,a) or not locomotionGrounded(world,a) then return false end
    local v=a.root.AssemblyLinearVelocity
    return v.X*row.x+v.Z*row.z>=locomotionRunSpeed(world,id)*world.config.Movement.runThresholdRatio
end

function World:resetLocomotion(id,actorReference)
    if not self.config.Movement then return end
    local a=actorReference or self.actors[id]
    if not a then return end
    local walk=a.locomotion and a.locomotion.walkSpeed or locomotionWalkSpeed(self,id)
    a.locomotion=nil
    a.model:SetAttribute('MovementMode','Idle')
    if a.root.Parent then
        a.humanoid:Move(Vector3.new(),false)
        a.humanoid.WalkSpeed=a.humanoid.PlatformStand and 0 or walk
    end
end

function World:isRunning(id)
    local modeActor=self.campaignModes and self.campaignModes.actors and self.campaignModes.actors[id]
    local body=self.actors[id]
    if body and body.campaignControl and modeActor then
        if self.campaignModes.isRunning then return self.campaignModes:isRunning(id) end
        local mode=self.campaignModes.mode
        if mode=='Rope' or modeActor.mounted or modeActor.medium=='Water' or modeActor.finished
            or not modeActor.grounded or not modeActor.input.run then return false end
        local v=modeActor.velocity
        local cap=self.config.Movement and self.config.Movement.heroRunSpeed or 24
        return v.x*v.x+v.z*v.z>=(cap*.75)^2
    end
    if not self.config.Movement then return false end
    local a=self.actors[id]
    return a~=nil and locomotionQualifies(self,id,a,a.locomotion) or false
end

function World:movementMode(id)
    local modeActor=self.campaignModes and self.campaignModes.actors and self.campaignModes.actors[id]
    local controlled=self.actors[id]
    if controlled and controlled.campaignControl and modeActor then
        if modeActor.medium=='Water' then return 'Swim' end
        if self.campaignModes.mode=='Rope' then return 'Rope' end
        if self.campaignModes.mode=='Clinger'and not modeActor.finished then return 'Ride' end
        if modeActor.mounted then return 'Ride' end
        if not modeActor.grounded then return 'Air' end
        if self:isRunning(id) then return 'Run' end
        return modeActor.velocity.x^2+modeActor.velocity.z^2>1 and 'Walk' or 'Idle'
    end
    local a=self.actors[id]
    if not a or not a.root.Parent or a.humanoid.Health<=0 or a.root.Anchored or a.humanoid.PlatformStand then return 'Idle' end
    if not self.config.Movement then return 'Idle' end
    local row=a.locomotion
    if not locomotionGrounded(self,a) or (row and row.airSpeed) then return 'Air' end
    if self:isRunning(id) then return 'Run' end
    if locomotionFresh(self,row) then
        local v=a.root.AssemblyLinearVelocity
        if v.X*row.x+v.Z*row.z>0 then return 'Walk' end
    end
    return 'Idle'
end

function World:move(id,x,z,runRequested)
    if self.campaignModes and self.campaignModes:move(id,x,z,runRequested) then return end
    if self.enemyCarries[id] then return end
    local a=self.actors[id]
    if not self.config.Movement then
        if a and a.campaignWalkSpeed~=nil and not a.humanoid.PlatformStand then a.humanoid.WalkSpeed=a.campaignWalkSpeed
        elseif a and self.enemyKinds[id]=='Drone' and not a.humanoid.PlatformStand then a.humanoid.WalkSpeed=self.config.Enemy.speed end
        return self._base.move(self,id,x,z)
    end
    if not a or not a.root.Parent or a.humanoid.Health<=0 or a.root.Anchored or a.humanoid.PlatformStand then
        self:resetLocomotion(id);return
    end
    local length=math.sqrt(x*x+z*z)
    if length>1 then x,z=x/length,z/length end
    local row=a.locomotion or {walkSpeed=locomotionWalkSpeed(self,id)}
    a.locomotion=row
    local grounded=locomotionGrounded(self,a)
    if row.airSpeed and grounded and not (a.routeJumpSupport and a.routeJumpSupport.consumed) then row.airSpeed=nil end
    if not grounded and not row.airSpeed then row.airSpeed=row.groundRun and locomotionRunSpeed(self,id) or row.walkSpeed end
    row.x,row.z=x,z
    row.runRequested=runRequested==true and length>0 and locomotionCanRun(self,id,a) or false
    row.at=length>0 and Workspace:GetServerTimeNow() or nil
    a.humanoid.WalkSpeed=row.airSpeed or (row.runRequested and locomotionRunSpeed(self,id) or row.walkSpeed)
    self._base.move(self,id,x,z)
    row.groundRun=locomotionQualifies(self,id,a,row)
    a.model:SetAttribute('MovementMode',self:movementMode(id))
end

function World:hazard(id)
    local controlled=self.actors[id]
    if controlled and controlled.campaignControl and controlled.root.Parent and controlled.humanoid.Health>0 then
        -- The mode owns rope/vehicle/swim coordinates and its swept hazards.
        -- The first route's absolute fall plane is unrelated to that space.
        return nil
    end
    local reason=self._base.hazard(self,id)
    if not self.config.Level then return reason end
    local actor=self.actors[id]
    if actor then
        if reason or actor.root.Anchored or actor.humanoid.PlatformStand then
            actor.routeJumpSupport=nil;self:resetLocomotion(id)
        else
            local support,grounded=sampleJumpSupport(self,actor,Workspace:GetServerTimeNow())
            local row=actor.locomotion
            if self.config.Movement and row then
                if row.airSpeed and grounded and not support.consumed then row.airSpeed=nil end
                if not grounded and not row.airSpeed then
                    row.airSpeed=row.groundRun and locomotionRunSpeed(self,id) or row.walkSpeed
                end
                if row.at and not locomotionFresh(self,row) then self:move(id,0,0,false)
                else
                    row.groundRun=locomotionQualifies(self,id,actor,row)
                    actor.humanoid.WalkSpeed=row.airSpeed or (row.runRequested and locomotionRunSpeed(self,id) or row.walkSpeed)
                end
                actor.model:SetAttribute('MovementMode',self:movementMode(id))
            end
        end
    end
    return reason
end

function World:jump(id)
    if self.campaignModes and self.campaignModes:jump(id) then return end
    if not self.config.Level then return self._base.jump(self,id) end
    local actor=self.actors[id]
    if not actor or not actor.root.Parent or actor.humanoid.Health<=0 or actor.root.Anchored
        or actor.humanoid.PlatformStand then return end
    if self:hazard(id) then return end
    local now=Workspace:GetServerTimeNow()
    local state,grounded=sampleJumpSupport(self,actor,now)
    if state.consumed then return end
    local grace=state.groundedAt and now-state.groundedAt>=0 and now-state.groundedAt<=.20
        and state.groundedY-actor.root.Position.Y<=3.5
    -- Native edge hangs can report Climbing/Air while this rig's rotated
    -- footprint still overlaps its safe floor. Accept one deliberate dismount;
    -- climbing never refreshes ground history or rearms a consumed jump.
    local climbingSupport=actor.humanoid:GetState()==Enum.HumanoidStateType.Climbing
        and actor.root.AssemblyLinearVelocity.Y<=1 and hasJumpSupport(self,actor.root)
    if not grounded and not grace and not climbingSupport then return end
    local power=actor.humanoid.JumpPower or self.config.JumpPower
    if type(power)~='number' or power<=0 or power~=power or power==math.huge then return end
    if self.config.Movement then
        local row=actor.locomotion or {walkSpeed=locomotionWalkSpeed(self,id),x=0,z=0}
        local running=self:isRunning(id)
        actor.locomotion=row
        row.airSpeed=row.airSpeed or (running and locomotionRunSpeed(self,id) or row.walkSpeed)
        row.groundRun=false
        actor.humanoid.WalkSpeed=row.airSpeed
        actor.model:SetAttribute('MovementMode','Air')
    end
    state.consumed=true; state.airborne=false; state.launchY=actor.root.Position.Y
    local velocity=actor.root.AssemblyLinearVelocity
    actor.root.AssemblyLinearVelocity=Vector3.new(velocity.X,power,velocity.Z)
    actor.humanoid.Jump=true
end

function World:setReaction(id,active)
    if active then self:resetLocomotion(id) end
    local carried = self.enemyCarries[id]
    if carried then
        -- Reaction deadlines may expire while the body is held or in flight.
        -- Remember the requested eventual state without unfreezing it early.
        carried.platformStand = active
        carried.autoRotate = not active
        carried.walkSpeed = active and 0 or locomotionWalkSpeed(self,id)
        return
    end
    self._base.setReaction(self,id,active)
    local actor=self.actors[id]
    if actor and (self.enemyKinds[id]=='Drone' or actor.campaignWalkSpeed~=nil) then
        actor.humanoid.WalkSpeed=active and 0 or locomotionWalkSpeed(self,id)
    end
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

local function moveEnemySafely(self, id, targetId, speed, away)
    if self.enemyCarries[id] then return end
    local a, b = self.actors[id], self.actors[targetId]
    if not a or not b or not a.root.Parent or not b.root.Parent or a.root.Anchored
        or a.humanoid.PlatformStand or a.humanoid.Health <= 0 then return end
    local delta = b.root.Position - a.root.Position
    if away then delta = -delta end
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
    -- Stop voluntary movement at an unsafe edge. External impulses and gravity
    -- remain untouched, so combat can still knock a mechanical enemy off.
    if self.config.Movement then
        local requested=(speed or 8)>=self.config.Movement.enemyRunSpeed
        self:move(id,direction.X,direction.Z,requested)
        if direction.Magnitude>0 then a.humanoid.WalkSpeed=speed or 8 end
    else a.humanoid:Move(direction, false) end
end

function World:enemyMove(id, targetId, speed)
    moveEnemySafely(self,id,targetId,speed,false)
end

function World:enemyRetreat(id, targetId, speed)
    moveEnemySafely(self,id,targetId,speed,true)
end

function World:enemyHealth(id, raw, maximum)
    local a = self.actors[id]
    if not a then return end
    maximum = math.max(1, tonumber(maximum) or 3)
    local hearts = math.clamp(math.ceil(math.max(0, tonumber(raw) or 0) / maximum * 3), 0, 3)
    a.model:SetAttribute("Hearts", hearts)
    a.model:SetAttribute("HealthRaw", raw)
    a.model:SetAttribute("HealthMax", maximum)
    if self.enemyKinds[id]=='Boss' and self.guardianAppearance then
        self.guardianAppearance.health(a,raw,maximum,self.presentationTime or 0)
    end
    if a.healthLabel then
        local campaignBoss=a.model:GetAttribute('BossKind')
        if campaignBoss then
            a.healthLabel.Text=(self.names[id] or campaignBoss)..'  '..tostring(math.max(0,raw))..' / '..tostring(maximum)
            return
        end
        local symbols = {}
        for n = 1, 3 do symbols[n] = n <= hearts and "♥" or "♡" end
        a.healthLabel.Text = (self.enemyKinds[id] == "Boss" and "GUARDIAN  ·  " or "") .. table.concat(symbols, " ")
    end
end

function World:bossShot(mode)
    local actor=self.actors[-99]
    if actor and self.guardianAppearance then
        self.guardianAppearance.shot(actor,mode,self.presentationTime or 0)
    end
end

function World:progress(zoneIndex, complete)
    if self.campaignWorld then
        self.folder:SetAttribute('ZoneIndex',zoneIndex)
        return
    end
    local level = self.config.Level
    if not level then return end
    zoneIndex = math.clamp(zoneIndex, 1, #level.zones + 1)
    self.zoneIndex = zoneIndex
    self.floors = {}
    for _,floor in ipairs(self.allFloors) do
        if floor:GetAttribute("ZoneIndex") <= zoneIndex then self.floors[#self.floors + 1] = floor end
    end
    local completed = zoneIndex - (complete and 0 or 1)
    for index,gate in ipairs(self.gates) do gateState(gate, index <= completed) end
    self.folder:SetAttribute("ZoneIndex", zoneIndex)
    self.folder:SetAttribute("ZoneName", level.zones[zoneIndex] and level.zones[zoneIndex].name or "Causeway Guardian")
end

function World:noSafe(enabled)
    if not self.config.Level then return self._base.noSafe(self, enabled) end
    self.blocked = enabled
    for _,floor in ipairs(self.allFloors) do floor.CanCollide = not enabled end
end

function World:reached(heroId, box)
    local actor = self.actors[heroId]
    if not actor or not actor.root.Parent or actor.humanoid.Health <= 0 then return false end
    local p = actor.root.Position - self.offset
    return p.X >= box.minX and p.X <= box.maxX and p.Y >= box.minY and p.Y <= box.maxY
        and p.Z >= box.minZ and p.Z <= box.maxZ
end

function World:groundPosition(position)
    local origin = Vector3.new(position.x, position.y, position.z) + self.offset + Vector3.new(0, 16, 0)
    local hit = Workspace:Raycast(origin, Vector3.new(0, -96, 0), self.ray)
    if not hit or hit.Normal.Y < .95 or hit.Instance:GetAttribute("Hazard")
        or not hit.Instance:GetAttribute("SurfaceId") then return nil end
    local p = hit.Position + Vector3.new(0, 1.2, 0) - self.offset
    return {x = p.X, y = p.Y, z = p.Z}
end

function World:stage(name)
    if self.campaignWorld then self.campaignWorld:stage(name);return end
    self.stageName = name
    self.folder:SetAttribute("Stage", name)
    if self.config.Level then
        local open = name == "Exit" or name == "Won"
        gateState(self.exitGate, open)
        self.exitGate.label.Text = name == "Won" and "CAUSEWAY CLEARED!" or (open and "EXIT  →  STAND ON THE SEAL" or "CAUSEWAY GUARDIAN")
        self.exitGate.label.TextColor3 = open and COLORS.mint or COLORS.amber
        self.exitPad.Transparency = open and .12 or .78
        return
    end
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
        self.exitGate.label.Text = name == "Won" and "CAUSEWAY CLEARED!" or "EXIT  →  STAND ON THE SEAL"
        self.exitGate.label.TextColor3 = COLORS.mint
        self.exitGate.label.TextTransparency = 0
    else
        self.exitGate.label.Text = "III  ·  CAUSEWAY GUARDIAN"
        self.exitGate.label.TextColor3 = Color3.fromRGB(226, 244, 211)
    end
    self.exitPad.Transparency = progress >= 3 and 0.12 or 0.78
end

function World:atExit(heroId)
    if self.config.Level then return self:reached(heroId, self.config.Level.boss.exit) end
    local a = self.actors[heroId]
    local p = a and a.root.Parent and a.root.Position - self.offset
    return a ~= nil and a.root.Parent ~= nil and a.humanoid.Health > 0
        and p.X >= 108 and math.abs(p.Z) <= 10
end

function World:projectile(id, positionTable, reflected, mode)
    if type(id) ~= "number" or id > -1000 or not positionTable then return false end
    local p = Vector3.new(positionTable.x, positionTable.y, positionTable.z) + self.offset
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
    local color, size = reflected and COLORS.mint or COLORS.amber, 1.55
    if mode == "Bullet" then color, size = Color3.fromRGB(255, 91, 66), 1.25
    elseif mode == "Heavy" then color, size = Color3.fromRGB(255, 151, 55), 2.6
    elseif mode == "Ground" or mode == "Carried" then color, size = Color3.fromRGB(255, 220, 71), 2.4
    elseif mode == "Thrown" then color, size = COLORS.mint, 2.4 end
    if mode=='StolenLife' or mode=='ReturningLife' then color,size=COLORS.mint,1.2
    elseif mode=='RavenClaw' then color,size=Color3.fromRGB(230,218,176),1.3
    elseif mode=='DeadRaven' then color,size=Color3.fromRGB(40,43,68),2 end
    a.root.CFrame = CFrame.new(p)
    a.halo.CFrame = CFrame.new(p)
    a.root.Size = Vector3.new(size, size, size)
    if mode=='StolenLife' or mode=='ReturningLife' then a.root.Size=Vector3.new(2.1,.55,.55)
    elseif mode=='RavenClaw' then a.root.Size=Vector3.new(.4,.4,3.6) end
    local haloSize = mode and size * 1.35 or 2.1
    a.halo.Size = Vector3.new(haloSize, haloSize, haloSize)
    if mode=='RavenClaw' or mode=='DeadRaven' then a.halo.Transparency=1 end
    a.root.Color = color
    a.halo.Color = color
    a.light.Color = color
    a.model:SetAttribute("Reflected", reflected == true)
    a.model:SetAttribute("ProjectileMode", mode)
    a.model:SetAttribute("Pickup", mode == "Ground")
    a.model:SetAttribute("Carried", mode == "Carried")
    if mode == "Ground" and not a.pickupLabel then
        a.pickupLabel = label(a.root, "BALL  ·  PICK UP", 190, Vector3.new(0, 2.7, 0))
        a.pickupLabel.TextColor3 = Color3.fromRGB(255, 220, 71)
    end
    if a.pickupLabel then a.pickupLabel.Parent.Enabled = mode == "Ground" end
    return true
end

function World:removeProjectile(id)
    local a = self.actors[id]
    if a and id <= -1000 then
        a.model:Destroy()
        self.actors[id] = nil
    end
end

local function livingBody(world, id)
    local actor = world.actors[id]
    return actor and actor.root.Parent and actor.model.Parent == world.actorFolder
        and actor.humanoid.Health > 0 and actor or nil
end

local function flatFacing(root)
    local look = root.CFrame.LookVector
    local length = math.sqrt(look.X*look.X + look.Z*look.Z)
    if length < .000001 then return nil end
    return look.X/length, look.Z/length
end

function World:canGrabEnemy(heroId, enemyId, range, height, facingDot)
    local hero, enemy = livingBody(self, heroId), livingBody(self, enemyId)
    if not hero or not enemy or heroId == enemyId or self.enemyKinds[enemyId] ~= 'Drone'
        or self.enemyCarries[enemyId] or hero.model:GetAttribute('CarryingEnemy') ~= nil
        or hero.root.Anchored or hero.humanoid.PlatformStand or enemy.root.Anchored
        or hero.humanoid.FloorMaterial == Enum.Material.Air
        or math.abs(hero.root.AssemblyLinearVelocity.Y) > 1 then return false end
    local support = Workspace:Raycast(hero.root.Position, Vector3.new(0,-3.4,0), self.ray)
    if not support or support.Normal.Y < .95 or support.Instance:GetAttribute('Hazard')
        or support.Instance:GetAttribute('SurfaceId') == nil then return false end
    local delta = enemy.root.Position - hero.root.Position
    if delta.Magnitude > range or math.abs(delta.Y) > height then return false end
    local x,z = flatFacing(hero.root)
    if not x then return false end
    local horizontal = math.sqrt(delta.X*delta.X + delta.Z*delta.Z)
    if horizontal > .000001 and (x*delta.X + z*delta.Z)/horizontal < facingDot then return false end
    return Workspace:Raycast(hero.root.Position, delta, self.ray) == nil
end

function World:carryEnemy(enemyId, heroId)
    local enemy, hero = livingBody(self, enemyId), livingBody(self, heroId)
    if not enemy or not hero or hero.root.Anchored or hero.humanoid.PlatformStand then return false end
    local carried = self.enemyCarries[enemyId]
    if carried and (carried.mode ~= 'Carried' or carried.actor ~= enemy or carried.holder ~= hero) then return false end
    local x,z = flatFacing(hero.root)
    if not x then return false end
    if not carried then
        if enemy.root.Anchored or self.enemyKinds[enemyId] ~= 'Drone'
            or hero.model:GetAttribute('CarryingEnemy') ~= nil then return false end
        self:resetLocomotion(enemyId,enemy)
        self:resetLocomotion(heroId,hero)
        carried = {actor = enemy, holder = hero, holderId = heroId, mode = 'Carried', collisions = {},
            platformStand = enemy.humanoid.PlatformStand, autoRotate = enemy.humanoid.AutoRotate,
            walkSpeed = enemy.humanoid.WalkSpeed, anchored = enemy.root.Anchored,
            evaluateStateMachine = enemy.humanoid.EvaluateStateMachine}
        -- PlatformStand alone still lets Humanoid rewrite torso collision.
        -- Stop evaluation before disabling the parts so the carried body stays inert.
        enemy.humanoid.EvaluateStateMachine = false
        for _,p in ipairs(enemy.model:GetDescendants()) do
            if p:IsA('BasePart') then carried.collisions[p] = p.CanCollide; p.CanCollide = false end
        end
        self.enemyCarries[enemyId] = carried
        hero.cosmeticActionEvent={action='PickupEnemy'}
        enemy.humanoid:Move(Vector3.new(),false)
    end
    enemy.humanoid.EvaluateStateMachine = false
    enemy.root.Anchored = true
    enemy.humanoid.PlatformStand, enemy.humanoid.AutoRotate, enemy.humanoid.WalkSpeed = true, false, 0
    enemy.root.AssemblyLinearVelocity, enemy.root.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    local origin = hero.root.Position
    local held = Vector3.new(origin.X+x*1.75, origin.Y+3.4, origin.Z+z*1.75)
    enemy.model:PivotTo(CFrame.lookAt(held, Vector3.new(held.X+x,held.Y,held.Z+z)) * CFrame.Angles(0,0,math.pi/2))
    enemy.model:SetAttribute('CarryMode','Carried')
    enemy.model:SetAttribute('HeldBy',heroId)
    hero.model:SetAttribute('CarryingEnemy',enemyId)
    return true
end

function World:releaseEnemy(enemyId, throwerId, tuning)
    local carried = self.enemyCarries[enemyId]
    if not carried then return false end
    local x,z
    if throwerId ~= nil then
        local thrower = livingBody(self,throwerId)
        tuning = tuning or self.config.EnemyCarry
        if carried.mode ~= 'Carried' or thrower ~= carried.holder or not thrower
            or throwerId ~= carried.holderId or thrower.root.Anchored or thrower.humanoid.PlatformStand
            or type(tuning) ~= 'table' or type(tuning.horizontal) ~= 'number' or type(tuning.vertical) ~= 'number'
            or tuning.horizontal ~= tuning.horizontal or tuning.vertical ~= tuning.vertical
            or math.abs(tuning.horizontal) == math.huge or math.abs(tuning.vertical) == math.huge
            or tuning.horizontal < 0 then return false end
        x,z = flatFacing(thrower.root)
        if not x then return false end
    end
    local enemy = carried.actor
    if enemy.root.Parent then enemy.humanoid.EvaluateStateMachine = carried.evaluateStateMachine end
    if carried.holder.model:GetAttribute('CarryingEnemy') == enemyId then
        carried.holder.model:SetAttribute('CarryingEnemy',nil)
    end
    enemy.model:SetAttribute('HeldBy',nil)
    if carried.mode == 'Carried' then
        for p,collidable in pairs(carried.collisions) do if p.Parent then p.CanCollide = collidable end end
        if enemy.root.Parent then
            enemy.root.Anchored = carried.anchored
            local allowed = enemy.root:CanSetNetworkOwnership()
            if allowed then enemy.root:SetNetworkOwner(nil) end
        end
    end
    if throwerId ~= nil then
        carried.mode = 'Thrown'
        carried.holder.cosmeticActionEvent={action='Throw'}
        enemy.model:SetAttribute('CarryMode','Thrown')
        enemy.root.AssemblyLinearVelocity = Vector3.new(x*tuning.horizontal,tuning.vertical,z*tuning.horizontal)
        enemy.root.AssemblyAngularVelocity = Vector3.new()
        return true
    end
    enemy.model:SetAttribute('CarryMode',nil)
    if enemy.root.Parent then
        enemy.humanoid.PlatformStand, enemy.humanoid.AutoRotate, enemy.humanoid.WalkSpeed =
            carried.platformStand, carried.autoRotate, carried.walkSpeed
    end
    self.enemyCarries[enemyId] = nil
    return true
end

-- New mechanical leg-club art. Ground items and equipment have separate lifetimes.
local function clubArt(parent, name, frame, arm)
    local model = Instance.new('Model')
    model.Name = name
    model:SetAttribute('ItemKind','WalkerClub')
    local art = {model=model,parts={}}
    local function piece(name, size, offset, color, material)
        local p = part(model,name,size,frame*offset,color,material or Enum.Material.Metal,false)
        p.CanQuery = false
        if arm then
            p.Anchored, p.Massless = false, true
            local weld = Instance.new('WeldConstraint')
            weld.Part0, weld.Part1, weld.Parent = arm, p, p
        end
        art.parts[#art.parts+1] = {part=p,offset=offset}
        return p
    end
    art.root = piece('Grip',Vector3.new(.48,.7,.55),CFrame.new(),COLORS.dark)
    piece('PistonShaft',Vector3.new(.4,2.3,.48),CFrame.new(0,-1.3,0),COLORS.pale)
    piece('UpperCollar',Vector3.new(.62,.3,.65),CFrame.new(0,-.5,0),COLORS.rust)
    piece('LowerCollar',Vector3.new(.62,.35,.65),CFrame.new(0,-2.25,0),COLORS.rust)
    piece('MechanicalFoot',Vector3.new(.95,.6,1.7),CFrame.new(0,-2.68,-.42),COLORS.dark)
    piece('ImpactPlate',Vector3.new(1.06,.19,1.85),CFrame.new(0,-3.04,-.42),COLORS.pale)
    piece('PowerStrip',Vector3.new(.12,1.5,.07),CFrame.new(0,-1.25,-.28),COLORS.mint,Enum.Material.Neon)
    model.PrimaryPart = art.root
    model.Parent = parent
    return art
end

function World:clubItem(id, position)
    local item = self.clubItems[id]
    if not position then
        if item then item.model:Destroy();self.clubItems[id]=nil end
        return
    end
    local physical = Vector3.new(position.x,position.y,position.z)+self.offset
    local frame = CFrame.new(physical)*CFrame.Angles(0,0,math.pi/2)
    if not item then
        item = clubArt(self.clubItemFolder,'ClubItem_'..tostring(id),frame)
        item.model:SetAttribute('ClubId',id)
        local text=label(item.root,"CLUB  ·  PICK UP",190,Vector3.new(0,1.4,0))
        text.TextColor3,text.TextSize,text.Parent.MaxDistance=COLORS.mint,14,45
        pointLight(item.root,COLORS.mint,7,.4)
        self.clubItems[id]=item
    end
    for _,piece in ipairs(item.parts) do piece.part.CFrame=frame*piece.offset end
end

function World:canPickupClub(heroId, position, range, height)
    local hero = livingBody(self,heroId)
    if not hero or heroId<=0 or hero.root.Anchored or hero.humanoid.PlatformStand
        or hero.model:GetAttribute('CarryingEnemy')~=nil
        or hero.humanoid.FloorMaterial==Enum.Material.Air
        or math.abs(hero.root.AssemblyLinearVelocity.Y)>1 then return false end
    local support=Workspace:Raycast(hero.root.Position,Vector3.new(0,-3.4,0),self.ray)
    if not support or support.Normal.Y<.95 or support.Instance:GetAttribute('Hazard')
        or support.Instance:GetAttribute('SurfaceId')==nil then return false end
    local destination=Vector3.new(position.x,position.y,position.z)+self.offset
    local delta=destination-hero.root.Position
    return delta.Magnitude<=range and math.abs(delta.Y)<=height
        and Workspace:Raycast(hero.root.Position,delta,self.ray)==nil
end

function World:equipClub(id, heroId)
    local hero=livingBody(self,heroId)
    local arm=hero and hero.model:FindFirstChild('Right Arm')
    if not hero or heroId<=0 or not arm then return false end
    local equipped=self.equippedClubs[id]
    if equipped then return equipped.owner==hero and equipped.heroId==heroId and equipped.model.Parent==hero.model end
    if hero.model:GetAttribute('EquippedClub')~=nil then return false end
    local grip=arm.CFrame*CFrame.new(0,-1.05,0)
    local appearance=hero.appearance
    if appearance and appearance.profile=='CanonicalNESHero' and appearance.ownerModel==hero.model
        and appearance.model and appearance.model.Parent==hero.model then
        local hand=appearance.model:FindFirstChild('RightHand')
        local wrist=hand and hand:FindFirstChild('RightWristRigAttachment')
        if hand and hand:IsA('BasePart') and wrist and wrist:IsA('Attachment') then
            -- The visible hand moves independently of its hidden R6 fallback.
            -- Use the palm centre; the wrist rotation corrects imported axes.
            arm,grip=hand,hand.CFrame*wrist.CFrame.Rotation
        end
    end
    local art=clubArt(hero.model,'EquippedClub_'..tostring(id),grip,arm)
    art.model:SetAttribute('ClubId',id)
    art.owner,art.heroId=hero,heroId
    self.equippedClubs[id]=art
    hero.model:SetAttribute('EquippedClub',id)
    ownCompletedRig(hero)
    return true
end

function World:unequipClub(id)
    local equipped=self.equippedClubs[id]
    if not equipped then return false end
    local owner=equipped.owner
    if owner.model:GetAttribute('EquippedClub')==id then
        owner.model:SetAttribute('EquippedClub',nil)
        owner.model:SetAttribute('ClubSwing',nil)
        if owner.poseMotors and not owner.model:GetAttribute('CarryingEnemy') then
            local right=owner.poseMotors['Right Shoulder']
            if right then right.joint.C0=right.base end
        end
    end
    equipped.model:Destroy()
    self.equippedClubs[id]=nil
    ownCompletedRig(owner)
    return true
end

function World:clubSwing(id, heroId)
    local equipped=self.equippedClubs[id]
    local hero=livingBody(self,heroId)
    if not equipped or equipped.owner~=hero or equipped.heroId~=heroId
        or hero.model:GetAttribute('EquippedClub')~=id then return false end
    equipped.swingUntil=(self.presentationTime or 0)+.28
    equipped.model:SetAttribute('Swinging',true)
    hero.model:SetAttribute('ClubSwing',true)
    hero.cosmeticActionEvent={action='Club'}
    return true
end

-- Collectibles are presentation only: they never enter the combat actor table.
function World:healingFly(id, position)
    local fly = self.healingFlyVisuals[id]
    if not position then
        if fly then fly.model:Destroy(); self.healingFlyVisuals[id] = nil end
        return
    end
    local physical = Vector3.new(position.x, position.y, position.z) + self.offset
    if not fly then
        local model = Instance.new("Model")
        model.Name = "HealingFly_" .. tostring(id)
        model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        model:SetAttribute("CollectibleId", id)
        model:SetAttribute("CollectibleKind", "HealingFly")
        model:SetAttribute("CanCatch", true)
        fly = {model = model, parts = {}, wings = {}}
        local function piece(name, size, offset, color, shape, material)
            local p = part(model, name, size, CFrame.new(physical) * offset, color, material, false)
            p.CanQuery = false
            if shape then p.Shape = shape end
            fly.parts[#fly.parts + 1] = {part = p, offset = offset}
            return p
        end
        fly.root = piece("FlyBody", Vector3.new(.85,.65,1.1), CFrame.new(), COLORS.mint,
            Enum.PartType.Ball, Enum.Material.Neon)
        piece("FlyHead", Vector3.new(.65,.6,.55), CFrame.new(0,.07,-.65), COLORS.moss, Enum.PartType.Ball)
        for _,side in ipairs({-1,1}) do
            piece("FlyEye", Vector3.new(.2,.25,.2), CFrame.new(side*.24,.18,-.89), COLORS.amber,
                Enum.PartType.Ball, Enum.Material.Neon)
            local offset = CFrame.new(side*.66,.24,.04) * CFrame.Angles(0,side*.35,side*.25)
            local wing = piece(side<0 and "LeftWing" or "RightWing", Vector3.new(1.05,.1,.72), offset,
                Color3.fromRGB(209,245,230), Enum.PartType.Ball)
            wing.Transparency = .3
            fly.wings[#fly.wings + 1] = {part = wing, offset = offset, side = side}
        end
        local aura = piece("HealingAura", Vector3.new(1.7,1.7,1.7), CFrame.new(), COLORS.mint,
            Enum.PartType.Ball, Enum.Material.ForceField)
        aura.Transparency = .84
        pointLight(fly.root, COLORS.mint, 7, .55)
        local text = label(fly.root, "FLY  ·  HEAL", 170, Vector3.new(0,1.6,0))
        text.TextSize = 13
        text.TextColor3 = COLORS.mint
        text.Parent.MaxDistance = 38
        model.PrimaryPart = fly.root
        if self.castAppearance then
            local mount=piece('Torso',Vector3.new(.1,.1,.1),CFrame.new(),COLORS.mint)
            mount.Transparency=1
            local cosmeticActor={model=model,root=fly.root}
            fly.castActor=cosmeticActor
            if self.castAppearance.attach(cosmeticActor,'HealingFly') and self.castAppearance.addFallback then
                self.castAppearance.addFallback(cosmeticActor,fly.root)
            end
        end
        model.Parent = self.healingFlyFolder
        self.healingFlyVisuals[id] = fly
    end
    for _,piece in ipairs(fly.parts) do piece.part.CFrame = CFrame.new(physical) * piece.offset end
end

function World:canCatchFly(heroSlot, position, range, height, facingDot)
    local actor = self.actors[heroSlot]
    if not actor or not actor.root.Parent then return false end
    local physical = Vector3.new(position.x, position.y, position.z) + self.offset
    local delta = physical - actor.root.Position
    if math.abs(delta.Y) > height or delta.Magnitude > range then return false end
    local horizontal = math.sqrt(delta.X*delta.X + delta.Z*delta.Z)
    if horizontal < .000001 then return true end
    local look = actor.root.CFrame.LookVector
    local lookLength = math.sqrt(look.X*look.X + look.Z*look.Z)
    return lookLength > .000001
        and (look.X*delta.X + look.Z*delta.Z) / (lookLength*horizontal) >= facingDot
end

function World:catchFly(heroSlot, flyId)
    local fly, actor = self.healingFlyVisuals[flyId], self.actors[heroSlot]
    if not fly then return false end
    local destination = fly.root.Position
    self:healingFly(flyId, nil)
    if not actor or not actor.root.Parent then return true end
    actor.cosmeticActionEvent={action='Tongue'}
    local head = actor.model:FindFirstChild("Head") or actor.root
    local mouth = (head.CFrame * CFrame.new(0,-.28,-.94)).Position
    local delta = destination - mouth
    local midpoint = Vector3.new((mouth.X+destination.X)/2, (mouth.Y+destination.Y)/2, (mouth.Z+destination.Z)/2)
    local model = Instance.new("Model")
    model.Name = "HealingCatch_" .. tostring(heroSlot)
    model:SetAttribute("CollectibleId", flyId)
    local tongue = part(model, "Tongue", Vector3.new(.13,.13,math.max(delta.Magnitude,.1)),
        CFrame.lookAt(midpoint, destination), Color3.fromRGB(255,145,158), Enum.Material.Neon, false)
    tongue.CanQuery = false
    local flash = ball(model, "HealingFlash", Vector3.new(.7,.7,.7), CFrame.new(mouth), COLORS.mint, Enum.Material.Neon)
    flash.CanQuery = false
    flash.Transparency = .35
    model.Parent = self.healingEffectFolder
    self.healingEffects[model] = (self.presentationTime or 0) + .22
    return true
end

-- Original Pig silhouettes for the trusted strike state, not NES frame timing.
local pigPoses = {
    PigJab = {
        Windup = {left=.9,right=-.25,leftRoll=.2,rightRoll=-.35,hip=.1},
        Recovery = {left=.45,right=1.85,leftRoll=.12,rightRoll=-.15,hip=0},
    },
    PigHeavy = {
        Windup = {left=2.25,right=2.25,leftRoll=-.5,rightRoll=.5,hip=.35},
        Recovery = {left=1.35,right=1.35,leftRoll=-.25,rightRoll=.25,hip=.15},
    },
    PigRush = {
        Windup = {left=-.65,right=-.65,leftRoll=-.55,rightRoll=.55,hip=.55},
        Recovery = {left=1.65,right=1.65,leftRoll=-.3,rightRoll=.3,hip=.35},
    },
}

-- The Walker's mechanical legs distinguish a light kick from the heavy launch.
local walkerPoses = {
    WalkerLight = {
        Windup = {left=.25,right=.55,leftRoll=-.2,rightRoll=.2,leftHip=.15,rightHip=-.9},
        Recovery = {left=.5,right=.6,leftRoll=-.15,rightRoll=.15,leftHip=0,rightHip=1.1},
    },
    WalkerHeavy = {
        Windup = {left=1.1,right=1.1,leftRoll=-.4,rightRoll=.4,leftHip=.8,rightHip=.8},
        Recovery = {left=1.65,right=1.65,leftRoll=-.25,rightRoll=.25,leftHip=-.25,rightHip=-.25},
    },
}

-- The generic grounded run strike reuses each family's original heavy silhouette.
-- These poses only present the server-selected action; they never choose damage.
pigPoses.EnemyRunStrike=pigPoses.PigRush
walkerPoses.EnemyRunStrike=walkerPoses.WalkerHeavy

local dragonPoses = {
    DragonHeadbutt = {
        Windup = {left=-.4,right=-.4,leftRoll=-.3,rightRoll=.3,hip=-.15,neck=-.55},
        Recovery = {left=.8,right=.8,leftRoll=-.5,rightRoll=.5,hip=.2,neck=.45},
    },
}

local heroPoses = {
    HeroJab={Windup={left=.3,right=-.3,leftRoll=.1,rightRoll=-.2,hip=0},
        Recovery={left=.4,right=1.9,leftRoll=.1,rightRoll=-.1,hip=0}},
    HeroUppercut={Windup={left=.7,right=-.7,leftRoll=.2,rightRoll=-.4,hip=.15},
        Recovery={left=.6,right=2.7,leftRoll=.1,rightRoll=-.2,hip=-.2}},
    HeroElbow={Windup={left=2.3,right=2.3,leftRoll=-.4,rightRoll=.4,hip=-.15},
        Recovery={left=1.2,right=1.2,leftRoll=-.2,rightRoll=.2,hip=.25}},
    HeroPowerPunch={Windup={left=.8,right=-1,leftRoll=.2,rightRoll=-.6,hip=.25},
        Recovery={left=.5,right=2.3,leftRoll=.1,rightRoll=-.1,hip=-.3}},
    HeroKick={Windup={left=.8,right=.8,leftRoll=-.2,rightRoll=.2,leftHip=.1,rightHip=-.6},
        Recovery={left=.5,right=.5,leftRoll=-.1,rightRoll=.1,leftHip=0,rightHip=1.2}},
    HeroBoot={Windup={left=1.1,right=1.1,leftRoll=-.4,rightRoll=.4,leftHip=.3,rightHip=-1},
        Recovery={left=.4,right=.4,leftRoll=-.2,rightRoll=.2,leftHip=-.2,rightHip=1.6}},
    Dash={Windup={left=-.5,right=-.5,leftRoll=-.4,rightRoll=.4,hip=.2},
        Recovery={left=1.6,right=1.6,leftRoll=-.2,rightRoll=.2,hip=.25}},
}

function World:updatePresentation(session, dt, enemies, director)
    if self.campaignWorld then self.campaignWorld:step(session.now) end
    dt = math.clamp(tonumber(dt) or 0, 0, 0.1)
    self.presentationTime = (self.presentationTime or 0) + dt
    for id,equipped in pairs(self.equippedClubs) do
        if equipped.swingUntil and self.presentationTime>=equipped.swingUntil then
            equipped.swingUntil=nil
            equipped.model:SetAttribute('Swinging',false)
            if equipped.owner.model:GetAttribute('EquippedClub')==id then equipped.owner.model:SetAttribute('ClubSwing',nil) end
        end
    end
    for model,expiresAt in pairs(self.healingEffects) do
        if self.presentationTime >= expiresAt then model:Destroy(); self.healingEffects[model] = nil end
    end
    for _,fly in pairs(self.healingFlyVisuals) do
        for _,wing in ipairs(fly.wings) do
            wing.part.CFrame = CFrame.new(fly.root.Position) * wing.offset
                * CFrame.Angles(0,0,math.sin(self.presentationTime*32)*.35*wing.side)
        end
        if fly.castActor and self.castAppearance then
            if not fly.castActor.castAppearance and self.castAppearance.attach(fly.castActor,'HealingFly') then
                if self.castAppearance.addFallback then self.castAppearance.addFallback(fly.castActor,fly.root) end
            end
            self.castAppearance.update(fly.castActor,{kind='HealingFly',actorId='fly:'..tostring(fly.model:GetAttribute('CollectibleId')),
                levelEpoch=session.state and session.state.levelEpoch,now=session.now,dt=dt,speed=0,mode='Fly'})
        end
    end
    local blend = 1 - math.exp(-dt * 18)
    for id, actor in pairs(self.actors) do
        if id > -1000 and actor.root.Parent and self.enemyKinds[id] ~= "Boss" then
            if not actor.poseMotors then
                actor.poseMotors = {}
                for _,joint in ipairs(actor.model:GetDescendants()) do
                    if joint:IsA("Motor6D") and (joint.Name=='RootJoint' or joint.Name == "Left Shoulder" or joint.Name == "Right Shoulder"
                        or joint.Name == "Left Hip" or joint.Name == "Right Hip"
                        or (joint.Name=='Neck' and enemies and enemies[id] and enemies[id].kind=='Dragon')) then
                        actor.poseMotors[joint.Name] = {joint = joint, base = joint.C0}
                    end
                end
            end
            if actor.wingMotors then
                local e=enemies and enemies[id]
                local flying=actor.model:GetAttribute('DragonFlight') and actor.humanoid.Health>0 and not (e and e.reactionUntil)
                for _,wing in ipairs(actor.wingMotors) do
                    local stroke=flying and math.sin(self.presentationTime*10)*.45*wing.side or 0
                    wing.joint.C0=wing.joint.C0:Lerp(wing.base*CFrame.Angles(0,0,stroke),blend)
                end
            end
            local combat = session and session.combat and session.combat[id]
            local enemy = enemies and enemies[id]
            local reacting = (combat and combat.reactionEnd ~= nil) or (enemy and enemy.reactionUntil ~= nil)
            local carryingEnemy = actor.model:GetAttribute('CarryingEnemy') ~= nil
            local dragonLink=actor.model:GetAttribute('DragonLink')
            local beingCarried = self.enemyCarries[id] and self.enemyCarries[id].mode == 'Carried'
            local club=self.equippedClubs[actor.model:GetAttribute('EquippedClub')]
            if club and club.owner~=actor then club=nil end
            local pig = enemy and enemy.kind == 'Pig'
            local poses = pig and pigPoses or (enemy and enemy.kind=='Walker' and walkerPoses)
                or (enemy and enemy.kind=='Dragon' and dragonPoses)
                or (combat and session.sourceCombat and heroPoses)
            local actionState=enemy or combat
            local windup=enemy and enemy.windup or (combat and combat.attack)
            local primaryAction,primaryPhase
            if poses then
                actor.attackPoseUntil,actor.attackPoseAction = nil,nil
                local dead = actor.humanoid.Health<=0 or (enemy and enemy.dead) or (combat and combat.deathAt~=nil)
                if not dead and not reacting and not carryingEnemy and not beingCarried then
                    if windup and poses[windup.action] then
                        primaryAction,primaryPhase = windup.action,'Windup'
                    elseif poses[actionState.lastStrikeAction] and type(actionState.strikeRecoveryUntil)=='number'
                        and session and type(session.now)=='number' and session.now<actionState.strikeRecoveryUntil then
                        primaryAction,primaryPhase = actionState.lastStrikeAction,'Recovery'
                    elseif pig and enemy.rushing then primaryAction,primaryPhase = 'PigRush','Running' end
                end
            else
                local attack = (combat and combat.attack) or (enemy and enemy.windup)
                if attack then
                    actor.attackPoseUntil = self.presentationTime + 0.17
                    actor.attackPoseAction = attack.action or 'Punch'
                end
            end
            if poses or actor.primaryPresentationActive then
                actor.model:SetAttribute('PrimaryAttack',primaryAction)
                actor.model:SetAttribute('AttackPhase',primaryPhase)
                actor.primaryPresentationActive = poses~=nil and poses~=false
            end
            local attacking = actor.attackPoseUntil and self.presentationTime < actor.attackPoseUntil
            local velocity = actor.campaignVelocity or actor.root.AssemblyLinearVelocity
            local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
            local movementMode=self.config.Movement and self:movementMode(id)
            if movementMode then actor.model:SetAttribute('MovementMode',movementMode) end
            local walking = not actor.root.Anchored and actor.humanoid.Health > 0
                and actor.humanoid.FloorMaterial ~= Enum.Material.Air
            if self.config.Movement then walking=movementMode=='Walk' or movementMode=='Run' end
            local running = primaryPhase=='Running' or (movementMode=='Run' and not primaryAction)
            actor.walkPhase = (actor.walkPhase or 0) + dt * math.min(speed, 20) * (running and 1.3 or .8)
            local stride = walking and math.sin(actor.walkPhase) * math.clamp(speed / 12, 0, 1) * (running and .75 or .5) or 0
            local primaryPose = primaryAction and poses[primaryAction][primaryPhase]
            for name, motor in pairs(actor.poseMotors) do
                local shoulder = string.find(name, "Shoulder", 1, true) ~= nil
                local left = string.find(name, "Left", 1, true) ~= nil
                local angle = stride * (left and 1 or -1) * (shoulder and -1 or 1)
                local roll = 0
                if name=='RootJoint' then
                    angle=movementMode=='Swim' and -.95 or 0
                elseif name=='Neck' then
                    angle=primaryPose and primaryPose.neck or 0
                elseif shoulder and carryingEnemy then
                    angle, roll = 2.65, left and -.2 or .2
                elseif dragonLink=='Mounted' then
                    angle=shoulder and .55 or 1.2;roll=left and -.2 or .2
                elseif dragonLink=='Captured' then
                    angle=shoulder and 2.5 or .35;roll=left and -.2 or .2
                elseif beingCarried then
                    angle, roll = shoulder and 1.3 or .45, left and -.3 or .3
                elseif shoulder and reacting then
                    angle, roll = 0.65, left and -0.25 or 0.25
                elseif movementMode=='Rope' then
                    local striking=combat and combat.strikeRecoveryUntil and session.now<combat.strikeRecoveryUntil
                    local armed=actor.model:FindFirstChild('CampaignRavenClaw')~=nil
                    angle=shoulder and (striking and armed and not left and 1.8 or 2.8)
                        or (striking and not left and 1.85 or .25)
                    roll=shoulder and (left and -.15 or .15) or 0
                elseif movementMode=='Ride' then
                    angle=shoulder and .65 or 1.1;roll=left and -.12 or .12
                elseif movementMode=='Swim' then
                    angle=shoulder and (1.2+math.sin(self.presentationTime*8+(left and 0 or math.pi))*.7)
                        or math.sin(self.presentationTime*8+(left and math.pi or 0))*.45
                elseif shoulder and club and not left then
                    angle,roll=club.swingUntil and 1.95 or .65,club.swingUntil and -.55 or .25
                elseif running then
                    angle = shoulder and (-.55-stride*.6) or (stride*1.2+.2)
                    roll = left and -.18 or .18
                elseif primaryPose then
                    angle = shoulder and (left and primaryPose.left or primaryPose.right)
                        or (left and primaryPose.leftHip or primaryPose.rightHip) or primaryPose.hip
                    roll = shoulder and (left and primaryPose.leftRoll or primaryPose.rightRoll) or 0
                elseif shoulder and attacking then
                    angle = actor.attackPoseAction == "Dash" and 1.5 or (left and 0.45 or 1.95)
                end
                motor.joint.C0 = motor.joint.C0:Lerp(motor.base * CFrame.Angles(angle, 0, roll), blend)
            end
            if self.characterAppearance then
                -- Accepted server state only. Source-stream commands remain
                -- inert; this context drives cosmetic joints after R6 fallback.
                local visualState=(actor.humanoid.Health<=0 or (enemy and enemy.dead) or (combat and combat.deathAt~=nil)) and 'Dead'
                    or (reacting and 'Reaction') or (carryingEnemy and 'Carrying') or (beingCarried and 'Carried')
                    or (dragonLink=='Mounted' and 'DragonMounted') or (dragonLink=='Captured' and 'DragonCaptured')
                    or (movementMode=='Swim' and 'Swim') or (movementMode=='Ride' and 'Ride')
                    or (movementMode=='Rope' and 'Rope') or (club and 'Club')
                    or ((movementMode=='Air' or actor.humanoid.FloorMaterial==Enum.Material.Air and not actor.campaignControl) and 'Air')
                    or (walking and math.abs(velocity.Z)>math.abs(velocity.X)*1.3 and 'DepthWalk') or nil
                local blocked=((actor.root.Anchored or actor.humanoid.PlatformStand) and not actor.campaignControl
                    and not visualState and 'Paused') or nil
                if combat and actor.visualReactionEpoch~=combat.reactionEpoch then
                    actor.visualReactionEpoch=combat.reactionEpoch;actor.visualReactionAt=session.now
                end
                if actor.cosmeticActionEvent and actor.seenCosmeticActionEvent~=actor.cosmeticActionEvent then
                    actor.seenCosmeticActionEvent=actor.cosmeticActionEvent
                    actor.visualAction={action=actor.cosmeticActionEvent.action,actorId=actor.model:GetAttribute('ActorId'),
                        at=session.now,tuning={windup=0}}
                end
                if actor.visualAction and session.now-actor.visualAction.at>2 then actor.visualAction=nil end
                local rideDeckY
                if visualState=='Ride' and self.campaignWorld and self.campaignWorld.world==self then
                    local rider=self.campaignModes and self.campaignModes.actors and self.campaignModes.actors[id]
                    local objects=self.campaignWorld.objects
                    local row=objects and (objects['vehicle-'..tostring(id)] or objects['clinger-'..tostring(id)])
                    local mount=row and row.courseAppearance
                    if rider and rider.actorId==actor.model:GetAttribute('ActorId') and mount and mount.skin
                        and mount.model.Parent==self.geometry and mount.skin.Parent==mount.model
                        and row.part.Parent==self.geometry then
                        local y=mount.deckWorldY
                        if type(y)=='number' and y==y and math.abs(y)<math.huge then rideDeckY=y end
                    end
                end
                self.characterAppearance.update(actor,{
                    enabled=combat~=nil and not enemy and session.sourceCombat and true or false,
                    actorId=actor.model:GetAttribute('ActorId'),now=session and session.now,dt=dt,
                    body=actor.model,levelEpoch=session.state and session.state.levelEpoch,
                    dashResult=actor.dashPresentationResult,
                    rideDeckY=rideDeckY,
                    attack=combat and combat.attack,recoveryAction=combat and combat.lastStrikeAction,
                    recoveryUntil=combat and combat.strikeRecoveryUntil,reactionEpoch=combat and combat.reactionEpoch,
                    blocked=blocked,visualState=visualState,verticalSpeed=velocity.Y,holding=carryingEnemy,
                    visualAction=actor.visualAction,reaction={heavy=combat and combat.heavyReaction==true,
                        startedAt=actor.visualReactionAt},
                    grounded=actor.campaignControl and (movementMode=='Walk' or movementMode=='Run' or movementMode=='Idle')
                        or not actor.campaignControl and actor.humanoid.FloorMaterial~=Enum.Material.Air,
                    mode=movementMode or (walking and 'Walk' or 'Idle'),speed=speed,
                    fearIntro=self.bossIntroState and self.bossIntroState.heroActors
                        and self.bossIntroState.heroActors[id]==actor.model:GetAttribute('ActorId') and {
                            id=self.bossIntroState.id,actorId=self.bossIntroState.heroActors[id],
                            counter=self.bossIntroState.counter,frameId=self.bossIntroState.fearFrame} or nil,
                })
            end
        end
    end
    if self.guardianAppearance then
        for id,actor in pairs(self.actors) do
            if self.enemyKinds[id]=='Boss' then self.guardianAppearance.update(actor,self.presentationTime) end
        end
    end
    if self.castAppearance then
        for _,actor in pairs(self.actors) do
            if actor.castRequestedKind and not actor.castAppearance and actor.root.Parent then
                self.castAppearance.attach(actor,actor.castRequestedKind)
            end
        end
        for id,actor in pairs(self.actors) do if actor.castAppearance and actor.root.Parent then
            local enemy=enemies and enemies[id]
            local machine=director and director.campaignEnemies
            local state=machine and machine.states[id]
            local dragons=director and (director.dragons or director.ordinary and director.ordinary.dragons)
            local flight=dragons and dragons.states[id]
            local bossState=director and director.boss
            local isBoss=bossState and id==-99
            local rawAttack=isBoss and bossState.attack or state and state.attack or enemy and enemy.windup
            if rawAttack and actor.castAttackSource~=rawAttack then
                actor.castAttackSource=rawAttack
                local tuning=rawAttack.move or rawAttack.tuning or self.config.Attacks[rawAttack.action] or {}
                actor.castAttack={name=rawAttack.name or rawAttack.action,
                    actorId=actor.model:GetAttribute('ActorId') or tostring(id),
                    levelEpoch=session.state and session.state.levelEpoch,
                    start=(rawAttack.tellAt or rawAttack.at or session.now)-(tuning.tell or tuning.windup or 0)}
            elseif not rawAttack then actor.castAttackSource=nil end
            local velocity=actor.campaignVelocity or actor.root.AssemblyLinearVelocity
            local mode=actor.model:GetAttribute('CampaignMode') or self:movementMode(id) or 'Idle'
            if type(mode)=='string' then mode=mode:gsub('^Enemy','') end
            local sourceState
            if actor.castAppearance.kind=='Dragon' then
                if flight and flight.mode=='Disabled' then mode='Disabled';sourceState='HeavyDisabled'
                elseif flight and flight.mode=='Approach' then mode='Fly';sourceState='Approach'
                elseif actor.model:GetAttribute('DragonFlight') then mode='Fly' end
            end
            local phase=isBoss and bossState.state or state and state.mode
                or enemy and enemy.windup and 'Tell' or enemy and enemy.strikeRecoveryUntil
                    and session.now<enemy.strikeRecoveryUntil and 'Recovery' or 'Ready'
            if not rawAttack and phase~='Recovery' then actor.castAttack=nil end
            local reacting=enemy and enemy.reactionUntil~=nil or isBoss and phase=='Reaction'
            local reactionProgress
            if reacting then
                local epoch=enemy and enemy.reactionEpoch or 0
                if not actor.castReacting or actor.castReactionEpoch~=epoch then
                    actor.castReactionAt=session.now;actor.castReactionEpoch=epoch
                end
                local untilAt=enemy and enemy.reactionUntil
                if type(untilAt)=='number' then
                    reactionProgress=math.clamp((session.now-actor.castReactionAt)/math.max(.001,untilAt-actor.castReactionAt),0,1)
                end
            else actor.castReactionAt=nil end
            actor.castReacting=reacting==true
            self.castAppearance.update(actor,{kind=actor.castAppearance.kind,
                actorId=actor.model:GetAttribute('ActorId') or tostring(id),levelEpoch=session.state and session.state.levelEpoch,
                now=session.now,dt=dt,speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude,
                mode=mode,sourceState=sourceState,
                phase=phase,attack=actor.castAttack,dead=actor.humanoid.Health<=0 or enemy and enemy.dead,
                reacting=reacting,reactionHeavy=enemy and enemy.heavyReaction==true
                    or isBoss and bossState.heavyReaction==true or flight and flight.mode=='Disabled',
                reactionProgress=reactionProgress,
                carried=self.enemyCarries[id] and self.enemyCarries[id].mode=='Carried'})
        end end
    end
end

function World:clearActors()
    if self.campaignModes then self.campaignModes:close('RunClosed');self.campaignModes=nil end
    self.transitionOrigins=nil
    for id in pairs(self.equippedClubs) do self:unequipClub(id) end
    for id in pairs(self.enemyCarries) do self:releaseEnemy(id) end
    for id,actor in pairs(self.actors) do self:resetLocomotion(id,actor) end
    if self.guardianAppearance then
        for _,actor in pairs(self.actors) do self.guardianAppearance.detach(actor) end
    end
    self._base.clearActors(self)
    self.enemyKinds = {}
    self.healingFlyFolder:ClearAllChildren()
    self.healingEffectFolder:ClearAllChildren()
    self.healingFlyVisuals, self.healingEffects = {}, {}
    self.clubItemFolder:ClearAllChildren()
    self.clubItems,self.equippedClubs={},{}
    resetOrigins(self)
    if self.config.Level then self:progress(1, false) end
    self:stage("Approach")
end

return World
