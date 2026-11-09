-- Tagged canonical P1/P2 resources and an explicit legacy Green study fallback.
-- Retargeting still follows existing R6 deltas; source pose/morph binding is separate.
-- Never replaces the R6 physical rig.
-- Caller must pin server network ownership AFTER all cosmetic parts are attached.
local Appearance={}
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

function Appearance.detach(actor)
    local state=actor.appearance
    if not state then return end
    actor.appearance=nil
    state.model:Destroy()
    for part,transparency in pairs(state.hidden) do
        if part.Parent and part:IsDescendantOf(state.ownerModel) then part.Transparency=transparency end
    end
    if state.metadataCaptured and state.ownerModel.Parent then
        state.ownerModel:SetAttribute('Template',state.previousTemplate)
        state.ownerModel:SetAttribute('Appearance',state.previousAppearance)
    end
end

function Appearance.update(actor)
    local state=actor.appearance
    if not state then return end
    if actor.model~=state.ownerModel or state.model.Parent~=state.ownerModel then
        Appearance.detach(actor);return
    end
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
        if name=='LeftShoulder' then delta=delta*CFrame.Angles(0,0,state.shoulderRoll)
        elseif name=='RightShoulder' then delta=delta*CFrame.Angles(0,0,-state.shoulderRoll)
        elseif name=='LeftElbow' or name=='RightElbow' then
            local shoulder=name=='LeftElbow' and 'Left Shoulder' or 'Right Shoulder'
            delta=CFrame.Angles(math.clamp(.15+math.max(0,pitches[shoulder])*.2,.15,.7),0,0)
        elseif name=='LeftKnee' or name=='RightKnee' then
            local hip=name=='LeftKnee' and 'Left Hip' or 'Right Hip'
            delta=CFrame.Angles(math.clamp(math.min(0,pitches[hip])*.6,-.75,0),0,0)
        end
        local joint=state.joints[name]
        joint.motor.C0=CFrame.new(joint.base.Position)*delta*joint.base.Rotation
    end
end

function Appearance.attach(actor,heroTemplate,templates)
    templates=templates or game:GetService('ServerStorage'):FindFirstChild('BrickToadsCharacterTemplates')
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
        return {model=clone,ownerModel=actor.model,sourceTemplate=template,heroTemplate=heroTemplate,
            profile=profile,shoulderRoll=shoulderRoll,rig=rig,joints=joints,hidden={}}
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
