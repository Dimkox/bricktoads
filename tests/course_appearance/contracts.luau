-- Instance/transform contracts, not Roblox collision or asset-loading emulation.
local rawCFrameNew=cf.new
cf.new=function(...)
    local n=select('#',...);local first=...
    assert(n==0 or n==1 and type(first)=='table'and type(first.X)=='number'and type(first.Y)=='number'and type(first.Z)=='number'
        or n==3 or n==12,'CFrame.new requires zero, Vector3, three or twelve arguments')
    if n==3 or n==12 then for _,v in ipairs({...})do assert(type(v)=='number','CFrame.new coordinates must be numbers')end end
    return rawCFrameNew(...)
end
function Vec.__add(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
function Frame.__mul(a,b)
    local p=b.Position;local c,s=math.cos(a.ry),math.sin(a.ry)
    local f=frame(a.Position.X+p.X*c+p.Z*s,a.Position.Y+p.Y,a.Position.Z-p.X*s+p.Z*c)
    f.rx,f.ry,f.rz=a.rx+b.rx,a.ry+b.ry,a.rz+b.rz;return f
end
function Frame:GetComponents()
    local cx,sx,cy,sy,cz,sz=math.cos(self.rx),math.sin(self.rx),math.cos(self.ry),math.sin(self.ry),math.cos(self.rz),math.sin(self.rz)
    return self.Position.X,self.Position.Y,self.Position.Z,cy*cz,-cy*sz,sy,
        sx*sy*cz+cx*sz,-sx*sy*sz+cx*cz,-sx*cy,-cx*sy*cz+sx*sz,cx*sy*sz+sx*cz,cx*cy
end
local storage=node('ServerStorage');local templates=node('Folder','BrickToadsCourseTemplates',storage)
local geometry=node('Folder','Geometry',node('Workspace'))
local tags={};local env=setmetatable({game={GetService=function(_,name)
    if name=='ServerStorage'then return storage end
    assert(name=='CollectionService');return {AddTag=function(_,model,tag)tags[model]=tag end}
end},Instance={new=function(class)return node(class)end},CFrame=cf,Vector3={new=vector},
Color3={fromRGB=function(...)return {...}end},Enum={Material={Metal='Metal',Concrete='Concrete',Neon='Neon'},PartType={Ball='Ball'}}},{__index=getfenv()})
local loader=assert(loadstring(AppearanceSource));setfenv(loader,env);local A=loader()
local function value(parent,class,name,v)local n=node(class,name,parent);n.Value=v;return n end
local function template(kind)
    local m=node('Model',kind,templates)
    value(m,'StringValue','AppearanceProfile','CanonicalCourseVehicle')
    value(m,'StringValue','CourseKind',kind);value(m,'StringValue','SourcePin','f1a43b69577246850d136473700a333b3cdfe93f')
    value(m,'NumberValue','DeckTop',0);value(m,'NumberValue','DeckLength',6);value(m,'NumberValue','DeckWidth',3)
    for _,name in ipairs({'Deck','Nose'})do
        local p=node('MeshPart',name,m);p._props.MeshId='rbxassetid://1234';p.TextureID='rbxassetid://5678'
        p.Size=vector(3,.4,6);p.CFrame=frame(0,-.2,name=='Nose'and-2 or 0);p.Transparency=0
    end
    return m
end
local function object(kind,id)
    local p=node('Part','Physical_'..(id or kind),geometry);p.Size=vector(6,.9,3);p.CFrame=frame(12,.4,9)
    p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Anchored=true;p.Massless=false;p.Transparency=.25
    p:SetAttribute('SurfaceId','original');return {id=id or kind,kind=kind,part=p}
end
local passed,failed=0,0
local function check(name,fn)local ok,why=pcall(fn);if ok then passed+=1;print('PASS course '..name)else failed+=1;print('FAIL course '..name..': '..tostring(why))end end
local function eq(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b))end
local function physical(row)
    local p=row.part;return {size=p.Size,frame=p.CFrame,collide=p.CanCollide,query=p.CanQuery,touch=p.CanTouch,
        anchored=p.Anchored,massless=p.Massless,surface=p:GetAttribute('SurfaceId')}
end
local function preserved(row,before)
    local p=row.part;assert(p.Size==before.size and p.CFrame==before.frame and p.CanCollide==before.collide
        and p.CanQuery==before.query and p.CanTouch==before.touch and p.Anchored==before.anchored
        and p.Massless==before.massless and p:GetAttribute('SurfaceId')==before.surface,'Physics/collider changed')
end
check('missing imported vehicle retains visible fallback without leaked model',function()
    local row=object('Jet');local before=physical(row);A.update(row,geometry,{})
    assert(not row.courseAppearance and row.part.Transparency==.25);preserved(row,before)
end)
check('whole vehicle clears the anchor ground and source forward becomes route forward',function()
    local t=template('Speeder');local row=object('Speeder');local before=physical(row)
    A.update(row,geometry,{})
    local state=assert(row.courseAppearance);assert(state.skin and state.model and state.skin.Parent==state.model)
    assert(state.model:GetAttribute('CourseAppearance')=='CanonicalCourseVehicle')
    assert(state.skin:GetAttribute('CanonicalCourseSkin')and tags[state.skin]=='BrickToadsCourseSkin')
    eq(state.deckWorldY,.43)
    eq(state.skin.Deck.CFrame.Position.Y-state.skin.Deck.Size.Y/2,.03)
    eq(state.skin.Deck.CFrame.Position.Y+state.skin.Deck.Size.Y/2,state.deckWorldY)
    assert(state.skin.Nose.CFrame.Position.X>state.skin.Deck.CFrame.Position.X,'Authored-Z must face route+X')
    assert(row.part.Transparency==.25,'Server fallback must stay visible until client typed preload succeeds')
    assert(row.part:GetAttribute('CourseFallbackOwner')==state.id and state.skin.CourseFallbackTarget.Value==row.part)
    assert(state.skin.Deck:GetAttribute('CourseVisibleTransparency')==0)
    assert(t.Deck.Size.X==3 and t.Deck.CFrame.Position.Y==-.2,'Shared template changed')
    preserved(row,before)
    for _,p in ipairs(state.skin:GetDescendants())do if p:IsA('MeshPart')then
        assert(p.Anchored and p.Massless and not p.CanCollide and not p.CanQuery and not p.CanTouch)
    end end
end)
check('same-size movement and yaw reuse skin and follow the original part',function()
    local row=object('Speeder','moving');A.update(row,geometry,{})
    local model=row.courseAppearance.model;local skin=row.courseAppearance.skin
    row.part.CFrame=frame(25,8,4)*cf.Angles(0,math.pi/2,0);local before=physical(row)
    A.update(row,geometry,{})
    assert(row.courseAppearance.model==model);eq(skin.Deck.CFrame.Position.Y,7.83)
    eq(row.courseAppearance.deckWorldY,8.03)
    eq(skin.Deck.CFrame.ry,0);preserved(row,before)
end)
check('resize replaces owned skin and detach restores exact fallback metadata',function()
    local row=object('Speeder','resize');row.part:SetAttribute('CourseFallbackOwner','old');row.part:SetAttribute('CourseFallbackTransparency',.7)
    A.update(row,geometry,{});local old=row.courseAppearance.model
    row.part.Size=vector(12,.9,6);A.update(row,geometry,{})
    assert(old.destroyed and row.courseAppearance.model~=old);eq(row.courseAppearance.skin.Deck.Size.X,6)
    local model=row.courseAppearance.model;A.remove(row)
    assert(not row.courseAppearance and model.destroyed and row.part.Transparency==.25)
    assert(row.part:GetAttribute('CourseFallbackOwner')=='old'and row.part:GetAttribute('CourseFallbackTransparency')==.7)
end)
check('invalid deck metadata and executable descendants fail atomically',function()
    local t=template('Surfboard');t.DeckLength.Value=0
    local row=object('Surfboard');A.update(row,geometry,{});assert(not row.courseAppearance and row.part.Transparency==.25)
    t.DeckLength.Value=6;node('Script','Bad',t.Deck)
    A.update(row,geometry,{});assert(not row.courseAppearance and row.part.Transparency==.25);t:Destroy()
end)
check('oriented source bounds determine clearance without a family lift constant',function()
    local t=template('Jet');t.Deck.CFrame=frame(0,-.2,0)*cf.Angles(0,0,math.pi/2)
    local row=object('Jet','oriented');local before=physical(row);A.update(row,geometry,{})
    local state=assert(row.courseAppearance);eq(state.deckWorldY,1.73)
    preserved(row,before)
end)
check('water surface raises only cosmetic deck and recomputes when leaving water',function()
    template('Surfboard');local row=object('Surfboard','water');local before=physical(row)
    A.update(row,geometry,{},4);local state=assert(row.courseAppearance)
    eq(state.deckWorldY,4.1);preserved(row,before)
    A.update(row,geometry,{},-2);assert(row.courseAppearance==state);eq(state.deckWorldY,.43)
    A.update(row,geometry,{},0/0);eq(state.deckWorldY,.43);preserved(row,before)
end)
check('actual named deck top is distinct from its metadata origin and not double applied',function()
    local t=template('ClingerVehicle');t.Deck.Name='RiderDeck'
    t.RiderDeck.Size=vector(3,.6,6);t.RiderDeck.CFrame=frame(0,-.15,0)
    local row=object('ClingerVehicle','actual-deck');row.part.CFrame=frame(12,.3,9)
    local before=physical(row);A.update(row,geometry,{})
    local state=assert(row.courseAppearance)
    eq(state.deckOriginWorldY,.48);eq(state.deckWorldY,.63)
    eq(state.skin.RiderDeck.CFrame.Position.Y+state.skin.RiderDeck.Size.Y/2,state.deckWorldY)
    eq(state.skin.RiderDeck.CFrame.Position.Y-state.skin.RiderDeck.Size.Y/2,.03)
    A.update(row,geometry,{},4)
    eq(state.deckOriginWorldY,3.95);eq(state.deckWorldY,4.1)
    eq(state.skin.RiderDeck.CFrame.Position.Y+state.skin.RiderDeck.Size.Y/2,4.1)
    preserved(row,before)
end)
check('structural walls and door headers have real inset volume and inert details',function()
    for _,kind in ipairs({'Wall','LowBarrier','Overhead','MovingWall','MechanicalCrusher','PipeCrusher','ElectricGate'})do
        local row=object(kind);row.part.Size=vector(3,18,12);row.part.CanCollide=kind=='MovingWall';row.part.CanQuery=row.part.CanCollide
        local before=physical(row);A.update(row,geometry,{alpha=.1})
        local state=assert(row.courseAppearance,'No structure for '..kind);assert(not state.skin and #state.model:GetChildren()>=6)
        assert(row.part.Transparency==1,'Opaque cosmetics should replace the orange placeholder visually')
        local maxDepth,minDepth=0,math.huge
        for _,p in ipairs(state.model:GetChildren())do if p:IsA('BasePart')then
            assert(p.Anchored and p.Massless and not p.CanCollide and not p.CanQuery and not p.CanTouch)
            maxDepth=math.max(maxDepth,p.Size.X);minDepth=math.min(minDepth,p.Size.X)
        end end
        assert(maxDepth>minDepth,'Only flat identical boxes were produced');preserved(row,before)
        local model=state.model;row.part.Size=vector(4,14,5);row.part.CFrame=frame(90,12,3)*cf.Angles(0,1,0)
        A.update(row,geometry,{alpha=.75});assert(model.destroyed and row.courseAppearance.model~=model)
        A.remove(row);assert(row.part.Transparency==.75,'Detach must restore latest original presentation alpha')
    end
end)
check('unrelated hazards receive no decorative replacement',function()
    local row=object('Gas');local before=physical(row);A.update(row,geometry,{})
    assert(not row.courseAppearance and row.part.Transparency==.25);preserved(row,before)
end)
print('Course appearance: '..passed..' passed, '..failed..' failed; native asset/render checks remain separate')
assert(failed==0,'Course appearance contracts failed')
