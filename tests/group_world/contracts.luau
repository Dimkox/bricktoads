-- These doubles exercise real coordinate consumers; engine physics is tested in Studio.
local Vec={}
Vec.__index=function(self,key)
    if key=='Magnitude' then return math.sqrt(self.X*self.X+self.Y*self.Y+self.Z*self.Z) end
    if key=='Unit' then
        local length=math.sqrt(self.X*self.X+self.Y*self.Y+self.Z*self.Z)
        return setmetatable({X=self.X/length,Y=self.Y/length,Z=self.Z/length},Vec)
    end
    return Vec[key]
end
function Vec.__add(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},Vec) end
function Vec.__sub(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},Vec) end
function Vec.__mul(a,b)
    if type(a)=='number' then a,b=b,a end
    return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},Vec)
end
function Vec.__unm(a) return setmetatable({X=-a.X,Y=-a.Y,Z=-a.Z},Vec) end
local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},Vec) end
local Frame={}; Frame.__index=Frame
function Frame.__mul(a,b)
    return setmetatable({Position=a.Position+b.Position,rotationX=(a.rotationX or 0)+(b.rotationX or 0),
        rotationY=(a.rotationY or 0)+(b.rotationY or 0),rotationZ=(a.rotationZ or 0)+(b.rotationZ or 0),
        RightVector=a.RightVector or vector(1,0,0),LookVector=a.LookVector or vector(0,0,-1)},Frame)
end
function Frame.__add(a,b) return setmetatable({Position=a.Position+b,
    RightVector=a.RightVector or vector(1,0,0),LookVector=a.LookVector or vector(0,0,-1)},Frame) end
function Frame:Lerp(other,alpha) return other end -- Pose selection only, not engine interpolation.
local function frame(x,y,z)
    return setmetatable({Position=type(x)=='table' and x or vector(x,y,z),
        RightVector=vector(1,0,0),LookVector=vector(0,0,-1)},Frame)
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
        -- Opt-in reproduction of the live assembly ownership reset: the basic
        -- rig was pinned before a later physical art part joined its assembly.
        local physicalAddition=self.ClassName=='Part'
        if self.ClassName=='Model' then
            for _,p in ipairs(self:GetDescendants()) do if p:IsA('BasePart') then physicalAddition=true;break end end
        end
        if value and physicalAddition then
            local ancestor,root=value,nil
            while ancestor do
                if ancestor.ClassName=='Model' then root=ancestor:FindFirstChild('HumanoidRootPart') end
                if root then break end
                ancestor=ancestor.Parent
            end
            if root and root.simulateAssemblyOwnershipReset then
                root.networkOwnershipAuto=true;root.networkOwner=root.nearbyAutomaticOwner
                root.assemblyOwnershipResets=(root.assemblyOwnershipResets or 0)+1
            end
        end
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
function Node:CanSetNetworkOwnership() return not self.Anchored and not self.networkOwnershipDenied,'Ownership unavailable in fixture' end
function Node:SetNetworkOwner(owner)
    self.networkOwner=owner;self.networkOwnerSet=true;self.networkOwnershipAuto=false
    self.networkOwnershipPins=(self.networkOwnershipPins or 0)+1
end
function Node:GetNetworkOwner() return self.networkOwner end
function Node:GetNetworkOwnershipAuto() return self.networkOwnershipAuto~=false end
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
    OverlapParams={new=function() return {} end},
    Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end},Enum=enum,
    Instance={new=function(class) return node(class) end},Vector3={new=vector},
    CFrame={new=frame,Angles=function(x,y,z)
        local result=frame();result.rotationX,result.rotationY,result.rotationZ=x,y,z;return result
    end,lookAt=function(p) return frame(p) end},
    UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}}, {__index=getfenv()})
local function source(text)
    local loader=assert(loadstring(text)); setfenv(loader,env); return loader()
end
function workspace:GetPartBoundsInRadius() return {} end
function workspace:Spherecast(origin,radius,direction,params)
    local hit=self:Raycast(origin,direction,params)
    if hit and hit.Position then hit.Distance=(hit.Position-origin).Magnitude end
    return hit
end
local World,Camera=source(WorldSource),source(CameraSource)
source(DragonWorldSource)(World)
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
    local root=node('Part','HumanoidRootPart',model); root.CFrame=frame(position); root.Size=vector(2,2,1)
    for _,name in ipairs({'Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg'}) do
        local limb=node('Part',name,model); limb.CFrame=frame(position)
    end
    root.Anchored=false; root.AssemblyLinearVelocity=vector()
    local a={model=model,root=root,humanoid={Health=100,PlatformStand=false,FloorMaterial=enum.Material.Slate,
        Jump=false,JumpPower=42,UseJumpPower=true,AutoRotate=true,WalkSpeed=12,EvaluateStateMachine=true},cue=0}
    a.humanoid.MoveDirection=vector()
    function a.humanoid:Move(direction) self.lastMove=direction;self.MoveDirection=direction end
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

local ownershipBase=table.clone(Base)
function ownershipBase.spawn(world,id,actorId,point)
    local ok=Base.spawn(world,id,actorId,point)
    local root=world.actors[id].root
    root.simulateAssemblyOwnershipReset=true;root.nearbyAutomaticOwner='nearby-player-2'
    root:SetNetworkOwner(nil) -- Real BaseWorld already pins this basic rig.
    return ok
end
local ownershipWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50,Enemy={speed=9}},
    {name='CompletedEnemyOwnership',offset={x=100,y=10,z=9216}})
for i,kind in ipairs({'Pig','Walker','Dragon','Boss'}) do
    local id=-20-i
    assert(ownershipWorld:spawnEnemy(id,kind,{x=-30+i*5,y=3,z=0}))
    local root=ownershipWorld.actors[id].root
    assert(root.assemblyOwnershipResets>0,'The complete species must actually invalidate the basic-rig ownership pin in this fixture')
    assert(root:GetNetworkOwner()==nil and not root:GetNetworkOwnershipAuto(),
        'Completed '..kind..' assembly must be pinned to the server after all physical art is attached')
end
local claimed=ownershipWorld.actors[-21]
local claimedModel,claimedRoot,claimedHP=claimed.model,claimed.root,claimed.humanoid.Health
claimedRoot.networkOwnershipAuto=true;claimedRoot.networkOwner='nearby-player-2'
ownershipWorld:enemyIdentity(-21,'ownership-run:enemy:1:-21','Player2')
assert(claimedRoot:GetNetworkOwner()==nil and not claimedRoot:GetNetworkOwnershipAuto(),
    'Claim identity must retain server physics rather than transfer the assembly to the logical role owner')
assert(ownershipWorld.actors[-21].model==claimedModel and ownershipWorld.actors[-21].root==claimedRoot
    and claimed.humanoid.Health==claimedHP and claimedModel:GetAttribute('ControlledByPlayer')==true
    and claimedModel:GetAttribute('ActorId')=='ownership-run:enemy:1:-21','Ownership correction cannot replace or heal the claimed body')
local ownershipHero=actor(ownershipWorld,1,claimedRoot.Position-vector(3,0,0))
ownershipHero.root.CFrame.LookVector=vector(1,0,0)
assert(ownershipWorld:carryEnemy(-21,1))
claimedRoot.networkOwnershipAuto=true;claimedRoot.networkOwner='nearby-player-2'
assert(ownershipWorld:releaseEnemy(-21))
assert(claimedRoot:GetNetworkOwner()==nil and not claimedRoot:GetNetworkOwnershipAuto()
    and claimed.model==claimedModel and claimed.humanoid.Health==claimedHP,'Unanchoring the carried same body must restore server authority')
local ownedDragon=ownershipWorld.actors[-23];ownedDragon.root.AssemblyMass=12
ownedDragon.root.networkOwnershipAuto=true;ownedDragon.root.networkOwner='nearby-player-2'
workspace.Gravity=196.2
assert(ownershipWorld:dragonMotion(-23,1,0,4.5,10))
assert(ownedDragon.root:GetNetworkOwner()==nil and not ownedDragon.root:GetNetworkOwnershipAuto(),
    'Dragon flight retains server authority on its existing completed body')
ownershipWorld:stopDragon(-23)
claimedRoot.networkOwnershipDenied=true
local canClaim,claimError=pcall(function() ownershipWorld:enemyIdentity(-21,'unchanged','Player2') end)
assert(not canClaim and string.find(tostring(claimError),'Ownership unavailable',1,true),
    'A failed server-ownership assignment must fail explicitly instead of silently accepting a client-owned body')
claimedRoot.networkOwnershipDenied=nil
ownershipWorld:clearActors()
print('PASS complete enemy assembly and same-body claim, carry and Dragon transitions retain checked server physics ownership')

local clubOwnershipWorld=World.new(Base,{FallY=-20,WalkSpeed=16},{name='ClubOwnership'})
local clubOwner=actor(clubOwnershipWorld,1,vector(0,3,0))
clubOwner.model:SetAttribute('ActorId','club-owner-body')
clubOwner.root.simulateAssemblyOwnershipReset=true;clubOwner.root.nearbyAutomaticOwner='nearby-player-1'
clubOwner.root:SetNetworkOwner(nil)
local ownerRoot,ownerModel,ownerHP=clubOwner.root,clubOwner.model,clubOwner.humanoid.Health
assert(clubOwnershipWorld:equipClub('ownership-club',1))
assert(ownerRoot.assemblyOwnershipResets>0,'Attaching the actual nested club model must invalidate the old pin in this fixture')
assert(ownerRoot:GetNetworkOwner()==nil and not ownerRoot:GetNetworkOwnershipAuto(),
    'Equipped nested weapon must pin the same hero assembly after its parts join')
assert(clubOwner.model==ownerModel and clubOwner.root==ownerRoot and clubOwner.humanoid.Health==ownerHP
    and ownerModel:GetAttribute('ActorId')=='club-owner-body','Equipping cannot replace or heal the hero')
ownerRoot.networkOwnershipAuto=true;ownerRoot.networkOwner='nearby-player-1'
assert(clubOwnershipWorld:unequipClub('ownership-club'))
assert(ownerRoot:GetNetworkOwner()==nil and not ownerRoot:GetNetworkOwnershipAuto(),
    'Removing a weapon must restore explicit server authority after its assembly change')
assert(clubOwnershipWorld:equipClub('old-owner-club',1))
local replacementOwner=actor(clubOwnershipWorld,1,vector(20,3,0))
replacementOwner.root:SetNetworkOwner('replacement-owner')
local replacementPins=replacementOwner.root.networkOwnershipPins
ownerRoot.networkOwnershipAuto=true;ownerRoot.networkOwner='nearby-player-1'
assert(clubOwnershipWorld:unequipClub('old-owner-club'))
assert(ownerRoot:GetNetworkOwner()==nil and not ownerRoot:GetNetworkOwnershipAuto()
    and replacementOwner.root:GetNetworkOwner()=='replacement-owner'
    and replacementOwner.root.networkOwnershipPins==replacementPins,'Unequip must pin its saved old owner and never the replacement')
replacementOwner.root.Anchored=true
assert(clubOwnershipWorld:equipClub('anchored-club',1) and clubOwnershipWorld:unequipClub('anchored-club'))
assert(replacementOwner.root.Anchored and replacementOwner.root.networkOwnershipPins==replacementPins,
    'Anchored equipment owners must skip ownership assignment and preserve their physical flags')
assert(clubOwner.humanoid.Health==ownerHP)
ownerModel:Destroy();clubOwnershipWorld:clearActors()
print('PASS weapon attachment and removal restore server ownership on the saved same body and skip anchored replacements')

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

-- The real rotated 2x2x1 rig can remain on the floor after its root centre
-- crosses an edge. Use the ordinary geometric Raycast double, not an always-hit stub.
local footprintWorld=World.new(Base,{FallY=-20,Level=source(LevelSource)},
    {name='JumpFootprintRoute',offset={x=400,y=20,z=7680}})
footprintWorld.geometry:ClearAllChildren()
local footprintFloor=node('Part','FootprintSupport',footprintWorld.geometry)
footprintFloor.Size=vector(44,2,12); footprintFloor.CFrame=frame(vector(26,-1,0)+footprintWorld.offset)
footprintFloor.CanCollide=true; footprintFloor:SetAttribute('SurfaceId','footprint-support')
local function edgeActor(x,z,right,look)
    local a=standing(footprintWorld,1)
    a.root.CFrame=frame(vector(x,3,z or -.637)+footprintWorld.offset)
    a.root.CFrame.RightVector=right or vector(0,0,1)
    a.root.CFrame.LookVector=look or vector(1,0,0)
    a.routeJumpSupport={consumed=false,groundedAt=0,groundedY=a.root.Position.Y}
    serverTime=1 -- The old centre-supported observation is beyond the existing grace.
    return a
end
local overhang=edgeActor(48.385)
assert(not workspace:Raycast(overhang.root.Position,vector(0,-3.4,0),footprintWorld.ray),
    'The observed root centre must genuinely miss the box floor ending at local X48')
assert(workspace:Raycast(overhang.root.Position-vector(.5,0,0),vector(0,-3.4,0),footprintWorld.ray),
    'The real face+X rig still has its half-depth over the same group-local floor')
footprintWorld:jump(1)
assert(overhang.humanoid.Jump,'Standing rotated body at X48.385 must jump after centre support history expires')
eq(overhang.root.AssemblyLinearVelocity,0,42,0,'Footprint support must use the unchanged configured jump power')
for _,case in ipairs({
    {x=48.5001,accept=false},
    {x=48.385,right=vector(0,0,-1),look=vector(-1,0,0),accept=true},
    {x=48.9,right=vector(1,0,0),look=vector(0,0,-1),accept=true},
    {x=49.0001,right=vector(1,0,0),look=vector(0,0,-1),accept=false},
    {x=48.385,z=6.8,accept=true}, -- Only the physical corner overlaps this support.
    {x=48.385,z=7.0001,accept=false},
}) do
    local a=edgeActor(case.x,case.z,case.right,case.look)
    footprintWorld:jump(1)
    assert(a.humanoid.Jump==case.accept,'Support must stay within the rotated actual-size footprint, including corners')
end
local narrow=edgeActor(48.385); narrow.root.Size=vector(2,2,.4)
footprintWorld:jump(1)
assert(not narrow.humanoid.Jump,'Support must use this actual root depth, not a fixed or cosmetic extent')
print('PASS jump support follows actual rotated rig footprint and corners without extending beyond its box')

for _,blocked in ipairs({'Air','Upward','Consumed','Hazard','NoSurface','NoFloor','TooHigh'}) do
    local a=edgeActor(48.385)
    if blocked=='Air' then a.humanoid.FloorMaterial=enum.Material.Air
    elseif blocked=='Upward' then a.root.AssemblyLinearVelocity=vector(0,2,0)
    elseif blocked=='Consumed' then a.routeJumpSupport.consumed=true
    elseif blocked=='Hazard' then footprintFloor:SetAttribute('Hazard',true)
    elseif blocked=='NoSurface' then footprintFloor:SetAttribute('SurfaceId',nil)
    elseif blocked=='NoFloor' then footprintFloor.CanCollide=false
    elseif blocked=='TooHigh' then a.root.CFrame.Position=a.root.Position+vector(0,1,0) end
    footprintWorld:jump(1)
    assert(not a.humanoid.Jump,'Footprint rays must preserve the existing '..blocked..' rejection')
    footprintFloor.CanCollide=true; footprintFloor:SetAttribute('Hazard',nil)
    footprintFloor:SetAttribute('SurfaceId','footprint-support')
end
local normalRaycast=workspace.Raycast
function workspace:Raycast(origin,direction,params)
    local hit=normalRaycast(self,origin,direction,params)
    if hit and hit.Instance==footprintFloor then hit.Normal=vector(0,.94,0) end
    return hit
end
local sloped=edgeActor(48.385); footprintWorld:jump(1)
assert(not sloped.humanoid.Jump,'Footprint support must preserve the upward-facing normal gate')
workspace.Raycast=normalRaycast
footprintWorld:clearActors()
print('PASS footprint support preserves physical floor, upward-flight, surface, hazard and consumed-jump guards')

-- Trusted route fixtures exercise the physical boundary independently of the
-- pure section/seed generator: the second route moves the actual aqueduct gap.
local canonicalRebuild=source(LevelSource)
local mapA,mapB=source(LevelSource),source(LevelSource)
mapA.variation={version=1,seed=111,sectionChoices={1,1,1,1,1,1}}
mapA.zones[1].obstacles={{kind='StoneCover',x=-50,y=1.5,z=-20,w=8,h=3,d=4}}
mapB.variation={version=1,seed=222,sectionChoices={2,2,1,1,1,1}}
mapB.zones[1].platforms[1].z=4;mapB.zones[1].platforms[1].d=56
mapB.zones[2].platforms[1].x=29;mapB.zones[2].platforms[1].w=50
mapB.zones[2].platforms[2].x=91.5;mapB.zones[2].platforms[2].w=65
mapB.zones[2].gaps={{minX=54,maxX=59,minZ=-19,maxZ=19}}
mapB.zones[3].obstacles={{kind='StoneCover',x=170,y=1.5,z=20,w=8,h=3,d=4}}
local sharedRebuildConfig={FallY=-20,JumpPower=50,Level=canonicalRebuild}
local rebuilding=World.new(Base,sharedRebuildConfig,{name='RebuildRouteA',offset={x=100,y=10,z=10240}})
local untouched=World.new(Base,sharedRebuildConfig,{name='RebuildRouteB',offset={x=100,y=10,z=10752}})
local neighbourFloor=untouched.allFloors[1]
assert(type(rebuilding.rebuildLevel)=='function','A new run needs an explicit empty-world level rebuild boundary')
rebuilding:clearActors();assert(rebuilding:rebuildLevel(mapA))
assert(rebuilding.config.Level==mapA and sharedRebuildConfig.Level==canonicalRebuild and untouched.config.Level==canonicalRebuild)
assert(rebuilding.folder:GetAttribute('LayoutSeed')==111 and rebuilding.folder:GetAttribute('LayoutVersion')==1)
assert(rebuilding:groundPosition({x=50,y=3,z=0})==nil and rebuilding:groundPosition({x=56,y=3,z=0}),
    'The first route must preserve its own actual gap instead of a visual-only change')
local oldFloor,oldCover=rebuilding.allFloors[1],rebuilding.geometry:FindFirstChild('StoneCover')
assert(oldCover and oldCover.CanCollide and oldCover.Anchored and oldCover:GetAttribute('SurfaceId')=='Floodgate')
assert(not table.find(rebuilding.allFloors,oldCover),'Cover is collision geometry, not a new respawn platform or combat actor')
rebuilding:progress(7,false);rebuilding:stage('Exit')
local liveLayoutBody=actor(rebuilding,1,vector(35,13,10240))
local oldGate,oldOrigin=rebuilding.gates[1],rebuilding.origins[1]
local accepted,reason=rebuilding:rebuildLevel(mapB)
assert(accepted==false and reason=='ACTORS_PRESENT','An existing body must reject a level rebuild')
assert(rebuilding.config.Level==mapA and rebuilding.allFloors[1]==oldFloor and not oldFloor.destroyed
    and rebuilding.geometry:FindFirstChild('StoneCover')==oldCover and rebuilding.gates[1]==oldGate
    and not rebuilding.exitGate.beam.CanCollide and rebuilding.origins[1]==oldOrigin
    and rebuilding.folder:GetAttribute('LayoutSeed')==111 and rebuilding.actors[1]==liveLayoutBody,
    'Rejection must precede every config, geometry, gate, origin, body and seed mutation')
rebuilding:healingFly('old-layout-fly',{x=-50,y=4.5,z=0});rebuilding:clubItem('old-layout-club',{x=-50,y=1.2,z=0})
rebuilding:clearActors()
rebuilding.lastSupport[1]='stale-layout';rebuilding.deathReason[1]='Fall';rebuilding.origins[1]=vector(777,888,999);rebuilding.blocked=true
assert(rebuilding:rebuildLevel(mapB))
assert(oldFloor.destroyed and oldCover.destroyed and liveLayoutBody.model.destroyed)
assert(rebuilding.config.Level==mapB and #rebuilding.floors==1 and rebuilding.gates[1].beam.CanCollide
    and rebuilding.exitGate.beam.CanCollide and rebuilding.stageName=='Approach' and not rebuilding.blocked)
assert(next(rebuilding.lastSupport)==nil and next(rebuilding.deathReason)==nil and next(rebuilding.actors)==nil)
assert(#rebuilding.healingFlyFolder:GetChildren()==0 and #rebuilding.clubItemFolder:GetChildren()==0)
assert(rebuilding.folder:GetAttribute('LayoutSeed')==222 and rebuilding.folder:GetAttribute('LayoutVersion')==1)
eq(rebuilding.origins[1],35,13,10237,'New safe origins follow the first support centre and one group offset')
eq(rebuilding.allFloors[2].Position,129,9,10240,'Rebuilt geometry receives its world translation exactly once')
assert(rebuilding:groundPosition({x=50,y=3,z=0}) and rebuilding:groundPosition({x=56,y=3,z=0})==nil,
    'The second map must replace the collidable crossing rather than retain the old floor')
assert(not neighbourFloor.destroyed and untouched.config.Level==canonicalRebuild and untouched.allFloors[1]==neighbourFloor)
print('PASS empty-world rebuild replaces actual route geometry and resets scoped gates, origins, support and layout metadata')

local newCover=rebuilding.geometry:FindFirstChild('StoneCover')
eq(newCover.Position,270,11.5,10260,'Stone cover uses domain-local layout coordinates plus the group offset once')
eq(newCover.Size,8,3,4)
assert(newCover.CanCollide and newCover:GetAttribute('SurfaceId')=='Courtyard' and newCover:GetAttribute('ZoneIndex')==3)
local coverGround=rebuilding:groundPosition({x=170,y=6,z=20})
assert(coverGround and coverGround.x==170 and coverGround.z==20 and math.abs(coverGround.y-4.2)<.00001)
rebuilding:progress(3,false)
local coverHero=actor(rebuilding,1,vector(270,16,10260));coverHero.humanoid.JumpPower=50
rebuilding:hazard(1);assert(rebuilding.lastSupport[1]=='Courtyard')
rebuilding:jump(1);assert(coverHero.humanoid.Jump and coverHero.root.AssemblyLinearVelocity.Y==50,
    'A supplied cover must retain ordinary physical support and the existing jump rule')
local coverRespawn=actualBase.findSafe({floors=rebuilding.floors,actors={},origins={[1]=coverHero.root.Position},
    deathReason={},lastSupport={[1]=rebuilding.lastSupport[1]},isSafe=function() return true end},1)
assert(coverRespawn and coverRespawn.surface:GetAttribute('SurfaceId')=='Courtyard',
    'Standing on cover must not invent a different respawn surface from its district support')
local keptFloor=rebuilding.allFloors[1]
untouched:clearActors();assert(untouched:rebuildLevel(mapA))
assert(rebuilding.allFloors[1]==keptFloor and not keptFloor.destroyed and rebuilding.config.Level==mapB)
eq(untouched.geometry:FindFirstChild('StoneCover').Position,50,11.5,10732,'Neighbouring layout keeps its own one-time offset')
rebuilding:clearActors();untouched:clearActors()
print('PASS original cover stays a scoped flat collider with matching support identity and independent-group rebuilds')

Base.move=actualBase.move; Base.setReaction=actualBase.setReaction
Base.hold=actualBase.hold; Base.kill=actualBase.kill
local locomotionWorld=World.new(Base,{FallY=-20,WalkSpeed=16,JumpPower=50,MoveTimeout=.35,Enemy={speed=9},
    Movement={heroRunSpeed=24,enemyRunSpeed=16,runThresholdRatio=.75},Level=source(LevelSource)},
    {name='LocomotionRoute',offset={x=100,y=10,z=8192}})
local function freshRunner(id)
    local old=locomotionWorld.actors[id]
    if old then old.model:Destroy() end
    local a=actor(locomotionWorld,id,vector(-40,3,0)+locomotionWorld.offset)
    a.humanoid.JumpPower=50
    a.root.CFrame.LookVector=vector(1,0,0)
    return a
end
serverTime=100
local runner=freshRunner(1)
locomotionWorld:move(1,1,0,true)
assert(runner.humanoid.WalkSpeed==24,'The server run cap must survive the DragonWorld move decorator')
assert(not locomotionWorld:isRunning(1) and locomotionWorld:movementMode(1)=='Idle',
    'A run flag while stationary or pushing a wall is not actual running')
runner.root.AssemblyLinearVelocity=vector(17.99,0,0)
assert(not locomotionWorld:isRunning(1),'Below75% of hero run speed cannot qualify')
runner.root.AssemblyLinearVelocity=vector(18,0,0)
assert(locomotionWorld:isRunning(1) and locomotionWorld:movementMode(1)=='Run')
runner.root.AssemblyLinearVelocity=vector(-24,0,0)
assert(not locomotionWorld:isRunning(1),'Velocity opposite the requested heading cannot qualify')
locomotionWorld:move(1,1,0,false);runner.root.AssemblyLinearVelocity=vector(32,0,0)
assert(runner.humanoid.WalkSpeed==16 and not locomotionWorld:isRunning(1),
    'Knockback speed alone must not become a run request')
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
runner.root.CFrame=frame(vector(50,3,0)+locomotionWorld.offset)
assert(not locomotionWorld:isRunning(1),'A stale floor report over a real route gap cannot qualify')
runner.root.CFrame=frame(vector(-40,3,0)+locomotionWorld.offset)
for _,block in ipairs({'Air','Held','Reaction','Carrying','Flight','Boss'}) do
    runner.humanoid.FloorMaterial=block=='Air' and enum.Material.Air or enum.Material.Slate
    runner.root.Anchored=block=='Held';runner.humanoid.PlatformStand=block=='Reaction'
    runner.model:SetAttribute('CarryingEnemy',block=='Carrying' and -1 or nil)
    runner.model:SetAttribute('DragonFlight',block=='Flight' and true or nil)
    locomotionWorld.enemyKinds[1]=block=='Boss' and 'Boss' or nil
    assert(not locomotionWorld:isRunning(1),'Blocked '..block..' cannot qualify as ground run')
end
runner.humanoid.FloorMaterial=enum.Material.Slate;runner.root.Anchored=false;runner.humanoid.PlatformStand=false
runner.model:SetAttribute('CarryingEnemy',nil);runner.model:SetAttribute('DragonFlight',nil);locomotionWorld.enemyKinds[1]=nil
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
serverTime=100.35
assert(not locomotionWorld:isRunning(1),'Missing movement heartbeat expires at the existing timeout')
locomotionWorld:move(1,0,0,false)
eq(runner.root.AssemblyLinearVelocity,24,0,0,'Stopping voluntary movement must not erase a physical impulse')
assert(not locomotionWorld:isRunning(1) and runner.humanoid.WalkSpeed==16)
locomotionWorld:move(1,1,0,true);locomotionWorld:setReaction(1,true);locomotionWorld:setReaction(1,false)
assert(not locomotionWorld:isRunning(1) and runner.humanoid.WalkSpeed==16 and runner.humanoid.MoveDirection.Magnitude==0,
    'Recovery cannot resume an old run or voluntary movement')
print('PASS server run requires bounded intent, actual heading velocity, valid physical support and current lifecycle')

runner=freshRunner(1);serverTime=101
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
locomotionWorld:jump(1)
local runTakeoff=runner.root.AssemblyLinearVelocity
eq(runTakeoff,24,50,0,'Run jump retains real takeoff speed and the same vertical jump power')
runner.humanoid.FloorMaterial=enum.Material.Air
runner.root.CFrame=frame(vector(-38,5,0)+locomotionWorld.offset)
locomotionWorld:move(1,0,1,false)
assert(runner.humanoid.WalkSpeed==24 and locomotionWorld:movementMode(1)=='Air' and not locomotionWorld:isRunning(1))
locomotionWorld:move(1,0,0,false);locomotionWorld:move(1,-1,0,false)
assert(runner.humanoid.WalkSpeed==24,'Release and steering retain the accepted run-jump air-control cap')
runner.root.AssemblyLinearVelocity=vector(37,8,-4);locomotionWorld:move(1,1,0,true)
eq(runner.root.AssemblyLinearVelocity,37,8,-4,'Air control must not overwrite actual external impulses')
locomotionWorld:jump(1)
eq(runner.root.AssemblyLinearVelocity,37,8,-4,'Running does not grant another jump in flight')
locomotionWorld:hazard(1)
runner.humanoid.FloorMaterial=enum.Material.Slate;runner.root.CFrame=frame(vector(-38,3,0)+locomotionWorld.offset)
runner.root.AssemblyLinearVelocity=vector();locomotionWorld:hazard(1);locomotionWorld:move(1,1,0,false)
assert(runner.humanoid.WalkSpeed==16,'Only an actual landing releases the frozen air-control cap')
runner=freshRunner(1);locomotionWorld:move(1,1,0,false);runner.root.AssemblyLinearVelocity=vector(16,0,0)
locomotionWorld:jump(1);local walkTakeoff=runner.root.AssemblyLinearVelocity
assert(runTakeoff.X>walkTakeoff.X and runTakeoff.Y==walkTakeoff.Y,'Longer run-jump range comes from real horizontal speed')
runner.humanoid.FloorMaterial=enum.Material.Air;runner.root.CFrame=frame(vector(-38,5,0)+locomotionWorld.offset)
locomotionWorld:move(1,1,0,true)
assert(runner.humanoid.WalkSpeed==16,'A walking jump cannot promote its air-control cap to run in midair')
print('PASS jump freezes real walk or run air cap, preserves steering and impulses, and prevents midair promotion')

runner=freshRunner(1);locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
local oldRunner=runner
runner=actor(locomotionWorld,1,vector(-40,3,0)+locomotionWorld.offset)
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
locomotionWorld:resetLocomotion(1,oldRunner)
assert(oldRunner.humanoid.MoveDirection.Magnitude==0 and oldRunner.humanoid.WalkSpeed==16
    and locomotionWorld:isRunning(1),'Old-body cleanup must not stop or alter its replacement')
locomotionWorld:hold(1,true);locomotionWorld:hold(1,false)
assert(not locomotionWorld:isRunning(1) and runner.humanoid.WalkSpeed==16)
local groundEnemy=freshRunner(-8);locomotionWorld.enemyKinds[-8]='Drone'
locomotionWorld:move(-8,1,0,true);groundEnemy.root.AssemblyLinearVelocity=vector(16,0,0)
assert(groundEnemy.humanoid.WalkSpeed==16 and locomotionWorld:isRunning(-8))
locomotionWorld:move(-8,1,0,false)
assert(groundEnemy.humanoid.WalkSpeed==9 and not locomotionWorld:isRunning(-8))
local mount=freshRunner(-9);mount.model:SetAttribute('EnemyKind','Dragon');locomotionWorld.enemyKinds[-9]='Drone'
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
assert(locomotionWorld:dragonLink(-9,1,'Mounted'))
locomotionWorld:move(1,0,0,false);assert(locomotionWorld:dragonUnlink(1))
assert(runner.humanoid.WalkSpeed==16 and not locomotionWorld:isRunning(1)
    and runner.humanoid.MoveDirection.Magnitude==0,'Dragon unlink cannot restore saved run speed or old running intent')
print('PASS locomotion cleanup is body-scoped and preserves ordinary enemy caps, hold and Dragon release')

runner=freshRunner(1);serverTime=102
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0);locomotionWorld:hazard(1)
runner.humanoid.FloorMaterial=enum.Material.Air;runner.root.CFrame=frame(vector(50,2,0)+locomotionWorld.offset)
runner.root.AssemblyLinearVelocity=vector(24,-8,0);serverTime=102.1;locomotionWorld:hazard(1)
locomotionWorld:jump(1);locomotionWorld:move(1,0,1,false)
assert(runner.humanoid.WalkSpeed==24,'A real running walk-off keeps its run air cap through the existing jump grace')
eq(runner.root.AssemblyLinearVelocity,24,50,0)
runner=freshRunner(1);runner.root.CFrame=frame(vector(-30,3,0)+locomotionWorld.offset)
groundEnemy=freshRunner(-8);locomotionWorld.enemyKinds[-8]='Drone'
locomotionWorld:enemyMove(-8,1,16);groundEnemy.root.AssemblyLinearVelocity=vector(16,0,0)
assert(locomotionWorld:isRunning(-8),'Safe NPC run approach uses the same actual-running eligibility')
groundEnemy.root.CFrame=frame(vector(47,3,0)+locomotionWorld.offset)
runner.root.CFrame=frame(vector(60,3,0)+locomotionWorld.offset)
locomotionWorld:enemyMove(-8,1,16)
assert(groundEnemy.humanoid.MoveDirection.Magnitude==0 and not locomotionWorld:isRunning(-8),
    'The existing three-ray edge stop must cancel NPC run intent without clearing real velocity')
eq(groundEnemy.root.AssemblyLinearVelocity,16,0,0)
runner=freshRunner(1);groundEnemy=freshRunner(-8);locomotionWorld.enemyKinds[-8]='Drone'
groundEnemy.root.CFrame=frame(runner.root.Position+vector(3,0,0))
locomotionWorld:move(1,1,0,true);runner.root.AssemblyLinearVelocity=vector(24,0,0)
locomotionWorld:move(-8,1,0,true);groundEnemy.root.AssemblyLinearVelocity=vector(16,0,0)
assert(locomotionWorld:carryEnemy(-8,1));assert(locomotionWorld:releaseEnemy(-8))
assert(runner.humanoid.WalkSpeed==16 and groundEnemy.humanoid.WalkSpeed==9
    and not locomotionWorld:isRunning(1) and not locomotionWorld:isRunning(-8),
    'Pig carry and release cannot save or restore either actor run speed')
local otherLocomotion=World.new(Base,locomotionWorld.config,{name='OtherLocomotion',offset={x=100,y=10,z=8704}})
local otherRunner=actor(otherLocomotion,1,vector(-40,3,0)+otherLocomotion.offset)
otherLocomotion:move(1,1,0,true);otherRunner.root.AssemblyLinearVelocity=vector(24,0,0)
locomotionWorld:resetLocomotion(1)
assert(otherLocomotion:isRunning(1),'Locomotion state cannot cross worlds sharing a slot ID')
print('PASS run grace, NPC edge safety and carry cleanup preserve physical motion and independent groups')

runner=freshRunner(1)
for _,name in ipairs({'Left Shoulder','Right Shoulder','Left Hip','Right Hip'}) do
    local motor=node('Motor6D',name,runner.model.Torso);motor.C0=frame()
end
local gaitSession={now=102.1,sourceCombat=true,combat={[1]={}}}
runner.root.AssemblyLinearVelocity=vector(24,0,0);runner.walkPhase=0
locomotionWorld:move(1,1,0,false);locomotionWorld:updatePresentation(gaitSession,.1,{})
local walkPhase=runner.walkPhase;local walkPose=runner.poseMotors['Right Shoulder'].joint.C0.rotationX
runner.walkPhase=0;locomotionWorld:move(1,1,0,true);locomotionWorld:updatePresentation(gaitSession,.1,{})
assert(runner.walkPhase>walkPhase and runner.poseMotors['Right Shoulder'].joint.C0.rotationX~=walkPose
    and runner.model:GetAttribute('MovementMode')=='Run','Run gait and cadence must differ visibly from walking')
gaitSession.combat[1].attack={action='Dash'};locomotionWorld:updatePresentation(gaitSession,.1,{})
assert(runner.poseMotors['Right Shoulder'].joint.C0.rotationX==-.5,'Accepted attack pose has priority over running gait')
gaitSession.combat[1].attack=nil;runner.model:SetAttribute('CarryingEnemy',-8)
locomotionWorld:updatePresentation(gaitSession,.1,{})
assert(runner.poseMotors['Right Shoulder'].joint.C0.rotationX==2.65,'Carry pose has priority over ground locomotion')
runner.model:SetAttribute('CarryingEnemy',nil)
locomotionWorld:clearActors()
assert(otherLocomotion:isRunning(1),'Run cleanup cannot stop another active group')
otherLocomotion:clearActors()
print('PASS trusted locomotion mode drives distinct finite gait below attack and carry pose priority')

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

local pigWorld=World.new(Base,{FallY=-20,Level=source(LevelSource),Enemy={speed=9},WalkSpeed=12},
    {name='PigPoseWorld',offset={x=100,y=10,z=3072}})
local posingPig=actor(pigWorld,-1,vector(100,13,3072))
pigWorld.enemyKinds[-1]='Drone'
for _,name in ipairs({'Left Shoulder','Right Shoulder','Left Hip','Right Hip'}) do
    local motor=node('Motor6D',name,posingPig.model.Torso);motor.C0=frame()
end
posingPig.root.AssemblyLinearVelocity=vector(9,0,0)
local poseSession={now=1,combat={}}
local pigState={kind='Pig',windup={at=1.2,action='PigJab'}}
local function pose()
    pigWorld:updatePresentation(poseSession,.1,{[-1]=pigState})
    return posingPig.poseMotors['Right Shoulder'].joint.C0.rotationX,
        posingPig.poseMotors['Left Shoulder'].joint.C0.rotationX
end
local jabRight,jabLeft=pose()
assert(posingPig.model:GetAttribute('PrimaryAttack')=='PigJab' and posingPig.model:GetAttribute('AttackPhase')=='Windup',
    'Pig strike presentation must expose the trusted current action and phase without controlling combat')
pigState.windup.action='PigHeavy'
local heavyRight,heavyLeft=pose()
pigState.windup.action='PigRush'
local rushRight,rushLeft=pose()
assert(jabRight~=heavyRight and jabRight~=rushRight and heavyRight~=rushRight,
    'Jab, finisher and rush must use distinct original shoulder poses')
assert(jabRight~=jabLeft and heavyRight==heavyLeft and rushRight==rushLeft,
    'Jab has a one-arm preparation while heavy/rush have separate two-arm preparations')
pigState.windup=nil;pigState.lastStrikeAction='PigHeavy';pigState.strikeRecoveryUntil=1.6;pigState.rushing=true
poseSession.now=1.3
local recoveryRight=pose()
assert(posingPig.model:GetAttribute('PrimaryAttack')=='PigHeavy' and posingPig.model:GetAttribute('AttackPhase')=='Recovery'
    and recoveryRight~=heavyRight,'A finite server deadline selects the action-specific recovery before running')
poseSession.now=1.6
local beforeRun=posingPig.walkPhase;pose();local runDelta=posingPig.walkPhase-beforeRun
assert(posingPig.model:GetAttribute('PrimaryAttack')=='PigRush' and posingPig.model:GetAttribute('AttackPhase')=='Running',
    'An expired recovery falls through to the current NPC running approach')
pigState.rushing=false
local beforeWalk=posingPig.walkPhase;pose();local walkDelta=posingPig.walkPhase-beforeWalk
assert(runDelta>walkDelta,'The running approach needs a visibly faster gait than the same-speed ordinary walk')
assert(posingPig.model:GetAttribute('PrimaryAttack')==nil and posingPig.model:GetAttribute('AttackPhase')==nil,
    'Idle Pig must clear both attack presentation attributes')
assert(posingPig.attackPoseUntil==nil and posingPig.attackPoseAction==nil,'Pig phases must not leave the legacy attack latch alive')
pigState.windup={at=2,action='PigJab'};pigState.rushing=true
pose();assert(posingPig.model:GetAttribute('AttackPhase')=='Windup','Windup has priority over running approach')
pigState.reactionUntil=2;pose()
assert(posingPig.model:GetAttribute('PrimaryAttack')==nil and posingPig.model:GetAttribute('AttackPhase')==nil,
    'An incoming reaction suppresses and clears all Pig attack presentation')
pigState.reactionUntil=nil
pigWorld.enemyCarries[-1]={mode='Carried'};pose()
assert(posingPig.model:GetAttribute('AttackPhase')==nil,'A held Pig cannot retain an attack telegraph')
pigWorld.enemyCarries[-1]=nil
posingPig.humanoid.Health=0;pose()
assert(posingPig.model:GetAttribute('PrimaryAttack')==nil and posingPig.model:GetAttribute('AttackPhase')==nil,
    'Dead bodies must not show an attack or recovery telegraph')
posingPig.humanoid.Health=100
pigState.kind=nil;pigState.windup={at=2}
pose()
assert(posingPig.attackPoseAction=='Punch' and posingPig.model:GetAttribute('AttackPhase')==nil,
    'Legacy ordinary enemy presentation keeps its original Punch fallback')
print('PASS Pig jab, finisher, rush, running and recovery poses are distinct finite presentation with safe cancellation')

local walkerPose=actor(pigWorld,-2,vector(103,13,3072));pigWorld.enemyKinds[-2]='Drone'
for _,name in ipairs({'Left Shoulder','Right Shoulder','Left Hip','Right Hip'}) do
    local motor=node('Motor6D',name,walkerPose.model.Torso);motor.C0=frame()
end
local walkerState={kind='Walker',windup={at=2.5,action='WalkerLight'}}
poseSession.now=2
local function poseWalker()
    pigWorld:updatePresentation(poseSession,.1,{[-2]=walkerState})
    return walkerPose.poseMotors['Right Hip'].joint.C0.rotationX,
        walkerPose.poseMotors['Left Hip'].joint.C0.rotationX
end
local lightLeg,lightSupport=poseWalker()
assert(walkerPose.model:GetAttribute('PrimaryAttack')=='WalkerLight' and walkerPose.model:GetAttribute('AttackPhase')=='Windup',
    'Walker needs its own trusted primary telegraph rather than the generic Punch fallback')
walkerState.windup.action='WalkerHeavy'
local heavyLeg,heavySupport=poseWalker()
assert(lightLeg~=heavyLeg and lightLeg~=lightSupport and heavyLeg==heavySupport,
    'The light leg preparation must differ from the two-leg heavy launch preparation')
walkerState.windup=nil;walkerState.lastStrikeAction='WalkerHeavy';walkerState.strikeRecoveryUntil=2.35
poseSession.now=2.2
local recoveryLeg=poseWalker()
assert(walkerPose.model:GetAttribute('AttackPhase')=='Recovery' and recoveryLeg~=heavyLeg,
    'Walker recovery has a separate finite leg pose selected by Session time')
poseSession.now=2.35;poseWalker()
assert(walkerPose.model:GetAttribute('PrimaryAttack')==nil and walkerPose.model:GetAttribute('AttackPhase')==nil
    and walkerPose.attackPoseUntil==nil and walkerPose.attackPoseAction==nil,'Walker expiry clears all primary presentation state')
walkerState.windup={at=3,action='WalkerLight'};walkerState.reactionUntil=3
poseWalker();assert(walkerPose.model:GetAttribute('AttackPhase')==nil,'Incoming reactions suppress Walker telegraphs')
walkerState.reactionUntil=nil;pigWorld.enemyCarries[-2]={mode='Carried'}
poseWalker();assert(walkerPose.model:GetAttribute('AttackPhase')==nil,'Held bodies cannot retain Walker strike poses')
pigWorld.enemyCarries[-2]=nil;walkerPose.humanoid.Health=0
poseWalker();assert(walkerPose.model:GetAttribute('AttackPhase')==nil,'Dead Walker cannot display an active strike')
walkerPose.humanoid.Health=100
pigState={kind='Pig',windup={at=3,action='PigJab'}}
pigWorld:updatePresentation(poseSession,.1,{[-1]=pigState,[-2]=walkerState})
assert(posingPig.model:GetAttribute('PrimaryAttack')=='PigJab','Walker presentation must not replace Pig primary states')
print('PASS Walker light leg, heavy launch and finite recovery poses preserve Pig and clear on interruption')

for _,entry in ipairs({{actor=posingPig,kind='Pig',id=-1},{actor=walkerPose,kind='Walker',id=-2}}) do
    local state={kind=entry.kind,windup={at=3,action='EnemyRunStrike'}}
    local states={[entry.id]=state};poseSession.now=2.5
    pigWorld:updatePresentation(poseSession,.1,states)
    assert(entry.actor.model:GetAttribute('PrimaryAttack')=='EnemyRunStrike'
        and entry.actor.model:GetAttribute('AttackPhase')=='Windup','Ground enemy run strike needs a trusted finite telegraph')
    state.windup=nil;state.lastStrikeAction='EnemyRunStrike';state.strikeRecoveryUntil=2.8
    pigWorld:updatePresentation(poseSession,.1,states)
    assert(entry.actor.model:GetAttribute('AttackPhase')=='Recovery')
    poseSession.now=2.8;pigWorld:updatePresentation(poseSession,.1,states)
    assert(entry.actor.model:GetAttribute('PrimaryAttack')==nil,'Running-strike art cannot outlive its server recovery deadline')
end
print('PASS Pig and Walker running strikes use finite original telegraph and recovery without new combat authority')

local dragonPose=actor(pigWorld,-3,vector(110,13,3072));pigWorld.enemyKinds[-3]='Drone'
for _,name in ipairs({'Left Shoulder','Right Shoulder','Left Hip','Right Hip','Neck'}) do
    local motor=node('Motor6D',name,dragonPose.model.Torso);motor.C0=frame()
end
local dragonState={kind='Dragon',windup={at=4,action='DragonHeadbutt'}}
poseSession.now=3
local function poseDragon() pigWorld:updatePresentation(poseSession,.1,{[-3]=dragonState}) end
poseDragon()
assert(dragonPose.model:GetAttribute('PrimaryAttack')=='DragonHeadbutt'
    and dragonPose.model:GetAttribute('AttackPhase')=='Windup','Dragon must present its own accepted headbutt')
local dragonNeck=dragonPose.poseMotors.Neck
assert(dragonNeck and dragonNeck.joint.C0.rotationX~=0,'Headbutt needs a real original neck pose')
local preparedNeck=dragonNeck.joint.C0.rotationX
dragonState.windup=nil;dragonState.lastStrikeAction='DragonHeadbutt';dragonState.strikeRecoveryUntil=3.25
poseDragon();assert(dragonNeck.joint.C0.rotationX~=preparedNeck and dragonPose.model:GetAttribute('AttackPhase')=='Recovery')
poseSession.now=3.25;poseDragon()
assert(dragonNeck.joint.C0.rotationX==0 and dragonPose.model:GetAttribute('PrimaryAttack')==nil,
    'Headbutt neck/phase must reset after the finite recovery')
dragonState.windup={at=5,action='DragonHeadbutt'};dragonState.reactionUntil=5;poseDragon()
assert(dragonNeck.joint.C0.rotationX==0 and dragonPose.model:GetAttribute('PrimaryAttack')==nil)
dragonState.reactionUntil=nil;dragonPose.humanoid.Health=0;poseDragon()
assert(dragonPose.model:GetAttribute('AttackPhase')==nil,'Death must cancel Dragon presentation')
dragonPose.humanoid.Health=100
print('PASS Dragon headbutt has real finite neck poses and clears on reaction/death')

local sourceHero=actor(pigWorld,1,vector(100,13,3072))
for _,name in ipairs({'Left Shoulder','Right Shoulder','Left Hip','Right Hip'}) do
    local motor=node('Motor6D',name,sourceHero.model.Torso);motor.C0=frame()
end
local sourceSession={now=4,sourceCombat={},combat={[1]={rawLife=47,attack={at=4.2,action='HeroUppercut'}}}}
pigWorld:updatePresentation(sourceSession,.1,{})
assert(sourceHero.model:GetAttribute('PrimaryAttack')=='HeroUppercut','Modern hero must show the server-selected action')
local upperArm=sourceHero.poseMotors['Right Shoulder'].joint.C0.rotationX
sourceSession.combat[1].attack.action='HeroBoot';pigWorld:updatePresentation(sourceSession,.1,{})
assert(sourceHero.poseMotors['Right Shoulder'].joint.C0.rotationX~=upperArm
    and sourceHero.poseMotors['Right Hip'].joint.C0.rotationX~=0,'Boot must have a distinct arm and leg pose')
sourceSession.combat[1].attack=nil;sourceSession.combat[1].lastStrikeAction='HeroBoot';sourceSession.combat[1].strikeRecoveryUntil=4.3
pigWorld:updatePresentation(sourceSession,.1,{})
assert(sourceHero.model:GetAttribute('AttackPhase')=='Recovery')
sourceSession.now=4.3;pigWorld:updatePresentation(sourceSession,.1,{})
assert(sourceHero.model:GetAttribute('PrimaryAttack')==nil and sourceHero.poseMotors['Right Hip'].joint.C0.rotationX==0)
sourceSession.combat[1].attack={action='HeroKick'};sourceSession.combat[1].reactionEnd=5
pigWorld:updatePresentation(sourceSession,.1,{})
assert(sourceHero.model:GetAttribute('PrimaryAttack')==nil,'Incoming damage suppresses the hero attack pose')
print('PASS source hero uppercut and boot poses follow authoritative finite action state without affecting combat')

local retreatWorld=World.new(Base,{FallY=-20,Level=source(LevelSource),Enemy={speed=9},WalkSpeed=12},
    {name='WalkerRetreatWorld',offset={x=100,y=10,z=3584}})
local retreatWalker=actor(retreatWorld,-1,vector(100,13,3584))
local closeHero=actor(retreatWorld,1,vector(102,13,3584))
closeHero.humanoid.FloorMaterial=enum.Material.Air -- Target grounding is not a movement prerequisite.
retreatWalker.root.AssemblyLinearVelocity=vector(4,5,6)
local originalFrame=retreatWalker.root.CFrame
assert(type(retreatWorld.enemyRetreat)=='function','Walker close-range movement needs a safe away-from-target command')
oldRaycast=workspace.Raycast
local retreatRays=0
function workspace:Raycast(origin,direction,params)
    if params==retreatWorld.ray then retreatRays+=1 end
    return oldRaycast(self,origin,direction,params)
end
retreatWorld:enemyRetreat(-1,1,7)
eq(retreatWalker.humanoid.lastMove,-1,0,0,'Retreat must move away from the actual same-group target')
assert(retreatWalker.humanoid.WalkSpeed==7 and retreatRays==3,'Retreat uses its configured speed and all three edge-support rays')
assert(retreatWalker.root.CFrame==originalFrame,'Backstep must not teleport or rotate the physical root')
eq(retreatWalker.root.AssemblyLinearVelocity,4,5,6,'Backstep must preserve existing impulses and gravity velocity')
retreatWorld:enemyMove(-1,1,9)
eq(retreatWalker.humanoid.lastMove,1,0,0,'Shared safety must preserve normal pursuit toward the target')
assert(retreatWalker.humanoid.WalkSpeed==9)
retreatWalker.root.CFrame=frame(20,13,3584);closeHero.root.CFrame=frame(22,13,3584)
retreatWorld:enemyRetreat(-1,1,7)
eq(retreatWalker.humanoid.lastMove,0,0,0,'A backward step across the real platform edge must stop voluntary movement')
eq(retreatWalker.root.Position,20,13,3584)
eq(retreatWalker.root.AssemblyLinearVelocity,4,5,6,'Unsafe-edge stopping cannot erase an outside impulse')
retreatWalker.root.CFrame=frame(100,13,3609.5);closeHero.root.CFrame=frame(102,13,3609.5)
retreatWorld:enemyRetreat(-1,1,7)
eq(retreatWalker.humanoid.lastMove,0,0,0,'A safe centre ray is insufficient when a side support ray crosses the edge')
retreatWalker.root.CFrame=frame(100,13,3584);closeHero.root.CFrame=frame(102,13,3584)
for _,guard in ipairs({'Anchored','Reaction','Carried','Dead','MissingTarget'}) do
    retreatWalker.root.Anchored=guard=='Anchored';retreatWalker.humanoid.PlatformStand=guard=='Reaction'
    retreatWalker.humanoid.Health=guard=='Dead' and 0 or 100
    retreatWorld.enemyCarries[-1]=guard=='Carried' and {mode='Carried'} or nil
    if guard=='MissingTarget' then closeHero.root.Parent=nil end
    local before=retreatWalker.humanoid.lastMove
    retreatWorld:enemyRetreat(-1,1,7)
    assert(retreatWalker.humanoid.lastMove==before,'Held, reacting, dead, anchored or targetless bodies cannot start a backstep')
end
retreatWorld.enemyCarries[-1]=nil
workspace.Raycast=oldRaycast
assert(default.folder.Parent==workspace and pigWorld.folder.Parent==workspace,'Retreat affects no other group world')
print('PASS Walker backstep shares three-ray edge safety, moves away at configured speed and preserves physical impulses')

local movementLinks=World.new(Base,{FallY=-20,Enemy={speed=9},WalkSpeed=12},{name='DragonMovementReset',offset={x=102,y=10,z=5120}})
local movementDragon=actor(movementLinks,-1,vector(102,13,5120))
local movementHero=actor(movementLinks,1,vector(106,13,5120))
for _,mode in ipairs({'Mounted','Captured'}) do
    movementHero.humanoid:Move(vector(1,0,0),false)
    assert(movementLinks:dragonLink(-1,1,mode))
    eq(movementHero.humanoid.MoveDirection,0,0,0,'Dragon link must clear the previous hero movement command')
    movementLinks:move(1,1,0)
    movementLinks:move(1,0,0) -- Session timeout/disconnect stop while the link owns physics.
    eq(movementHero.humanoid.MoveDirection,0,0,0,'Linked movement suppression cannot preserve a previous walking command')
    -- Exercise release clearing independently, including a residual actuator command.
    movementHero.humanoid:Move(vector(1,0,0),false)
    local oldMove=movementHero.humanoid.Move
    local resetState
    function movementHero.humanoid:Move(direction,relative)
        if direction.Magnitude==0 then
            resetState={evaluate=self.EvaluateStateMachine,standing=self.PlatformStand,anchored=movementHero.root.Anchored}
        end
        oldMove(self,direction,relative)
    end
    assert(movementLinks:dragonUnlink(1))
    movementHero.humanoid.Move=oldMove
    eq(movementHero.humanoid.MoveDirection,0,0,0,'Mounted and captured release cannot resume stale voluntary movement')
    assert(resetState and resetState.evaluate==false and resetState.standing and resetState.anchored,
        'The old move command must be cleared before restoring normal body locomotion')
    assert(movementHero.humanoid.EvaluateStateMachine and not movementHero.humanoid.PlatformStand
        and movementHero.humanoid.WalkSpeed==12 and not movementHero.root.Anchored and movementHero.humanoid.Health==100,
        'Clearing old movement must preserve saved physics and health')
end
movementHero.humanoid:Move(vector(1,0,0),false)
assert(movementLinks:dragonLink(-1,1,'Captured'))
movementHero.humanoid:Move(vector(1,0,0),false)
local oldLinkedHero=movementHero
local newMovementHero=actor(movementLinks,1,vector(120,13,5120))
newMovementHero.humanoid:Move(vector(-1,0,0),false)
movementLinks:clearActors()
eq(oldLinkedHero.humanoid.MoveDirection,0,0,0,'Cleanup must stop the saved old linked body, not look up its replacement slot')
eq(newMovementHero.humanoid.MoveDirection,-1,0,0,'Old-link cleanup cannot rewrite a new actor movement command')
assert(oldLinkedHero.humanoid.Health==100 and next(movementLinks.dragonLinks)==nil)
print('PASS Dragon link and release discard stale hero movement before restoring physics on both modes and old-body cleanup')

local responseWorld=World.new(Base,{FallY=-20},{name='AcceptedResponseWorld'})
local responseTarget=actor(responseWorld,1,vector(0,3,0))
local responseAttacker=actor(responseWorld,2,vector(2,3,0))
responseAttacker.root.CFrame.LookVector=vector(1,0,0)
responseTarget.root.AssemblyMass=2
local applied=0
function responseTarget.root:ApplyImpulse(value) self.lastApplied=value;applied+=1 end
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18)
eq(responseTarget.root.lastApplied,18,0,0,'A captured response survives removal of the live impulse table')
local bound=pcall(actualBase.impulse,responseWorld,1,2,{profile=18,horizontal=9,vertical=0},22)
assert(not bound and applied==1,'A snapshot cannot be rebound to a different profile')
print('PASS accepted response snapshots stay bound to their own profile without a live config table')

responseAttacker.root.CFrame.LookVector=vector(-1,0,0)
local currentFacingFrame=responseAttacker.root.CFrame
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18,{x=1,z=0})
eq(responseTarget.root.lastApplied,18,0,0,'A captured shot direction must override an attacker who later turns around')
assert(responseAttacker.root.CFrame==currentFacingFrame,'A shot response cannot rotate the current attacker to fake its accepted direction')
responseWorld.actors[2]=nil
local appliedBefore=applied
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18,{x=3,y=0,z=0})
assert(applied==appliedBefore+1,'Accepted direction must still apply an impulse after its attacker actor disappears')
eq(responseTarget.root.lastApplied,18,0,0,'Explicit horizontal direction is normalized independently of current actors')
local replacementAttacker=actor(responseWorld,2,vector(4,3,0));replacementAttacker.root.CFrame.LookVector=vector(-1,0,0)
local replacementFrame=replacementAttacker.root.CFrame
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18,{x=1,y=0,z=0})
eq(responseTarget.root.lastApplied,18,0,0,'A new attacker appearance cannot redirect an earlier shot')
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18)
eq(responseTarget.root.lastApplied,-18,0,0,'Without a captured direction legacy attacks retain current-facing impulses')
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18,{x=0/0,z=1})
eq(responseTarget.root.lastApplied,-18,0,0,'Malformed direction falls back to the existing actor facing')
assert(replacementAttacker.root.CFrame==replacementFrame)
responseWorld.actors[2]=nil;appliedBefore=applied
actualBase.impulse(responseWorld,1,2,{profile=18,horizontal=9,vertical=0},18,{x=0,z=0})
assert(applied==appliedBefore,'An absent attacker and invalid direction cannot invent an impulse')
print('PASS actual world impulse uses accepted shot direction through turns, replacement and disappearance without rotating actors')

-- Physical API contracts execute the real adapter; they do not integrate Roblox physics.
assert(type(World.dragonMotion)=='function','Dragon flight needs a real world adapter')
workspace.Gravity=196.2
local flightWorld=World.new(Base,{FallY=-20,Enemy={speed=9},WalkSpeed=12,JumpPower=42},{name='DragonPhysical',offset={x=102,y=10,z=4096}})
local deck=node('Part','DragonDeck',flightWorld.geometry);deck.CFrame=frame(106,9,4096);deck.Size=vector(40,2,30);deck.CanCollide=true;deck:SetAttribute('SurfaceId','dragon-deck')
local dragon=actor(flightWorld,-1,vector(102,13,4096));dragon.root.AssemblyMass=12;dragon.root.CFrame.LookVector=vector(1,0,0)
flightWorld.enemyKinds[-1]='Drone';dragon.model:SetAttribute('EnemyKind','Dragon')
local rider=actor(flightWorld,1,vector(106,13,4096));rider.root.CFrame.LookVector=vector(-1,0,0)
for _,p in ipairs(rider.model:GetDescendants()) do if p:IsA('BasePart') then p.CanCollide=p.Name=='Torso' end end
assert(flightWorld:dragonGrounded(-1) and flightWorld:dragonFloor(-1)==3)
assert(flightWorld:dragonMotion(-1,1,0,4.5,10))
eq(dragon.root.AssemblyLinearVelocity,10,9,0,'Flight height is local to its group elevation')
local force=flightWorld.dragonFlights[-1].force
assert(math.abs(force.Force.Y-2354.4)<1e-6 and dragon.humanoid.PlatformStand)
flightWorld:stopDragon(-1)
assert(force.Parent==nil and not dragon.humanoid.PlatformStand and dragon.humanoid.EvaluateStateMachine==true)
assert(flightWorld:dragonCanMount(1,-1,5,4))
assert(flightWorld:dragonLink(-1,1,'Mounted'))
assert(rider.root.Anchored and not rider.humanoid.EvaluateStateMachine and not rider.model.Torso.CanCollide)
eq(rider.root.Position,102,16.2,4096,'Mounted hero must get group translation once')
flightWorld:hold(1,false);assert(rider.root.Anchored,'Shield removal cannot unanchor a linked rider')
flightWorld:setReaction(1,true);flightWorld:setReaction(1,false)
flightWorld:dragonUnlink(1)
assert(not rider.root.Anchored and rider.humanoid.EvaluateStateMachine and not rider.humanoid.PlatformStand
    and rider.humanoid.WalkSpeed==12 and rider.model.Torso.CanCollide)
print('PASS Dragon physical flight and mounting restore gravity/authority/collisions and local coordinates')

rider.root.CFrame=frame(106,13,4096)
assert(flightWorld:dragonLink(-1,1,'Captured'))
local predecessor=rider
rider=actor(flightWorld,1,vector(120,13,4096))
flightWorld:dragonUnlink(1,true)
assert(not predecessor.root.Anchored and not rider.root.Anchored and rider.humanoid.PlatformStand==false)
eq(rider.root.Position,120,13,4096,'Releasing the old body cannot teleport the replacement')
local target=actor(flightWorld,2,vector(111,13,4096))
local nearer=actor(flightWorld,-2,vector(109,13,4096))
local found,blocked=flightWorld:dragonFireTargets({x=0,y=3,z=0},{x=12,y=3,z=0},1,{[-1]=true,[1]=true})
assert(found[1]==-2 and found[2]==2 and not blocked,'Swept shots use deterministic nearest live actors from this group')
local originalRay=workspace.Raycast
function workspace:Raycast(origin,direction,params)
    if direction.X>0 then return {Position=vector(110,13,4096),Instance=deck} end
    return originalRay(self,origin,direction,params)
end
found,blocked=flightWorld:dragonFireTargets({x=0,y=3,z=0},{x=12,y=3,z=0},1,{[-1]=true,[1]=true})
assert(blocked and #found==1 and found[1]==-2,'A wall must prevent hits on the actor behind it')
workspace.Raycast=originalRay
flightWorld:dragonFire(-5001,{x=3,y=4,z=0})
eq(flightWorld.dragonFires[-5001].Position,105,14,4096)
flightWorld:clearActors()
assert(next(flightWorld.dragonFires)==nil and next(flightWorld.dragonLinks)==nil and next(flightWorld.dragonFlights)==nil)
assert(default.folder.Parent==workspace and route.folder.Parent==workspace,'Flight cleanup stays inside its group')
print('PASS Dragon release protects replacement bodies, swept fire stops at geometry and cleanup stays scoped')

local fireWorld=World.new(Base,{FallY=-20},{name='DragonFireVolume',offset={x=0,y=0,z=4608}})
local sphereCalls=0
function workspace:GetPartBoundsInRadius(origin,radius,params)
    assert(radius==1 and params.RespectCanCollide==true and params.FilterDescendantsInstances[1]==fireWorld.geometry)
    return self.fireOverlap and {fireWorld.floors[1]} or {}
end
function workspace:Spherecast(origin,radius,delta,params)
    sphereCalls+=1;assert(radius==1 and delta.X==12 and params==fireWorld.ray)
    return {Position=vector(9,3,4608),Distance=8,Instance=fireWorld.floors[1]}
end
actor(fireWorld,2,vector(9,3,4608))
local ids,wall=fireWorld:dragonFireTargets({x=0,y=3,z=0},{x=12,y=3,z=0},1,{})
assert(wall and #ids==0 and sphereCalls==1,'Fire needs a radius sweep and center-travel wall bound')
workspace.fireOverlap=true
ids,wall=fireWorld:dragonFireTargets({x=0,y=3,z=0},{x=12,y=3,z=0},1,{})
assert(wall and #ids==0 and sphereCalls==1,'Initial wall overlap consumes fire before a sweep or damage')
workspace.fireOverlap=nil
print('PASS Dragon fire volume checks initial obstruction and sphere radius before candidate damage')

local artWorld=World.new(Base,{FallY=-20,WalkSpeed=12},{name='DragonArt'})
assert(artWorld:spawnEnemy(-9,'Dragon',{x=0,y=3,z=0}))
local art=artWorld.actors[-9]
assert(art.wingMotors and #art.wingMotors==2,'Original Dragon wings need articulated motors')
local wing=art.wingMotors[1]
art.model:SetAttribute('DragonFlight',true)
artWorld:updatePresentation({now=0,combat={}},.1,{[-9]={kind='Dragon'}})
assert(wing.joint.C0.rotationZ~=wing.base.rotationZ,'Active flight needs a visible wing stroke')
art.model:SetAttribute('DragonFlight',nil)
artWorld:updatePresentation({now=1,combat={}},.1,{[-9]={kind='Dragon'}})
assert(wing.joint.C0.rotationZ==wing.base.rotationZ,'Stopped flight must return its wing pose')
print('PASS original wing motors move only for authoritative flight and return to rest')

local entryWorld=World.new(Base,{FallY=-20},{name='DragonFireEntry'})
local saveSphere,saveOverlap=workspace.Spherecast,workspace.GetPartBoundsInRadius
function workspace:GetPartBoundsInRadius() return {} end
function workspace:Spherecast() return nil end
actor(entryWorld,-1,vector(2,3,2.9));actor(entryWorld,2,vector(3,3,0))
local order=entryWorld:dragonFireTargets({x=0,y=3,z=0},{x=3.2,y=3,z=0},1,{})
assert(order[1]==2 and order[2]==-1,'An initial actor overlap must precede a later grazing entry')
local emitter=actor(entryWorld,-9,vector(0,3,0));emitter.root.CFrame.LookVector=vector(1,0,0)
function workspace:Spherecast(origin,radius,direction,params)
    assert(origin.X==0 and radius==1 and direction.X==2.8)
    return {Position=vector(.9,3.25,0),Distance=0,Instance=entryWorld.floors[1]}
end
local muzzle,direction,obstructed=entryWorld:dragonMuzzle(-9)
assert(muzzle and direction and obstructed,'A thin wall entirely before the muzzle must block the accepted shot')
workspace.Spherecast,workspace.GetPartBoundsInRadius=saveSphere,saveOverlap
print('PASS fire orders first contact and detects a thin wall before its projected muzzle')

local appearanceCalls,appearanceUpdates=0,0
local appearanceAdapter={}
function appearanceAdapter.attach(body,template)
    appearanceCalls+=1
    if template~='Mr. Green' then return false end
    local mesh=node('Part','GeneratedSurface',body.model)
    mesh.Anchored=false;mesh.Massless=true;mesh.CanCollide=false
    return true
end
function appearanceAdapter.update(body)
    appearanceUpdates+=1
    assert(body.root:GetNetworkOwner()==nil and not body.root:GetNetworkOwnershipAuto(),
        'Pose updates must observe the fully assembled server-owned hero')
end
local appearanceWorld=World.new(ownershipBase,{FallY=-20,WalkSpeed=16,JumpPower=50},
    {name='HeroAppearanceIntegration',characterAppearance=appearanceAdapter})
assert(appearanceWorld:spawn(1,'appearance-hero',nil,false,'Mr. Green'))
local appearanceHero=appearanceWorld.actors[1]
assert(appearanceCalls==1 and appearanceHero.root.assemblyOwnershipResets>0,
    'The real spawn hook must attach cosmetics after basic assembly and exercise ownership reset')
assert(appearanceHero.root:GetNetworkOwner()==nil and not appearanceHero.root:GetNetworkOwnershipAuto()
    and appearanceHero.humanoid.Health==100,'Cosmetic assembly preserves HP and restores manual server authority')
appearanceWorld:updatePresentation({now=0,combat={}},.1,{})
assert(appearanceUpdates==1,'The world must update cosmetic joints after its normal pose presentation')
appearanceWorld:clearActors()
print('PASS hero appearance integration restores server authority after cosmetics and updates only presentation')
