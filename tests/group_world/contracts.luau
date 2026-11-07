-- These doubles exercise real coordinate consumers; engine physics is tested in Studio.
local Vec={}
Vec.__index=function(self,key)
    if key=='Magnitude' then return math.sqrt(self.X*self.X+self.Y*self.Y+self.Z*self.Z) end
    return Vec[key]
end
function Vec.__add(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},Vec) end
function Vec.__sub(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},Vec) end
local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},Vec) end
local Frame={}; Frame.__index=Frame
function Frame.__mul(a,b) return setmetatable({Position=a.Position+b.Position},Frame) end
function Frame.__add(a,b) return setmetatable({Position=a.Position+b},Frame) end
local function frame(x,y,z)
    return setmetatable({Position=type(x)=='table' and x or vector(x,y,z)},Frame)
end
local Node={}
Node.__index=function(self,key)
    if key=='Parent' then return rawget(self,'_parent') end
    if key=='Position' then return self.CFrame.Position end
    return Node[key] or self:FindFirstChild(key)
end
Node.__newindex=function(self,key,value)
    if key=='Parent' then
        local old=rawget(self,'_parent')
        if old then for i,child in ipairs(old.children) do if child==self then table.remove(old.children,i); break end end end
        rawset(self,'_parent',value)
        if value then value.children[#value.children+1]=self end
    else rawset(self,key,value) end
end
local function node(class,name,parent)
    local result=setmetatable({ClassName=class,Name=name or class,children={},attributes={}},Node)
    result.Parent=parent
    return result
end
function Node:IsA(class) return self.ClassName==class or class=='BasePart' and self.ClassName=='Part' end
function Node:GetChildren() return table.clone(self.children) end
function Node:GetDescendants()
    local all={}
    for _,child in ipairs(self.children) do
        all[#all+1]=child
        for _,descendant in ipairs(child:GetDescendants()) do all[#all+1]=descendant end
    end
    return all
end
function Node:FindFirstChild(name) for _,child in ipairs(self.children) do if child.Name==name then return child end end end
function Node:SetAttribute(name,value) self.attributes[name]=value end
function Node:GetAttribute(name) return self.attributes[name] end
function Node:Destroy() self.destroyed=true; self.Parent=nil end
function Node:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
function Node:PivotTo(cf) self.HumanoidRootPart.CFrame=cf end
local workspace=node('Workspace','Workspace')
local serverTime=0
function workspace:GetServerTimeNow() return serverTime end
function workspace:Raycast(origin,direction,params)
    local highest,partHit
    for _,p in ipairs(params.geometry:GetDescendants()) do
        if p:IsA('BasePart') and p.CanCollide then
            local top=p.Position.Y+p.Size.Y/2
            if origin.X>=p.Position.X-p.Size.X/2 and origin.X<=p.Position.X+p.Size.X/2
                and origin.Z>=p.Position.Z-p.Size.Z/2 and origin.Z<=p.Position.Z+p.Size.Z/2
                and top<=origin.Y and top>=origin.Y+direction.Y and (not highest or top>highest) then
                highest,partHit=top,p
            end
        end
    end
    if partHit then return {Instance=partHit,Position=vector(origin.X,highest,origin.Z),Normal=vector(0,1,0)} end
end
local lighting=node('Lighting','Lighting')
local enum=setmetatable({},{__index=function(self,key)
    local group=setmetatable({},{__index=function(_,value) return value end}); rawset(self,key,group); return group
end})
local env=setmetatable({workspace=workspace,game={GetService=function(_,name) return name=='Workspace' and workspace or lighting end},
    Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end},Enum=enum,
    Instance={new=function(class) return node(class) end},Vector3={new=vector},
    CFrame={new=frame,Angles=function() return frame() end,lookAt=function(p) return frame(p) end},
    UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}}, {__index=getfenv()})
local function source(text)
    local loader=assert(loadstring(text)); setfenv(loader,env); return loader()
end
local World,Camera=source(WorldSource),source(CameraSource)
local Base={}
function Base.new(config)
    local folder=node('Folder','CombatStandWorld',workspace)
    local geometry=node('Folder','Geometry',folder)
    return {config=config,folder=folder,geometry=geometry,actorFolder=node('Folder','Actors',folder),
        actors={},names={},origins={},deathReason={},lastSupport={},ray={geometry=geometry}}
end
function Base.clearActors(self)
    for _,a in pairs(self.actors) do a.model:Destroy() end
    self.actors={}; self.origins={}
end
local function actor(self,id,position)
    local model=node('Model','Actor_'..id,self.actorFolder)
    local root=node('Part','HumanoidRootPart',model); root.CFrame=frame(position)
    for _,name in ipairs({'Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg'}) do
        local limb=node('Part',name,model); limb.CFrame=frame(position)
    end
    root.Anchored=false; root.AssemblyLinearVelocity=vector()
    local a={model=model,root=root,humanoid={Health=100,PlatformStand=false,FloorMaterial=enum.Material.Slate,
        Jump=false,JumpPower=42,UseJumpPower=true},cue=0}
    self.actors[id]=a; return a
end
function Base.spawn(self,id,actorId,point)
    local origin=self.origins[id]
    actor(self,id,point and point.position or vector(origin.X,3,origin.Z))
    self.actors[id].model:SetAttribute('ActorId',actorId)
    return true
end
local function eq(actual,x,y,z,message)
    assert(actual.X==x and actual.Y==y and actual.Z==z,message or ('Unexpected vector '..actual.X..','..actual.Y..','..actual.Z))
end
local default=World.new(Base,{FallY=-20})
local second=World.new(Base,{FallY=-20},{name='BrickToadsWorld_G2',offset={x=100,y=10,z=512}})
assert(default.folder.Parent==workspace and not default.folder.destroyed,'Creating a group must preserve the first world')
assert(second.folder.Name=='BrickToadsWorld_G2','Group world name must match its namespace')
eq(second.floors[1].Position,121,8.3,512,'All group geometry must shift into its own arena')
eq(second.origins[1],35,13,505,'Safe respawn origins must use physical world coordinates')
local bounds=second:cameraBounds()
assert(bounds.minX==6 and bounds.maxX==236 and bounds.minY==17 and bounds.minZ==463 and bounds.maxZ==561,
    'Camera bounds must enclose the physical group geometry')
assert(second.config.FallY==-10 and default.config.FallY==-20,'Fall checks must remain relative to each arena height')
local duplicate=pcall(function() World.new(Base,{FallY=-20},{name='BrickToadsWorld_G2'}) end)
assert(not duplicate and second.folder.Parent==workspace,'Duplicate names must not replace an active world')
print('PASS group construction preserves worlds and offsets geometry, safe origins, camera bounds and falls')

assert(second:spawnEnemy(-1,'Drone',{x=82,y=3,z=-7}))
eq(second.actors[-1].root.Position,182,13,505,'Enemy local spawn coordinates must become global physical coordinates')
local localPosition=second:position(-1)
assert(localPosition.x==82 and localPosition.y==3 and localPosition.z==-7,'Director reads must remain local')
assert(second:projectile(-1001,{x=68,y=3,z=0},false))
eq(second.actors[-1001].root.Position,168,13,512,'Projectiles must share the same local-to-physical transform')
local hero=actor(second,1,vector(210,13,512))
assert(second:atExit(1),'Exit must compare the group-local position')
hero.root.CFrame=frame(210,13,0)
assert(not second:atExit(1),'A body in another arena cannot complete this group exit')
assert(second:spawn(2,'hero-two',nil,true,'Mr. Green'))
eq(second.actors[2].root.Position,35,13,512,'Emergency spawns must respect the arena height')
second:clearActors()
eq(second.origins[3],35,13,519,'New runs must reset shifted hero origins')
assert(default.folder.Parent==workspace,'Clearing group actors cannot destroy another world')
print('PASS local enemies/projectiles, physical emergency spawns, exits and new-run origins stay scoped')

local defaultActor=actor(default,1,vector(-65,3,0)); defaultActor.model:SetAttribute('ActorId','same-id')
local groupActor=actor(second,1,vector(35,13,512)); groupActor.model:SetAttribute('ActorId','same-id')
local camera=Camera.new()
camera:sync({runId='same-run',levelEpoch=1,groupId='G1',worldName='BrickToadsWorld',heroes={{actorId='same-id',status='Alive'}}})
camera:refreshTargets(); assert(camera.models['same-id']==defaultActor.model)
camera.mode='Free'; camera.freePosition=vector(1,2,3); camera.point=vector(3,2,1); camera.keys.W=true
camera:sync({runId='same-run',levelEpoch=1,groupId='G2',worldName='BrickToadsWorld_G2',heroes={{actorId='same-id',status='Alive'}}})
assert(camera.mode=='Follow' and camera.freePosition==nil and camera.point==nil and next(camera.keys)==nil,
    'World/group switches must reset free camera and its held input even if run/epoch match')
assert(next(camera.models or {})==nil and #camera.targets==0,'Old world targets must clear immediately')
camera:refreshTargets(); assert(camera.models['same-id']==groupActor.model,'Camera resolves only the selected world')
camera:sync({runId='same-run',levelEpoch=1,worldName='MissingGroup',heroes={{actorId='same-id',status='Alive'}}})
camera:refreshTargets(); assert(next(camera.models)==nil,'A missing selected world must never fall back to a different group')
camera:sync({runId='same-run',levelEpoch=1,worldName='MissingGroup',heroes={},cameraBounds=bounds})
local view={SetAttribute=function() end}
camera:step(.01,view)
eq(view.CFrame.Position,121,35,542,'A group without loaded actors must keep its camera in its own arena')
camera:sync({heroes={{actorId='same-id',status='Alive'}}})
camera:refreshTargets(); assert(camera.models['same-id']==defaultActor.model,'Old snapshots retain default-world compatibility')
print('PASS camera selects one world, clears cross-group state and never falls back from an explicit missing world')

local route=World.new(Base,{FallY=-20,Level=source(LevelSource)},
    {name='RouteWorld',offset={x=100,y=10,z=1024}})
assert(route.allFloors and #route.allFloors==12,'Modern route must build all district and guardian supports')
assert(#route.floors==1,'Initial respawns must not use unopened district platforms')
assert(route:groundPosition({x=50,y=3,z=0})==nil,'Aqueduct gap must have no collision bridge below it')
assert(route:groundPosition({x=532,y=3,z=0})==nil,'Longbridge gap must remain a real fall')
for _,x in ipairs({272,303,334}) do
    assert(route:groundPosition({x=x,y=9,z=0})==nil,'Cliff jumps must have no hidden supporting floor')
end
local landing=route:groundPosition({x=287,y=5,z=6})
assert(landing and landing.x==287 and math.abs(landing.y-3.2)<.00001 and landing.z==6,
    'Ground pickup placement must return the local top of its own elevated support')
assert(route.gates[1].beam.CanCollide and route.exitGate.beam.CanCollide,'Future gates start closed')
route:progress(2,false)
assert(#route.floors==3 and not route.gates[1].beam.CanCollide and route.gates[2].beam.CanCollide,
    'Zone entry opens only completed district gates and respawn supports')
local fullBounds=route:cameraBounds()
assert(fullBounds.maxX>790 and fullBounds.minZ<1024 and fullBounds.maxZ>1024,'Camera bounds include the complete offset route')
route:progress(6,true)
assert(#route.floors==11 and not route.gates[6].beam.CanCollide and route.exitGate.beam.CanCollide,
    'A complete district cannot expose future respawn supports before its exit is reached')
route:progress(7,false); assert(#route.floors==12,'Entering the guardian court unlocks its respawn support')
route:stage('Boss'); assert(route.exitGate.beam.CanCollide,'Guardian gate remains closed throughout battle')
route:stage('Exit'); assert(not route.exitGate.beam.CanCollide,'Defeating the guardian opens its final gate')
local finisher=actor(route,1,vector(780,13,1024))
assert(route:atExit(1),'Final exit must come from the level definition and group-local coordinates')
assert(not route:reached(1,{minX=0,maxX=4,minY=1,maxY=9,minZ=-10,maxZ=10}))
route:clearActors(); assert(#route.floors==1 and route.gates[1].beam.CanCollide,'New runs reset unlocked supports and all district gates')
route:noSafe(true); route:noSafe(false)
assert(route:groundPosition({x=50,y=3,z=0})==nil,'Resetting safe supports must not turn cosmetic marsh into a collision bridge')
print('PASS full district route keeps true gaps, elevated pickups, completed gates and safe supports scoped')

for _,item in ipairs({{kind='Pig',part='PigSnout'},{kind='Walker',part='WalkerShoulder'},{kind='Dragon',part='DragonWing'}}) do
    assert(route:spawnEnemy(-10,item.kind,{x=-35,y=3,z=0}))
    assert(route.actors[-10].model:FindFirstChild(item.part),'Species must have distinct visible original silhouettes')
    assert(route.actors[-10].model:GetAttribute('EnemyKind')==item.kind)
end
route:projectile(-2001,{x=-30,y=1.2,z=0},false,'Ground')
local pickup=route.actors[-2001]
assert(pickup.model:GetAttribute('ProjectileMode')=='Ground' and pickup.model:GetAttribute('Pickup')==true)
eq(pickup.root.Position,70,11.2,1024,'Modern pickups obey the same group offset as other actors')
local gold=pickup.root.Color
route:projectile(-2001,{x=-30,y=3,z=0},false,'Bullet')
assert(pickup.model:GetAttribute('Pickup')==false and pickup.root.Color~=gold,'Live bullets cannot look like ground pickups')
print('PASS ordinary species and guardian projectile modes have distinct original readable presentation')

local actualBase=source(BaseWorldSource)
local scopedSearch={floors=route.floors,actors={},origins={[1]=vector(720,13,1024)},deathReason={[1]='Fall'},lastSupport={},
    isSafe=function() return true end}
local scopedPoint=actualBase.findSafe(scopedSearch,1)
assert(scopedPoint and scopedPoint.surface:GetAttribute('ZoneIndex')==1,
    'Even a fall near the guardian cannot respawn into a still-locked district')
local tiny=node('Part','NarrowSupport',route.geometry); tiny.Size=vector(3,2,2); tiny.CFrame=frame(50,0,0); tiny.CanCollide=true
local wide=node('Part','SafeSupport',route.geometry); wide.Size=vector(20,2,20); wide.CFrame=frame(0,-1,0); wide.CanCollide=true
local search={floors={tiny,wide},actors={},origins={[1]=vector(0,3,0)},deathReason={},lastSupport={},
    isSafe=function() return true end}
local point=actualBase.findSafe(search,1)
assert(point and point.surface==wide,'Too-small support must be skipped instead of crashing respawn search')
print('PASS narrow support cannot crash safe respawn search')

-- These contracts run the actual adapter/hazard code; only engine integration is doubled.
Base.jump=actualBase.jump; Base.hazard=actualBase.hazard
local function standing(world,id)
    local previous=world.actors[id]
    if previous then previous.model:Destroy() end
    local a=actor(world,id,vector(47,3,0)+world.offset)
    a.model:SetAttribute('ActorId','jump-body-'..id)
    return a
end
local function walkOff(world,a,at,y)
    serverTime=at
    a.humanoid.FloorMaterial=enum.Material.Air
    a.root.CFrame=frame(vector(50.57,y or 1.31,0)+world.offset)
    a.root.AssemblyLinearVelocity=vector(16,-20,3)
    assert(world:hazard(1)==nil)
end

local delayed=standing(route,1)
serverTime=0; assert(route:hazard(1)==nil)
walkOff(route,delayed,.16)
route:jump(1)
eq(delayed.root.AssemblyLinearVelocity,16,42,3,
    'A server-confirmed walk-off within 0.20s must accept the delayed jump and preserve horizontal momentum')
assert(delayed.humanoid.Jump,'Accepted modern jump must also request its humanoid jump state')
print('PASS modern delayed jump uses bounded server ground history and preserves horizontal momentum')

delayed.humanoid.FloorMaterial=enum.Material.Slate
delayed.root.AssemblyLinearVelocity=vector(16,0,3); delayed.humanoid.Jump=false
serverTime=.17; route:hazard(1); route:jump(1)
eq(delayed.root.AssemblyLinearVelocity,16,0,3,'The stale grounded physics frame before takeoff cannot rearm a consumed jump')
assert(not delayed.humanoid.Jump)
delayed.humanoid.FloorMaterial=enum.Material.Air
delayed.root.CFrame=frame(vector(52,4,0)+route.offset)
delayed.root.AssemblyLinearVelocity=vector(16,30,3); serverTime=.18; route:hazard(1)
delayed.root.AssemblyLinearVelocity=vector(16,-2,3); delayed.humanoid.Jump=false
serverTime=.19; route:hazard(1); route:jump(1)
eq(delayed.root.AssemblyLinearVelocity,16,-2,3,'An airborne player cannot repeat the coyote jump')
assert(not delayed.humanoid.Jump)
delayed.humanoid.FloorMaterial=enum.Material.Slate
delayed.root.CFrame=frame(vector(56,3,0)+route.offset)
delayed.root.AssemblyLinearVelocity=vector(16,0,3); serverTime=.6; route:hazard(1); route:jump(1)
eq(delayed.root.AssemblyLinearVelocity,16,42,3,'A real landing must restore one jump')
print('PASS jump consumption survives stale floor reports and midair input, then resets after actual landing')

for _,case in ipairs({{at=.2,y=-.5,accept=true},{at=.2001,y=1.31,accept=false},{at=.16,y=-.501,accept=false}}) do
    local a=standing(route,1); serverTime=0; route:hazard(1)
    walkOff(route,a,case.at,case.y); route:jump(1)
    assert(a.humanoid.Jump==case.accept,'Walk-off grace must enforce both its exact time boundary and maximum 3.5-stud drop')
    eq(a.root.AssemblyLinearVelocity,16,case.accept and 42 or -20,3)
end
for _,blocked in ipairs({'Anchored','Reaction','Dead'}) do
    local a=standing(route,1); serverTime=0; route:hazard(1); walkOff(route,a,.1)
    if blocked=='Anchored' then a.root.Anchored=true
    elseif blocked=='Reaction' then a.humanoid.PlatformStand=true
    else a.humanoid.Health=0 end
    route:jump(1)
    eq(a.root.AssemblyLinearVelocity,16,-20,3,'Dead, held, and reacting actors cannot use jump grace')
    assert(not a.humanoid.Jump)
end
print('PASS jump grace rejects expired, deep, dead, held and reacting requests')

local old=standing(route,1); serverTime=0; route:hazard(1)
local replacement=standing(route,1); walkOff(route,replacement,.1); route:jump(1)
assert(not replacement.humanoid.Jump,'A replacement body must never inherit the previous actor jump history')
eq(replacement.root.AssemblyLinearVelocity,16,-20,3)
local scoped=World.new(Base,{FallY=-20,Level=source(LevelSource)},
    {name='OtherJumpRoute',offset={x=100,y=10,z=1536}})
local isolated=standing(scoped,1); walkOff(scoped,isolated,.1); scoped:jump(1)
assert(not isolated.humanoid.Jump,'A different group cannot borrow grounded history for the same slot ID')
local legacy=standing(default,1); serverTime=0; default:hazard(1)
walkOff(default,legacy,.1); default:jump(1)
assert(not legacy.humanoid.Jump,'Legacy worlds must retain the original grounded-only BaseWorld jump')
eq(legacy.root.AssemblyLinearVelocity,16,-20,3)
print('PASS jump history belongs to one actual actor in one modern world and preserves legacy behavior')
