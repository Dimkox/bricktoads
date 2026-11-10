-- Prepared native instances only. No live player, Session, route or asset writes.
-- Leaves an owned gallery for client loading/screenshots; remove both named QA folders afterward.
assert(game:GetService('RunService'):IsStudio(),'Studio QA only')
local SS=game:GetService('ServerStorage')
local sourceModules=assert(game.ServerScriptService:FindFirstChild('BrickToads')).gameplay
assert(not workspace:FindFirstChild('BrickToadsCourseGallery'),'Owned gallery already exists')
assert(not SS:FindFirstChild('BrickToadsCourseElementsQA'),'Owned course QA already exists')
local owner=Instance.new('Folder');owner.Name='BrickToadsCourseElementsQA';owner.Parent=SS
local GP=sourceModules:Clone();GP.Name='Modules';GP.Parent=owner
for _,v in ipairs(GP:GetDescendants())do if v:IsA('BaseScript')then v.Disabled=true end end
local CampaignWorld=require(GP.CampaignWorld)
local Definition=require(GP.CampaignDefinition)
local gallery=Instance.new('Folder');gallery.Name='BrickToadsCourseGallery';gallery.Parent=workspace
local geo=Instance.new('Folder');geo.Name='Geometry';geo.Parent=gallery
local world={folder=gallery,geometry=geo,offset=Vector3.new(9000,0,0),config={},
    castAppearance=require(GP.CanonicalCastAppearance)}
local course=CampaignWorld.new(world,Definition.build(3,1158731273))
local report={schema=1,scope='Prepared actual renderer/resources/lifecycle; no campaign or human-input acceptance',
    placeId=game.PlaceId,createdAt=os.time(),rows={},inventory={},errors={},mountCandidates={},
    limits={'Native bounds expose clipping; bounding boxes do not measure visible pixels.',
        'Raised candidates change only owned fixture cosmetic parts; they are not production behavior.',
        'Imported resource loading/visibility is tested separately on the genuine client.',
        'Primitive inventory validates existing simple art; it does not claim detailed meshes.'}}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function vector(v)return {v.X,v.Y,v.Z}end
local function validPart(p)
    for _,v in ipairs({p.Size.X,p.Size.Y,p.Size.Z})do assert(finite(v)and v>0,'Invalid native size '..p.Name)end
    for _,v in ipairs({p.CFrame:GetComponents()})do assert(finite(v),'Invalid native frame '..p.Name)end
end
local function bounds(p)
    local low,high=math.huge,-math.huge
    for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
        local q=p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2))
        low=math.min(low,q.Y);high=math.max(high,q.Y)
    end end end
    return low,high
end
local function member(list,p)local n=0;for _,v in ipairs(list)do if v==p then n+=1 end end;return n end
local function snapshot(p)
    return {size=p.Size,frame=p.CFrame,collide=p.CanCollide,touch=p.CanTouch,query=p.CanQuery,
        anchored=p.Anchored,massless=p.Massless,surface=p:GetAttribute('SurfaceId')}
end
local function preserved(p,s)
    assert(p.Size==s.size and p.CFrame==s.frame and p.CanCollide==s.collide and p.CanTouch==s.touch
        and p.CanQuery==s.query and p.Anchored==s.anchored and p.Massless==s.massless
        and p:GetAttribute('SurfaceId')==s.surface,'Original collider changed')
end
local function inspect(row,raisedCandidate)
    local state=assert(row.courseAppearance,'No course appearance '..row.kind)
    local result={kind=row.kind,parts=0,meshes=0,resources={},minY=math.huge,maxY=-math.huge}
    for _,p in ipairs(state.model:GetDescendants())do if p:IsA('BasePart')then
        validPart(p);result.parts+=1
        assert(p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery,
            'Unsafe owned cosmetic '..p.Name)
        local low,high=bounds(p);result.minY=math.min(result.minY,low);result.maxY=math.max(result.maxY,high)
        if p:IsA('MeshPart')then
            result.meshes+=1;assert(p.MeshId:match('^rbxassetid://%d+$'),'Missing mesh '..p.Name)
            local surface=p:FindFirstChildOfClass('SurfaceAppearance')
            assert(p.TextureID:match('^rbxassetid://%d+$')or surface and surface.ColorMap:match('^rbxassetid://%d+$'),
                'Missing native texture '..p.Name)
            result.resources[#result.resources+1]={name=p.Name,mesh=p.MeshId,texture=p.TextureID,
                colorMap=surface and surface.ColorMap,minY=low,maxY=high}
        end
    end end
    assert(result.parts>0,'Empty appearance')
    if state.skin then
        assert(state.skin:GetAttribute('CanonicalCourseSkin')==true and state.skin:GetAttribute('CourseSkinId')==state.id)
        assert(state.skin.CourseFallbackTarget.Value==row.part and row.part:GetAttribute('CourseFallbackOwner')==state.id)
        local deck=state.skin:FindFirstChild(row.kind=='Surfboard'and'Deck'or'RiderDeck')
        assert(deck,'Missing rider deck');local _,top=bounds(deck)
        result.deckTop=top;result.anchorFootPlaneY=row.part.Position.Y-(row.kind=='ClingerVehicle'and .3 or .4)
        result.expectedFootY=state.deckWorldY or result.anchorFootPlaneY
        result.deckDelta=top-result.expectedFootY;result.deckVsAnchorFoot=top-result.anchorFootPlaneY
        if not raisedCandidate then
            assert(math.abs(result.deckDelta)<=(state.deckWorldY and .02 or .12),'Deck does not match its actual declared rider plane')
        end
        assert(row.part.Transparency<1,'Server must retain the loading fallback')
    end
    return result
end
local function protect(name,fn)
    local ok,err=xpcall(fn,debug.traceback)
    if not ok then report.errors[#report.errors+1]={kind=name,error=tostring(err)}end
end
local function templateFingerprint()
    local rows={};local templates=assert(SS:FindFirstChild('BrickToadsCourseTemplates'))
    for _,t in ipairs(templates:GetChildren())do for _,p in ipairs(t:GetDescendants())do if p:IsA('MeshPart')then
        rows[#rows+1]=p:GetFullName()..':'..tostring(p.Size)..':'..tostring(p.CFrame)..':'..p.MeshId..':'..p.TextureID
    end end end
    table.sort(rows);return table.concat(rows,'|')
end
local templatesBefore=templateFingerprint()
local cases={{'Speeder',6,.9,3},{'Surfboard',6,.9,3},{'Jet',6,.9,3},{'ClingerVehicle',4,.6,4},
    {'Wall',3,18,12},{'LowBarrier',3,3,44},{'Overhead',3,5,12},{'MovingWall',4,14,5},
    {'MechanicalCrusher',6,10,6},{'PipeCrusher',5,10,8},{'ElectricGate',3,9,44}}
for n,c in ipairs(cases)do protect(c[1],function()
    local kind=c[1];local vehicle=n<=4;local id='fixture-'..kind
    local point={x=(n-1)%4*22,y=vehicle and(kind=='Jet'and 5.4 or(kind=='ClingerVehicle'and .3 or .4))or 12,
        z=120+math.floor((n-1)/4)*60}
    local size={w=c[2],h=c[3],d=c[4]};local metadata={collidable=kind=='MovingWall',yaw=.2,alpha=vehicle and 0 or .1}
    if kind=='Surfboard'then
        -- Own QA water coverage exercises the actual renderer's surface lookup.
        course.route.course.media=course.route.course.media or{}
        course.route.course.media[#course.route.course.media+1]={kind='Water',minX=point.x-12,maxX=point.x+12,
            minZ=point.z-12,maxZ=point.z+42,minY=-1,maxY=1}
    end
    local baseline=#world.floors
    local p=course:object(id,kind,point,size,metadata);local row=course.objects[id];local before=snapshot(p)
    assert(p.Size==Vector3.new(size.w,size.h,size.d)
        and p.CFrame==CFrame.new(point.x,point.y,point.z)*CFrame.Angles(0,metadata.yaw,0)+world.offset,
        'Original native dimensions or pose differ from authored renderer input')
    assert(p.Anchored and p.CanCollide==metadata.collidable and p.CanQuery==metadata.collidable and not p.CanTouch,
        'Original native collision/query flags changed')
    local result=inspect(row);preserved(p,before)
    assert(member(world.floors,p)==(metadata.collidable and 1 or 0)and member(world.allFloors,p)==member(world.floors,p))
    local old=row.courseAppearance.model
    point.x+=3;metadata.yaw=.7;course:object(id,kind,point,size,metadata)
    assert(row.part==p and row.courseAppearance.model==old,'Movement replaced original body or skin')
    size.w+=.5;course:object(id,kind,point,size,metadata)
    assert(row.part==p and old.Parent==nil and row.courseAppearance.model~=old,'Resize leaked old art or replaced collider')
    old=row.courseAppearance.model;course:remove(id)
    assert(p.Parent==nil and old.Parent==nil and #world.floors==baseline and member(world.allFloors,p)==0,'Remove leaked art or floor')
    size.w=c[2];point.x-=3;metadata.yaw=.2
    p=course:object(id,kind,point,size,metadata);row=course.objects[id]
    result.lifecyclePassed=true;result.originalSize=vector(p.Size);result.collider=metadata.collidable;report.rows[#report.rows+1]=result
    if vehicle then
        local floor=Instance.new('Part');floor.Name='QA_Road_'..kind;floor.Size=Vector3.new(18,2,18)
        floor.CFrame=CFrame.new(point.x,kind=='Surfboard'and 0 or-1,point.z)+world.offset
        floor.Anchored=true;floor.CanCollide=false;floor.CanTouch=false;floor.CanQuery=false;floor.Transparency=kind=='Surfboard'and .65 or 0
        floor.Material=kind=='Surfboard'and Enum.Material.Glass or Enum.Material.Concrete;floor.Parent=gallery
        result.referenceSurfaceY=kind=='Surfboard'and 1 or 0
        result.hullBelowSurface=result.minY<result.referenceSurfaceY
        if row.courseAppearance.deckWorldY==nil then
            local lifts={Speeder=1.06,Surfboard=1.05,Jet=0,ClingerVehicle=2.94}
            local q={x=point.x,y=point.y,z=point.z+30};local candidateId=id..'-raised-candidate'
            local raisedFloor=floor:Clone();raisedFloor.Name='QA_Candidate_Road_'..kind
            raisedFloor.CFrame+=Vector3.new(0,0,30);raisedFloor.Parent=gallery
            course:object(candidateId,kind,q,size,metadata);local candidate=course.objects[candidateId]
            for _,r in ipairs(candidate.courseAppearance.rows)do r.part.CFrame+=Vector3.new(0,lifts[kind],0)end
            local raised=inspect(candidate,true);raised.cosmeticLift=lifts[kind];raised.preparedCandidate=true
            -- Candidate deck intentionally no longer meets the unchanged physical-foot plane.
            report.mountCandidates[#report.mountCandidates+1]=raised
        end
    end
end)end

-- Inventory comes from all thirteen actual authored definitions after roster conversion.
local inventory={}
local function add(kind,size,metadata)if not inventory[kind]then inventory[kind]={size=size,metadata=metadata or{}}end end
local function dimensions(row)return {w=row.w or 2,h=row.h or 2,d=row.d or 2}end
for index=2,13 do
    local d=Definition.build(index,1158731273);local c=d.course
    for _,h in ipairs(c.hazards or{})do add(h.kind,dimensions(h),{alpha=.1})end
    for _,h in ipairs(c.walls or{})do add(h.kind,dimensions(h),{collidable=true})end
    for _,s in ipairs(c.supports or{})do add(s.kind,dimensions(s),{collidable=true})end
    for _,s in ipairs(c.lifts or{})do add(s.kind,dimensions(s),{collidable=true})end
    for _,b in ipairs(c.blocks or{})do add('IceBlock',dimensions(b),{collidable=true})end
    for _,e in ipairs(c.emitters or{})do add(e.kind,{w=3,h=3,d=3});add(e.kind=='RetroBlaster'and'RetroBolt'or'Rocket',{w=1,h=1,d=1})end
    if c.mount then add(d.mode=='Surf'and'Surfboard'or d.mode,{w=6,h=.9,d=3});add('BoardingPad',{w=7,h=1,d=6});add('Warning',{w=1,h=.3,d=5})end
    if d.mode=='Rope'then add('Rope',{w=.18,h=20,d=.18})end
    if d.mode=='Clinger'then add('ClingerVehicle',{w=4,h=.6,d=4});add('Buzzball',{w=5,h=5,d=5})end
    if d.mode=='Tower'then add('Tower',{w=28,h=105,d=28});add('TowerPlatform',{w=18,h=2,d=18},{collidable=true})end
    if #(c.media or{})>0 then add('Water',{w=20,h=8,d=20})end
    if #(c.bombs or{})>0 then add('Bomb',{w=3,h=3,d=3})end
    if #(c.fans or{})>0 then add('Fan',{w=12,h=14,d=14},{alpha=.8})end
    if #(c.springs or{})>0 then add('Spring',{w=8,h=4,d=8})end
    if #(c.ramps or{})>0 then add('Ramp',{w=3,h=1,d=12})end
end
add('Telegraph',{w=6,h=.12,d=6},{alpha=.35})
local names={};for kind in pairs(inventory)do names[#names+1]=kind end;table.sort(names)
for n,kind in ipairs(names)do protect('Inventory:'..kind,function()
    local entry=inventory[kind];local id='inventory-'..kind
    local p=course:object(id,kind,{x=(n-1)%8*20,y=kind=='Tower'and 55 or 12,z=360+math.floor((n-1)/8)*65},entry.size,entry.metadata)
    validPart(p);local row=course.objects[id]
    local mapped=row.courseAppearance and(row.courseAppearance.skin and'ImportedVehicle'or'Authored3DStructure')
        or row.serpent and'ImportedSnakeSupport'or'ExistingPrimitive'
    report.inventory[#report.inventory+1]={kind=kind,renderer=mapped,size=vector(p.Size),
        collider=p.CanCollide,query=p.CanQuery,floorCount=member(world.floors,p)}
    assert(p.Anchored and not p.CanTouch and p.CanQuery==p.CanCollide,'Unexpected original renderer physics')
    assert(member(world.floors,p)==(p.CanCollide and 1 or 0),'Floor registry mismatch')
end)end
assert(templateFingerprint()==templatesBefore,'Shared vehicle resources were changed')
report.sharedTemplatesPreserved=true
local read=Instance.new('BindableFunction');read.Name='Read';read.Parent=owner
read.OnInvoke=function()return game:GetService('HttpService'):JSONEncode(report)end
local cleanup=Instance.new('BindableFunction');cleanup.Name='Cleanup';cleanup.Parent=owner
cleanup.OnInvoke=function()course:close();gallery:Destroy();owner:Destroy();return true end
return {cases=#report.rows,inventoryKinds=#report.inventory,candidates=#report.mountCandidates,
    errors=report.errors,gallery=gallery:GetFullName(),read=read:GetFullName()}
