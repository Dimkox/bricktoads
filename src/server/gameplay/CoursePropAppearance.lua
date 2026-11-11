-- Cosmetic course resources. Original renderer parts remain authoritative.
local Appearance={}
local PIN='f1a43b69577246850d136473700a333b3cdfe93f'
local KINDS={AirMine=true,BoardingPad=true,Bomb=true,Buzzball=true,ElectricTrap=true,Fan=true,Gas=true,
    Gear=true,IceBlock=true,Icicle=true,Lift=true,Log=true,Mine=true,MovingIcePlatform=true,Ramp=true,
    Rocket=true,RocketLauncher=true,Rope=true,RotatingSpike=true,Snowball=true,Spike=true,Spring=true,
    Telegraph=true,Tower=true,TowerPlatform=true,Warning=true,Water=true,Whirlpool=true}
local FITS={Stretch=true,TileZ=true,Tower=true,Rope=true}
local MOTIONS={SpinX=true,SpinY=true,SpinZ=true,Pulse=true,Orbit=true}
local sequence=0
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function positive(v)return finite(v)and v>0 end
local function scalar(model,name)
    local v=assert(model:FindFirstChild(name),'Missing '..name)
    assert(v:IsA('NumberValue')and finite(v.Value),'Invalid '..name);return v.Value
end
local function text(model,name)
    local v=assert(model:FindFirstChild(name),'Missing '..name)
    assert(v:IsA('StringValue'),'Invalid '..name);return v.Value
end
local function same(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local function checked(frame)
    for _,v in ipairs({frame:GetComponents()})do assert(finite(v),'Nonfinite prop transform')end
end
local function product(a,b)return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)end
function Appearance.remove(row)
    local state=row.coursePropAppearance;if not state then return end
    row.coursePropAppearance=nil;state.model:Destroy()
    local p=state.part
    if p and p.Parent and p:GetAttribute('CoursePropFallbackOwner')==state.id then
        p:SetAttribute('CoursePropFallbackOwner',state.previousOwner)
        p:SetAttribute('CoursePropFallbackTransparency',state.previousFallbackAlpha)
    end
end
local function create(row,parent)
    local folder=game:GetService('ServerStorage'):FindFirstChild('BrickToadsCoursePropTemplates')
    local template=folder and folder:FindFirstChild(row.kind)
    if not template or not template:IsA('Model')then return end
    local resource,model
    local ok,state=pcall(function()
        resource=assert(template:Clone(),'Uncloneable prop template')
        assert(text(resource,'AppearanceProfile')=='CanonicalCourseProp'and text(resource,'CourseKind')==row.kind
            and text(resource,'SourcePin')==PIN,'Untrusted prop template')
        local mode=text(resource,'FitMode');assert(FITS[mode],'Unknown prop fit')
        local ref=Vector3.new(scalar(resource,'ReferenceSizeX'),scalar(resource,'ReferenceSizeY'),scalar(resource,'ReferenceSizeZ'))
        local size=row.part.Size
        for _,v in ipairs({ref.X,ref.Y,ref.Z,size.X,size.Y,size.Z})do assert(positive(v)and v<=10000,'Invalid prop envelope')end
        local source={};local names={}
        for _,p in ipairs(resource:GetChildren())do
            if p:IsA('MeshPart')then
                assert(not names[p.Name],'Duplicate prop part');names[p.Name]=true
                assert(type(p.MeshId)=='string'and p.MeshId:match('^rbxassetid://%d+$'),'Missing uploaded prop mesh')
                assert(finite(p.Transparency)and p.Transparency>=0 and p.Transparency<1,'Invisible prop resource')
                for _,v in ipairs({p.Size.X,p.Size.Y,p.Size.Z})do assert(positive(v),'Invalid prop dimensions')end
                checked(p.CFrame)
                for _,child in ipairs(p:GetChildren())do
                    assert(child:IsA('SurfaceAppearance')and #child:GetChildren()==0,'Unexpected prop mesh descendant')
                end
                local motion,pivot,speed
                if resource:FindFirstChild('MotionKind_'..p.Name)then
                    motion=text(resource,'MotionKind_'..p.Name);assert(MOTIONS[motion],'Unknown prop motion')
                    speed=scalar(resource,'MotionSpeed_'..p.Name);assert(math.abs(speed)<=50,'Unbounded prop motion')
                    pivot=Vector3.new(scalar(resource,'MotionPivotX_'..p.Name),scalar(resource,'MotionPivotY_'..p.Name),scalar(resource,'MotionPivotZ_'..p.Name))
                    for _,v in ipairs({pivot.X,pivot.Y,pivot.Z})do assert(math.abs(v)<=10000,'Invalid prop pivot')end
                end
                source[#source+1]={part=p,frame=p.CFrame,alpha=p.Transparency,motion=motion,pivot=pivot,speed=speed}
            else
                assert((p:IsA('StringValue')or p:IsA('NumberValue'))and #p:GetChildren()==0,'Unexpected prop resource descendant')
            end
        end
        assert(#source>=1 and #source<=8,'Invalid prop segment count')
        local fit=CFrame.new();local target=size
        if mode=='Tower'then target=Vector3.new(size.Y,size.X,size.Z);fit=CFrame.Angles(0,0,-math.pi/2)
        elseif mode=='Rope'and size.Y>size.Z then target=Vector3.new(size.X,size.Z,size.Y);fit=CFrame.Angles(math.pi/2,0,0)end
        local scale=Vector3.new(target.X/ref.X,target.Y/ref.Y,target.Z/ref.Z)
        -- Keep each rotating plane isotropic. Spinning an already stretched
        -- ellipse would enlarge the visible danger envelope during its turn.
        for _,s in ipairs(source)do
            if s.motion=='SpinX'then local v=math.min(scale.Y,scale.Z);scale=Vector3.new(scale.X,v,v)
            elseif s.motion=='SpinY'or s.motion=='Orbit'then local v=math.min(scale.X,scale.Z);scale=Vector3.new(v,scale.Y,v)
            elseif s.motion=='SpinZ'then local v=math.min(scale.X,scale.Y);scale=Vector3.new(v,v,scale.Z)end
        end
        local offsets={Vector3.new()}
        if mode=='TileZ'then
            -- Bounded repeated solids preserve the source silhouette inside long
            -- mine volumes instead of stretching a sphere across the lane.
            local uniform=math.min(scale.X,scale.Y,scale.Z)
            local countY=math.clamp(math.floor(target.Y/(ref.Y*uniform)+1e-6),1,4)
            local countZ=math.clamp(math.floor(target.Z/(ref.Z*uniform)+1e-6),1,64)
            local budget=math.min(64,math.floor(128/#source))
            if countY*countZ>budget then
                countY=math.max(1,math.floor(countY*math.sqrt(budget/(countY*countZ))))
                countZ=math.min(countZ,math.floor(budget/countY))
            end
            uniform=math.min(uniform,target.Y/(countY*ref.Y),target.Z/(countZ*ref.Z))
            scale=Vector3.new(uniform,uniform,uniform)
            offsets={}
            for y=1,countY do for z=1,countZ do
                offsets[#offsets+1]=Vector3.new(0,-target.Y/2+(y-.5)*target.Y/countY,-target.Z/2+(z-.5)*target.Z/countZ)
            end end
        end
        model=Instance.new('Model');model.Name='CourseProp_'..tostring(row.id)
        model:SetAttribute('CoursePropAppearance','CanonicalCourseProp')
        local skin=Instance.new('Model');skin.Name=row.kind..'Appearance'
        sequence+=1;local id=row.kind..':'..tostring(sequence)
        skin:SetAttribute('CanonicalCoursePropSkin',true);skin:SetAttribute('CoursePropSkinId',id)
        local rows={}
        for tile,offset in ipairs(offsets)do for _,s in ipairs(source)do
            local p=s.part:Clone();p.Name=s.part.Name..(#offsets>1 and'_'..tile or'')
            p.Size=product(p.Size,scale);p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
            local pos=product(s.frame.Position,scale)
            local frame=CFrame.new(pos.X+offset.X,pos.Y+offset.Y,pos.Z+offset.Z)*s.frame.Rotation
            local pivot=s.pivot and product(s.pivot,scale)or Vector3.new()
            if s.motion then
                p:SetAttribute('MotionKind',s.motion);p:SetAttribute('MotionSpeed',s.speed)
                p:SetAttribute('MotionPivotX',pivot.X+offset.X);p:SetAttribute('MotionPivotY',pivot.Y+offset.Y);p:SetAttribute('MotionPivotZ',pivot.Z+offset.Z)
            end
            p.Parent=skin
            rows[#rows+1]={part=p,frame=frame,motion=s.motion,speed=s.speed,baselineAlpha=s.alpha,
                pivot=CFrame.new(pivot.X+offset.X,pivot.Y+offset.Y,pivot.Z+offset.Z)}
        end end
        resource:Destroy();resource=nil
        local refValue=Instance.new('ObjectValue');refValue.Name='CoursePropFallbackTarget';refValue.Value=row.part;refValue.Parent=skin
        skin.Parent=model
        return {model=model,skin=skin,id=id,rows=rows,part=row.part,kind=row.kind,size=size,fit=fit,fitMode=mode,
            previousOwner=row.part:GetAttribute('CoursePropFallbackOwner'),
            previousFallbackAlpha=row.part:GetAttribute('CoursePropFallbackTransparency')}
    end)
    if not ok then if model then model:Destroy()end;if resource then resource:Destroy()end;return end
    row.part:SetAttribute('CoursePropFallbackOwner',state.id)
    row.part:SetAttribute('CoursePropFallbackTransparency',row.part.Transparency)
    state.model.Parent=parent
    game:GetService('CollectionService'):AddTag(state.skin,'BrickToadsCoursePropSkin')
    return state
end
function Appearance.step(row,now)
    local state=row.coursePropAppearance;if not state then return end
    if not row.part or row.part~=state.part or not row.part.Parent or not state.model.Parent
        or state.skin.Parent~=state.model then Appearance.remove(row);return end
    if not finite(now)then return end
    local metadata=state.metadata or{}
    local alpha=finite(metadata.alpha)and math.clamp(metadata.alpha,0,1)or row.part.Transparency
    -- The translucent Updraft volume is a physical indicator; its solid fan
    -- cosmetic deliberately stays opaque until that volume is fully hidden.
    if row.kind=='Fan'and metadata.role=='Updraft'and alpha<1 then alpha=0 end
    local moving=metadata.hazard~=false and metadata.role~='Defused'and metadata.role~='Exploded'
    local anchor=state.projectileRotation and CFrame.new(row.part.CFrame.Position)*state.projectileRotation or row.part.CFrame
    for _,r in ipairs(state.rows)do
        local phase=r.motion and moving and(now*(r.speed or 1))%(math.pi*2)or nil
        -- Rest transforms/fit/pivots are immutable for this skin. Only a real
        -- anchor or animation-phase change needs another CFrame calculation.
        if r.lastAnchor~=anchor or r.lastPhase~=phase then
            local motion=CFrame.new()
            if phase then
                if r.motion=='SpinX'then motion=CFrame.Angles(phase,0,0)
                elseif r.motion=='SpinY'or r.motion=='Orbit'then motion=CFrame.Angles(0,phase,0)
                elseif r.motion=='SpinZ'then motion=CFrame.Angles(0,0,phase)
                elseif r.motion=='Pulse'then motion=CFrame.new(0,math.sin(phase)*math.min(state.size.Y*.035,.2),0)end
            end
            r.part.CFrame=anchor*state.fit*r.pivot*motion*r.pivot:Inverse()*r.frame
            r.lastAnchor=anchor;r.lastPhase=phase
        end
        local visible=r.baselineAlpha+(1-r.baselineAlpha)*alpha
        if r.lastVisible~=visible then
            r.part.Transparency=visible
            r.part:SetAttribute('CoursePropVisibleTransparency',visible)
            r.lastVisible=visible
        end
    end
end
function Appearance.update(row,parent,metadata,now)
    if not row then return end
    if not row.part or not row.part.Parent then Appearance.remove(row);return end
    local state=row.coursePropAppearance
    if state and(state.part~=row.part or state.kind~=row.kind or not same(state.size,row.part.Size)
        or state.model.Parent~=parent or state.skin.Parent~=state.model)then Appearance.remove(row);state=nil end
    if not state and KINDS[row.kind]then state=create(row,parent);row.coursePropAppearance=state end
    if not state then return end
    state.metadata=metadata or{}
    local velocity=state.metadata.visualVelocity
    if row.kind=='Rocket'and state.metadata.role=='Projectile'and type(velocity)=='table'
        and finite(velocity.x)and finite(velocity.y)and finite(velocity.z)then
        local length=math.sqrt(velocity.x^2+velocity.y^2+velocity.z^2)
        if length>.0001 and length<10000 then
            local direction=Vector3.new(velocity.x/length,velocity.y/length,velocity.z/length)
            local up=math.abs(direction.Y)>.99 and Vector3.new(1,0,0)or Vector3.new(0,1,0)
            state.projectileRotation=CFrame.lookAt(Vector3.new(),direction,up).Rotation
        end
    elseif state.metadata.role~='Projectile'then state.projectileRotation=nil end
    if row.part:GetAttribute('CoursePropFallbackOwner')==state.id
        and row.part:GetAttribute('CoursePropFallbackTransparency')~=row.part.Transparency then
        row.part:SetAttribute('CoursePropFallbackTransparency',row.part.Transparency)
    end
    Appearance.step(row,finite(now)and now or 0)
end
return Appearance
