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
function Node:CanSetNetworkOwnership() return not self.Anchored end
function Node:SetNetworkOwner(owner) self.networkOwner=owner;self.networkOwnerSet=true end
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
        Jump=false,JumpPower=42,UseJumpPower=true,AutoRotate=true,WalkSpeed=12,EvaluateStateMachine=true},cue=0}
    function a.humanoid:Move(direction) self.lastMove=direction end
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

assert(type(second.healingFly)=='function' and type(second.catchFly)=='function',
    'The world must present healing flies separately from combat actors')
default:healingFly('shared-fly',{x=12,y=4,z=2})
second:healingFly('shared-fly',{x=12,y=4,z=2})
local firstFly=default.healingFlyFolder:FindFirstChild('HealingFly_shared-fly')
local secondFly=second.healingFlyFolder:FindFirstChild('HealingFly_shared-fly')
assert(firstFly and secondFly and firstFly~=secondFly,'Equal fly IDs in separate groups must create independent models')
eq(firstFly.PrimaryPart.Position,12,4,2)
eq(secondFly.PrimaryPart.Position,112,14,514,'Healing-fly coordinates must apply their group offset once')
assert(secondFly:GetAttribute('CollectibleId')=='shared-fly' and secondFly:GetAttribute('CollectibleKind')=='HealingFly')
assert(second.actors['shared-fly']==nil,'Healing flies cannot add an enemy or combat target')
for _,p in ipairs(secondFly:GetDescendants()) do
    if p:IsA('BasePart') then assert(not p.CanCollide and not p.CanTouch and not p.CanQuery,
        'Healing-fly art must not obstruct movement, supports, or combat queries') end
end
second:healingFly('shared-fly',{x=18,y=5,z=-3})
eq(secondFly.PrimaryPart.Position,118,15,509,'Moving a fly must preserve its existing model and physical group transform')
local catcher=actor(second,1,vector(115,13,509))
catcher.root.CFrame.LookVector=vector(1,0,0)
assert(type(second.canCatchFly)=='function','Fly catches need an authoritative facing/range predicate')
assert(second:canCatchFly(1,{x=18,y=5,z=-3},6,3,.25),'A nearby elevated fly ahead should be catchable in local coordinates')
assert(not second:canCatchFly(1,{x=12,y=5,z=-3},6,3,.25),'A fly behind the actual root direction cannot be caught')
assert(second:canCatchFly(1,{x=18,y=3,z=1},6,3,.6),'The exact facing-dot boundary remains eligible')
assert(not second:canCatchFly(1,{x=17.99,y=3,z=1},6,3,.6),'A fly outside the facing cone is unavailable')
assert(second:canCatchFly(1,{x=21,y=3,z=-3},6,3,.25),'The exact range boundary remains eligible')
assert(not second:canCatchFly(1,{x=21.001,y=3,z=-3},6,3,.25),'A fly beyond the range is unavailable')
assert(not second:canCatchFly(1,{x=21,y=6,z=-3},6,3,.25),'The catch radius uses three-dimensional distance')
assert(second:canCatchFly(1,{x=15,y=6,z=-3},6,3,.25),'A directly overhead fly at the height boundary needs no facing direction')
assert(not second:canCatchFly(1,{x=15,y=6.001,z=-3},6,3,.25),'Excessive vertical distance blocks a catch')
assert(not second:canCatchFly(2,{x=18,y=5,z=-3},6,3,.25),'Missing bodies cannot catch flies')
assert(second:catchFly(1,'shared-fly'),'An accepted catch should remove its visual and create a short tongue cue')
assert(secondFly.destroyed and firstFly.Parent~=nil,'Catching one group fly must preserve another group fly')
assert(#second.healingEffectFolder:GetChildren()==1,'A catch should have a single transient effect model')
assert(second:catchFly(1,'shared-fly')==false,'Repeated visual catch cannot create another effect')
second:updatePresentation(nil,.1);second:updatePresentation(nil,.1);second:updatePresentation(nil,.1)
assert(#second.healingEffectFolder:GetChildren()==0,'Catch effects must expire without keeping consumed flies alive')
second:healingFly('reset-fly',{x=20,y=4,z=0})
second:catchFly(1,'reset-fly')
second:healingFly('pending-fly',{x=22,y=4,z=0})
second:clearActors()
assert(#second.healingFlyFolder:GetChildren()==0 and #second.healingEffectFolder:GetChildren()==0,
    'New runs must clear all flies and pending tongue effects in their own world')
assert(firstFly.Parent~=nil,'Resetting one group must preserve the other group healing visuals')
default:healingFly('shared-fly',nil)
assert(firstFly.destroyed,'Explicit removal must destroy a fly without a catch effect')
print('PASS healing flies are separate noncolliding group visuals with bounded catch effects and run cleanup')

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

Base.move=actualBase.move; Base.setReaction=actualBase.setReaction
local carrying=World.new(Base,{FallY=-20,Level=source(LevelSource),Enemy={speed=9},WalkSpeed=12},
    {name='EnemyCarryWorld',offset={x=100,y=10,z=2048}})
local holder=actor(carrying,1,vector(100,13,2048))
holder.root.CFrame.LookVector=vector(1,0,0)
local pig=actor(carrying,-1,vector(103,13,2048))
pig.model:SetAttribute('ActorId','original-pig'); pig.model:SetAttribute('HealthRaw',2)
carrying.enemyKinds[-1]='Drone'
assert(type(carrying.canGrabEnemy)=='function','Enemy grabbing needs actual-body grounding, range, facing and geometry checks')
assert(carrying:canGrabEnemy(1,-1,4,2,.25),'A grounded hero can grab the nearby same-world pig ahead')
pig.root.CFrame=frame(97,13,2048)
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'A pig behind the actual hero direction cannot be grabbed')
pig.root.CFrame=frame(104.01,13,2048)
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'Grab range must not extend beyond its configured boundary')
pig.root.CFrame=frame(103,15.01,2048)
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'A grab cannot exceed its configured vertical separation')
pig.root.CFrame=frame(103,13,2048)
holder.humanoid.FloorMaterial=enum.Material.Air
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'Airborne heroes cannot initiate a ground grab')
holder.humanoid.FloorMaterial=enum.Material.Slate
holder.root.AssemblyLinearVelocity=vector(0,2,0)
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'A stale grounded report during upward flight cannot enable grabbing')
holder.root.AssemblyLinearVelocity=vector()
holder.root.CFrame=frame(150,13,2048); holder.root.CFrame.LookVector=vector(1,0,0)
pig.root.CFrame=frame(153,13,2048)
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'FloorMaterial alone cannot turn a true route gap into ground support')
holder.root.CFrame=frame(100,13,2048); holder.root.CFrame.LookVector=vector(1,0,0)
pig.root.CFrame=frame(103,13,2048)
for _,state in ipairs({'Anchored','Reaction','Dead'}) do
    holder.root.Anchored=state=='Anchored'; holder.humanoid.PlatformStand=state=='Reaction'
    holder.humanoid.Health=state=='Dead' and 0 or 100
    assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'A held, reacting or dead hero cannot grab')
end
holder.root.Anchored=false;holder.humanoid.PlatformStand=false;holder.humanoid.Health=100
local oldRaycast=workspace.Raycast
function workspace:Raycast(origin,direction,params)
    if math.abs(direction.X)>0 then return {Instance=carrying.gates[1].beam,Normal=vector(-1,0,0)} end
    return oldRaycast(self,origin,direction,params)
end
assert(not carrying:canGrabEnemy(1,-1,4,2,.25),'Collidable group geometry between the bodies blocks a grab')
workspace.Raycast=oldRaycast
assert(carrying:canGrabEnemy(1,-1,4,2,.25),'Removing only the geometry obstruction restores the eligible close grab')
print('PASS enemy grabs require actual same-world bodies, ground support, facing and clear geometry')

for _,p in ipairs(pig.model:GetDescendants()) do
    if p:IsA('BasePart') then p.CanCollide=p.Name=='Torso' or p.Name=='Head' end
end
local originalModel,originalHP=pig.model,pig.humanoid.Health
assert(carrying:carryEnemy(-1,1),'Grabbing must attach the same living model without spawning')
assert(pig.model==originalModel and pig.humanoid.Health==originalHP and pig.model:GetAttribute('HealthRaw')==2)
assert(pig.model:GetAttribute('ActorId')=='original-pig' and pig.model:GetAttribute('CarryMode')=='Carried'
    and pig.model:GetAttribute('HeldBy')==1 and holder.model:GetAttribute('CarryingEnemy')==-1)
assert(pig.root.Anchored and pig.humanoid.PlatformStand)
assert(pig.humanoid.EvaluateStateMachine==false,
    'Carried bodies must disable automatic humanoid collision updates before physics can re-enable torso collision')
for _,p in ipairs(pig.model:GetDescendants()) do if p:IsA('BasePart') then assert(not p.CanCollide) end end
eq(pig.root.Position,101.75,16.4,2048,'Carry pose must use the actual translated holder once')
holder.root.CFrame=frame(105,13,2048);holder.root.CFrame.LookVector=vector(0,0,1)
assert(carrying:carryEnemy(-1,1))
eq(pig.root.Position,105,16.4,2049.75,'Repeated carry updates must follow the same holder current position and facing')
local previousMove=pig.humanoid.lastMove
carrying:setReaction(-1,false);carrying:move(-1,1,0)
assert(pig.root.Anchored and pig.humanoid.PlatformStand and pig.humanoid.lastMove==previousMove,
    'Reaction expiry and movement must not unfreeze or move a carried body')
assert(not carrying:releaseEnemy(-1,2,{horizontal=26,vertical=16}),'A missing thrower cannot release a held body')
assert(not carrying:releaseEnemy(-1,1,{horizontal=0/0,vertical=16}),'Invalid throw tuning cannot mutate the hold')
assert(pig.root.Anchored and not pig.model.Torso.CanCollide and pig.model:GetAttribute('CarryMode')=='Carried'
    and holder.model:GetAttribute('CarryingEnemy')==-1,'Rejected throws must preserve held physics and attributes')
assert(carrying:releaseEnemy(-1,1,{horizontal=26,vertical=16}),'Throwing releases the same body with current validated holder direction')
assert(not pig.root.Anchored and pig.humanoid.PlatformStand and pig.model:GetAttribute('CarryMode')=='Thrown')
assert(pig.humanoid.EvaluateStateMachine==true,'Throw release must restore the original humanoid evaluation setting')
assert(pig.root.networkOwnerSet and pig.root.networkOwner==nil,'Unanchored throws must remain server owned')
assert(pig.model:GetAttribute('HeldBy')==nil and holder.model:GetAttribute('CarryingEnemy')==nil)
eq(pig.root.AssemblyLinearVelocity,0,16,26,'Throw direction must be captured from the current holder immediately')
assert(pig.model.Torso.CanCollide and pig.model.Head.CanCollide and not pig.root.CanCollide
    and not pig.model['Left Arm'].CanCollide,'Each target part must restore its own original collision value')
holder.root.CFrame=frame(500,40,2000);holder.root.CFrame.LookVector=vector(-1,0,0)
eq(pig.root.AssemblyLinearVelocity,0,16,26,'Later holder movement cannot retarget the accepted throw')
carrying:setReaction(-1,false)
assert(pig.humanoid.PlatformStand,'Thrown bodies remain physical until the domain ends their reaction')
assert(carrying:releaseEnemy(-1),'Ending throw restores autonomous body physics without another launch')
assert(pig.model:GetAttribute('CarryMode')==nil and not pig.humanoid.PlatformStand and pig.humanoid.AutoRotate)
eq(pig.root.AssemblyLinearVelocity,0,16,26,'Ending throw must preserve its actual current physical motion')
assert(pig.model==originalModel and pig.humanoid.Health==originalHP)
print('PASS enemy carry keeps identity and health, restores per-part collisions and launches once in current facing')

holder.root.CFrame=frame(100,13,2048);holder.root.CFrame.LookVector=vector(1,0,0)
pig.root.CFrame=frame(103,13,2048)
assert(carrying:carryEnemy(-1,1))
local oldHeldPosition=pig.root.Position
local oldHolder=holder
holder=actor(carrying,1,vector(300,13,2048));holder.root.CFrame.LookVector=vector(-1,0,0)
assert(not carrying:carryEnemy(-1,1),'Replacement hero models cannot inherit an old carry')
assert(not carrying:releaseEnemy(-1,1,{horizontal=26,vertical=16}),'A replacement hero cannot throw the predecessor held body')
assert(pig.root.Anchored and pig.model:GetAttribute('CarryMode')=='Carried','Rejected replacement throws leave the old carry unchanged')
assert(carrying:releaseEnemy(-1),'Dropping after replacement must use the already held body pose')
eq(pig.root.Position,oldHeldPosition.X,oldHeldPosition.Y,oldHeldPosition.Z,'Drop cannot teleport to a replacement hero')
assert(oldHolder.model:GetAttribute('CarryingEnemy')==nil and holder.model:GetAttribute('CarryingEnemy')==nil,
    'Release must clear the original holder reference without attaching the replacement')
assert(pig.humanoid.EvaluateStateMachine==true,'A normal drop restores the original enabled evaluation')
pig.root.CFrame=frame(303,13,2048)
pig.humanoid.EvaluateStateMachine=false
assert(carrying:carryEnemy(-1,1))
assert(carrying:releaseEnemy(-1) and pig.humanoid.EvaluateStateMachine==false,
    'A body whose evaluation was originally disabled must retain that setting after drop')
assert(carrying:carryEnemy(-1,1))
assert(carrying:releaseEnemy(-1,1,{horizontal=26,vertical=16}) and pig.humanoid.EvaluateStateMachine==false,
    'A throw must also preserve an originally disabled evaluation setting')
assert(carrying:releaseEnemy(-1) and pig.humanoid.EvaluateStateMachine==false)
pig.humanoid.EvaluateStateMachine=true
assert(carrying:carryEnemy(-1,1))
pig.humanoid.Health=0
assert(carrying:releaseEnemy(-1) and pig.humanoid.EvaluateStateMachine==true,
    'A dead carried body must regain its original evaluation when the domain forgets it')
pig.humanoid.Health=100
assert(carrying:carryEnemy(-1,1))
carrying:clearActors()
assert(next(carrying.enemyCarries)==nil and holder.model:GetAttribute('CarryingEnemy')==nil,
    'New-run cleanup clears original carry attributes and bookkeeping before destroying actors')
assert(pig.humanoid.EvaluateStateMachine==true,'Cleanup must restore carried evaluation before destroying its body')
assert(default.folder.Parent==workspace and route.folder.Parent==workspace,'Carry cleanup preserves other group worlds')
print('PASS carry drops and new-run cleanup retain old body references without crossing group or actor generations')

local weapons=World.new(Base,{FallY=-20,Level=source(LevelSource),Enemy={speed=9},WalkSpeed=12},
    {name='ClubWorld',offset={x=100,y=10,z=2560}})
assert(type(weapons.clubItem)=='function','Walker clubs need a separate group-local ground-item presentation')
weapons:clubItem('walker-leg',{x=3,y=.3,z=0})
default:clubItem('walker-leg',{x=3,y=.3,z=0})
local groundClub=weapons.clubItemFolder:FindFirstChild('ClubItem_walker-leg')
local otherClub=default.clubItemFolder:FindFirstChild('ClubItem_walker-leg')
assert(groundClub and otherClub and groundClub~=otherClub)
eq(groundClub.PrimaryPart.Position,103,10.3,2560,'A ground club must use its own world offset exactly once')
assert(groundClub:GetAttribute('ClubId')=='walker-leg' and groundClub:GetAttribute('ItemKind')=='WalkerClub')
for _,p in ipairs(groundClub:GetDescendants()) do
    assert(not p:IsA('Humanoid'),'An item model must not create an enemy Humanoid')
    if p:IsA('BasePart') then assert(not p.CanCollide and not p.CanQuery and not p.CanTouch) end
end
assert(weapons.actors['walker-leg']==nil,'Ground weapons remain outside combat targets')
weapons:clubItem('walker-leg',{x=4,y=.3,z=1})
assert(weapons.clubItemFolder:FindFirstChild('ClubItem_walker-leg')==groundClub,'Updating one ground weapon cannot duplicate its model')
eq(groundClub.PrimaryPart.Position,104,10.3,2561)
print('PASS ground clubs are independent noncolliding original item models with one group translation')

local wielder=actor(weapons,1,vector(100,13,2560));wielder.root.CFrame.LookVector=vector(1,0,0)
assert(weapons:canPickupClub(1,{x=-2,y=.3,z=0},4.5,3),'Ground club pickup must not require pre-facing the object')
assert(not weapons:canPickupClub(1,{x=-4,y=.3,z=0},4.5,3),'Pickup checks full spatial distance to the item')
assert(not weapons:canPickupClub(1,{x=0,y=-.01,z=0},4.5,3),'Pickup has an independent vertical limit')
wielder.humanoid.FloorMaterial=enum.Material.Air
assert(not weapons:canPickupClub(1,{x=2,y=.3,z=0},4.5,3),'Airborne heroes cannot take a grounded club')
wielder.humanoid.FloorMaterial=enum.Material.Slate
for _,state in ipairs({'Anchored','Reaction','Dead'}) do
    wielder.root.Anchored=state=='Anchored';wielder.humanoid.PlatformStand=state=='Reaction'
    wielder.humanoid.Health=state=='Dead' and 0 or 100
    assert(not weapons:canPickupClub(1,{x=2,y=.3,z=0},4.5,3),'Held, reacting and dead bodies cannot pick up a club')
end
wielder.root.Anchored=false;wielder.humanoid.PlatformStand=false;wielder.humanoid.Health=100
wielder.root.CFrame=frame(150,13,2560)
assert(not weapons:canPickupClub(1,{x=52,y=.3,z=0},4.5,3),'FloorMaterial without an actual support ray cannot permit pickup over a gap')
wielder.root.CFrame=frame(100,13,2560)
oldRaycast=workspace.Raycast
function workspace:Raycast(origin,direction,params)
    if math.abs(direction.X)>0 then return {Instance=weapons.gates[1].beam,Normal=vector(-1,0,0)} end
    return oldRaycast(self,origin,direction,params)
end
assert(not weapons:canPickupClub(1,{x=2,y=.3,z=0},4.5,3),'Collidable own-world geometry blocks a club pickup')
workspace.Raycast=oldRaycast
assert(weapons:canPickupClub(1,{x=2,y=.3,z=0},4.5,3))
print('PASS club pickup validates live grounded current bodies, full reach and geometry without mandatory pre-facing')

assert(weapons:equipClub('walker-leg',1),'Equipping must weld original art to the current hero body')
local equipment=wielder.model:FindFirstChild('EquippedClub_walker-leg')
assert(equipment and groundClub.Parent~=nil,'Equip is independent of removal of its matching ground model')
assert(wielder.model:GetAttribute('EquippedClub')=='walker-leg' and equipment:GetAttribute('ClubId')=='walker-leg')
local weldCount=0
for _,p in ipairs(equipment:GetDescendants()) do
    assert(not p:IsA('Humanoid'))
    if p:IsA('BasePart') then assert(p.Massless and not p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch) end
    if p:IsA('WeldConstraint') then assert(p.Part0==wielder.model['Right Arm']);weldCount+=1 end
end
assert(weldCount>0,'All equipped geometry must move with the same actor right arm')
assert(weapons:equipClub('walker-leg',1) and wielder.model:FindFirstChild('EquippedClub_walker-leg')==equipment,
    'Repeating equip on the same current actor must not duplicate art')
assert(not weapons:equipClub('other-leg',1),'One hero cannot visually equip two different clubs')
weapons:clubItem('walker-leg',nil)
assert(groundClub.destroyed and equipment.Parent==wielder.model,'Ground-item removal cannot destroy equipped art')
local healthBefore=wielder.humanoid.Health
assert(weapons:clubSwing('walker-leg',1) and equipment:GetAttribute('Swinging')==true)
assert(not weapons:clubSwing('walker-leg',2),'Only the actual equipped body can display its swing')
assert(wielder.humanoid.Health==healthBefore and weapons.actors['walker-leg']==nil,'Visual swing cannot create damage or an actor')
weapons:updatePresentation(nil,.1);weapons:updatePresentation(nil,.1);weapons:updatePresentation(nil,.1);weapons:updatePresentation(nil,.1)
assert(equipment:GetAttribute('Swinging')~=true and wielder.model:GetAttribute('ClubSwing')==nil,'Swing pose flags expire without changing equipment')
local originalWielder=wielder
wielder=actor(weapons,1,vector(300,13,2560))
assert(not weapons:equipClub('walker-leg',1) and not weapons:clubSwing('walker-leg',1),
    'A replacement body cannot inherit the old actor equipment or swing')
originalWielder.poseMotors={['Right Shoulder']={joint={C0='weapon-pose'},base='rest-pose'}}
assert(weapons:unequipClub('walker-leg') and equipment.destroyed)
assert(originalWielder.model:GetAttribute('EquippedClub')==nil and originalWielder.model:GetAttribute('ClubSwing')==nil)
assert(originalWielder.poseMotors['Right Shoulder'].joint.C0=='rest-pose','Unequip restores the old owner weapon arm pose')
assert(wielder.model:GetAttribute('EquippedClub')==nil,'Unequip must clean the saved old-owner reference, never the replacement')
weapons:clubItem('walker-leg',{x=200,y=.3,z=0})
assert(weapons:equipClub('walker-leg',1),'An explicitly dropped club ID can be picked up again by a current body')
local newEquipment=wielder.model:FindFirstChild('EquippedClub_walker-leg')
assert(newEquipment and newEquipment~=equipment)
wielder.model:SetAttribute('CarryingEnemy',-5)
wielder.poseMotors={['Right Shoulder']={joint={C0='pig-carry-pose'},base='rest-pose'}}
assert(weapons:unequipClub('walker-leg'))
assert(wielder.poseMotors['Right Shoulder'].joint.C0=='pig-carry-pose','Weapon release must not overwrite the higher-priority Pig carry pose')
wielder.model:SetAttribute('CarryingEnemy',nil)
assert(weapons:equipClub('walker-leg',1))
newEquipment=wielder.model:FindFirstChild('EquippedClub_walker-leg')
weapons:clearActors()
assert(newEquipment.destroyed and wielder.model:GetAttribute('EquippedClub')==nil
    and next(weapons.equippedClubs)==nil and #weapons.clubItemFolder:GetChildren()==0,
    'A new run clears this world ground items, equipment, pose flags and saved owners')
assert(otherClub.Parent~=nil,'Weapon reset must preserve another group copy of the same logical item')
default:clubItem('walker-leg',nil)
print('PASS equipped clubs weld to one original owner, have visual-only finite swings and clean old bodies on drop/reset')
