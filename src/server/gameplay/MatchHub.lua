-- Current-Player authority and routing for independent local playable groups.
local MatchHub={}
MatchHub.__index=MatchHub

local function identifier(value)
    return type(value)=='string' and #value>0 and #value<=160
end
local function exact(payload,allowed)
    if type(payload)~='table' then return false end
    for key in pairs(payload) do if not allowed[key] then return false end end
    return true
end
local function active(controller)
    return controller.current~=nil and not controller:_open()
end

-- The Hub registry owns connection tombstones. Group registries own only routed
-- membership, so the same current Player can return after an observer transfer.
local function groupRegistry(hub,groupId)
    local registry={current={},arrivals=setmetatable({},{__mode='k'}),serial=0}
    function registry:join(player)
        if not hub.connections:isCurrent(player) or hub.routes[player.UserId]~=groupId then return false end
        local previous=self.current[player.UserId]
        if previous==player then return false end
        self.serial+=1; self.arrivals[player]=self.serial; self.current[player.UserId]=player
        return true,previous
    end
    function registry:isCurrent(player)
        return hub.connections:isCurrent(player) and hub.routes[player.UserId]==groupId and self.current[player.UserId]==player
    end
    function registry:remove(player)
        if self.current[player.UserId]~=player then return false end
        self.current[player.UserId]=nil
        return true
    end
    function registry:online(players)
        local online,seen={},{}
        for _,player in ipairs(players) do
            if self:isCurrent(player) and not seen[player] then
                online[#online+1]=player; seen[player]=true
            end
        end
        table.sort(online,function(a,b) return self.arrivals[a]<self.arrivals[b] end)
        return online
    end
    return registry
end

function MatchHub.new(deps,worldFactory)
    assert(type(worldFactory)=='function','World factory is required')
    local configured=deps.Config.Groups and deps.Config.Groups.maxGroups or 4
    assert(type(configured)=='number' and configured>=1 and configured%1==0,'Invalid group capacity')
    local self=setmetatable({deps=deps,worldFactory=worldFactory,maxGroups=math.min(4,configured),
        connections=deps.Registry.new(),groups={},order={},routes={},requests={},
        buckets=setmetatable({},{__mode='k'}),notices=setmetatable({},{__mode='k'}),
        envelopes=setmetatable({},{__mode='k'}),snapshotSeq=setmetatable({},{__mode='k'})},MatchHub)
    self.queue=deps.BossQueue.new(deps.Config.BossQueue,function(userId,context)
        return self:_queueEligible(userId,context)
    end)
    self:_create()
    return self
end

function MatchHub:_create()
    local index=#self.order+1; local id='group-'..index
    local world=self.worldFactory(index,id)
    local controllerDeps=table.clone(self.deps)
    controllerDeps.GroupId=id; controllerDeps.SharedBossQueue=self.queue
    controllerDeps.Registry={new=function() return groupRegistry(self,id) end}
    local group={id=id,name='Команда '..index,world=world}
    group.controller=self.deps.Controller.new(controllerDeps,world)
    self.groups[id]=group; self.order[#self.order+1]=id
    return group
end

-- A queued boss may already own its matching active guardian. That existing
-- assignment is the only living-role exception when validating its own slot.
function MatchHub:_livingRole(userId,context)
    for _,id in ipairs(self.order) do
        local group=self.groups[id]; local c=group.controller
        if active(c) then
            local slot=c.ownerSlots[userId]
            local hero=slot and c.current.state.heroes[slot]
            if hero and hero.status~='Eliminated' then return group end
            local role=c.director:controlled(userId)
            if role and role.status=='Alive' then
                local matchingBoss=role.template=='Boss' and context and context.groupId==id
                    and context.runId==c.current.state.runId and context.levelEpoch==c.current.state.levelEpoch
                if not matchingBoss then return group end
            end
        end
    end
end

function MatchHub:_queueEligible(userId,context)
    local target=context and self.groups[context.groupId]
    if target and active(target.controller) and target.controller.ownerSlots[userId] then return false end
    return self:_livingRole(userId,context)==nil
end

function MatchHub:members(groupId,players)
    local members={}
    for _,player in ipairs(self.connections:online(players)) do
        if self.routes[player.UserId]==groupId then members[#members+1]=player end
    end
    return members
end

function MatchHub:selected(player)
    if not self.connections:isCurrent(player) then return nil end
    return self.groups[self.routes[player.UserId]]
end

function MatchHub:join(player)
    local joined,previous=self.connections:join(player)
    if not joined then return false end
    local id=self.routes[player.UserId] or self.order[1]
    self.routes[player.UserId]=id
    local group=self.groups[id]
    if previous then group.controller:leave(previous) end
    group.controller:join(player)
    return true
end

function MatchHub:leave(player)
    if not self.connections:remove(player) then return false end
    local group=self.groups[self.routes[player.UserId]]
    if group then group.controller:leave(player) end
    self.buckets[player]=nil; self.notices[player]=nil
    return true
end

function MatchHub:_switchReason(userId,targetId,now)
    if targetId and self.routes[userId]==targetId then return nil end
    if self:_livingRole(userId,nil) then return 'ROLE_ACTIVE' end
    local queue=self.queue:view(userId,now)
    if queue.state=='Accepted' or queue.state=='Ready' or queue.state=='Active' then return 'ROLE_RESERVED' end
end

function MatchHub:_move(player,target,now)
    local previous=self.groups[self.routes[player.UserId]]
    if previous==target then return end
    if previous then previous.controller:leave(player) end
    self.routes[player.UserId]=target.id
    local queue=self.queue:view(player.UserId,now)
    if queue.state~='None' then
        target.controller.preferences[player.UserId]='Spectator'
        target.controller.viewChoices[player.UserId]='Spectating'
    end
    target.controller:join(player)
end

function MatchHub:_rate(player,now)
    local rate=self.deps.Config.MaxIntentRate
    local bucket=self.buckets[player] or {tokens=rate,last=now}
    bucket.tokens=math.min(rate,bucket.tokens+math.max(0,now-bucket.last)*rate)
    bucket.last=math.max(bucket.last,now); self.buckets[player]=bucket
    if bucket.tokens<1 then return false end
    bucket.tokens-=1
    return true
end

function MatchHub:_offerGroup(userId,offerId,now)
    local view=self.queue:view(userId,now)
    if view.offerId~=offerId then return nil end
    for _,id in ipairs(self.order) do
        local group=self.groups[id]
        if group.controller.bossSlot==view.slotId then return group end
    end
end

function MatchHub:handle(player,payload,players)
    if not player.Parent or not self.connections:isCurrent(player) then return 'STALE_CONNECTION' end
    local function done(code)
        self.notices[player]=code~='OK' and code or nil
        return code
    end
    local now=self.deps.clock()
    if not self:_rate(player,now) then return done('RATE_LIMIT') end
    if type(payload)~='table' or type(payload.kind)~='string' then return done('INVALID_INTENT') end
    local selected=self:selected(player)
    if payload.groupId==nil then
        if payload.kind~='Sync' or self.envelopes[player] then return done('MISSING_GROUP') end
    elseif not identifier(payload.groupId) then return done('INVALID_INTENT')
    elseif payload.groupId~=selected.id then return done('WRONG_GROUP') end
    self.envelopes[player]=true

    if payload.kind=='CreateGroup' then
        if not exact(payload,{kind=true,groupId=true,requestId=true}) or not identifier(payload.requestId) then return done('INVALID_INTENT') end
        local requests=self.requests[player.UserId]
        if requests and requests[payload.requestId] then return done('OK') end
        local reason=self:_switchReason(player.UserId,nil,now)
        if reason then return done(reason) end
        if #self.order>=self.maxGroups then return done('GROUP_LIMIT') end
        local group=self:_create()
        if not requests then requests={}; self.requests[player.UserId]=requests end
        requests[payload.requestId]=group.id
        self:_move(player,group,now)
        return done('OK')
    elseif payload.kind=='JoinGroup' then
        if not exact(payload,{kind=true,groupId=true,targetGroupId=true}) or not identifier(payload.targetGroupId) then return done('INVALID_INTENT') end
        local target=self.groups[payload.targetGroupId]
        if not target then return done('UNKNOWN_GROUP') end
        local reason=self:_switchReason(player.UserId,target.id,now)
        if reason then return done(reason) end
        self:_move(player,target,now)
        return done('OK')
    elseif payload.kind=='ReplyBoss' or payload.kind=='ConnectBoss' then
        local reply=payload.kind=='ReplyBoss'
        if not exact(payload,reply and {kind=true,groupId=true,offerId=true,accepted=true}
            or {kind=true,groupId=true,offerId=true}) or not identifier(payload.offerId)
            or (reply and type(payload.accepted)~='boolean') then return done('INVALID_INTENT') end
        local target=self:_offerGroup(player.UserId,payload.offerId,now)
        if not target then return done('STALE_OFFER') end
        local result
        if reply then result=self.queue:reply(player.UserId,payload.offerId,payload.accepted,now)
        else result=self.queue:connect(player.UserId,payload.offerId,now) end
        if result=='OK' and (not reply or payload.accepted) then self:_move(player,target,now) end
        return done(result)
    end

    local c=selected.controller
    if payload.kind=='ClaimEnemy' or payload.kind=='QueueBoss' or (payload.kind=='SelectRole' and payload.role=='Hero') then
        local owned=self:_livingRole(player.UserId,nil)
        if owned and owned~=selected then return done('ROLE_ACTIVE') end
    elseif payload.kind=='Start' and c:_open() then
        for _,candidate in ipairs(c:_heroes(self:members(selected.id,players))) do
            if self:_livingRole(candidate.UserId,nil) then return done('ROLE_ACTIVE') end
            local queue=self.queue:view(candidate.UserId,now)
            if queue.state=='Accepted' or queue.state=='Ready' or queue.state=='Active' then return done('ROLE_RESERVED') end
        end
    end
    local inner={}
    for key,value in pairs(payload) do if key~='groupId' then inner[key]=value end end
    return done(c:handle(player,inner,self:members(selected.id,players)))
end

function MatchHub:snapshot(player,players)
    if not player.Parent then return nil end
    local selected=self:selected(player)
    if not selected then return nil end
    local data=selected.controller:snapshot(player,self:members(selected.id,players))
    if not data then return nil end
    local now=self.deps.clock()
    data.groupId=selected.id; data.groupName=selected.name
    data.worldName=selected.world.folder and selected.world.folder.Name or selected.world.name
    data.groups={}
    for _,id in ipairs(self.order) do
        local group=self.groups[id]; local c=group.controller
        local reason=self:_switchReason(player.UserId,id,now)
        data.groups[#data.groups+1]={id=id,name=group.name,
            status=c.director and c.director.result or (c.current and c.current.state.status or 'Lobby'),
            heroes=c.current and #c.current.order or 0,players=#self:members(id,players),canJoin=reason==nil,reason=reason}
    end
    data.canCreateGroup=#self.order<self.maxGroups and self:_switchReason(player.UserId,nil,now)==nil
    data.notice=self.notices[player]
    local queue=data.bossQueue
    if queue then
        queue.available=queue.available and self:_queueEligible(player.UserId,nil)
        if queue.offerId then
            local target=self:_offerGroup(player.UserId,queue.offerId,now)
            if target then queue.groupId=target.id; queue.groupName=target.name end
        end
    end
    self.snapshotSeq[player]=(self.snapshotSeq[player] or 0)+1
    data.snapshotSeq=self.snapshotSeq[player];data.serverNow=now
    return data
end

function MatchHub:controlledSlot(userId)
    local group=self.groups[self.routes[userId]]
    if not group then return nil end
    local slot=group.controller:controlledSlot(userId)
    if slot then return slot,group.world end
end

function MatchHub:step(now,dt)
    self.queue:step(now)
    for _,id in ipairs(self.order) do self.groups[id].controller:step(now,dt) end
end

return MatchHub
