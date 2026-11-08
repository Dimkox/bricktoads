-- One source-backed Walker leg-club per combat death. Geometry/timing/NPC HP are Roblox calibration.
-- Only validated primary intents reach this module; no packet chooses an item, target or damage.
local WalkerClubs={}
WalkerClubs.__index=WalkerClubs
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function point(p) return type(p)=='table' and finite(p.x) and finite(p.y) and finite(p.z) end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end

function WalkerClubs.new(director)
    return setmetatable({director=director,session=director.session,world=director.world,
        config=director.config.WalkerClub,attack=director.config.Attacks.Club,
        now=director.now or director.session.now,items={},sources={},equipment={},pending={},pendingBySlot={}},WalkerClubs)
end

function WalkerClubs:_active()
    return not self.closed and not self.director.result and self.session.state.status=='Active'
end

function WalkerClubs:_hero(slot,offline)
    if not self:_active() then return nil end
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    if not h or h.status~='Alive' or (not offline and not h.connected) or not h.actorId
        or not c or c.deathAt or c.reactionEnd or c.attack or self.world:hazard(slot) then return nil end
    return h,c
end

function WalkerClubs:_log(kind,slot,data)
    self.session:_record(kind,slot,data)
end

function WalkerClubs:walkerDefeated(id,position,cause)
    local e=self.director.enemies[id]
    if not self:_active() or cause~='Combat' or not e or e.kind~='Walker'
        or type(e.actorId)~='string' or self.sources[e.actorId] then return nil end
    local itemId='walker-club:'..e.actorId
    local item={id=itemId,sourceActorId=e.actorId,state='Lost'}
    self.sources[e.actorId]=itemId;self.items[itemId]=item
    local ground=point(position) and self.world:groundPosition(position)
    if not point(ground) then return nil end
    item.state='Ground';item.position=copy(ground)
    self.world:clubItem(itemId,item.position)
    self:_log('WalkerClubCreated',nil,{itemId=itemId,enemyId=id,enemyActorId=e.actorId,position=copy(ground)})
    return itemId
end

function WalkerClubs:_sameOwner(slot,row)
    local h,c=self.session.state.heroes[slot],self.session.combat[slot]
    return h and h.actorId==row.actorId and h.attempt==row.attempt
        and self.session.state.levelEpoch==row.levelEpoch and c==row.combat
end

function WalkerClubs:_sync(slot)
    local row=self.equipment[slot]
    if not row then return nil end
    -- Read the current position only after identity matches: a replacement actor
    -- must never supply a fresh safe drop position for the previous weapon.
    if self:_sameOwner(slot,row) then
        local position=self.world:position(slot)
        if point(position) then row.lastPosition=copy(position) end
        local h,c=self.session.state.heroes[slot],self.session.combat[slot]
        if h.status=='Alive' and not c.deathAt and not self.world:hazard(slot)
            and (c.heavyReactionEpoch or 0)==row.heavyReactionEpoch then return row end
    end
    self:drop(slot,'OwnerChangedOrHeavyReaction')
    return nil
end

function WalkerClubs:hasClub(slot)
    return not self.closed and self:_sync(slot)~=nil
end

function WalkerClubs:_nearest(slot)
    local position=self.world:position(slot)
    if not point(position) then return nil end
    local selected,best=nil,math.huge
    for id,item in pairs(self.items) do
        if item.state=='Ground' and point(item.position)
            and self.world:canPickupClub(slot,item.position,self.config.pickupRange,self.config.pickupHeight) then
            local p=item.position
            local range=(p.x-position.x)^2+(p.y-position.y)^2+(p.z-position.z)^2
            if range<best or (range==best and (not selected or id<selected.id)) then selected,best=item,range end
        end
    end
    return selected
end

function WalkerClubs:interaction(slot)
    self.now=math.max(self.now,self.session.now,self.director.now or 0)
    if not self:_active() then return {available=false,carrying=false,equipped=false} end
    local row=self:_sync(slot)
    if row then
        return {available=self:_hero(slot)~=nil,kind='WalkerClub',label="CLUB HIT",carrying=false,equipped=true}
    end
    return {available=self:_hero(slot)~=nil and self:_nearest(slot)~=nil,
        kind='WalkerClub',label="PICK UP CLUB",carrying=false,equipped=false}
end

function WalkerClubs:_swing(slot,row,now,h,c)
    if self.pendingBySlot[slot] then return 'COOLDOWN' end
    local code=self.session:_event('BeginAttack',slot,{connectionEpoch=h.connectionEpoch})
    if code~='OK' then return code end
    self.world:hold(slot,false)
    local pending={slot=slot,item=row.item,equipment=row,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=self.session.state.levelEpoch,combat=c,reactionEpoch=c.reactionEpoch or 0,
        at=now+self.attack.windup}
    pending.expiresAt=pending.at+self.attack.window
    self.pending[#self.pending+1]=pending;self.pendingBySlot[slot]=pending
    c.nextAttack=math.max(c.nextAttack or 0,now+self.attack.cooldown)
    self.director.now=now
    self.director:closeTargetForAttack(self.world:targets(slot,self.attack))
    self.world:clubSwing(row.item.id,slot)
    self:_log('ClubSwingAccepted',slot,{itemId=row.item.id,sourceEnemyProfile=2,sourceHeroProfile=20})
    return 'OK'
end

function WalkerClubs:interact(slot,now,action)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    if not self:_active() or action~='Punch' then return 'NO_INTERACTION' end
    local row=self:_sync(slot)
    local h,c=self:_hero(slot)
    if not h then return 'NO_INTERACTION' end
    if row then return self:_swing(slot,row,now,h,c) end
    local item=self:_nearest(slot)
    if not item then return 'NO_INTERACTION' end
    local origin=self.world:position(slot)
    if not self.world:equipClub(item.id,slot) then return 'CLUB_EQUIP_FAILED' end
    local x,z=item.position.x-origin.x,item.position.z-origin.z
    if x*x+z*z>0 then self.world:aim(slot,x,z) end
    item.state='Equipped';item.slot=slot
    self.equipment[slot]={item=item,actorId=h.actorId,attempt=h.attempt,levelEpoch=self.session.state.levelEpoch,
        combat=c,heavyReactionEpoch=c.heavyReactionEpoch or 0,lastPosition=copy(self.world:position(slot))}
    self.world:clubItem(item.id,nil)
    self:_log('ClubEquipped',slot,{itemId=item.id})
    return 'OK'
end

function WalkerClubs:drop(slot,reason)
    local row=self.equipment[slot]
    if not row then return false end
    if self:_sameOwner(slot,row) then
        local position=self.world:position(slot)
        if point(position) then row.lastPosition=copy(position) end
    end
    self.equipment[slot]=nil
    local pending=self.pendingBySlot[slot]
    if pending then pending.cancelled=true;self.pendingBySlot[slot]=nil end
    local item=row.item
    self.world:unequipClub(item.id)
    item.slot=nil;item.state='Lost';item.position=nil
    local ground=point(row.lastPosition) and self.world:groundPosition(row.lastPosition)
    if point(ground) then item.state='Ground';item.position=copy(ground);self.world:clubItem(item.id,item.position)
    else self.world:clubItem(item.id,nil) end
    self:_log('ClubDropped',slot,{itemId=item.id,reason=reason,supported=item.state=='Ground',position=item.position})
    return true
end

function WalkerClubs:bossIntro()
    if self.bossIntroduced or self.closed then return end
    self.bossIntroduced=true
    local owners={};for slot in pairs(self.equipment) do owners[#owners+1]=slot end
    table.sort(owners)
    for _,slot in ipairs(owners) do self:drop(slot,'BossIntro') end
end

function WalkerClubs:_resolve(pending)
    local slot=pending.slot
    local h,c=self:_hero(slot,true)
    if pending.cancelled or self.now>pending.expiresAt or not h or h.actorId~=pending.actorId
        or h.attempt~=pending.attempt or self.session.state.levelEpoch~=pending.levelEpoch
        or c~=pending.combat or (c.reactionEpoch or 0)~=pending.reactionEpoch
        or self.equipment[slot]~=pending.equipment or pending.equipment.item~=pending.item then return end
    for _,target in ipairs(self.world:targets(slot,self.attack)) do
        if self.session:_hit(slot,target,'Club') then
            self:_log('ClubSwingHit',slot,{itemId=pending.item.id,target=target});break
        end
    end
end

function WalkerClubs:step(now)
    if not finite(now) or now<self.now then return 'INVALID_TIME' end
    self.now=now
    if self.closed then return 'RUN_CLOSED' end
    if not self:_active() then self:close();return 'RUN_CLOSED' end
    local owners={};for slot in pairs(self.equipment) do owners[#owners+1]=slot end
    table.sort(owners)
    for _,slot in ipairs(owners) do self:_sync(slot) end
    local future={}
    for _,pending in ipairs(self.pending) do
        if pending.cancelled or now>=pending.at then
            if self.pendingBySlot[pending.slot]==pending then self.pendingBySlot[pending.slot]=nil end
            if not pending.cancelled then self:_resolve(pending) end
        else future[#future+1]=pending end
    end
    self.pending=future
    return 'OK'
end

function WalkerClubs:close()
    if self.closed then return end
    self.closed=true;self.pending={};self.pendingBySlot={};self.equipment={}
    for id,item in pairs(self.items) do
        self.world:unequipClub(id);self.world:clubItem(id,nil);item.state='Lost';item.slot=nil;item.position=nil
    end
end

return WalkerClubs
