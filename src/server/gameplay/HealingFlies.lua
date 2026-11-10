-- Source-backed food arithmetic; flight, reach and timing are Roblox calibration.
-- No remote accepts an item, target position or heal amount from the client.
local HealingFlies={}
HealingFlies.__index=HealingFlies
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end

function HealingFlies.new(session,world,config)
    local self=setmetatable({session=session,world=world,config=config.HealingFlies,rows={},byId={},
        pending={},pendingBySlot={},now=session.now,consumed=0},HealingFlies)
    for zoneIndex,zone in ipairs(config.Level and config.Level.zones or {}) do
        for _,point in ipairs(zone.flies or {}) do
            assert(type(point.id)=='string' and not self.byId[point.id],'Fly IDs must be unique')
            local row={id=point.id,zone=zoneIndex,x=point.x,y=point.y,z=point.z}
            self.rows[#self.rows+1]=row;self.byId[row.id]=row
        end
    end
    return self
end

function HealingFlies:_position(row)
    return {x=row.x,y=row.y+math.sin(self.now*self.config.bobSpeed+row.zone)*self.config.bobHeight,z=row.z}
end

function HealingFlies:activate(zoneIndex)
    if self.closed then return end
    for _,row in ipairs(self.rows) do
        if row.zone==zoneIndex and not row.consumed then
            row.active=true;self.world:healingFly(row.id,self:_position(row))
        end
    end
end

function HealingFlies:_hero(slot,offline)
    if self.closed or self.session.state.status~='Active' then return nil end
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    if not h or h.status~='Alive' or (not offline and not h.connected) or not h.actorId
        or not c or c.deathAt or c.reactionEnd or c.attack or self.world:hazard(slot) then return nil end
    return h,c
end

function HealingFlies:_reachable(slot,row)
    return row.active and not row.consumed and self.world:canCatchFly(slot,self:_position(row),
        self.config.range,self.config.height,self.config.facingDot)
end

function HealingFlies:_nearest(slot)
    local origin=self.world:position(slot)
    if not origin then return nil end
    local selected,best=nil,math.huge
    for _,row in ipairs(self.rows) do
        if self:_reachable(slot,row) then
            local p=self:_position(row)
            local range=(origin.x-p.x)^2+(origin.y-p.y)^2+(origin.z-p.z)^2
            if range<best then selected,best=row,range end
        end
    end
    return selected
end

function HealingFlies:interaction(slot)
    self.now=math.max(self.now,self.session.now)
    if not self:_hero(slot) or self.pendingBySlot[slot] then return {available=false} end
    return {available=self:_nearest(slot)~=nil,label="CATCH FLY",kind='HealingFly',carrying=false}
end

function HealingFlies:interact(slot,now)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    local h,c=self:_hero(slot)
    if not h then return 'NO_INTERACTION' end
    if self.pendingBySlot[slot] then return 'COOLDOWN' end
    local row=self:_nearest(slot)
    if not row then return 'NO_INTERACTION' end
    local code=self.session:_event('BeginAttack',slot,{connectionEpoch=h.connectionEpoch})
    if code~='OK' then return code end
    self.world:hold(slot,false)
    local pending={slot=slot,row=row,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=self.session.state.levelEpoch,at=now+self.config.windup,combat=c,reactionEpoch=c.reactionEpoch or 0}
    self.pending[#self.pending+1]=pending;self.pendingBySlot[slot]=pending
    return 'OK'
end

function HealingFlies:_catch(pending)
    local h,c=self:_hero(pending.slot,true)
    if not h or h.actorId~=pending.actorId or h.attempt~=pending.attempt
        or c~=pending.combat or (c.reactionEpoch or 0)~=pending.reactionEpoch
        or self.session.state.levelEpoch~=pending.levelEpoch or not self:_reachable(pending.slot,pending.row) then return end
    local before=c.rawLife
    local after=math.min(47,before+8)
    local code=self.session:_event('SetHealth',pending.slot,{health=self.session.Combat.hearts(after)})
    if code~='OK' then return end
    c.rawLife=after;pending.row.consumed=true;pending.row.active=false;self.consumed+=1
    self.world:catchFly(pending.slot,pending.row.id)
    self.session:_record('FlyCaught',pending.slot,{flyId=pending.row.id,before=before,after=after})
end

function HealingFlies:step(now)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    if self.closed then return 'RUN_CLOSED' end
    if self.session.state.status~='Active' then self:close();return 'RUN_CLOSED' end
    local future={}
    for _,pending in ipairs(self.pending) do
        if now>=pending.at then
            self.pendingBySlot[pending.slot]=nil
            self:_catch(pending)
        else future[#future+1]=pending end
    end
    self.pending=future
    for _,row in ipairs(self.rows) do
        if row.active then self.world:healingFly(row.id,self:_position(row)) end
    end
    return 'OK'
end

function HealingFlies:snapshot()
    local active=0
    for _,row in ipairs(self.rows) do if row.active then active+=1 end end
    return {active=active,consumed=self.consumed,total=#self.rows}
end

function HealingFlies:close()
    if self.closed then return end
    self.closed=true;self.pending={};self.pendingBySlot={}
    for _,row in ipairs(self.rows) do
        row.active=false;self.world:healingFly(row.id,nil)
    end
end

return HealingFlies
