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
    return not controller.faulted and controller.current~=nil and not controller:_open()
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
        entryLanes={},entrySerial=0,readyPlayers=setmetatable({},{__mode='k'}),
        buckets=setmetatable({},{__mode='k'}),notices=setmetatable({},{__mode='k'}),
        envelopes=setmetatable({},{__mode='k'}),snapshotSeq=setmetatable({},{__mode='k'}),
        actionSerial=setmetatable({},{__mode='k'}),queueDepth=0,pendingQuarantines={}},MatchHub)
    self.queue=deps.BossQueue.new(deps.Config.BossQueue,function(userId,context)
        return self:_queueEligible(userId,context)
    end)
    -- Eligibility can quarantine a faulty group, but it must not close that
    -- group's slot while BossQueue is iterating its entries or filling a slot.
    for _,name in ipairs({'register','select','cancel','reply','connect','step','start','close','view'}) do
        local method=self.queue[name]
        self.queue[name]=function(queue,...)
            self.queueDepth+=1
            local results=table.pack(pcall(method,queue,...))
            self.queueDepth-=1
            if self.queueDepth==0 then self:_flushQuarantines() end
            if not results[1] then error(results[2],0) end
            return table.unpack(results,2,results.n)
        end
    end
    self:_create()
    return self
end

-- Server-only control. No remote intent routes to this method.
function MatchHub:setInfiniteLives(enabled)
    if type(enabled)~='boolean' then return 'INVALID_OPTION' end
    local development=self.deps.Config.Development
    if not development or development.allowInfiniteLives~=true then return 'DEVELOPMENT_ONLY' end
    development.infiniteLives=enabled
    for _,group in pairs(self.groups) do
        self:_guard(group,function()
            local c=group.controller
            c.deps.Config.Development.infiniteLives=enabled
            if active(c) then assert(c.current:setInfiniteLives(enabled)=='OK') end
        end)
    end
    return 'OK'
end

function MatchHub:_flushQuarantines()
    if self.flushingQuarantines then return end
    self.flushingQuarantines=true
    while next(self.pendingQuarantines) do
        local pending=self.pendingQuarantines
        self.pendingQuarantines={}
        for group in pairs(pending) do
            if group.controller.quarantine then pcall(function() group.controller:quarantine() end) end
        end
    end
    self.flushingQuarantines=false
end

function MatchHub:_guard(group,callback)
    local ok,result=xpcall(callback,debug.traceback)
    if ok then return result,true end
    group.controller.faulted=true
    self.pendingQuarantines[group]=true
    if self.queueDepth==0 then self:_flushQuarantines() end
    local notify=self.deps.warn or warn
    if notify then pcall(notify,'[BrickToads '..group.id..'] '..tostring(result)) end
    return 'PARTY_FAULTED',false
end

function MatchHub:_create(entryOwner)
    local index=#self.order+1; local id='group-'..index
    if entryOwner then
        index=self.maxGroups+1
        while self.entryLanes[index] do index+=1 end
        self.entrySerial+=1; id='speeder-'..self.entrySerial
        self.entryLanes[index]=true
    end
    local world=self.worldFactory(index,id)
    local controllerDeps=table.clone(self.deps)
    controllerDeps.GroupId=id
    if entryOwner then
        -- No human boss can transfer into someone else's private ride.
        controllerDeps.BossQueue=nil; controllerDeps.SharedBossQueue=nil
    else controllerDeps.SharedBossQueue=self.queue end
    controllerDeps.Registry={new=function() return groupRegistry(self,id) end}
    controllerDeps.nextActionFeedbackId=function(player)
        self.actionSerial[player]=(self.actionSerial[player] or 0)+1
        return self.actionSerial[player]
    end
    local group={id=id,name=entryOwner and "Copper Rush" or ("Team "..index),world=world,
        entryOwner=entryOwner,entryPending=entryOwner~=nil,worldIndex=index}
    group.controller=self.deps.Controller.new(controllerDeps,world)
    self.groups[id]=group
    if entryOwner then self.entryLanes[index]=group else self.order[#self.order+1]=id end
    return group
end

-- Each private world lasts for its owner's visit. Group IDs stay unique even
-- when another rider reuses the same physical lane.
function MatchHub:_releaseEntry(group)
    if not group or not group.entryOwner or self.groups[group.id]~=group then return end
    if self.routes[group.entryOwner]==group.id then self.routes[group.entryOwner]=nil end
    self.groups[group.id]=nil
    self:_guard(group,function()
        group.controller:_closeDirector('EntryClosed')
        group.world:clearActors()
        if group.world.campaignWorld then group.world.campaignWorld:close() end
    end)
    group.world.folder:Destroy()
    self.entryLanes[group.worldIndex]=nil
end

function MatchHub:_startEntry(player,group)
    if not group or not group.entryPending or group.startingEntry or group.entryOwner~=player.UserId
        or not self.readyPlayers[player] or not group.controller.connections:isCurrent(player) then
        return 'OK'
    end
    local now=self.deps.clock()
    if group.entryRetryAt and now<group.entryRetryAt then return 'ENTRY_PENDING' end
    group.startingEntry=true
    local code,ok=self:_guard(group,function()
        local result=group.controller:startSpeederEntry(player,{player})
        assert(result~='UNAVAILABLE','Speeder entry has no campaign configuration')
        return result
    end)
    group.startingEntry=nil
    if code=='OK' or not ok then
        group.entryPending=false
        group.entryStartFault=not ok
    else
        group.entryRetryAt=now+1
    end
    self.notices[player]=code~='OK' and code or nil
    return code
end

-- A queued boss may already own its matching active guardian. That existing
-- assignment is the only living-role exception when validating its own slot.
function MatchHub:_livingRole(userId,context)
    local function hasRole(group)
        local c=group.controller
        local living,ok=self:_guard(group,function()
            if active(c) then
                local slot=c.ownerSlots[userId]
                local hero=slot and c.current.state.heroes[slot]
                if hero and hero.status~='Eliminated' then return true end
                local role=c.director:controlled(userId)
                if role and role.status=='Alive' then
                    local matchingBoss=role.template=='Boss' and context and context.groupId==group.id
                        and context.runId==c.current.state.runId and context.levelEpoch==c.current.state.levelEpoch
                    if not matchingBoss then return true end
                end
            end
            return false
        end)
        return ok and living
    end
    local own=self.groups[self.routes[userId]]
    if own and own.entryOwner==userId and hasRole(own) then return own end
    for _,id in ipairs(self.order) do
        if hasRole(self.groups[id]) then return self.groups[id] end
    end
end

function MatchHub:_queueEligible(userId,context)
    local target=context and self.groups[context.groupId]
    if target and target.entryOwner then return false end
    if target then
        local ownsHero,ok=self:_guard(target,function()
            return active(target.controller) and target.controller.ownerSlots[userId]~=nil
        end)
        if not ok or ownsHero then return false end
    end
    local living=self:_livingRole(userId,context)
    -- The role scan itself can discover a broken target. Do not grant an
    -- invitation/acceptance just because its now-faulted roles were skipped.
    if target and target.controller.faulted then return false end
    return living==nil
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

function MatchHub:join(player,entryRoute)
    local joined,previous=self.connections:join(player)
    if not joined then return false end
    local userId=player.UserId
    local group=self.groups[self.routes[userId]]
    local createdEntry
    if previous and group then self:_guard(group,function() group.controller:leave(previous) end) end
    if entryRoute=='speeder' and not (group and group.entryPending) then
        -- Preserve heroes and human boss reservations on reconnect. An idle
        -- lobby or a spectator preference does not override a new ad entry.
        local living=self:_livingRole(userId,nil)
        local queue=self.queue:view(userId,self.deps.clock())
        if living then group=living
        elseif queue.state~='Accepted' and queue.state~='Ready' and queue.state~='Active' then
            if queue.state~='None' then self.queue:cancel(userId,self.deps.clock()) end
            self:_releaseEntry(group)
            group=self:_create(userId)
            createdEntry=group
        end
    end
    if not self.connections:isCurrent(player) then
        self:_releaseEntry(createdEntry)
        return false
    end
    group=group or self.groups[self.order[1]]
    self.routes[userId]=group.id
    self:_guard(group,function() group.controller:join(player) end)
    self:_startEntry(player,group)
    return true
end

function MatchHub:leave(player)
    if not self.connections:remove(player) then return false end
    local group=self.groups[self.routes[player.UserId]]
    if group then self:_guard(group,function() group.controller:leave(player) end) end
    self:_releaseEntry(group)
    self.readyPlayers[player]=nil
    if self.deps.Transfer then self.deps.Transfer:remove(player) end
    self.actionSerial[player]=nil;self.snapshotSeq[player]=nil;self.envelopes[player]=nil
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
    if previous then self:_guard(previous,function() previous.controller:leave(player) end) end
    self:_releaseEntry(previous)
    self.routes[player.UserId]=target.id
    local queue=self.queue:view(player.UserId,now)
    if queue.state~='None' then
        target.controller.preferences[player.UserId]='Spectator'
        target.controller.viewChoices[player.UserId]='Spectating'
    end
    self:_guard(target,function() target.controller:join(player) end)
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
    if player.Parent and type(payload)=='table' and payload.kind=='EntryReady' then
        if not exact(payload,{kind=true}) then return 'INVALID_INTENT' end
        -- PlayerAdded may still be routing this exact instance, so retain a
        -- readiness signal that arrives before the initial snapshot.
        self.readyPlayers[player]=true
        return self:_startEntry(player,self:selected(player))
    end
    if not player.Parent or not self.connections:isCurrent(player) then return 'STALE_CONNECTION' end
    local function done(code)
        self.notices[player]=code~='OK' and code or nil
        return code
    end
    local now=self.deps.clock()
    if not self:_rate(player,now) then return done('RATE_LIMIT') end
    if type(payload)~='table' or type(payload.kind)~='string' then return done('INVALID_INTENT') end
    local selected=self:selected(player)
    if not selected then return done('MISSING_GROUP') end
    if payload.groupId==nil then
        if payload.kind~='Sync' or self.envelopes[player] then return done('MISSING_GROUP') end
    elseif not identifier(payload.groupId) then return done('INVALID_INTENT')
    elseif payload.groupId~=selected.id then return done('WRONG_GROUP') end
    self.envelopes[player]=true
    if selected.entryPending and payload.kind~='Sync' then return done('ENTRY_PENDING') end

    if payload.kind=='RideReady' then
        if not exact(payload,{kind=true,groupId=true,runId=true}) or not identifier(payload.runId)
            or selected.entryOwner~=player.UserId then return done('INVALID_INTENT') end
        local c=selected.controller
        if c.faulted then return done('PARTY_FAULTED') end
        if not c.current or c.current.state.runId~=payload.runId then return done('STALE_RUN') end
        return done(self:_guard(selected,function() return c:releaseSpeederEntry(player,payload.runId) end))
    elseif payload.kind=='Start' and selected.entryStartFault then
        if not exact(payload,{kind=true,groupId=true}) then return done('INVALID_INTENT') end
        local fresh=self:_create(player.UserId)
        if not self.connections:isCurrent(player) or self:selected(player)~=selected then
            self:_releaseEntry(fresh)
            return 'STALE_CONNECTION'
        end
        self:_move(player,fresh,now)
        return done(self:_startEntry(player,fresh))
    elseif payload.kind=='CreateGroup' then
        if not exact(payload,{kind=true,groupId=true,requestId=true}) or not identifier(payload.requestId) then return done('INVALID_INTENT') end
        local requests=self.requests[player.UserId]
        if requests and requests[payload.requestId] then return done('OK') end
        local reason=self:_switchReason(player.UserId,nil,now)
        if reason then return done(reason) end
        if #self.order>=self.maxGroups then
            return done(self.deps.Transfer and self.deps.Transfer:request(player,payload.requestId) or 'GROUP_LIMIT')
        end
        local group=self:_create()
        if not requests then requests={}; self.requests[player.UserId]=requests end
        requests[payload.requestId]=group.id
        self:_move(player,group,now)
        return done('OK')
    elseif payload.kind=='JoinGroup' then
        if not exact(payload,{kind=true,groupId=true,targetGroupId=true}) or not identifier(payload.targetGroupId) then return done('INVALID_INTENT') end
        local target=self.groups[payload.targetGroupId]
        if not target or (target.entryOwner and target.entryOwner~=player.UserId) then return done('UNKNOWN_GROUP') end
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
    elseif payload.kind=='Start' then
        local open,readOk=self:_guard(selected,function() return c:_open() end)
        if not readOk then return done('PARTY_FAULTED') end
        if open then
            local heroes,heroesOk=self:_guard(selected,function() return c:_heroes(self:members(selected.id,players)) end)
            if not heroesOk then return done('PARTY_FAULTED') end
            for _,candidate in ipairs(heroes) do
                if self:_livingRole(candidate.UserId,nil) then return done('ROLE_ACTIVE') end
                local queue=self.queue:view(candidate.UserId,now)
                if queue.state=='Accepted' or queue.state=='Ready' or queue.state=='Active' then return done('ROLE_RESERVED') end
            end
        end
    end
    local inner={}
    for key,value in pairs(payload) do if key~='groupId' then inner[key]=value end end
    return done(self:_guard(selected,function() return c:handle(player,inner,self:members(selected.id,players)) end))
end

function MatchHub:snapshot(player,players)
    if not player.Parent then return nil end
    local selected=self:selected(player)
    if not selected then return nil end
    local members=self:members(selected.id,players)
    local data,ok=self:_guard(selected,function() return selected.controller:snapshot(player,members) end)
    if not ok then data=self.deps.Controller.snapshot(selected.controller,player,members) end
    if not data then return nil end
    local now=self.deps.clock()
    data.groupId=selected.id; data.groupName=selected.name
    if selected.entryPending then data.entryPending=true end
    data.worldName=selected.world.folder and selected.world.folder.Name or selected.world.name
    data.groups={}
    for _,id in ipairs(self.order) do
        local group=self.groups[id]; local c=group.controller
        local reason=self:_switchReason(player.UserId,id,now)
        local summary,readOk=self:_guard(group,function()
            if c.faulted then return {status='Faulted',heroes=0} end
            return {status=c.director and c.director.result or (c.current and c.current.state.status or 'Lobby'),
                heroes=c.current and #c.current.order or 0}
        end)
        if not readOk then summary={status='Faulted',heroes=0} end
        data.groups[#data.groups+1]={id=id,name=group.name,
            status=summary.status,heroes=summary.heroes,players=#self:members(id,players),canJoin=reason==nil,reason=reason}
    end
    data.canCreateGroup=(#self.order<self.maxGroups or self.deps.Transfer~=nil) and self:_switchReason(player.UserId,nil,now)==nil
    if self.deps.Transfer then data.serverTransfer=self.deps.Transfer:snapshot(player) end
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
    if not group or group.controller.faulted then return nil end
    local slot,ok=self:_guard(group,function() return group.controller:controlledSlot(userId) end)
    if ok and slot then return slot,group.world end
end

function MatchHub:step(now,dt)
    self.queue:step(now)
    local function tick(group)
        local controller=group.controller
        if not controller.faulted then
            self:_guard(group,function()
                controller:step(now,dt)
                if controller.current and group.world.updatePresentation then
                    group.world:updatePresentation(controller.current,dt,controller.director.enemies,controller.director)
                end
            end)
        end
    end
    for _,id in ipairs(self.order) do tick(self.groups[id]) end
    for _,group in pairs(self.entryLanes) do
        if group~=true then tick(group) end
    end
end

return MatchHub
