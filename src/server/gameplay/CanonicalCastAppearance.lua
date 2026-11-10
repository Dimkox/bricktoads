-- Imported cast surfaces articulate on an unchanged authoritative collider rig.
local Presentation=if script then require(script.Parent.CanonicalCastPresentation) else require('./CanonicalCastPresentation')
local A={}
local PIN='f1a43b69577246850d136473700a333b3cdfe93f'
local attachmentSequence=0
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function tagged(t,name,value)
    local v=t:FindFirstChild(name);return v and v:IsA('StringValue') and v.Value==value
end
local function checkedFrame(frame)
    local values={frame:GetComponents()};assert(#values==12,'Invalid cast frame')
    for _,n in ipairs(values) do assert(finite(n),'Nonfinite cast transform') end
    return frame
end
function A.detach(actor)
    local s=actor.castAppearance;if not s then return end
    actor.castAppearance=nil;s.model:Destroy()
    for p,alpha in pairs(s.hidden) do
        if p.Parent and p:GetAttribute('CastFallbackOwner')==s.skinId then
            local prior=s.fallbackMetadata[p]
            p:SetAttribute('CastFallbackOwner',prior.owner);p:SetAttribute('CastFallbackTransparency',prior.alpha)
            -- Visibility is selected locally after typed client preloading;
            -- the authoritative fallback remains available on the server.
            if p:IsDescendantOf(s.ownerModel) then p.Transparency=alpha end
        end
    end
    if actor.model==s.ownerModel then actor.model:SetAttribute('CastAppearance',s.previousTag) end
end
function A.addFallback(actor,part)
    local s=actor.castAppearance
    if not s or not part or not part:IsA('BasePart') or s.hidden[part]~=nil then return false end
    s.hidden[part]=part.Transparency
    s.fallbackMetadata[part]={owner=part:GetAttribute('CastFallbackOwner'),alpha=part:GetAttribute('CastFallbackTransparency')}
    part:SetAttribute('CastFallbackOwner',s.skinId);part:SetAttribute('CastFallbackTransparency',part.Transparency)
    local reference=Instance.new('ObjectValue');reference.Name='CastFallbackTarget';reference.Value=part;reference.Parent=s.model
    return true
end
function A.attach(actor,kind,templates)
    templates=templates or game:GetService('ServerStorage'):FindFirstChild('BrickToadsCastTemplates')
    local t=templates and templates:FindFirstChild(kind)
    if not t or not t:IsA('Model') or not tagged(t,'AppearanceProfile','CanonicalNESCast')
        or not tagged(t,'CastKind',kind) or not tagged(t,'SourcePin',PIN) then return false,'NO_CAST_RESOURCE' end
    local previous=actor.castAppearance
    if previous and previous.ownerModel==actor.model and previous.sourceTemplate==t then return true end
    local clone
    local ok,s=pcall(function()
        clone=assert(t:Clone(),'Uncloneable cast resource');clone.Name=kind..'Appearance'
        local torso=assert(actor.model:FindFirstChild('Torso'),'Missing physical torso')
        for _,d in ipairs(clone:GetDescendants()) do
            assert(d:IsA('MeshPart') or d:IsA('StringValue') or d:IsA('Attachment') or d:IsA('SurfaceAppearance'),
                'Unexpected cast descendant')
            if d:IsA('MeshPart') then assert(d.Parent==clone,'Nested cast physics')
            else assert(#d:GetChildren()==0,'Cast metadata, attachments and surfaces must be leaves')end
        end
        local parts,parents,count={},{},0
        for _,p in ipairs(clone:GetChildren()) do
            if p:IsA('MeshPart') then
                count+=1;assert(not parts[p.Name],'Duplicate cast segment');parts[p.Name]=p
                assert(type(p.MeshId)=='string' and p.MeshId:match('^rbxassetid://%d+$'),'Missing uploaded mesh')
                assert(finite(p.Transparency) and p.Transparency>=0 and p.Transparency<1,'Invisible cast resource')
                for _,n in ipairs({p.Size.X,p.Size.Y,p.Size.Z}) do assert(finite(n) and n>0,'Invalid cast dimensions') end
                checkedFrame(p.CFrame)
                local parent=p:FindFirstChild('ParentSegment');assert(parent and parent:IsA('StringValue'),'Missing cast parent')
                parents[p.Name]=parent.Value
                for _,child in ipairs(p:GetChildren()) do
                    assert(child:IsA('Attachment') or child:IsA('SurfaceAppearance') or child==parent,'Unexpected segment child')
                    if child:IsA('Attachment') then checkedFrame(child.CFrame) end
                end
                p.Anchored=false;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
            else assert(p:IsA('StringValue'),'Unexpected cast model child') end
        end
        assert(count>=1 and count<=32 and parts.Body and parents.Body=='@Torso','Invalid cast root')
        local joints={}
        for name,p in pairs(parts) do
            local parent=parents[name];local seen={[name]=true}
            while parent~='@Torso' do
                assert(parts[parent] and not seen[parent],'Cyclic or missing cast parent');seen[parent]=true;parent=parents[parent]
            end
            assert(name=='Body' or parents[name]~='@Torso','Multiple cast roots')
            local a=parents[name]=='@Torso' and torso or parts[parents[name]]
            local to=assert(p:FindFirstChild('CastRigAttachment'),'Missing child cast pivot')
            assert(to:IsA('Attachment'),'Invalid child cast pivot')
            local base=CFrame.new()
            if name~='Body' then
                local from=assert(a:FindFirstChild('Cast'..name..'RigAttachment'),'Missing parent cast pivot')
                assert(from:IsA('Attachment'),'Invalid parent cast pivot');base=from.CFrame
            end
            local m=Instance.new('Motor6D');m.Name='Cast'..name;m.Part0=a;m.Part1=p;m.C0=base;m.C1=to.CFrame;m.Parent=p
            joints[name]={motor=m,base=base,c1=to.CFrame,part=p,size=p.Size,parentPart=a}
        end
        local pixelScale
        if kind=='Walker' then
            assert(parts.LeftLeg and parts.RightLeg and parts.LeftFoot and parts.RightFoot,'Incomplete Walker components')
            local metadata=clone:FindFirstChild('SourcePixelScale')
            if metadata then assert(metadata:IsA('StringValue'),'Invalid source pixel scale');pixelScale=tonumber(metadata.Value)
            else pixelScale=parts.LeftLeg.Size.Y/58 end
            assert(finite(pixelScale) and pixelScale>0 and pixelScale<=10,'Invalid source pixel scale')
        end
        for _,p in pairs(parts) do p.CFrame=torso.CFrame*p.CFrame end
        local prior=actor.model:GetAttribute('CastAppearance');if previous then prior=previous.previousTag end
        return {model=clone,sourceTemplate=t,ownerModel=actor.model,kind=kind,joints=joints,hidden={},fallbackMetadata={},
            presentation=Presentation.new(),previousTag=prior,pixelScale=pixelScale}
    end)
    if not ok then if clone then clone:Destroy() end;return false,'INVALID_CAST_RESOURCE: '..tostring(s) end
    if previous then A.detach(actor) end
    attachmentSequence+=1;s.skinId=actor.model.Name..':'..tostring(attachmentSequence)
    clone:SetAttribute('CanonicalCastSkin',true);clone:SetAttribute('CastSkinId',s.skinId)
    actor.castAppearance=s
    for _,p in ipairs(actor.model:GetDescendants()) do
        if p:IsA('BasePart') and p~=actor.root then A.addFallback(actor,p) end
    end
    for _,j in pairs(s.joints) do j.part:SetAttribute('CastVisibleTransparency',j.part.Transparency) end
    clone.Parent=actor.model;actor.model:SetAttribute('CastAppearance','CanonicalNESCast')
    game:GetService('CollectionService'):AddTag(clone,'BrickToadsCastSkin')
    return true
end
local function restoreGeometry(s)
    for _,j in pairs(s.joints) do j.part.Size=j.size;j.motor.C1=j.c1 end
end
local function walkerComponents(s,components)
    if not components or components.units~='sourcePixels' then return end
    local pixel=s.pixelScale
    -- The imported straight strut is58 pixels high: top63 to foot-pivot5.
    -- CanonicalWalker type11 neutral anchors are head-57, starts-56/-58,
    -- terminal D3 feet(-3,0)/(-3,-2). Preserve each exact decoded endpoint.
    local bodyShift=-(components.headAnchor.y+57)*pixel
    local body=s.joints.Body;body.motor.C0=body.base*CFrame.new(0,bodyShift,0)
    for index,side in ipairs({'Left','Right'})do
        local source=components.legs[index];local last=source.sprites[#source.sprites]
        local leg=s.joints[side..'Leg'];local foot=s.joints[side..'Foot']
        local dx=(last.x+3)*pixel
        local topShift=-(source.start.y-(-56-(index-1)*2))*pixel
        local bottomShift=-(last.y-(-(index-1)*2))*pixel
        local height=leg.size.Y+topShift-bottomShift
        local length=math.sqrt(height*height+dx*dx)
        local ratio=length/leg.size.Y;local angle=math.atan2(dx,height)
        leg.part.Size=Vector3.new(leg.size.X,leg.size.Y*ratio,leg.size.Z)
        local centerY=(topShift+bottomShift)/2-bodyShift
        leg.motor.C0=leg.base*CFrame.new(dx/2,centerY,0)*CFrame.Angles(0,0,angle)
        local c1=leg.c1
        leg.motor.C1=CFrame.new(c1.Position.X,c1.Position.Y*ratio,c1.Position.Z)*c1.Rotation
        -- Foot position follows the lengthened straight shaft; counter-rotate
        -- at its own pivot so the D3 foot remains flat instead of tilting.
        local base=foot.base
        foot.motor.C0=CFrame.new(base.Position.X,base.Position.Y*ratio,base.Position.Z)*base.Rotation*CFrame.Angles(0,0,-angle)
    end
end
local function clearPose(s)
    Presentation.cancel(s.presentation);s.pose=nil;restoreGeometry(s)
    for _,j in pairs(s.joints)do j.motor.C0=j.base end
    s.model:SetAttribute('SourceGraphicsNamespace',nil);s.model:SetAttribute('SourceGraphicsFrame',nil)
    s.model:SetAttribute('VisualState',nil)
end
function A.update(actor,context)
    local s=actor.castAppearance;if not s then return end
    if actor.model~=s.ownerModel or s.model.Parent~=s.ownerModel then A.detach(actor);return end
    for _,j in pairs(s.joints) do
        if j.motor.Parent~=j.part or j.part.Parent~=s.model or j.motor.Part0~=j.parentPart or j.motor.Part1~=j.part then A.detach(actor);return end
    end
    if type(context)~='table' or context.kind~=s.kind then clearPose(s);return end
    local pose=Presentation.sample(s.presentation,context);if not pose then clearPose(s);return end
    s.pose=pose
    restoreGeometry(s)
    for name,j in pairs(s.joints) do
        local a=pose.joints[name] or {0,0,0};j.motor.C0=j.base*CFrame.Angles(a[1],a[2],a[3])
    end
    if s.kind=='Walker' then walkerComponents(s,pose.components)end
    s.model:SetAttribute('SourceGraphicsNamespace',pose.namespace)
    s.model:SetAttribute('SourceGraphicsFrame',pose.frameId)
    s.model:SetAttribute('VisualState',pose.state)
end
return A
