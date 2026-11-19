-- Only portraits use embedded art. Full-screen images always use native Roblox delivery.
local encoding = game:GetService("EncodingService")
local assets = game:GetService("AssetService")
local Fallback = {}
local cache = {}

local function portrait(key)
    if cache[key] then return cache[key] end
    local sheet = require(if key <= 16 then script.Parent.ArcadePixels else script.Parent.ArcadeEnemyPixels)
    local indices = encoding:Base64Decode(buffer.fromstring(sheet[(key-1)%16+1]))
    local palette = encoding:Base64Decode(buffer.fromstring(sheet.palette))
    local size = sheet.size
    local pixels = buffer.create(size * size * 4)
    for i = 0, size * size - 1 do
        local offset = buffer.readu8(indices, i) * 3
        buffer.copy(pixels, i*4, palette, offset, 3)
        buffer.writeu8(pixels, i*4+3, 255)
    end
    local result = {}
    -- Editable images are optional on published experiences and memory-limited devices.
    local ok, bitmap = pcall(function()
        local image = assets:CreateEditableImage({Size = Vector2.new(size,size)})
        if image then image:WritePixelsBuffer(Vector2.zero, image.Size, pixels) end
        return image
    end)
    if ok and bitmap then
        result.bitmap = bitmap
    else
        -- Sample the same portrait for native UI on clients without editable images.
        -- Four gradients per row retain the muzzle and eye outlines at phone card size.
        result.rows = {}
        for y = 0, 63 do
            local row = math.round(y * (size-1) / 63)
            for strip = 0, 3 do
                local points = {}
                for column = 0, 16 do
                    local x = math.round((strip*16 + column) * (size-1) / 64)
                    local p = (row*size+x)*4
                    local color = Color3.fromRGB(buffer.readu8(pixels,p),buffer.readu8(pixels,p+1),buffer.readu8(pixels,p+2))
                    points[column+1] = ColorSequenceKeypoint.new(column/16,color)
                end
                table.insert(result.rows, ColorSequence.new(points))
            end
        end
    end
    cache[key] = result
    return result
end

function Fallback.refresh(image)
    local layer = image:FindFirstChild("EmbeddedIllustration")
    local key = image:GetAttribute("ArcadeTile")
    if layer and (image.IsLoaded or layer:GetAttribute("Tile") ~= key) then
        layer:Destroy()
        layer = nil
    end
    if image.IsLoaded or layer or not key then return end
    local art = portrait(key)
    if image.IsLoaded or image:GetAttribute("ArcadeTile") ~= key or image:FindFirstChild("EmbeddedIllustration") then return end
    layer = Instance.new(if art.bitmap then "ImageLabel" else "Frame")
    layer.Name = "EmbeddedIllustration"
    layer.BackgroundTransparency = 1
    layer.AnchorPoint = Vector2.new(.5,.5)
    layer.Position = UDim2.fromScale(.5,.5)
    layer.Size = UDim2.fromScale(1,1)
    layer:SetAttribute("Tile", key)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.Parent = layer
    if art.bitmap then
        layer.ImageContent = Content.fromObject(art.bitmap)
    else
        for n, sequence in ipairs(art.rows) do
            local strip = Instance.new("Frame")
            strip.BorderSizePixel = 0
            strip.BackgroundColor3 = image.ImageColor3
            strip.Position = UDim2.fromScale((n-1)%4/4, math.floor((n-1)/4)/64)
            strip.Size = UDim2.new(.25,0,1/64,1)
            local gradient = Instance.new("UIGradient")
            gradient.Color = sequence
            gradient.Parent = strip
            strip.Parent = layer
        end
    end
    layer.ClipsDescendants = true
    layer.Parent = image
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
    local old = image:FindFirstChild("EmbeddedIllustration")
    if old then old:Destroy() end
    task.delay(.45, function()
        if image.Parent and image:GetAttribute("ArcadeTile") == key then Fallback.refresh(image) end
    end)
end

return Fallback
