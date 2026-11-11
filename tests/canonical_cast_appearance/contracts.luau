function Frame:GetComponents() return self.Position.X,self.Position.Y,self.Position.Z,1,0,0,0,1,0,0,0,1 end
local env=setmetatable({script={Parent={CanonicalCastPresentation='Presentation'}},
    require=function(name) assert(name=='Presentation');return ActualPresentation end,
    game={GetService=function(_,name) assert(name=='CollectionService');return {
        AddTag=function(_,model,tag) model:SetAttribute('TestCollectionTag',tag) end} end},
    Instance={new=function(class) return node(class) end},CFrame=cf,Vector3={new=vector}},{__index=getfenv()})
local loader=assert(loadstring(AppearanceSource));setfenv(loader,env);local A=loader()
local function value(parent,name,text) local v=node('StringValue',name,parent);v.Value=text;return v end
local function template()
    local folder=node('Folder');local m=node('Model','Pig',folder)
    value(m,'AppearanceProfile','CanonicalNESCast');value(m,'CastKind','Pig')
    value(m,'SourcePin','f1a43b69577246850d136473700a333b3cdfe93f')
    for _,name in ipairs({'Body','Head'}) do
        local p=node('MeshPart',name,m);p._props.MeshId='rbxassetid://12345';p.Size=vector(2,2,2)
        p.CFrame=frame(0,name=='Body' and 0 or 2,0);p.Transparency=0
        value(p,'ParentSegment',name=='Body' and '@Torso' or 'Body')
        local a=node('Attachment','CastRigAttachment',p);a.CFrame=frame()
    end
    local a=node('Attachment','CastHeadRigAttachment',m.Body);a.CFrame=frame(0,2,0)
    return folder,m
end
local function actor()
    local m=node('Model','PhysicalActor',node('Workspace'))
    local root=node('Part','HumanoidRootPart',m);root.CFrame=frame(5,3,0);root.Transparency=1
    local torso=node('Part','Torso',m);torso.CFrame=frame(5,3,0);torso.Transparency=.2;torso.CanCollide=true
    local old=node('Part','FallbackFace',m);old.CFrame=frame();old.Transparency=.3
    return {model=m,root=root,humanoid={Health=47},actorId='real'},torso,old
end
local passed,failed=0,0;local function check(name,fn) local ok,why=pcall(fn);if ok then passed+=1;print('PASS cast skin '..name)else failed+=1;print('FAIL cast skin '..name..': '..tostring(why))end end
check('valid skins preserve physical body and make every new part cosmetic',function()
    local f=template();local a,t,old=actor();local physical=t.CFrame
    assert(A.attach(a,'Pig',f));assert(t.CFrame==physical and t.CanCollide and a.humanoid.Health==47)
    assert(t.Transparency==.2 and old.Transparency==.3,'Server must retain the visible fallback')
    assert(t:GetAttribute('CastFallbackOwner')==a.castAppearance.skinId)
    for _,p in ipairs(a.castAppearance.model:GetChildren()) do if p:IsA('MeshPart') then
        assert(p.Massless and not p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
    end end
end)
check('repeat and neighbouring actors retain independent instances',function()
    local f=template();local a=actor();local b=actor();assert(A.attach(a,'Pig',f) and A.attach(b,'Pig',f))
    local skin=a.castAppearance.model;assert(A.attach(a,'Pig',f) and a.castAppearance.model==skin)
    assert(skin~=b.castAppearance.model and skin.Head~=b.castAppearance.model.Head)
end)
check('detach restores exact prior alpha and never edits collider health',function()
    local f=template();local a,t,old=actor();assert(A.attach(a,'Pig',f));local skin=a.castAppearance.model
    A.detach(a);assert(not a.castAppearance and skin.destroyed and t.Transparency==.2 and old.Transparency==.3)
    assert(t.CanCollide and a.humanoid.Health==47)
end)
check('cyclic absent parent and missing pivot fail atomically',function()
    for _,mode in ipairs({'Cycle','Absent','Pivot'}) do
        local f,m=template();local a,t=actor()
        if mode=='Cycle' then m.Head.ParentSegment.Value='Head'
        elseif mode=='Absent' then m.Head.ParentSegment.Value='Missing'
        else m.Body.CastHeadRigAttachment:Destroy() end
        assert(not A.attach(a,'Pig',f));assert(not a.castAppearance and t.Transparency==.2)
    end
end)
check('nested executable content is rejected before attachment',function()
    local f,m=template();local surface=node('SurfaceAppearance','SurfaceAppearance',m.Head)
    node('Script','Unexpected',surface);local a,t=actor()
    assert(not A.attach(a,'Pig',f) and t.Transparency==.2)
end)
check('nonfinite transform invisible mesh and bad profile retain visible fallback',function()
    for _,mode in ipairs({'NaN','Invisible','Profile','Source','Kind'}) do
        local f,m=template();local a,t=actor()
        if mode=='NaN' then m.Head.CFrame=frame(0/0,0,0)
        elseif mode=='Invisible' then m.Head.Transparency=1
        elseif mode=='Profile' then m.AppearanceProfile.Value='Unknown'
        elseif mode=='Source' then m.SourcePin.Value='other'
        else m.CastKind.Value='Dragon' end
        assert(not A.attach(a,'Pig',f) and t.Transparency==.2)
    end
end)
check('invalid replacement never removes an already validated skin',function()
    local f=template();local a=actor();assert(A.attach(a,'Pig',f));local skin=a.castAppearance.model
    local other,m=template();m.Head.ParentSegment.Value='Missing'
    assert(not A.attach(a,'Pig',other) and a.castAppearance.model==skin and not skin.destroyed)
end)
check('pose only rotates cosmetic motors and retains physical transform',function()
    local f=template();local a,t=actor();assert(A.attach(a,'Pig',f));local physical=t.CFrame
    A.update(a,{kind='Pig',actorId='body',levelEpoch=1,now=10,reacting=true})
    assert(a.castAppearance.pose.state=='Reaction' and t.CFrame==physical and a.humanoid.Health==47)
    assert(a.castAppearance.joints.Head.motor.C0.rx~=0)
end)
check('replaced actor clears stale cosmetics without hiding new body',function()
    local f=template();local a=actor();assert(A.attach(a,'Pig',f));local old=a.model
    local fresh,t=actor();a.model=fresh.model
    A.update(a,{kind='Pig',actorId='new',now=10})
    assert(not a.castAppearance and t.Transparency==.2 and old.Torso.Transparency==.2)
end)
check('nested physics under metadata surfaces and attachments are rejected before replacing a valid skin',function()
    for _,container in ipairs({'Metadata','Surface','Attachment'})do
        local f,m=template();local a,t=actor();assert(A.attach(a,'Pig',f));local previous=a.castAppearance
        local bad,model=template();local parent
        if container=='Metadata' then parent=value(model,'ExtraMetadata','text')
        elseif container=='Surface' then parent=node('SurfaceAppearance','SurfaceAppearance',model.Head)
        else parent=model.Head.CastRigAttachment end
        local nested=node('MeshPart','UnpreparedPhysics',parent);nested._props.MeshId='rbxassetid://999'
        nested.CFrame=frame();nested.Size=vector(1,1,1);nested.Anchored=true;nested.CanCollide=true;nested.Transparency=0
        assert(not A.attach(a,'Pig',bad),'Nested physical mesh was admitted')
        assert(a.castAppearance==previous and not previous.model.destroyed and t.Transparency==.2)
    end
end)
check('invalid update clears the cosmetic pose and cannot resume the old accepted attack',function()
    local f=template();local a,t=actor();assert(A.attach(a,'Pig',f))
    local attack={name='PigJab',start=10,actorId='body',levelEpoch=1}
    A.update(a,{kind='Pig',actorId='body',levelEpoch=1,now=10,attack=attack})
    local state=a.castAppearance;assert(state.pose.animationId==0x28)
    A.update(a,{kind='Pig',actorId='body',levelEpoch=1,now=9,attack=attack})
    assert(state.pose==nil and state.model:GetAttribute('SourceGraphicsFrame')==nil)
    assert(state.joints.Head.motor.C0.rx==state.joints.Head.base.rx)
    A.update(a,{kind='Pig',actorId='body',levelEpoch=1,now=10.1,attack=attack})
    assert(not state.pose.animationId and #state.pose.events==0 and t.CanCollide)
end)
local function walkerTemplate()
    local f,m=template();m.Name='Walker';m.CastKind.Value='Walker';m.Head:Destroy();m.Body.CastHeadRigAttachment:Destroy()
    value(m,'SourcePixelScale','1')
    for _,side in ipairs({'Left','Right'})do
        local leg=node('MeshPart',side..'Leg',m);leg._props.MeshId='rbxassetid://123'
        leg.CFrame=frame(0,0,0);leg.Size=vector(1,58,1);leg.Transparency=0
        value(leg,'ParentSegment','Body');local pivot=node('Attachment','CastRigAttachment',leg);pivot.CFrame=frame()
        local from=node('Attachment','Cast'..side..'LegRigAttachment',m.Body);from.CFrame=frame(0,-28,0)
        local foot=node('MeshPart',side..'Foot',m);foot._props.MeshId='rbxassetid://124'
        foot.CFrame=frame(0,-29,0);foot.Size=vector(2,5,2);foot.Transparency=0
        value(foot,'ParentSegment',side..'Leg');pivot=node('Attachment','CastRigAttachment',foot);pivot.CFrame=frame()
        from=node('Attachment','Cast'..side..'FootRigAttachment',leg);from.CFrame=frame(0,-29,0)
    end
    return f,m
end
check('Walker source endpoint changes move and resize real straight leg cosmetics then restore on reaction',function()
    local f=walkerTemplate();local a,t=actor();assert(A.attach(a,'Walker',f))
    local state=a.castAppearance;local leg=state.joints.LeftLeg;local foot=state.joints.LeftFoot
    local size=leg.part.Size;local c1=leg.motor.C1;local collider=t.CFrame
    local attack={name='WalkerLight',start=10,actorId='body',levelEpoch=1}
    A.update(a,{kind='Walker',actorId='body',levelEpoch=1,now=10+11/60,attack=attack})
    assert(state.pose.components and leg.part.Size.Y>size.Y,'Walker components never resized the strut')
    assert(leg.motor.C0.Position.X~=leg.base.Position.X and leg.motor.C0.rz~=leg.base.rz)
    assert(foot.motor.C0.Position.Y~=foot.base.Position.Y and foot.motor.C0.rz~=foot.base.rz)
    assert(t.CFrame==collider and t.CanCollide and a.humanoid.Health==47)
    A.update(a,{kind='Walker',actorId='body',levelEpoch=1,now=11,reacting=true,attack=attack})
    assert(leg.part.Size==size and leg.motor.C1==c1,'Reaction must restore the saved native geometry exactly')
end)
check('Walker pixel scale is validated before a new skin hides the physical fallback',function()
    local f,m=walkerTemplate();m.SourcePixelScale.Value='nan';local a,t=actor()
    assert(not A.attach(a,'Walker',f) and not a.castAppearance and t.Transparency==.2)
end)
check('changed joint endpoints detach the saved skin without editing a foreign body',function()
    local f=template();local a,t=actor();assert(A.attach(a,'Pig',f));local other,foreign=actor()
    a.castAppearance.joints.Head.motor.Part0=foreign
    A.update(a,{kind='Pig',actorId='body',levelEpoch=1,now=10})
    assert(not a.castAppearance and t.Transparency==.2 and foreign.Transparency==.2)
end)
check('client preload owns visibility while server keeps explicit fallback references and never fetches meshes',function()
    local f=template();local a,t,old=actor();assert(A.attach(a,'Pig',f))
    local s=a.castAppearance
    assert(t.Transparency==.2 and old.Transparency==.3 and s.model:GetAttribute('CanonicalCastSkin')==true)
    assert(s.model:GetAttribute('TestCollectionTag')=='BrickToadsCastSkin')
    local found=false
    for _,reference in ipairs(s.model:GetChildren()) do
        if reference:IsA('ObjectValue') and reference.Name=='CastFallbackTarget' and reference.Value==t then found=true end
    end
    assert(found and t:GetAttribute('CastFallbackOwner')==s.skinId)
    local external=node('Part','ExternalSupport',node('Workspace'));external.Transparency=.15
    assert(A.addFallback(a,external) and not A.addFallback(a,external))
    assert(external.Transparency==.15 and external:GetAttribute('CastFallbackOwner')==s.skinId)
    A.detach(a);assert(external.Transparency==.15 and external:GetAttribute('CastFallbackOwner')==nil)
    assert(t:GetAttribute('CastFallbackOwner')==nil and old.Transparency==.3)
end)
