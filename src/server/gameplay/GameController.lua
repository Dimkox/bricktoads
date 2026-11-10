-- One group's runtime. Player identity comes from the server, never from payload fields.
local Controller={}
Controller.__index=Controller
local templates={['Mr. Green']=true,['Mr. Yellow']=true,['Mr. Brown']=true}
local roles={Hero=true,Enemy=true,Spectator=true}
local bossTypes={CausewayGuardian=true,BigBlag=true,RoboManus=true,GeneralSlaughter=true,Buzzball=true,DarkQueen=true}
local levelHooks={'contextualIntent','beforeHitImpulse','groundRunAllowed','canRunStrike','attackSelector','contextualAttack'}
local function campaignSeed(runId)
    local seed=1
    for index=1,#runId do seed=(seed*131+string.byte(runId,index))%2147483646 end
    return seed+1
end
local actionDenials={NOT_RUNNING=true,REACTION=true,COOLDOWN=true,HELD=true,THROWN=true}
local function variationMetadata(route)
    local value=route and route.variation
    return value and {version=value.version,seed=value.seed,sectionChoices=table.clone(value.sectionChoices)} or nil
end
local function exact(payload,allowed)
    if type(payload)~='table' then return false end
    local count=0
    for key in pairs(payload) do count+=1; if count>4 or not allowed[key] then return false end end
    return true
end
function Controller.new(deps,world)
    deps=table.clone(deps)
    deps.Config=table.clone(deps.Config)
    if deps.Config.Development then deps.Config.Development=table.clone(deps.Config.Development) end
    local self=setmetatable({deps=deps,world=world,connections=deps.Registry.new(),players={},choices={},preferences={},viewChoices={},owners={},ownerSlots={},buckets={},notices={},
        baseLevel=deps.Config.Level,actionFeedback=setmetatable({},{__mode='k'}),actionSerial=setmetatable({},{__mode='k'})},Controller)
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
    local joined,previous=self.connections:join(player)
    if not joined then return end
    self.players[player.UserId]=player
    if previous then self.actionFeedback[previous]=nil;self.actionSerial[previous]=nil end
    self.actionFeedback[player]=nil
    if self.faulted then return end
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
    if changed then self.players[player.UserId]=nil end
    if self.faulted then
        self.buckets[player]=nil;self.notices[player]=nil;self.actionFeedback[player]=nil;self.actionSerial[player]=nil
        return
    end
    if changed and self.director then
        self.director.ownerConnections=self.director.ownerConnections or {}
        self.director.ownerConnections[player.UserId]=false
    end
    local slot=self.ownerSlots[player.UserId]
    if changed and self.current and slot and self.current.state.status=='Active' and not self.director.result then
        self.current:connection(slot,false,self.deps.clock())
    end
    if changed and self.director and not self:_open() then self.director:connection(player.UserId,false) end
    self.buckets[player]=nil; self.notices[player]=nil;self.actionFeedback[player]=nil;self.actionSerial[player]=nil
end
function Controller:_open()
    if self.faulted or not self.current or self.current.state.status=='Lost' then return true end
    if not self.director or not self.director.result then return false end
    return self.director.result~='Won' or not self.campaignIndex
        or self.campaignIndex>=self.deps.CampaignDefinition.count or self.finished==true
end

function Controller:_closeDirector(reason)
    local director=self.director
    if not director then return end
    if director.close then director:close(reason)
    else
        if director.cancelBossIntro then director:cancelBossIntro(reason) end
        for _,name in ipairs({'flies','carry','clubs','dragons'}) do
            local component=director[name]
            if component and component.close then component:close(reason) end
        end
    end
end

function Controller:_createDirector(at)
    local deps=self.deps
    for _,key in ipairs(levelHooks) do self.current[key]=self.baseSessionHooks[key] end
    if self.campaignIndex and self.campaignIndex>1 then
        self.director=deps.CampaignDirector.new(self.current,self.world,deps.Combat,deps.Config,deps)
    else
        self.director=deps.Director.new(self.current,self.world,deps.Combat,deps.Config,deps.GuardianPattern,
            deps.HealingFlies,deps.EnemyCarry,deps.WalkerClubs,deps.DragonFlight,deps.BossIntro)
    end
    self.current.contextualAttack=function(slot,now,action)
        return self.director.interact and self.director:interact(slot,now,action) or 'NO_INTERACTION'
    end
    if deps.SourceCombat then deps.SourceCombat.bind(self.current,self.director,deps.Config) end
    for _,owner in pairs(self.players) do self:_enemyName(owner) end
    self.bossSlot=nil
    local definition=deps.Config.Level
    local bossId=self.campaignIndex and self.campaignIndex>1
        and definition.boss and (definition.boss.kind or definition.boss.type)
        or ((not self.campaignIndex or self.campaignIndex==1) and 'CausewayGuardian' or nil)
    if self.bossQueue and bossId then
        self.bossSlot=self.current.state.runId..':'..bossId..':'..self.current.state.levelEpoch
        assert(self.bossQueue:register(self.bossSlot,bossId,{runId=self.current.state.runId,
            groupId=self.current.state.groupId,levelEpoch=self.current.state.levelEpoch},at)=='OK')
        self.director.bossGate=function(now) return self.bossQueue:start(self.bossSlot,now) end
    end
end

function Controller:_advanceCampaign(now)
    local nextIndex=self.campaignIndex+1
    local definition=self.deps.CampaignDefinition.build(nextIndex,self.campaignSeed)
    if self.bossQueue and self.bossSlot then self.bossQueue:close(self.bossSlot,now) end
    self:_closeDirector('LevelAdvanced')
    local rebuilt,reason=self.world:advanceGeometry(definition)
    assert(rebuilt==true,'Cannot build the next campaign stage: '..tostring(reason))
    local code=self.current:advanceLevel(definition.id,now,{prerequisitesMet=true})
    assert(code=='OK','Cannot advance the campaign: '..tostring(code))
    self.deps.Config.Level=definition
    self.deps.Config.Calibration=definition.calibration or self.deps.Config.Calibration
    self.campaignIndex=nextIndex
    self.actionFeedback=setmetatable({},{__mode='k'})
    self.notices={}
    self:_createDirector(now)
    self.current:_record('CampaignStageStarted',nil,{index=nextIndex,levelId=definition.id,mode=definition.mode})
end

function Controller:quarantine()
    self.faulted=true
    if self.director and self.director.cancelBossIntro then pcall(function() self.director:cancelBossIntro('Quarantine') end) end
    self.actionFeedback=setmetatable({},{__mode='k'})
    if self.bossQueue and self.bossSlot then pcall(function() self.bossQueue:close(self.bossSlot,self.deps.clock()) end) end
    for id in pairs(self.world.actors or {}) do
        pcall(function() self.world:move(id,0,0) end)
        if self.world.hold then pcall(function() self.world:hold(id,true) end) end
    end
end

function Controller:_actionContext(player)
    if not self.current or self:_open() then return nil end
    local slot=self.ownerSlots[player.UserId]
    local role=slot and self.current.state.heroes[slot] or self.director:controlled(player.UserId)
    if not role or role.status~='Alive' or not role.connected then return nil end
    if slot and self.current.combat[slot].deathAt then return nil end
    return role
end

function Controller:_actionOutcome(player,payload,code,now)
    if (payload.kind~='Attack' and payload.kind~='Jump') or not self.deps.Session.validIntent(payload) then return end
    local role=self:_actionContext(player)
    if not role then return end
    if code=='OK' then self.actionFeedback[player]=nil;return end
    if not actionDenials[code] then return end
    local id
    if self.deps.nextActionFeedbackId then id=self.deps.nextActionFeedbackId(player)
    else id=(self.actionSerial[player] or 0)+1;self.actionSerial[player]=id end
    local state=self.current.state
    self.actionFeedback[player]={id=id,code=code,kind=payload.kind,groupId=state.groupId,runId=state.runId,
        actorId=role.actorId,connectionEpoch=role.connectionEpoch,expiresAt=now+1.4}
end

function Controller:_feedbackSnapshot(player,view)
    local row=self.actionFeedback[player]
    if not row then return nil end
    local role=self:_actionContext(player)
    if not role or view~='Playing' or self.deps.clock()>=row.expiresAt
        or row.runId~=self.current.state.runId or row.actorId~=role.actorId
        or row.connectionEpoch~=role.connectionEpoch then self.actionFeedback[player]=nil;return nil end
    return {id=row.id,code=row.code,kind=row.kind,groupId=row.groupId,runId=row.runId,
        actorId=row.actorId,expiresAt=row.expiresAt}
end
function Controller:_begin(player,players)
    local online=self:_heroes(players)
    if #online==0 then return 'NO_HERO' end
    if online[1]~=player then return 'HOST_ONLY' end
    if not self:_open() then return 'RUN_ACTIVE' end
    local at=self.deps.clock()
    local runId=self.deps.guid()
    local route
    if self.deps.LevelVariation and self.baseLevel then
        route=self.deps.LevelVariation.build(self.baseLevel,self.deps.LevelVariation.seedFromId(runId))
    end
    if self.bossQueue and self.bossSlot then self.bossQueue:close(self.bossSlot,at) end
    self:_closeDirector('RunReplaced')
    self.world:clearActors(); self.ownerSlots={}; self.owners={}; self.viewChoices={}
    if route then
        local rebuilt,reason=self.world:rebuildLevel(route)
        assert(rebuilt==true,'Cannot rebuild the new run level: '..tostring(reason))
        self.deps.Config.Level=route
        self.deps.Config.Calibration=route.calibration or self.deps.Config.Calibration
    end
    self.actionFeedback=setmetatable({},{__mode='k'})
    local roster={}
    for index=1,math.min(3,#online) do
        local owner=online[index]
        local template=self.choices[owner.UserId] or 'Mr. Green'
        self.ownerSlots[owner.UserId]=index
        self.owners[index]={userId=owner.UserId,displayName=owner.DisplayName,username=owner.Name,template=template}
        self.world.names[index]=owner.DisplayName..' @'..owner.Name
        roster[index]={userId=index,template=template}
    end
    self.previousJournal=self.journal
    self.journal=self.deps.RunJournal and self.deps.RunJournal.new({runId=runId,groupId=self.deps.GroupId or 'combat-stand',
        build=self.deps.BuildId or 'unknown',rules='D01-D10-source-combat-v1'}) or nil
    self.current=self.deps.Session.new(self.deps.Core,self.deps.Combat,self.deps.Config,roster,runId,self.world,function(row)
        if self.journal then self.journal:record(row) end
        if row.kind=='Hit' then self.world:cue(row.userId,row.data.blocked) end
    end,self.deps.GroupId and {groupId=self.deps.GroupId,levelId='causeway'} or nil)
    local actorOwners={}
    for slot,owner in ipairs(self.owners) do actorOwners[slot]=owner.userId end
    self.current:_record('RunStarted',nil,{heroCount=#roster,owners=actorOwners,variation=variationMetadata(self.deps.Config.Level)})
    local development=self.deps.Config.Development
    if development and development.allowInfiniteLives==true and development.infiniteLives==true then
        assert(self.current:setInfiniteLives(true)=='OK','Cannot enable trusted Studio infinite lives')
    end
    self.current:step(self.deps.clock())
    self.campaignIndex=self.deps.CampaignDefinition and self.deps.CampaignDirector and 1 or nil
    self.campaignSeed=self.deps.LevelVariation and self.deps.LevelVariation.seedFromId(runId) or campaignSeed(runId)
    self.baseSessionHooks={}
    for _,key in ipairs(levelHooks) do self.baseSessionHooks[key]=self.current[key] end
    local originalHit=self.current._hit
    self.current._hit=function(session,attacker,target,action,tuning)
        if type(target)=='number' and target<0 then return self.director:hit(attacker,target,action,tuning) end
        return originalHit(session,attacker,target,action,tuning)
    end
    self:_createDirector(at)
    self.finished=false
    self.faulted=false
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
    if self.faulted and payload.kind~='Start' and payload.kind~='Sync' then return 'PARTY_FAULTED' end
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
        if not exact(payload,{kind=true,bossId=true}) or not bossTypes[payload.bossId] then return 'INVALID_INTENT' end
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
    self:_actionOutcome(player,payload,code,at)
    if code=='OK' then self.notices[player]=nil else self.notices[player]=code end
    return code
end
function Controller:step(now,dt)
    if self.faulted then return end
    if self.bossQueue then self.bossQueue:step(now) end
    if not self.current or self.finished then return end
    self.director.now=now
    self.current:step(now); self.director:step(now,dt)
    if self.director.result=='Won' and self.campaignIndex and self.campaignIndex<self.deps.CampaignDefinition.count then
        self.current:_record('CampaignStageCompleted',nil,{index=self.campaignIndex})
        self:_advanceCampaign(now)
        return
    end
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
    if self.faulted then
        local heroes=self:_heroes(players)
        local state=self.current and self.current.state or {}
        return {status='Faulted',fault=true,now=self.deps.clock(),
            runId=state.runId or ((self.deps.GroupId or 'combat-stand')..':faulted'),levelEpoch=state.levelEpoch or 1,
            heroes={},lobby={},level={stage='Faulted',objective="Party stopped. Start a new game."},
            online=#online,heroOnline=#heroes,host=heroes[1] and heroes[1].UserId,
            canStart=heroes[1]==player,canSelect=false,canChooseView=false,view='Menu',
            selectedTemplate=self.choices[player.UserId] or 'Mr. Green',preference=self.preferences[player.UserId] or 'Hero',
            enemyOffers={},enemyUnavailableReason='PARTY_FAULTED',interaction={available=false}}
    end
    local data=self.current and self.current:snapshot() or {status='Lobby',heroes={},now=self.deps.clock()}
    data.status=self.director and self.director.result or data.status
    data.level=self.director and self.director:snapshot() or {stage='Lobby',objective="Choose a hero and set out"}
    if self.campaignIndex then
        data.campaign={index=self.campaignIndex,count=self.deps.CampaignDefinition.count,
            complete=self.finished==true and self.director.result=='Won'}
        data.level.campaignIndex=self.campaignIndex;data.level.campaignCount=self.deps.CampaignDefinition.count
    end
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
    data.actionFeedback=self:_feedbackSnapshot(player,data.view)
    if self.bossQueue then
        data.bossQueue=self.bossQueue:view(player.UserId,self.deps.clock())
        data.bossQueue.available=self:_bossSelection(player)=='OK'
    end
    return data
end
return Controller
