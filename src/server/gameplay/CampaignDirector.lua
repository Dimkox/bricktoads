-- A campaign stage has independent traversal, ordinary-combat and boss gates.
-- The ordinary first-route director supplies family combat, never its exit FSM.
local CampaignDirector={}
CampaignDirector.__index=CampaignDirector
local function finite(value)
    return type(value)=='number' and value==value and value>-math.huge and value<math.huge
end

function CampaignDirector.new(session,world,Combat,config,deps)
    local self=setmetatable({session=session,world=world,config=config,deps=deps,
        definition=config.Level,now=session.now,stage=config.Level.mode or 'Course',bossSequences={},encounterSerial=0},CampaignDirector)
    self.modes=deps.CampaignModes.new(session,world,self.definition)
    world.campaignModes=self.modes
    self.ordinary=deps.Director.new(session,world,Combat,config,deps.GuardianPattern,deps.HealingFlies,
        deps.EnemyCarry,deps.WalkerClubs,deps.DragonFlight,deps.BossIntro)
    -- Authored campaign courses own topology and completion. Family AI still
    -- resolves its attacks, reactions, claims and same-body ownership normally.
    self.ordinary._zoneReached=function() return false end
    self.ordinary._boss=function() end
    self.enemies=table.clone(self.ordinary.enemies)
    self.ownerNames=self.ordinary.ownerNames
    self.ownerConnections=self.ordinary.ownerConnections or {}
    self.ordinary.ownerConnections=self.ownerConnections
    self.carry=self.ordinary.carry;self.clubs=self.ordinary.clubs;self.dragons=self.ordinary.dragons
    self.modes.canBoard=function() return self:_boardingCleared() end
    self.modes.spawnEncounter=function(event) return self:_spawnEncounter(event) end
    self.modes.resetEncounters=function(event) return self:_resetEncounters(event) end
    self.modes.ropeKick=function(slot,now) return self:_ropeKick(slot,now) end
    if deps.CampaignEnemies then
        self.campaignEnemies=deps.CampaignEnemies.new(self.ordinary)
        self.ordinary.campaignEnemies=self.campaignEnemies
        self.campaignEnemies.externalEnemies=self.enemies
        self.campaignEnemies.enemyHit=function(attacker,target,action,tuning) return self:hit(attacker,target,action,tuning) end
        self.campaignEnemies.vehicleObstacleHit=function(slot,owner,actorId) return self.modes:vehicleObstacleHit(slot) end
    end
    if self.modes.race then
        self.enemies[self.modes.race.enemyId]=self.modes.race.enemy
        self.modes.race.ownerNames=self.ownerNames
    end
    return self
end

function CampaignDirector:_boardingCleared()
    for id,enemy in pairs(self.ordinary.enemies) do
        if id~=-99 and not enemy.dead and not enemy.encounter
            and not (self.dragons and self.dragons:isMounted(id)) then return false end
    end
    return true
end
function CampaignDirector:_spawnEncounter(event)
    if self.closed or self.result then return false end
    self.encounterSerial+=1
    local row=table.clone(event)
    -- A course rewind is a new scripted appearance, never reuse an old identity.
    row.id=-200-self.encounterSerial
    assert(row.id>-1000,'Too many scripted encounter appearances')
    local p=event.position
    row.x,row.y,row.z=p.x,p.y,p.z;row.spawnSerial=self.encounterSerial
    self.ordinary.now=self.session.now
    self.ordinary:_wave('Route',{row})
    local enemy=self.ordinary.enemies[row.id]
    enemy.encounter=true;enemy.encounterKey=event.id
    self.enemies[row.id]=enemy
    return row.id
end
function CampaignDirector:_resetEncounters(event)
    for id,enemy in pairs(self.ordinary.enemies) do
        -- Cleanup is unconditional; Modes separately decides which triggers
        -- lie beyond the checkpoint and may create a new scripted appearance.
        if enemy.encounter then
            if not enemy.dead then self.ordinary:_kill(id,'CourseRewind') end
            if self.campaignEnemies and self.campaignEnemies.expireEncounter then self.campaignEnemies:expireEncounter(id) end
        end
    end
end
function CampaignDirector:_ropeKick(slot,now)
    local hero=self.session.state.heroes[slot]
    local combat=self.session.combat[slot]
    if not hero or hero.status~='Alive' or not hero.connected or not combat or combat.deathAt then return 'NOT_ALIVE' end
    self.now=now;self.ordinary.now=now
    local code=self.session:_event('BeginAttack',slot,{connectionEpoch=hero.connectionEpoch})
    if code~='OK' then return code end
    self.world:hold(slot,false)
    local armed=self.campaignEnemies and self.campaignEnemies:hasRavenClaw(slot)
    local targets=self.world:targets(slot,self.config.Attacks[armed and 'RopeClaw' or 'RopeStrike'])
    self:closeTargetForAttack(targets)
    local action=armed and 'RopeClaw' or 'RopeStrike'
    for _,target in ipairs(targets) do
        local enemy=self.ordinary.enemies[target]
        if enemy and not enemy.dead then
            action=(enemy.kind~='LargeRaven' and enemy.rawLife and (enemy.rawLife<16 or enemy.kind=='RetroBlaster' and enemy.rawLife<32)) and 'RopeBoot'
                or (armed and 'RopeClaw' or 'RopeStrike')
            if self.ordinary:hit(slot,target,action,self.config.Attacks[action]) then break end
        elseif self.session.state.heroes[target] and self.session:_hit(slot,target,action,self.config.Attacks[action]) then break end
    end
    combat.lastStrikeAction='HeroKick';combat.strikeRecoveryUntil=now+.25
    self.session:_record('AttackAccepted',slot,{action=action,context='Rope',sourceAnimation='46/48/4E/50/52'})
    return 'OK'
end

function CampaignDirector:_hasSurvivor()
    for _,id in ipairs(self.session.order) do
        local hero,combat=self.session.state.heroes[id],self.session.combat[id]
        if hero and hero.status=='Alive' and combat and not combat.deathAt then return true end
    end
    return false
end

function CampaignDirector:_ordinaryCleared()
    for id,enemy in pairs(self.ordinary.enemies) do
        if id~=-99 and not enemy.dead and not (self.dragons and self.dragons:isMounted(id)) then return false end
    end
    return true
end

function CampaignDirector:_startBoss(now,chase)
    local assigned=self.bossGate and self.bossGate(now) or {state='NPC'}
    if not assigned or assigned.state=='Waiting' then self.stage='BossReady';return false end
    local definition=table.clone(self.definition)
    definition.boss=table.clone(self.definition.boss)
    definition.boss.type=definition.boss.type or definition.boss.kind
    definition.boss.chaseComplete=chase~=true
    definition.bossGate={ownerUserId=assigned.state=='Human' and assigned.userId or nil,
        connected=assigned.state~='Human' or self.ownerConnections[assigned.userId]~=false,
        connectionEpoch=1,ownerName=assigned.userId and self.ownerNames[assigned.userId]}
    self.boss=self.deps.CampaignBoss.new(self.session,self.world,self.config,definition)
    self.boss.externalEnemies=self.enemies
    self.boss.enemyHit=function(attacker,target,action,tuning) return self:hit(attacker,target,action,tuning) end
    self.enemies[-99]=self.boss.enemies[-99]
    if chase then
        self.stage='Chase'
        self.modes.chaseActor=function(point)
            if self.boss.state=='Chase' then self.world:placeActor(-99,point) end
        end
        self.modes.chaseLife=self.boss.enemies[-99].rawLife
        if definition.bossGate.ownerUserId and self.modes.setChaseController then
            self.modes:setChaseController(definition.bossGate.ownerUserId,definition.bossGate.connected)
        end
    else self.stage='Boss' end
    self.world:stage(self.stage)
    return true
end

function CampaignDirector:step(now,dt)
    if self.closed or self.result then return end
    self.now=now;self.ordinary.now=now
    if self.session.state.status=='Lost' then
        self.result='Lost';self.stage='Lost';self.world:stage('Lost');self:close('Lost');return
    end
    if self.definition.mode=='Clinger' and not self.boss and not self:_startBoss(now,true) then return end
    self.modes:step(now,dt)
    self.ordinary:step(now,dt)
    if self.campaignEnemies then self.campaignEnemies:step(now,dt) end
    if self.boss then
        if self.boss.state=='Chase' and self.modes.complete then
            self.modes.chaseFinished=true
            self.world:placeActor(-99,self.definition.boss.position)
            self.boss:finishChase();self.stage='Boss';self.world:stage('Boss')
        end
        self.boss:step(now,dt)
        -- Session may still owe the last hero's accepted death and paid retry.
        -- Keep this stage stepping until the same eligibility as advanceLevel
        -- holds; never replace its geometry or cancel that lethal deadline.
        if self.boss.defeated and self.modes.complete and self:_hasSurvivor() then self.result='Won';self.stage='Won';self.world:stage('Won') end
    elseif self.modes.complete and (self.definition.requiresClearAtExit==false or self:_ordinaryCleared()) then
        local boss=self.definition.boss
        if boss and (boss.kind or boss.type) then self:_startBoss(now)
        elseif self:_hasSurvivor() then self.result='Won';self.stage='Won';self.world:stage('Won') end
    end
end

function CampaignDirector:hit(attacker,target,action,tuning)
    if self.closed or self.result then return false end
    if self.modes.race and self.modes.race:isTarget(target) then
        self.modes.race.now=math.max(self.now,self.session.now or 0)
        return self.modes.race:hit(attacker,target,action,tuning)
    end
    if target==-99 then
        if not self.boss then return false end
        self.boss.now=self.now
        return self.boss:hit(attacker,target,action,tuning)
    end
    self.ordinary.now=self.now
    return self.ordinary:hit(attacker,target,action,tuning)
end
function CampaignDirector:selectBossAction(target,input)
    if target==-99 and self.boss and self.boss.selectAction then return self.boss:selectAction(input) end
end
function CampaignDirector:_finishReaction(id,enemy) return self.ordinary:_finishReaction(id,enemy) end
function CampaignDirector:closeTargetForAttack(targets)
    if self.modes.race then self.modes.race:closeTargetForAttack(targets) end
    return self.ordinary:closeTargetForAttack(targets)
end
function CampaignDirector:controlled(userId)
    local boss=self.boss and self.boss:controlled(userId)
    local racer=self.modes.race and self.modes.race:controlled(userId)
    return boss or racer or self.ordinary:controlled(userId)
end
function CampaignDirector:available(userId)
    if self.closed or self.result or (self.boss and self.boss:controlled(userId)) then return {} end
    local race=self.modes.race
    if race and race:controlled(userId) then return {} end
    local offers=self.ordinary:available(userId)
    if race and not self.ordinary:controlled(userId) then
        for _,offer in ipairs(race:available(userId)) do offers[#offers+1]=offer end
    end
    return offers
end
function CampaignDirector:claim(userId,id)
    if self.closed or self.result then return 'RUN_CLOSED' end
    if id==-99 then return 'UNKNOWN_ENEMY' end
    if self.boss and self.boss:controlled(userId) then return 'ENEMY_ALREADY_OWNED' end
    if self.modes.race then
        if self.modes.race:controlled(userId) or self.ordinary:controlled(userId) and id==self.modes.race.enemyId then return 'ENEMY_ALREADY_OWNED' end
        if id==self.modes.race.enemyId then return self.modes.race:claim(userId,id) end
    end
    return self.ordinary:claim(userId,id)
end
function CampaignDirector:connection(userId,connected)
    if self.modes.race and self.modes.race:controlled(userId) then return self.modes.race:connection(userId,connected) end
    if self.boss and self.boss:controlled(userId) then
        if self.boss.state=='Chase' and self.modes.chaseConnection then self.modes:chaseConnection(connected) end
        return self.boss:connection(userId,connected)
    end
    return self.ordinary:connection(userId,connected)
end
function CampaignDirector:command(userId,payload,now,validator)
    if self.modes.race and self.modes.race:controlled(userId) then return self.modes.race:command(userId,payload,now,validator) end
    local role=self.boss and self.boss:controlled(userId)
    if not role then return self.ordinary:command(userId,payload,now,validator) end
    if type(validator)~='function' or not validator(payload) then return 'INVALID_INTENT' end
    if payload.runId~=self.session.state.runId then return 'WRONG_RUN' end
    if self.closed or self.result or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    if not role.connected then return 'OFFLINE' end
    if role.status~='Alive' then return 'NOT_ALIVE' end
    if payload.actorId~=role.actorId or payload.attempt~=role.attempt
        or payload.levelEpoch~=self.session.state.levelEpoch then return 'STALE_ACTOR' end
    if payload.connectionEpoch~=role.connectionEpoch then return 'STALE_CONNECTION' end
    local sequence=self.bossSequences[userId]
    if sequence and sequence.connectionEpoch==role.connectionEpoch and payload.seq<=sequence.seq then return 'STALE_SEQUENCE' end
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now;self.bossSequences[userId]={connectionEpoch=role.connectionEpoch,seq=payload.seq}
    if self.boss.state=='Chase' then
        if payload.kind~='Move' then return 'CHASE_ONLY' end
        if self.modes.chaseCommand then return self.modes:chaseCommand(payload.x,payload.z,now) end
        return 'CHASE_ONLY'
    end
    if payload.kind=='Attack' then return self.boss:command(payload.attack,self.bossAim,now) end
    if not self.boss:canMove() then return 'REACTION' end
    if payload.kind=='Jump' then self.world:jump(-99)
    else
        local length=math.sqrt(payload.x^2+payload.z^2)
        if length>0 then self.bossAim={x=payload.x/length,z=payload.z/length} end
        self.world:move(-99,payload.x,payload.z,false)
    end
    return 'OK'
end
function CampaignDirector:interaction(slot)
    local mode=self.modes:interaction(slot)
    if mode and (mode.available or mode.carrying) then
        mode.label=mode.label or mode.action
        if mode.kind=='CampaignKick' and self.campaignEnemies and self.campaignEnemies:hasRavenClaw(slot) then mode.label='Raven claw strike' end
        return mode
    end
    return self.ordinary:interaction(slot)
end
function CampaignDirector:interact(slot,now,action)
    local result=self.modes:interact(slot,now,action)
    if result~='NO_INTERACTION' then return result end
    return self.ordinary:interact(slot,now,action)
end
function CampaignDirector:cancelBossIntro(reason) return self.ordinary:cancelBossIntro(reason) end
function CampaignDirector:close(reason)
    if self.closed then return end
    self.closed=true
    self.modes:close(reason)
    if self.world.campaignModes==self.modes then self.world.campaignModes=nil end
    if self.boss then self.boss:close(reason) end
    if self.campaignEnemies then self.campaignEnemies:close(reason) end
    self.ordinary:cancelBossIntro(reason)
    for _,name in ipairs({'flies','carry','clubs','dragons'}) do
        local component=self.ordinary[name]
        if component and component.close then component:close(reason) end
    end
end
function CampaignDirector:snapshot()
    local data=self.ordinary:snapshot()
    local mode=self.modes:snapshot()
    data.stage=self.stage;data.mode=self.definition.mode;data.modeState=mode
    data.bossMechanic=self.boss and 'Campaign' or nil;data.bossHits=nil;data.bossMax=nil;data.bossIntro=nil
    data.objective=mode.objective or self.definition.objective or self.definition.name
    if self.definition.course and self.definition.course.mount and not self:_boardingCleared() then
        data.objective='Defeat the patrol before boarding'
    end
    data.campaignIndex=self.definition.campaignIndex;data.campaignCount=self.deps.CampaignDefinition and self.deps.CampaignDefinition.count or 13
    data.levelName=self.definition.name;data.result=self.result
    if self.modes.race then
        local rival=self.modes.race:snapshot()
        data.enemies[#data.enemies+1]={id=rival.enemyId,actorId=rival.actorId,kind='RacingRat',resourceKind='CourseRival',
            dead=rival.dead,courseRival=true,reactionEpoch=self.modes.race.enemy.reactionEpoch}
    end
    if self.stage=='BossReady' then data.objective='Assigning boss: waiting for the invited player' end
    if self.boss then
        data.boss=self.boss:snapshot();data.bossType=self.definition.boss.kind or self.definition.boss.type
        data.bossRawLife=data.boss.rawLife;data.bossProgress=data.boss.progress
        for key,value in pairs(data.boss) do if string.sub(key,1,4)=='boss' then data[key]=value end end
        data.objective=data.boss.objective or 'Defeat '..data.bossType
    end
    if self.result=='Won' then data.objective='Course cleared' elseif self.result=='Lost' then data.objective='Team eliminated' end
    return data
end
return CampaignDirector
