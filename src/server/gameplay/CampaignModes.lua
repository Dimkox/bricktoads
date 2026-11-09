-- Server-owned course simulation. Layouts and all numeric tuning are original
-- Roblox adaptation; reference evidence establishes the distinct mode families.
-- This module moves existing actors only. Session owns health, lives and spawns.
local Modes={};Modes.__index=Modes
local FIXED=1/60
local INPUT_TIMEOUT=.35
local BODY={x=1.6,y=2.5,z=1.2}
local function sourceModule(name)
    if script then return require(script.Parent[name]) end
    return require('./'..name)
end
local function copy(t) if type(t)~='table' then return t end;local r={};for k,v in pairs(t) do r[k]=copy(v) end;return r end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function point(x,y,z) return {x=x,y=y,z=z or 0} end
local function dist(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function inside(p,v)
    return p.x>=v.minX and p.x<=v.maxX and p.y>=v.minY and p.y<=v.maxY and p.z>=v.minZ and p.z<=v.maxZ
end
local function normalized(x,z) local n=math.sqrt(x*x+z*z);if n>1 then return x/n,z/n end;return x,z end
local function size(h) return {w=h.w,h=h.h,d=h.d} end
local function center(h) return point(h.x,h.y,h.z) end
-- Segment/expanded-AABB slab intersection prevents thin obstacle tunnelling.
local function swept(a,b,h,oldCenter)
    local old=oldCenter or center(h);local current=center(h)
    local t0,t1=0,1
    for _,axis in ipairs({'x','y','z'}) do
        local ext=(axis=='x' and h.w or (axis=='y' and h.h or h.d))/2+BODY[axis]
        local start=a[axis]-old[axis];local delta=b[axis]-current[axis]-start
        if math.abs(delta)<1e-8 then if start < -ext or start > ext then return false end
        else
            local lo,hi=(-ext-start)/delta,(ext-start)/delta
            if lo>hi then lo,hi=hi,lo end
            t0=math.max(t0,lo);t1=math.min(t1,hi);if t0>t1 then return false end
        end
    end
    return t1>=0 and t0<=1
end
local function motionPosition(h,t)
    local p=center(h);local m=h.motion
    if m then
        local wave=(t/(m.period or 3)*math.pi*2)+(m.phase or 0)
        if m.axis=='orbit' then p.x=math.cos(wave)*(m.radius or 23);p.z=math.sin(wave)*(m.radius or 23)
        elseif m.axis then p[m.axis]=p[m.axis]+math.sin(wave)*(m.amplitude or 0) end
    end
    return p
end
local function pathPosition(def,t)
    local path=def.path;local total=0;local lengths={}
    for i=1,#path do local n=i%#path+1;lengths[i]=dist(path[i],path[n]);total+=lengths[i] end
    local travel=(t*def.speed)%total
    for i,length in ipairs(lengths) do
        if travel<=length then
            local a,b=path[i],path[i%#path+1];local f=length==0 and 0 or travel/length
            return point(a.x+(b.x-a.x)*f,a.y+(b.y-a.y)*f,a.z+(b.z-a.z)*f)
        end
        travel-=length
    end
    return copy(path[1])
end
function Modes.new(session,world,definition)
    assert(session and world and definition and definition.course,'A campaign course is required')
    local self=setmetatable({session=session,world=world,definition=definition,course=definition.course,mode=definition.mode,
        actors={},supports={},blocks={},hazards={},objects={},now=session.now or 0,elapsed=0,discardedSeconds=0,
        complete=false,closed=false,room=1,bombIndex=1,race=definition.mode=='Race' and {elapsed=0} or nil,rotation=0,chaseLife=definition.course.chaseLife or 207,
        broken={},chaseProgress=-(definition.course.chaseGap or 32),projectiles={},emitterNext={},projectileSerial=0,
        encounterFired={},vehicleGroup=definition.course.mount and {phase='Mounting',checkpoint=1,elapsed=0,speed=0,serial=0} or nil},Modes)
    for _,support in ipairs(self.course.supports or {}) do
        self.supports[#self.supports+1]={id=support.id,definition=support,position=pathPosition(support,0),previous=pathPosition(support,0)}
        for segment=2,support.segments or 1 do
            local phase=-(segment-1)*(support.segmentSpacing or 6)/support.speed
            self.supports[#self.supports+1]={id=support.id..'-segment-'..segment,definition=support,phase=phase,
                position=pathPosition(support,phase),previous=pathPosition(support,phase)}
        end
    end
    for _,support in ipairs(self.course.lifts or {}) do
        self.supports[#self.supports+1]={id=support.id,definition=support,position=pathPosition(support,0),previous=pathPosition(support,0)}
    end
    for _,block in ipairs(self.course.blocks or {}) do
        self.blocks[#self.blocks+1]={id=block.id,definition=block,position=copy(block.position),previous=copy(block.position)}
    end
    self:_syncActors();self:_objects(0)
    if self.mode=='Race' then self.race=sourceModule('CampaignRace').new(session,world,definition) end
    return self
end
function Modes:_object(id,kind,p,dimensions,metadata)
    self.objects[id]=true
    if self.world.campaignObject then self.world:campaignObject(id,kind,p,dimensions,metadata or {}) end
end
function Modes:_log(kind,slot,data)
    if self.session._record then self.session:_record(kind,slot,data,self.now) end
end
function Modes:_living(slot)
    local h=self.session.state.heroes[slot];local combat=self.session.combat[slot]
    local emergency=h and h.shield and h.shield.kind=='Emergency' and self.now<h.shield.deadline
    return h and h.status=='Alive' and not emergency and combat and not combat.deathAt and self.world:position(slot)~=nil
end
function Modes:_emergencyHeld(slot)
    local hero=self.session.state.heroes[slot];local combat=self.session.combat[slot]
    return hero and hero.status=='Alive' and combat and not combat.deathAt and hero.shield
        and hero.shield.kind=='Emergency' and self.now<hero.shield.deadline
end
function Modes:_controlled(slot)
    local h=self.session.state.heroes[slot];local c=self.session.combat[slot]
    return self:_living(slot) and h.connected~=false and not c.reactionEnd
end
function Modes:_special(s)
    if s.finished then return false end
    if self.mode=='Finale' then return false end
    if self.mode=='Speeder' or self.mode=='Surf' or self.mode=='Jet' then return s.mounted end
    return true
end
function Modes:_slotOffset(slot)
    for n,id in ipairs(self.session.order) do if id==slot then return (n-(#self.session.order+1)/2)*4 end end
    return 0
end
function Modes:respawnPosition(slot)
    local s=self.actors[slot];local index=s and s.checkpoint or 1
    if self.vehicleGroup and s and s.mounted and not s.finished then index=self.vehicleGroup.checkpoint end
    local cp=self.course.checkpoints[index]
    local p=copy(cp and cp.position or self.definition.spawn)
    if s and s.finished then
        local arena=self.definition.boss.platform;p=point(arena.x-15,arena.y+arena.h/2+3,arena.z)
    elseif self.mode=='Tower' and cp then
        for _,support in ipairs(self.course.towerPlatforms) do if math.abs(support.y-cp.progress)<.001 then
            local angle=support.angle+self.rotation;p=point(math.cos(angle)*support.radius,support.y+3,math.sin(angle)*support.radius);break
        end end
    end
    p.z+=self:_slotOffset(slot)
    return p
end
function Modes:_syncActors()
    for _,slot in ipairs(self.session.order) do
        local h=self.session.state.heroes[slot]
        local current=self.actors[slot]
        if self:_emergencyHeld(slot) then
            -- Session alone owns the held pose and its safe release. Remember
            -- the transition without touching the native body or its resources.
            if current then current.emergencyHeld=true;current.input={x=0,z=0,run=false,at=-math.huge} end
        elseif h and self:_living(slot) then
            local s=self.actors[slot]
            if not s or s.actorId~=h.actorId or s.attempt~=h.attempt then
                local before=s;local target=before and self:respawnPosition(slot) or self.world:position(slot) or self.definition.spawn
                s={slot=slot,actorId=h.actorId,attempt=h.attempt,position=copy(target),previous=copy(target),
                    velocity=point(0,0,0),input={x=0,z=0,run=false,at=-math.huge},checkpoint=before and before.checkpoint or 1,
                    grounded=false,mounted=before and before.mounted or false,progress=before and before.savedProgress or 0,finished=before and before.finished or false,
                    segment=1,segmentProgress=0,chaser=-(self.course.chaseGap or 32),oxygen=self.course.oxygenSeconds or 18,medium='Dry'}
                if self.mode=='Clinger' then s.chaser=-(self.course.chaseGap or 32) end
                self.actors[slot]=s
                if before and s.mounted and self.vehicleGroup and self.vehicleGroup.phase=='AwaitingRespawn' then
                    -- Session's committed attempt may resume a pending cohort;
                    -- a genuinely lost cohort never creates another attempt.
                    self.vehicleGroup.phase='Stopped';self.vehicleGroup.phaseElapsed=0;self.vehicleGroup.speed=0;self.vehicleGroup.elapsed=0
                end
                if before and self.mode=='Clinger' and self.chaseNeedsReset then
                    self.chaseProgress=-(self.course.chaseGap or 32);self.chaseNeedsReset=nil
                end
                if before then self:_log('CampaignCheckpointRespawn',slot,{checkpoint=s.checkpoint,mode=self.mode}) end
                self:_ground(s,s.position,0)
                if self:_special(s) and self.world.campaignPose then self.world:campaignPose(slot,s.position,self.mode,s.velocity) end
            elseif s.emergencyHeld then
                -- A same-body safe relocation is just as valid as a new paid
                -- attempt. Start from Session's released world pose, never the
                -- stale position from before the emergency hold.
                s.emergencyHeld=nil;s.position=copy(self.world:position(slot));s.previous=copy(s.position)
                s.velocity=point(0,0,0);s.external=nil;s.input={x=0,z=0,run=false,at=-math.huge}
                self:_ground(s,s.position,0)
            end
        end
    end
end
function Modes:move(slot,x,z,run)
    local s=self.actors[slot]
    if self.closed or not s or not self:_special(s) then return false end
    if not finite(x) or not finite(z) then return true end
    x,z=normalized(x,z)
    if not self:_controlled(slot) or (s.mounted and self.vehicleGroup and self.vehicleGroup.phase~='Riding') then x,z,run=0,0,false end
    s.input={x=x,z=z,run=run==true,at=self.now}
    return true
end
function Modes:jump(slot)
    local s=self.actors[slot]
    if self.closed or not s or not self:_special(s) then return false end
    if not self:_controlled(slot) then return true end
    if s.mounted and self.vehicleGroup and self.vehicleGroup.phase~='Riding' then return true end
    if self.mode=='Rope' then
        s.velocity.x+=s.input.x*9;s.velocity.z+=s.input.z*9
    elseif self.mode=='Jet' then
        -- Flight lift is a bounded impulse, never a ground double-jump.
        s.velocity.y=math.min(15,s.velocity.y+5)
    elseif self.mode=='Clinger' then
        return true
    elseif s.medium=='Water' then
        s.velocity.y=math.min(18,s.velocity.y+10)
    elseif s.grounded then
        s.airSpeed=(s.input.run and 24 or self.course.maxSpeed) or 16
        s.velocity.y=self.course.jumpSpeed or 51;s.grounded=false;s.support=nil
        if self.mode=='Ascent' or self.mode=='Tower' then for _,spring in ipairs(self.course.springs or {}) do
            if math.abs(s.position.x-spring.x)<=spring.w/2+1 and math.abs(s.position.y-spring.y)<=4 and math.abs(s.position.z-spring.z)<=spring.d/2 then
                s.velocity.y=spring.power
            end
        end end
        self:_log('CampaignJump',slot,{mode=self.mode})
    end
    return true
end
function Modes:impulse(slot,velocity)
    local s=self.actors[slot]
    if self.closed or not s or not self:_special(s) or not self:_living(slot) then return false end
    if not velocity or not finite(velocity.x) or not finite(velocity.y) or not finite(velocity.z) then return false end
    if s.mounted and self.vehicleGroup and self.vehicleGroup.phase~='Riding' then return true end
    s.external=point(clamp(velocity.x,-60,60),0,clamp(velocity.z,-60,60))
    s.velocity.y=clamp(velocity.y,-70,70);s.grounded=false;s.support=nil
    return true
end
function Modes:isRunning(slot)
    local s=self.actors[slot]
    if not s or not self:_special(s) or not self:_controlled(slot) or not s.grounded or s.medium=='Water'
        or self.mode=='Rope' or self.mode=='Clinger' or self.course.mount then return false end
    local input=self:_input(s)
    if not input.run then return false end
    local x,z=input.x,input.z
    if self.mode=='Tower' then local angle=math.atan2(s.position.z,s.position.x);x,z=-math.sin(angle)*input.x,math.cos(angle)*input.x end
    return s.velocity.x*x+s.velocity.z*z>=18
end
function Modes:_input(s)
    if not self:_controlled(s.slot) or self.now-s.input.at>INPUT_TIMEOUT then s.input.x=0;s.input.z=0;s.input.run=false end
    return s.input
end
function Modes:_ground(s,previous,dt)
    local candidate=-math.huge;local supportId=nil
    local function check(p,id,stepHeight)
        local top=p.y+p.h/2+3
        local dx,dz=s.position.x-p.x,s.position.z-p.z
        if p.yaw then local a=p.yaw;dx,dz=dx*math.cos(a)-dz*math.sin(a),dx*math.sin(a)+dz*math.cos(a) end
        if math.abs(dx)<=p.w/2 and math.abs(dz)<=p.d/2
            and previous.y>=top-((s.grounded and stepHeight) or .4) and s.position.y<=top+.12 and s.velocity.y<=0 and top>candidate then candidate=top;supportId=id end
    end
    if self.mode=='Tower' then
        for n,p in ipairs(self.course.towerPlatforms or {}) do
            local angle=p.angle+self.rotation;check({x=math.cos(angle)*p.radius,y=p.y-1,z=math.sin(angle)*p.radius,w=p.w,h=2,d=p.d,yaw=-angle},'tower-'..n)
        end
    else for n,p in ipairs(self.course.platforms or {}) do check(p,'floor-'..n) end end
    for _,support in ipairs(self.supports) do
        local p=support.position;local def=support.definition
        -- Adjacent body segments overlap horizontally and form a shallow slope.
        -- Ordinary stepping across their small top differences preserves the
        -- carry; static room ledges still require the player's explicit jump.
        check({x=p.x,y=p.y,z=p.z,w=def.w,h=def.h,d=def.d},support.id,def.kind=='Serpent' and 1.5 or nil)
    end
    for _,block in ipairs(self.blocks) do local p,def=block.position,block.definition
        check({x=p.x,y=p.y,z=p.z,w=def.w,h=def.h,d=def.d},block.id)
    end
    if candidate>-math.huge then s.position.y=candidate;s.velocity.y=0;s.grounded=true;s.support=supportId;s.airSpeed=nil
    elseif dt>0 then s.grounded=false;s.support=nil end
end
function Modes:_carry(s)
    if not s.grounded or not s.support then return end
    if self.mode=='Tower' and string.sub(s.support,1,6)=='tower-' then
        local a=self.rotation-self.previousRotation
        local x,z=s.position.x,s.position.z;s.position.x=x*math.cos(a)-z*math.sin(a);s.position.z=x*math.sin(a)+z*math.cos(a)
    end
    for _,support in ipairs(self.supports) do if support.id==s.support then
        s.position.x+=support.position.x-support.previous.x;s.position.y+=support.position.y-support.previous.y;s.position.z+=support.position.z-support.previous.z
    end end
    for _,block in ipairs(self.blocks) do if block.id==s.support then
        s.position.x+=block.position.x-block.previous.x;s.position.z+=block.position.z-block.previous.z
    end end
end
function Modes:_blockCollision(s,previous,input)
    for _,block in ipairs(self.blocks) do
        local p,def=block.position,block.definition
        local horizontal=def.w/2+BODY.x
        if math.abs(s.position.z-p.z)<def.d/2+BODY.z and s.position.y-3<p.y+def.h/2-.05 and s.position.y+2>p.y-def.h/2 then
            local direction=s.position.x>previous.x and 1 or -1
            local crossing=(direction==1 and previous.x<=p.x-horizontal+.1 and s.position.x>p.x-horizontal)
                or (direction==-1 and previous.x>=p.x+horizontal-.1 and s.position.x<p.x+horizontal)
            if crossing then
                if s.grounded and input.x*direction>.1 then p.x=clamp(p.x+s.position.x-previous.x,def.minX,def.maxX) end
                s.position.x=p.x-direction*horizontal;s.velocity.x=0
            end
        end
    end
end
function Modes:_platforming(s,dt)
    local input=self:_input(s);self:_carry(s)
    local old=copy(s.position);local c=self.course
    local medium='Dry';local current
    for _,water in ipairs(c.media or {}) do if inside(s.position,water) then medium='Water';current=water.current;break end end
    s.medium=medium
    if medium=='Water' then
        local accel=c.swimAcceleration or 28;local max=c.swimSpeed or 15
        s.velocity.x=clamp(s.velocity.x+input.x*accel*dt,-max,max)*math.exp(-1.4*dt)
        s.velocity.z*=math.exp(-3*dt)
        s.velocity.y=clamp(s.velocity.y-input.z*accel*dt+3*dt,-max,max)*math.exp(-1.2*dt)
        if current then
            -- Current is an environmental force. It never writes accepted input
            -- or chooses a route, and can be opposed with ordinary swim steering.
            s.velocity.x=clamp(s.velocity.x+(current.x or 0)*dt,-max,max)
            s.velocity.y=clamp(s.velocity.y+(current.y or 0)*dt,-max,max)
            s.velocity.z=clamp(s.velocity.z+(current.z or 0)*dt,-max,max)
        end
        s.grounded=false;s.support=nil
        s.oxygen-=dt
        if s.oxygen<=0 then self:_die(s,'CampaignDrowned');return end
    else
        s.oxygen=c.oxygenSeconds or 18
        local max=s.airSpeed or ((input.run and 24 or c.maxSpeed) or 16)
        if self.mode=='Ice' then
            s.velocity.x=clamp(s.velocity.x+input.x*c.acceleration*dt,-max,max)
            s.velocity.z=clamp(s.velocity.z+input.z*c.acceleration*dt,-max,max)
            local friction=math.exp(-c.friction*dt*.18)
            s.velocity.x*=friction;s.velocity.z*=friction
        elseif self.mode=='Tower' then
            local theta=math.atan2(s.position.z,s.position.x);local tangent=input.x*max
            local radial=input.z*8
            s.velocity.x=-math.sin(theta)*tangent+math.cos(theta)*radial
            s.velocity.z=math.cos(theta)*tangent+math.sin(theta)*radial
            local wind=math.sin(self.elapsed*.8+(c.windPhase or 0))*c.windForce
            s.velocity.x+=math.cos(theta)*wind;s.velocity.z+=math.sin(theta)*wind
        else s.velocity.x=input.x*max;s.velocity.z=input.z*max end
        s.velocity.y-= (c.gravity or 150)*dt
        for _,fan in ipairs(c.fans or {}) do
            if math.abs(s.position.x-fan.x)<=fan.w/2 and math.abs(s.position.y-fan.y)<=fan.h/2 and math.abs(s.position.z-fan.z)<=fan.d/2 then
                s.velocity.y=math.min(32,s.velocity.y+fan.force*dt)
            end
        end
    end
    s.position.x+=s.velocity.x*dt;s.position.y+=s.velocity.y*dt;s.position.z+=s.velocity.z*dt
    self:_blockCollision(s,old,input)
    self:_wallCollision(s,old)
    if medium=='Water' then
        -- Pipe mouths allow vertical surface breaches; swimming can jump out.
        for _,water in ipairs(c.media or {}) do if inside(old,water) then
            s.position.z=clamp(s.position.z,water.minZ+BODY.z,water.maxZ-BODY.z)
        end end
    end
    self:_ground(s,old,dt)
end
function Modes:_wallCollision(s,old)
    for _,wall in ipairs(self.walls or {}) do
        if swept(old,s.position,wall,wall.previous) then
            local before=wall.previous;local axis,side
            for _,a in ipairs({'x','z','y'}) do
                local extent=(a=='x' and wall.w or (a=='y' and wall.h or wall.d))/2+BODY[a]
                if old[a]<=before[a]-extent+.01 then axis,side=a,-1;break end
                if old[a]>=before[a]+extent-.01 then axis,side=a,1;break end
            end
            if axis then
                local extent=(axis=='x' and wall.w or (axis=='y' and wall.h or wall.d))/2+BODY[axis]
                s.position[axis]=wall[axis]+side*(extent+.01);s.velocity[axis]=0
            else self:_die(s,'CampaignCrushed');return end
        end
    end
end
function Modes:_rope(s,dt)
    local input=self:_input(s);local c=self.course
    s.velocity.x=(s.velocity.x+input.x*c.swingAcceleration*dt)*math.exp(-c.swingDamping*dt)
    s.velocity.z=(s.velocity.z+input.z*c.swingAcceleration*dt)*math.exp(-c.swingDamping*dt)
    s.position.x=clamp(s.position.x+s.velocity.x*dt,-c.swingLimit,c.swingLimit)
    s.position.z=clamp(s.position.z+s.velocity.z*dt,-c.swingLimit,c.swingLimit)
    s.velocity.y=-c.descentSpeed;s.position.y+=s.velocity.y*dt
    s.progress=self.definition.spawn.y-s.position.y
    self:_object('rope-'..s.slot,'Rope',point(s.position.x,(c.anchor.y+s.position.y)/2,s.position.z),
        {w=.2,h=math.max(1,c.anchor.y-s.position.y),d=.2},{collidable=false,label='Rope',anchor=c.anchor,endpoint=copy(s.position)})
end
function Modes:_vehicle(s,dt)
    local input=self:_input(s);local c=self.course
    local group=self.vehicleGroup
    if group.phase~='Riding' then
        s.velocity=point(0,0,0)
        self:_object('vehicle-'..s.slot,self.mode=='Surf' and 'Surfboard' or self.mode,point(s.position.x,s.position.y-2.6,s.position.z),
            {w=6,h=.9,d=3},{collidable=false,role='Vehicle'})
        return
    end
    local speed=group.speed
    local oldX=s.position.x
    s.velocity.x=speed+input.x*5;s.position.x+=s.velocity.x*dt
    if self.mode=='Jet' then
        -- Right/left adjust relative forward speed; up/down adjust altitude.
        s.velocity.z=0
        s.velocity.y=clamp(s.velocity.y-input.z*48*dt,-17,17)*math.exp(-2*dt)
        s.position.y=clamp(s.position.y+s.velocity.y*dt,c.altitudeMin,c.altitudeMax)
    else
        s.velocity.z=input.z*c.steerSpeed;s.position.z=clamp(s.position.z+s.velocity.z*dt,-c.laneLimit,c.laneLimit)
        for _,ramp in ipairs(c.ramps or {}) do
            if s.grounded and oldX<ramp.x and s.position.x>=ramp.x and math.abs(s.position.z-ramp.z)<=ramp.d/2 then
                s.velocity.y=ramp.launchSpeed;s.grounded=false;self:_log('CampaignRamp',s.slot,{ramp=ramp.id})
            end
        end
        s.velocity.y-=100*dt;s.position.y+=s.velocity.y*dt
        if s.position.y<=3 then s.position.y=3;s.velocity.y=0;s.grounded=true else s.grounded=false end
        if self.mode=='Surf' then s.position.z=clamp(s.position.z+math.sin(self.elapsed*.9)*2*dt,-c.laneLimit,c.laneLimit) end
    end
    s.progress=s.position.x-c.mount.x
    self:_object('vehicle-'..s.slot,self.mode=='Surf' and 'Surfboard' or self.mode,point(s.position.x,s.position.y-2.6,s.position.z),
        {w=6,h=.9,d=3},{collidable=false,role='Vehicle'})
end
function Modes:_vehicleSurvivors()
    local riders={}
    for _,slot in ipairs(self.session.order) do local actor=self.actors[slot]
        local hero=self.session.state.heroes[slot]
        if actor and actor.mounted and not actor.finished and self:_living(slot)
            and actor.actorId==hero.actorId and actor.attempt==hero.attempt then riders[#riders+1]=actor end
    end
    return riders
end
function Modes:_vehicleHasRetry()
    if self.session.state.status~='Active' then return false end
    for _,slot in ipairs(self.session.order) do local actor=self.actors[slot];local hero=self.session.state.heroes[slot]
        -- Alive includes an emergency-held body, a dying animation, or a paid
        -- spawn not yet synchronized by this mode. Each still belongs to the
        -- active Session; waiting does not grant a respawn or release its hold.
        if actor and actor.mounted and not actor.finished and hero
            and (hero.status=='AwaitingRespawn' or hero.status=='Alive') then return true end
    end
    return false
end
function Modes:_vehicleDeath(s)
    if s.vehicleDeathObserved then return end
    s.vehicleDeathObserved=true;self:_vehicleCrash(s.slot)
end
function Modes:_vehicleDeaths()
    if not self.vehicleGroup then return end
    for _,slot in ipairs(self.session.order) do local s=self.actors[slot]
        if s and s.mounted and not s.finished then
            local hero=self.session.state.heroes[slot];local combat=self.session.combat[slot]
            if hero and (hero.status~='Alive' or hero.actorId~=s.actorId or hero.attempt~=s.attempt or (combat and combat.deathAt)) then
                -- Session may commit an engine/combat death and its paid next
                -- spawn between mode steps. Observe the old attempt once;
                -- never call Session:_die again for that lifecycle transition.
                self:_vehicleDeath(s)
            end
        end
    end
end
function Modes:_vehicleCrash(slot)
    local group=self.vehicleGroup
    if not group then return end
    local survivors=self:_vehicleSurvivors()
    if group.phase=='Stopped' or group.phase=='Rewinding' or group.phase=='AwaitingRespawn' then
        if #survivors==0 then group.phase=self:_vehicleHasRetry() and 'AwaitingRespawn' or 'Lost' end
        return
    end
    group.phase=#survivors>0 and 'Stopped' or (self:_vehicleHasRetry() and 'AwaitingRespawn' or 'Lost')
    group.phaseElapsed=0;group.speed=0;group.elapsed=0;group.serial+=1
    group.rewindFrom=copy(self.actors[slot].position);group.rewindTo=self:respawnPosition(survivors[1] and survivors[1].slot or slot)
    group.start={}
    for _,rider in ipairs(survivors) do
        group.start[rider.slot]=copy(rider.position);rider.velocity=point(0,0,0);rider.external=nil
        rider.input={x=0,z=0,run=false,at=-math.huge};rider.airSpeed=nil
    end
    local checkpoint=self.course.checkpoints[group.checkpoint];local replayIds={}
    for _,event in ipairs(self.course.encounters or {}) do
        if event.progress>=checkpoint.progress then self.encounterFired[event.id]=nil;replayIds[#replayIds+1]=event.id end
    end
    if self.resetEncounters then self.resetEncounters({checkpoint=group.checkpoint,progress=checkpoint.progress,serial=group.serial,
        elapsed=self.elapsed,phase=group.phase,replayIds=replayIds}) end
    self:_log('CampaignGroupStopped',slot,{checkpoint=group.checkpoint,serial=group.serial,mode=self.mode})
end
function Modes:_vehicleGroupStep(dt)
    local group=self.vehicleGroup;if not group then return end
    local riders=self:_vehicleSurvivors()
    if group.phase=='AwaitingRespawn' then
        if #riders>0 then group.phase='Stopped';group.phaseElapsed=0;group.start=group.start or {}
        elseif not self:_vehicleHasRetry() then group.phase='Lost' end
    elseif group.phase=='Riding' then
        if #riders==0 then group.phase=self:_vehicleHasRetry() and 'AwaitingRespawn' or 'Lost';group.speed=0;return end
        group.elapsed+=dt
        local target=math.min(self.course.maxSpeed,self.course.speed+group.elapsed*self.course.acceleration)
        group.speed=math.min(target,group.speed+(self.course.restart.acceleration or 110)*dt)
    elseif group.phase=='Stopped' or group.phase=='Rewinding' then
        if #riders==0 then group.phase=self:_vehicleHasRetry() and 'AwaitingRespawn' or 'Lost';group.speed=0;return end
        group.start=group.start or {}
        for _,rider in ipairs(riders) do
            if not group.start[rider.slot] then group.start[rider.slot]=copy(rider.position) end
        end
        local restart=self.course.restart;group.phaseElapsed+=dt
        if group.phase=='Stopped' and group.phaseElapsed>=restart.stopSeconds then
            group.phase='Rewinding';group.phaseElapsed=0
        end
        if group.phase=='Rewinding' then
            local f=clamp(group.phaseElapsed/restart.rewindSeconds,0,1)
            for _,rider in ipairs(riders) do
                local start=group.start[rider.slot] or copy(rider.position);local target=self:respawnPosition(rider.slot)
                rider.position=point(start.x+(target.x-start.x)*f,start.y+(target.y-start.y)*f,start.z+(target.z-start.z)*f)
                rider.velocity=point(0,0,0);rider.input={x=0,z=0,run=false,at=-math.huge}
                if self.world.campaignPose then self.world:campaignPose(rider.slot,rider.position,self.mode,rider.velocity) end
            end
            if f>=1 then
                group.phase='Riding';group.phaseElapsed=0;group.elapsed=0;group.speed=0
                self.elapsed=group.checkpointElapsed or 0
                for _,rider in ipairs(riders) do
                    rider.position=self:respawnPosition(rider.slot);rider.previous=copy(rider.position)
                    rider.progress=self.course.checkpoints[group.checkpoint].progress;rider.grounded=true
                end
                for id in pairs(self.projectiles) do
                    self.objects[id]=nil;if self.world.campaignRemove then self.world:campaignRemove(id) end
                end
                self.projectiles={};self.emitterNext={}
                self:_log('CampaignGroupRewound',nil,{checkpoint=group.checkpoint,serial=group.serial,mode=self.mode})
            end
        end
    end
end
function Modes:_encounters()
    if not self.spawnEncounter then return end
    if self.vehicleGroup and self.vehicleGroup.phase~='Riding' then return end
    for _,event in ipairs(self.course.encounters or {}) do
        if not self.encounterFired[event.id] then
            for _,slot in ipairs(self.session.order) do local s=self.actors[slot]
                if s and s.mounted and not s.finished and self:_living(slot) and s.progress>=event.progress then
                    if self.spawnEncounter(copy(event))~=false then
                        self.encounterFired[event.id]=true;self:_log('CampaignEncounterSpawned',slot,{id=event.id,kind=event.kind})
                    end
                    break
                end
            end
        end
    end
end
function Modes:_clinger(s,dt)
    local input=self:_input(s);local c=self.course;local segment=c.path[s.segment]
    if not segment then return end
    local correct=input.x*segment.direction.x+input.z*segment.direction.z>=.8
    local speed=correct and c.speed or 2
    local travel=speed*dt
    -- A turn consumes only distance earned with the current direction. A single
    -- held direction never crosses a corner and receives unearned route progress.
    local left=segment.length-s.segmentProgress
    local used=math.min(left,travel);s.segmentProgress+=used;s.progress+=used
    s.position=point(segment.from.x+segment.direction.x*s.segmentProgress,segment.from.y,
        segment.from.z+segment.direction.z*s.segmentProgress)
    if s.segmentProgress>=segment.length-1e-7 then s.segment+=1;s.segmentProgress=0 end
    if not self.chaseFinished and math.abs(self.chaseProgress-s.progress)<=3 then self:_die(s,'CampaignChaseCaught') end
    self:_object('clinger-'..s.slot,'ClingerVehicle',point(s.position.x,s.position.y-2.7,s.position.z),
        {w=4,h=.6,d=4},{collidable=false,role='Vehicle'})
end
function Modes:setChaseController(userId,connected)
    self.chaseController={userId=userId,connected=connected~=false,input={x=0,z=0,at=-math.huge}}
end
function Modes:chaseConnection(connected)
    if not self.chaseController then return end
    self.chaseController.connected=connected==true;self.chaseController.input={x=0,z=0,at=-math.huge}
end
function Modes:chaseCommand(x,z,now)
    if not self.chaseController then return 'NO_CONTROLLER' end
    if not self.chaseController.connected then return 'OFFLINE' end
    if not finite(x) or not finite(z) or not finite(now) or now<self.now or x*x+z*z>1.01 then return 'INVALID_INTENT' end
    self.chaseController.input={x=x,z=z,at=now};return 'OK'
end
function Modes:_chase(dt)
    if self.mode~='Clinger' or self.chaseFinished then return end
    local c=self.course;local speed=c.chaseSpeed
    if self.chaseController then
        speed=0;local controller=self.chaseController;local input=controller.input
        if controller.connected and self.now-input.at<=INPUT_TIMEOUT then
            local distance=math.max(0,self.chaseProgress);local segment=c.path[1]
            for _,p in ipairs(c.path) do segment=p;if distance<=p.length then break end;distance-=p.length end
            speed=math.max(0,input.x*segment.direction.x+input.z*segment.direction.z)*c.chaseSpeed
        end
    end
    self.chaseProgress+=speed*dt
    local remaining=math.max(0,self.chaseProgress);local q=c.path[1].from
    if self.chaseProgress<0 then local first=c.path[1]
        q=point(first.from.x+first.direction.x*self.chaseProgress,first.from.y,first.from.z+first.direction.z*self.chaseProgress)
    else for _,p in ipairs(c.path) do
        q=point(p.from.x+p.direction.x*p.length,p.from.y,p.from.z+p.direction.z*p.length)
        if remaining<=p.length then q=point(p.from.x+p.direction.x*remaining,p.from.y,p.from.z+p.direction.z*remaining);break end
        remaining-=p.length
    end end
    if self.chaseActor then self.chaseActor(q)
    else self:_object('shared-chaser','Buzzball',q,{w=5,h=5,d=5},{collidable=false,role='Chaser',life=self.chaseLife}) end
end
function Modes:_die(s,reason)
    if not self:_living(s.slot) then return end
    local h=self.session.state.heroes[s.slot]
    -- Spawn shields protect crashes; leaving the world/pit and drowning use
    -- Session's existing physical-hazard policy independently of combat shields.
    local physical=reason=='CampaignFall' or reason=='CampaignDrowned'
    if not physical and h.shield and self.now<h.shield.deadline then return end
    self.session:_die(s.slot,reason);self:_log('CampaignHazard',s.slot,{mode=self.mode,reason=reason})
    if s.mounted and self.vehicleGroup then self:_vehicleDeath(s) end
    if self.mode=='Clinger' then
        local others=false
        for _,slot in ipairs(self.session.order) do local actor=self.actors[slot]
            if actor and not actor.finished and self:_living(slot) then others=true;break end
        end
        if not others then self.chaseNeedsReset=true end
    end
    if self.world.campaignRelease then self.world:campaignRelease(s.slot) end
end
function Modes:vehicleObstacleHit(slot)
    local s=self.actors[slot]
    if not self.vehicleGroup or not s or not s.mounted or s.finished then return false end
    -- A mounted obstacle belongs to the course collision policy, including
    -- protected/paused bodies. Never fall through to ordinary melee damage.
    if not self.closed and self.vehicleGroup.phase=='Riding' and self:_living(slot) then self:_die(s,'CampaignCrash') end
    return true
end
function Modes:_hazards(s,old)
    if s.mounted and self.vehicleGroup and self.vehicleGroup.phase~='Riding' then return end
    for _,h in ipairs(self.hazards) do
        if h.active~=false and swept(old,s.position,h,h.previous) then
            if self.mode=='Speeder' or self.mode=='Surf' or self.mode=='Jet' or h.kind=='Spike' or h.kind=='RotatingSpike' or h.kind=='PipeCrusher' or h.kind=='MechanicalCrusher' then
                self:_die(s,'CampaignCrash')
            elseif not s.nextHit or self.now>=s.nextHit then
                s.nextHit=self.now+.8;self.session:_hit(-9001,s.slot,'Dash')
                self:_log('CampaignHazardHit',s.slot,{kind=h.kind,mode=self.mode})
            end
            if not self:_living(s.slot) then return end
        end
    end
end
function Modes:_checkpoint(s)
    local progress
    if self.mode=='Rope' then progress=s.progress
    elseif self.mode=='Ascent' or self.mode=='Tower' then progress=s.position.y-3
    elseif self.mode=='Serpents' then progress=self.room-1
    elseif self.mode=='Race' then progress=self.bombIndex-1
    elseif self.course.mount then progress=s.progress
    else progress=s.position.x end
    for index,p in ipairs(self.course.checkpoints) do
        if p.progress<=progress and index>s.checkpoint then
            s.checkpoint=index;s.savedProgress=p.progress
            if self.vehicleGroup and s.mounted then
                self.vehicleGroup.checkpoint=index;self.vehicleGroup.checkpointElapsed=self.elapsed
                for _,rider in pairs(self.actors) do if rider.mounted and not rider.finished then rider.checkpoint=index;rider.savedProgress=p.progress end end
            end
            self:_log('CampaignCheckpoint',s.slot,{checkpoint=index,mode=self.mode})
        end
    end
end
function Modes:_finish(s)
    if self.course.mount then return s.mounted and self.vehicleGroup.phase=='Riding' and inside(s.position,self.course.finish)
    elseif self.mode=='Serpents' then
        local room=self.course.rooms[self.room]
        if room and inside(s.position,room.exit) then
            self:_log('CampaignRoomCleared',s.slot,{room=self.room});self.room+=1
            if self.room>#self.course.rooms then return true end
            for _,other in pairs(self.actors) do other.checkpoint=self.room end
        end
        return false
    elseif self.mode=='Race' then return self.bombIndex>#self.course.bombs and inside(s.position,self.course.finish)
    elseif self.mode=='Clinger' then return s.segment>#self.course.path
    elseif self.mode=='Tower' then
        local last=self.course.towerPlatforms[#self.course.towerPlatforms];local angle=last.angle+self.rotation
        local target=point(math.cos(angle)*last.radius,last.y+3,math.sin(angle)*last.radius)
        return s.grounded and s.position.y>=last.y+2 and dist(s.position,target)<9
    elseif self.mode=='Rope' then return s.position.y<=6 and math.abs(s.position.x)<=20 and math.abs(s.position.z)<=16
    end
    return inside(s.position,self.course.finish)
end
function Modes:_race(dt)
    if self.mode~='Race' then return end
    self.race:step(self.now,dt);self.bombIndex=self.race.bombIndex
end
function Modes:interaction(slot)
    if self.closed or not self:_controlled(slot) then return {available=false} end
    local s=self.actors[slot]
    if not s or s.finished then return {available=false} end
    if self.course.mount and not s.mounted then
        local p=self.world:position(slot)
        if p and dist(p,self.course.mount)<=self.course.mountRange and (not self.canBoard or self.canBoard()) then
            return {available=true,action='Board '..string.lower(self.mode),kind='CampaignMount'}
        end
    end
    if self.mode=='Race' then return self.race:interaction(slot) end
    if self.mode=='Rope' then return {available=true,action='Rope kick',kind='CampaignKick'} end
    return {available=false}
end
function Modes:interact(slot,now,action)
    local s=self.actors[slot]
    if self.mode=='Race' then
        if self.closed or not s or s.finished or not self:_controlled(slot) then return 'NO_INTERACTION' end
        local result=self.race:interact(slot,now,action)
        if result=='OK' then self.bombIndex=self.race.bombIndex;for _,a in pairs(self.actors) do self:_checkpoint(a) end end
        return result
    end
    if not self.closed and s and not s.finished and self:_controlled(slot) then
        if (self.course.mount and s.mounted) or self.mode=='Clinger' then return 'HANDS_FULL' end
        if self.course.mount and not s.mounted and self.canBoard and not self.canBoard() then
            local p=self.world:position(slot)
            if p and dist(p,self.course.mount)<=self.course.mountRange then return 'ENEMIES_REMAIN' end
        end
    end
    if action~='Punch' then return 'NO_INTERACTION' end
    local interaction=self:interaction(slot);if not interaction.available then return 'NO_INTERACTION' end
    if interaction.kind=='CampaignMount' then
        s.mounted=true;s.position=copy(self.course.mount);s.previous=copy(s.position);s.velocity=point(0,0,0);s.grounded=true
        s.position.z+=self:_slotOffset(slot);s.previous.z=s.position.z
        if self.vehicleGroup.phase=='Mounting' then self.vehicleGroup.phase='Riding';self.vehicleGroup.speed=self.course.speed end
        self:_log('CampaignMounted',slot,{mode=self.mode})
        if self.world.campaignPose then self.world:campaignPose(slot,s.position,self.mode,s.velocity) end
    elseif interaction.kind=='CampaignKick' then
        if s.nextAction and self.now<s.nextAction then return 'COOLDOWN' end
        s.nextAction=self.now+.4
        if self.ropeKick then
            local result=self.ropeKick(slot,now)
            if result and result~='OK' and result~='NO_TARGET' then return result end
        end
        for _,h in ipairs(self.course.hazards) do
            if (h.kind=='Raven' or h.kind=='Toadtrap') and not self.broken[h.id] then
                local p=motionPosition(h,self.elapsed)
                if dist(p,s.position)<=8 then self.broken[h.id]=true;self:_log('CampaignRopeKick',slot,{hazard=h.id}) end
            end
        end
    end
    return 'OK'
end
function Modes:_objects(dt)
    self.hazards={}
    self.walls={}
    for _,wall in ipairs(self.course.walls or {}) do
        local p=motionPosition(wall,self.elapsed);local previous=motionPosition(wall,self.elapsed-dt)
        local row=copy(wall);row.x,row.y,row.z=p.x,p.y,p.z;row.previous=previous;self.walls[#self.walls+1]=row
        self:_object(wall.id,wall.kind,p,size(wall),{collidable=true,role='MovingWall'})
    end
    for _,h in ipairs(self.course.hazards or {}) do
        local p=motionPosition(h,self.elapsed);local previous=motionPosition(h,self.elapsed-dt)
        local row=copy(h);row.x,row.y,row.z=p.x,p.y,p.z;row.previous=previous
        if h.kind=='Gas' or h.kind=='ElectricTrap' or h.kind=='ElectricGate' then row.active=math.sin(self.elapsed*2+(h.motion and h.motion.phase or 0))>.1 end
        if self.broken[h.id] then row.active=false end
        self.hazards[#self.hazards+1]=row
        self:_object(h.id,h.kind,p,size(h),{collidable=false,hazard=row.active~=false,alpha=self.broken[h.id] and 1 or (row.active==false and .75 or .1),role='Hazard'})
        if self.course.mount then
            self:_object('warning-'..h.id,'Warning',point(h.x-18,self.mode=='Jet' and h.y or 3,h.z),{w=1,h=.3,d=5},{collidable=false,label='!',alpha=.25,role='Warning'})
        end
    end
    for _,support in ipairs(self.supports) do
        support.previous=support.position;support.position=pathPosition(support.definition,self.elapsed+(support.phase or 0))
        self:_object(support.id,support.definition.kind,support.position,size(support.definition),{collidable=true,role='Support'})
    end
    if self.mode=='Tower' then
        for n,p in ipairs(self.course.towerPlatforms) do local angle=p.angle+self.rotation
            self:_object('tower-'..n,'TowerPlatform',point(math.cos(angle)*p.radius,p.y-1,math.sin(angle)*p.radius),
                {w=p.w,h=2,d=p.d},{collidable=true,yaw=-angle,role='Support'})
        end
        self:_object('tower-core','Tower',point(0,45,0),{w=28,h=105,d=28},{collidable=false,role='Scenery'})
    end
    for n,water in ipairs(self.course.media or {}) do
        self:_object('water-'..n,'Water',point((water.minX+water.maxX)/2,(water.minY+water.maxY)/2,(water.minZ+water.maxZ)/2),
            {w=water.maxX-water.minX,h=water.maxY-water.minY,d=water.maxZ-water.minZ},{collidable=false,alpha=.65,role='Medium'})
    end
    if self.course.mount then
        self:_object('boarding','BoardingPad',self.course.mount,{w=7,h=1,d=6},{collidable=false,label='BOARD',role='Objective'})
    end
    for n,bomb in ipairs(self.course.bombs or {}) do
        local exploded=n==self.bombIndex and self.race.failed
        self:_object(bomb.id,'Bomb',bomb.position,{w=3,h=3,d=3},{collidable=false,label=exploded and 'EXPLODED' or (n==self.bombIndex and 'DEFUSE' or ''),
            role=n<self.bombIndex and 'Defused' or (exploded and 'Exploded' or 'Objective'),alpha=(n<self.bombIndex or exploded) and .65 or 0})
    end
    for n,fan in ipairs(self.course.fans or {}) do self:_object(fan.id,'Fan',center(fan),size(fan),{collidable=false,alpha=.8,role='Updraft'}) end
    for n,spring in ipairs(self.course.springs or {}) do self:_object('spring-'..n,'Spring',center(spring),size(spring),{collidable=false,role='Spring'}) end
    for _,ramp in ipairs(self.course.ramps or {}) do
        for step=1,3 do self:_object(ramp.id..'-'..step,'Ramp',point(ramp.x-6+step*3,step*.5,ramp.z),
            {w=3,h=step,d=ramp.d},{collidable=false,role='Ramp'}) end
    end
end
function Modes:_projectiles(dt)
    if self.vehicleGroup and self.vehicleGroup.phase~='Riding' then return end
    for _,emitter in ipairs(self.course.emitters or {}) do
        self:_object(emitter.id,emitter.kind,emitter.position,{w=3,h=3,d=3},{collidable=false,role='Emitter'})
        if self.elapsed>=(self.emitterNext[emitter.id] or .2) then
            local target,best
            for _,slot in ipairs(self.session.order) do local s=self.actors[slot]
                if s and not s.finished and self:_living(slot) and (not self.course.mount or s.mounted) then
                    local range=dist(s.position,emitter.position)
                    if range<45 and (not best or range<best) then target=s;best=range end
                end
            end
            if target then
                self.emitterNext[emitter.id]=self.elapsed+emitter.interval
                self.projectileSerial+=1;local id='course-shot-'..self.projectileSerial
                local p=copy(emitter.position);local scale=emitter.speed/math.max(.1,best)
                self.projectiles[id]={position=p,velocity=point((target.position.x-p.x)*scale,(target.position.y-p.y)*scale,(target.position.z-p.z)*scale),
                    expires=self.elapsed+emitter.life,kind=emitter.kind=='RetroBlaster' and 'RetroBolt' or 'Rocket'}
            end
        end
    end
    local remove={}
    for id,shot in pairs(self.projectiles) do
        local old=copy(shot.position);local p=shot.position
        p.x+=shot.velocity.x*dt;p.y+=shot.velocity.y*dt;p.z+=shot.velocity.z*dt
        local h={id=id,kind=shot.kind,x=p.x,y=p.y,z=p.z,w=1,h=1,d=1,previous=old}
        self:_object(id,shot.kind,p,{w=1,h=1,d=1},{collidable=false,role='Projectile'})
        for _,slot in ipairs(self.session.order) do local s=self.actors[slot]
            if s and not s.finished and self:_living(slot) and swept(s.previous,s.position,h,old) then
                if not s.nextHit or self.now>=s.nextHit then
                    self.session:_hit(-9001,slot,'Dash');s.nextHit=self.now+.8
                end
                remove[id]=true;break
            end
        end
        if self.elapsed>=shot.expires then remove[id]=true end
    end
    for id in pairs(remove) do self.projectiles[id]=nil;self.objects[id]=nil;if self.world.campaignRemove then self.world:campaignRemove(id) end end
end
function Modes:_slice(dt)
    self:_vehicleGroupStep(dt)
    self.elapsed+=dt;self.previousRotation=self.rotation;self.rotation=self.elapsed*(self.course.rotationSpeed or 0)
    self:_objects(dt);self:_race(dt);self:_chase(dt)
    for _,block in ipairs(self.blocks) do block.previous=copy(block.position) end
    for _,slot in ipairs(self.session.order) do
        local s=self.actors[slot]
        if s and not s.finished and self:_living(slot) then
            local old=copy(s.position);s.previous=old
            if not self:_special(s) then s.position=copy(self.world:position(slot))
            elseif self.mode=='Rope' then self:_rope(s,dt)
            elseif self.mode=='Speeder' or self.mode=='Surf' or self.mode=='Jet' then self:_vehicle(s,dt)
            elseif self.mode=='Clinger' then self:_clinger(s,dt)
            else self:_platforming(s,dt) end
            if s.external then
                s.position.x+=s.external.x*dt;s.position.z+=s.external.z*dt
                local decay=math.exp(-3*dt);s.external.x*=decay;s.external.z*=decay
            end
            if self.mode=='Tower' then
                -- The native core is a radius-14 cylinder. Stop body penetration
                -- only at that wall; there is no outer-radius safety boundary.
                local radius=math.sqrt(s.position.x^2+s.position.z^2)
                if radius<15.6 then
                    local nx,nz=s.position.x/math.max(radius,.001),s.position.z/math.max(radius,.001)
                    s.position.x=nx*15.6;s.position.z=nz*15.6
                    local inward=s.velocity.x*nx+s.velocity.z*nz
                    if inward<0 then s.velocity.x-=nx*inward;s.velocity.z-=nz*inward end
                end
            end
            self:_hazards(s,old)
            if self:_living(slot) then
                self:_checkpoint(s)
                local bounds=self.definition.bounds
                if s.position.y<(bounds.minY or -45) or s.position.x<bounds.minX-8 or s.position.x>bounds.maxX+8
                    or s.position.z<bounds.minZ-8 or s.position.z>bounds.maxZ+8 then self:_die(s,'CampaignFall')
                elseif self:_finish(s) then
                    self.complete=true;s.finished=true;self:_log('CampaignCourseCleared',slot,{mode=self.mode})
                    if self.world.campaignPose and self.mode~='Finale' then self.world:campaignPose(slot,s.position,self.mode,s.velocity) end
                    if self.world.campaignRelease then self.world:campaignRelease(slot) end
                elseif self:_special(s) and self.world.campaignPose then self.world:campaignPose(slot,s.position,self.mode,s.velocity) end
            end
        end
    end
    for _,block in ipairs(self.blocks) do self:_object(block.id,'IceBlock',block.position,size(block.definition),{collidable=true,role='Pushable'}) end
    self:_projectiles(dt)
    self:_encounters()
end
function Modes:step(now,dt)
    if self.closed or self.session.state.status~='Active' then return end
    if not finite(now) or not finite(dt) or dt<0 or now<self.now then return end
    self.now=now;self:_vehicleDeaths();self:_syncActors()
    local accepted=math.min(dt,.5);self.discardedSeconds+=dt-accepted
    local remaining=accepted
    while remaining>1e-8 do local slice=math.min(FIXED,remaining);self:_slice(slice);remaining-=slice end
end
function Modes:snapshot()
    local actors={}
    for _,slot in ipairs(self.session.order) do local s=self.actors[slot];if s then
        actors[#actors+1]={slot=slot,actorId=s.actorId,attempt=s.attempt,position=copy(s.position),checkpoint=s.checkpoint,
            progress=s.progress,mounted=s.mounted,medium=s.medium,oxygen=s.oxygen,segment=s.segment,grounded=s.grounded,specialControl=self:_special(s),finished=s.finished}
    end end
    local race=self.mode=='Race' and self.race:snapshot() or nil
    return {mode=self.mode,complete=self.complete,elapsed=self.elapsed,discardedSeconds=self.discardedSeconds,actors=actors,room=self.room,
        bombIndex=self.bombIndex,bombCount=self.course.bombs and #self.course.bombs or 0,raceTime=race and race.raceTime,race=race,
        chaseLife=self.chaseLife,chaseProgress=self.chaseProgress,vehicleGroup=copy(self.vehicleGroup),camera={mode=self.mode,angle=self.rotation,
            center=self.mode=='Tower' and point(0,50,0) or nil,rewindSerial=self.vehicleGroup and self.vehicleGroup.serial,
            phase=self.vehicleGroup and self.vehicleGroup.phase,rewindFrom=self.vehicleGroup and copy(self.vehicleGroup.rewindFrom),
            rewindTo=self.vehicleGroup and copy(self.vehicleGroup.rewindTo)},
        objective=self.definition.zones[1].objective}
end
function Modes:close(reason)
    if self.closed then return end
    self.closed=true
    if self.mode=='Race' then self.race:close(reason) end
    for _,slot in ipairs(self.session.order) do if self.world.campaignRelease then self.world:campaignRelease(slot) end end
    for id in pairs(self.objects) do if self.world.campaignRemove then self.world:campaignRemove(id) end end
    self.objects={};self:_log('CampaignModeClosed',nil,{mode=self.mode,reason=reason})
end
return Modes
