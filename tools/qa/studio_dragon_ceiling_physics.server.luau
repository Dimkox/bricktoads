-- Prepared native physics regression, not a campaign or player playthrough.
-- Run the full file through execute_luau ONLY in the authorized Studio Server.
-- The fixture owns fresh ModuleScripts and two translated GameWorld instances.
-- Baseline uses the pre-guard DragonWorld source embedded below from git e6d9.
-- Fixed starts ordinary lift with its OWN roof noncolliding, enables that roof,
-- then invokes the real guard before the first physics yield. No ChangeState,
-- health write, kill, live campaign reference, input injection, or geometry
-- outside the owned worlds is used. All factory Lighting writes are restored
-- synchronously before yielding. All owned worlds/modules are then destroyed.
local BASELINE_FACTORY_SOURCE = [====[
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
]====]
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),
    'Prepared physics probe requires an authorized running Studio Server')
local HttpService=game:GetService('HttpService')
local Lighting=game:GetService('Lighting')
local Workspace=game:GetService('Workspace')
local ServerStorage=game:GetService('ServerStorage')
local project=assert(game:GetService('ServerScriptService'):FindFirstChild('BrickToads'),'Missing production modules')
local gameplay=assert(project:FindFirstChild('gameplay'),'Missing gameplay modules')
local runtime=assert(project:FindFirstChild('CombatRuntime'),'Missing stand runtime modules')
local fixedSource=gameplay.DragonWorld.Source
assert(string.find(fixedSource,'function World:dragonAscentBlocked',1,true),'Fixed source lacks pure ascent predicate')
assert(not string.find(BASELINE_FACTORY_SOURCE,'ASCENT_BLOCKED',1,true),'Embedded baseline unexpectedly contains guard')
-- GameWorld's normal constructor removes untouched blank-template defaults.
-- Refuse rather than allow the fixture to remove any non-owned object.
for _,object in ipairs(Workspace:GetChildren()) do
    assert(not (object.Name=='Baseplate' and object:IsA('BasePart'))
        and not (object.Name=='SpawnLocation' and object:IsA('SpawnLocation')),
        'Blank-template defaults remain; fixture refuses global constructor cleanup')
end
local id=HttpService:GenerateGUID(false)
local owned=Instance.new('Folder');owned.Name='DragonAscentPhysicsModules_'..id;owned.Parent=ServerStorage
local result={schemaVersion=1,scenario='prepared_native_dragon_ceiling_physics',status='running',
    placeId=game.PlaceId,placeVersion=game.PlaceVersion,studioVersion=version(),
    baselineRevision='e6d9',buildInfoSource=project.BuildInfo.Source,startedAt=DateTime.now():ToIsoDate(),
    preparation={isolatedWorlds=true,realBaseWorldR6=true,initialRootY=-4.04,ceilingBottomY=-2,goalY=4.5,
        offsets={{x=4096,y=100,z=32768},{x=4224,y=100,z=32768}},
        fixedRoofEnabledAfterOrdinaryLiftBeforeFirstPhysics=true,noForcedHumanoidState=true,
        noHealthWrites=true,noKills=true,noSessionOrDirector=true,noActiveCampaignReferences=true},
    limits={'Prepared engine regression only; not a natural encounter or campaign pass',
        'World:hazard classifies a real fall without the fixture committing a death',
        'Domain attack/capture ordering requires separate tests and campaign acceptance'},
    checks={},samples={},calls={}}
local worlds={}
local ownedWorldNames={}
local lightingProperties={'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top',
    'GlobalShadows','FogColor','FogStart','FogEnd'}
local atmosphereProperties={'Density','Offset','Color','Decay','Glare','Haze'}
local lightBefore={}
local atmosphereBefore
local atmosphereValues={}
local lightingDirty=false
local function captureLighting()
    for _,key in ipairs(lightingProperties) do lightBefore[key]=Lighting[key] end
    atmosphereBefore=Lighting:FindFirstChild('CausewayAtmosphere')
    atmosphereValues={}
    if atmosphereBefore then
        assert(atmosphereBefore:IsA('Atmosphere'),'Unexpected global atmosphere object')
        for _,key in ipairs(atmosphereProperties) do atmosphereValues[key]=atmosphereBefore[key] end
    end
end
local function restoreLighting()
    if not lightingDirty then return end
    for _,key in ipairs(lightingProperties) do Lighting[key]=lightBefore[key] end
    local current=Lighting:FindFirstChild('CausewayAtmosphere')
    if atmosphereBefore then
        assert(current==atmosphereBefore,'Factory unexpectedly replaced global atmosphere')
        for _,key in ipairs(atmosphereProperties) do atmosphereBefore[key]=atmosphereValues[key] end
    elseif current then current:Destroy() end
    lightingDirty=false
end
local function check(name,passed,details)
    local row={name=name,passed=passed==true}
    if not passed then row.details=details end
    result.checks[#result.checks+1]=row
    assert(passed,name)
end
local function vector(v) return {x=v.X,y=v.Y,z=v.Z} end
local function sameVector(a,b) return (a-b).Magnitude<1e-7 end
local function module(name,source)
    local item=Instance.new('ModuleScript');item.Name=name;item.Source=source;item.Parent=owned
    return require(item)
end
local function snapshot(row)
    local world,a=row.world,row.actor
    local position=a.root.Position-world.offset
    local rise=4.5+world.offset.Y-a.root.Position.Y
    local hit=rise>0 and Workspace:Raycast(a.root.Position,Vector3.new(0,rise,0),world.ray)
    local force=a.root:FindFirstChild('DragonGravity')
    local hazard=world:hazard(-1)
    return {position=vector(position),velocity=vector(a.root.AssemblyLinearVelocity),health=a.humanoid.Health,
        nativeState=tostring(a.humanoid:GetState()),anchored=a.root.Anchored,
        platformStand=a.humanoid.PlatformStand,evaluateStateMachine=a.humanoid.EvaluateStateMachine,
        autoRotate=a.humanoid.AutoRotate,walkSpeed=a.humanoid.WalkSpeed,
        flightAttribute=a.model:GetAttribute('DragonFlight')==true,flightRow=world.dragonFlights[-1]~=nil,
        forcePresent=force~=nil,force=force and vector(force.Force) or nil,
        attachmentPresent=a.root:FindFirstChild('DragonLift')~=nil,hazard=hazard,
        ray=hit and {part=hit.Instance:GetFullName(),ownRoof=hit.Instance==row.roof,
            position=vector(hit.Position-world.offset),normal=vector(hit.Normal),distance=hit.Distance} or nil}
end
local function motion(row,elapsed)
    local before=row.actor.root.AssemblyLinearVelocity
    local accepted,reason=row.world:dragonMotion(-1,0,0,4.5,10)
    local after=row.actor.root.AssemblyLinearVelocity
    local call={label=row.label,elapsed=elapsed,beforeVelocity=vector(before),afterVelocity=vector(after),
        accepted=accepted==true,returnedNil=accepted==nil,reason=reason,
        fallingVelocityUnchanged=sameVector(before,after)}
    result.calls[#result.calls+1]=call
    if row.label=='fixed' then
        check('fixed request refuses blocked ascent '..#result.calls,accepted==false and reason=='ASCENT_BLOCKED',call)
        if elapsed>0 then
            check('blocked retry preserves integrated native velocity '..#result.calls,sameVector(before,after),call)
        end
    end
    return call
end
local function cleanup()
    local failures={}
    for _,row in ipairs(worlds) do
        local ok,err=pcall(function()
            for slot in pairs(row.world.dragonLinks) do row.world:dragonUnlink(slot) end
            for actorId in pairs(row.world.dragonFlights) do row.world:stopDragon(actorId) end
            row.world.folder:Destroy()
        end)
        if not ok then failures[#failures+1]=tostring(err) end
    end
    for _,name in ipairs(ownedWorldNames) do
        local remaining=Workspace:FindFirstChild(name)
        if remaining then remaining:Destroy() end
    end
    owned:Destroy()
    result.cleanupFailures=failures
    result.cleaned=#failures==0
end
local setupOk,setupError=xpcall(function()
    local Base=module('BaseWorld',runtime.RobloxWorld.Source)
    local makeConfig=require(gameplay.GameConfig)
    local baseConfig=require(runtime.Config)
    local function makeWorld(label,source,offset)
        local World=module(label..'GameWorld',gameplay.GameWorld.Source)
        module(label..'DragonWorld',source)(World)
        local name='DragonAscentPhysics_'..label..'_'..id
        assert(not Workspace:FindFirstChild(name),'Fixture world name already exists')
        ownedWorldNames[#ownedWorldNames+1]=name
        captureLighting();lightingDirty=true
        local world=World.new(Base,makeConfig(baseConfig,nil),{name=name,offset=offset})
        local row={label=label,world=world};worlds[#worlds+1]=row
        -- Restore before another fresh require or any later operation can yield.
        restoreLighting()
        world.geometry:ClearAllChildren()
        local roof=Instance.new('Part');roof.Name='OwnCeiling';roof.Size=Vector3.new(24,2,24)
        roof.CFrame=CFrame.new(0,-1,0)+world.offset;roof.Anchored=true
        roof.CanCollide=label=='baseline';roof:SetAttribute('SurfaceId','NativeDragonOwnRoof')
        roof.Parent=world.geometry;row.roof=roof
        world.floors={roof};world.allFloors={roof}
        check(label..' real R6 spawn',world:spawnEnemy(-1,'Dragon',{x=0,y=-4.04,z=0})==true)
        row.actor=world.actors[-1];row.initialHealth=row.actor.humanoid.Health
        if label=='fixed' then
            check('fixed ordinary clear lift precondition',world:dragonMotion(-1,0,0,4.5,10)==true)
            row.originalForce=world.dragonFlights[-1].force
            roof.CanCollide=true
            local beforePosition=row.actor.root.Position
            local beforeVelocity=row.actor.root.AssemblyLinearVelocity
            check('fixed pure predicate observes own ceiling',world:dragonAscentBlocked(-1,4.5)==true)
            check('pure predicate preserves actual pose and velocity',sameVector(beforePosition,row.actor.root.Position)
                and sameVector(beforeVelocity,row.actor.root.AssemblyLinearVelocity))
            result.fixedBeforeGuard=snapshot(row)
        end
        result[label..'Initial']=snapshot(row)
        motion(row,0)
        result[label..'AfterFirstRequest']=snapshot(row)
        return row
    end
    makeWorld('baseline',BASELINE_FACTORY_SOURCE,{x=4096,y=100,z=32768})
    makeWorld('fixed',fixedSource,{x=4224,y=100,z=32768})
end,debug.traceback)
-- The constructor's global presentation writes must not survive a yield.
local restoreOk,restoreError=pcall(restoreLighting)
result.factoryLightingRestoredBeforeYield=restoreOk
local ok,err=xpcall(function()
    assert(setupOk,setupError)
    assert(restoreOk,restoreError)
    local baseline,fixed=worlds[1],worlds[2]
    check('real upward rays hit each own physical underside',
        result.baselineInitial.ray and result.baselineInitial.ray.ownRoof and result.baselineInitial.ray.normal.y<-.9
        and result.fixedInitial.ray and result.fixedInitial.ray.ownRoof and result.fixedInitial.ray.normal.y<-.9)
    check('fixed removes existing gravity cancellation and restores physics',
        not fixed.originalForce.Parent and not result.fixedAfterFirstRequest.flightRow
        and not result.fixedAfterFirstRequest.forcePresent and not result.fixedAfterFirstRequest.attachmentPresent
        and not result.fixedAfterFirstRequest.platformStand and result.fixedAfterFirstRequest.evaluateStateMachine)
    local start=Workspace:GetServerTimeNow()
    local lastSample=-math.huge
    while Workspace:GetServerTimeNow()-start<.75 do
        RunService.Heartbeat:Wait()
        local elapsed=Workspace:GetServerTimeNow()-start
        assert(elapsed<5,'Native physics observation exceeded deadline')
        for _,row in ipairs(worlds) do
            local observed=snapshot(row)
            check(row.label..' health remains unchanged '..#result.calls,observed.health==row.initialHealth,observed)
            if observed.hazard and not result[row.label..'FirstHazard'] then
                result[row.label..'FirstHazard']={elapsed=elapsed,observation=observed}
            end
            motion(row,elapsed)
        end
        if elapsed-lastSample>=.05 then
            lastSample=elapsed
            result.samples[#result.samples+1]={elapsed=elapsed,baseline=snapshot(baseline),fixed=snapshot(fixed)}
        end
    end
    result.baselineFinal=snapshot(baseline);result.fixedFinal=snapshot(fixed)
    local b,f=result.baselineFinal,result.fixedFinal
    check('baseline remains pinned beneath roof with lift active',b.flightRow and b.forcePresent
        and b.position.y>-6 and b.position.y<-2 and b.hazard==nil,b)
    check('fixed falls physically after at least half a second',
        f.position.y<result.fixedInitial.position.y-6 and f.velocity.y<-10
        and not f.flightRow and not f.forcePresent,f)
    check('fall is classified by ordinary World hazard',
        result.fixedFirstHazard and result.fixedFirstHazard.observation.hazard=='Fall',result.fixedFirstHazard)
    check('no health change was used to produce the distinction',b.health==baseline.initialHealth and f.health==fixed.initialHealth)
end,debug.traceback)
if not ok then result.status='failed';result.error=tostring(err)
else result.status='passed' end
cleanup()
if not result.cleaned then result.status='failed' end
result.finishedAt=DateTime.now():ToIsoDate()
return HttpService:JSONEncode(result)

