-- Tagged canonical P1/P2 resources and an explicit legacy Green study fallback.
-- Canonical idle/walk/run and seven accepted attacks use source-frame 3D poses.
-- Priority/unsupported states retain R6 retargeting. Optional approved morphs
-- are preassembled before the caller pins ownership, then only change visibility.
-- Never replaces the R6 physical rig.
-- Caller must pin server network ownership AFTER all cosmetic parts are attached.
local Appearance={}
local HeroPresentation=script and require(script.Parent.CanonicalHeroPresentation)
local JOINTS={
    {'Waist','LowerTorso','UpperTorso'}, {'Neck','UpperTorso','Head','Neck'},
    {'LeftShoulder','UpperTorso','LeftUpperArm','Left Shoulder'},
    {'LeftElbow','LeftUpperArm','LeftLowerArm'}, {'LeftWrist','LeftLowerArm','LeftHand'},
    {'RightShoulder','UpperTorso','RightUpperArm','Right Shoulder'},
    {'RightElbow','RightUpperArm','RightLowerArm'}, {'RightWrist','RightLowerArm','RightHand'},
    {'LeftHip','LowerTorso','LeftUpperLeg','Left Hip'},
    {'LeftKnee','LeftUpperLeg','LeftLowerLeg'}, {'LeftAnkle','LeftLowerLeg','LeftFoot'},
    {'RightHip','LowerTorso','RightUpperLeg','Right Hip'},
    {'RightKnee','RightUpperLeg','RightLowerLeg'}, {'RightAnkle','RightLowerLeg','RightFoot'},
}
local RIG_NAMES={'Neck','Left Shoulder','Right Shoulder','Left Hip','Right Hip'}
local HIDDEN={Torso=true,Head=true,['Left Arm']=true,['Right Arm']=true,['Left Leg']=true,['Right Leg']=true,Eye=true}
local CANONICAL={['Mr. Green']='CanonicalPlayer1',['Mr. Yellow']='CanonicalPlayer2'}
local MORPHS={PowerFist={part='RightHand',attachment='RightWristRigAttachment'},
    BigBoot={part='RightFoot',attachment='RightAnkleRigAttachment'}}
local MORPH_PREFIX={['Mr. Green']='Green',['Mr. Yellow']='PlayerTwo'}
local function resource(templates,heroTemplate)
    local name=CANONICAL[heroTemplate]
    if not name then return nil,'NO_CHARACTER_RESOURCE' end
    local candidate=templates and templates:FindFirstChild(name)
    if candidate then
        if not candidate:IsA('Model') then return nil,'INVALID_CHARACTER_RESOURCE' end
        local profile=candidate:FindFirstChild('AppearanceProfile')
        if profile then
            if not profile:IsA('StringValue') or profile.Value~='CanonicalNESHero' then return nil,'UNKNOWN_APPEARANCE_PROFILE' end
            return candidate,'CanonicalNESHero',0
        end
    end
    -- Only the historical GreenToad name can opt into the old generated study.
    -- Untagged canonical resources cannot stand in for either canonical player.
    if heroTemplate~='Mr. Green' then return nil,'NO_CHARACTER_RESOURCE' end
    local legacy=templates and templates:FindFirstChild('GreenToad')
    if not legacy then return nil,'NO_CHARACTER_RESOURCE' end
    if not legacy:IsA('Model') then return nil,'INVALID_CHARACTER_RESOURCE' end
    local profile=legacy:FindFirstChild('AppearanceProfile')
    if profile and (not profile:IsA('StringValue') or profile.Value~='LegacyGeneratedGreen') then return nil,'UNKNOWN_APPEARANCE_PROFILE' end
    return legacy,'LegacyGeneratedGreen',math.rad(45)
end
local function scaled(frame,scale)
    return CFrame.new(frame.Position*scale)*frame.Rotation
end
local function motor(name,parent,part0,part1,c0,c1)
    local m=Instance.new('Motor6D');m.Name='Appearance'..name
    m.Part0=part0;m.Part1=part1;m.C0=c0;m.C1=c1;m.Parent=parent
    return m
end
local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end
local function tag(model,name,value)
    local child=model:FindFirstChild(name)
    return child and child:IsA('StringValue') and child.Value==value
end
local function prepareMorph(skin,template,heroTemplate,kind,spec)
    if not template or not template:IsA('Model') or not tag(template,'AppearanceProfile','CanonicalNESHeroMorph')
        or not tag(template,'MorphKind',kind) or not tag(template,'HeroTemplate',heroTemplate) then return nil end
    local scale=template:FindFirstChild('AppearanceScale')
    if not scale or not scale:IsA('NumberValue') or scale.Value~=1 then return nil end
    local clone
    local ok,row=pcall(function()
        clone=assert(template:Clone(),'Uncloneable morph')
        local part,count
        count=0
        for _,child in ipairs(clone:GetChildren()) do
            if child:IsA('MeshPart') then part=child;count+=1
            else assert(child:IsA('StringValue') or child:IsA('NumberValue'),'Unexpected morph object') end
        end
        assert(count==1 and part.Name=='Morph','Expected one Morph MeshPart')
        assert(type(part.MeshId)=='string' and part.MeshId:match('^rbxassetid://%d+$'),'Missing uploaded morph mesh')
        for _,value in ipairs({part.Size.X,part.Size.Y,part.Size.Z}) do assert(finite(value) and value>0,'Invalid morph size') end
        assert(finite(part.Transparency) and part.Transparency>=0 and part.Transparency<1,'Invisible morph resource')
        local origin,origins
        origins=0
        for _,child in ipairs(part:GetChildren()) do
            if child:IsA('Attachment') then
                assert(child.Name=='MorphOriginRigAttachment','Unexpected morph attachment');origin=child;origins+=1
            else assert(child:IsA('SurfaceAppearance'),'Unexpected morph content') end
        end
        assert(origins==1,'Missing morph origin')
        local identity=part.CFrame*origin.CFrame
        local x,y,z=identity:ToEulerAnglesXYZ()
        for _,value in ipairs({identity.Position.X,identity.Position.Y,identity.Position.Z,x,y,z}) do
            assert(finite(value) and math.abs(value)<=1e-4,'Morph origin must be identity in joint space')
        end
        local original=assert(skin:FindFirstChild(spec.part),'Missing original morph limb')
        local attachment=assert(original:FindFirstChild(spec.attachment),'Missing original morph joint')
        assert(original:IsA('MeshPart') and attachment:IsA('Attachment'),'Invalid original morph joint')
        local c0=attachment.CFrame*part.CFrame
        local visible=part.Transparency
        part.CFrame=original.CFrame*c0
        part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Massless=true;part.Transparency=1
        local joint=motor('Morph'..kind,part,original,part,c0,CFrame.new())
        clone.PrimaryPart=part
        return {part=part,model=clone,template=template,joint=joint,originalPart=original,
            visibleTransparency=visible,spec=spec}
    end)
    if not ok then if clone then clone:Destroy() end;return nil end
    return row
end
local function prepareMorphs(skin,heroTemplate,templates)
    local rows,folder={}
    local prefix=MORPH_PREFIX[heroTemplate]
    if templates and prefix then for kind,spec in pairs(MORPHS) do
        local row=prepareMorph(skin,templates:FindFirstChild(prefix..kind),heroTemplate,kind,spec)
        if row then
            if not folder then folder=Instance.new('Folder');folder.Name='Morphs';folder.Parent=skin end
            row.model.Parent=folder;rows[kind]=row
        end
    end end
    return rows,folder
end
local function restoreMorph(state,row)
    if row.originalTransparency~=nil then
        if row.originalPart.Parent==state.model then row.originalPart.Transparency=row.originalTransparency end
        row.originalTransparency=nil
    end
    if row.part.Parent==row.model then row.part.Transparency=1 end
end
local function updateMorphs(state,sourcePose)
    local requested=sourcePose and sourcePose.morphKind
    local active=state.morphs and state.morphs[requested]
    if active and not (state.morphFolder and state.morphFolder.Parent==state.model and active.model.Parent==state.morphFolder
        and active.part.Parent==active.model and active.originalPart==state.model:FindFirstChild(active.spec.part)
        and active.joint.Parent==active.part and active.joint.Part0==active.originalPart and active.joint.Part1==active.part
        and tag(active.model,'AppearanceProfile','CanonicalNESHeroMorph') and tag(active.model,'HeroTemplate',state.heroTemplate)
        and tag(active.model,'MorphKind',requested)) then active=nil end
    for _,row in pairs(state.morphs or {}) do
        if row==active then
            -- Capture at entry, not every render: an already hidden limb's1
            -- must never overwrite its exact original (possibly nonzero) value.
            if row.originalTransparency==nil then row.originalTransparency=row.originalPart.Transparency end
            row.part.Transparency=row.visibleTransparency;row.originalPart.Transparency=1
        else restoreMorph(state,row) end
    end
    state.activeMorph=active and requested or nil
end

function Appearance.detach(actor)
    local state=actor.appearance
    if not state then return end
    actor.appearance=nil
    updateMorphs(state,nil)
    state.presentation=nil;state.sourcePose=nil
    state.model:Destroy()
    for part,transparency in pairs(state.hidden) do
        if part.Parent and part:IsDescendantOf(state.ownerModel) then part.Transparency=transparency end
    end
    if state.metadataCaptured and state.ownerModel.Parent then
        state.ownerModel:SetAttribute('Template',state.previousTemplate)
        state.ownerModel:SetAttribute('Appearance',state.previousAppearance)
    end
end

function Appearance.update(actor,context)
    local state=actor.appearance
    if not state then return end
    if actor.model~=state.ownerModel or state.model.Parent~=state.ownerModel then
        Appearance.detach(actor);return
    end
    local sourcePose,fallback
    if HeroPresentation and state.profile=='CanonicalNESHero' and context then
        state.presentation=state.presentation or HeroPresentation.new()
        sourcePose,fallback=HeroPresentation.sample(state.presentation,context)
    elseif state.presentation then
        -- No trusted server context: discard the old sequence instead of
        -- allowing an extended limb to persist or resume on a later update.
        state.presentation=nil
    end
    state.sourcePose,state.sourceFallback=sourcePose,fallback
    updateMorphs(state,sourcePose)
    local deltas,pitches={},{}
    for _,name in ipairs(RIG_NAMES) do
        local r=state.rig[name]
        local delta=(r.base:Inverse()*r.joint.C0).Rotation
        deltas[name]=delta;pitches[name]=delta:ToEulerAnglesXYZ()
    end
    for _,definition in ipairs(JOINTS) do
        local name,source=definition[1],definition[4]
        local delta=source and deltas[source] or CFrame.new()
        -- Only the old generated study needs the splayed-arm correction.
        -- Canonical resources keep their authored shoulder orientation.
        if sourcePose then
            local angles=sourcePose.joints[name]
            delta=CFrame.Angles(angles[1],angles[2],angles[3])
        elseif name=='LeftShoulder' then delta=delta*CFrame.Angles(0,0,state.shoulderRoll)
        elseif name=='RightShoulder' then delta=delta*CFrame.Angles(0,0,-state.shoulderRoll)
        elseif name=='LeftElbow' or name=='RightElbow' then
            local shoulder=name=='LeftElbow' and 'Left Shoulder' or 'Right Shoulder'
            delta=CFrame.Angles(math.clamp(.15+math.max(0,pitches[shoulder])*.2,.15,.7),0,0)
        elseif name=='LeftKnee' or name=='RightKnee' then
            local hip=name=='LeftKnee' and 'Left Hip' or 'Right Hip'
            delta=CFrame.Angles(math.clamp(math.min(0,pitches[hip])*.6,-.75,0),0,0)
        end
        local joint=state.joints[name]
        if state.profile=='CanonicalNESHero' then
            -- The importer keeps a rotated MeshPart rest frame. Its authored
            -- attachment axes compensate for that rotation; apply the pose in
            -- those axes so a forward punch still follows the face's -Z axis.
            joint.motor.C0=joint.base*delta
        else
            joint.motor.C0=CFrame.new(joint.base.Position)*delta*joint.base.Rotation
        end
    end
end

function Appearance.attach(actor,heroTemplate,templates,morphTemplates)
    templates=templates or game:GetService('ServerStorage'):FindFirstChild('BrickToadsCharacterTemplates')
    morphTemplates=morphTemplates or game:GetService('ServerStorage'):FindFirstChild('BrickToadsCharacterMorphs')
    local template,profile,shoulderRoll=resource(templates,heroTemplate)
    if not template then return false,profile end
    local previous=actor.appearance
    if previous and previous.ownerModel==actor.model and previous.sourceTemplate==template
        and previous.heroTemplate==heroTemplate and previous.profile==profile then return true end
    local rig={}
    for _,part in ipairs(actor.model:GetDescendants()) do
        if part:IsA('Motor6D') then
            for _,name in ipairs(RIG_NAMES) do if part.Name==name then
                local current=actor.poseMotors and actor.poseMotors[name]
                rig[name]={joint=part,base=current and current.base or part.C0}
            end end
        end
    end
    for _,name in ipairs(RIG_NAMES) do if not rig[name] then return false,'NO_R6_POSE_RIG' end end
    local clone=template:Clone();clone.Name=template.Name..'Appearance'
    local ok,state=pcall(function()
        local scale=assert(clone:FindFirstChild('AppearanceScale'),'Missing fit scale').Value
        assert(type(scale)=='number' and scale>0 and scale<=2,'Invalid fit scale')
        local count=0
        for _,part in ipairs(clone:GetChildren()) do if part:IsA('MeshPart') then
            count+=1;part.Size=part.Size*scale
            part.CFrame=scaled(part.CFrame,scale)
            part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Massless=true
            for _,child in ipairs(part:GetChildren()) do
                assert(child:IsA('Attachment') or child:IsA('SurfaceAppearance'),'Template contains an unexpected rig object')
                if child:IsA('Attachment') then child.CFrame=scaled(child.CFrame,scale) end
            end
        end end
        assert(count==15,'Expected15 generated MeshParts')
        local torso=assert(actor.model:FindFirstChild('Torso'),'Missing R6 torso')
        local lower=assert(clone:FindFirstChild('LowerTorso'),'Missing visual torso')
        local rootOffset=lower.CFrame
        local joints={}
        for _,definition in ipairs(JOINTS) do
            local name=definition[1]
            local a,b=assert(clone:FindFirstChild(definition[2])),assert(clone:FindFirstChild(definition[3]))
            local c0=assert(a:FindFirstChild(name..'RigAttachment'),'Missing '..name..' source attachment').CFrame
            local c1=assert(b:FindFirstChild(name..'RigAttachment'),'Missing '..name..' target attachment').CFrame
            joints[name]={base=c0,motor=motor(name,b,a,b,c0,c1)}
        end
        motor('Root',lower,torso,lower,rootOffset,CFrame.new())
        for _,part in ipairs(clone:GetChildren()) do if part:IsA('MeshPart') then part.CFrame=torso.CFrame*part.CFrame end end
        local morphs,morphFolder
        if profile=='CanonicalNESHero' then morphs,morphFolder=prepareMorphs(clone,heroTemplate,morphTemplates) end
        return {model=clone,ownerModel=actor.model,sourceTemplate=template,heroTemplate=heroTemplate,
            profile=profile,shoulderRoll=shoulderRoll,rig=rig,joints=joints,hidden={},morphs=morphs,morphFolder=morphFolder}
    end)
    if not ok then clone:Destroy();return false,'INVALID_CHARACTER_RESOURCE: '..tostring(state) end
    -- Preparation touches only the clone. An invalid replacement must leave an
    -- existing appearance, visibility and presentation metadata intact.
    if previous then Appearance.detach(actor) end
    state.previousTemplate=actor.model:GetAttribute('Template')
    state.previousAppearance=actor.model:GetAttribute('Appearance')
    state.metadataCaptured=true
    clone.Parent=actor.model
    actor.appearance=state
    for _,part in ipairs(actor.model:GetChildren()) do if part:IsA('BasePart') and HIDDEN[part.Name] then
        state.hidden[part]=part.Transparency;part.Transparency=1
    end end
    actor.model:SetAttribute('Template',heroTemplate)
    actor.model:SetAttribute('Appearance',profile)
    Appearance.update(actor)
    return true
end

return Appearance
