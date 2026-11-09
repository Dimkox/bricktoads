-- Native Luau runs the real module; external Roblox Instances and immutable
-- vector/CFrame values are doubled. CFrames compose actual rigid matrices.
local Vec={};Vec.__index=Vec
local function vector(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},Vec)end
function Vec.__mul(a,b)return vector(a.X*b,a.Y*b,a.Z*b)end
local Rigid={}
local function rigid(position,rotation)return setmetatable({Position=position,r=rotation or {1,0,0,0,1,0,0,0,1}},Rigid)end
local function rotate(r,v)return vector(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)end
Rigid.__index=function(a,key)if key=='Rotation'then return rigid(vector(),a.r)end;return Rigid[key]end
function Rigid.__mul(a,b)
    local r={};for i=0,2 do for j=1,3 do r[i*3+j]=a.r[i*3+1]*b.r[j]+a.r[i*3+2]*b.r[3+j]+a.r[i*3+3]*b.r[6+j]end end
    local p=rotate(a.r,b.Position);return rigid(vector(a.Position.X+p.X,a.Position.Y+p.Y,a.Position.Z+p.Z),r)
end
function Rigid:Inverse()
    local a=self.r;local r={a[1],a[4],a[7],a[2],a[5],a[8],a[3],a[6],a[9]}
    return rigid(rotate(r,vector(-self.Position.X,-self.Position.Y,-self.Position.Z)),r)
end
function Rigid:GetComponents()return self.Position.X,self.Position.Y,self.Position.Z,table.unpack(self.r)end
function Rigid:ToEulerAnglesXYZ()
    local r=self.r;local y=math.asin(math.clamp(r[3],-1,1))
    if math.abs(math.cos(y))<1e-7 then return math.atan2(r[8],r[5]),y,0 end
    return math.atan2(-r[6],r[9]),y,math.atan2(-r[2],r[1])
end
local cf={}
function cf.new(x,y,z,...)local rotation={...};return rigid(type(x)=='table'and x or vector(x,y,z),#rotation>0 and rotation or nil)end
function cf.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return rigid(vector(),{cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy})
end
local RGB={};RGB.__index=RGB
local function color(r,g,b)return setmetatable({R=r,G=g,B=b},RGB)end
function RGB:Lerp(other,t)return color(self.R+(other.R-self.R)*t,self.G+(other.G-self.G)*t,self.B+(other.B-self.B)*t)end
local colors={new=color,fromRGB=function(r,g,b)return color(r/255,g/255,b/255)end}
local created,cloned=0,0
local Node={}
Node.__index=function(a,k)if Node[k]then return Node[k]end;local v=a._props[k];if v~=nil then return v end;return a:FindFirstChild(k)end
Node.__newindex=function(a,k,v)
    assert(k~='MeshId','Runtime must preserve uploaded MeshId instead of writing it')
    if k=='Parent'then local old=a._props.Parent;if old then for i,c in ipairs(old._children)do if c==a then table.remove(old._children,i);break end end end;if v then v._children[#v._children+1]=a end end
    a._props[k]=v
end
local function node(class,name,parent)
    created+=1
    local n=setmetatable({_props={ClassName=class,Name=name or class},_children={},_attributes={}},Node);n.Parent=parent;return n
end
function Node:IsA(class)return class==self.ClassName or class=='BasePart'and(self.ClassName=='Part'or self.ClassName=='MeshPart')end
function Node:GetChildren()return table.clone(self._children)end
function Node:FindFirstChild(name)for _,c in ipairs(self._children)do if c.Name==name then return c end end end
function Node:GetDescendants()local a={};for _,c in ipairs(self._children)do a[#a+1]=c;for _,d in ipairs(c:GetDescendants())do a[#a+1]=d end end;return a end
function Node:IsDescendantOf(other)local p=self.Parent;while p do if p==other then return true end;p=p.Parent end;return false end
function Node:Clone()
    cloned+=1;if self.Archivable==false then return nil end
    local n=node(self.ClassName,self.Name)
    for k,v in pairs(self._props)do if k~='Parent'then n._props[k]=v end end
    for k,v in pairs(self._attributes)do n._attributes[k]=v end
    for _,c in ipairs(self._children)do local copy=c:Clone();if copy then copy.Parent=n end end;return n
end
function Node:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil;self._props.destroyed=true end
function Node:SetAttribute(k,v)self._attributes[k]=v end
function Node:GetAttribute(k)return self._attributes[k]end
local function tag(model,class,name,value)local item=node(class,name,model);item.Value=value;return item end
local storage=node('ServerStorage')
local workspace=node('Workspace')
local names={'GuardianChassis','GuardianLeftCannon','GuardianRightCannon'}
local function templates()
    local folder=node('Folder','BrickToadsBossTemplates')
    local model=node('Model','BossWalkerGuardian',folder)
    tag(model,'StringValue','AppearanceProfile','CanonicalBossWalker');tag(model,'NumberValue','AppearanceScale',1)
    tag(model,'StringValue','SourceAssetId','123456');tag(model,'StringValue','SourceGlbSha256',string.rep('a',64))
    tag(model,'StringValue','AssetManifestSha256',string.rep('b',64))
    for i,name in ipairs(names)do
        local part=node('MeshPart',name,model);part._props.MeshId='rbxassetid://'..(9000+i)
        part.TextureID='rbxassetid://8000';part.Material='SmoothPlastic';part.Color=colors.fromRGB(30*i,50,70)
        part.Size=vector(2,3,4);part.MeshSize=vector(2,3,4);part.Transparency=i/20;part.Anchored=true
        part.CanCollide=true;part.CanTouch=true;part.CanQuery=true;part.Massless=false
        local x=i==2 and -3 or i==3 and 3 or 0
        -- Imported mesh geometry retains Y180 at its bounding-box centre.
        part.CFrame=cf.new(x,1,-1)*cf.Angles(0,math.pi,0)
        local mount=node('Attachment','GuardianMountRigAttachment',part)
        mount.CFrame=part.CFrame:Inverse()*cf.new(x,0,0)
        if i>1 then local muzzle=node('Attachment','MuzzleRigAttachment',part);muzzle.CFrame=part.CFrame:Inverse()*cf.new(x,0,-4)end
        local surface=node('SurfaceAppearance','SurfaceAppearance',part);surface.ColorMap='rbxassetid://7000';surface.RoughnessMap='rbxassetid://7001';surface.Color=color(.8,.7,.6)
    end
    return folder
end
local defaultTemplates=templates();defaultTemplates.Parent=storage
local env=setmetatable({game={GetService=function(_,name)assert(name=='ServerStorage');return storage end},
    Instance={new=function(class)return node(class)end},CFrame=cf,Vector3={new=vector},Color3=colors,
    Enum={Material={Neon='Neon'},PartType={Ball='Ball'}}},{__index=getfenv()})
local Appearance
if AppearanceSource then local loader=assert(loadstring(AppearanceSource));setfenv(loader,env);Appearance=loader()
else Appearance={attach=function()return false,'NO_IMPLEMENTATION'end}end
local function actor(id)
    local m=node('Model','Actor_'..id,workspace);m:SetAttribute('ActorId',id);m:SetAttribute('Template','physical');m:SetAttribute('OwnerUserId',531)
    for i,name in ipairs({'HumanoidRootPart','Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg','Eye'})do
        local p=node('Part',name,m);p.CFrame=cf.new(11,7,13)*cf.Angles(0,.7,0);p.Size=vector(2,2,1)
        p.Transparency=name=='HumanoidRootPart'and 1 or i/20;p.Color=colors.fromRGB(70,80,90)
        p.CanCollide=name=='Torso'or name=='Head';p.Anchored=false;p.Massless=false
    end
    local h=node('Humanoid','Humanoid',m);h.Health=37;h.WalkSpeed=0;h.JumpPower=0
    for _,joint in ipairs({{'RootJoint','HumanoidRootPart','Torso'},{'Neck','Torso','Head'},
        {'Left Shoulder','Torso','Left Arm'},{'Right Shoulder','Torso','Right Arm'},
        {'Left Hip','Torso','Left Leg'},{'Right Hip','Torso','Right Leg'}})do
        local motor=node('Motor6D',joint[1],m[joint[2]]);motor.Part0=m[joint[2]];motor.Part1=m[joint[3]]
        motor.C0=cf.new(0,.2,0)*cf.Angles(.1,0,0);motor.C1=cf.new(0,-.2,0)
    end
    local label=node('BillboardGui','WorldLabel',m.HumanoidRootPart);label.Text='health';label.Enabled=true
    return {model=m,root=m.HumanoidRootPart,humanoid=h,healthLabel=label,appearance={heroSentinel=true}}
end
local function near(a,b,message)assert(math.abs(a-b)<1e-5,(message or 'Value mismatch')..': '..tostring(a)..' vs '..tostring(b))end
local function sameFrame(a,b)
    near(a.Position.X,b.Position.X);near(a.Position.Y,b.Position.Y);near(a.Position.Z,b.Position.Z)
    for i=1,9 do near(a.r[i],b.r[i])end
end
local function sameColor(a,b)near(a.R,b.R);near(a.G,b.G);near(a.B,b.B)end
local function skin(a)return assert(a.guardianAppearance).model end
local function childMotor(part)for _,p in ipairs(part:GetChildren())do if p:IsA('Motor6D')then return p end end;error('Missing cosmetic Motor6D')end
local function flashes(a)
    local result={};for _,p in ipairs(skin(a):GetChildren())do if p:IsA('Part')then result[#result+1]=p end end
    assert(#result==2,'Both flash Parts must be preassembled');return result
end
local function cannonFrame(a,name)local motor=childMotor(skin(a)[name]);return a.root.CFrame*motor.C0*motor.C1:Inverse()end
local function localMuzzle(a,name)local part=skin(a)[name];return a.root.CFrame:Inverse()*cannonFrame(a,name)*part.MuzzleRigAttachment.CFrame end
local passed=0
local function test(name,fn)fn();passed+=1;print('PASS '..name)end

-- Catches no attach, substituted geometry, changed authorities or missing flash preassembly.
test('valid source commits three actual meshes and two nonphysical flashes without replacing the body',function()
    local a=actor('assembly');local root,h,hero=a.root,a.humanoid,a.appearance
    assert(Appearance.attach(a),'Valid canonical Guardian template must attach')
    local meshes,motors,welds,humanoids=0,0,0,0
    for _,part in ipairs(a.model:GetDescendants())do
        if part:IsA('MeshPart')then
            meshes+=1;assert(part.MeshId==defaultTemplates.BossWalkerGuardian[part.Name].MeshId)
            assert(part.TextureID=='rbxassetid://8000'and part.SurfaceAppearance.ColorMap=='rbxassetid://7000')
            assert(part.Material=='SmoothPlastic'and part.SurfaceAppearance.RoughnessMap=='rbxassetid://7001')
        end
        if part:IsA('Motor6D')then motors+=1 end;if part:IsA('WeldConstraint')then welds+=1 end;if part:IsA('Humanoid')then humanoids+=1 end
        if part:IsA('BasePart')and part:IsDescendantOf(skin(a))then assert(not part.Anchored and part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery)end
    end
    assert(meshes==3 and motors==9 and welds==2 and humanoids==1)
    for _,flash in ipairs(flashes(a))do
        assert(flash.Transparency==1)
        local weld;for _,c in ipairs(flash:GetChildren())do if c:IsA('WeldConstraint')then weld=c end end
        assert(weld and weld.Part1==flash and(weld.Part0.Name=='GuardianLeftCannon'or weld.Part0.Name=='GuardianRightCannon'))
        sameFrame(flash.CFrame,weld.Part0.CFrame*weld.Part0.MuzzleRigAttachment.CFrame)
    end
    assert(a.root==root and a.humanoid==h and a.appearance==hero and h.Health==37 and h.WalkSpeed==0 and h.JumpPower==0)
    assert(a.model.Torso.CanCollide and a.model.Head.CanCollide and not root.Anchored)
    assert(a.healthLabel.Text=='health'and a.healthLabel.Enabled and a.model:GetAttribute('OwnerUserId')==531)
    assert(a.model:GetAttribute('ActorId')=='assembly'and a.model:GetAttribute('Template')=='physical')
    assert(a.model.Torso.Transparency==1 and a.model.Eye.Transparency==1)
    assert(defaultTemplates.BossWalkerGuardian.GuardianChassis.Anchored,'Stored source must be untouched')
end)

-- Catches lost imported C1 rotation, inverse recoil, muzzle placement or C0 delta order.
test('Y180 import rest and attachment equation retain forward muzzles and recoil backward in root axes',function()
    local a=actor('matrix');local source=templates();assert(Appearance.attach(a,source))
    for _,name in ipairs(names)do
        local part=skin(a)[name];local motor=childMotor(part)
        sameFrame(motor.C1,source.BossWalkerGuardian[name].GuardianMountRigAttachment.CFrame)
        sameFrame(a.root.CFrame:Inverse()*cannonFrame(a,name),source.BossWalkerGuardian[name].CFrame)
        assert(part.CFrame.r[1]<0,'World fixture must retain the imported rest yaw')
    end
    sameFrame(localMuzzle(a,'GuardianLeftCannon'),cf.new(-3,0,-4))
    sameFrame(localMuzzle(a,'GuardianRightCannon'),cf.new(3,0,-4))
    Appearance.shot(a,'Bullet',10);Appearance.update(a,10)
    near(localMuzzle(a,'GuardianLeftCannon').Position.Z,-3.75,'Left muzzle must recoil toward +Z, not forward')
    near(localMuzzle(a,'GuardianRightCannon').Position.Z,-4)
    Appearance.update(a,10+7/60)
    sameFrame(localMuzzle(a,'GuardianLeftCannon'),cf.new(-3,0,-4))
    Appearance.shot(a,'Heavy',11);Appearance.update(a,11)
    near(localMuzzle(a,'GuardianRightCannon').Position.Z,-3.75)
    near(localMuzzle(a,'GuardianLeftCannon').Position.Z,-4)
end)

-- Catches render-time assembly, stale flashes, timer drift or unaccepted cues producing recoil.
test('accepted shots alternate prebuilt flashes and expire without assembling anything during presentation',function()
    local a=actor('finite');assert(Appearance.attach(a));local before=created;local copy=cloned
    local rootFrame=a.root.CFrame;local physical={}
    for _,p in ipairs(a.model:GetDescendants())do if p:IsA('Motor6D')and not p:IsDescendantOf(skin(a))then physical[p]={p.C0,p.C1,p.Part0,p.Part1}end end
    local flash=flashes(a);local visible=function()local n=0;for _,p in ipairs(flash)do if p.Transparency<1 then n+=1 end end;return n end
    for _,mode in ipairs({'Blocked','Melee','HeavyBlocked','bullet'})do Appearance.shot(a,mode,20)end
    Appearance.shot(a,'Bullet',0/0);Appearance.update(a,20)
    near(localMuzzle(a,'GuardianLeftCannon').Position.Z,-4);assert(visible()==0)
    Appearance.shot(a,'Bullet',21);Appearance.update(a,21);assert(visible()==1)
    local first;for _,p in ipairs(flash)do if p.Transparency<1 then first=p end end
    Appearance.update(a,21.09);assert(visible()==0)
    assert(localMuzzle(a,'GuardianLeftCannon').Position.Z> -4,'Recoil must still be within explicit seven-frame duration')
    Appearance.update(a,21+7/60);near(localMuzzle(a,'GuardianLeftCannon').Position.Z,-4)
    Appearance.shot(a,'Heavy',22);Appearance.update(a,22);assert(visible()==1 and first.Transparency==1)
    for i=1,60 do Appearance.update(a,22+i/60)end
    assert(visible()==0 and created==before and cloned==copy,'No Part, Weld, Motor or clone may be added by shots/updates')
    assert(a.humanoid.Health==37 and a.model.Torso.CanCollide)
    assert(a.root.CFrame==rootFrame,'Cosmetic shots cannot move or turn the authoritative root')
    for p,prior in pairs(physical)do assert(p.C0==prior[1]and p.C1==prior[2]and p.Part0==prior[3]and p.Part1==prior[4],'Physical R6 joints must remain exact')end
end)

-- Catches raw-value initialization flashes, health increases flashing, tint leaks and recoil from health.
test('normalized health changes tint only on a real decrease and restore exact colors and transparency',function()
    local a=actor('health');assert(Appearance.attach(a));local colorsBefore,transBefore,surfacesBefore={},{},{}
    for _,name in ipairs(names)do colorsBefore[name]=skin(a)[name].Color;transBefore[name]=skin(a)[name].Transparency;surfacesBefore[name]=skin(a)[name].SurfaceAppearance.Color end
    local before=created
    Appearance.health(a,3,3,1);Appearance.health(a,47,47,2);Appearance.health(a,47,47,3);Appearance.update(a,3)
    for _,name in ipairs(names)do sameColor(skin(a)[name].Color,colorsBefore[name])end
    Appearance.health(a,31,47,4);Appearance.update(a,4)
    assert(math.abs(skin(a).GuardianChassis.Color.R-colorsBefore.GuardianChassis.R)>.1,'Actual damage must tint the source geometry')
    assert(math.abs(skin(a).GuardianChassis.SurfaceAppearance.Color.R-surfacesBefore.GuardianChassis.R)>.05,'Actual damage must also tint PBR ColorMap through SurfaceAppearance.Color')
    near(localMuzzle(a,'GuardianLeftCannon').Position.Z,-4);near(localMuzzle(a,'GuardianRightCannon').Position.Z,-4)
    Appearance.update(a,4.3)
    for _,name in ipairs(names)do assert(skin(a)[name].Color==colorsBefore[name],'Expiry must restore exact original Color value');assert(skin(a)[name].Transparency==transBefore[name]);assert(skin(a)[name].SurfaceAppearance.Color==surfacesBefore[name])end
    Appearance.health(a,47,47,5);Appearance.update(a,5)
    sameColor(skin(a).GuardianChassis.Color,colorsBefore.GuardianChassis)
    Appearance.health(a,15,47,6);Appearance.update(a,6);assert(skin(a).GuardianChassis.Color~=colorsBefore.GuardianChassis)
    Appearance.health(a,0,47,7);Appearance.update(a,7.3)
    for _,name in ipairs(names)do assert(skin(a)[name].Color==colorsBefore[name])end
    assert(created==before and a.humanoid.Health==37 and a.healthLabel.Text=='health')
end)

-- Catches shared actor state and nonexact restore, including reattach reassembly.
test('two actors keep independent shot health and original visibility through repeat attach and detach',function()
    local a,b=actor('one'),actor('two');local aTorso=a.model.Torso.Transparency;local bTorso=b.model.Torso.Transparency
    assert(Appearance.attach(a)and Appearance.attach(b));local first=skin(a);local before=created
    assert(Appearance.attach(a)and skin(a)==first and created==before,'Repeated attach must be idempotent')
    assert(skin(a)~=skin(b)and skin(a).GuardianChassis~=skin(b).GuardianChassis)
    Appearance.health(a,47,47,1);Appearance.health(b,47,47,1);Appearance.health(a,31,47,2);Appearance.shot(a,'Bullet',2)
    Appearance.update(a,2);Appearance.update(b,2)
    near(localMuzzle(b,'GuardianLeftCannon').Position.Z,-4);assert(flashes(b)[1].Transparency==1 and flashes(b)[2].Transparency==1)
    sameColor(skin(b).GuardianChassis.Color,defaultTemplates.BossWalkerGuardian.GuardianChassis.Color)
    Appearance.detach(a);assert(not a.guardianAppearance and first.destroyed and a.model.Torso.Transparency==aTorso)
    assert(a.model.Eye.Transparency==.4 and a.appearance.heroSentinel and b.guardianAppearance and b.model.Torso.Transparency==1)
    Appearance.detach(b);assert(b.model.Torso.Transparency==bTorso)
end)

-- Catches accepting dangerous/hidden/untagged assets and mutating the old actor before validation.
test('missing malformed and unsafe resources reject before cloning or changing any actor',function()
    local mutations={
        function(m)m.AppearanceProfile.Value='Unverified'end,
        function(m)m.AppearanceProfile:Destroy()end,
        function(m)m.AppearanceScale.Value=2 end,
        function(m)m.SourceAssetId.Value='not-an-upload'end,
        function(m)m.SourceGlbSha256.Value='not-a-sha256'end,
        function(m)m.AssetManifestSha256.Value='not-a-sha256'end,
        function(m)m.GuardianChassis._props.MeshId=''end,
        function(m)m.GuardianChassis._props.MeshId='rbxassetid://0'end,
        function(m)m.GuardianChassis.Size=vector(0,2,2)end,
        function(m)m.GuardianChassis.MeshSize=vector(2,0,2)end,
        function(m)m.GuardianChassis.Transparency=1 end,
        function(m)m.GuardianChassis.Transparency=-.1 end,
        function(m)m.GuardianChassis.GuardianMountRigAttachment:Destroy()end,
        function(m)m.GuardianLeftCannon.MuzzleRigAttachment:Destroy()end,
        function(m)m.GuardianLeftCannon.MuzzleRigAttachment.CFrame=m.GuardianLeftCannon.CFrame:Inverse()*cf.new(-3,0,4)end,
        function(m)m.GuardianRightCannon.GuardianMountRigAttachment.CFrame=m.GuardianRightCannon.CFrame:Inverse()*cf.new(-3,0,0)end,
        function(m)m.GuardianChassis.GuardianMountRigAttachment.CFrame=m.GuardianChassis.CFrame:Inverse()*cf.new(0,0,.3)end,
        function(m)m.GuardianLeftCannon.GuardianMountRigAttachment.CFrame=m.GuardianLeftCannon.GuardianMountRigAttachment.CFrame*cf.Angles(0,.1,0)end,
        function(m)node('Script','Injected',m.GuardianChassis)end,
        function(m)node('Humanoid','Humanoid',m)end,
        function(m)node('Part','HiddenCollider',m.GuardianChassis)end,
        function(m)node('MeshPart','FourthMesh',m)end,
        function(m)node('Attachment','GuardianMountRigAttachment',m.GuardianChassis)end,
    }
    for i,mutate in ipairs(mutations)do
        local source=templates();mutate(source.BossWalkerGuardian)
        local a=actor('bad-'..i);local original=a.model.Torso.Transparency;local before=cloned
        local ok,reason=Appearance.attach(a,source)
        assert(not ok and type(reason)=='string'and reason~='','Malformed fixture '..i..' must be rejected')
        assert(not a.guardianAppearance and a.model.Torso.Transparency==original and cloned==before,'Validation must precede cloning and hiding for fixture '..i)
        assert(a.appearance.heroSentinel and a.humanoid.Health==37)
    end
    local a=actor('missing');local initial=a.model.Torso.Transparency
    assert(not Appearance.attach(a,node('Folder'))and a.model.Torso.Transparency==initial)
    local saved=defaultTemplates.Parent;defaultTemplates.Parent=nil
    assert(not Appearance.attach(a)and not a.guardianAppearance and a.model.Torso.Transparency==initial)
    defaultTemplates.Parent=saved
end)

-- Catches rejecting optional provenance/API properties and non-atomic clone failure.
test('optional metadata and unavailable MeshSize work while uncloneable resources retain the old actor',function()
    local source=templates();local model=source.BossWalkerGuardian
    model.SourceAssetId:Destroy();model.SourceGlbSha256:Destroy();model.AssetManifestSha256:Destroy()
    for _,name in ipairs(names)do model[name].MeshSize=nil end
    local a=actor('optional');assert(Appearance.attach(a,source))
    local committed=a.guardianAppearance
    for _,uncloneable in ipairs({'BossWalkerGuardian','GuardianRightCannon'})do
        local replacement=templates()
        local target=uncloneable=='BossWalkerGuardian'and replacement.BossWalkerGuardian or replacement.BossWalkerGuardian[uncloneable]
        target.Archivable=false
        assert(not Appearance.attach(a,replacement),'A resource omitted by native Clone cannot commit')
        assert(a.guardianAppearance==committed and not committed.model.destroyed and a.model.Torso.Transparency==1)
    end
end)

-- Catches tearing down a valid skin before validating a replacement.
test('invalid replacement preserves a committed appearance and exact state',function()
    local a=actor('replacement');assert(Appearance.attach(a));local committed=a.guardianAppearance
    local bad=templates();bad.BossWalkerGuardian.GuardianLeftCannon.MuzzleRigAttachment:Destroy()
    assert(not Appearance.attach(a,bad)and a.guardianAppearance==committed and not committed.model.destroyed)
    assert(a.model.Torso.Transparency==1)
end)

-- Catches stale cosmetics surviving replacement/removal and touching a new body.
test('owner replacement removed model and detached skin clean up without rebuilding or modifying a newer actor',function()
    for _,kind in ipairs({'replacement','removed','skin-removed','root-replaced'})do
        local a=actor('old-'..kind);local original=a.model;local trans=original.Torso.Transparency
        assert(Appearance.attach(a));local appearance=skin(a);local replacement=actor('new-'..kind)
        if kind=='replacement'then a.model=replacement.model
        elseif kind=='removed'then original.Parent=nil
        elseif kind=='skin-removed'then appearance.Parent=nil
        else a.root=replacement.root end
        local before=created;Appearance.update(a,10)
        assert(not a.guardianAppearance and appearance.destroyed and created==before)
        assert(original.Torso.Transparency==trans and replacement.model.Torso.Transparency==.1)
        assert(replacement.model:GetAttribute('ActorId')=='new-'..kind and replacement.humanoid.Health==37)
    end
end)
print('GuardianAppearance: '..passed..' passed')
