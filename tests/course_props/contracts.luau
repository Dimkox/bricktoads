local clone=Node.Clone
function Node:Clone()local n=clone(self);n._attributes=table.clone(self._attributes);return n end
local raw=cf.new
cf.new=function(...)
    local n=select('#',...);assert(n==0 or n==1 and type((...))=='table'or n==3 or n==12,'Invalid CFrame.new arity')
    return raw(...)
end
function Frame:GetComponents()return self.Position.X,self.Position.Y,self.Position.Z,1,0,0,0,1,0,0,0,1 end
cf.lookAt=function(a,b)
    local f=frame(a);f.ry=math.atan2(-(b.X-a.X),-(b.Z-a.Z));return f
end
function Vec.__mul(a,b)if type(b)=='number'then return vector(a.X*b,a.Y*b,a.Z*b)end;return vector(a.X*b.X,a.Y*b.Y,a.Z*b.Z)end
local storage=node('ServerStorage');local templates=node('Folder','BrickToadsCoursePropTemplates',storage)
local geometry=node('Folder','Geometry',node('Workspace'));local tags={}
local env=setmetatable({game={GetService=function(_,name)
    if name=='ServerStorage'then return storage end
    assert(name=='CollectionService');return {AddTag=function(_,model,tag)tags[model]=tag end}
end},Instance={new=function(class)return node(class)end},CFrame=cf,Vector3={new=vector}},{__index=getfenv()})
local loader=assert(loadstring(AppearanceSource));setfenv(loader,env);local A=loader()
local function value(parent,class,name,v)local n=node(class,name,parent);n.Value=v;return n end
local function template(kind,mode)
    local m=node('Model',kind,templates)
    value(m,'StringValue','AppearanceProfile','CanonicalCourseProp');value(m,'StringValue','CourseKind',kind)
    value(m,'StringValue','SourcePin','f1a43b69577246850d136473700a333b3cdfe93f');value(m,'StringValue','FitMode',mode or'Stretch')
    for _,axis in ipairs({'X','Y','Z'})do value(m,'NumberValue','ReferenceSize'..axis,4)end
    local p=node('MeshPart','Core',m);p._props.MeshId='rbxassetid://1234';p.TextureID='rbxassetid://5678'
    p.Size=vector(2,2,2);p.CFrame=frame(0,0,0);p.Transparency=.1
    return m
end
local function object(kind,size)
    local p=node('Part','Physical',geometry);p.Size=size or vector(8,4,12);p.CFrame=frame(20,4,6)
    p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.Anchored=true;p.Transparency=.2;p:SetAttribute('SurfaceId','same')
    return {id=kind,kind=kind,part=p}
end
local function snapshot(r)local p=r.part;return {p.Size,p.CFrame,p.Transparency,p.CanCollide,p.CanQuery,p.CanTouch,p:GetAttribute('SurfaceId')}end
local function preserved(r,s)local p=r.part;assert(p.Size==s[1]and p.CFrame==s[2]and p.Transparency==s[3]and p.CanCollide==s[4]and p.CanQuery==s[5]and p.CanTouch==s[6]and p:GetAttribute('SurfaceId')==s[7],'Physical object changed')end
local count=0
local function test(name,fn)fn();count+=1;print('PASS prop '..name)end
local kinds={'AirMine','BoardingPad','Bomb','Buzzball','ElectricTrap','Fan','Gas','Gear','IceBlock','Icicle','Lift','Log','Mine','MovingIcePlatform','Ramp','Rocket','RocketLauncher','Rope','RotatingSpike','Snowball','Spike','Spring','Telegraph','Tower','TowerPlatform','Warning','Water','Whirlpool'}
test('missing resources leave physical fallback and no leaked models',function()
    local row=object('Mine');local s=snapshot(row);A.update(row,geometry,{},0)
    assert(not row.coursePropAppearance);preserved(row,s)
end)
for _,kind in ipairs(kinds)do template(kind,kind=='Tower'and'Tower'or kind=='Rope'and'Rope'or kind=='Mine'and'TileZ'or'Stretch')end
test('all28 attach independent inert skins without changing physical/support state',function()
    for _,kind in ipairs(kinds)do
        local row=object(kind);local s=snapshot(row);A.update(row,geometry,{},0)
        local state=assert(row.coursePropAppearance,kind);assert(#state.rows>=1 and #state.rows<=128)
        assert(state.skin.Parent==state.model and state.model:GetAttribute('CoursePropAppearance')=='CanonicalCourseProp')
        assert(state.skin:GetAttribute('CanonicalCoursePropSkin')and tags[state.skin]=='BrickToadsCoursePropSkin')
        assert(state.skin.CoursePropFallbackTarget.Value==row.part and row.part:GetAttribute('CoursePropFallbackOwner')==state.id)
        for _,r in ipairs(state.rows)do assert(r.part.Anchored and r.part.Massless and not r.part.CanCollide and not r.part.CanQuery and not r.part.CanTouch)end
        preserved(row,s);A.remove(row);assert(not row.coursePropAppearance and state.model.destroyed)
    end
end)
test('same-size movement reuses model and alpha follows active/broken states',function()
    local row=object('Bomb');A.update(row,geometry,{alpha=0},0);local state=row.coursePropAppearance
    row.part.CFrame=frame(40,12,9);local s=snapshot(row);A.update(row,geometry,{alpha=.75},.2)
    assert(row.coursePropAppearance==state);assert(state.rows[1].part.Transparency>.75)
    assert(state.rows[1].part.CFrame.Position.X==40)
    A.update(row,geometry,{alpha=1},.3);assert(state.rows[1].part.Transparency==1)
    assert(state.rows[1].part:GetAttribute('CoursePropVisibleTransparency')==1);preserved(row,s)
end)
test('resize atomically replaces owned skin and restores previous owner metadata',function()
    local row=object('Gear');row.part:SetAttribute('CoursePropFallbackOwner','prior');row.part:SetAttribute('CoursePropFallbackTransparency',.6)
    A.update(row,geometry,{},0);local old=row.coursePropAppearance.model
    row.part.Size=vector(20,8,12);A.update(row,geometry,{},1);assert(old.destroyed)
    local state=row.coursePropAppearance;A.remove(row)
    assert(state.model.destroyed and row.part:GetAttribute('CoursePropFallbackOwner')=='prior'and row.part:GetAttribute('CoursePropFallbackTransparency')==.6)
end)
test('stale removal cannot overwrite a replacement owner',function()
    local row=object('IceBlock');A.update(row,geometry,{},0)
    row.part:SetAttribute('CoursePropFallbackOwner','new-owner');row.part:SetAttribute('CoursePropFallbackTransparency',.7)
    A.remove(row);assert(row.part:GetAttribute('CoursePropFallbackOwner')=='new-owner'and row.part:GetAttribute('CoursePropFallbackTransparency')==.7)
end)
test('long mine envelopes contain bounded repeated objects instead of stretched orbs',function()
    local row=object('Mine',vector(3,9,44));A.update(row,geometry,{},0);local state=assert(row.coursePropAppearance)
    assert(#state.rows>1 and #state.rows<=128);local min,max=math.huge,-math.huge
    for _,r in ipairs(state.rows)do min=math.min(min,r.part.CFrame.Position.Z);max=math.max(max,r.part.CFrame.Position.Z);assert(r.part.Size.Z<=4)end
    assert(max-min>30)
end)
test('tile envelopes remain inside each cell when ceil chooses multiple rows',function()
    local t=templates.Mine;local old=t.Core.Size;t.Core.Size=vector(4,4,4)
    local row=object('Mine',vector(8,9,44));A.update(row,geometry,{},0)
    for _,r in ipairs(assert(row.coursePropAppearance).rows)do
        local p=r.part
        assert(math.abs(p.CFrame.Position.Y-4)+p.Size.Y/2<=4.50001,'Tiled mine exceeds danger envelope Y')
        assert(math.abs(p.CFrame.Position.Z-6)+p.Size.Z/2<=22.00001,'Tiled mine exceeds danger envelope Z')
    end
    t.Core.Size=old
end)
test('a spinning rotor keeps equal plane scale inside its stationary envelope',function()
    local t=templates.Fan;value(t,'StringValue','MotionKind_Core','SpinZ');value(t,'NumberValue','MotionSpeed_Core',2)
    for _,axis in ipairs({'X','Y','Z'})do value(t,'NumberValue','MotionPivot'..axis..'_Core',0)end
    local row=object('Fan',vector(8,4,12));A.update(row,geometry,{},0)
    local p=assert(row.coursePropAppearance).rows[1].part
    assert(p.Size.X==p.Size.Y,'Nonuniform rotor scale changes its extent through a spin')
end)
test('animation is finite deterministic follows original and never mutates templates',function()
    local t=templates.Gear;value(t,'StringValue','MotionKind_Core','SpinY');value(t,'NumberValue','MotionSpeed_Core',2)
    for _,axis in ipairs({'X','Y','Z'})do value(t,'NumberValue','MotionPivot'..axis..'_Core',0)end
    local row=object('Gear');local before=snapshot(row);A.update(row,geometry,{},0)
    local state=row.coursePropAppearance;A.step(row,.4);local angle=state.rows[1].part.CFrame.ry;assert(math.abs(angle)>.1)
    A.step(row,.4);assert(state.rows[1].part.CFrame.ry==angle)
    A.step(row,0/0);assert(state.rows[1].part.CFrame.ry==angle)
    A.step(row,math.huge);assert(state.rows[1].part.CFrame.ry==angle)
    assert(t.Core.CFrame.ry==0 and t.Core.Size.X==2);preserved(row,before)
end)
test('malformed or executable resource trees are rejected atomically',function()
    local t=templates.Spike;local before=#geometry:GetChildren();local row=object('Spike')
    node('Script','Unexpected',t.Core);A.update(row,geometry,{},0);assert(not row.coursePropAppearance and #geometry:GetChildren()==before+1)
    t.Core.Unexpected:Destroy();t.ReferenceSizeX.Value=0;A.update(row,geometry,{},0);assert(not row.coursePropAppearance)
    t.ReferenceSizeX.Value=4;value(t,'StringValue','MotionKind_Core','Untrusted');A.update(row,geometry,{},0);assert(not row.coursePropAppearance)
end)
test('removed model and detached physical object recover without orphan skins',function()
    local row=object('Water');A.update(row,geometry,{},0);local old=row.coursePropAppearance
    old.model:Destroy();A.update(row,geometry,{},1);assert(row.coursePropAppearance~=old)
    local current=row.coursePropAppearance;row.part:Destroy();A.step(row,2);assert(not row.coursePropAppearance and current.model.destroyed)
end)
test('projectile nose follows actual velocity without rotating the physical hit volume',function()
    local row=object('Rocket',vector(1,1,1));local before=snapshot(row)
    A.update(row,geometry,{role='Projectile',visualVelocity={x=12,y=0,z=0}},0)
    local state=assert(row.coursePropAppearance);assert(math.abs(state.rows[1].part.CFrame.ry+math.pi/2)<1e-6,'Rocket nose ignores actual velocity')
    A.update(row,geometry,{role='Projectile',visualVelocity={x=0,y=0,z=0}},.1)
    assert(math.abs(state.rows[1].part.CFrame.ry+math.pi/2)<1e-6,'Stationary frame lost last heading')
    preserved(row,before)
end)
print('Course prop lifecycle contracts: '..count..' passed; rendering/axes remain native checks')
