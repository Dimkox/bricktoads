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
print('CharacterAppearance: '..passed..' passed')
