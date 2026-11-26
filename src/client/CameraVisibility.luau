-- Compose the first-person mask with the game's streamed skins and attack morphs.
local CameraVisibility = {}
local hiddenActor, added, removing
local saved = {}

function CameraVisibility.get(part)
    local value = saved[part] or part.LocalTransparencyModifier
    return type(value) == "number" and value >= 0 and value <= 1 and value or 0
end

function CameraVisibility.set(part, value)
    if saved[part] ~= nil then
        saved[part] = value
    else
        part.LocalTransparencyModifier = value
    end
end

local function hide(part)
    if saved[part] == nil and (part:IsA("BasePart") or part:IsA("Decal")) then
        saved[part] = part.LocalTransparencyModifier
        part.LocalTransparencyModifier = 1
    end
end

local function restore(part)
    local value = saved[part]
    if value ~= nil then
        saved[part] = nil
        part.LocalTransparencyModifier = value
    end
end

function CameraVisibility.setHiddenActor(actor)
    if actor == hiddenActor then return end
    if hiddenActor then
        added:Disconnect()
        removing:Disconnect()
        added, removing = nil, nil
        for part in pairs(saved) do restore(part) end
    end
    hiddenActor = actor
    if actor then
        added = actor.DescendantAdded:Connect(hide)
        removing = actor.DescendantRemoving:Connect(restore)
        for _, part in ipairs(actor:GetDescendants()) do hide(part) end
    end
end

return CameraVisibility
