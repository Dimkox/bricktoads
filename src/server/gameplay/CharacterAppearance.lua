-- Tagged canonical player resources and an explicit legacy Green study fallback.
-- Brown shares P1 anatomy with an approved third-player palette adaptation.
-- Priority/unsupported states retain R6 retargeting. Optional approved morphs
-- are preassembled before the caller pins ownership, then only change visibility.
-- Never replaces the R6 physical rig.
-- Caller must pin server network ownership AFTER all cosmetic parts are attached.
local Appearance={}
local skinSerial=0
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
local CANONICAL={['Mr. Green']='CanonicalPlayer1',['Mr. Yellow']='CanonicalPlayer2',['Mr. Brown']='CanonicalPlayerBrown'}
local MORPHS={PowerFist={part='RightHand',attachment='RightWristRigAttachment'},
    BigBoot={part='RightFoot',attachment='RightAnkleRigAttachment'},
    FearBeforeCut={part='Head',attachment='NeckRigAttachment'},
    FearAfterCut={part='Head',attachment='NeckRigAttachment'}}
local MORPH_PREFIX={['Mr. Green']='Green',['Mr. Yellow']='PlayerTwo',['Mr. Brown']='Brown'}
local RESOURCE_MAPS={'ColorMap','NormalMap','RoughnessMap','MetalnessMap','EmissiveMask'}
local function rawId(value)return type(value)=='string'and value or''end
local function mapUri(surface,property)
    -- Legacy map string properties are PluginSecurity, even for reads. The
    -- corresponding Content getters are available to normal server Scripts.
    local ok,id=pcall(function()
        local content=surface[property..'Content'];local source=content.SourceType.Name
        if source=='None'then return '' end
        if source=='Uri'then
            local uri=content.Uri;if type(uri)=='string'and uri~=''then return uri end
        end
    end)
    return ok and id or nil
end
local function captureResources(part)
    -- Capture the prepared resource, including explicit zero/empty values,
    -- before it enters Workspace. The client must not infer completeness from
    -- whichever children/properties have arrived in a replication packet.
    local surfaces={}
    for _,surface in ipairs(part:GetChildren())do if surface:IsA('SurfaceAppearance')then
        local maps={}
        for _,property in ipairs(RESOURCE_MAPS)do
            local id=assert(mapUri(surface,property),'Unreadable or unsupported '..property..'Content')
            maps[#maps+1]=property..#id..':'..id
        end
        surfaces[#surfaces+1]=table.concat(maps,'|')
    end end
    table.sort(surfaces)
    local tuples={};for _,surface in ipairs(surfaces)do tuples[#tuples+1]=#surface..':'..surface end
    part:SetAttribute('HeroExpectedSurfaceCount',#surfaces)
    part:SetAttribute('HeroExpectedSurfaceMaps',table.concat(tuples,';'))
    part:SetAttribute('HeroExpectedMeshId',rawId(part.MeshId))
    part:SetAttribute('HeroExpectedTextureId',rawId(part.TextureID))
end
local function resource(templates,heroTemplate)
    local name=CANONICAL[heroTemplate]
    if not name then return nil,'NO_CHARACTER_RESOURCE' end
    local candidate=templates and templates:FindFirstChild(name)
    if not candidate and heroTemplate=='Mr. Brown' then
        -- Reuse geometry only after the same canonical profile validation.
        -- Cloning/recoloring occurs later and never mutates this P1 resource.
        candidate=templates and templates:FindFirstChild('CanonicalPlayer1')
    end
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
local function brownPalette(model)
    local skin=Color3.fromRGB(160,112,86)
    -- Surface tint preserves the existing eye/mouth atlas details. A dedicated
    -- imported Brown atlas may replace this declared tint adaptation later.
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA('MeshPart') then
            part.Color=skin
            for _,surface in ipairs(part:GetChildren()) do
                if surface:IsA('SurfaceAppearance') then surface.Color=skin end
            end
        end
    end
    model:SetAttribute('PaletteAdaptation','ApprovedThirdHeroBrownPalette')
end
local function prepareMorph(skin,template,heroTemplate,kind,spec,sourceHero)
    sourceHero=sourceHero or heroTemplate
    if not template or not template:IsA('Model') or not tag(template,'AppearanceProfile','CanonicalNESHeroMorph')
        or not tag(template,'MorphKind',kind) or not tag(template,'HeroTemplate',sourceHero) then return nil end
    local scale=template:FindFirstChild('AppearanceScale')
    if not scale or not scale:IsA('NumberValue') or scale.Value~=1 then return nil end
    local clone
    local ok,row=pcall(function()
        clone=assert(template:Clone(),'Uncloneable morph')
        if heroTemplate=='Mr. Brown' then
            clone:FindFirstChild('HeroTemplate').Value=heroTemplate
            if sourceHero~='Mr. Brown' then brownPalette(clone) end
            clone:SetAttribute('PaletteAdaptation','ApprovedThirdHeroBrownPalette')
        end
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
        part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Massless=true
        -- The client composes base/morph availability in one local visibility
        -- coordinator. Server alpha must remain renderable even while loading.
        part:SetAttribute('HeroVisibleTransparency',visible)
        captureResources(part)
        clone:SetAttribute('HeroMorphKind',kind)
        local reference=Instance.new('ObjectValue');reference.Name='HeroMorphOriginal';reference.Value=original;reference.Parent=clone
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
        local source=templates:FindFirstChild(prefix..kind)
        local sourceHero=heroTemplate
        if not source and heroTemplate=='Mr. Brown' then source=templates:FindFirstChild('Green'..kind);sourceHero='Mr. Green' end
        local row=prepareMorph(skin,source,heroTemplate,kind,spec,sourceHero)
        if row then
            if not folder then folder=Instance.new('Folder');folder.Name='Morphs';folder.Parent=skin end
            row.model.Parent=folder;rows[kind]=row
        end
    end end
    return rows,folder
end
local function updateMorphs(state,sourcePose)
    local requested=sourcePose and sourcePose.morphKind
    local active=state.morphs and state.morphs[requested]
    if active and not (state.morphFolder and state.morphFolder.Parent==state.model and active.model.Parent==state.morphFolder
        and active.part.Parent==active.model and active.originalPart==state.model:FindFirstChild(active.spec.part)
        and active.joint.Parent==active.part and active.joint.Part0==active.originalPart and active.joint.Part1==active.part
        and tag(active.model,'AppearanceProfile','CanonicalNESHeroMorph') and tag(active.model,'HeroTemplate',state.heroTemplate)
        and tag(active.model,'MorphKind',requested)) then active=nil end
    state.activeMorph=active and requested or nil
    -- Playback publishes intent only. All fifteen base parts and four optional
    -- morph assemblies already exist before network ownership is pinned.
    if state.skinId and state.model:GetAttribute('HeroActiveMorph')~=state.activeMorph then
        state.model:SetAttribute('HeroActiveMorph',state.activeMorph)
    end
end
local function restoreGeometry(state)
    for _,row in pairs(state.geometryParts or {})do
        row.part.Size=row.size
        for attachment,frame in pairs(row.attachments)do attachment.CFrame=frame end
    end
    for _,joint in pairs(state.joints)do joint.motor.C0=joint.base;joint.motor.C1=joint.baseC1 end
    if state.rootJoint then state.rootJoint.motor.C0=state.rootJoint.base;state.rootJoint.motor.C1=state.rootJoint.baseC1 end
end
local function triple(values,positive)
    if type(values)~='table' or #values~=3 then return false end
    for _,n in ipairs(values)do
        if not finite(n) or (positive and (n<=0 or n>3)) or (not positive and math.abs(n)>2)then return false end
    end
    return true
end
local function validGeometry(state,geometry)
    if geometry==nil then return true end
    if type(geometry)~='table' or type(geometry.parts)~='table' then return false end
    for name,scale in pairs(geometry.parts)do if not state.geometryParts[name] or not triple(scale,true)then return false end end
    if geometry.offsets~=nil then
        if type(geometry.offsets)~='table' then return false end
        for name,offset in pairs(geometry.offsets)do if not state.joints[name] or not triple(offset,false)then return false end end
    end
    return geometry.rootOffset==nil or triple(geometry.rootOffset,false)
end
local function rescaled(frame,scale)
    local p=frame.Position
    return CFrame.new(p.X*scale[1],p.Y*scale[2],p.Z*scale[3])*frame.Rotation
end
local function applyGeometry(state,geometry)
    if not geometry then return end
    for name,scale in pairs(geometry.parts)do
        local row=state.geometryParts[name];local size=row.size
        row.part.Size=Vector3.new(size.X*scale[1],size.Y*scale[2],size.Z*scale[3])
        for attachment,frame in pairs(row.attachments)do attachment.CFrame=rescaled(frame,scale)end
    end
    for _,joint in pairs(state.joints)do joint.motor.C1=joint.attachment1.CFrame end
    if geometry.rootOffset then state.rootJoint.motor.C0=state.rootJoint.base*CFrame.new(table.unpack(geometry.rootOffset))end
end
local function alignRideDeck(state,sourcePose,deckY)
    if not sourcePose or sourcePose.kind~='Ride' or not finite(deckY)then return end
    local root=state.rootJoint and state.rootJoint.motor
    if not root or not root.Part0 or not root.Part1 then return end
    -- Native cosmetic Part.CFrames may still describe the previous heartbeat.
    -- Solve this frame's exact authored Motor6D equations from the physical
    -- torso, without moving any physical or cosmetic part directly.
    local frames={[root.Part1]=root.Part0.CFrame*root.C0*root.C1:Inverse()}
    for _,definition in ipairs(JOINTS)do
        local joint=state.joints[definition[1]].motor
        local parent=joint.Part0 and frames[joint.Part0]
        if not parent or not joint.Part1 then return end
        frames[joint.Part1]=parent*joint.C0*joint.C1:Inverse()
    end
    local lowest=math.huge
    for _,name in ipairs({'LeftFoot','RightFoot'})do
        local row=state.geometryParts[name];local p=row and row.part
        local frame=p and p.Parent==state.model and frames[p]
        if not frame then return end
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            local corner=frame*CFrame.new(p.Size.X*x/2,p.Size.Y*y/2,p.Size.Z*z/2)
            lowest=math.min(lowest,corner.Position.Y)
        end end end
    end
    local delta=deckY-lowest
    if not finite(delta)then return end
    -- Convert a WORLD vertical shift into the torso's current local axes.
    -- restoreGeometry resets Root.C0 before every update, so this never stacks.
    local localShift=(root.Part0.CFrame.Rotation:Inverse()*CFrame.new(0,delta,0)).Position
    root.C0=CFrame.new(localShift)*root.C0
end

function Appearance.detach(actor)
    local state=actor.appearance
    if not state then return end
    actor.appearance=nil
    updateMorphs(state,nil)
    restoreGeometry(state)
    state.presentation=nil;state.sourcePose=nil
    if state.skinId then
        game:GetService('CollectionService'):RemoveTag(state.model,'BrickToadsHeroSkin')
        for part,metadata in pairs(state.fallbackMetadata)do
            if part.Parent and part:GetAttribute('HeroFallbackOwner')==state.skinId then
                part:SetAttribute('HeroFallbackOwner',metadata.owner)
                part:SetAttribute('HeroFallbackTransparency',metadata.alpha)
            end
        end
    end
    state.model:Destroy()
    for part,transparency in pairs(state.hidden) do
        if part.Parent and part:IsDescendantOf(state.ownerModel) then part.Transparency=transparency end
    end
    if state.metadataCaptured and state.ownerModel.Parent
        and (not state.skinId or state.ownerModel:GetAttribute('HeroAppearanceOwner')==state.skinId)then
        state.ownerModel:SetAttribute('Template',state.previousTemplate)
        state.ownerModel:SetAttribute('Appearance',state.previousAppearance)
        if state.skinId then state.ownerModel:SetAttribute('HeroAppearanceOwner',state.previousHeroOwner)end
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
        -- Keep the observed acceptance identity when context is unavailable.
        -- Recreating state next frame would reaccept the same old attack.
        if HeroPresentation then HeroPresentation.cancel(state.presentation)
        else state.presentation=nil end
    end
    state.sourcePose,state.sourceFallback=sourcePose,fallback
    restoreGeometry(state)
    if sourcePose and not validGeometry(state,sourcePose.geometry)then
        if HeroPresentation then HeroPresentation.cancel(state.presentation,context and (context.attack or context.visualAction))end
        sourcePose=nil;state.sourcePose=nil;state.sourceFallback='InvalidGeometry'
    end
    applyGeometry(state,sourcePose and sourcePose.geometry)
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
            local base=sourcePose and sourcePose.geometry and joint.attachment0.CFrame or joint.base
            local offset=sourcePose and sourcePose.geometry and sourcePose.geometry.offsets and sourcePose.geometry.offsets[name]
            joint.motor.C0=base*(offset and CFrame.new(table.unpack(offset))or CFrame.new())*delta
        else
            joint.motor.C0=CFrame.new(joint.base.Position)*delta*joint.base.Rotation
        end
    end
    alignRideDeck(state,sourcePose,context and context.rideDeckY)
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
    local clone=template:Clone();clone.Name=(CANONICAL[heroTemplate] or template.Name)..'Appearance'
    local ok,state=pcall(function()
        local scale=assert(clone:FindFirstChild('AppearanceScale'),'Missing fit scale').Value
        assert(type(scale)=='number' and scale>0 and scale<=2,'Invalid fit scale')
        local count=0;local geometryParts={}
        for _,part in ipairs(clone:GetChildren()) do if part:IsA('MeshPart') then
            count+=1;part.Size=part.Size*scale
            part.CFrame=scaled(part.CFrame,scale)
            part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Massless=true
            for _,child in ipairs(part:GetChildren()) do
                assert(child:IsA('Attachment') or child:IsA('SurfaceAppearance'),'Template contains an unexpected rig object')
                if child:IsA('Attachment') then child.CFrame=scaled(child.CFrame,scale) end
            end
            local captured={part=part,size=part.Size,attachments={}}
            for _,child in ipairs(part:GetChildren())do if child:IsA('Attachment')then captured.attachments[child]=child.CFrame end end
            geometryParts[part.Name]=captured
        end end
        assert(count==15,'Expected15 generated MeshParts')
        if heroTemplate=='Mr. Brown' then
            if template.Name~='CanonicalPlayerBrown' then brownPalette(clone) end
            clone:SetAttribute('PaletteAdaptation','ApprovedThirdHeroBrownPalette')
        end
        local torso=assert(actor.model:FindFirstChild('Torso'),'Missing R6 torso')
        local lower=assert(clone:FindFirstChild('LowerTorso'),'Missing visual torso')
        local rootOffset=lower.CFrame
        local joints={}
        for _,definition in ipairs(JOINTS) do
            local name=definition[1]
            local a,b=assert(clone:FindFirstChild(definition[2])),assert(clone:FindFirstChild(definition[3]))
            local attachment0=assert(a:FindFirstChild(name..'RigAttachment'),'Missing '..name..' source attachment')
            local attachment1=assert(b:FindFirstChild(name..'RigAttachment'),'Missing '..name..' target attachment')
            local c0,c1=attachment0.CFrame,attachment1.CFrame
            joints[name]={base=c0,baseC1=c1,attachment0=attachment0,attachment1=attachment1,motor=motor(name,b,a,b,c0,c1)}
        end
        local rootC1=CFrame.new()
        local rootJoint={base=rootOffset,baseC1=rootC1,motor=motor('Root',lower,torso,lower,rootOffset,rootC1)}
        for _,part in ipairs(clone:GetChildren()) do if part:IsA('MeshPart') then part.CFrame=torso.CFrame*part.CFrame end end
        local morphs,morphFolder
        if profile=='CanonicalNESHero' then morphs,morphFolder=prepareMorphs(clone,heroTemplate,morphTemplates) end
        local skinId
        if profile=='CanonicalNESHero' then
            skinSerial+=1;skinId='hero-'..skinSerial
            clone:SetAttribute('CanonicalHeroSkin',true);clone:SetAttribute('HeroSkinId',skinId)
            clone:SetAttribute('HeroExpectedBasePartCount',15)
            for _,part in ipairs(clone:GetChildren())do if part:IsA('MeshPart')then
                assert(finite(part.Transparency)and part.Transparency>=0 and part.Transparency<1,'Invisible base resource')
                part:SetAttribute('HeroVisibleTransparency',part.Transparency)
                captureResources(part)
            end end
        end
        return {model=clone,ownerModel=actor.model,sourceTemplate=template,heroTemplate=heroTemplate,
            profile=profile,shoulderRoll=shoulderRoll,rig=rig,joints=joints,rootJoint=rootJoint,geometryParts=geometryParts,
            hidden={},morphs=morphs,morphFolder=morphFolder,skinId=skinId,fallbackMetadata={}}
    end)
    if not ok then clone:Destroy();return false,'INVALID_CHARACTER_RESOURCE: '..tostring(state) end
    -- Preparation touches only the clone. An invalid replacement must leave an
    -- existing appearance, visibility and presentation metadata intact.
    if previous then Appearance.detach(actor) end
    state.previousTemplate=actor.model:GetAttribute('Template')
    state.previousAppearance=actor.model:GetAttribute('Appearance')
    state.previousHeroOwner=actor.model:GetAttribute('HeroAppearanceOwner')
    state.metadataCaptured=true
    clone.Parent=actor.model
    actor.appearance=state
    local fallbackCount=0
    for _,part in ipairs(actor.model:GetChildren()) do if part:IsA('BasePart') and HIDDEN[part.Name] then
        if state.skinId then
            fallbackCount+=1
            state.fallbackMetadata[part]={owner=part:GetAttribute('HeroFallbackOwner'),alpha=part:GetAttribute('HeroFallbackTransparency')}
            part:SetAttribute('HeroFallbackOwner',state.skinId);part:SetAttribute('HeroFallbackTransparency',part.Transparency)
            local reference=Instance.new('ObjectValue');reference.Name='HeroFallbackTarget';reference.Value=part;reference.Parent=clone
        else
            -- The old generated study keeps its explicit legacy behavior.
            state.hidden[part]=part.Transparency;part.Transparency=1
        end
    end end
    actor.model:SetAttribute('Template',heroTemplate)
    actor.model:SetAttribute('Appearance',profile)
    if state.skinId then
        clone:SetAttribute('HeroExpectedFallbackCount',fallbackCount)
        actor.model:SetAttribute('HeroAppearanceOwner',state.skinId)
        game:GetService('CollectionService'):AddTag(clone,'BrickToadsHeroSkin')
    end
    Appearance.update(actor)
    return true
end

return Appearance
