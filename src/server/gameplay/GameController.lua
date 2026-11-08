-- One group's runtime. Player identity comes from the server, never from payload fields.
local Controller={}
Controller.__index=Controller
local templates={['Mr. Green']=true,['Mr. Yellow']=true,['Mr. Brown']=true}
local roles={Hero=true,Enemy=true,Spectator=true}
local function exact(payload,allowed)
    if type(payload)~='table' then return false end
    local count=0
    for key in pairs(payload) do count+=1; if count>4 or not allowed[key] then return false end end
    return true
end
function Controller.new(deps,world)
    local self=setmetatable({deps=deps,world=world,connections=deps.Registry.new(),choices={},preferences={},viewChoices={},owners={},ownerSlots={},buckets={},notices={}},Controller)
    if deps.SharedBossQueue then self.bossQueue=deps.SharedBossQueue
    elseif deps.BossQueue then
        self.bossQueue=deps.BossQueue.new(deps.Config.BossQueue,function(userId,context)
            return self:_bossEligible(userId,context)
        end)
    end
    return self
end
function Controller:_bossEligible(userId,context)
    if not self.current or self:_open() then return true end
    if self.ownerSlots[userId] then return false end
    local role=self.director:controlled(userId)
    return not role or role.status~='Alive' or role.template=='Boss'
end
function Controller:_bossSelection(player)
    if not self:_open() and self.ownerSlots[player.UserId] then return 'HERO_LOCKED' end
    local role=not self:_open() and self.director:controlled(player.UserId)
    if role and role.status=='Alive' then return 'ROLE_ACTIVE' end
    return 'OK'
end
function Controller:_heroes(players)
    local heroes={}
    for _,p in ipairs(self.connections:online(players)) do
        if (self.preferences[p.UserId] or 'Hero')=='Hero' then heroes[#heroes+1]=p end
    end
    return heroes
end
function Controller:_enemyName(player)
    self.director.ownerNames=self.director.ownerNames or {}
    self.director.ownerNames[player.UserId]=player.DisplayName..' @'..player.Name
    self.director.ownerConnections=self.director.ownerConnections or {}
    self.director.ownerConnections[player.UserId]=true
    local role=self.director:controlled(player.UserId)
    if role and role.status=='Alive' and self.world.enemyIdentity then
        self.world:enemyIdentity(role.enemyId,role.actorId,self.director.ownerNames[player.UserId])
    end
end
function Controller:join(player)
    if not self.connections:join(player) then return end
    if self.director then self:_enemyName(player) end
    local slot=self.ownerSlots[player.UserId]
    if self.current and slot and self.current.state.status=='Active' and not self.director.result then
        if self.current.state.heroes[slot].connected then self.current:connection(slot,false,self.deps.clock()) end
        self.current:connection(slot,true,self.deps.clock())
    end
    if self.director and not self:_open() then
        local role=self.director:controlled(player.UserId)
        if role then
            if role.connected then self.director:connection(player.UserId,false) end
            self.director:connection(player.UserId,true)
            self:_enemyName(player)
        end
    end
end
function Controller:leave(player)
    local changed=self.connections:remove(player)
    if changed and self.director then
        self.director.ownerConnections=self.director.ownerConnections or {}
        self.director.ownerConnections[player.UserId]=false
    end
    local slot=self.ownerSlots[player.UserId]
    if changed and self.current and slot and self.current.state.status=='Active' and not self.director.result then
        self.current:connection(slot,false,self.deps.clock())
    end
    if changed and self.director and not self:_open() then self.director:connection(player.UserId,false) end
    self.buckets[player]=nil; self.notices[player]=nil
end
function Controller:_open()
    return not self.current or self.current.state.status=='Lost' or self.director.result~=nil
end
function Controller:_begin(player,players)
    local online=self:_heroes(players)
    if #online==0 then return 'NO_HERO' end
    if online[1]~=player then return 'HOST_ONLY' end
    if not self:_open() then return 'RUN_ACTIVE' end
    local at=self.deps.clock()
    if self.bossQueue and self.bossSlot then self.bossQueue:close(self.bossSlot,at) end
    self.world:clearActors(); self.ownerSlots={}; self.owners={}; self.viewChoices={}
    local roster={}
    for index=1,math.min(3,#online) do
        local owner=online[index]
        local template=self.choices[owner.UserId] or 'Mr. Green'
        self.ownerSlots[owner.UserId]=index
        self.owners[index]={userId=owner.UserId,displayName=owner.DisplayName,username=owner.Name,template=template}
        self.world.names[index]=owner.DisplayName..' @'..owner.Name
        roster[index]={userId=index,template=template}
    end
    local runId=self.deps.guid()
    self.previousJournal=self.journal
    self.journal=self.deps.RunJournal and self.deps.RunJournal.new({runId=runId,groupId=self.deps.GroupId or 'combat-stand',
        build=self.deps.BuildId or 'unknown',rules='D01-D10-source-combat-v1'}) or nil
    self.current=self.deps.Session.new(self.deps.Core,self.deps.Combat,self.deps.Config,roster,runId,self.world,function(row)
        if self.journal then self.journal:record(row) end
        if row.kind=='Hit' then self.world:cue(row.userId,row.data.blocked) end
    end,self.deps.GroupId and {groupId=self.deps.GroupId,levelId='causeway'} or nil)
    local actorOwners={}
    for slot,owner in ipairs(self.owners) do actorOwners[slot]=owner.userId end
    self.current:_record('RunStarted',nil,{heroCount=#roster,owners=actorOwners})
    self.current:step(self.deps.clock())
    self.director=self.deps.Director.new(self.current,self.world,self.deps.Combat,self.deps.Config,self.deps.GuardianPattern,self.deps.HealingFlies,self.deps.EnemyCarry,self.deps.WalkerClubs)
    self.current.contextualAttack=function(slot,now,action)
        return self.director.interact and self.director:interact(slot,now,action) or 'NO_INTERACTION'
    end
    if self.deps.SourceCombat then self.deps.SourceCombat.bind(self.current,self.director,self.deps.Config) end
    for _,owner in ipairs(self.connections:online(players)) do self:_enemyName(owner) end
    if self.bossQueue then
        self.bossSlot=self.current.state.runId..':guardian:'..self.current.state.levelEpoch
        self.bossQueue:register(self.bossSlot,'CausewayGuardian',{
            runId=self.current.state.runId,groupId=self.current.state.groupId,levelEpoch=self.current.state.levelEpoch},at)
        self.director.bossGate=function(now) return self.bossQueue:start(self.bossSlot,now) end
    end
    local originalHit=self.current._hit
    local director=self.director
    self.current._hit=function(session,attacker,target,action,tuning)
        if type(target)=='number' and target<0 then return director:hit(attacker,target,action,tuning) end
        return originalHit(session,attacker,target,action,tuning)
    end
    self.finished=false
    return 'OK'
end
function Controller:controlledSlot(userId)
    local hero=self.ownerSlots[userId]
    if hero then return hero end
    local role=self.director and self.director:controlled(userId)
    if role and role.status=='Alive' then return role.enemyId end
end
function Controller:handle(player,payload,players)
    if not player.Parent or not self.connections:isCurrent(player) then return 'STALE_CONNECTION' end
    local at=self.deps.clock()
    local rate=self.deps.Config.MaxIntentRate
    local bucket=self.buckets[player] or {tokens=rate,last=at}
    bucket.tokens=math.min(rate,bucket.tokens+math.max(0,at-bucket.last)*rate); bucket.last=at; self.buckets[player]=bucket
    if bucket.tokens<1 then return 'RATE_LIMIT' end
    bucket.tokens-=1
    if type(payload)~='table' or type(payload.kind)~='string' then return 'INVALID_INTENT' end
    local code
    if payload.kind=='Sync' or payload.kind=='Start' then
        if not exact(payload,{kind=true}) then return 'INVALID_INTENT' end
        code=payload.kind=='Start' and self:_begin(player,players) or 'OK'
    elseif payload.kind=='SelectHero' then
        if not exact(payload,{kind=true,template=true}) or not templates[payload.template] then return 'INVALID_INTENT' end
        if not self:_open() then code='RUN_ACTIVE'
        else self.choices[player.UserId]=payload.template; code='OK' end
    elseif payload.kind=='SelectRole' then
        if not exact(payload,{kind=true,role=true}) or not roles[payload.role] then return 'INVALID_INTENT' end
        if not self:_open() then code='RUN_ACTIVE'
        else
            if self.bossQueue then self.bossQueue:cancel(player.UserId,at) end
            self.preferences[player.UserId]=payload.role; code='OK'
        end
    elseif payload.kind=='QueueBoss' then
        if not exact(payload,{kind=true,bossId=true}) or payload.bossId~='CausewayGuardian' then return 'INVALID_INTENT' end
        code=self:_bossSelection(player)
        if code=='OK' then
            code=self.bossQueue and self.bossQueue:select(player.UserId,payload.bossId,at) or 'UNAVAILABLE'
            if code=='OK' then
                self.preferences[player.UserId]='Spectator'; self.viewChoices[player.UserId]='Spectating'
                if self.director then self:_enemyName(player) end
            end
        end
    elseif payload.kind=='CancelBossQueue' then
        if not exact(payload,{kind=true}) then return 'INVALID_INTENT' end
        code=self.bossQueue and self.bossQueue:cancel(player.UserId,at) or 'UNAVAILABLE'
    elseif payload.kind=='ReplyBoss' or payload.kind=='ConnectBoss' then
        local reply=payload.kind=='ReplyBoss'
        if not exact(payload,reply and {kind=true,offerId=true,accepted=true} or {kind=true,offerId=true})
            or type(payload.offerId)~='string' or #payload.offerId==0 or #payload.offerId>160
            or (reply and type(payload.accepted)~='boolean') then return 'INVALID_INTENT' end
        code=self:_bossSelection(player)
        if code=='OK' then
            if not self.bossQueue then code='UNAVAILABLE'
            elseif reply then code=self.bossQueue:reply(player.UserId,payload.offerId,payload.accepted,at)
            else code=self.bossQueue:connect(player.UserId,payload.offerId,at) end
        end
    elseif payload.kind=='ChooseView' then
        if not exact(payload,{kind=true,runId=true,levelEpoch=true,view=true})
            or type(payload.runId)~='string' or #payload.runId==0 or #payload.runId>160
            or type(payload.levelEpoch)~='number' or payload.levelEpoch<1 or payload.levelEpoch>1000000000 or payload.levelEpoch%1~=0
            or (payload.view~='Menu' and payload.view~='Spectating') then return 'INVALID_INTENT' end
        if self:_open() then code='RUN_CLOSED'
        elseif payload.runId~=self.current.state.runId then code='WRONG_RUN'
        elseif payload.levelEpoch~=self.current.state.levelEpoch then code='STALE_LEVEL'
        else
            local slot=self.ownerSlots[player.UserId]
            local hero=slot and self.current.state.heroes[slot]
            local enemy=self.director:controlled(player.UserId)
            if hero and hero.status~='Eliminated' then code='NOT_ELIMINATED'
            elseif hero then
                code=self.current:_clock(at)
                if code=='OK' and hero.view~=payload.view then
                    code=self.current:_event('ChooseView',slot,{view=payload.view,connectionEpoch=hero.connectionEpoch})
                end
            elseif enemy and enemy.status=='Alive' then code='ROLE_ACTIVE'
            else self.viewChoices[player.UserId]=payload.view; code='OK' end
        end
    elseif payload.kind=='ClaimEnemy' then
        if not exact(payload,{kind=true,runId=true,levelEpoch=true,enemyId=true})
            or type(payload.enemyId)~='number' or payload.enemyId%1~=0 or payload.enemyId>=0 or payload.enemyId<=-1000 then return 'INVALID_INTENT' end
        if self:_open() then code='RUN_CLOSED'
        elseif payload.runId~=self.current.state.runId then code='WRONG_RUN'
        elseif payload.levelEpoch~=self.current.state.levelEpoch then code='STALE_LEVEL'
        elseif self.ownerSlots[player.UserId] then code='HERO_LOCKED'
        else
            local queue=self.bossQueue and self.bossQueue:view(player.UserId,at)
            if queue and (queue.state=='Accepted' or queue.state=='Ready' or queue.state=='Active') then code='ROLE_RESERVED'
            else
                self:_enemyName(player)
                self.director.now=at
                code=self.director:claim(player.UserId,payload.enemyId)
                if code=='OK' then
                    if self.bossQueue then self.bossQueue:cancel(player.UserId,at) end
                    self.viewChoices[player.UserId]=nil
                end
            end
        end
    elseif self.current then
        local slot=self.ownerSlots[player.UserId]
        if self:_open() then code='RUN_CLOSED'
        elseif slot then
            code=self.current:intent(slot,payload,at)
            local accepted=self.current.combat[slot].attack
            local actor=self.current.state.heroes[slot].actorId
            if code=='OK' and payload.kind=='Attack' and accepted
                and accepted.actorId==actor and (accepted.inputAction or accepted.action)==payload.attack then
                self.director.now=at
                self.director:closeTargetForAttack(self.world:targets(slot,accepted.tuning or self.deps.Config.Attacks[accepted.action]))
            end
        elseif self.director:controlled(player.UserId) then
            code=self.director:command(player.UserId,payload,at,self.deps.Session.validIntent)
        else code='SPECTATOR' end
    else code='NO_RUN' end
    if code=='OK' then self.notices[player]=nil else self.notices[player]=code end
    return code
end
function Controller:step(now,dt)
    if self.bossQueue then self.bossQueue:step(now) end
    if not self.current or self.finished then return end
    self.director.now=now
    self.current:step(now); self.director:step(now,dt)
    if self.bossQueue and self.bossSlot and (self.director.stage=='Exit' or self.director.result) then
        self.bossQueue:close(self.bossSlot,now)
    end
    if self.director.result then
        self.finished=true
        self.current:_record('RunResult',nil,{result=self.director.result})
        for _,id in ipairs(self.current.order) do
            self.world:move(id,0,0)
            if self.world.hold then self.world:hold(id,true) end
        end
        for id in pairs(self.director.enemies or {}) do self.world:move(id,0,0) end
    end
end
function Controller:snapshot(player,players)
    if not self.connections:isCurrent(player) then return nil end
    local online=self.connections:online(players)
    local data=self.current and self.current:snapshot() or {status='Lobby',heroes={},now=self.deps.clock()}
    data.status=self.director and self.director.result or data.status
    data.level=self.director and self.director:snapshot() or {stage='Lobby',objective='Выберите героя и отправляйтесь в путь'}
    for _,hero in ipairs(data.heroes) do
        local owner=self.owners[hero.slot]
        for key,value in pairs(owner) do hero[key]=value end
    end
    data.lobby={}
    for _,owner in ipairs(online) do
        data.lobby[#data.lobby+1]={userId=owner.UserId,displayName=owner.DisplayName,username=owner.Name,
            template=self.choices[owner.UserId] or 'Mr. Green',preference=self.preferences[owner.UserId] or 'Hero'}
    end
    data.mine=self.ownerSlots[player.UserId]
    local heroes=self:_heroes(players)
    data.online=#online; data.heroOnline=#heroes; data.host=heroes[1] and heroes[1].UserId
    data.canStart=heroes[1]==player and self:_open()
    data.canSelect=self:_open()
    data.selectedTemplate=self.choices[player.UserId] or 'Mr. Green'
    data.preference=self.preferences[player.UserId] or 'Hero'
    data.enemyRole=self.director and self.director:controlled(player.UserId)
    data.cameraBounds=self.world.cameraBounds and self.world:cameraBounds() or nil
    if self:_open() then data.view='Menu'; data.canChooseView=false
    elseif data.mine then
        local hero=self.current.state.heroes[data.mine]
        data.view=hero.status=='Eliminated' and hero.view or 'Playing'
        data.canChooseView=hero.status=='Eliminated'
    elseif data.enemyRole and data.enemyRole.status=='Alive' then data.view='Playing'; data.canChooseView=false
    else
        data.view=self.viewChoices[player.UserId] or (data.enemyRole and 'Choice' or 'Spectating')
        data.canChooseView=true
    end
    data.enemyOffers={}
    if not self.current or self:_open() then data.enemyUnavailableReason='RUN_CLOSED'
    elseif data.mine then data.enemyUnavailableReason='HERO_LOCKED'
    elseif data.enemyRole then
        data.enemyUnavailableReason=data.enemyRole.status=='Alive' and 'ENEMY_ALREADY_OWNED' or 'ENEMY_LIFE_SPENT'
    else
        data.enemyOffers=self.director:available(player.UserId)
        if #data.enemyOffers==0 then data.enemyUnavailableReason='NO_ENEMY_AVAILABLE' end
    end
    data.notice=self.notices[player]
    data.interaction=data.mine and self.director and self.director.interaction and self.director:interaction(data.mine) or {available=false}
    data.weapon=data.mine and self.director and self.director.clubs and self.director.clubs:hasClub(data.mine) and 'WalkerClub' or nil
    data.feedback=self.journal and self.journal:feedback() or nil
    if self.bossQueue then
        data.bossQueue=self.bossQueue:view(player.UserId,self.deps.clock())
        data.bossQueue.available=self:_bossSelection(player)=='OK'
    end
    return data
end
return Controller
