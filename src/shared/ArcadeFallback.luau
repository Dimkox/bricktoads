-- The place carries a small RGB copy of each illustration for cold or offline image caches.
local pixels = require(script.Parent.ArcadePixels)
local encoding = game:GetService("EncodingService")
local Fallback = {}
local sequences = {}

local function scanlines(key, width, height)
    if sequences[key] then return sequences[key] end
    local rgb = encoding:Base64Decode(buffer.fromstring(pixels[key]))
    local result = {}
    for row = 0, height - 1 do
        for x = 0, width - 1, 16 do
            local points = {}
            for col = 0, 15 do
                local p = (row * width + x + col) * 3
                local color = Color3.fromRGB(buffer.readu8(rgb, p), buffer.readu8(rgb, p+1), buffer.readu8(rgb, p+2))
                points[col+1] = ColorSequenceKeypoint.new(col / 15, color)
            end
            table.insert(result, ColorSequence.new(points))
        end
    end
    sequences[key] = result
    return result
end

function Fallback.bind(image, key)
    if image:GetAttribute("ArcadeTile") == key then return end
    image:SetAttribute("ArcadeTile", key)
    if not image:GetAttribute("WatchingImage") then
        image:SetAttribute("WatchingImage", true)
        image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
            Fallback.refresh(image)
        end)
    end
    Fallback.refresh(image)
end

function Fallback.refresh(image)
    local layer = image:FindFirstChild("EmbeddedIllustration")
    local key = image:GetAttribute("ArcadeTile")
    if layer and (image.IsLoaded or layer:GetAttribute("Tile") ~= key) then
        layer:Destroy()
        layer = nil
    end
    if image.IsLoaded or layer or not key then return end

    local square = key ~= "splash"
    local width, height = square and 32 or 64, square and 32 or 40
    layer = Instance.new("Frame")
    layer.Name = "EmbeddedIllustration"
    layer.BackgroundTransparency = 1
    layer.Position = UDim2.fromScale(.5,.5)
    layer.AnchorPoint = Vector2.new(.5,.5)
    layer.Size = UDim2.fromScale(1,1)
    layer:SetAttribute("Tile", key)
    if square then
        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.AspectRatio = 1
        aspect.Parent = layer
    end
    local tilesAcross = width / 16
    for n, sequence in ipairs(scanlines(key, width, height)) do
        local strip = Instance.new("Frame")
        strip.BorderSizePixel = 0
        strip.BackgroundColor3 = image.ImageColor3
        strip.Position = UDim2.fromScale((n-1) % tilesAcross / tilesAcross, math.floor((n-1)/tilesAcross)/height)
        strip.Size = UDim2.new(1/tilesAcross,0,1/height,1)
        local gradient = Instance.new("UIGradient")
        gradient.Color = sequence
        gradient.Parent = strip
        strip.Parent = layer
    end
    layer.ClipsDescendants = true
    layer.Parent = image
end

return Fallback
