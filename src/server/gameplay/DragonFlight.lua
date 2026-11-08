-- Temporary transport over existing actors. Damage/resources remain owned by Session/Director.
local Flight={}
Flight.__index=Flight
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function sortedKeys(t) local r={};for k in pairs(t) do r[#r+1]=k end;table.sort(r);return r end
function Flight.new(director)
    local self=setmetatable({director=director,session=director.session,world=director.world,
        config=table.clone(director.config.DragonFlight),states={},heroes={},shots={},serial=0,now=director.now},Flight)
    local previousIntent=self.session.contextualIntent
    self.session.contextualIntent=function(slot,p,now)
        local code=self:heroIntent(slot,p,now)
        if code~='NO_INTERACTION' then return code end
        return previousIntent and previousIntent(slot,p,now) or 'NO_INTERACTION'
    end
    local previousHit=self.session.beforeHitImpulse
    self.session.beforeHitImpulse=function(slot)
        self:heroHit(slot)
        if previousHit then previousHit(slot) end
    end
    return self
end
function Flight:_active() return not self.closed and not self.director.result and self.session.state.status=='Active' end
function Flight:_row(id)
    local e=self.director.enemies[id]
    if not e or e.dead or e.kind~='Dragon' then return nil end
    local row=self.states[id]
    if row and (row.enemy~=e or row.actorId~=e.actorId) then self:forgetEnemy(id);row=nil end
    if not row then
        local p=self.world:position(id);if not p then return nil end
        row={id=id,enemy=e,actorId=e.actorId,mode='Approach',homeY=self.world:dragonFloor(id) or p.y}
        self.states[id]=row
    end
    return row
end
function Flight:_hero(slot,ready)
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    if not self:_active() or not h or h.status~='Alive' or not h.actorId or not c or c.deathAt
        or self.world:hazard(slot) then return nil end
    if ready and (not h.connected or c.reactionEnd or c.attack) then return nil end
    return h,c
end
function Flight:_valid(row)
    local h,c=self:_hero(row.slot)
    return h and self.director.enemies[row.id]==row.enemy and not row.enemy.dead
        and row.enemy.actorId==row.actorId and h.actorId==row.heroActorId and h.attempt==row.attempt
        and self.session.state.levelEpoch==row.levelEpoch and c==row.combat
        and (c.reactionEpoch or 0)==row.heroReactionEpoch
end
function Flight:_log(kind,row,data)
    data=data or {};data.enemyId=row.id;data.enemyActorId=row.actorId;data.mode=row.mode
    self.session:_record(kind,row.slot,data)
end
function Flight:_release(row,reason,jump)
    if not row.slot then return end
    local slot=row.slot
    self.world:dragonUnlink(slot,jump)
    if self.heroes[slot]==row then self.heroes[slot]=nil end
    self:_log('DragonReleased',row,{reason=reason})
    row.slot=nil;row.mode='Turn';row.turnUntil=self.now+self.config.turnSeconds;row.move=nil
end
function Flight:isMounted(id) local r=self.states[id];return r~=nil and r.mode=='Mounted' end
function Flight:heroHit(slot)
    self.now=math.max(self.now,self.session.now)
    local row=self.heroes[slot];if row then self:_release(row,'Hit') end
end
function Flight:hitEnemy(id,heavy)
    local row=self:_row(id);if not row then return end
    self.now=math.max(self.now,self.director.now)
    self:_release(row,'DragonHit');row.capture=nil
    self.world:stopDragon(id)
    row.mode=heavy and 'Disabled' or 'Turn'
    row.disabledUntil=heavy and self.now+self.config.disabledSeconds or nil
    row.turnUntil=self.now+self.config.turnSeconds
end
function Flight:forgetEnemy(id)
    local row=self.states[id]
    if row then self:_release(row,'DragonRemoved');self.world:stopDragon(id);self.states[id]=nil end
end
function Flight:_mountable(slot,id,row)
    return row.mode=='Disabled' and self.now<row.disabledUntil and not row.slot and not row.capture
        and not row.enemy.reactionUntil and self.world:dragonGrounded(id)
        and self.world:dragonCanMount(slot,id,self.config.mountRange,self.config.mountHeight)
end
function Flight:interaction(slot)
    self.now=math.max(self.now,self.session.now,self.director.now)
    local linked=self.heroes[slot]
    if linked and self:_valid(linked) then
        return {available=linked.mode=='Mounted',carrying=true,kind='Dragon',
            label=linked.mode=='Mounted' and 'ОГОНЬ • ПРЫЖОК — СПЕШИТЬСЯ' or 'ВАС СХВАТИЛИ'}
    end
    if not self:_hero(slot,true) then return {available=false} end
    for _,id in ipairs(sortedKeys(self.director.enemies)) do
        local row=self:_row(id)
        if row and self:_mountable(slot,id,row) then return {available=true,kind='Dragon',label='ОСЕДЛАТЬ'} end
    end
    return {available=false}
end
function Flight:interact(slot,now,action)
    self.now=math.max(self.now,now)
    if not self:_active() or action~='Punch' or self.heroes[slot] then return 'NO_INTERACTION' end
    local h,c=self:_hero(slot,true);if not h then return 'NO_INTERACTION' end
    for _,id in ipairs(sortedKeys(self.director.enemies)) do
        local row=self:_row(id)
        if row and self:_mountable(slot,id,row) then
            if not self.world:dragonLink(id,slot,'Mounted') then return 'NO_INTERACTION' end
            local code=self.session:_event('BeginAttack',slot,{connectionEpoch=h.connectionEpoch})
            if code~='OK' then self.world:dragonUnlink(slot);return code end
            self.world:hold(slot,false)
            row.mode='Mounted';row.slot=slot;row.heroActorId=h.actorId;row.attempt=h.attempt
            row.levelEpoch=self.session.state.levelEpoch;row.combat=c;row.heroReactionEpoch=c.reactionEpoch or 0
            row.enemy.windup=nil;row.enemy.engaged=true;row.enemy.lastMove=nil;row.enemy.dragonMove=nil
            self.heroes[slot]=row
            if self.director.clubs then self.director.clubs:drop(slot,'DragonMount') end
            self:_log('DragonMounted',row,{ownerUserId=row.enemy.ownerUserId})
            return 'OK'
        end
    end
    return 'NO_INTERACTION'
end
function Flight:_fire(row,h,c)
    if self.now<c.nextAttack or c.attack then return 'COOLDOWN' end
    local count=0;for _ in pairs(self.shots) do count+=1 end
    if count>=2 then return 'PROJECTILE_LIMIT' end
    local origin,direction,obstructed=self.world:dragonMuzzle(row.id)
    if not origin or not direction then return 'NO_INTERACTION' end
    local code=self.session:_event('BeginAttack',row.slot,{connectionEpoch=h.connectionEpoch})
    if code~='OK' then return code end
    self.world:hold(row.slot,false)
    local tuning=self.director.Combat.captureAttack(self.director.config,'DragonFire')
    tuning.impulseDirection=table.clone(direction)
    c.nextAttack=self.now+tuning.cooldown
    if obstructed then self:_log('DragonFireBlocked',row);return 'OK' end
    self.serial+=1;local id=-5000-self.serial
    self.shots[id]={position=table.clone(origin),direction=table.clone(direction),created=self.now,
        expires=self.now+self.config.fireLife,slot=row.slot,dragon=row.id,heroActorId=h.actorId,
        tuning=tuning,speed=self.config.fireSpeed,radius=self.config.fireRadius}
    self.world:dragonFire(id,origin)
    self:_log('DragonFireAccepted',row,{projectileId=id,profile=22})
    return 'OK'
end
function Flight:heroIntent(slot,p,now)
    self.now=math.max(self.now,now)
    local row=self.heroes[slot]
    if not row then return 'NO_INTERACTION' end
    if not self:_valid(row) then self:_release(row,'ActorChanged');return 'NO_INTERACTION' end
    if row.mode=='Captured' then return 'HELD' end
    local h,c=self:_hero(slot,true);if not h then return 'REACTION' end
    if p.kind=='Move' then row.move={x=p.x,z=p.z,at=now};return 'OK' end
    if p.kind=='Jump' or (p.kind=='Attack' and p.attack=='Dash') then self:_release(row,'Dismount',p.kind=='Jump');return 'OK' end
    if p.kind=='Attack' then return self:_fire(row,h,c) end
    return 'NO_INTERACTION'
end
function Flight:enemyCommand(id,e,p,now)
    local row=self:_row(id);if not row then return nil end
    if row.mode=='Mounted' then return 'MOUNTED' end
    if row.mode=='Captured' or row.capture then return 'CAPTURING' end
    if row.mode=='Disabled' and now<row.disabledUntil then return 'DISABLED' end
    if p.kind=='Move' then e.dragonMove={x=p.x,z=p.z,at=now};return 'OK' end
    if p.kind=='Jump' then row.liftUntil=now+self.config.liftSeconds;return 'OK' end
    return nil
end
function Flight:_capturable(slot)
    local h,c=self:_hero(slot)
    return h and not self.heroes[slot] and c.reactionEnd and self.now<c.reactionEnd and c.heavyReaction==true
        and not (h.shield and self.now<h.shield.deadline)
end
function Flight:beginCapture(id,e,target)
    self.now=math.max(self.now,self.director.now)
    local row=self:_row(id)
    if not row or row.slot or row.capture or e.reactionUntil or self.now<(e.nextAttack or 0) then return false end
    local geometry=self.config.captureGeometry
    for _,slot in ipairs(self.world:targets(id,geometry)) do
        if (not target or slot==target) and self:_capturable(slot) then
            row.capture={at=self.now+self.config.captureWindup,expires=self.now+self.config.captureWindup+self.config.captureWindow,
                reactionEpoch=e.reactionEpoch or 0,geometry=table.clone(geometry)}
            e.engaged=true;e.windup=nil
            self:_log('DragonCaptureAccepted',row)
            return true
        end
    end
    return false
end
function Flight:_capture(row)
    local pending=row.capture;row.capture=nil
    row.enemy.nextAttack=self.now+self.config.turnSeconds
    if self.now>pending.expires or (row.enemy.reactionEpoch or 0)~=pending.reactionEpoch or row.enemy.reactionUntil then return end
    for _,slot in ipairs(self.world:targets(row.id,pending.geometry)) do
        if self:_capturable(slot) then
            local h,c=self:_hero(slot)
            if self.world:dragonLink(row.id,slot,'Captured') then
                row.slot=slot;row.heroActorId=h.actorId;row.attempt=h.attempt;row.levelEpoch=self.session.state.levelEpoch
                row.combat=c;row.heroReactionEpoch=c.reactionEpoch or 0;row.mode='Captured'
                row.releaseAt=self.now+self.config.captureSeconds;self.heroes[slot]=row
                self:_log('DragonCaptured',row)
                return
            end
        end
    end
    self:_log('DragonCaptureMiss',row)
end
function Flight:enemyStep(id,e,dt)
    local row=self:_row(id);if not row then return end
    if e.reactionUntil then self.world:stopDragon(id);return end
    if row.mode=='Disabled' then
        self.world:stopDragon(id)
        if self.now<row.disabledUntil then return end
        row.mode='Approach';row.disabledUntil=nil
    end
    local floor=self.world:dragonFloor(id);if floor then row.homeY=floor end
    local height=row.homeY+self.config.altitude
    if row.liftUntil and self.now<row.liftUntil then height+=self.config.liftHeight end
    local x,z=0,0
    if row.mode=='Mounted' then
        local move=row.move
        if row.slot and self.session.state.heroes[row.slot].connected and move and self.now-move.at<self.director.config.MoveTimeout then x,z=move.x,move.z end
    elseif row.mode=='Captured' then
        height+=self.config.captureHeight
    elseif row.capture then
        if self.now>=row.capture.at then self:_capture(row) end
    elseif e.windup then
        if self.now>=e.windup.at then
            self.director:_resolveStrike(id,e);row.mode='Turn';row.turnUntil=self.now+self.config.turnSeconds
        end
    elseif row.mode=='Turn' and self.now<(row.turnUntil or 0) then
        x,z=0,0
    elseif e.ownerUserId then
        local move=e.dragonMove
        if e.connected and move and self.now-move.at<self.director.config.MoveTimeout then x,z=move.x,move.z end
    else
        row.mode='Approach'
        local target,range=self.director:_nearest(self.world:position(id))
        if target then
            local a,b=self.world:position(id),self.world:position(target)
            local dx,dz=b.x-a.x,b.z-a.z;local length=math.sqrt(dx*dx+dz*dz)
            if range<=self.config.attackRange and self.now>=e.nextAttack then
                self.world:face(id,target);self.director:_beginStrike(id,e,target)
            elseif length>.5 then x,z=dx/length,dz/length end
        end
    end
    self.world:dragonMotion(id,x,z,height,self.config.speed)
end
function Flight:_shotStep(id,shot,dt)
    if self.now>=shot.expires then return true end
    local a=shot.position;local d=shot.direction;local amount=shot.speed*dt
    local b={x=a.x+d.x*amount,y=a.y+d.y*amount,z=a.z+d.z*amount}
    local targets,wall=self.world:dragonFireTargets(a,b,shot.radius,{[shot.slot]=true,[shot.dragon]=true})
    for _,target in ipairs(targets) do
        local e=self.director.enemies[target];local h=self.session.state.heroes[target];local c=self.session.combat[target]
        local hit=false
        if e and not e.dead and not e.boss and not e.heavyReaction then hit=self.director:hit(shot.slot,target,'DragonFire',shot.tuning)
        elseif h and h.status=='Alive' and c and not (c.reactionEnd and c.heavyReaction) then
            hit=self.session:_hit(shot.slot,target,'DragonFire',shot.tuning)
        end
        if hit then self.session:_record('DragonFireHit',shot.slot,{target=target,projectileId=id,heroActorId=shot.heroActorId});return true end
    end
    if wall then return true end
    shot.position=b;self.world:dragonFire(id,b)
    return false
end
function Flight:step(now,dt)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    if not self:_active() then self:close();return 'RUN_CLOSED' end
    for _,id in ipairs(sortedKeys(self.states)) do
        local row=self.states[id]
        if row.slot then
            if not self:_valid(row) then self:_release(row,'ActorChanged')
            elseif row.mode=='Captured' and now>=row.releaseAt then self:_release(row,'CaptureComplete')
            elseif not self.world:dragonLink(id,row.slot,row.mode) then self:_release(row,'PhysicalLinkLost') end
        end
    end
    local delta=finite(dt) and math.clamp(dt,0,.1) or 0
    for _,id in ipairs(sortedKeys(self.shots)) do
        if self:_shotStep(id,self.shots[id],delta) then self.world:removeDragonFire(id);self.shots[id]=nil end
    end
    return 'OK'
end
function Flight:close()
    if self.closed then return end
    self.closed=true
    for _,id in ipairs(sortedKeys(self.states)) do self:forgetEnemy(id) end
    for id in pairs(self.shots) do self.world:removeDragonFire(id) end
    self.shots={}
end
return Flight
