-- Prepared native-instance fixture, not a playthrough or a physics/input claim.
-- Install fresh CampaignWorld and CanonicalCastAppearance (with its normal
-- sibling dependencies) under ServerStorage.BrickToadsVisualQA.Modules.
-- Cosmetic motors are explicitly solved for edit-mode geometry inspection.
assert(game:GetService('RunService'):IsStudio(),'Studio fixture only')
local SS=game:GetService('ServerStorage')
local QA=assert(SS:FindFirstChild('BrickToadsVisualQA'),'Missing owned visual QA folder')
local modules=assert(QA:FindFirstChild('Modules'),'Missing fresh QA modules')
local Campaign=require(assert(modules:FindFirstChild('CampaignWorld'),'Install the current CampaignWorld module'))
local Cast=require(assert(modules:FindFirstChild('CanonicalCastAppearance'),'Missing cast appearance module'))
local source=assert(SS:FindFirstChild('BrickToadsCastTemplates')):FindFirstChild('Snake')
assert(source and source:IsA('Model'),'Missing imported Snake template')
assert(not workspace:FindFirstChild('BrickToadsSerpentAcceptance'),'Remove only the prior owned Serpent fixture before rerunning')
local owner=Instance.new('Folder');owner.Name='BrickToadsSerpentAcceptance';owner.Parent=workspace
local report={scope='Prepared native CampaignWorld Serpent cosmetic/support acceptance',
    limitations='Owned synthetic support fixtures; explicitly solved cosmetic Motor6Ds; no campaign completion, player input, or physics integration claim.',
    placeId=game.PlaceId,createdAt=os.time(),cases={},errors={}}
local function closeFrame(a,b,message)
    local x,y={a:GetComponents()},{b:GetComponents()}
    for i,n in ipairs(x)do assert(math.abs(n-y[i])<.01,message..' component '..i..' actual='..tostring(n)..' expected='..tostring(y[i]))end
end
local function relativeMeshFrame(collider,part)
    -- Subtract large world positions before rotating the small local offset.
    -- CFrame inverse translation products lose precision at this remote fixture.
    local rotation=collider.CFrame.Rotation
    local position=rotation:VectorToObjectSpace(part.Position-collider.Position)
    return CFrame.new(position)*rotation:ToObjectSpace(part.CFrame.Rotation)
end
local function count(list,value)
    local n=0;for _,entry in ipairs(list)do if entry==value then n+=1 end end;return n
end
local sourceState={}
for _,entry in ipairs(source:GetDescendants())do
    if entry:IsA('MeshPart')then sourceState[entry]={size=entry.Size,frame=entry.CFrame,parent=entry.Parent}
    elseif entry:IsA('Attachment')then sourceState[entry]={frame=entry.CFrame,parent=entry.Parent}end
end
local function unchangedSource()
    assert(source.Parent==SS.BrickToadsCastTemplates,'Shared source template was moved')
    for entry,saved in pairs(sourceState)do
        assert(entry.Parent==saved.parent and entry.CFrame==saved.frame,'Shared source pivot/frame changed')
        if saved.size then assert(entry.Size==saved.size,'Shared source geometry was resized')end
    end
end
local function destroyed(entry,message)
    assert(entry.Parent==nil,message..' still has a parent')
    local ok=pcall(function()entry.Parent=owner end)
    assert(not ok,message..' was unparented without being destroyed')
end
local function newWorld(name)
    local folder=Instance.new('Folder');folder.Name=name;folder.Parent=owner
    local geometry=Instance.new('Folder');geometry.Name='Geometry';geometry.Parent=folder
    local world={folder=folder,geometry=geometry,offset=Vector3.new(9600,0,150),config={}}
    local route={id='prepared-serpents-'..name,name='Prepared Serpent acceptance',mode='Serpents',campaignIndex=7,
        spawn={x=0,y=8,z=0},bounds={minY=-40},course={renderDynamicPlatforms=true},
        boss={platform={x=60,y=0,z=0,w=20,h=2,d=20},pad={x=60,y=2,z=0,w=10,d=10}}}
    local campaign=Campaign.new(world,route)
    return campaign,world
end
local function skinReady(campaign,id,now)
    for attempt=0,60 do
        campaign:step(now+attempt*.01)
        local row=assert(campaign.objects[id],'Support disappeared during readiness wait')
        if row.serpent then return row.serpent end
        assert(row.part.Transparency<1 and row.part.CanCollide and row.part.CanQuery,
            'Pending/failed art hid or disabled the original support')
        if attempt<60 then task.wait(.1)end
    end
    error('Imported Snake resources did not become ready within six seconds')
end
local function solve(skin)
    local root=skin.actor.root;local rootFrame=root.CFrame
    local motors,flags={},{}
    for _,part in ipairs(skin.proxy:GetDescendants())do
        if part:IsA('Motor6D')then
            assert(part.Part0 and part.Part1 and part.Part1:IsA('MeshPart'),'Cosmetic motor lost a mesh endpoint')
            motors[#motors+1]={motor=part,part0=part.Part0,part1=part.Part1,c0=part.C0,c1=part.C1}
        elseif part:IsA('BasePart')then
            flags[part]={anchored=part.Anchored,massless=part.Massless,collide=part.CanCollide,
                query=part.CanQuery,touch=part.CanTouch}
        end
    end
    -- Plan in root-local coordinates while the real assembly remains untouched.
    -- Direct writes to a joined MeshPart can move the whole assembly in Edit.
    local frames={[root]=CFrame.new()}
    for _=1,#motors do for _,row in ipairs(motors)do
        if not frames[row.part1] and frames[row.part0] then
            frames[row.part1]=frames[row.part0]*row.c0*row.c1:Inverse()
        end
    end end
    for _,row in ipairs(motors)do assert(frames[row.part1],'Disconnected cosmetic joint hierarchy')end
    local ok,why=pcall(function()
        for _,row in ipairs(motors)do row.motor.Part0=nil;row.motor.Part1=nil end
        for _,row in ipairs(motors)do row.part1.CFrame=rootFrame*frames[row.part1]end
    end)
    -- Always restore the original endpoint identities, including on fixture error.
    for _,row in ipairs(motors)do row.motor.Part0=row.part0;row.motor.Part1=row.part1 end
    assert(ok,why)
    closeFrame(root.CFrame,rootFrame,'Disconnected prepared solver moved its root')
    for part,saved in pairs(flags)do
        assert(part.Anchored==saved.anchored and part.Massless==saved.massless and part.CanCollide==saved.collide
            and part.CanQuery==saved.query and part.CanTouch==saved.touch,'Prepared solver changed physical flags')
    end
end
local function colliderState(part)
    return {size=part.Size,frame=part.CFrame,anchored=part.Anchored,collide=part.CanCollide,
        query=part.CanQuery,touch=part.CanTouch,group=part.CollisionGroup,
        surface=part:GetAttribute('SurfaceId'),zone=part:GetAttribute('ZoneIndex')}
end
local function unchangedCollider(part,saved)
    assert(part.Size==saved.size and part.CFrame==saved.frame,'Art changed the authoritative collider dimensions/frame')
    assert(part.Anchored==saved.anchored and part.CanCollide==saved.collide
        and part.CanQuery==saved.query and part.CanTouch==saved.touch
        and part.CollisionGroup==saved.group,'Art changed authoritative physics flags')
    assert(part:GetAttribute('SurfaceId')==saved.surface and part:GetAttribute('ZoneIndex')==saved.zone,
        'Art changed authoritative support identity')
end
local function cosmeticInvariant(campaign,world,id,skin)
    local row=campaign.objects[id];local collider=row.part
    assert(skin.proxy.Parent==world.geometry and skin.temporary.Parent==nil,'Cosmetic/template ownership escaped the fixture')
    assert(skin.actor.castAppearance and skin.actor.castAppearance.model.Parent==skin.proxy,'Missing real attached cast skin')
    assert(skin.proxy:GetAttribute('CosmeticAdaptation')=='SourceHeadLinkWithAuthored3DSerpentSupportFit'
        and skin.proxy:GetAttribute('SourceBodyTrace')=='UNKNOWN_NAMETABLE_BODY','Serpent adaptation provenance missing')
    assert(skin.actor.root.Anchored and skin.actor.root.Massless and skin.actor.root.Transparency==1
        and not skin.actor.root.CanCollide and not skin.actor.root.CanTouch and not skin.actor.root.CanQuery,
        'Cosmetic proxy became physical')
    assert(count(world.allFloors,collider)==1 and count(world.floors,collider)==1,'Real support missing or duplicated')
    local meshes=0
    for _,part in ipairs(skin.proxy:GetDescendants())do if part:IsA('BasePart')then
        assert(not part.CanCollide and not part.CanQuery and not part.CanTouch and part.Massless,'Serpent art became physical/queryable')
        assert(count(world.allFloors,part)==0 and count(world.floors,part)==0,'Cosmetic part entered playable floor arrays')
        if part:IsA('MeshPart')then
            meshes+=1;assert(not part.Anchored and part.Transparency<1,'Imported cosmetic segment is fixed or invisible')
        end
    end end
    assert(meshes>0 and collider.Transparency<1,'Server must retain the support fallback for client readiness')
    assert(collider:GetAttribute('CastFallbackOwner')==skin.actor.castAppearance.skinId,
        'Support fallback is not explicitly bound to this cosmetic skin')
    closeFrame(skin.actor.root.CFrame,collider.CFrame*skin.fit,'Cosmetic root did not follow the support frame')
    solve(skin)
    closeFrame(skin.actor.root.CFrame,collider.CFrame*skin.fit,'Prepared manual rig solving moved the cosmetic root')
    local body=assert(skin.actor.castAppearance.model:FindFirstChild('Body'))
    local top=-math.huge
    for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
        local p=body.CFrame:PointToWorldSpace(Vector3.new(body.Size.X*x/2,body.Size.Y*y/2,body.Size.Z*z/2))
        top=math.max(top,collider.CFrame:PointToObjectSpace(p).Y)
    end end end
    assert(math.abs(top-collider.Size.Y/2)<.01,'Rendered Snake back no longer meets the original support top')
    unchangedSource()
    return meshes
end
local initialPoint,initialSize={x=0,y=14,z=0},{x=16,y=1,z=8}
local function create(campaign,world,id)
    local part=campaign:object(id,'Serpent',initialPoint,initialSize)
    local saved=colliderState(part)
    world.castAppearance=Cast
    local skin=skinReady(campaign,id,100)
    unchangedCollider(part,saved);cosmeticInvariant(campaign,world,id,skin)
    return part,skin
end
local function run(name,fn)
    local campaign,world=newWorld(name)
    local ok,result=pcall(fn,campaign,world)
    local cleanupOk,cleanupError=pcall(function()campaign:close();world.folder:Destroy();unchangedSource()end)
    if not cleanupOk then ok=false;result=tostring(result)..'; cleanup: '..tostring(cleanupError)end
    report.cases[#report.cases+1]={name=name,passed=ok,result=ok and result or nil}
    if not ok then report.errors[#report.errors+1]={name=name,error=tostring(result)}end
end
run('MovementAndYaw',function(campaign,world)
    local floorCount=#world.allFloors
    local collider,skin=create(campaign,world,'moving')
    local relative={}
    for _,part in ipairs(skin.actor.castAppearance.model:GetChildren())do if part:IsA('MeshPart')then
        relative[part]=relativeMeshFrame(collider,part)
    end end
    local moved=campaign:object('moving','Serpent',{x=12,y=18,z=-7},initialSize,{yaw=.7})
    assert(moved==collider and campaign.objects.moving.serpent==skin,'Position/yaw rebuilt the collider or cached art')
    local expected=CFrame.new(12,18,-7)*CFrame.Angles(0,.7,0)+world.offset
    closeFrame(collider.CFrame,expected,'Support movement differs from caller intent')
    local meshes=cosmeticInvariant(campaign,world,'moving',skin)
    for part,frame in pairs(relative)do closeFrame(relativeMeshFrame(collider,part),frame,'Real mesh '..part.Name..' failed to follow support translation/yaw')end
    assert(#world.allFloors==floorCount+1 and #world.floors==floorCount+1,'Art changed playable floor count')
    return {meshes=meshes,colliderPreserved=true,realMeshesFollowed=true}
end)
run('ResizeRebuild',function(campaign,world)
    local collider,old=create(campaign,world,'resized')
    local sizes={};for _,part in ipairs(old.actor.castAppearance.model:GetChildren())do if part:IsA('MeshPart')then sizes[part.Name]=part.Size end end
    local oldModel=old.actor.castAppearance.model
    local resized=campaign:object('resized','Serpent',initialPoint,{x=32,y=1,z=16})
    local skin=skinReady(campaign,'resized',102)
    assert(resized==collider and skin~=old,'Resize must retain collider identity and rebuild cached cosmetic geometry')
    assert(collider.Size==Vector3.new(32,1,16),'Cosmetics changed requested support dimensions')
    assert(old.actor.castAppearance==nil,'Old cast attachment survived resize')
    destroyed(old.proxy,'Old resize proxy');destroyed(old.temporary,'Old private resized template');destroyed(oldModel,'Old resized skin')
    for _,part in ipairs(skin.actor.castAppearance.model:GetChildren())do if part:IsA('MeshPart')then
        assert((part.Size-sizes[part.Name]*2).Magnitude<.001,'Imported segment did not uniformly double with its support fit')
    end end
    cosmeticInvariant(campaign,world,'resized',skin)
    return {sameCollider=true,newOwnedRig=true,uniformScale=2}
end)
run('Removal',function(campaign,world)
    local floorCount=#world.allFloors
    local collider,skin=create(campaign,world,'removed');local model=skin.actor.castAppearance.model
    campaign:remove('removed')
    assert(campaign.objects.removed==nil and skin.actor.castAppearance==nil,'Removed Serpent retained runtime state')
    destroyed(collider,'Removed collider');destroyed(skin.proxy,'Removed cosmetic proxy')
    destroyed(skin.temporary,'Removed private template');destroyed(model,'Removed attached skin')
    assert(#world.allFloors==floorCount and #world.floors==floorCount,'Removed Serpent remained a playable floor')
    return {ownedInstancesDestroyed=true,supportArraysRestored=true}
end)
run('KindReplacement',function(campaign,world)
    local collider,skin=create(campaign,world,'replaced')
    local lift=campaign:object('replaced','Lift',initialPoint,initialSize)
    assert(lift~=collider and campaign.objects.replaced.serpent==nil and lift.Transparency<1
        and lift.CanCollide and lift.CanQuery,'Lift replacement retained hidden Serpent state')
    destroyed(collider,'Replaced collider');destroyed(skin.proxy,'Replaced Serpent proxy');destroyed(skin.temporary,'Replaced private template')
    assert(count(world.allFloors,lift)==1 and count(world.floors,lift)==1,'Replacement support identity/count incorrect')
    return {replacementVisible=true,priorOwnedArtDestroyed=true}
end)
run('CourseClose',function(campaign,world)
    local floorCount=#world.allFloors
    local first,a=create(campaign,world,'close-a')
    local second=campaign:object('close-b','Serpent',{x=24,y=14,z=0},initialSize)
    local b=skinReady(campaign,'close-b',104)
    cosmeticInvariant(campaign,world,'close-b',b);campaign:close()
    assert(next(campaign.objects)==nil and #world.allFloors==floorCount and #world.floors==floorCount,'Course close retained dynamic support state')
    for _,entry in ipairs({first,second,a.proxy,a.temporary,b.proxy,b.temporary})do destroyed(entry,'Closed course instance')end
    return {allDynamicSupportsRemoved=true,allOwnedSerpentsDestroyed=true}
end)
if #report.errors==0 then
    local campaign,world=newWorld('VisualSample')
    local ok,why=pcall(function()
        local _,skin=create(campaign,world,'sample')
        report.visualSample={folder=world.folder:GetFullName(),meshes=cosmeticInvariant(campaign,world,'sample',skin),
            position={x=world.offset.X,y=14,z=world.offset.Z},retainedForCapture=true}
    end)
    if not ok then campaign:close();world.folder:Destroy();report.errors[#report.errors+1]={name='VisualSample',error=tostring(why)}end
end
report.status=#report.errors==0 and 'Passed' or 'Failed'
local result=QA:FindFirstChild('SerpentResult')
if result then assert(result:IsA('StringValue'),'Owned SerpentResult has an unexpected type');result:Destroy()end
result=Instance.new('StringValue');result.Name='SerpentResult';result.Value=game:GetService('HttpService'):JSONEncode(report);result.Parent=QA
return {status=report.status,cases=#report.cases,errors=report.errors,result=result:GetFullName(),fixture=owner:GetFullName()}
