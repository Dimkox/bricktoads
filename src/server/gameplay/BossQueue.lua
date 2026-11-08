-- Server-owned FIFO selection. Slots may compete, but each user has one queue/role state.
-- All methods are synchronous; eligibility is supplied by the authoritative controller.
-- The eligibility callback must not yield, mutate this queue, or reenter its methods.
local BossQueue={}
BossQueue.__index=BossQueue

local function finite(value)
    return type(value)=='number' and value==value and value>-math.huge and value<math.huge
end
local function identifier(value)
    return type(value)=='string' and #value>0 and #value<=160
end
local function validUser(userId)
    -- Studio clients use negative IDs; the server has already authenticated the identity.
    return finite(userId) and userId%1==0 and math.abs(userId)<=9007199254740991
end

function BossQueue.new(options,eligible)
    options=options or {}
    local inviteSeconds=options.inviteSeconds or 10
    local connectSeconds=options.connectSeconds or 15
    assert(finite(inviteSeconds) and inviteSeconds>0,'Invalid invitation duration')
    assert(finite(connectSeconds) and connectSeconds>0,'Invalid connection duration')
    assert(eligible==nil or type(eligible)=='function','Invalid eligibility callback')
    return setmetatable({inviteSeconds=inviteSeconds,connectSeconds=connectSeconds,
        eligible=eligible or function() return true end,entries={},waiting={},slots={},slotOrder={},serial=0,now=0},BossQueue)
end

function BossQueue:_removeWaiting(entry)
    local waiting=self.waiting[entry.bossId]
    if not waiting then return end
    for index,userId in ipairs(waiting) do
        if userId==entry.userId then table.remove(waiting,index); return end
    end
end

function BossQueue:_release(entry)
    local slot=entry.slotId and self.slots[entry.slotId]
    if slot and slot.userId==entry.userId then slot.userId=nil end
    entry.slotId=nil; entry.offerId=nil; entry.deadline=nil
end

function BossQueue:_forget(entry)
    self:_removeWaiting(entry)
    self:_release(entry)
    self.entries[entry.userId]=nil
end

function BossQueue:_rotate(entry)
    self:_removeWaiting(entry)
    self:_release(entry)
    entry.state='Queued'
    local waiting=self.waiting[entry.bossId]
    waiting[#waiting+1]=entry.userId
end

function BossQueue:_fill()
    -- Registration order is stable even when slot identifiers sort differently.
    for _,slot in ipairs(self.slotOrder) do
        if slot.state=='Open' and not slot.userId then
            for _,userId in ipairs(self.waiting[slot.bossId] or {}) do
                local entry=self.entries[userId]
                if entry and entry.state=='Queued' and not slot.tried[userId] and self.eligible(userId,slot.context) then
                    self.serial+=1
                    entry.state='Invited'; entry.slotId=slot.id
                    entry.offerId='boss-offer:'..self.serial; entry.deadline=self.now+self.inviteSeconds
                    slot.userId=userId; slot.tried[userId]=true
                    break
                end
            end
        end
    end
end

function BossQueue:_advance(now)
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    -- A delayed caller cannot roll back deadlines already observed by the server.
    self.now=math.max(self.now,now)
    for _,slot in ipairs(self.slotOrder) do
        if slot.state=='Open' and slot.userId then
            local entry=self.entries[slot.userId]
            if not entry or entry.slotId~=slot.id then
                slot.userId=nil
            elseif (entry.deadline and self.now>=entry.deadline) or not self.eligible(entry.userId,slot.context) then
                if entry.state=='Invited' then self:_rotate(entry)
                else self:_forget(entry) end
            end
        end
    end
    self:_fill()
    return 'OK'
end

function BossQueue:register(slotId,bossId,context,now)
    if not identifier(slotId) then return 'INVALID_SLOT' end
    if not identifier(bossId) then return 'INVALID_BOSS' end
    local result=self:_advance(now); if result~='OK' then return result end
    if self.slots[slotId] then return 'SLOT_EXISTS' end
    local slot={id=slotId,bossId=bossId,context=context,state='Open',tried={}}
    self.slots[slotId]=slot; self.slotOrder[#self.slotOrder+1]=slot
    self:_fill()
    return 'OK'
end

function BossQueue:select(userId,bossId,now)
    if not validUser(userId) then return 'INVALID_USER' end
    if not identifier(bossId) then return 'INVALID_BOSS' end
    local result=self:_advance(now); if result~='OK' then return result end
    local entry=self.entries[userId]
    if entry and entry.bossId==bossId then return 'OK' end
    if entry and (entry.state=='Accepted' or entry.state=='Ready' or entry.state=='Active') then return 'ROLE_RESERVED' end
    if not self.eligible(userId,nil) then return 'INELIGIBLE' end
    if entry then self:_forget(entry) end
    entry={userId=userId,bossId=bossId,state='Queued'}
    self.entries[userId]=entry
    local waiting=self.waiting[bossId]
    if not waiting then waiting={}; self.waiting[bossId]=waiting end
    waiting[#waiting+1]=userId
    self:_fill()
    return 'OK'
end

function BossQueue:cancel(userId,now)
    if not validUser(userId) then return 'INVALID_USER' end
    local result=self:_advance(now); if result~='OK' then return result end
    local entry=self.entries[userId]
    if not entry then return 'OK' end
    if entry.state=='Active' then return 'ROLE_ACTIVE' end
    self:_forget(entry); self:_fill()
    return 'OK'
end

function BossQueue:reply(userId,offerId,accepted,now)
    if not validUser(userId) then return 'INVALID_USER' end
    if not identifier(offerId) then return 'INVALID_OFFER' end
    if type(accepted)~='boolean' then return 'INVALID_REPLY' end
    local result=self:_advance(now); if result~='OK' then return result end
    local entry=self.entries[userId]
    if not entry or entry.offerId~=offerId then return 'STALE_OFFER' end
    if entry.state~='Invited' then
        if accepted and (entry.state=='Accepted' or entry.state=='Ready' or entry.state=='Active') then return 'OK' end
        return 'STALE_OFFER'
    end
    if accepted then
        self:_removeWaiting(entry)
        entry.state='Accepted'; entry.deadline=self.now+self.connectSeconds
    else
        -- tried is retained by the slot, so this entry can only serve a future slot.
        self:_rotate(entry)
    end
    self:_fill()
    return 'OK'
end

function BossQueue:connect(userId,offerId,now)
    if not validUser(userId) then return 'INVALID_USER' end
    if not identifier(offerId) then return 'INVALID_OFFER' end
    local result=self:_advance(now); if result~='OK' then return result end
    local entry=self.entries[userId]
    if not entry or entry.offerId~=offerId then return 'STALE_OFFER' end
    if entry.state=='Ready' or entry.state=='Active' then return 'OK' end
    if entry.state~='Accepted' then return 'STALE_OFFER' end
    entry.state='Ready'; entry.deadline=nil
    return 'OK'
end

function BossQueue:step(now)
    return self:_advance(now)
end

function BossQueue:start(slotId,now)
    local result=self:_advance(now); if result~='OK' then return nil,result end
    local slot=self.slots[slotId]
    if not slot then return nil,'UNKNOWN_SLOT' end
    if slot.state=='Closed' then return nil,'SLOT_CLOSED' end
    if slot.state=='NPC' then return {state='NPC'} end
    if slot.state=='Human' then return {state='Human',userId=slot.userId} end
    local entry=slot.userId and self.entries[slot.userId]
    if entry then
        if entry.state~='Ready' then return {state='Waiting'} end
        entry.state='Active'; slot.state='Human'
        return {state='Human',userId=entry.userId}
    end
    slot.state='NPC'
    return {state='NPC'}
end

function BossQueue:close(slotId,now)
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    local slot=self.slots[slotId]
    if not slot then return 'UNKNOWN_SLOT' end
    -- Close before processing deadlines: expiry must not rotate this owner or
    -- create a replacement offer that closing would immediately discard.
    if slot.userId then
        local entry=self.entries[slot.userId]
        if entry then self:_forget(entry) end
    end
    slot.userId=nil; slot.state='Closed'
    return self:_advance(now)
end

function BossQueue:view(userId,now)
    local result=self:_advance(now); if result~='OK' then return {state='None'},result end
    local entry=self.entries[userId]
    if not entry then return {state='None'} end
    local view={state=entry.state,bossId=entry.bossId,offerId=entry.offerId,
        slotId=entry.slotId,deadline=entry.deadline}
    if entry.state=='Queued' or entry.state=='Invited' then
        for position,id in ipairs(self.waiting[entry.bossId]) do
            if id==userId then view.position=position; break end
        end
    end
    return view
end

return BossQueue
