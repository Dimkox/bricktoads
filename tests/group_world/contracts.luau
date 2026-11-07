-- These doubles exercise real coordinate consumers; engine physics is tested in Studio.
local Vec={}; Vec.__index=Vec
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
    return {config=config,folder=folder,geometry=node('Folder','Geometry',folder),actorFolder=node('Folder','Actors',folder),
        actors={},names={},origins={}}
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
    local a={model=model,root=root,humanoid={Health=100},cue=0}
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
