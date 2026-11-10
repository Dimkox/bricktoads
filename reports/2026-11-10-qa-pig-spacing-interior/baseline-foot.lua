local Nav=require('./nav')
local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function floorRows(w)return w.testFloors end
local Enum={Material={Air='Air'}}
local function normalize(p)
    p=p or neutral();local x,z=p.x or 0,p.z or 0;local n=math.sqrt(x*x+z*z)
    if n>1 then x,z=x/n,z/n end
    return {x=x,z=z,jump=p.jump==true,primary=p.primary==true,run=p.run==true,aimX=p.aimX,aimZ=p.aimZ}
end
local function foot(ctx,desired,combatPlan)
    local p=ctx.position;local a=ctx.world.actors[ctx.slot]
    if not p or not a then return neutral() end
    local link=a.model and a.model:GetAttribute('DragonLink')
    if link=='Captured' then return neutral() end
    if link=='Mounted' then
        local floor=Nav.currentFloor(p,floorRows(ctx.world))
        if not floor or p.x<floor.minX or p.x>floor.maxX or p.z<floor.minZ or p.z>floor.maxZ
            or p.y<floor.top+3 or p.y>floor.top+12 then
            qa.navigation={phase='Mounted; no safe dismount support',target=p};return neutral()
        end
        if p.x>=floor.minX+3 and p.x<=floor.maxX-3 and p.z>=floor.minZ+3 and p.z<=floor.maxZ-3 then
            qa.navigation={phase='Dismount on authored support',target=p}
            return {x=0,z=0,jump=true,primary=false,run=false}
        end
        local target=point(math.clamp(p.x,floor.minX+3.2,floor.maxX-3.2),floor.top+3,
            math.clamp(p.z,floor.minZ+3.2,floor.maxZ-3.2))
        local dx,dz=target.x-p.x,target.z-p.z;local n=math.max(1,math.sqrt(dx*dx+dz*dz))
        qa.navigation={phase='Move mount onto safe support',target=target}
        return {x=dx/n,z=dz/n,jump=false,primary=false,run=false}
    end
    if ctx.modes and ctx.actor and ctx.actor.finished then
        local dx,dz=desired.x-p.x,desired.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
        local out=combatPlan or neutral()
        if not combatPlan then out.x,out.z=n>.7 and dx/math.max(n,1) or 0,n>.7 and dz/math.max(n,1) or 0 end
        return out
    end
    local planKey=ctx.stageToken..':'..tostring(ctx.slot)
    local state=qa.plans[planKey]
    local hero=ctx.session.state.heroes[ctx.slot]
    if not state or state.actorId~=hero.actorId then state={actorId=hero.actorId};qa.plans[planKey]=state end
    local v=a.root.AssemblyLinearVelocity
    local floors=floorRows(ctx.world)
    local support=Nav.currentFloor(p,floors,state.previousFloor)
    local beyondSupport=support and (desired.x<support.minX or desired.x>support.maxX
        or desired.z<support.minZ or desired.z>support.maxZ)
    local combat=ctx.session.combat[ctx.slot]
    local requested=a.locomotion and a.locomotion.runRequested
    local actualSpeed=math.sqrt(v.X*v.X+v.Z*v.Z)
    local canLaunch=a.humanoid.FloorMaterial~=Enum.Material.Air and not a.humanoid.PlatformStand
        and not combat.reactionEnd and not combat.deathAt and requested and actualSpeed>=18
    local material=a.humanoid.FloorMaterial
    local standing=support and not state.jump and hero.status=='Alive' and hero.connected and not hero.held
        and a.model:GetAttribute('ActorId')==hero.actorId and a.root.Parent and not a.root.Anchored
        and a.humanoid.Health>0 and not a.humanoid.PlatformStand and material and material~=Enum.Material.Air
        and not combat.reactionEnd and not combat.deathAt and math.abs(v.Y)<2
        and p.x>=support.minX and p.x<=support.maxX and p.z>=support.minZ and p.z<=support.maxZ
        and math.abs(p.y-(support.top+3))<.75 and support.maxX-support.minX>6 and support.maxZ-support.minZ>6
    if standing and combatPlan then
        if combatPlan.hold and combat.attack then
            qa.navigation={phase='Hold accepted strike on authored support',target=p}
            return {x=0,z=0,run=false,primary=false,jump=false,hold=true}
        elseif combatPlan.evasion then
            local goal=point(math.clamp(p.x+(combatPlan.x or 0)*6,support.minX+3,support.maxX-3),support.top+3,
                math.clamp(p.z+(combatPlan.z or 0)*6,support.minZ+3,support.maxZ-3))
            local dx,dz=goal.x-p.x,goal.z-p.z;local n=math.max(1,math.sqrt(dx*dx+dz*dz))
            qa.navigation={phase='Evade on authored support',target=goal}
            return {x=dx/n,z=dz/n,run=false,primary=false,jump=false,evasion=true}
        elseif combatPlan.primary==true and combatPlan.run==true and canLaunch and not combat.attack then
            -- Preserve the already validated public running primary, including
            -- facing/run axes. Session still selects and validates its Dash.
            qa.navigation={phase='Running strike on authored support',target=desired}
            return combatPlan
        end
    end
    local nav=Nav.plan(p,desired,floors,state,ctx.now,{grounded=canLaunch,
        vy=v.Y,allowCrossing=true,jumpLead=3.2})
    if nav.phase=='No support' then
        local closest,best
        for _,f in ipairs(floors) do
            local x=math.clamp(p.x,f.minX,f.maxX);local z=math.clamp(p.z,f.minZ,f.maxZ)
            local gap=distance(p,{x=x,z=z})
            if gap<=3 and p.y>=f.top-2 and p.y<=f.top+4 and (not best or gap<best) then closest,best=f,gap end
        end
        if closest then
            nav.target=point(math.clamp(p.x,closest.minX+3,closest.maxX-3),closest.top+3,
                math.clamp(p.z,closest.minZ+3,closest.maxZ-3))
            nav.phase='Recover edge with ordinary input';nav.crossing=true;nav.jump=true
        end
    end
    local out=combatPlan or neutral();local target=nav.target
    -- Adjoining supports need route movement even without a gap. Preserve an
    -- accepted attack or an actual retreat/sidestep from the combat policy.
    local approachNextSupport=beyondSupport and not (combatPlan and (out.primary or out.evasion or out.hold or combat and combat.attack))
    if nav.crossing or nav.attackAllowed~=true or not combatPlan or approachNextSupport then
        local dx,dz=target.x-p.x,target.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
        out.x,out.z=n>.15 and dx/math.max(n,1) or 0,n>.15 and dz/math.max(n,1) or 0
    end
    if nav.attackAllowed~=true then out.primary=false;out.run=false end
    if nav.crossing then out.jump=nav.jump==true;out.run=true else out.jump=out.jump or nav.jump==true end
    qa.navigation={phase=nav.phase,target=target,fault=nav.fault}
    return out
end
return{foot=foot,normalize=normalize,qa=qa,nav=Nav,states=qa.plans}
