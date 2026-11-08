-- Roblox physical boundary for same-body Dragon transport; all coordinates passed in are group-local.
local Workspace=game:GetService('Workspace')
local function living(world,id)
    local a=world.actors[id]
    return a and a.root.Parent and a.humanoid.Health>0 and a or nil
end
local function facing(a)
    local v=a.root.CFrame.LookVector
    if not v then return 1,0 end
    local n=math.sqrt(v.X*v.X+v.Z*v.Z)
    if n<.001 then return 1,0 end
    return v.X/n,v.Z/n
end
return function(World)
    if World.dragonMotion then return World end
    local previousNew,previousMove,previousReaction,previousClear=World.new,World.move,World.setReaction,World.clearActors
    function World.new(...)
        local self=previousNew(...)
        self.dragonFlights,self.dragonLinks,self.dragonFires={},{},{}
        self.dragonOverlap=OverlapParams.new();self.dragonOverlap.FilterType=Enum.RaycastFilterType.Include
        self.dragonOverlap.FilterDescendantsInstances={self.geometry};self.dragonOverlap.RespectCanCollide=true
        self.dragonFireFolder=Instance.new('Folder');self.dragonFireFolder.Name='DragonFire';self.dragonFireFolder.Parent=self.folder
        return self
    end
    function World:dragonFloor(id)
        local a=living(self,id);if not a then return nil end
        local p=a.root.Position
        local hit=Workspace:Raycast(p,Vector3.new(0,-64,0),self.ray)
        if hit and hit.Normal.Y>.9 and not hit.Instance:GetAttribute('Hazard') then return hit.Position.Y-self.offset.Y+3 end
    end
    function World:dragonGrounded(id)
        local a=living(self,id);if not a or a.root.Anchored then return false end
        local hit=Workspace:Raycast(a.root.Position,Vector3.new(0,-3.5,0),self.ray)
        return hit~=nil and hit.Normal.Y>.9 and not hit.Instance:GetAttribute('Hazard')
            and math.abs(a.root.AssemblyLinearVelocity.Y)<2
    end
    function World:dragonCanMount(slot,id,range,height)
        local hero,dragon=living(self,slot),living(self,id)
        if not hero or not dragon or hero.root.Anchored or hero.humanoid.PlatformStand
            or self.dragonLinks[slot] or hero.model:GetAttribute('CarryingEnemy') then return false end
        local delta=dragon.root.Position-hero.root.Position
        if delta.Magnitude>range or math.abs(delta.Y)>height or not self:dragonGrounded(slot) then return false end
        return Workspace:Raycast(hero.root.Position,delta,self.ray)==nil
    end
    function World:dragonMotion(id,x,z,height,speed)
        local a=living(self,id);if not a or a.root.Anchored then return false end
        local row=self.dragonFlights[id]
        if row and row.actor~=a then self:stopDragon(id);row=nil end
        if not row then
            if a.humanoid.PlatformStand then return false end
            self:resetLocomotion(id,a)
            local attachment=Instance.new('Attachment');attachment.Name='DragonLift';attachment.Parent=a.root
            local force=Instance.new('VectorForce');force.Name='DragonGravity';force.Attachment0=attachment
            force.RelativeTo=Enum.ActuatorRelativeTo.World;force.ApplyAtCenterOfMass=true;force.Parent=a.root
            row={actor=a,attachment=attachment,force=force,platformStand=a.humanoid.PlatformStand,
                evaluate=a.humanoid.EvaluateStateMachine,autoRotate=a.humanoid.AutoRotate,walkSpeed=a.humanoid.WalkSpeed}
            self.dragonFlights[id]=row
            if a.root:CanSetNetworkOwnership() then a.root:SetNetworkOwner(nil) end
        end
        a.humanoid.EvaluateStateMachine=false;a.humanoid.PlatformStand=true;a.humanoid.AutoRotate=false;a.humanoid.WalkSpeed=0
        row.force.Force=Vector3.new(0,a.root.AssemblyMass*Workspace.Gravity,0)
        local p=a.root.Position-self.offset
        local bounds=self.config.Level and self.config.Level.bounds
        if bounds then
            if (p.X<=bounds.minX+2 and x<0) or (p.X>=bounds.maxX-2 and x>0) then x=0 end
            if (p.Z<=bounds.minZ+2 and z<0) or (p.Z>=bounds.maxZ-2 and z>0) then z=0 end
        end
        local vertical=math.clamp((height-p.Y)*6,-14,14)
        a.root.AssemblyLinearVelocity=Vector3.new(x*speed,vertical,z*speed)
        a.root.AssemblyAngularVelocity=Vector3.new()
        if x*x+z*z>.001 then
            local origin=a.root.Position;a.root.CFrame=CFrame.lookAt(origin,origin+Vector3.new(x,0,z))
        end
        a.model:SetAttribute('DragonFlight',true)
        return true
    end
    function World:stopDragon(id)
        local row=self.dragonFlights[id];if not row then return end
        self.dragonFlights[id]=nil;row.force:Destroy();row.attachment:Destroy()
        local a=row.actor;a.model:SetAttribute('DragonFlight',nil)
        if a.root.Parent then
            a.humanoid.EvaluateStateMachine=row.evaluate;a.humanoid.PlatformStand=row.platformStand
            a.humanoid.AutoRotate=row.autoRotate;a.humanoid.WalkSpeed=row.walkSpeed
            a.root.AssemblyLinearVelocity=Vector3.new();a.root.AssemblyAngularVelocity=Vector3.new()
        end
    end
    function World:dragonLink(id,slot,mode)
        local dragon,hero=living(self,id),living(self,slot)
        if not dragon or not hero or (mode~='Mounted' and mode~='Captured') then return false end
        local row=self.dragonLinks[slot]
        if row and (row.hero~=hero or row.dragon~=dragon or row.mode~=mode) then return false end
        for other,link in pairs(self.dragonLinks) do if other~=slot and link.dragon==dragon then return false end end
        if not row then
            if hero.root.Anchored then return false end
            self:resetLocomotion(slot,hero)
            row={hero=hero,dragon=dragon,id=id,mode=mode,collisions={},anchored=hero.root.Anchored,
                evaluate=hero.humanoid.EvaluateStateMachine,platformStand=hero.humanoid.PlatformStand,
                autoRotate=hero.humanoid.AutoRotate,walkSpeed=hero.humanoid.WalkSpeed}
            for _,p in ipairs(hero.model:GetDescendants()) do if p:IsA('BasePart') then row.collisions[p]=p.CanCollide;p.CanCollide=false end end
            self.dragonLinks[slot]=row
        end
        -- A previous walking intent must not survive the period of linked physics.
        -- Physical flags are restored on release; voluntary movement is never replayed.
        hero.humanoid:Move(Vector3.new(),false)
        hero.humanoid.EvaluateStateMachine=false;hero.humanoid.PlatformStand=true
        hero.humanoid.AutoRotate=false;hero.humanoid.WalkSpeed=0;hero.root.Anchored=true
        hero.root.AssemblyLinearVelocity=Vector3.new();hero.root.AssemblyAngularVelocity=Vector3.new()
        local p=dragon.root.Position;local x,z=facing(dragon)
        local y=p.Y+(mode=='Mounted' and 3.2 or -2.4)
        if mode=='Captured' then local floor=self:dragonFloor(id);if floor then y=math.max(y,floor+self.offset.Y) end end
        local position=Vector3.new(p.X,y,p.Z)
        hero.model:PivotTo(CFrame.lookAt(position,position+Vector3.new(x,0,z)))
        hero.model:SetAttribute('DragonLink',mode);hero.model:SetAttribute('DragonId',id)
        return true
    end
    function World:dragonUnlink(slot,jump)
        local row=self.dragonLinks[slot];if not row then return false end
        self.dragonLinks[slot]=nil
        local a=row.hero;a.model:SetAttribute('DragonLink',nil);a.model:SetAttribute('DragonId',nil)
        self:resetLocomotion(slot,a)
        if a.root.Parent then
            a.humanoid:Move(Vector3.new(),false)
            a.root.Anchored=row.anchored;a.humanoid.EvaluateStateMachine=row.evaluate
            a.humanoid.PlatformStand=row.platformStand;a.humanoid.AutoRotate=row.autoRotate;a.humanoid.WalkSpeed=row.walkSpeed
            for p,value in pairs(row.collisions) do if p.Parent then p.CanCollide=a.humanoid.Health>0 and value or false end end
            if a.root:CanSetNetworkOwnership() then a.root:SetNetworkOwner(nil) end
            if jump and a.humanoid.Health>0 and not row.anchored and not row.platformStand then
                local velocity=row.dragon.root.Parent and row.dragon.root.AssemblyLinearVelocity or Vector3.new()
                a.root.AssemblyLinearVelocity=Vector3.new(velocity.X,18,velocity.Z)
            end
        end
        return true
    end
    function World:hold(id,held)
        if held then self:resetLocomotion(id) end
        local row=self.dragonLinks[id]
        if row then row.anchored=held;return end
        self._base.hold(self,id,held)
    end
    function World:move(id,x,z,runRequested)
        if self.dragonLinks[id] or self.dragonFlights[id] then return end
        previousMove(self,id,x,z,runRequested)
    end
    function World:setReaction(id,active)
        local row=self.dragonLinks[id]
        if row then
            if active then self:resetLocomotion(id,row.hero) end
            row.platformStand=active;row.autoRotate=not active;row.walkSpeed=active and 0 or self.config.WalkSpeed
            return
        end
        previousReaction(self,id,active)
    end
    function World:kill(id)
        self:resetLocomotion(id)
        self:dragonUnlink(id)
        for slot,row in pairs(self.dragonLinks) do if row.id==id then self:dragonUnlink(slot) end end
        self:stopDragon(id)
        self._base.kill(self,id)
    end
    function World:dragonMuzzle(id)
        local a=living(self,id);if not a then return nil end
        local p=self:position(id);local x,z=facing(a)
        local origin=Vector3.new(p.x,p.y+.25,p.z)+self.offset
        local reach=Vector3.new(x*2.8,0,z*2.8)
        local radius=self.config.DragonFlight and self.config.DragonFlight.fireRadius or 1
        local blocked=#Workspace:GetPartBoundsInRadius(origin,radius,self.dragonOverlap)>0
            or Workspace:Spherecast(origin,radius,reach,self.ray)~=nil
        return {x=p.x+x*2.8,y=p.y+.25,z=p.z+z*2.8},{x=x,y=0,z=z},blocked
    end
    function World:dragonFire(id,position)
        local p=self.dragonFires[id]
        if not p then
            p=Instance.new('Part');p.Name='Fire_'..id;p.Shape=Enum.PartType.Ball;p.Size=Vector3.new(1.3,1.3,1.3)
            p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
            p.Material=Enum.Material.Neon;p.Color=Color3.fromRGB(255,174,55);p.Parent=self.dragonFireFolder
            self.dragonFires[id]=p
        end
        p.CFrame=CFrame.new(Vector3.new(position.x,position.y,position.z)+self.offset)
    end
    function World:removeDragonFire(id)
        local p=self.dragonFires[id];if p then p:Destroy();self.dragonFires[id]=nil end
    end
    function World:dragonFireTargets(from,to,radius,exclude)
        local origin=Vector3.new(from.x,from.y,from.z)+self.offset
        local delta=Vector3.new(to.x-from.x,to.y-from.y,to.z-from.z)
        local length=delta.Magnitude;local length2=length*length
        if #Workspace:GetPartBoundsInRadius(origin,radius,self.dragonOverlap)>0 then return {},true end
        local wall=length>0 and Workspace:Spherecast(origin,radius,delta,self.ray) or nil
        local limit=wall and math.min(1,wall.Distance/length) or 1
        local candidates={}
        for id in pairs(self.actors) do
            local a=living(self,id)
            if a and not exclude[id] then
                local p=a.root.Position-origin
                local raw=length2>0 and (p.X*delta.X+p.Y*delta.Y+p.Z*delta.Z)/length2 or 0
                local expanded=radius+2
                local distance2=p.X*p.X+p.Y*p.Y+p.Z*p.Z
                local entry
                if distance2<=expanded*expanded then entry=0
                elseif length2>0 then
                    local dot=p.X*delta.X+p.Y*delta.Y+p.Z*delta.Z
                    local discriminant=dot*dot-length2*(distance2-expanded*expanded)
                    if discriminant>=0 then entry=(dot-math.sqrt(discriminant))/length2 end
                end
                if entry and entry>=0 and entry<=limit and (not wall or raw<=limit) then
                    candidates[#candidates+1]={id=id,t=entry}
                end
            end
        end
        table.sort(candidates,function(a,b) if a.t~=b.t then return a.t<b.t end;return a.id<b.id end)
        local result={};for _,row in ipairs(candidates) do result[#result+1]=row.id end
        return result,wall~=nil
    end
    function World:clearActors()
        for slot in pairs(self.dragonLinks) do self:dragonUnlink(slot) end
        for id in pairs(self.dragonFlights) do self:stopDragon(id) end
        for id in pairs(self.dragonFires) do self:removeDragonFire(id) end
        previousClear(self)
    end
    return World
end
