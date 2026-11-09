-- Lifecycle/pose API doubles only; no claim of simulated mesh rendering/physics.
local Vec={};Vec.__index=Vec
local function vector(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},Vec)end
function Vec.__mul(a,b)return vector(a.X*b,a.Y*b,a.Z*b)end
local Frame={}
local function frame(x,y,z)
    return setmetatable({Position=type(x)=='table'and x or vector(x,y,z),rx=0,ry=0,rz=0},Frame)
end
Frame.__index=function(a,k)
    if k=='Rotation'then local b=frame();b.rx,b.ry,b.rz=a.rx,a.ry,a.rz;return b end
    return Frame[k]
end
function Frame.__mul(a,b)
    local f=frame(a.Position.X+b.Position.X,a.Position.Y+b.Position.Y,a.Position.Z+b.Position.Z)
    f.rx,f.ry,f.rz=a.rx+b.rx,a.ry+b.ry,a.rz+b.rz;return f
end
function Frame:Inverse()
    local f=frame(-self.Position.X,-self.Position.Y,-self.Position.Z);f.rx,f.ry,f.rz=-self.rx,-self.ry,-self.rz;return f
end
function Frame:ToEulerAnglesXYZ()return self.rx,self.ry,self.rz end
local cf={new=frame,Angles=function(x,y,z)local f=frame();f.rx,f.ry,f.rz=x,y,z;return f end}
local Node={}
Node.__index=function(a,k)
    if Node[k]then return Node[k]end
    local v=a._props[k];if v~=nil then return v end
    return a:FindFirstChild(k)
end
Node.__newindex=function(a,k,v)
    assert(k~='MeshId','MeshId must never be assigned during gameplay')
    if k=='Parent'then
        local old=a._props.Parent
        if old then for i,c in ipairs(old._children)do if c==a then table.remove(old._children,i);break end end end
        if v then v._children[#v._children+1]=a end
    end
    a._props[k]=v
end
local function node(class,name,parent)
    local n=setmetatable({_props={ClassName=class,Name=name or class},_children={},_attributes={}},Node);n.Parent=parent;return n
end
function Node:IsA(class)return class==self.ClassName or class=='BasePart'and(self.ClassName=='Part'or self.ClassName=='MeshPart')end
function Node:GetChildren()return table.clone(self._children)end
function Node:FindFirstChild(name)for _,c in ipairs(self._children)do if c.Name==name then return c end end end
function Node:GetDescendants()
    local a={};for _,c in ipairs(self._children)do a[#a+1]=c;for _,d in ipairs(c:GetDescendants())do a[#a+1]=d end end;return a
end
function Node:IsDescendantOf(other)local p=self.Parent;while p do if p==other then return true end;p=p.Parent end;return false end
function Node:Clone()
    local n=node(self.ClassName,self.Name)
    for k,v in pairs(self._props)do if k~='Parent'then n._props[k]=v end end
    for _,c in ipairs(self._children)do c:Clone().Parent=n end
    return n
end
function Node:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil;self._props.destroyed=true end
function Node:SetAttribute(k,v)self._attributes[k]=v end
function Node:GetAttribute(k)return self._attributes[k]end
local storage=node('ServerStorage');local templates=node('Folder','BrickToadsCharacterTemplates',storage)
local template=node('Model','GreenToad',templates)
local scale=node('NumberValue','AppearanceScale',template);scale.Value=Manifest.fit.scale
for _,row in ipairs(Manifest.parts)do
    local p=node('MeshPart',row.name,template);p._props.MeshId=row.meshId;p.TextureID=row.textureId
    p.Size=vector(table.unpack(row.size));p.CFrame=frame(table.unpack(row.cframe));p.Anchored=true
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.Transparency=0
    for _,a in ipairs(row.attachments)do local child=node('Attachment',a.name,p);child.CFrame=frame(table.unpack(a.cframe))end
    for _,a in ipairs(row.surfaceAppearances)do local child=node('SurfaceAppearance',a.name,p);child.ColorMap=a.colorMap end
end
local env=setmetatable({game={GetService=function()return storage end},Instance={new=function(class)return node(class)end},CFrame=cf},{__index=getfenv()})
local loader=assert(loadstring(AppearanceSource));setfenv(loader,env);local Appearance=loader()
local workspace=node('Workspace')
local function actor(id)
    local m=node('Model','Actor_'..id,workspace);m:SetAttribute('ActorId',id)
    for _,name in ipairs({'HumanoidRootPart','Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg'})do
        local p=node('Part',name,m);p.Size=vector(2,2,1);p.CFrame=frame();p.Transparency=name=='HumanoidRootPart'and 1 or 0
        p.CanCollide=name=='Torso'or name=='Head';p.Anchored=false
    end
    local h=node('Humanoid','Humanoid',m);h.Health=100;h.WalkSpeed=24;h.JumpPower=50
    local a={model=m,root=m.HumanoidRootPart,humanoid=h,poseMotors={}}
    for _,name in ipairs({'Neck','Left Shoulder','Right Shoulder','Left Hip','Right Hip'})do
        local j=node('Motor6D',name,m.Torso);j.C0=frame();j.C1=frame();a.poseMotors[name]={joint=j,base=frame()}
    end
    return a
end
local passed=0
local function test(name,fn)fn();passed+=1;print('PASS '..name)end
local function canonicalTemplates()
    local folder=node('Folder','CanonicalTemplates')
    for i,name in ipairs({'CanonicalPlayer1','CanonicalPlayer2'})do
        local model=template:Clone();model.Name=name;model.AppearanceScale.Value=1;model.Parent=folder
        local profile=node('StringValue','AppearanceProfile',model);profile.Value='CanonicalNESHero'
        model.Head.SurfaceAppearance.ColorMap='canonical-player-'..i
    end
    return folder
end
test('Green attaches the actual fifteen mesh template with PBR and no additional humanoid',function()
    local a=actor('first');assert(Appearance.attach(a,'Mr. Green'))
    local n,h,motors=0,0,0
    for _,p in ipairs(a.model:GetDescendants())do
        if p:IsA('MeshPart')then n+=1;assert(not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Massless and not p.Anchored)
            assert(p:FindFirstChild('SurfaceAppearance').ColorMap~='')end
        if p:IsA('Humanoid')then h+=1 end
        if p:IsA('Motor6D')and string.sub(p.Name,1,10)=='Appearance'then motors+=1 end
    end
    assert(n==15 and h==1 and motors==15)
    assert(a.humanoid.Health==100 and a.humanoid.WalkSpeed==24 and a.humanoid.JumpPower==50)
    assert(a.model.Torso.CanCollide and a.model.Head.CanCollide and a.root.Anchored==false and a.model:GetAttribute('ActorId')=='first')
end)
test('Yellow Brown and missing templates retain their real fallback appearance',function()
    for _,name in ipairs({'Mr. Yellow','Mr. Brown','Other'})do local a=actor(name);assert(not Appearance.attach(a,name));assert(not a.appearance and a.model.Torso.Transparency==0)end
    local a=actor('missing');assert(not Appearance.attach(a,'Mr. Green',node('Folder')));assert(a.model.Torso.Transparency==0)
end)
test('two Green actors have independent cloned parts joints and pose deltas',function()
    local a,b=actor('a'),actor('b');assert(Appearance.attach(a,'Mr. Green')and Appearance.attach(b,'Mr. Green'))
    a.poseMotors['Right Shoulder'].joint.C0=cf.Angles(1.9,0,0)
    a.poseMotors['Left Hip'].joint.C0=cf.Angles(-.5,0,0)
    Appearance.update(a);Appearance.update(b)
    assert(a.appearance.model~=b.appearance.model and a.appearance.model.Head~=b.appearance.model.Head)
    local x=a.appearance.joints.RightShoulder.motor.C0:ToEulerAnglesXYZ();assert(math.abs(x-1.9)<1e-6)
    local y=b.appearance.joints.RightShoulder.motor.C0:ToEulerAnglesXYZ();assert(y==0)
    assert(a.appearance.joints.RightElbow.motor.C0.rx>b.appearance.joints.RightElbow.motor.C0.rx)
    assert(a.appearance.joints.LeftKnee.motor.C0.rx<0 and b.appearance.joints.LeftKnee.motor.C0.rx==0)
end)
test('repeat attachment does not clone again and detach restores only saved original visibility',function()
    local a=actor('repeat');assert(Appearance.attach(a,'Mr. Green'));local model=a.appearance.model
    assert(Appearance.attach(a,'Mr. Green')and a.appearance.model==model)
    assert(a.model.Torso.Transparency==1);Appearance.detach(a)
    assert(not a.appearance and model.destroyed and a.model.Torso.Transparency==0)
    assert(a.model.Torso.CanCollide and a.humanoid.Health==100)
end)
test('replaced actor model is never hidden restored or driven by stale cosmetic state',function()
    local a=actor('old');assert(Appearance.attach(a,'Mr. Green'));local old=a.appearance.model
    local replacement=actor('new');a.model=replacement.model
    Appearance.update(a)
    assert(not a.appearance and old.destroyed and replacement.model.Torso.Transparency==0)
    assert(replacement.model:GetAttribute('ActorId')=='new'and replacement.humanoid.Health==100)
end)
test('malformed source attachment rejects atomically before changing rig visibility',function()
    local bad=templates:Clone();bad.GreenToad.LeftHand.LeftWristRigAttachment:Destroy()
    local a=actor('bad');assert(not Appearance.attach(a,'Mr. Green',bad));assert(not a.appearance and a.model.Torso.Transparency==0)
end)

test('tagged canonical P1 and P2 select separate resources on the same R6 physical actor',function()
    local source=canonicalTemplates()
    for i,name in ipairs({'Mr. Green','Mr. Yellow'})do
        local a=actor('canonical-'..i)
        local model,root,humanoid=a.model,a.root,a.humanoid
        assert(Appearance.attach(a,name,source))
        assert(a.appearance.model.Head.SurfaceAppearance.ColorMap=='canonical-player-'..i)
        assert(a.model==model and a.root==root and a.humanoid==humanoid and humanoid.Health==100)
        assert(a.model.Torso.CanCollide and a.model.Head.CanCollide and not a.root.Anchored)
        assert(a.model:GetAttribute('ActorId')=='canonical-'..i)
        assert(a.model:GetAttribute('Template')==name and a.model:GetAttribute('Appearance')=='CanonicalNESHero')
        assert(a.appearance.model.Head.Size.X==source['CanonicalPlayer'..i].Head.Size.X,'Canonical template scale1 must retain its authored proportions')
        assert(source['CanonicalPlayer'..i].Head.Anchored,'Cloning cannot modify the stored source resource')
    end
end)

test('canonical shoulders retain their authored neutral rotations without explorer45degree correction',function()
    local source=canonicalTemplates();local a=actor('canonical-neutral')
    assert(Appearance.attach(a,'Mr. Green',source))
    for _,name in ipairs({'LeftShoulder','RightShoulder'})do
        local joint=a.appearance.joints[name]
        assert(joint.motor.C0.rz==joint.base.rz,'Canonical neutral shoulders cannot inherit the explorer arm roll')
    end
    a.poseMotors['Right Shoulder'].joint.C0=cf.Angles(1.2,0,.2)
    Appearance.update(a)
    assert(math.abs(a.appearance.joints.RightShoulder.motor.C0.rz-.2)<1e-6)
    local legacy=actor('legacy-neutral');assert(Appearance.attach(legacy,'Mr. Green'))
    assert(math.abs(legacy.appearance.joints.LeftShoulder.motor.C0.rz-math.rad(45))<1e-6)
    assert(math.abs(legacy.appearance.joints.RightShoulder.motor.C0.rz+math.rad(45))<1e-6)
end)

test('untagged canonical P2 is unavailable and never borrows a Green resource or invents Brown',function()
    local source=canonicalTemplates()
    source.CanonicalPlayer2.AppearanceProfile:Destroy()
    local legacy=template:Clone();legacy.Parent=source
    for _,name in ipairs({'Mr. Yellow','Mr. Brown'})do
        local a=actor(name);a.model:SetAttribute('Template','original');a.model:SetAttribute('Appearance','original-art')
        local ok=Appearance.attach(a,name,source)
        assert(not ok and not a.appearance and a.model.Torso.Transparency==0)
        assert(a.model:GetAttribute('Template')=='original'and a.model:GetAttribute('Appearance')=='original-art')
    end
    source.CanonicalPlayer1.AppearanceProfile:Destroy()
    local a=actor('explicit-legacy');assert(Appearance.attach(a,'Mr. Green',source))
    assert(a.appearance.model.Head.SurfaceAppearance.ColorMap==template.Head.SurfaceAppearance.ColorMap)
    assert(a.model:GetAttribute('Appearance')=='LegacyGeneratedGreen','Untagged GreenToad must remain identifiable as the legacy study')
end)

test('unknown explicit profiles reject before detaching a valid canonical appearance',function()
    local source=canonicalTemplates();local a=actor('profile-switch')
    assert(Appearance.attach(a,'Mr. Green',source));local previous=a.appearance
    source.CanonicalPlayer2.AppearanceProfile.Value='UnverifiedAvatar'
    local ok,reason=Appearance.attach(a,'Mr. Yellow',source)
    assert(not ok and reason=='UNKNOWN_APPEARANCE_PROFILE')
    assert(a.appearance==previous and not previous.model.destroyed and a.model.Torso.Transparency==1)
    assert(a.model:GetAttribute('Template')=='Mr. Green'and a.model:GetAttribute('Appearance')=='CanonicalNESHero')
    source.CanonicalPlayer1.AppearanceProfile.Value='UnverifiedAvatar'
    ok,reason=Appearance.attach(a,'Mr. Green',source)
    assert(not ok and reason=='UNKNOWN_APPEARANCE_PROFILE'and a.appearance==previous)
end)

test('invalid profile value class and legacy explicit unknown profiles fail without hiding a body',function()
    local source=canonicalTemplates();source.CanonicalPlayer2.AppearanceProfile:Destroy()
    local wrong=node('NumberValue','AppearanceProfile',source.CanonicalPlayer2);wrong.Value=1
    local a=actor('invalid-tag');assert(not Appearance.attach(a,'Mr. Yellow',source))
    assert(not a.appearance and a.model.Torso.Transparency==0)
    local legacy=templates:Clone();local tag=node('StringValue','AppearanceProfile',legacy.GreenToad);tag.Value='UnknownLegacy'
    local b=actor('invalid-legacy');local ok,reason=Appearance.attach(b,'Mr. Green',legacy)
    assert(not ok and reason=='UNKNOWN_APPEARANCE_PROFILE'and not b.appearance and b.model.Torso.Transparency==0)
end)

test('malformed canonical replacement preserves the existing resource visibility and metadata atomically',function()
    local source=canonicalTemplates();local a=actor('malformed-swap')
    assert(Appearance.attach(a,'Mr. Green',source));local previous=a.appearance
    source.CanonicalPlayer2.LeftHand.LeftWristRigAttachment:Destroy()
    local ok=Appearance.attach(a,'Mr. Yellow',source)
    assert(not ok and a.appearance==previous and not previous.model.destroyed)
    assert(a.model.Torso.Transparency==1 and a.humanoid.Health==100)
    assert(a.model:GetAttribute('Template')=='Mr. Green'and a.model:GetAttribute('Appearance')=='CanonicalNESHero')
end)

test('canonical selection changes resource once and cleanup restores saved owner metadata',function()
    local source=canonicalTemplates();local a=actor('canonical-change')
    a.model:SetAttribute('Template','prior-template');a.model:SetAttribute('Appearance','prior-art')
    assert(Appearance.attach(a,'Mr. Green',source));local first=a.appearance.model
    assert(Appearance.attach(a,'Mr. Green',source)and a.appearance.model==first)
    assert(Appearance.attach(a,'Mr. Yellow',source));local second=a.appearance.model
    assert(second~=first and first.destroyed and second.Head.SurfaceAppearance.ColorMap=='canonical-player-2')
    assert(Appearance.attach(a,'Mr. Yellow',source)and a.appearance.model==second)
    Appearance.detach(a)
    assert(not a.appearance and second.destroyed and a.model.Torso.Transparency==0)
    assert(a.model:GetAttribute('Template')=='prior-template'and a.model:GetAttribute('Appearance')=='prior-art')
    assert(a.model:GetAttribute('ActorId')=='canonical-change'and a.humanoid.Health==100)
end)

test('canonical replacement cleanup never restores attributes on a newer actor model',function()
    local source=canonicalTemplates();local a=actor('canonical-old')
    a.model:SetAttribute('Template','old-template');a.model:SetAttribute('Appearance','old-art')
    assert(Appearance.attach(a,'Mr. Yellow',source));local original=a.model;local appearance=a.appearance.model
    local replacement=actor('canonical-new');replacement.model:SetAttribute('Template','new-template');replacement.model:SetAttribute('Appearance','new-art')
    a.model=replacement.model;Appearance.update(a)
    assert(not a.appearance and appearance.destroyed and original:GetAttribute('Template')=='old-template')
    assert(original:GetAttribute('Appearance')=='old-art'and original.Torso.Transparency==0)
    assert(replacement.model:GetAttribute('Template')=='new-template'and replacement.model:GetAttribute('Appearance')=='new-art')
    assert(replacement.model.Torso.Transparency==0 and replacement.humanoid.Health==100)
end)
print('CharacterAppearance: '..passed..' passed')
