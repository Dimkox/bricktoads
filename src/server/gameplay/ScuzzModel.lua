-- BT-88. Articulated local-asset fallback for the common group rat.
-- Regenerate these tables with assets/models/Scuzz/runtime_data.py.
local V = Vector3.new
local colors = {
    ember = Color3.fromRGB(183, 83, 26),
    gold = Color3.fromRGB(223, 126, 43),
    cream = Color3.fromRGB(250, 181, 84),
    shade = Color3.fromRGB(126, 56, 29),
    mane = Color3.fromRGB(37, 29, 28),
    black = Color3.fromRGB(22, 22, 25),
    inner = Color3.fromRGB(173, 86, 64),
    tooth = Color3.fromRGB(254, 225, 166),
    eye = Color3.fromRGB(248, 190, 70),
}
local pivots = {
    {"Pelvis", "", V(0, 1.28, 0.23)},
    {"Chest", "Pelvis", V(0, 1.94, 0.18)},
    {"Head", "Chest", V(0, 2.97, 0.09)},
    {"Jaw", "Head", V(0, 3.28, -0.34)},
    {"Arm_L", "Chest", V(-0.4, 2.71, 0.13)},
    {"Elbow_L", "Arm_L", V(-0.78, 2.23, 0.24)},
    {"Hand_L", "Elbow_L", V(-0.77, 2.29, -0.34)},
    {"Leg_L", "Pelvis", V(-0.37, 1.53, 0.23)},
    {"Foot_L", "Leg_L", V(-0.63, 0.33, 0.48)},
    {"Arm_R", "Chest", V(0.4, 2.71, 0.13)},
    {"Elbow_R", "Arm_R", V(0.78, 2.23, 0.24)},
    {"Hand_R", "Elbow_R", V(0.77, 2.29, -0.34)},
    {"Leg_R", "Pelvis", V(0.37, 1.53, 0.23)},
    {"Foot_R", "Leg_R", V(0.63, 0.33, 0.48)},
}
local sockets = {
    {"MuzzleAim", "Head", V(0, 3.32, -1.56)},
    {"StrikeOrigin", "Hand_R", V(0.78, 1.99, -0.58)},
    {"JumpCenter", "Pelvis", V(0, 1.45, 0.21)},
    {"VfxHit", "Chest", V(0, 2.49, 0.08)},
    {"Ground_L", "Foot_L", V(-0.62, 0.015, -0.32)},
    {"Ground_R", "Foot_R", V(0.62, 0.015, -0.32)},
}
-- Each section spans a start and end point with a transverse width and depth.
local shapes = {
    {"Haunch", "Pelvis", "ember", V(0, 0.76, 0.22), V(0, 2.15, 0.21), 1.24, 0.94, false},
    {"Mantle", "Chest", "gold", V(0, 1.65, 0.23), V(0, 3.08, 0.03), 1.06, 0.78, false},
    {"Bib", "Chest", "cream", V(0, 1.6855, -0.0406), V(0, 2.7789, -0.1599), 0.64, 0.34, false},
    {"Skull", "Head", "gold", V(0, 2.994, 0.1892), V(0, 3.7792, 0.0302), 0.98, 0.86, false},
    {"Bridge", "Head", "gold", V(0, 3.48, -0.13), V(0, 3.31, -1.1), 0.9, 0.62, false},
    {"Snout", "Head", "gold", V(0, 3.39, -0.78), V(0, 3.31, -1.38), 0.7, 0.4, false},
    {"Nose", "Head", "black", V(0, 3.3002, -1.3511), V(0, 3.35, -1.5698), 0.29, 0.214, false},
    {"Mouth", "Jaw", "shade", V(0, 3.23, -0.3345), V(0, 3.23, -1.2191), 0.62, 0.22, false},
    {"Chin", "Jaw", "cream", V(0, 3.1502, -0.3439), V(0, 3.2, -1.1192), 0.56, 0.2, false},
    {"Crown0", "Head", "mane", V(-0.2, 3.69, 0.03), V(-0.12, 4.46, 0.59), 0.28, 0.32, true},
    {"Crown1", "Head", "mane", V(-0.1, 3.69, 0.03), V(-0.06, 4.31, 0.87), 0.34, 0.32, true},
    {"Crown2", "Head", "mane", V(0.04, 3.69, 0.03), V(0.07, 4.14, 0.96), 0.32, 0.32, true},
    {"Crown3", "Head", "mane", V(0.19, 3.69, 0.03), V(0.28, 4.28, 0.66), 0.24, 0.32, true},
    {"Crown4", "Head", "mane", V(0.27, 3.69, 0.03), V(0.41, 4.09, 0.53), 0.2, 0.32, true},
    {"Spine0", "Chest", "shade", V(0, 2.76, 0.39), V(0, 2.4, 0.73), 0.34, 0.24, true},
    {"Spine1", "Chest", "shade", V(0, 2.48, 0.39), V(0, 2.12, 0.73), 0.34, 0.24, true},
    {"Spine2", "Chest", "shade", V(0, 2.2, 0.39), V(0, 1.84, 0.73), 0.34, 0.24, true},
    {"Spine3", "Chest", "shade", V(0, 1.92, 0.39), V(0, 1.56, 0.73), 0.34, 0.24, true},
    {"ThighL", "Leg_L", "gold", V(-0.3915, 1.5256, 0.2983), V(-0.6797, 0.6609, -0.0496), 0.76, 0.76, false},
    {"HockL", "Leg_L", "ember", V(-0.6599, 0.8275, -0.0076), V(-0.63, 0.3305, 0.4795), 0.48, 0.44, false},
    {"FootL", "Foot_L", "gold", V(-0.6102, 0.2695, 0.5345), V(-0.65, 0.1701, -0.5689), 0.62, 0.368, false},
    {"ToeL0", "Foot_L", "cream", V(-0.4702, 0.1697, -0.2423), V(-0.505, 0.1081, -0.7095), 0.202, 0.184, false},
    {"ToeL1", "Foot_L", "cream", V(-0.6402, 0.1697, -0.2428), V(-0.675, 0.1081, -0.7994), 0.202, 0.184, false},
    {"ToeL2", "Foot_L", "cream", V(-0.8102, 0.1697, -0.2423), V(-0.845, 0.1081, -0.7095), 0.202, 0.184, false},
    {"ShoulderL", "Arm_L", "gold", V(-0.4019, 2.7076, 0.1305), V(-0.7796, 2.2305, 0.2399), 0.5, 0.49, false},
    {"ForearmL", "Elbow_L", "ember", V(-0.78, 2.2303, 0.2371), V(-0.77, 2.2899, -0.3394), 0.332, 0.36, false},
    {"KnucklesL", "Hand_L", "gold", V(-0.7701, 2.2895, -0.3411), V(-0.79, 2.1901, -0.5498), 0.316, 0.28, false},
    {"DigitL0", "Hand_L", "cream", V(-0.68, 2.24, -0.44), V(-0.708, 1.99, -0.5), 0.104, 0.11, true},
    {"DigitL1", "Hand_L", "cream", V(-0.77, 2.24, -0.44), V(-0.798, 2.004, -0.5), 0.104, 0.11, true},
    {"DigitL2", "Hand_L", "cream", V(-0.86, 2.24, -0.44), V(-0.888, 2.018, -0.5), 0.104, 0.11, true},
    {"EarL", "Head", "ember", V(-0.3807, 3.4121, 0.1703), V(-0.5199, 3.8296, 0.2299), 0.32, 0.28, false},
    {"EarCupL", "Head", "inner", V(-0.4805, 3.5112, 0.1103), V(-0.5749, 3.7597, 0.16), 0.184, 0.15, false},
    {"EyeRimL", "Head", "shade", V(-0.3253, 3.4408, -0.6387), V(-0.3829, 3.5998, -0.3803), 0.254, 0.224, false},
    {"EyeL", "Head", "eye", V(-0.3523, 3.4606, -0.629), V(-0.4069, 3.5699, -0.4302), 0.216, 0.174, false},
    {"PupilL", "Head", "black", V(-0.4101, 3.4705, -0.5898), V(-0.425, 3.5699, -0.55), 0.098, 0.102, false},
    {"BrowL", "Head", "mane", V(-0.31, 3.52, -0.74), V(-0.5, 3.76, -0.14), 0.188, 0.156, true},
    {"CheekL0", "Head", "ember", V(-0.33, 3.55, -0.06), V(-0.53, 3.42, 0.47), 0.18, 0.28, true},
    {"CheekL2", "Head", "ember", V(-0.33, 3.29, -0.06), V(-0.53, 3.16, 0.47), 0.18, 0.28, true},
    {"WhiskerL1", "Head", "mane", V(-0.11, 3.31, -1.3), V(-0.53, 3.294, -1.185), 0.024, 0.024, false},
    {"RuffL1", "Chest", "ember", V(-0.34, 2.49, 0.13), V(-0.55, 2.21, 0.41), 0.21, 0.2, true},
    {"ThighR", "Leg_R", "gold", V(0.3915, 1.5256, 0.2983), V(0.6797, 0.6609, -0.0496), 0.76, 0.76, false},
    {"HockR", "Leg_R", "ember", V(0.6599, 0.8275, -0.0076), V(0.63, 0.3305, 0.4795), 0.48, 0.44, false},
    {"FootR", "Foot_R", "gold", V(0.6102, 0.2695, 0.5345), V(0.65, 0.1701, -0.5689), 0.62, 0.368, false},
    {"ToeR0", "Foot_R", "cream", V(0.4702, 0.1697, -0.2423), V(0.505, 0.1081, -0.7095), 0.202, 0.184, false},
    {"ToeR1", "Foot_R", "cream", V(0.6402, 0.1697, -0.2428), V(0.675, 0.1081, -0.7994), 0.202, 0.184, false},
    {"ToeR2", "Foot_R", "cream", V(0.8102, 0.1697, -0.2423), V(0.845, 0.1081, -0.7095), 0.202, 0.184, false},
    {"ShoulderR", "Arm_R", "gold", V(0.4019, 2.7076, 0.1305), V(0.7796, 2.2305, 0.2399), 0.5, 0.49, false},
    {"ForearmR", "Elbow_R", "ember", V(0.78, 2.2303, 0.2371), V(0.77, 2.2899, -0.3394), 0.332, 0.36, false},
    {"KnucklesR", "Hand_R", "gold", V(0.7701, 2.2895, -0.3411), V(0.79, 2.1901, -0.5498), 0.316, 0.28, false},
    {"DigitR0", "Hand_R", "cream", V(0.68, 2.24, -0.44), V(0.708, 1.99, -0.5), 0.104, 0.11, true},
    {"DigitR1", "Hand_R", "cream", V(0.77, 2.24, -0.44), V(0.798, 2.004, -0.5), 0.104, 0.11, true},
    {"DigitR2", "Hand_R", "cream", V(0.86, 2.24, -0.44), V(0.888, 2.018, -0.5), 0.104, 0.11, true},
    {"EarR", "Head", "ember", V(0.3807, 3.4121, 0.1703), V(0.5199, 3.8296, 0.2299), 0.32, 0.28, false},
    {"EarCupR", "Head", "inner", V(0.4805, 3.5112, 0.1103), V(0.5749, 3.7597, 0.16), 0.184, 0.15, false},
    {"EyeRimR", "Head", "shade", V(0.3253, 3.4408, -0.6387), V(0.3829, 3.5998, -0.3803), 0.254, 0.224, false},
    {"EyeR", "Head", "eye", V(0.3523, 3.4606, -0.629), V(0.4069, 3.5699, -0.4302), 0.216, 0.174, false},
    {"PupilR", "Head", "black", V(0.4101, 3.4705, -0.5898), V(0.425, 3.5699, -0.55), 0.098, 0.102, false},
    {"BrowR", "Head", "mane", V(0.31, 3.52, -0.74), V(0.5, 3.76, -0.14), 0.188, 0.156, true},
    {"CheekR0", "Head", "ember", V(0.33, 3.55, -0.06), V(0.53, 3.42, 0.47), 0.18, 0.28, true},
    {"CheekR2", "Head", "ember", V(0.33, 3.29, -0.06), V(0.53, 3.16, 0.47), 0.18, 0.28, true},
    {"WhiskerR1", "Head", "mane", V(0.11, 3.31, -1.3), V(0.53, 3.294, -1.185), 0.024, 0.024, false},
    {"RuffR1", "Chest", "ember", V(0.34, 2.49, 0.13), V(0.55, 2.21, 0.41), 0.21, 0.2, true},
}
local poses = {
    Appear = {Pelvis = V(-12, 0, 0), Head = V(12, 13, 0), Arm_L = V(-31, 0, -20)},
    IdleAlert = {Chest = V(-4, 0, 0), Head = V(4, 10, -4), Jaw = V(5, 0, 0)},
    Step = {Leg_L = V(22, 0, 0), Leg_R = V(-22, 0, 0), Arm_L = V(-20, 0, 0), Arm_R = V(20, 0, 0), Foot_L = V(-12, 0, 0), Foot_R = V(12, 0, 0)},
    GroupAdvance = {Chest = V(-10, 0, 0), Leg_L = V(28, 0, 0), Leg_R = V(-28, 0, 0), Arm_L = V(-26, 0, 0), Arm_R = V(26, 0, 0), Head = V(4, -12, 0)},
    Turn = {Pelvis = V(0, 16, 0), Chest = V(0, 20, 0), Head = V(0, 19, 0), Leg_R = V(12, 0, 0)},
    Hop = {Chest = V(-14, 0, 0), Leg_L = V(-32, 0, 0), Leg_R = V(-32, 0, 0), Arm_L = V(-31, 0, -12), Arm_R = V(-31, 0, 12)},
    Fall = {Head = V(14, 0, 0), Arm_L = V(8, 0, -41), Arm_R = V(8, 0, 41), Leg_L = V(20, 0, 0), Leg_R = V(-12, 0, 0)},
    Land = {Chest = V(-26, 0, 0), Leg_L = V(-27, 0, 0), Leg_R = V(-27, 0, 0), Head = V(19, 0, 0)},
    Attack66 = {Chest = V(-19, -24, 0), Arm_R = V(64, -12, 14), Elbow_R = V(31, 0, 0), Arm_L = V(-30, 0, 0), Head = V(13, 18, 0), Jaw = V(15, 0, 0)},
    Attack68 = {Chest = V(-24, 8, 0), Arm_L = V(47, 0, -24), Arm_R = V(47, 0, 24), Leg_L = V(-30, 0, 0), Leg_R = V(-42, 0, 0), Head = V(16, 0, 0), Jaw = V(21, 0, 0)},
    Recover = {Chest = V(10, 11, 0), Arm_R = V(-20, 0, 0), Head = V(-8, -7, 0)},
    ReactLight = {Head = V(19, 12, -9), Chest = V(12, 0, 0), Arm_L = V(-15, 0, -22)},
    ReactHeavyGround = {Pelvis = V(-85, 0, -8), Chest = V(-5, 0, 0), Head = V(59, 0, 0), Arm_L = V(29, 0, -24), Arm_R = V(29, 0, 24)},
    HeavyRecover = {Pelvis = V(-85, 0, -8), Chest = V(-5, 0, 0), Head = V(59, 0, 0), Arm_L = V(29, 0, -24), Arm_R = V(29, 0, 24)},
    DeathAir = {Pelvis = V(24, 9, 30), Chest = V(19, 0, 0), Arm_L = V(-26, 0, -48), Arm_R = V(23, 0, 37)},
    DeathGround = {Pelvis = V(2, 0, 77), Chest = V(21, 0, 0), Head = V(-13, 0, -7), Leg_R = V(21, 0, 0)},
    Remove = {Pelvis = V(2, 0, 77), Chest = V(21, 0, 0), Head = V(-13, 0, -7), Leg_R = V(21, 0, 0)},
}
local envelopes = {
    Appear = {{0, 0}, {0.5, 1}, {1, 0}},
    IdleAlert = {{0, 0}, {0.25, 1}, {0.5, 0}, {0.75, -1}, {1, 0}},
    Step = {{0, 0}, {0.25, 1}, {0.5, 0}, {0.75, -1}, {1, 0}},
    GroupAdvance = {{0, 0}, {0.25, 1}, {0.5, 0}, {0.75, -1}, {1, 0}},
    Turn = {{0, 0}, {0.5, 1}, {1, 0}},
    Hop = {{0, 0}, {0.5, 1}, {1, 0}},
    Fall = {{0, 0}, {0.5, 1}, {1, 0}},
    Land = {{0, 0}, {0.5, 1}, {1, 0}},
    Attack66 = {{0, 0}, {0.1905, -0.32}, {0.381, 1}, {0.5714, 0.18}, {0.7619, 0.9}, {1, 0}},
    Attack68 = {{0, 0}, {0.2083, -0.48}, {0.4583, 1}, {0.7083, 0.64}, {1, 0}},
    Recover = {{0, 0}, {0.5, 1}, {1, 0}},
    ReactLight = {{0, 0}, {0.5, 1}, {1, 0}},
    ReactHeavyGround = {{0, 0}, {0.4667, 1}, {1, 1}},
    HeavyRecover = {{0, 1}, {0.4, 0.7}, {1, 0}},
    DeathAir = {{0, 0}, {0.4667, 1}, {1, 1}},
    DeathGround = {{0, 0}, {0.4667, 1}, {1, 1}},
    Remove = {{0, 1}, {1, 1}},
}
local floorTracks = {
    Appear = {0.0016, 0.0156, 0.0445, 0.0728, 0.0995, 0.1246, 0.148, 0.1246, 0.0995, 0.0728, 0.0445, 0.0156, 0.0016},
    IdleAlert = {0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016},
    Step = {0.0016, 0.0002, 0.0088, 0.0142, 0.0146, 0.0101, 0.001, 0.0101, 0.0146, 0.0142, 0.0088, 0.0002, 0.0016, 0.0005, 0.0091, 0.0145, 0.015, 0.0106, 0.0014, 0.0106, 0.015, 0.0145, 0.0091, 0.0005, 0.0016},
    GroupAdvance = {0.0016, 0.053, 0.1127, 0.1617, 0.1997, 0.2339, 0.2568, 0.2339, 0.1997, 0.1617, 0.1127, 0.053, 0.0016, 0.0533, 0.1131, 0.1623, 0.2004, 0.2343, 0.2572, 0.2343, 0.2004, 0.1623, 0.1131, 0.0533, 0.0016},
    Turn = {0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016},
    Hop = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    Fall = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    Land = {0.0016, 0.051, 0.1092, 0.1575, 0.1957, 0.2289, 0.2533, 0.2289, 0.1957, 0.1575, 0.1092, 0.051, 0.0016},
    Attack66 = {0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016},
    Attack68 = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    Recover = {0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016},
    ReactLight = {0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016, 0.0016},
    ReactHeavyGround = {0.0016, 0.1624, 0.2875, 0.3554, 0.3526, 0.2859, 0.1537, -0.0367, -0.0367, -0.0367, -0.0367, -0.0367, -0.0367, -0.0367, -0.0367, -0.0367},
    HeavyRecover = {-0.0367, 0.0358, 0.1021, 0.1617, 0.2141, 0.2588, 0.2956, 0.3366, 0.3585, 0.3616, 0.3436, 0.3047, 0.2453, 0.1754, 0.0881, 0.0016},
    DeathAir = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    DeathGround = {0.0016, 0.1191, 0.2111, 0.25, 0.2346, 0.1742, 0.0668, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876},
    Remove = {-0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876, -0.0876},
}
-- END SCULPT DATA

local Scuzz = {}

local function cosmetic(kind, name, parent)
    local part = Instance.new(kind)
    part.Name = name
    part.Anchored = false
    part.Massless = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Parent = parent
    return part
end

local function poseAmount(clip, t)
    local keys = envelopes[clip]
    if not keys then return 0 end
    for index = 2, #keys do
        local prior, nextKey = keys[index - 1], keys[index]
        if t <= nextKey[1] then
            local alpha = (t - prior[1]) / (nextKey[1] - prior[1])
            return prior[2] + alpha * (nextKey[2] - prior[2])
        end
    end
    return keys[#keys][2]
end

local function floorHeight(clip, progress)
    local track = floorTracks[clip]
    if not track then return 0 end
    local frame = 1 + progress * (#track - 1)
    local first = math.floor(frame)
    local prior = track[first]
    return prior + ((track[first + 1] or prior) - prior) * (frame - first)
end

function Scuzz.attach(parent, anchor, groundOffset)
    local model = Instance.new("Model")
    model.Name = "ScuzzVisual"
    local floor = CFrame.new(0, -(groundOffset or 2.25), 0)
    local parts, origins, joints, rest = {}, {}, {}, {}
    for _, entry in ipairs(pivots) do
        local name, owner, pivot = table.unpack(entry)
        local hub = cosmetic("Part", name, model)
        hub.Size = V(0.05, 0.05, 0.05)
        hub.Transparency = 1
        hub.CastShadow = false
        hub.CFrame = anchor.CFrame * floor * CFrame.new(pivot)
        local joint = Instance.new("Motor6D")
        joint.Name = name .. "Motor"
        joint.Part0 = parts[owner] or anchor
        joint.Part1 = hub
        joint.C0 = if parts[owner] then CFrame.new(pivot - origins[owner]) else floor * CFrame.new(pivot)
        joint:SetAttribute('SkinNeutral',joint.C0)
        joint.Parent = hub
        parts[name], origins[name], joints[name], rest[name] = hub, pivot, joint, joint.C0
    end
    for _, entry in ipairs(shapes) do
        local name, bone, shade, start, finish, width, depth, tapered = table.unpack(entry)
        local limb = parts[bone]
        local part = cosmetic(if tapered then "WedgePart" else "Part", name, model)
        if not tapered then part.Shape = Enum.PartType.Ball end
        local axis = (finish - start).Unit
        local guide = if math.abs(axis.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
        local right = (guide - axis * guide:Dot(axis)).Unit
        local back = -axis
        local center = (start + finish) * 0.5 - origins[bone]
        local frame = CFrame.fromMatrix(center, right, back:Cross(right), back)
        part.Size = V(math.max(0.05, width), math.max(0.05, depth), math.max(0.05, (finish - start).Magnitude))
        part.Color = colors[shade]
        part.Material = Enum.Material.SmoothPlastic
        part.CFrame = limb.CFrame * frame
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = limb
        weld.Part1 = part
        weld.Parent = part
    end
    for _, entry in ipairs(sockets) do
        local name, bone, pivot = table.unpack(entry)
        local attachment = Instance.new("Attachment")
        attachment.Name = name
        attachment.Position = pivot - origins[bone]
        attachment.Parent = parts[bone]
    end
    model.PrimaryPart = parts.Pelvis
    model.Parent = parent
    -- The caller owns fallback visibility, animation selection, lifetime and the physical actor.
    local function pose(clip, phase)
        local targets = poses[clip] or {}
        local progress = math.clamp(phase or 0, 0, 1)
        local amount = poseAmount(clip, progress)
        for name, joint in pairs(joints) do
            local offset = if name == "Pelvis" then floorHeight(clip, progress) else 0
            local angles = (targets[name] or Vector3.zero) * math.rad(amount)
            joint.C0 = rest[name] * CFrame.new(0, offset, 0) * CFrame.Angles(0, 0, angles.Z) * CFrame.Angles(0, angles.Y, 0) * CFrame.Angles(angles.X, 0, 0)
        end
    end
    return {model = model, pose = pose}
end

return Scuzz
