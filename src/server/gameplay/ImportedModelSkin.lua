-- Approved imported geometry follows the existing cosmetic rig. The native visual
-- is available immediately, including when Roblox cannot deliver an asset.
local Skin={}
local ids={RatPod=138389972582010,Meteorite=85366635220573,ShadowCloud=112664563553810,Scuzz=71192236028656}
-- The importer exposes these texture IDs to Studio. Client scripts use replicated
-- attributes because SurfaceAppearance map properties require plugin capability.
local maps={
    Meteorite={ColorMap='rbxassetid://133369040010732',NormalMap='rbxassetid://76136314086327',RoughnessMap='rbxassetid://126733848963981',MetalnessMap='rbxassetid://100717397125338'},
    ShadowCloud={ColorMap='rbxassetid://137907337698025',NormalMap='rbxassetid://73205988271170',RoughnessMap='rbxassetid://121490698526750',MetalnessMap='rbxassetid://103765965764002'},
    RatPod={ColorMap='rbxassetid://135968660458783',NormalMap='rbxassetid://127500140879129',RoughnessMap='rbxassetid://104217843500156',MetalnessMap='rbxassetid://106011624259326'},
    Scuzz={ColorMap='rbxassetid://114193305944650',NormalMap='rbxassetid://87325461063443',RoughnessMap='rbxassetid://117514331356982',MetalnessMap='rbxassetid://103765965764002'},
}
local cache,loading={},{}
local function load(kind)
    if cache[kind] then return cache[kind] end
    if loading[kind] then
        loading[kind].Event:Wait()
        return cache[kind]
    end
    local signal=Instance.new('BindableEvent')
    loading[kind]=signal
    local ok,asset=pcall(function() return game:GetService('InsertService'):LoadAsset(ids[kind]) end)
    if ok then cache[kind]=asset end
    loading[kind]=nil
    signal:Fire()
    task.defer(function() signal:Destroy() end)
    return cache[kind]
end

local flip=CFrame.Angles(0,math.pi,0)
function Skin.attach(kind,visual,anchor,origin)
    task.spawn(function()
        local source=load(kind)
        if not source or not visual.Parent or not anchor.Parent then return end
        local expected=({RatPod=4,Meteorite=2,Scuzz=1,ShadowCloud=10})[kind]
        local pieces={}
        for _,v in ipairs(source:GetDescendants()) do
            if v:IsA('MeshPart') then table.insert(pieces,v) end
        end
        if #pieces~=expected then return end
        local imported=Instance.new('Model')
        imported.Name='ImportedGeometry'
        local scale=(kind=='RatPod' or kind=='Meteorite') and 1/.28 or 1
        local basis=(origin or CFrame.identity)*flip
        local boneRows={}
        for _,ref in ipairs(pieces) do
            local target=kind=='ShadowCloud' and visual:FindFirstChild(ref.Name) or anchor
            if not target then imported:Destroy();return end
            local part=ref:Clone()
            for _,v in ipairs(part:GetDescendants()) do
                if v:IsA('JointInstance') or v:IsA('Constraint') or v:IsA('BaseScript') then v:Destroy() end
            end
            part.Size=ref.Size*scale
            local point=ref.CFrame
            local localFrame=basis*CFrame.new(point.Position*scale)*point.Rotation
            part.CFrame=anchor.CFrame*localFrame
            part.Anchored=false;part.Massless=true
            part.CanQuery=false;part.CanCollide=false;part.CanTouch=false
            if kind=='Scuzz' then
                for _,bone in ipairs(part:GetDescendants()) do
                    if bone:IsA('Bone') then
                        local rest=bone.CFrame
                        bone.CFrame=CFrame.new(rest.Position*scale)*rest.Rotation
                        local hub=visual:FindFirstChild(bone.Name)
                        local motor=hub and hub:FindFirstChild(bone.Name..'Motor')
                        if motor then
                            table.insert(boneRows,{bone=bone,rest=bone.CFrame,motor=motor,neutral=motor:GetAttribute('SkinNeutral') or motor.C0,
                                axes=basis.Rotation*ref:FindFirstChild(bone.Name,true).WorldCFrame.Rotation})
                        end
                    end
                end
            end
            local joint=Instance.new('Weld');joint.Part0=target;joint.Part1=part
            if kind=='ShadowCloud' then
                local frame=CFrame.identity
                local driver=target
                while driver~=anchor do
                    local motor=driver:FindFirstChild(driver.Name..'Joint')
                    if not motor then imported:Destroy();return end
                    frame=(motor:GetAttribute('Rest') or motor.C0)*frame
                    driver=motor.Part0
                end
                joint.C0=frame:ToObjectSpace(localFrame)
            else
                joint.C0=localFrame
            end
            joint.Parent=part
            part.Parent=imported
        end
        if kind=='Scuzz' and #boneRows~=14 then imported:Destroy();return end
        local skinId=game:GetService('HttpService'):GenerateGUID(false)
        visual:SetAttribute('CastAppearance','CanonicalNESCast')
        imported:SetAttribute('CanonicalCastSkin',true)
        imported:SetAttribute('CastSkinId',skinId)
        imported:SetAttribute('PreloadMaterialMaps',true)
        for name,content in pairs(maps[kind]) do imported:SetAttribute(name,content) end
        for _,mesh in ipairs(imported:GetChildren()) do
            mesh:SetAttribute('CastVisibleTransparency',mesh.Transparency)
        end
        for _,part in ipairs(visual:GetDescendants()) do
            if part:IsA('BasePart') and part.Transparency<1 then
                part:SetAttribute('CastFallbackOwner',skinId)
                part:SetAttribute('CastFallbackTransparency',part.Transparency)
                local ref=Instance.new('ObjectValue')
                ref.Name='CastFallbackTarget';ref.Value=part;ref.Parent=imported
            end
        end
        imported.Parent=visual
        game:GetService('CollectionService'):AddTag(imported,'BrickToadsCastSkin')
        visual:SetAttribute('ImportedModelId',ids[kind])
        if kind=='Scuzz' then Skin.bones[visual]=boneRows end
    end)
end

Skin.bones=setmetatable({},{__mode='k'})
function Skin.poseScuzz(visual)
    for _,row in ipairs(Skin.bones[visual] or {}) do
        local delta=row.neutral:ToObjectSpace(row.motor.C0)
        row.bone.CFrame=row.rest*row.axes:Inverse()*delta*row.axes
    end
end
return Skin
