-- Each atlas is a 4-by-4 grid at Roblox's 1024px image resolution.
local Art = {
    splash = "rbxassetid://127656873971587",
    icon = "rbxassetid://123865642729026",
}
local fallback = require(script.Parent:WaitForChild("ArcadeFallback"))
local tiles = {}
Art.cast = {}
function Art.backdrop(image)
    image.Image = Art.splash
    fallback.bind(image, "splash")
end
local function atlas(image, names)
    for index, name in ipairs(names) do
        local cell = index - 1
        table.insert(Art.cast, name)
        tiles[name] = {image, Vector2.new(cell % 4 * 256, math.floor(cell / 4) * 256), #Art.cast}
    end
end
atlas("rbxassetid://128231984612533", {
    "Mr. Green", "Mr. Yellow", "Mr. Brown", "Pig",
    "Dragon", "Walker", "Raven", "RacingRat",
    "CausewayGuardian", "BigBlag", "RoboManus", "GeneralSlaughter",
    "Buzzball", "DarkQueen", "Robot", "Snake",
})
atlas("rbxassetid://118744022897484", {
    "LargeRaven", "Invader", "RocketRat", "Snowman",
    "SentryDrone", "GasTurret", "RetroBlaster", "SaturnToadtrap",
    "Slug", "Electrofish", "Hammerfish", "Shark",
    "Duck", "Hordhead", "FlyingHead", "Swellcheeks",
})

function Art.setPortrait(image, key)
    local tile = tiles[key] or tiles.SentryDrone
    if image.Image ~= tile[1] then image.Image = tile[1] end
    image.ImageRectOffset = tile[2]
    image.ImageRectSize = Vector2.new(256, 256)
    fallback.bind(image, tile[3])
end

function Art.portrait(parent, key)
    local image = Instance.new("ImageLabel")
    image.Name = "CharacterPortrait"
    image.BackgroundTransparency = 1
    image.ScaleType = Enum.ScaleType.Fit
    Art.setPortrait(image, key)
    image.Parent = parent
    return image
end

function Art.enemyKey(enemy)
    if enemy.bossType then return enemy.bossType end
    if enemy.template == "Boss" then return "CausewayGuardian" end
    if enemy.resourceKind == "CourseRival" then return "RacingRat" end
    return enemy.kind or "SentryDrone"
end

return table.freeze(Art)
