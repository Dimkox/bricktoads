-- Geometry generated from assets/models/{RatPod,Meteorite}/design.py.
local designs = {
    RatPod = {
        parts = {
            {"PodHull", "Keel", "Ball", {2.25, 1.65, 4.82}, {0, -0.26, -0.17}, {10, 65, 76}, "Metal", {0, 0, 0}},
            {"PodHull", "PressureHull", "Ball", {2.5, 2.18, 4.9}, {0, -0.02, -0.1}, {4, 164, 171}, "Metal", {0, 0, 0}},
            {"PodHull", "NoseSkid", "Ball", {1.48, 0.5, 2.03}, {0, -0.12, -1.585}, {24, 201, 199}, "Metal", {-6, 0, 0}},
            {"PodHull", "ChineL", "Ball", {0.36, 0.38, 3.23}, {-1.02, -0.25, -0.08}, {24, 99, 108}, "Metal", {0, 4, -5}},
            {"PodHull", "IntakeL0", "Block", {0.1, 0.46, 0.085}, {-1.17, -0.3, 0.36}, {10, 65, 76}, "Metal", {17, 0, 0}},
            {"PodHull", "IntakeL1", "Block", {0.1, 0.46, 0.085}, {-1.17, -0.3, 0.57}, {10, 65, 76}, "Metal", {17, 0, 0}},
            {"PodHull", "IntakeL2", "Block", {0.1, 0.46, 0.085}, {-1.17, -0.3, 0.78}, {10, 65, 76}, "Metal", {17, 0, 0}},
            {"Stabilizers", "FoilL", "Wedge", {0.79, 0.35, 1.5}, {-1.48, -0.37, 0.65}, {4, 164, 171}, "Metal", {-5, -15, 12}},
            {"Stabilizers", "FoilEdgeL", "Ball", {0.16, 0.19, 1.16}, {-1.78, -0.4, 0.63}, {24, 201, 199}, "Metal", {-5, -15, 12}},
            {"PodHull", "ChineR", "Ball", {0.36, 0.38, 3.23}, {1.02, -0.25, -0.08}, {24, 99, 108}, "Metal", {0, -4, 5}},
            {"PodHull", "IntakeR0", "Block", {0.1, 0.46, 0.085}, {1.17, -0.3, 0.36}, {10, 65, 76}, "Metal", {17, 0, 0}},
            {"PodHull", "IntakeR1", "Block", {0.1, 0.46, 0.085}, {1.17, -0.3, 0.57}, {10, 65, 76}, "Metal", {17, 0, 0}},
            {"PodHull", "IntakeR2", "Block", {0.1, 0.46, 0.085}, {1.17, -0.3, 0.78}, {10, 65, 76}, "Metal", {17, 0, 0}},
            {"Stabilizers", "FoilR", "Wedge", {0.79, 0.35, 1.5}, {1.48, -0.37, 0.65}, {4, 164, 171}, "Metal", {-5, 15, -12}},
            {"Stabilizers", "FoilEdgeR", "Ball", {0.16, 0.19, 1.16}, {1.78, -0.4, 0.63}, {24, 201, 199}, "Metal", {-5, 15, -12}},
            {"Cockpit", "CanopyFrame", "Ball", {1.98, 1.13, 3.23}, {0, 0.53, -0.49}, {24, 99, 108}, "Metal", {-13, 0, 0}},
            {"Cockpit", "SmokedCanopy", "Ball", {1.87, 1.39, 3.03}, {0, 0.61, -0.5}, {12, 24, 49}, "SmoothPlastic", {-13, 0, 0}},
            {"Cockpit", "ReflectedSky", "Ball", {0.33, 0.055, 1.27}, {0.45, 1.22, -0.56}, {65, 101, 135}, "SmoothPlastic", {-13, 0, -21}},
            {"RearRing", "Collar0", "Block", {0.726807971, 0.32, 0.53}, {0, 1.05, 1.6}, {24, 99, 108}, "Metal", {0, 0, 0}},
            {"RearRing", "Collar1", "Block", {0.726807971, 0.32, 0.53}, {0.617174515, 0.849467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -36}},
            {"RearRing", "Collar2", "Block", {0.726807971, 0.32, 0.53}, {0.998609342, 0.324467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -72}},
            {"RearRing", "Collar3", "Block", {0.726807971, 0.32, 0.53}, {0.998609342, -0.324467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -108}},
            {"RearRing", "Collar4", "Block", {0.726807971, 0.32, 0.53}, {0.617174515, -0.849467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -144}},
            {"RearRing", "Collar5", "Block", {0.726807971, 0.32, 0.53}, {1.28587914e-16, -1.05, 1.6}, {24, 99, 108}, "Metal", {0, 0, -180}},
            {"RearRing", "Collar6", "Block", {0.726807971, 0.32, 0.53}, {-0.617174515, -0.849467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -216}},
            {"RearRing", "Collar7", "Block", {0.726807971, 0.32, 0.53}, {-0.998609342, -0.324467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -252}},
            {"RearRing", "Collar8", "Block", {0.726807971, 0.32, 0.53}, {-0.998609342, 0.324467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -288}},
            {"RearRing", "Collar9", "Block", {0.726807971, 0.32, 0.53}, {-0.617174515, 0.849467844, 1.6}, {24, 99, 108}, "Metal", {0, 0, -324}},
            {"RearRing", "RearRim0", "Block", {0.761417874, 0.32, 0.57}, {0, 1.1, 2.09}, {4, 164, 171}, "Metal", {0, 0, 0}},
            {"RearRing", "RearRim1", "Block", {0.761417874, 0.32, 0.57}, {0.646563778, 0.889918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -36}},
            {"RearRing", "RearRim2", "Block", {0.761417874, 0.32, 0.57}, {1.04616217, 0.339918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -72}},
            {"RearRing", "RearRim3", "Block", {0.761417874, 0.32, 0.57}, {1.04616217, -0.339918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -108}},
            {"RearRing", "RearRim4", "Block", {0.761417874, 0.32, 0.57}, {0.646563778, -0.889918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -144}},
            {"RearRing", "RearRim5", "Block", {0.761417874, 0.32, 0.57}, {1.34711148e-16, -1.1, 2.09}, {4, 164, 171}, "Metal", {0, 0, -180}},
            {"RearRing", "RearRim6", "Block", {0.761417874, 0.32, 0.57}, {-0.646563778, -0.889918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -216}},
            {"RearRing", "RearRim7", "Block", {0.761417874, 0.32, 0.57}, {-1.04616217, -0.339918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -252}},
            {"RearRing", "RearRim8", "Block", {0.761417874, 0.32, 0.57}, {-1.04616217, 0.339918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -288}},
            {"RearRing", "RearRim9", "Block", {0.761417874, 0.32, 0.57}, {-0.646563778, 0.889918694, 2.09}, {4, 164, 171}, "Metal", {0, 0, -324}},
            {"RearRing", "RimLip0", "Block", {0.685276087, 0.32, 0.26}, {0, 0.99, 2.47}, {24, 201, 199}, "Metal", {0, 0, 0}},
            {"RearRing", "RimLip1", "Block", {0.685276087, 0.32, 0.26}, {0.5819074, 0.800926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -36}},
            {"RearRing", "RimLip2", "Block", {0.685276087, 0.32, 0.26}, {0.941545951, 0.305926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -72}},
            {"RearRing", "RimLip3", "Block", {0.685276087, 0.32, 0.26}, {0.941545951, -0.305926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -108}},
            {"RearRing", "RimLip4", "Block", {0.685276087, 0.32, 0.26}, {0.5819074, -0.800926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -144}},
            {"RearRing", "RimLip5", "Block", {0.685276087, 0.32, 0.26}, {1.21240033e-16, -0.99, 2.47}, {24, 201, 199}, "Metal", {0, 0, -180}},
            {"RearRing", "RimLip6", "Block", {0.685276087, 0.32, 0.26}, {-0.5819074, -0.800926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -216}},
            {"RearRing", "RimLip7", "Block", {0.685276087, 0.32, 0.26}, {-0.941545951, -0.305926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -252}},
            {"RearRing", "RimLip8", "Block", {0.685276087, 0.32, 0.26}, {-0.941545951, 0.305926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -288}},
            {"RearRing", "RimLip9", "Block", {0.685276087, 0.32, 0.26}, {-0.5819074, 0.800926824, 2.47}, {24, 201, 199}, "Metal", {0, 0, -324}},
            {"RearRing", "Recess", "Cylinder", {0.15, 1.66, 1.66}, {0, 0, 2.01}, {10, 65, 76}, "Metal", {0, 90, 0}},
            {"RearRing", "TurbineHub", "Cylinder", {0.1, 0.6, 0.6}, {0, 0, 2.14}, {73, 221, 225}, "Neon", {0, 90, 0}},
        },
        points = {PathMount = {0, 0, 0}, NoseDirection = {0, 0, -2.6}, Exhaust = {0, 0, 2.5}, TrailOrigin = {0, 0, 2.53}, ImpactVFX = {0, 0, -2.45}, BoundsCenter = {0, 0, 0}},
    },
    Meteorite = {
        parts = {
            {"HotCore", "GoldenLimb", "Ball", {2.49, 2.49, 2.3}, {0, 0, 0.24}, {255, 186, 30}, "SmoothPlastic", {0, 0, 0}},
            {"HotCore", "WhiteFront", "Ball", {2.46, 2.46, 2.5}, {0, 0, 0}, {255, 249, 176}, "Neon", {0, 0, 0}},
            {"HotCore", "Dimple0", "Ball", {0.22, 0.286, 0.076}, {0.877633721, 0.268422436, -0.83222242}, {233, 164, 36}, "SmoothPlastic", {12.6050715, -46.9825392, 0}},
            {"HotCore", "Dimple1", "Ball", {0.14, 0.182, 0.076}, {0.430717365, -0.478984561, -1.06487207}, {233, 164, 36}, "SmoothPlastic", {-22.9183118, -22.345354, 0}},
            {"HotCore", "Dimple2", "Ball", {0.23, 0.299, 0.076}, {-0.60614103, 0.674069442, -0.844856039}, {233, 164, 36}, "SmoothPlastic", {33.2315521, 36.0963411, 0}},
            {"HotCore", "Dimple3", "Ball", {0.18, 0.234, 0.076}, {-0.7768309, -0.30430687, -0.918482802}, {233, 164, 36}, "SmoothPlastic", {-14.3239449, 40.6800035, 0}},
            {"HotCore", "Dimple4", "Ball", {0.1, 0.13, 0.076}, {-0.303926566, 0.0614743782, -1.20962692}, {233, 164, 36}, "SmoothPlastic", {2.86478898, 14.3239449, 0}},
            {"HotCore", "Dimple5", "Ball", {0.12, 0.156, 0.076}, {0.207852799, 0.865033686, -0.863171645}, {233, 164, 36}, "SmoothPlastic", {44.690708, -13.7509871, 0}},
            {"HotCore", "Dimple6", "Ball", {0.14, 0.182, 0.076}, {-0.156001691, -0.744379279, -0.982394557}, {233, 164, 36}, "SmoothPlastic", {-37.2422567, 9.16732472, 0}},
            {"FlameShell", "Tongue0_0", "Ball", {0.78, 0.7098, 1.386}, {0.78, 0, 0.48}, {255, 197, 43}, "SmoothPlastic", {-0, 9, 0}},
            {"FlameShell", "Tongue0_1", "Ball", {0.59, 0.5369, 1.26231}, {0.876811371, 0.0982604182, 1.131}, {255, 197, 43}, "SmoothPlastic", {-1.0023164, 8.94401262, 0}},
            {"FlameShell", "Tongue0_2", "Ball", {0.37, 0.3367, 1.15857}, {0.947789505, 0.197262929, 1.677}, {255, 197, 43}, "SmoothPlastic", {-1.83386671, 8.81118226, 0}},
            {"FlameShell", "Tongue0_3", "Ball", {0.2, 0.182, 1.0668}, {1.00100167, 0.296532714, 2.16}, {255, 197, 43}, "SmoothPlastic", {-2.5563165, 8.62932477, 0}},
            {"FlameShell", "Tongue1_0", "Ball", {0.78, 0.7098, 1.6236}, {0.551543289, 0.551543289, 0.48}, {255, 218, 64}, "SmoothPlastic", {-6.36396103, 6.36396103, 0}},
            {"FlameShell", "Tongue1_1", "Ball", {0.59, 0.5369, 1.478706}, {0.550518658, 0.689479874, 1.2426}, {255, 218, 64}, "SmoothPlastic", {-7.0331167, 5.61562725, 0}},
            {"FlameShell", "Tongue1_2", "Ball", {0.37, 0.3367, 1.357182}, {0.530702431, 0.809674341, 1.8822}, {255, 218, 64}, "SmoothPlastic", {-7.52718632, 4.93370714, 0}},
            {"FlameShell", "Tongue1_3", "Ball", {0.2, 0.182, 1.24968}, {0.498134778, 0.917495364, 2.448}, {255, 218, 64}, "SmoothPlastic", {-7.90944279, 4.29426533, 0}},
            {"FlameShell", "Tongue2_0", "Ball", {0.78, 0.7098, 1.221}, {4.77612252e-17, 0.78, 0.48}, {250, 162, 21}, "SmoothPlastic", {-9, 5.5109106e-16, 0}},
            {"FlameShell", "Tongue2_1", "Ball", {0.59, 0.5369, 1.112035}, {-0.0982604182, 0.876811371, 1.0535}, {250, 162, 21}, "SmoothPlastic", {-8.94401262, -1.0023164, 0}},
            {"FlameShell", "Tongue2_2", "Ball", {0.37, 0.3367, 1.020645}, {-0.197262929, 0.947789505, 1.5345}, {250, 162, 21}, "SmoothPlastic", {-8.81118226, -1.83386671, 0}},
            {"FlameShell", "Tongue2_3", "Ball", {0.2, 0.182, 0.9398}, {-0.296532714, 1.00100167, 1.96}, {250, 162, 21}, "SmoothPlastic", {-8.62932477, -2.5563165, 0}},
            {"FlameShell", "Tongue3_0", "Ball", {0.78, 0.7098, 1.518}, {-0.551543289, 0.551543289, 0.48}, {255, 197, 43}, "SmoothPlastic", {-6.36396103, -6.36396103, 0}},
            {"FlameShell", "Tongue3_1", "Ball", {0.59, 0.5369, 1.38253}, {-0.689479874, 0.550518658, 1.193}, {255, 197, 43}, "SmoothPlastic", {-5.61562725, -7.0331167, 0}},
            {"FlameShell", "Tongue3_2", "Ball", {0.37, 0.3367, 1.26891}, {-0.809674341, 0.530702431, 1.791}, {255, 197, 43}, "SmoothPlastic", {-4.93370714, -7.52718632, 0}},
            {"FlameShell", "Tongue3_3", "Ball", {0.2, 0.182, 1.1684}, {-0.917495364, 0.498134778, 2.32}, {255, 197, 43}, "SmoothPlastic", {-4.29426533, -7.90944279, 0}},
            {"FlameShell", "Tongue4_0", "Ball", {0.78, 0.7098, 1.7028}, {-0.78, 9.55224503e-17, 0.48}, {255, 218, 64}, "SmoothPlastic", {-1.10218212e-15, -9, 0}},
            {"FlameShell", "Tongue4_1", "Ball", {0.59, 0.5369, 1.550838}, {-0.876811371, -0.0982604182, 1.2798}, {255, 218, 64}, "SmoothPlastic", {1.0023164, -8.94401262, 0}},
            {"FlameShell", "Tongue4_2", "Ball", {0.37, 0.3367, 1.423386}, {-0.947789505, -0.197262929, 1.9506}, {255, 218, 64}, "SmoothPlastic", {1.83386671, -8.81118226, 0}},
            {"FlameShell", "Tongue4_3", "Ball", {0.2, 0.182, 1.31064}, {-1.00100167, -0.296532714, 2.544}, {255, 218, 64}, "SmoothPlastic", {2.5563165, -8.62932477, 0}},
            {"FlameShell", "Tongue5_0", "Ball", {0.78, 0.7098, 1.3728}, {-0.551543289, -0.551543289, 0.48}, {250, 162, 21}, "SmoothPlastic", {6.36396103, -6.36396103, 0}},
            {"FlameShell", "Tongue5_1", "Ball", {0.59, 0.5369, 1.250288}, {-0.550518658, -0.689479874, 1.1248}, {250, 162, 21}, "SmoothPlastic", {7.0331167, -5.61562725, 0}},
            {"FlameShell", "Tongue5_2", "Ball", {0.37, 0.3367, 1.147536}, {-0.530702431, -0.809674341, 1.6656}, {250, 162, 21}, "SmoothPlastic", {7.52718632, -4.93370714, 0}},
            {"FlameShell", "Tongue5_3", "Ball", {0.2, 0.182, 1.05664}, {-0.498134778, -0.917495364, 2.144}, {250, 162, 21}, "SmoothPlastic", {7.90944279, -4.29426533, 0}},
            {"FlameShell", "Tongue6_0", "Ball", {0.78, 0.7098, 1.5576}, {-1.43283676e-16, -0.78, 0.48}, {255, 197, 43}, "SmoothPlastic", {9, -1.65327318e-15, 0}},
            {"FlameShell", "Tongue6_1", "Ball", {0.59, 0.5369, 1.418596}, {0.0982604182, -0.876811371, 1.2116}, {255, 197, 43}, "SmoothPlastic", {8.94401262, 1.0023164, 0}},
            {"FlameShell", "Tongue6_2", "Ball", {0.37, 0.3367, 1.302012}, {0.197262929, -0.947789505, 1.8252}, {255, 197, 43}, "SmoothPlastic", {8.81118226, 1.83386671, 0}},
            {"FlameShell", "Tongue6_3", "Ball", {0.2, 0.182, 1.19888}, {0.296532714, -1.00100167, 2.368}, {255, 197, 43}, "SmoothPlastic", {8.62932477, 2.5563165, 0}},
            {"FlameShell", "Tongue7_0", "Ball", {0.78, 0.7098, 1.2936}, {0.551543289, -0.551543289, 0.48}, {255, 218, 64}, "SmoothPlastic", {6.36396103, 6.36396103, 0}},
            {"FlameShell", "Tongue7_1", "Ball", {0.59, 0.5369, 1.178156}, {0.689479874, -0.550518658, 1.0876}, {255, 218, 64}, "SmoothPlastic", {5.61562725, 7.0331167, 0}},
            {"FlameShell", "Tongue7_2", "Ball", {0.37, 0.3367, 1.081332}, {0.809674341, -0.530702431, 1.5972}, {255, 218, 64}, "SmoothPlastic", {4.93370714, 7.52718632, 0}},
            {"FlameShell", "Tongue7_3", "Ball", {0.2, 0.182, 0.99568}, {0.917495364, -0.498134778, 2.048}, {255, 218, 64}, "SmoothPlastic", {4.29426533, 7.90944279, 0}},
            {"FlameShell", "CentralFlare", "Ball", {1.5, 1.52, 3.22}, {0.08, 0.02, 1.33}, {255, 222, 67}, "SmoothPlastic", {1, 3, 0}},
            {"FlameShell", "LongFlare", "Ball", {0.47, 0.38, 2.2}, {0.1, 0.19, 2.59}, {255, 194, 36}, "SmoothPlastic", {-5, -5, 0}},
        },
        points = {FlightCenter = {0, 0, 0}, Forward = {0, 0, -1.25}, TrailOrigin = {0, 0, 2.05}, ImpactVFX = {0, 0, -1.2}, AudioOrigin = {0, 0, 0}},
    },
}
-- END OF GENERATED DESIGNS

local AirHazardModels = {}
local V = Vector3.new

local function frame(position, angles)
    local transform = CFrame.new(table.unpack(position))
    if angles then
        transform *= CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
    end
    return transform
end

local function cosmetic(part)
    part.Anchored = false
    part.Massless = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
end

local function weld(parent, child)
    local joint = Instance.new("WeldConstraint")
    joint.Part0 = parent
    joint.Part1 = child
    joint.Parent = child
end

local function point(parent, name, offset)
    local node = Instance.new("Attachment")
    node.Name = name
    node.CFrame = offset
    node.Parent = parent
    return node
end

local function effects(kind, root)
    local fiery = kind == "Meteorite"
    local origin = root.TrailOrigin.CFrame
    local width = fiery and .38 or .18
    local trail = Instance.new("Trail")
    trail.Name = "TrailEmitter"
    trail.Attachment0 = point(root, "TrailLeft", origin * CFrame.new(-width, 0, 0))
    trail.Attachment1 = point(root, "TrailRight", origin * CFrame.new(width, 0, 0))
    trail.Color = ColorSequence.new(fiery and Color3.fromRGB(255, 218, 61) or Color3.fromRGB(85, 229, 233))
    trail.Transparency = NumberSequence.new(.30, 1)
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.LightEmission = .7
    trail.FaceCamera = true
    trail.Lifetime = fiery and .14 or .10
    trail.MaxLength = fiery and 1.6 or 1
    trail.Parent = root
    if fiery then
        local burst = Instance.new("ParticleEmitter")
        burst.Name = "ImpactBurst"
        burst.Enabled = false
        burst.Rate = 0
        burst.Lifetime = NumberRange.new(.12, .24)
        burst.Speed = NumberRange.new(2, 5)
        burst.SpreadAngle = Vector2.new(180, 180)
        burst.LightEmission = 1
        burst.Color = ColorSequence.new(Color3.fromRGB(255, 243, 137), Color3.fromRGB(255, 153, 27))
        burst.Size = NumberSequence.new(.34, 0)
        burst.Transparency = NumberSequence.new(.12, 1)
        burst.Parent = root.ImpactVFX
    end
end

-- The owner controls the hazard transform and lifetime. The fixed local nose is -Z.
function AirHazardModels.attach(kind, parent, anchor)
    local design = designs[kind]
    if not design then return nil end
    local model = Instance.new("Model")
    model.Name = kind
    local root = Instance.new("Part")
    root.Name = "VisualRoot"
    cosmetic(root)
    root.Size = V(.1, .1, .1)
    root.Transparency = 1
    root.CFrame = anchor.CFrame
    root.Parent = model
    model.PrimaryPart = root
    local mount = Instance.new("Weld")
    mount.Name = "PathJoint"
    mount.Part0 = anchor
    mount.Part1 = root
    mount.Parent = root
    for _, spec in ipairs(design.parts) do
        local section, name, shape, size, pos, color, material, angles = table.unpack(spec)
        local group = model:FindFirstChild(section)
        if not group then
            group = Instance.new("Model")
            group.Name = section
            group.Parent = model
        end
        local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
        if part:IsA("Part") then part.Shape = Enum.PartType[shape] end
        cosmetic(part)
        part.Name = name
        part.Size = V(table.unpack(size))
        part.Color = Color3.fromRGB(table.unpack(color))
        part.Material = Enum.Material[material]
        part.CFrame = root.CFrame * frame(pos, angles)
        part.Parent = group
        weld(root, part)
    end
    for name, pos in pairs(design.points) do
        local transform = frame(pos)
        if name == "Exhaust" then transform *= CFrame.Angles(0, math.pi, 0) end
        point(root, name, transform)
    end
    effects(kind, root)
    model.Parent = parent
    return model
end

-- Rotate only the visual mount when the course proxy keeps its original orientation.
function AirHazardModels.face(model, velocity)
    if velocity.Magnitude < .001 then return end
    local joint = model.PrimaryPart.PathJoint
    local direction = joint.Part0.CFrame:VectorToObjectSpace(velocity.Unit)
    local up = math.abs(direction.Y) > .99 and Vector3.xAxis or Vector3.yAxis
    joint.C0 = CFrame.lookAt(Vector3.zero, direction, up)
end

-- Single finite impact effect. Destroying the model also removes every effect.
function AirHazardModels.impact(model)
    if model:GetAttribute("ImpactShown") then return end
    model:SetAttribute("ImpactShown", true)
    local root = model.PrimaryPart
    root.TrailEmitter.Enabled = false
    local burst = root.ImpactVFX:FindFirstChild("ImpactBurst")
    if burst then burst:Emit(8) end
end

return AirHazardModels
