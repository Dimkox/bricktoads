-- Prepared native renderer acceptance only; never creates a Session or GameWorld.
-- Read/Cleanup are owned BindableFunctions. The caller removes this gallery after client QA.
assert(game:GetService('RunService'):IsStudio(),'Studio QA only')
local SS=game:GetService('ServerStorage')
local source=assert(game.ServerScriptService:FindFirstChild('BrickToads')).gameplay
local OWNER='BrickToadsCoursePropsQA'
local GALLERY='BrickToadsCoursePropsGallery'
assert(not SS:FindFirstChild(OWNER)and not workspace:FindFirstChild(GALLERY),'Owned prop QA already exists')
local templates=assert(SS:FindFirstChild('BrickToadsCoursePropTemplates'),'Missing private prop templates')
local KINDS={'AirMine','BoardingPad','Bomb','Buzzball','ElectricTrap','Fan','Gas','Gear','IceBlock','Icicle',
    'Lift','Log','Mine','MovingIcePlatform','Ramp','Rocket','RocketLauncher','Rope','RotatingSpike','Snowball',
    'Spike','Spring','Telegraph','Tower','TowerPlatform','Warning','Water','Whirlpool'}
local wanted={};for _,kind in ipairs(KINDS)do wanted[kind]=true end
local owner=Instance.new('Folder');owner.Name=OWNER;owner.Parent=SS
local modules=source:Clone();modules.Name='Modules';modules.Parent=owner
for _,v in ipairs(modules:GetDescendants())do if v:IsA('BaseScript')then v.Disabled=true end end
local CampaignWorld=require(modules.CampaignWorld)
local Definition=require(modules.CampaignDefinition)
local Modes=require(modules.CampaignModes)
local PropAppearance=require(modules.CoursePropAppearance)
-- Only this prepared catalog is persistent, so a far-away test client receives
-- the full resource set. Natural campaign distance streaming is tested separately.
local gallery=Instance.new('Model');gallery.Name=GALLERY;gallery.ModelStreamingMode=Enum.ModelStreamingMode.Persistent;gallery.Parent=workspace
local report={schema=1,scope='Prepared actual CampaignWorld and definition renderer input acceptance',
    placeId=game.PlaceId,createdAt=os.time(),cases={},definitions={},errors={},
    limits={'No live campaign, player input, progress, damage, or asset load success is asserted.',
        'Native geometry/resource checks do not measure visible pixels. Genuine-client visual QA is separate.',
        'Causeway has no course table; its definition is inspected without inventing course geometry.'}}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function vector(v)return {v.X,v.Y,v.Z}end
local function count(list,p)local n=0;for _,v in ipairs(list)do if v==p then n+=1 end end;return n end
local function protect(label,fn)
    local ok,err=xpcall(fn,debug.traceback)
    if not ok then report.errors[#report.errors+1]={case=label,error=tostring(err)}end
end
local function valid(p)
    for _,n in ipairs({p.Size.X,p.Size.Y,p.Size.Z})do assert(finite(n)and n>0,'Invalid native size '..p.Name)end
    for _,n in ipairs({p.CFrame:GetComponents()})do assert(finite(n),'Invalid native CFrame '..p.Name)end
end
local function fingerprint()
    local rows={}
    for _,model in ipairs(templates:GetChildren())do
        assert(model:IsA('Model')and wanted[model.Name],'Unexpected shared prop model')
        for _,p in ipairs(model:GetDescendants())do
            local value=p:GetFullName()..':'..p.ClassName
            if p:IsA('MeshPart')then value..=':'..tostring(p.Size)..':'..tostring(p.CFrame)..':'..p.MeshId..':'..p.TextureID
                ..':'..tostring(p.Color)..':'..tostring(p.Material)..':'..tostring(p.Transparency)
            elseif p:IsA('SurfaceAppearance')then value..=':'..p.ColorMap..':'..p.NormalMap..':'..p.RoughnessMap..':'..p.MetalnessMap
            elseif p:IsA('ValueBase')then value..=':'..tostring(p.Value)end
            local attributes=p:GetAttributes();local keys={};for key in pairs(attributes)do keys[#keys+1]=key end;table.sort(keys)
            for _,key in ipairs(keys)do value..=':'..key..'='..tostring(attributes[key])end
            rows[#rows+1]=value
        end
    end
    assert(#templates:GetChildren()==28,'Exactly 28 shared prop templates required')
    table.sort(rows);return table.concat(rows,'|')
end
local originalTemplates=fingerprint()
local lighting=game:GetService('Lighting')
local originalLighting={lighting.ClockTime,lighting.Brightness,lighting.Ambient,lighting.OutdoorAmbient,lighting.FogEnd}
local function newWorld(name,definition,z)
    local folder=Instance.new('Folder');folder.Name=name;folder.Parent=gallery
    local geometry=Instance.new('Folder');geometry.Name='Geometry';geometry.Parent=folder
    local world={folder=folder,geometry=geometry,offset=Vector3.new(18000,0,z or 0),config={},
        castAppearance=require(modules.CanonicalCastAppearance)}
    local course=CampaignWorld.new(world,definition)
    function world:campaignObject(id,kind,point,size,metadata)return course:object(id,kind,point,size,metadata)end
    function world:campaignRemove(id)return course:remove(id)end
    return world,course
end
local function snapshot(p,world)
    return {size=p.Size,frame=p.CFrame,shape=p.Shape,material=p.Material,collide=p.CanCollide,touch=p.CanTouch,
        query=p.CanQuery,anchored=p.Anchored,massless=p.Massless,surface=p:GetAttribute('SurfaceId'),
        zone=p:GetAttribute('ZoneIndex'),alpha=p.Transparency,floors=count(world.floors,p),allFloors=count(world.allFloors,p)}
end
local function preserved(p,world,s,pose)
    assert(p.Parent and p.Size==(pose and pose.size or s.size)and p.CFrame==(pose and pose.frame or s.frame),
        'Appearance changed original collider geometry')
    assert(p.Shape==s.shape and p.Material==s.material and p.CanCollide==s.collide and p.CanTouch==s.touch
        and p.CanQuery==s.query and p.Anchored==s.anchored and p.Massless==s.massless
        and p:GetAttribute('SurfaceId')==s.surface and p:GetAttribute('ZoneIndex')==s.zone,
        'Appearance changed original native collider contract')
    assert(p.Transparency==s.alpha,'Appearance changed original loading fallback transparency')
    assert(count(world.floors,p)==s.floors and count(world.allFloors,p)==s.allFloors,'Appearance changed support registry')
    if p.CanQuery then
        local filter=RaycastParams.new();filter.FilterType=Enum.RaycastFilterType.Include;filter.FilterDescendantsInstances={p}
        local result=workspace:Raycast(p.Position+Vector3.new(0,p.Size.Magnitude+2,0),Vector3.new(0,-2*p.Size.Magnitude-4,0),filter)
        assert(result and result.Instance==p,'Original queryable support no longer answers native queries')
    end
end
local function inspect(row)
    local state=assert(row.coursePropAppearance,'Missing prop appearance '..row.kind)
    local model=assert(state.model,'Missing prop model '..row.kind)
    assert(model.Parent and model:IsDescendantOf(gallery),'Prop escaped owned fixture')
    assert(model:GetAttribute('CoursePropAppearance')=='CanonicalCourseProp','Missing prop appearance profile')
    assert(state.skin:GetAttribute('CanonicalCoursePropSkin')==true and state.skin:GetAttribute('CoursePropSkinId')==state.id,
        'Missing private prop skin identity')
    assert(game:GetService('CollectionService'):HasTag(state.skin,'BrickToadsCoursePropSkin'),'Missing client readiness tag')
    assert(state.skin.CoursePropFallbackTarget.Value==row.part and row.part:GetAttribute('CoursePropFallbackOwner')==state.id,
        'Invalid original fallback ownership')
    local allowed={}
    for _,part in ipairs(templates[row.kind]:GetDescendants())do if part:IsA('MeshPart')then
        local surface=part:FindFirstChildOfClass('SurfaceAppearance')
        allowed[part.MeshId..'|'..part.TextureID..'|'..(surface and surface.ColorMap or'')]=true
    end end
    local result={kind=row.kind,meshCount=0,resources={},min={math.huge,math.huge,math.huge},max={-math.huge,-math.huge,-math.huge}}
    for _,p in ipairs(model:GetDescendants())do
        assert(not p:IsA('BaseScript')and not p:IsA('JointInstance')and not p:IsA('Attachment'),'Executable or rigged prop descendant')
        if p:IsA('BasePart')then
            assert(p:IsA('MeshPart'),'Prop contains placeholder geometry')
            valid(p);result.meshCount+=1
            assert(p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery,'Unsafe cosmetic flags')
            assert(p.MeshId:match('^rbxassetid://%d+$'),'Missing uploaded mesh')
            local surface=p:FindFirstChildOfClass('SurfaceAppearance')
            assert(p.TextureID:match('^rbxassetid://%d+$')or surface and surface.ColorMap:match('^rbxassetid://%d+$'),'Missing uploaded prop texture')
            assert(allowed[p.MeshId..'|'..p.TextureID..'|'..(surface and surface.ColorMap or'')],'Prop changed shared resource identity')
            assert(finite(p.Transparency)and p.Transparency>=0 and p.Transparency<=1,'Invalid cosmetic alpha')
            for _,child in ipairs(p:GetChildren())do assert(child:IsA('SurfaceAppearance')and #child:GetChildren()==0,'Unexpected mesh child')end
            for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
                local v=p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2))
                for axis,n in ipairs({v.X,v.Y,v.Z})do result.min[axis]=math.min(result.min[axis],n);result.max[axis]=math.max(result.max[axis],n)end
            end end end
            result.resources[#result.resources+1]={name=p.Name,mesh=p.MeshId,texture=p.TextureID,colorMap=surface and surface.ColorMap}
        end
    end
    assert(result.meshCount>0 and result.meshCount<=128,'Unbounded or empty prop mesh set')
    local metadata=state.metadata or{}
    local alpha=metadata.alpha or row.part.Transparency
    if row.kind=='Fan'and metadata.role=='Updraft'and alpha<1 then alpha=0 end
    for _,entry in ipairs(state.rows)do
        local expected=entry.baselineAlpha+(1-entry.baselineAlpha)*alpha
        assert(math.abs(entry.part.Transparency-expected)<1e-6
            and math.abs(entry.part:GetAttribute('CoursePropVisibleTransparency')-expected)<1e-6,'Cosmetic alpha contract differs from actual state')
    end
    return result
end
local function bounded(row,rest)
    local collider=row.part
    for _,p in ipairs(row.coursePropAppearance.model:GetDescendants())do if p:IsA('MeshPart')then
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            local worldPoint=p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2))
            local localPoint=collider.CFrame:PointToObjectSpace(worldPoint)
            if rest then
                assert(math.abs(localPoint.X)<=collider.Size.X/2+.02 and math.abs(localPoint.Y)<=collider.Size.Y/2+.02
                    and math.abs(localPoint.Z)<=collider.Size.Z/2+.02,'Rest cosmetic bounds escape original collider envelope')
            else
                assert(localPoint.Magnitude<=collider.Size.Magnitude*1.2+.5,'Animated cosmetic escapes bounded neighborhood')
            end
        end end end
    end end
end
local sizes={AirMine={3,9,44},BoardingPad={7,1,6},Bomb={3,3,3},Buzzball={5,5,5},ElectricTrap={6,8,7},
    Fan={12,14,14},Gas={6,6,6},Gear={5,10,8},IceBlock={6,4,6},Icicle={4,6,7},Lift={14,1,15},Log={3,3,44},
    Mine={3,3,12},MovingIcePlatform={7,1,12},Ramp={3,1,12},Rocket={1,1,1},RocketLauncher={3,3,3},
    Rope={.18,.18,20},RotatingSpike={4,5,4},Snowball={4,6,7},Spike={5,5,5},Spring={8,4,8},Telegraph={6,.12,6},
    Tower={28,105,28},TowerPlatform={18,2,18},Warning={1,.3,5},Water={112,22,36},Whirlpool={3,3,12}}
local support={IceBlock=true,Lift=true,MovingIcePlatform=true,TowerPlatform=true}
local world,course=newWorld('DirectCases',Definition.build(3,1158731273),0)
local baselineFloors=#world.floors
for index,kind in ipairs(KINDS)do protect(kind,function()
    local caseFloors=#world.floors
    local values=sizes[kind];local size={w=values[1],h=values[2],d=values[3]}
    local point={x=(index-1)%7*35,y=kind=='Tower'and 55 or 16,z=120+math.floor((index-1)/7)*75}
    local metadata={collidable=support[kind]==true,yaw=.23,alpha=kind=='Water'and .65 or .1,hazard=true,role='QA'}
    course:step(0)
    local id='direct-'..kind;local p=course:object(id,kind,point,size,metadata);local row=course.objects[id]
    local expectedSize=kind=='Tower'and Vector3.new(size.h,size.w,size.d)or Vector3.new(size.w,size.h,size.d)
    local expectedFrame=CFrame.new(point.x,point.y,point.z)
        *(kind=='Tower'and CFrame.Angles(0,0,math.pi/2)or CFrame.Angles(0,metadata.yaw,0))+world.offset
    assert(p.Size==expectedSize and p.CFrame==expectedFrame,'Appearance changed authored renderer dimensions or pose')
    assert(p.Anchored and not p.CanTouch and p.CanCollide==(support[kind]==true)and p.CanQuery==(support[kind]==true),
        'Appearance changed authored renderer collision/query flags')
    local before=snapshot(p,world);local result=inspect(row);preserved(p,world,before);bounded(row,true)
    assert(before.floors==(support[kind]and 1 or 0)and before.allFloors==before.floors,'Unexpected actual support membership')
    local model=row.coursePropAppearance.model;local countBefore=#model:GetDescendants()
    local frames={};for _,part in ipairs(model:GetDescendants())do if part:IsA('MeshPart')then
        frames[part]={part.CFrame,part.Size,part.Transparency}end end
    course:step(.2);preserved(p,world,before);inspect(row);bounded(row,false)
    course:step(.8);preserved(p,world,before);inspect(row);bounded(row,false)
    local animated=false;for part,rest in pairs(frames)do
        if part.CFrame~=rest[1]or part.Size~=rest[2]or part.Transparency~=rest[3]then animated=true end end
    local expectedAnimation=false
    for _,value in ipairs(templates[kind]:GetChildren())do
        if value:IsA('StringValue')and value.Name:match('^MotionKind_')then expectedAnimation=true end
    end
    assert(not expectedAnimation or animated,'Declared prop animation did not change a native frame, size, or alpha')
    result.animationObserved=animated
    assert(row.coursePropAppearance.model==model and #model:GetDescendants()==countBefore,'Animation grows or replaces prop resources')
    point.x+=4;metadata.yaw=.71
    course:object(id,kind,point,size,metadata)
    assert(row.part==p and row.coursePropAppearance.model==model,'Movement replaced original body or appearance')
    local moved={size=p.Size,frame=p.CFrame};preserved(p,world,before,moved)
    size.w+=.5;course:object(id,kind,point,size,metadata)
    assert(row.part==p and model.Parent==nil and row.coursePropAppearance.model~=model,'Resize leaked art or replaced collider')
    local resized=row.coursePropAppearance.model;inspect(row)
    metadata.alpha=.75;metadata.hazard=false;metadata.role='Inactive';course:object(id,kind,point,size,metadata)
    assert(row.coursePropAppearance.model==resized,'Inactive state rebuilt resources');inspect(row)
    metadata.alpha=1;metadata.role='Broken';course:object(id,kind,point,size,metadata);inspect(row)
    for _,part in ipairs(resized:GetDescendants())do if part:IsA('MeshPart')then
        assert(part.Transparency==1 and part:GetAttribute('CoursePropVisibleTransparency')==1,'Broken prop remains visible')end end
    -- An older owner's cleanup may not erase the identity of a newer fallback owner.
    p:SetAttribute('CoursePropFallbackOwner','external-owner')
    p:SetAttribute('CoursePropFallbackTransparency',.42)
    PropAppearance.remove(row)
    assert(not row.coursePropAppearance and resized.Parent==nil and p:GetAttribute('CoursePropFallbackOwner')=='external-owner'
        and p:GetAttribute('CoursePropFallbackTransparency')==.42,'Old owner overwrote replacement fallback ownership')
    metadata.alpha=.1;metadata.role='QA';course:object(id,kind,point,size,metadata)
    resized=row.coursePropAppearance.model;inspect(row)
    local replacement=kind=='Spike'and'AirMine'or'Spike'
    local newPart=course:object(id,replacement,point,{w=4,h=5,d=4},{alpha=.1,hazard=true})
    assert(p.Parent==nil and resized.Parent==nil and newPart~=p,'Kind change leaked original body or art')
    local newModel=course.objects[id].coursePropAppearance.model
    course:remove(id)
    assert(newPart.Parent==nil and newModel.Parent==nil and course.objects[id]==nil,'Remove leaked owned instances')
    assert(count(world.floors,p)==0 and count(world.allFloors,p)==0 and #world.floors==caseFloors,'Remove leaked support membership')
    p=course:object(id,kind,point,size,{alpha=.1,hazard=true,collidable=support[kind]==true})
    inspect(course.objects[id]);result.size=vector(p.Size);result.shape=p.Shape.Name;result.support=p.CanCollide
    result.lifecyclePassed=true;result.instanceCount=#course.objects[id].coursePropAppearance.model:GetDescendants()
    report.cases[#report.cases+1]=result
end)end

-- Execute the actual renderer-input functions against every actual course definition.
-- An empty prepared actor state prevents any Session, health, input, or progress effects.
for index=1,13 do protect('Definition:'..index,function()
    local definition=Definition.build(index,1158731273)
    local result={index=index,mode=definition.mode,name=definition.name,states={},kinds={}}
    report.definitions[#report.definitions+1]=result
    if not definition.course then result.reason='Causeway has no CampaignWorld course renderer';return end
    local native,renderer=newWorld('Definition_'..index,definition,600+index*350)
    local mode=setmetatable({course=definition.course,definition=definition,world=native,mode=definition.mode,
        session={order={}},actors={},supports={},blocks={},objects={},broken={},elapsed=0,rotation=0,
        bombIndex=1,race={failed=false},projectiles={},emitterNext={},projectileSerial=0},Modes)
    for _,field in ipairs({'supports','lifts'})do for _,entry in ipairs(definition.course[field]or{})do
        for segment=1,entry.segments or 1 do mode.supports[#mode.supports+1]={id=entry.id..'-qa-'..segment,definition=entry,
            position=entry.path[1],phase=-(segment-1)*(entry.segmentSpacing or 6)/entry.speed}end
    end end
    for _,time in ipairs({0,.7,1.8})do
        mode.elapsed=time;mode.rotation=time*(definition.course.rotationSpeed or 0)
        mode:_objects(.1);mode:_projectiles(.1);renderer:step(time)
        for _,block in ipairs(definition.course.blocks or{})do native:campaignObject(block.id,'IceBlock',block.position,
            {w=block.w,h=block.h,d=block.d},{collidable=true,role='Block'})end
        local state={time=time,count=0,propCount=0,kindCounts={}}
        for _,row in pairs(renderer.objects)do
            valid(row.part);state.count+=1
            local original=snapshot(row.part,native);preserved(row.part,native,original)
            if wanted[row.kind]then
                inspect(row);state.propCount+=1;state.kindCounts[row.kind]=(state.kindCounts[row.kind]or 0)+1;result.kinds[row.kind]=true
            end
        end
        result.states[#result.states+1]=state
    end
    local old={};for _,row in pairs(renderer.objects)do old[#old+1]={part=row.part,model=row.coursePropAppearance and row.coursePropAppearance.model}end
    renderer:close()
    for _,row in ipairs(old)do assert(row.part.Parent==nil and(not row.model or row.model.Parent==nil),'Definition close leaked dynamics')end
    assert(next(renderer.objects)==nil,'Definition close left object rows');result.closePassed=true
end)end
protect('Close',function()
    local old={};for _,row in pairs(course.objects)do old[#old+1]={part=row.part,model=row.coursePropAppearance and row.coursePropAppearance.model}end
    course:close();assert(next(course.objects)==nil and #world.floors==baselineFloors,'Close leaked rows or support registrations')
    for _,row in ipairs(old)do assert(row.part.Parent==nil and(not row.model or row.model.Parent==nil),'Close leaked owned art')end
    assert(fingerprint()==originalTemplates,'Shared prop resources changed')
    local after={lighting.ClockTime,lighting.Brightness,lighting.Ambient,lighting.OutdoorAmbient,lighting.FogEnd}
    for n,value in ipairs(originalLighting)do assert(after[n]==value,'Prepared fixture changed live Lighting')end
    report.sharedTemplatesPreserved=true;report.lightingPreserved=true;report.closePassed=true
end)
-- Retain one representative per kind after separately verifying close cleanup above.
protect('Gallery',function()
    for index,kind in ipairs(KINDS)do
        local values=sizes[kind]
        course:object('gallery-'..kind,kind,{x=(index-1)%7*35,y=kind=='Tower'and 55 or 16,
            z=120+math.floor((index-1)/7)*75},{w=values[1],h=values[2],d=values[3]},
            {collidable=support[kind]==true,alpha=kind=='Water'and .65 or .1,hazard=true,role=kind=='Fan'and'Updraft'or'QA'})
    end
    course:step(.2);course:step(.8)
    report.galleryKinds=28
end)
local read=Instance.new('BindableFunction');read.Name='Read';read.Parent=owner
read.OnInvoke=function()return game:GetService('HttpService'):JSONEncode(report)end
local step=Instance.new('BindableFunction');step.Name='Step';step.Parent=owner
step.OnInvoke=function(now)assert(finite(now),'Finite gallery time required');course:step(now);return true end
local cleanup=Instance.new('BindableFunction');cleanup.Name='Cleanup';cleanup.Parent=owner
cleanup.OnInvoke=function()course:close();gallery:Destroy();owner:Destroy();return true end
return {cases=#report.cases,definitions=#report.definitions,errors=report.errors,gallery=gallery:GetFullName(),read=read:GetFullName()}
