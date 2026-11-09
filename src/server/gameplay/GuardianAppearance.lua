-- Cosmetic canonical Guardian skin on the existing server-owned R6 actor.
-- Attach before the caller pins completed-assembly ownership. Nothing here
-- changes gameplay health, aim, projectiles, collisions or the physical rig.
local Appearance={}
local PROFILE='CanonicalBossWalker'
local TEMPLATE='BossWalkerGuardian'
local MOUNT='GuardianMountRigAttachment'
local MUZZLE='MuzzleRigAttachment'
local NAMES={'GuardianChassis','GuardianLeftCannon','GuardianRightCannon'}
local HIDDEN={HumanoidRootPart=true,Torso=true,Head=true,['Left Arm']=true,['Right Arm']=true,
    ['Left Leg']=true,['Right Leg']=true,Eye=true}
-- Source recoil counter 7; conversion to seconds and the 3D displacement,
-- flash and hurt-color timing are explicit authored Roblox presentation.
local RECOIL_SECONDS=7/60
local RECOIL_STUDS=.25
local FLASH_SECONDS=.065
local HURT_SECONDS=.16
local HURT_COLOR=Color3.fromRGB(255,190,160)
local EPSILON=1e-4

local function finite(value)
    return type(value)=='number' and value==value and value>-math.huge and value<math.huge
end

local function positiveSize(size)
    for _,value in ipairs({size.X,size.Y,size.Z}) do
        assert(finite(value) and value>0,'Invalid mesh dimensions')
    end
end

local function finiteFrame(frame)
    local values={frame:GetComponents()}
    assert(#values==12,'Invalid attachment frame')
    for _,value in ipairs(values) do assert(finite(value),'Nonfinite frame') end
    return frame
end

local function rootAxes(frame)
    local values={finiteFrame(frame):GetComponents()}
    for i=4,12 do
        local identity=(i==4 or i==8 or i==12) and 1 or 0
        assert(math.abs(values[i]-identity)<EPSILON,'Attachment must use root axes')
    end
    return frame.Position
end

local function uploadedId(value)
    return type(value)=='string' and value:match('^rbxassetid://%d+$') and tonumber(value:sub(14))>0
end

local function validatePart(part,index)
    assert(part:IsA('MeshPart'),'Expected an uploaded MeshPart')
    assert(uploadedId(part.MeshId),'Missing uploaded mesh')
    positiveSize(part.Size)
    -- MeshSize is read-only and not available in every native test/API surface.
    -- Whenever the engine exposes it, reject empty or invalid imported geometry.
    local hasMeshSize,meshSize=pcall(function() return part.MeshSize end)
    if hasMeshSize and meshSize~=nil then positiveSize(meshSize) end
    assert(finite(part.Transparency) and part.Transparency>=0 and part.Transparency<1,'Invisible mesh')
    finiteFrame(part.CFrame)
    local mount,muzzle,surfaces
    surfaces=0
    for _,child in ipairs(part:GetChildren()) do
        assert(#child:GetChildren()==0,'Nested template content is forbidden')
        if child:IsA('Attachment') then
            finiteFrame(child.CFrame)
            if child.Name==MOUNT then assert(not mount,'Duplicate mount');mount=child
            elseif child.Name==MUZZLE and index>1 then assert(not muzzle,'Duplicate muzzle');muzzle=child
            else error('Unexpected attachment') end
        else
            assert(child:IsA('SurfaceAppearance'),'Unexpected mesh content')
            surfaces+=1;assert(surfaces<=1,'Duplicate surface appearance')
        end
    end
    assert(mount,'Missing mount attachment')
    local position=rootAxes(part.CFrame*mount.CFrame)
    if index==1 then
        assert(math.abs(position.X)<EPSILON and math.abs(position.Y)<EPSILON and math.abs(position.Z)<EPSILON,
            'Chassis mount must be root origin')
    else
        assert(index==2 and position.X< -EPSILON or index==3 and position.X>EPSILON,'Cannon mount has wrong side')
        assert(muzzle,'Missing muzzle attachment')
        local muzzlePosition=rootAxes(part.CFrame*muzzle.CFrame)
        assert(muzzlePosition.Z<position.Z-EPSILON,'Muzzle must face forward of mount')
    end
end

local function validateTemplate(template)
    assert(template:IsA('Model'),'Boss resource must be a Model')
    local found,parts={},{}
    for _,child in ipairs(template:GetChildren()) do
        assert(not found[child.Name],'Duplicate template child');found[child.Name]=true
        local index=table.find(NAMES,child.Name)
        if index then
            validatePart(child,index);parts[index]=child
        elseif child.Name=='AppearanceProfile' then
            assert(child:IsA('StringValue') and child.Value==PROFILE,'Unknown appearance profile')
            assert(#child:GetChildren()==0,'Nested metadata content')
        elseif child.Name=='AppearanceScale' then
            assert(child:IsA('NumberValue') and child.Value==1,'Appearance scale must be one')
            assert(#child:GetChildren()==0,'Nested metadata content')
        elseif child.Name=='SourceAssetId' then
            assert(child:IsA('StringValue') and type(child.Value)=='string' and child.Value:match('^%d+$')
                and tonumber(child.Value)>0,'Invalid source asset identity')
            assert(#child:GetChildren()==0,'Nested metadata content')
        elseif child.Name=='SourceGlbSha256' or child.Name=='AssetManifestSha256' then
            assert(child:IsA('StringValue') and type(child.Value)=='string' and #child.Value==64
                and child.Value:match('^%x+$'),'Invalid source fingerprint')
            assert(#child:GetChildren()==0,'Nested metadata content')
        else error('Unexpected template object') end
    end
    assert(found.AppearanceProfile and found.AppearanceScale,'Missing appearance metadata')
    for index=1,3 do assert(parts[index],'Expected three canonical meshes') end
    return parts
end

local function nonphysical(part)
    part.Anchored=false;part.Massless=true
    part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
end

local function validOwner(actor,state)
    if actor.model~=state.ownerModel or actor.root~=state.root or not state.ownerModel.Parent
        or state.model.Parent~=state.ownerModel or not state.root:IsDescendantOf(state.ownerModel) then return false end
    for _,row in ipairs(state.rows) do
        if row.part.Parent~=state.model or row.motor.Parent~=row.part or row.motor.Part0~=state.root
            or row.motor.Part1~=row.part then return false end
        if row.surface and row.surface.Parent~=row.part then return false end
        if row.flash and (row.flash.Parent~=state.model or row.weld.Parent~=row.flash
            or row.weld.Part0~=row.part or row.weld.Part1~=row.flash) then return false end
    end
    return true
end

function Appearance.detach(actor)
    local state=actor and actor.guardianAppearance
    if not state then return end
    actor.guardianAppearance=nil
    -- Restore values even if a consumer retains a reference to the old skin.
    for _,row in ipairs(state.rows) do
        if row.part.Parent==state.model then
            row.part.Color=row.color;row.part.Transparency=row.transparency
        end
        if row.surface and row.surface.Parent==row.part then row.surface.Color=row.surfaceColor end
        if row.flash and row.flash.Parent==state.model then row.flash.Transparency=1 end
    end
    state.model:Destroy()
    for part,transparency in pairs(state.hidden) do
        if part.Parent and part:IsDescendantOf(state.ownerModel) then part.Transparency=transparency end
    end
end

function Appearance.update(actor,now)
    local state=actor and actor.guardianAppearance
    if not state then return end
    if not validOwner(actor,state) then Appearance.detach(actor);return end
    if not finite(now) then return end
    local hurt=state.hurtAt and now-state.hurtAt
    local tint=hurt and hurt>=0 and math.max(0,1-hurt/HURT_SECONDS)*.65 or 0
    for _,row in ipairs(state.rows) do
        local elapsed=row.shotAt and now-row.shotAt
        local recoil=elapsed and elapsed>=0 and math.max(0,1-elapsed/RECOIL_SECONDS)*RECOIL_STUDS or 0
        -- C0's base is authored in root mount axes; C1 retains the importer's
        -- Y180 rest rotation. A +Z delta therefore recoils away from -Z fire.
        row.motor.C0=row.base*CFrame.new(0,0,recoil)
        row.part.Color=tint>0 and row.color:Lerp(HURT_COLOR,tint) or row.color
        row.part.Transparency=row.transparency
        -- PBR ColorMap tint is separate from the underlying MeshPart color.
        if row.surface then row.surface.Color=tint>0 and row.surfaceColor:Lerp(HURT_COLOR,tint) or row.surfaceColor end
        if row.flash then row.flash.Transparency=elapsed and elapsed>=0 and elapsed<FLASH_SECONDS and 0 or 1 end
    end
end

function Appearance.shot(actor,mode,now)
    local state=actor and actor.guardianAppearance
    if not state then return false end
    if not validOwner(actor,state) then Appearance.detach(actor);return false end
    -- Only accepted GuardianPattern projectile creation calls this API. Generic
    -- boss cues include blocked melee and cannot be treated as successful shots.
    if (mode~='Bullet' and mode~='Heavy') or not finite(now) then return false end
    state.shotSerial+=1
    local index=state.shotSerial%2==1 and 2 or 3
    state.rows[index].shotAt=now
    Appearance.update(actor,now)
    return true
end

function Appearance.health(actor,current,maximum,now)
    local state=actor and actor.guardianAppearance
    if not state then return end
    if not validOwner(actor,state) then Appearance.detach(actor);return end
    if not finite(current) or not finite(maximum) or maximum<=0 or not finite(now) then return end
    local normalized=math.clamp(current/maximum,0,1)
    -- Initialization often reports 3/3 then 47/47. Compare fractions so those
    -- two representations of full health never create a fabricated damage cue.
    if state.normalizedHealth and normalized<state.normalizedHealth then state.hurtAt=now end
    state.normalizedHealth=normalized
    Appearance.update(actor,now)
end

function Appearance.attach(actor,templates)
    if not actor or not actor.model or not actor.model:IsA('Model') or not actor.model.Parent
        or not actor.root or not actor.root:IsA('BasePart') or not actor.root:IsDescendantOf(actor.model) then
        return false,'INVALID_GUARDIAN_ACTOR'
    end
    templates=templates or game:GetService('ServerStorage'):FindFirstChild('BrickToadsBossTemplates')
    local template=templates and templates:FindFirstChild(TEMPLATE)
    if not template then return false,'NO_BOSS_RESOURCE' end
    -- Scan original content before cloning: no unsafe Scripts, hidden/nested
    -- colliders, untagged models or partial imports can reach a live assembly.
    local valid,validationError=pcall(validateTemplate,template)
    if not valid then return false,'INVALID_BOSS_RESOURCE: '..tostring(validationError) end
    local previous=actor.guardianAppearance
    if previous and previous.sourceTemplate==template and validOwner(actor,previous) then return true end
    local clone
    local prepared,state=pcall(function()
        clone=assert(template:Clone(),'Uncloneable boss resource')
        local parts=validateTemplate(clone)
        clone.Name=TEMPLATE..'Appearance'
        local result={model=clone,ownerModel=actor.model,root=actor.root,sourceTemplate=template,
            profile=PROFILE,rows={},hidden={},shotSerial=0}
        for index,part in ipairs(parts) do
            local mount=part:FindFirstChild(MOUNT)
            local base=part.CFrame*mount.CFrame
            local row={part=part,base=base,color=part.Color,transparency=part.Transparency}
            for _,child in ipairs(part:GetChildren()) do
                if child:IsA('SurfaceAppearance') then row.surface=child;row.surfaceColor=child.Color end
            end
            part.CFrame=actor.root.CFrame*part.CFrame
            nonphysical(part)
            local motor=Instance.new('Motor6D');motor.Name='GuardianAppearance'..part.Name
            motor.Part0=actor.root;motor.Part1=part;motor.C0=base;motor.C1=mount.CFrame;motor.Parent=part
            row.motor=motor
            if index>1 then
                local muzzle=part:FindFirstChild(MUZZLE)
                local flash=Instance.new('Part');flash.Name=part.Name..'MuzzleFlash'
                flash.Size=Vector3.new(.44,.44,.55);flash.Shape=Enum.PartType.Ball
                flash.Material=Enum.Material.Neon;flash.Color=Color3.fromRGB(255,224,128)
                flash.Transparency=1;flash.CFrame=part.CFrame*muzzle.CFrame;nonphysical(flash)
                local weld=Instance.new('WeldConstraint');weld.Name='GuardianMuzzleFlashWeld'
                weld.Part0=part;weld.Part1=flash;weld.Parent=flash;flash.Parent=clone
                row.flash,row.weld=flash,weld
            end
            result.rows[index]=row
        end
        return result
    end)
    if not prepared then
        if clone then clone:Destroy() end
        return false,'INVALID_BOSS_RESOURCE: '..tostring(state)
    end
    -- Only a complete validated replacement may retire the previous appearance.
    if previous then Appearance.detach(actor) end
    for _,part in ipairs(actor.model:GetChildren()) do
        if part:IsA('BasePart') and HIDDEN[part.Name] then state.hidden[part]=part.Transparency end
    end
    clone.Parent=actor.model
    actor.guardianAppearance=state
    for part in pairs(state.hidden) do part.Transparency=1 end
    return true
end

return Appearance
