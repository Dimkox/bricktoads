-- Run on the Studio server during Play. Uses a detached folder for isolated geometry.
local server = game:GetService("ServerScriptService")
local world = require(assert(server:FindFirstChild("GameWorld", true)))
local campaign = require(assert(server:FindFirstChild("CampaignDefinition", true)))
local offset = Vector3.new(1250, 5, -250)
local geometry = Instance.new("Folder")
local planted = { [1]=true, [3]=true, [9]=true, [13]=true }
local counts = {}
local measured = 0
local runs = 0
local function verify(index, seed)
    local route = campaign.build(index, seed)
    local half = index == 3 and route.course.laneLimit or 8
    world.scatterPlants({geometry=geometry, offset=offset}, route)
    local parts = geometry:GetChildren()
    assert((#parts > 0) == (planted[index] == true), route.name)
    local leaves, patches, trunks, crowns = 0, 0, 0, 0
    local firstTrees = {}
    local fingerprint = {}
    for _, part in ipairs(parts) do
        assert(part:IsA("BasePart") and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
        if part.Name == "GroundLeaf" then leaves += 1 end
        if part.Name == "GrassPatch" then patches += 1 end
        if part.Name == "MarshTrunk" then
            trunks += 1
            local pos=part.Position-offset
            assert(pos.Z < -half and part.Size.Y >= 5)
            table.insert(firstTrees,pos.X)
        elseif part.Name == "MarshCrown" then
            crowns += 1
        end
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
        for _, x in ipairs({-.5,.5}) do
            for _, y in ipairs({-.5,.5}) do
                for _, z in ipairs({-.5,.5}) do
                    local corner = part.CFrame * (part.Size * Vector3.new(x,y,z)) - offset
                    minX,maxX=math.min(minX,corner.X),math.max(maxX,corner.X)
                    minZ,maxZ=math.min(minZ,corner.Z),math.max(maxZ,corner.Z)
                end
            end
        end
        assert(maxZ <= -half or minZ >= half, "Plant intrudes into route")
        local supported = false
        for _, zone in ipairs(route.zones) do
            for _, floor in ipairs(zone.platforms) do
                if minX >= floor.x-floor.w/2+2 and maxX <= floor.x+floor.w/2-2 and minZ >= floor.z-floor.d/2 and maxZ <= floor.z+floor.d/2 and (minZ >= floor.z+half or maxZ <= floor.z-half) and (index ~= 9 or floor.y+floor.h/2 >= 0) then
                    supported = true
                end
            end
        end
        assert(supported, "Plant outside supported shoulder")
        for _, crest in ipairs(route.course and route.course.roadCrests or {}) do
            assert(maxX <= crest.x-crest.halfLength or minX >= crest.x+crest.halfLength)
        end
        table.insert(fingerprint, part.Name .. tostring(part.Position) .. tostring(part.Size))
    end
    assert(leaves == 5*patches and crowns == 3*trunks)
    if index==1 then
        for _,x in ipairs({route.spawn.x,route.zones[1].gateX}) do
            local nearest=math.huge
            for _,tx in ipairs(firstTrees) do nearest=math.min(nearest,math.abs(tx-x)) end
            assert(nearest <= 28,"Missing visible tree near spawn or first gate")
        end
    end
    counts[route.name] = math.max(counts[route.name] or 0, patches)
    measured += #parts
    runs += 1
    geometry:ClearAllChildren()
    return table.concat(fingerprint,"|")
end
for index=1,13 do
    local original = verify(index,1)
    assert(original == verify(index,1))
    if planted[index] then assert(original ~= verify(index,2)) end
    for sample=1,40 do
        verify(index, 1 + sample*104729)
        if sample%10 == 0 then task.wait() end
    end
end
geometry:Destroy()
return game:GetService("HttpService"):JSONEncode({layouts=runs, parts=measured, maxClumpsByLevel=counts})
