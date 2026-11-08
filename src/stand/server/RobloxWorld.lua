-- Original stand geometry and server-owned physical bodies. No ROM assets or client positions.
local World = {}
World.__index = World
local Workspace = game:GetService("Workspace")
local function part(parent, name, size, frame, color, anchored)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.CFrame=frame; p.Anchored=anchored
    p.Color=color; p.Material=Enum.Material.SmoothPlastic
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent
    return p
end
local function joint(parent, name, a, b, c0, c1)
    local m=Instance.new("Motor6D")
    m.Name=name; m.Part0=a; m.Part1=b; m.C0=c0; m.C1=c1; m.Parent=parent
end
local function own(root)
    if not root.Anchored then
        local allowed,reason=root:CanSetNetworkOwnership()
        assert(allowed,reason or "Cannot assign server ownership")
        root:SetNetworkOwner(nil)
    end
end
local function body(actorId, position, color, displayName)
    local model=Instance.new("Model"); model.Name="Actor_"..actorId
    local root=part(model,"HumanoidRootPart",Vector3.new(2,2,1),CFrame.new(),color,true)
    root.Transparency=1; root.CanCollide=false; root.RootPriority=127
    local torso=part(model,"Torso",Vector3.new(2,2,1),CFrame.new(),color,false)
    local head=part(model,"Head",Vector3.new(2,1,1),CFrame.new(0,1.5,0),color,false)
    local la=part(model,"Left Arm",Vector3.new(1,2,1),CFrame.new(-1.5,0,0),color,false)
    local ra=part(model,"Right Arm",Vector3.new(1,2,1),CFrame.new(1.5,0,0),color,false)
    local ll=part(model,"Left Leg",Vector3.new(1,2,1),CFrame.new(-0.5,-2,0),color,false)
    local rl=part(model,"Right Leg",Vector3.new(1,2,1),CFrame.new(0.5,-2,0),color,false)
    for _,limb in ipairs({la,ra,ll,rl}) do limb.CanCollide=false end
    joint(root,"RootJoint",root,torso,CFrame.new(),CFrame.new())
    joint(torso,"Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-0.5,0))
    joint(torso,"Left Shoulder",torso,la,CFrame.new(-1,0.5,0),CFrame.new(0.5,0.5,0))
    joint(torso,"Right Shoulder",torso,ra,CFrame.new(1,0.5,0),CFrame.new(-0.5,0.5,0))
    joint(torso,"Left Hip",torso,ll,CFrame.new(-0.5,-1,0),CFrame.new(0,1,0))
    joint(torso,"Right Hip",torso,rl,CFrame.new(0.5,-1,0),CFrame.new(0,1,0))
    for _,x in ipairs({-0.55,0.55}) do
        local eye=part(model,"Eye",Vector3.new(0.35,0.35,0.25),CFrame.new(x,1.75,-0.58),Color3.new(1,1,0.8),false)
        eye.CanCollide=false; eye.Massless=true
        local weld=Instance.new("WeldConstraint"); weld.Part0=head; weld.Part1=eye; weld.Parent=eye
    end
    local humanoid=Instance.new("Humanoid")
    humanoid.Name="Humanoid"; humanoid.DisplayName=displayName
    humanoid.BreakJointsOnDeath=false; humanoid.MaxHealth=100; humanoid.Health=100
    humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.HipHeight=0; humanoid.UseJumpPower=true; humanoid.Parent=model
    model.PrimaryPart=root
    model:PivotTo(CFrame.lookAt(position,position+Vector3.new(1,0,0)))
    model:SetAttribute("ActorId",actorId)
    return {model=model,root=root,humanoid=humanoid,cue=0}
end

function World.new(config)
    local folder=Instance.new("Folder"); folder.Name="CombatStandWorld"; folder.Parent=Workspace
    local geometry=Instance.new("Folder"); geometry.Name="Geometry"; geometry.Parent=folder
    local actors=Instance.new("Folder"); actors.Name="Actors"; actors.Parent=folder
    local self=setmetatable({config=config,folder=folder,geometry=geometry,actorFolder=actors,
        actors={},origins={},lastSupport={},deathReason={},names={},floors={},blocked=false},World)
    local floor=part(geometry,"MainPlatform",Vector3.new(72,2,36),CFrame.new(0,-1,0),Color3.fromRGB(64,83,99),true)
    floor:SetAttribute("SurfaceId","Main"); self.floors[#self.floors+1]=floor
    local island=part(geometry,"Island",Vector3.new(16,2,16),CFrame.new(56,-1,0),Color3.fromRGB(73,98,112),true)
    island:SetAttribute("SurfaceId","Island"); self.floors[#self.floors+1]=island
    part(geometry,"PhysicalWall",Vector3.new(2,7,36),CFrame.new(-35,3.5,0),Color3.fromRGB(114,128,140),true)
    self.danger=part(geometry,"DangerSurface",Vector3.new(10,0.2,6),CFrame.new(-8,0.1,12),Color3.fromRGB(220,85,70),true)
    self.danger:SetAttribute("Hazard",true); self.danger:SetAttribute("SurfaceId","Main")
    local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances={geometry}; ray.RespectCanCollide=true; self.ray=ray
    local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances={geometry,actors}; overlap.RespectCanCollide=true; self.overlap=overlap
    return self
end

function World:isSafe(point, uid)
    if self.blocked or not point or not point.surface or not point.surface.Parent or not point.surface.CanCollide then return false end
    local p=point.position
    for _,offset in ipairs({Vector3.new(),Vector3.new(-1.9,0,-0.9),Vector3.new(-1.9,0,0.9),
        Vector3.new(1.9,0,-0.9),Vector3.new(1.9,0,0.9)}) do
        local hit=Workspace:Raycast(p+offset+Vector3.new(0,1,0),Vector3.new(0,-6,0),self.ray)
        if not hit or hit.Instance~=point.surface or hit.Normal.Y<0.95 or hit.Instance:GetAttribute("Hazard") then return false end
    end
    local actor=self.actors[uid]
    for _,p2 in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(p),Vector3.new(4.1,5.8,2.1),self.overlap)) do
        if p2.CanCollide and not (actor and p2:IsDescendantOf(actor.model)) then return false end
    end
    return true
end

function World:findSafe(uid)
    if self.blocked then return nil end
    local actor=self.actors[uid]
    local origin=actor and actor.root.Parent and actor.root.Position or self.origins[uid] or Vector3.new(-18+uid*6,3,0)
    local points={}
    for _,floor in ipairs(self.floors) do
        local same=self.deathReason[uid]=="Fall" or not self.lastSupport[uid]
            or floor:GetAttribute("SurfaceId")==self.lastSupport[uid]
        if floor.CanCollide and same then
            local minX,maxX=floor.Position.X-floor.Size.X/2+2.2,floor.Position.X+floor.Size.X/2-2.2
            local minZ,maxZ=floor.Position.Z-floor.Size.Z/2+1.2,floor.Position.Z+floor.Size.Z/2-1.2
            -- An upright body cannot fit on a support smaller than its safe footprint.
            if minX<=maxX and minZ<=maxZ then
                local y=floor.Position.Y+floor.Size.Y/2+3
                local function add(x,z) points[#points+1]={position=Vector3.new(x,y,z),surface=floor} end
                add(math.clamp(origin.X,minX,maxX),math.clamp(origin.Z,minZ,maxZ))
                for x=minX,maxX,4.5 do for z=minZ,maxZ,3 do add(x,z) end end
            end
        end
    end
    table.sort(points,function(a,b)
        local da=(a.position-origin).Magnitude; local db=(b.position-origin).Magnitude
        if da~=db then return da<db end
        if a.position.X~=b.position.X then return a.position.X<b.position.X end
        return a.position.Z<b.position.Z
    end)
    for _,point in ipairs(points) do if self:isSafe(point,uid) then return point end end
    return nil
end

function World:spawn(uid, actorId, point, held, template)
    if point and not self:isSafe(point,uid) then return false end
    local origin=self.origins[uid] or Vector3.new(-18+uid*6,3,0)
    local position=point and point.position or Vector3.new(origin.X,3,origin.Z)
    local colors={["Mr. Green"]=Color3.fromRGB(81,160,88),["Mr. Yellow"]=Color3.fromRGB(201,179,64),["Mr. Brown"]=Color3.fromRGB(144,108,76)}
    local prepared
    local ok,err=pcall(function()
        prepared=body(actorId,position,colors[template],self.names[uid] or ("P"..uid))
        prepared.model:SetAttribute("Slot",uid)
        prepared.humanoid.WalkSpeed=self.config.WalkSpeed; prepared.humanoid.JumpPower=self.config.JumpPower
        prepared.model.Parent=self.actorFolder
        prepared.root.Anchored=held
        own(prepared.root)
    end)
    if not ok then
        if prepared then prepared.model:Destroy() end
        warn("[BT-STAND] physical spawn failed: "..tostring(err))
        return false
    end
    local old=self.actors[uid]
    self.actors[uid]=prepared; self.origins[uid]=position
    if not held then self.deathReason[uid]=nil end
    if old then old.model:Destroy() end
    return true
end

function World:hold(uid, held)
    local a=self.actors[uid]; if not a or not a.root.Parent then return end
    a.root.Anchored=held
    if held then
        a.root.AssemblyLinearVelocity=Vector3.new(); a.root.AssemblyAngularVelocity=Vector3.new()
        a.humanoid:Move(Vector3.new(),false)
    else own(a.root) end
end
function World:move(uid, x, z)
    local a=self.actors[uid]
    if a and a.humanoid.Health>0 and not a.root.Anchored and not a.humanoid.PlatformStand then
        a.humanoid:Move(Vector3.new(x,0,z),false)
    end
end
function World:jump(uid)
    local a=self.actors[uid]
    if a and a.humanoid.Health>0 and not a.root.Anchored and not a.humanoid.PlatformStand
        and a.humanoid.FloorMaterial~=Enum.Material.Air then a.humanoid.Jump=true end
end
function World:setReaction(uid, active)
    local a=self.actors[uid]; if not a then return end
    a.humanoid.PlatformStand=active
    a.humanoid.AutoRotate=not active
    a.humanoid.WalkSpeed=active and 0 or self.config.WalkSpeed
end
function World:targets(uid, cfg)
    local a=self.actors[uid]; if not a then return {} end
    local candidates={}
    for id,b in pairs(self.actors) do
        if id~=uid and b.root.Parent and b.humanoid.Health>0 then
            local localP=a.root.CFrame:PointToObjectSpace(b.root.Position)
            local delta=b.root.Position-a.root.Position
            if -localP.Z>=0 and -localP.Z<=cfg.reach and math.abs(localP.X)<=cfg.width and math.abs(localP.Y)<=cfg.height then
                local blocker=Workspace:Raycast(a.root.Position,delta,self.ray)
                if not blocker then candidates[#candidates+1]={id=id,distance=delta.Magnitude} end
            end
        end
    end
    table.sort(candidates,function(a2,b2)
        if a2.distance~=b2.distance then return a2.distance<b2.distance end
        return a2.id<b2.id
    end)
    local result={}; for _,candidate in ipairs(candidates) do result[#result+1]=candidate.id end
    return result
end
function World:impulse(uid, attacker, cfg, profile)
    assert((self.config.Impulses and self.config.Impulses[profile]==cfg) or (cfg and cfg.profile==profile),"Unbound response profile")
    local a,b=self.actors[uid],self.actors[attacker]
    if not a or not b or a.root.Anchored then return end
    local facing=b.root.CFrame.LookVector
    local horizontal=Vector3.new(facing.X,0,facing.Z)
    if horizontal.Magnitude<0.001 then horizontal=Vector3.new(1,0,0) else horizontal=horizontal.Unit end
    a.root:ApplyImpulse((horizontal*cfg.horizontal+Vector3.new(0,cfg.vertical,0))*a.root.AssemblyMass)
end
function World:hazard(uid)
    local a=self.actors[uid]
    if not a or not a.root.Parent then return "ActorMissing" end
    if a.humanoid.Health<=0 then return "EngineDeath" end
    local p=a.root.Position
    if p.Y<self.config.FallY then self.deathReason[uid]="Fall"; return "Fall" end
    for _,offset in ipairs({Vector3.new(),Vector3.new(-0.7,0,-0.35),Vector3.new(0.7,0,0.35)}) do
        local hit=Workspace:Raycast(p+offset,Vector3.new(0,-3.4,0),self.ray)
        if hit then
            self.lastSupport[uid]=hit.Instance:GetAttribute("SurfaceId") or self.lastSupport[uid]
            if hit.Instance:GetAttribute("Hazard") then self.deathReason[uid]="Surface"; return "Surface" end
        end
    end
    return nil
end
function World:kill(uid)
    local a=self.actors[uid]; if not a then return end
    self.origins[uid]=a.root.Position
    a.root.Anchored=false; a.humanoid.Health=0
    for _,p in ipairs(a.model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
end
function World:relocate(uid, point)
    if not self:isSafe(point,uid) then return false end
    local a=self.actors[uid]
    a.model:PivotTo(CFrame.lookAt(point.position,point.position+Vector3.new(1,0,0)))
    a.root.AssemblyLinearVelocity=Vector3.new(); a.root.AssemblyAngularVelocity=Vector3.new()
    self.origins[uid]=point.position; self.deathReason[uid]=nil
    return true
end
function World:observe(uid)
    local a=self.actors[uid]; if not a or not a.root.Parent then return {} end
    local p,v=a.root.Position,a.root.AssemblyLinearVelocity
    return {position={p.X,p.Y,p.Z},velocity={v.X,v.Y,v.Z},held=a.root.Anchored}
end
function World:cue(uid, blocked)
    local a=self.actors[uid]; if not a then return end
    a.cue=a.cue+1; local token=a.cue
    local h=a.model:FindFirstChild("Feedback") or Instance.new("Highlight")
    h.Name="Feedback"; h.FillTransparency=0.35; h.OutlineTransparency=0
    h.FillColor=blocked and Color3.fromRGB(90,175,255) or Color3.fromRGB(255,170,70)
    h.Parent=a.model
    task.delay(0.18,function() if self.actors[uid]==a and a.cue==token then h:Destroy() end end)
end
function World:noSafe(enabled)
    self.blocked=enabled
    for _,floor in ipairs(self.floors) do floor.CanCollide=not enabled end
    self.danger.CanCollide=not enabled
end
function World:pose(uid, x, y, z, yaw)
    local a=assert(self.actors[uid],"No actor")
    a.model:PivotTo(CFrame.new(x,y,z)*CFrame.Angles(0,math.rad(yaw),0))
    a.root.AssemblyLinearVelocity=Vector3.new(); a.root.AssemblyAngularVelocity=Vector3.new()
end
function World:clearActors()
    for _,a in pairs(self.actors) do a.model:Destroy() end
    self.actors={}; self.origins={}; self.lastSupport={}; self.deathReason={}
    self:noSafe(false)
end
return World
