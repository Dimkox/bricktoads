-- Original 3D family controllers. Source handler identities/attack families are
-- recorded in research/2026-11-09-campaign-enemies.md; all physical budgets,
-- attack bindings, populations and named-action mappings below are Roblox tuning.
-- Existing Director owns spawn, engagement, one-life claims, raw Life and damage.
local Enemies={}
Enemies.__index=Enemies
local families={
    Raven={mode='Fly',attack='Swoop',range=28,speed=10},LargeRaven={mode='Fly',attack='Swoop',range=30,speed=8},
    Invader={mode='Ground',attack='StealLife',range=16,speed=9},
    RocketRat={mode='Ride',attack='DropObstacle',range=35,speed=14},
    Snowman={mode='Ground',attack='Snowball',range=38,speed=4},
    SentryDrone={mode='Ground',attack='TwinBolt',range=40,speed=0},
    GasTurret={mode='Ground',attack='Gas',range=30,speed=0},
    RetroBlaster={mode='Wall',attack='Bolt',range=42,speed=0},
    SaturnToadtrap={mode='Wall',attack='Snap',range=9,speed=0},
    Robot={mode='Ground',attack='Bolt',range=36,speed=6},
    Slug={mode='Ground',attack='Latch',range=10,speed=5},
    Electrofish={mode='Swim',attack='Shock',range=8,speed=9},
    Hammerfish={mode='Swim',attack='Lunge',range=15,speed=10},
    Shark={mode='Swim',attack='Bite',range=18,speed=13},
    Duck={mode='Swim',attack='Bite',range=12,speed=7},
    Hordhead={mode='Ground',attack='Roll',range=15,speed=8},
    Swellcheeks={mode='Fly',attack='Gas',range=30,speed=8},
    FlyingHead={mode='Fly',attack='Swoop',range=25,speed=11},
}
local actions={
    Swoop={tell=.4,active=.75,recovery=.6,lift=-3,radius=2.6,damage='DragonHeadbutt'},
    Leap={tell=.35,active=.7,recovery=.6,lift=5,radius=2.8,damage='PigRush'},
    StealLife={tell=.35,active=.7,recovery=.6,lift=5,radius=2.8},
    DropObstacle={tell=.45,active=.1,recovery=.8,projectile='Obstacle',damage='WalkerHeavy'},
    Snowball={tell=.5,active=.15,recovery=.75,projectile='Snowball',speed=28,damage='DragonFire'},
    Bolt={tell=.45,active=.12,recovery=.65,projectile='Bolt',speed=34,damage='DragonFire'},
    TwinBolt={tell=.4,active=.15,recovery=.8,projectile='Bolt',speed=34,twin=true,damage='DragonFire'},
    Gas={tell=.5,active=.2,recovery=.9,projectile='GasCloud',speed=12,damage='PigJab'},
    Shock={tell=.4,active=.2,recovery=.8,radial=6,damage='DragonFire'},
    Lunge={tell=.4,active=.65,recovery=.6,lift=0,radius=2.8,damage='WalkerHeavy'},
    Bite={tell=.3,active=.6,recovery=.6,lift=0,radius=2.7,damage='PigHeavy'},
    Roll={tell=.4,active=.7,recovery=.8,lift=1.5,radius=3,damage='PigRush'},
    Snap={tell=.45,active=.25,recovery=.9,reach=9,width=3,height=4,damage='WalkerHeavy'},
    Latch={tell=.3,active=.6,recovery=.7,lift=3,radius=2.6,damage='PigJab'},
    Explode={tell=.8,active=.1,recovery=0,radial=7,damage='HeroBoot',selfDestruct=true},
}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function point(p) return type(p)=='table' and finite(p.x) and finite(p.y) and finite(p.z) end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b)
    if not point(a) or not point(b) then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function aim(x,z)
    if not finite(x) or not finite(z) then return nil end
    local length=math.sqrt(x*x+z*z)
    if not finite(length) or length<.001 then return nil end
    return {x=x/length,z=z/length}
end
local function sweep(a,b,p)
    if not point(a) or not point(b) or not point(p) then return math.huge end
    local x,y,z=b.x-a.x,b.y-a.y,b.z-a.z;local length=x*x+y*y+z*z
    local t=length>0 and math.clamp(((p.x-a.x)*x+(p.y-a.y)*y+(p.z-a.z)*z)/length,0,1) or 0
    return distance({x=a.x+x*t,y=a.y+y*t,z=a.z+z*t},p)
end
function Enemies.new(director)
    return setmetatable({director=director,session=director.session,world=director.world,config=director.config,
        runId=director.session.state.runId,levelEpoch=director.session.state.levelEpoch,
        now=director.now or 0,states={},projectiles={},lifeTokens={},debris={},ravenClaws={},serial=0},Enemies)
end
function Enemies:owns(_,e) return e~=nil and not e.boss and families[e.kind]~=nil end
function Enemies:movementKind(_,e) return e and families[e.kind] and families[e.kind].mode or nil end
function Enemies:_state(id,e)
    local state=self.states[id]
    if not state or state.actorId~=e.actorId then
        state={actorId=e.actorId,mode='Ready',nextAttack=e.nextAttack or self.now,origin=copy(self.world:position(id)),aim={x=1,z=0},startAt=self.now}
        self.states[id]=state
        local family=families[e.kind]
        if family.mode=='Ground' and self.world.campaignWalkSpeed then self.world:campaignWalkSpeed(id,family.speed) end
    end
    return state
end
function Enemies:stateFor(id) return self.states[id] and self.states[id].mode or 'Ready' end
function Enemies:_targets(id)
    local result,seen={},{}
    for _,target in ipairs(self.session.order) do
        local h,c=self.session.state.heroes[target],self.session.combat[target]
        if h.status=='Alive' and c and not c.deathAt and point(self.world:position(target)) then result[#result+1]=target;seen[target]=true end
    end
    for target,e in pairs(self.director.enemies) do
        if target~=id and not e.dead and point(self.world:position(target)) then result[#result+1]=target;seen[target]=true end
    end
    for target,e in pairs(self.externalEnemies or {}) do
        if target~=id and not seen[target] and not e.dead and point(self.world:position(target)) then result[#result+1]=target end
    end
    table.sort(result);return result
end
function Enemies:_nearest(id,direction)
    local p=self.world:position(id);local selected,best=nil,math.huge
    for _,target in ipairs(self.session.order) do
        local h,c=self.session.state.heroes[target],self.session.combat[target];local q=self.world:position(target)
        if h.status=='Alive' and c and not c.deathAt and point(q) then
            local d=distance(p,q);local front=not direction or (q.x-p.x)*direction.x+(q.z-p.z)*direction.z>=0
            if front and d<best then selected,best=target,d end
        end
    end
    return selected,best
end
function Enemies:_hit(id,target,action,hits,impactPosition)
    if hits[target] then return end;hits[target]=true
    local tuning=self.config.Attacks[action]
    if impactPosition then
        tuning=table.clone(tuning);tuning.impactPosition=copy(impactPosition)
    end
    if self.session.state.heroes[target] then return self.session:_hit(id,target,action,tuning) end
    if self.enemyHit then return self.enemyHit(id,target,action,tuning) end
    return self.director:hit(id,target,action,tuning)
end
function Enemies:_bounded(p,id)
    local b=self.config.Level and self.config.Level.bounds or {}
    local result={x=math.clamp(p.x,b.minX or -10000,b.maxX or 10000),
        y=math.clamp(p.y,b.minY or -10000,b.maxY or 10000),z=math.clamp(p.z,b.minZ or -10000,b.maxZ or 10000)}
    local e=id and self.director.enemies[id];local state=id and self.states[id]
    if e and families[e.kind].mode=='Swim' and state then
        local media=self.config.Level and self.config.Level.course and self.config.Level.course.media or {}
        for _,water in ipairs(media) do
            local o=state.origin
            if water.kind=='Water' and o.x>=water.minX and o.x<=water.maxX and o.y>=water.minY
                and o.y<=water.maxY and o.z>=water.minZ and o.z<=water.maxZ then
                result.x=math.clamp(result.x,water.minX+2,water.maxX-2)
                result.y=math.clamp(result.y,water.minY+2,water.maxY-2)
                result.z=math.clamp(result.z,water.minZ+2,water.maxZ-2);break
            end
        end
    end
    return result
end
function Enemies:_pose(id,p,mode,direction)
    p=self:_bounded(p,id)
    if self.world.campaignPose then self.world:campaignPose(id,p,'Enemy'..mode,direction)
    else self.world:placeActor(id,p) end
end
function Enemies:_waterPlane(s)
    local media=self.config.Level and self.config.Level.course and self.config.Level.course.media or {}
    local o=s.origin
    for _,water in ipairs(media) do
        if water.kind=='Water' and o.x>=water.minX and o.x<=water.maxX and o.y>=water.minY and o.y<=water.maxY
            and o.z>=water.minZ and o.z<=water.maxZ then return (water.minZ+water.maxZ)/2 end
    end
    return o.z
end
function Enemies:_floatMotion(id,s,family,p,move,duration)
    local result=copy(p)
    result.x+=move.x*family.speed*duration
    if family.mode=='Swim' then
        result.y-=move.z*family.speed*duration
        local center=self:_waterPlane(s);local delta=center-result.z
        result.z+=math.clamp(delta,-family.speed*duration*.5,family.speed*duration*.5)
    else
        result.z+=move.z*family.speed*duration
        local gravity=family.speed*2
        local vy=s.flyVy or 0;result.y+=vy*duration-gravity*duration^2/2
        s.flyVy=vy-gravity*duration
        local bounds=self.config.Level and self.config.Level.bounds or {}
        local low=math.max(s.origin.y-12,(bounds.minY or -10000)+3)
        local high=math.min(s.origin.y+24,(bounds.maxY or 10000)-3)
        if result.y<low then result.y=low;s.flyVy=0 end
        if result.y>high then result.y=high;s.flyVy=0 end
    end
    self:_pose(id,result,family.mode,s.aim)
end
function Enemies:_flap(s,family)
    if self.now<(s.flapAt or 0) then return 'COOLDOWN' end
    s.flyVy=family.speed;s.flapAt=self.now+.25
    return 'OK'
end
function Enemies:_release(id)
    local e=self.director.enemies[id];local s=self.states[id]
    if e and not e.dead and families[e.kind] and families[e.kind].mode=='Wall' and s then
        self:_pose(id,s.origin,'Wall',s.aim);return
    end
    if self.world.campaignRelease then self.world:campaignRelease(id) end
end
function Enemies:onHit(id)
    self.now=math.max(self.now,self.director.now or 0)
    local state=self.states[id]
    local token=state and state.stolenKey and self.lifeTokens[state.stolenKey]
    if token and token.mode=='Carried' then
        token.mode='Returning';token.expiresAt=self.now+3
        token.position=copy(self.world:position(id) or token.position)
    end
    if state then state.mode='Ready';state.attack=nil;state.latch=nil;state.move=nil;state.nextAttack=self.now+.4 end
    self:_release(id)
end
function Enemies:forgetEnemy(id) self:onHit(id);self.states[id]=nil end
function Enemies:_begin(id,e,name,direction,target)
    local s=self:_state(id,e)
    if self.closed or e.dead then return 'NOT_ALIVE' end
    if e.reactionUntil then return 'REACTION' end
    if s.mode~='Ready' or self.now<s.nextAttack then return 'COOLDOWN' end
    if name=='StealLife' and s.hasStolen then return 'NO_AMMO' end
    local p=self.world:position(id);if not point(p) then return 'NO_TARGET' end
    local dir=direction or s.aim
    target=target or self:_nearest(id,dir)
    local q=target and self.world:position(target)
    if not q then q={x=p.x+dir.x*10,y=p.y,z=p.z+dir.z*10} end
    local family=families[e.kind];local m=actions[name]
    if distance(p,q)>family.range then q={x=p.x+dir.x*family.range,y=p.y,z=p.z+dir.z*family.range};target=nil end
    if family.mode=='Ground' then q={x=q.x,y=p.y,z=q.z} end
    s.aim=dir;s.mode='Tell';s.move=nil
    s.attack={name=name,move=m,origin=copy(p),destination=self:_bounded(q,id),aim=dir,target=target,
        at=self.now+m.tell,untilAt=self.now+m.tell+m.active,recoverAt=self.now+m.tell+m.active+m.recovery,
        lastAt=self.now+m.tell,hits={},reactionEpoch=e.reactionEpoch or 0}
    e.engaged=true;e.windup=nil;e.lastMove=nil
    self.world:move(id,0,0);self.world:cue(id,true)
    if family.mode~='Ground' then self:_pose(id,p,family.mode,dir) end
    if self.world.aim then self.world:aim(id,dir.x,dir.z) end
    if self.world.bossTell then self.world:bossTell(e.kind..name,s.attack.destination,m.radial or m.radius or 2,s.attack.at) end
    if self.director._log then self.director:_log('CampaignEnemyAttack',id,{kind=e.kind,attack=name,actorId=e.actorId,effectAt=s.attack.at}) end
    return 'OK'
end
function Enemies:command(id,e,payload,now)
    if not self:owns(id,e) then return nil end
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now
    if not point(self.world:position(id)) then return 'NOT_ALIVE' end
    local s=self:_state(id,e);local family=families[e.kind]
    if self.closed or e.dead then return 'NOT_ALIVE' end
    if e.ownerUserId and e.connected==false then return 'OFFLINE' end
    if e.kind=='RocketRat' then
        if payload.kind=='Move' then
            if not finite(payload.x) or not finite(payload.z) or payload.x^2+payload.z^2>1.01 then return 'INVALID_MOVE' end
            return 'OK'
        elseif payload.kind=='Jump' then return 'NO_JUMP'
        elseif payload.kind=='Attack' and payload.attack=='Punch' then return self:_rocketDrop(id,e,s) end
        return 'INVALID_ACTION'
    end
    if e.reactionUntil or s.mode~='Ready' then return 'REACTION' end
    if payload.kind=='Move' then
        if not finite(payload.x) or not finite(payload.z) or payload.x^2+payload.z^2>1.01 then return 'INVALID_MOVE' end
        local dir=aim(payload.x,family.mode=='Swim' and 0 or payload.z)
        if dir then s.aim=dir;if self.world.aim then self.world:aim(id,dir.x,dir.z) end end
        s.move={x=payload.x,z=payload.z};e.lastMove=now
        if family.mode=='Ground' or family.mode=='Wall' then
            if self.world.campaignWalkSpeed then self.world:campaignWalkSpeed(id,family.speed) end
            self.world:move(id,family.speed>0 and payload.x or 0,family.speed>0 and payload.z or 0,false)
        end
        return 'OK'
    elseif payload.kind=='Jump' then
        if family.mode=='Fly' then return self:_flap(s,family) end
        if family.mode=='Ground' and family.speed>0 then self.world:jump(id);return 'OK' end
        return 'NO_JUMP'
    elseif payload.kind~='Attack' or payload.attack~='Punch' then return 'INVALID_ACTION' end
    local _,range=self:_nearest(id,s.aim)
    return self:_begin(id,e,e.kind=='Robot' and range<=7 and 'Explode' or family.attack,s.aim)
end
function Enemies:_spawn(id,e,a,direction)
    self.serial+=1;local key=-6000-self.serial*2;local m=a.move;local origin=copy(self.world:position(id))
    local mode=m.projectile;local dir=direction or a.aim
    local p={owner=id,actorId=e.actorId,mode=mode,position=origin,direction=dir,lastAt=a.at,created=a.at,
        expiresAt=a.at+(mode=='Obstacle' and 4 or mode=='GasCloud' and 2.5 or 2),
        speed=m.speed or 0,action=m.damage,hits={},groundY=a.destination.y}
    self.projectiles[key]=p;self.world:projectile(key,origin,false,mode)
end
function Enemies:_steal(id,e,s,target,hits)
    if hits[target] then return end;hits[target]=true
    if s.hasStolen or not self.session.state.heroes[target] then return end
    local link=self.session:_stealLife(id,target)
    if not link then return end
    self.serial+=1;local key=-6000-self.serial*2
    self.lifeTokens[key]={owner=id,actorId=e.actorId,link=link,mode='Carried',expiresAt=self.now+5,
        position=copy(self.world:position(id)),lastAt=self.now}
    -- The thief's finite escape belongs to its own life, not to the victim's
    -- return eligibility. A dead/replaced hero invalidates only that link.
    e.lifeEscapeAt=self.now+5
    s.hasStolen=true;s.stolenKey=key
    self.world:projectile(key,self.lifeTokens[key].position,false,'StolenLife')
end
function Enemies:_removeLife(id)
    local token=self.lifeTokens[id];if not token then return end
    self.session:_discardStolenLife(token.link)
    self.lifeTokens[id]=nil;self.world:removeProjectile(id)
end
function Enemies:_spawnDebris(mode,position,sourceActorId)
    self.serial+=1;local key=-6000-self.serial*2
    self.debris[key]={mode=mode,position=copy(position),created=self.now,lastAt=self.now,
        expiresAt=self.now+(mode=='DeadRaven' and 3 or 7),sourceActorId=sourceActorId,vy=2}
    self.world:projectile(key,position,false,mode)
    return key
end
function Enemies:afterHit(id,e)
    if not self:owns(id,e) or e.dead then return false end
    self.now=math.max(self.now,self.director.now or 0)
    local p=self.world:position(id)
    if e.kind=='Invader' then
        -- Type15 becomes linked type1D on contact with an accepted hit. The
        -- return token can outlive this spent body; $FF is not a health budget.
        self.director:_kill(id,'InvaderTransformation');return true
    elseif e.kind=='Raven' then
        self:_spawnDebris('DeadRaven',p,e.actorId)
        self.director:_kill(id,'RavenReaction');return true
    elseif e.kind=='LargeRaven' and not e.clawCreated then
        -- A reaction spawns type2F; it settles and grants have_stick on contact.
        -- One finite pickup per authored actor bounds the source slot allocator.
        e.clawCreated=true;self:_spawnDebris('RavenClaw',p,e.actorId)
    end
    return false
end
function Enemies:hasRavenClaw(slot)
    local row=self.ravenClaws[slot];if not row then return false end
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    local same=h and h.actorId==row.actorId and h.attempt==row.attempt and c==row.combat
        and self.session.state.levelEpoch==row.levelEpoch
    if self.closed or not same or h.status~='Alive' or c.deathAt or (c.heavyReactionEpoch or 0)~=row.heavyReactionEpoch then
        self.ravenClaws[slot]=nil
        if self.world.campaignClaw then self.world:campaignClaw(slot,false) end
        if not self.closed and same and h.status=='Alive' and not c.deathAt and point(self.world:position(slot)) then
            self:_spawnDebris('RavenClaw',self.world:position(slot),row.sourceActorId)
        end
        return false
    end
    return true
end
function Enemies:_debrisStep(now)
    for slot in pairs(self.ravenClaws) do self:hasRavenClaw(slot) end
    local ids={};for id in pairs(self.debris) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do
        local p=self.debris[id];local duration=math.max(0,math.min(now,p.expiresAt)-p.lastAt)
        local ground=p.mode=='RavenClaw' and self.world.groundPosition and self.world:groundPosition(p.position)
        p.position.y+=p.vy*duration-14*duration^2;p.vy-=28*duration;p.lastAt=now
        if point(ground) and p.position.y<=ground.y then p.position.y=ground.y;p.vy=0 end
        local consumed=false
        if p.mode=='RavenClaw' and now>=p.created+.35 then
            for _,slot in ipairs(self.session.order) do
                local h,c=self.session.state.heroes[slot],self.session.combat[slot]
                if h.status=='Alive' and c and not c.deathAt and not self:hasRavenClaw(slot)
                    and distance(p.position,self.world:position(slot))<=4 then
                    self.ravenClaws[slot]={actorId=h.actorId,attempt=h.attempt,combat=c,levelEpoch=self.session.state.levelEpoch,
                        heavyReactionEpoch=c.heavyReactionEpoch or 0,sourceActorId=p.sourceActorId}
                    if self.world.campaignClaw then self.world:campaignClaw(slot,true) end
                    self.session:_record('RavenClawPickedUp',slot,{sourceActorId=p.sourceActorId})
                    consumed=true;break
                end
            end
        end
        if consumed or now>=p.expiresAt then self.debris[id]=nil;self.world:removeProjectile(id)
        else self.world:projectile(id,p.position,false,p.mode) end
    end
end
function Enemies:_lifeStep(now)
    local ids={};for id in pairs(self.lifeTokens) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do
        local t=self.lifeTokens[id];local h=self.session.state.heroes[t.link.slot]
        local c=self.session.combat[t.link.slot];local q=self.world:position(t.link.slot)
        if now>=t.expiresAt and t.mode=='Carried' then
            local owner=self.director.enemies[t.owner]
            if owner and not owner.dead and owner.actorId==t.actorId then self.director:_kill(t.owner,'InvaderEscape') end
            self:_removeLife(id)
            continue
        end
        if self.session.state.status~='Active' or self.session.state.runId~=t.link.runId
            or self.session.state.levelEpoch~=t.link.levelEpoch or not h or h.status~='Alive'
            or h.actorId~=t.link.actorId or h.attempt~=t.link.attempt or c~=t.link.combat or c.deathAt
            or not point(q) or now>=t.expiresAt then self:_removeLife(id)
        elseif t.mode=='Carried' then
            local e=self.director.enemies[t.owner];local p=self.world:position(t.owner)
            if not e or e.actorId~=t.actorId or not point(p) then self:_removeLife(id)
            else t.position={x=p.x,y=p.y+2,z=p.z};self.world:projectile(id,t.position,false,'StolenLife');t.lastAt=now end
        else
            local duration=math.max(0,now-t.lastAt);local range=distance(t.position,q)
            if range<=1.5+24*duration then
                self.session:_recoverStolenLife(t.link);self:_removeLife(id)
            else
                local f=24*duration/range
                t.position={x=t.position.x+(q.x-t.position.x)*f,y=t.position.y+(q.y-t.position.y)*f,z=t.position.z+(q.z-t.position.z)*f}
                t.lastAt=now;self.world:projectile(id,t.position,false,'ReturningLife')
            end
        end
    end
end
function Enemies:_trajectory(e,s)
    local t=e.trajectory
    if not t then
        t={duration=4,from=copy(s.origin),to={x=s.origin.x+56,y=s.origin.y,z=s.origin.z},dropAt=1.5,dropGroundY=s.origin.y}
    end
    assert(point(t.from) and point(t.to) and finite(t.duration) and t.duration>0 and t.duration<=30,'Invalid rocket-rat trajectory')
    return t
end
function Enemies:_rocketPosition(t,elapsed)
    local f=math.clamp(elapsed/t.duration,0,1)
    return {x=t.from.x+(t.to.x-t.from.x)*f,y=t.from.y+(t.to.y-t.from.y)*f,z=t.from.z+(t.to.z-t.from.z)*f}
end
function Enemies:_rocketDrop(id,e,s,at)
    if e.reactionUntil then return 'REACTION' end
    if s.dropped or e.allowedDrop==false then return 'NO_AMMO' end
    local t=self:_trajectory(e,s);s.dropped=true;e.engaged=true
    local acceptedAt=at or self.now
    local a={move=actions.DropObstacle,aim=s.aim,at=acceptedAt,
        destination={x=0,y=t.dropGroundY or t.from.y,z=0}}
    self:_spawn(id,e,a)
    -- Sparse steps still emit at the point/time on the same scripted route.
    local p=self.projectiles[-6000-self.serial*2]
    p.position=self:_rocketPosition(t,acceptedAt-s.startAt)
    self.world:projectile(-6000-self.serial*2,p.position,false,p.mode)
    return 'OK'
end
function Enemies:_rocketStep(id,e,s)
    local t=self:_trajectory(e,s);local elapsed=self.now-s.startAt
    if elapsed>=t.duration then self.director:_kill(id,'EncounterExpired');return true end
    if e.reactionUntil then self:onHit(id);return true end
    self:_pose(id,self:_rocketPosition(t,elapsed),'Ride',s.aim)
    -- The route and drop gate run while the owner is offline. Both controllers
    -- share the same one-drop action; ownership does not introduce free flight.
    if elapsed>=(t.dropAt or 1.5) and not s.dropped then self:_rocketDrop(id,e,s,s.startAt+(t.dropAt or 1.5)) end
    return true
end
function Enemies:_area(id,center,radius,a)
    for _,target in ipairs(self:_targets(id)) do
        if distance(center,self.world:position(target))<=radius then self:_hit(id,target,a.move.damage,a.hits) end
    end
end
function Enemies:_motion(a,at)
    local t=math.clamp((at-a.at)/a.move.active,0,1)
    return {x=a.origin.x+(a.destination.x-a.origin.x)*t,
        y=a.origin.y+(a.destination.y-a.origin.y)*t+math.sin(t*math.pi)*(a.move.lift or 0),
        z=a.origin.z+(a.destination.z-a.origin.z)*t}
end
function Enemies:_attack(id,e,s)
    local a=s.attack;if not a then return end
    if (e.reactionEpoch or 0)~=a.reactionEpoch then self:onHit(id);return end
    if s.mode=='Tell' and self.now>=a.at then
        s.mode='Active';self.world:cue(id,false)
        if a.move.projectile then
            self:_spawn(id,e,a)
            if a.move.twin then self:_spawn(id,e,a,{x=-a.aim.x,z=-a.aim.z}) end
        end
    end
    if s.mode=='Active' then
        local m=a.move;local at=math.min(self.now,a.untilAt)
        if m.lift~=nil then
            local cursor=a.lastAt
            while cursor<at and s.mode~='Latched' do
                local nextAt=math.min(at,cursor+.05);local before,after=self:_motion(a,cursor),self:_motion(a,nextAt)
                for _,target in ipairs(self:_targets(id)) do
                    if sweep(before,after,self.world:position(target))<=m.radius then
                        if a.name=='StealLife' then self:_steal(id,e,s,target,a.hits)
                        else self:_hit(id,target,m.damage,a.hits) end
                        if a.name=='Latch' and self.session.state.heroes[target] then
                            s.mode='Latched';s.latch={target=target,untilAt=self.now+2.5,nextHit=self.now+.7,
                                actorId=self.session.state.heroes[target].actorId};break
                        end
                    end
                end
                cursor=nextAt
            end
            if s.mode~='Latched' then self:_pose(id,self:_motion(a,at),'Attack',a.aim) end
        elseif m.radial then self:_area(id,a.origin,m.radial,a)
        elseif m.reach then
            for _,target in ipairs(self:_targets(id)) do
                local q=self.world:position(target);local x,z=q.x-a.origin.x,q.z-a.origin.z
                local front=x*a.aim.x+z*a.aim.z;local side=x*a.aim.z-z*a.aim.x
                if front>=0 and front<=m.reach and math.abs(side)<=m.width and math.abs(q.y-a.origin.y)<=m.height then
                    self:_hit(id,target,m.damage,a.hits)
                end
            end
        end
        a.lastAt=at
        if m.selfDestruct then self.director:_kill(id,'SelfDestruct');return end
        if self.now>=a.untilAt and s.mode~='Latched' then
            s.mode='Recovery'
            if families[e.kind].mode=='Ground' then self:_release(id) end
        end
    end
    if s.mode=='Recovery' and self.now>=a.recoverAt then
        s.mode='Ready';s.attack=nil;s.nextAttack=self.now+.4
    end
end
function Enemies:enemyStep(id,e,dt)
    if not self:owns(id,e) then return false end
    self.now=self.director.now
    if self.closed or e.dead or not point(self.world:position(id)) then self:forgetEnemy(id);return true end
    local s=self:_state(id,e);local family=families[e.kind]
    if e.kind=='Invader' and e.lifeEscapeAt and self.now>=e.lifeEscapeAt then
        -- Escape consumes the carried resource; ordinary hits still release
        -- its return through onHit before spending this actor's one life.
        if s.stolenKey then self:_removeLife(s.stolenKey) end
        self.director:_kill(id,'InvaderEscape');return true
    end
    if e.kind=='RocketRat' then return self:_rocketStep(id,e,s) end
    if family.mode=='Wall' then self:_pose(id,s.origin,'Wall',s.aim) end
    if e.reactionUntil or self.director.carry and self.director.carry:blocksEnemy(id) then self:onHit(id);return true end
    if s.mode=='Latched' then
        local l=s.latch;local h=self.session.state.heroes[l.target];local c=self.session.combat[l.target]
        if not h or h.actorId~=l.actorId or h.status~='Alive' or c.deathAt or self.now>=l.untilAt then self:onHit(id)
        else
            local p=self.world:position(l.target)
            self:_pose(id,{x=p.x,y=p.y+1.5,z=p.z},'Latch',s.aim)
            if self.now>=l.nextHit then self:_hit(id,l.target,'PigJab',{});l.nextHit=self.now+.7 end
        end
        return true
    end
    self:_attack(id,e,s)
    if e.dead or s.mode~='Ready' then
        if not e.dead and family.mode~='Ground' then self:_pose(id,family.mode=='Wall' and s.origin or self.world:position(id),family.mode,s.aim) end
        return true
    end
    local duration=finite(dt) and math.clamp(dt,0,.25) or 0
    if e.ownerUserId then
        if e.lastMove and self.now-e.lastMove>(self.config.MoveTimeout or .35) then
            e.lastMove=nil;s.move=nil;self.world:move(id,0,0)
        end
        if family.mode~='Ground' and family.mode~='Wall' then
            local p=self.world:position(id);local move=e.connected and s.move or {x=0,z=0}
            self:_floatMotion(id,s,family,p,move or {x=0,z=0},duration)
        end
    else
        local target,range=self:_nearest(id)
        local attackRange=actions[family.attack].radial or family.range
        if target and range<=attackRange and self.now>=s.nextAttack and not (e.kind=='Invader' and s.hasStolen) then
            self.world:face(id,target);local p,q=self.world:position(id),self.world:position(target)
            local dir=aim(q.x-p.x,q.z-p.z) or s.aim
            self:_begin(id,e,e.kind=='Robot' and range<=7 and 'Explode' or family.attack,dir,target)
        elseif target and family.speed>0 and range>attackRange then
            if family.mode=='Ground' then self.world:enemyMove(id,target,family.speed)
            else
                local p,q=self.world:position(id),self.world:position(target);local dx=q.x-p.x
                local dz=family.mode=='Swim' and p.y-q.y or q.z-p.z
                local length=math.max(1,math.sqrt(dx*dx+dz*dz))
                if family.mode=='Fly' and q.y>p.y+.5 then self:_flap(s,family) end
                self:_floatMotion(id,s,family,p,{x=dx/length,z=dz/length},duration)
            end
        elseif family.mode~='Ground' and family.mode~='Wall' then self:_floatMotion(id,s,family,self.world:position(id),{x=0,z=0},duration) end
    end
    return true
end
function Enemies:_remove(id) self.projectiles[id]=nil;self.world:removeProjectile(id) end
-- Only an explicit course rewind calls this hook. Ordinary death, disconnect
-- and role expiry keep already accepted effects alive for their normal life.
function Enemies:expireEncounter(id)
    local enemy=self.director.enemies[id]
    if not enemy or enemy.kind~='RocketRat' then return 0 end
    local ids={}
    for key,p in pairs(self.projectiles) do
        if p.owner==id and p.actorId==enemy.actorId then ids[#ids+1]=key end
    end
    for _,key in ipairs(ids) do self:_remove(key) end
    return #ids
end
function Enemies:step(now,dt)
    if not finite(now) or now<0 or dt~=nil and (not finite(dt) or dt<0) then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end;self.now=now
    if self.closed then return 'OK' end
    if self.session.state.runId~=self.runId or self.session.state.levelEpoch~=self.levelEpoch then
        self:close('ContextChanged');return 'RUN_CLOSED'
    end
    self:_lifeStep(now,dt)
    self:_debrisStep(now)
    local ids={};for id in pairs(self.projectiles) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do
        local p=self.projectiles[id]
        -- A mounted crash can synchronously rewind the course and remove other
        -- encounter effects whose keys are still in this frame's snapshot.
        if not p then continue end
        local at=math.min(now,p.expiresAt);local duration=math.max(0,at-p.lastAt)
        local before=p.position;local after={x=before.x+p.direction.x*p.speed*duration,y=before.y,z=before.z+p.direction.z*p.speed*duration}
        if p.mode=='Obstacle' then after.y=math.max(p.groundY,before.y-18*duration) end
        local radius=p.mode=='GasCloud' and math.min(4,1+(at-p.created)*1.5) or p.mode=='Obstacle' and 3 or 1.8
        local candidates={}
        for _,target in ipairs(self:_targets(p.owner)) do
            local q=self.world:position(target)
            if sweep(before,after,q)<=radius then candidates[#candidates+1]={id=target,distance=distance(before,q)} end
        end
        table.sort(candidates,function(a,b) return a.distance<b.distance end)
        local consumed=false
        for _,target in ipairs(candidates) do
            local position=self.world:position(target.id)
            if self.world.campaignProjectileBlocked and self.world:campaignProjectileBlocked(before,position) then consumed=true;break end
            local handled=p.mode=='Obstacle' and self.session.state.heroes[target.id]~=nil
                and self.vehicleObstacleHit and self.vehicleObstacleHit(target.id,p.owner,p.actorId)
            if not handled then self:_hit(p.owner,target.id,p.action,p.hits,position) end
            if p.mode~='GasCloud' then consumed=true;break end
        end
        if not consumed and self.world.campaignProjectileBlocked and self.world:campaignProjectileBlocked(before,after) then consumed=true end
        if consumed or now>=p.expiresAt then self:_remove(id)
        else p.position=after;p.lastAt=now;self.world:projectile(id,after,false,p.mode) end
    end
    return 'OK'
end
function Enemies:close(reason)
    if self.closed then return end;self.closed=reason or 'Closed'
    local ids={};for id in pairs(self.projectiles) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do self:_remove(id) end
    local tokens={};for id in pairs(self.lifeTokens) do tokens[#tokens+1]=id end
    for _,id in ipairs(tokens) do self:_removeLife(id) end
    for id in pairs(self.debris) do self.world:removeProjectile(id) end;table.clear(self.debris)
    for slot in pairs(self.ravenClaws) do if self.world.campaignClaw then self.world:campaignClaw(slot,false) end end
    table.clear(self.ravenClaws)
    for id in pairs(self.states) do self:_release(id) end;table.clear(self.states)
end
return Enemies
