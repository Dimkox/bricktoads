-- Existing-body Pig pickup/throw. Reach, timing and ordinary damage are Roblox calibration.
-- Source throw profile17/raw4 is provenance; this module never creates projectile collateral damage.
local EnemyCarry={}
EnemyCarry.__index=EnemyCarry
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end

function EnemyCarry.new(director)
    return setmetatable({director=director,session=director.session,world=director.world,
        config=director.config.EnemyCarry,now=director.now or director.session.now,
        pending={},pendingBySlot={},states={},holders={}},EnemyCarry)
end

function EnemyCarry:_hero(slot,offline)
    if self.closed or self.director.result or self.session.state.status~='Active' then return nil end
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    if not h or h.status~='Alive' or (not offline and not h.connected) or not h.actorId
        or not c or c.deathAt or c.reactionEnd or c.attack or self.world:hazard(slot) then return nil end
    return h,c
end

function EnemyCarry:_sameHero(row,offline)
    local h,c=self:_hero(row.slot,offline)
    return h and h.actorId==row.heroActorId and h.attempt==row.attempt
        and self.session.state.levelEpoch==row.levelEpoch and c==row.combat
        and (c.reactionEpoch or 0)==row.heroReactionEpoch
end

function EnemyCarry:_sameEnemy(row)
    local e=self.director.enemies[row.id]
    return e and e==row.enemy and not e.dead and e.actorId==row.enemyActorId
end

function EnemyCarry:_eligible(id,e,slot)
    return e.kind=='Pig' and not e.boss and not e.dead and not self.states[id]
        and not (e.reactionUntil and self.now<e.reactionUntil) and not self.world:hazard(id)
        and self.world:canGrabEnemy(slot,id,self.config.range,self.config.height,self.config.facingDot)
end

function EnemyCarry:_nearest(slot)
    local origin=self.world:position(slot)
    if not origin then return nil end
    local selected,best=nil,math.huge
    for id,e in pairs(self.director.enemies) do
        if self:_eligible(id,e,slot) then
            local p=self.world:position(id)
            if p then
                local range=(p.x-origin.x)^2+(p.y-origin.y)^2+(p.z-origin.z)^2
                if range<best or (range==best and (not selected or id<selected)) then selected,best=id,range end
            end
        end
    end
    return selected
end

function EnemyCarry:_log(kind,row,data)
    data=data or {}
    data.enemyId=row.id;data.enemyActorId=row.enemyActorId;data.heroActorId=row.heroActorId
    self.session:_record(kind,row.slot,data)
end

function EnemyCarry:_remove(row,reason)
    if self.states[row.id]~=row then return end
    self.states[row.id]=nil
    if self.holders[row.slot]==row.id then self.holders[row.slot]=nil end
    self.world:releaseEnemy(row.id)
    local e=self.director.enemies[row.id]
    if row.mode=='Thrown' and e==row.enemy and e.reactionUntil==row.untilTime then
        if e.rawLife~=nil and reason=='FlightComplete' then self.director:_finishReaction(row.id,e)
        else e.reactionUntil=nil;e.heavyReaction=nil;self.world:setReaction(row.id,false) end
    end
    if row.mode=='Carried' then self:_log('EnemyDropped',row,{reason=reason}) end
end

function EnemyCarry:stateFor(id)
    local row=self.states[id]
    return row and row.mode or nil
end

function EnemyCarry:blocksEnemy(id)
    return self.states[id]~=nil
end

function EnemyCarry:interaction(slot)
    self.now=math.max(self.now,self.session.now,self.director.now or 0)
    local id=self.holders[slot];local row=id and self.states[id]
    if row and row.mode=='Carried' then
        return {available=self:_sameHero(row,false)==true and self:_sameEnemy(row)==true and not self.world:hazard(row.id),
            carrying=true,kind='EnemyCarry',label='БРОСИТЬ ВРАГА'}
    end
    if not self:_hero(slot) or self.pendingBySlot[slot] then return {available=false,carrying=false} end
    return {available=self:_nearest(slot)~=nil,carrying=false,kind='EnemyCarry',label='СХВАТИТЬ'}
end

function EnemyCarry:_throw(row,now)
    if not self:_sameHero(row,false) or not self:_sameEnemy(row) then
        self:_remove(row,'HolderChanged');return 'NO_INTERACTION'
    end
    if self.world:hazard(row.id) then
        self.director:_kill(row.id);self:forgetEnemy(row.id);return 'NOT_ALIVE'
    end
    local h=self.session.state.heroes[row.slot]
    local code=self.session:_event('BeginAttack',row.slot,{connectionEpoch=h.connectionEpoch})
    if code~='OK' then return code end
    self.world:hold(row.slot,false)
    if not self.world:releaseEnemy(row.id,row.slot,self.config) then return 'CARRY_RELEASE_FAILED' end
    row.mode='Thrown';row.untilTime=now+self.config.reaction
    self.holders[row.slot]=nil
    local e=row.enemy
    e.windup=nil;e.lastMove=nil;e.reactionUntil=row.untilTime
    self.world:setReaction(row.id,true)
    local before=e.health
    -- The existing death callback may forget this very state. Do not recreate it afterward.
    self.director:applyThrowDamage(row.id,row.slot)
    row.enemyReactionEpoch=e.reactionEpoch or 0
    self:_log('EnemyThrown',row,{before=before,after=e.health,damage=self.config.throwDamage,
        sourceProfile=self.config.sourceProfile,sourceRawDamage=self.config.sourceRawDamage})
    return 'OK'
end

function EnemyCarry:interact(slot,now,action)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    if self.closed or self.director.result or self.session.state.status~='Active' then return 'NO_INTERACTION' end
    local id=self.holders[slot];local held=id and self.states[id]
    if held and held.mode=='Carried' then
        if action~='Punch' then return 'HANDS_FULL' end
        return self:_throw(held,now)
    end
    if action~='Punch' then return 'NO_INTERACTION' end
    local h,c=self:_hero(slot)
    if not h then return 'NO_INTERACTION' end
    if self.pendingBySlot[slot] then return 'COOLDOWN' end
    id=self:_nearest(slot)
    if not id then return 'NO_INTERACTION' end
    local code=self.session:_event('BeginAttack',slot,{connectionEpoch=h.connectionEpoch})
    if code~='OK' then return code end
    self.world:hold(slot,false)
    local e=self.director.enemies[id]
    local row={id=id,slot=slot,enemy=e,enemyActorId=e.actorId,enemyReactionEpoch=e.reactionEpoch or 0,
        heroActorId=h.actorId,attempt=h.attempt,levelEpoch=self.session.state.levelEpoch,
        combat=c,heroReactionEpoch=c.reactionEpoch or 0,at=now+self.config.windup}
    row.expiresAt=row.at+self.config.window
    self.pending[#self.pending+1]=row;self.pendingBySlot[slot]=row
    e.engaged=true
    self:_log('EnemyGrabAccepted',row)
    return 'OK'
end

function EnemyCarry:_capture(row)
    if row.cancelled or self.now>row.expiresAt or self.holders[row.slot]
        or not self:_sameHero(row,true) or not self:_sameEnemy(row)
        or (row.enemy.reactionEpoch or 0)~=row.enemyReactionEpoch
        or not self:_eligible(row.id,row.enemy,row.slot) then return end
    -- Director resolves expired reactions later in this tick. Normalize that
    -- old physics before World saves it, so a future drop cannot restore it.
    if row.enemy.reactionUntil and self.now>=row.enemy.reactionUntil then
        if row.enemy.rawLife~=nil then self.director:_finishReaction(row.id,row.enemy)
        else row.enemy.reactionUntil=nil;self.world:setReaction(row.id,false) end
    end
    if not self.world:carryEnemy(row.id,row.slot) then return end
    row.mode='Carried';self.states[row.id]=row;self.holders[row.slot]=row.id
    row.enemy.windup=nil;row.enemy.lastMove=nil;row.enemy.reactionUntil=nil
    self.world:move(row.id,0,0)
    self:_log('EnemyGrabbed',row,{health=row.enemy.health,ownerUserId=row.enemy.ownerUserId})
end

function EnemyCarry:step(now)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    if self.closed then return 'RUN_CLOSED' end
    if self.director.result or self.session.state.status~='Active' then self:close();return 'RUN_CLOSED' end
    local active={}
    for id in pairs(self.states) do active[#active+1]=id end
    table.sort(active)
    for _,id in ipairs(active) do
        local row=self.states[id]
        if row then
            if not self:_sameEnemy(row) then self:_remove(row,'EnemyChanged')
            elseif self.world:hazard(id) then self.director:_kill(id);self:forgetEnemy(id)
            elseif row.mode=='Carried' then
                if not self:_sameHero(row,true) or (row.enemy.reactionEpoch or 0)~=row.enemyReactionEpoch then
                    self:_remove(row,'Interrupted')
                elseif not self.world:carryEnemy(id,row.slot) then self:_remove(row,'PhysicalLinkLost') end
            elseif (row.enemy.reactionEpoch or 0)~=row.enemyReactionEpoch then self:_remove(row,'EnemyInterrupted')
            elseif now>=row.untilTime then self:_remove(row,'FlightComplete') end
        end
    end
    local future={}
    for _,row in ipairs(self.pending) do
        if row.cancelled or now>=row.at then
            if self.pendingBySlot[row.slot]==row then self.pendingBySlot[row.slot]=nil end
            if not row.cancelled then self:_capture(row) end
        else future[#future+1]=row end
    end
    self.pending=future
    return 'OK'
end

function EnemyCarry:forgetEnemy(id)
    local row=self.states[id]
    if row then self:_remove(row,'EnemyReleased') end
    for _,pending in ipairs(self.pending) do
        if pending.id==id then
            pending.cancelled=true
            if self.pendingBySlot[pending.slot]==pending then self.pendingBySlot[pending.slot]=nil end
        end
    end
end

function EnemyCarry:close()
    if self.closed then return end
    self.closed=true
    local active={};for id in pairs(self.states) do active[#active+1]=id end
    for _,id in ipairs(active) do self:_remove(self.states[id],'RunClosed') end
    self.pending={};self.pendingBySlot={};self.holders={}
end

return EnemyCarry
