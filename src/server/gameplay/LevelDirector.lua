-- Original prototype encounters. All decisions run on the server.
-- Enemy arithmetic/timing are provisional; hero damage/shields use the tested Session.
local Director={}
Director.__index=Director
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function distance(a,b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function towards(a,b,amount)
    local d=distance(a,b)
    if d==0 then return table.clone(a) end
    local t=math.min(1,amount/d)
    return {x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,z=a.z+(b.z-a.z)*t}
end
local objectives={Approach="Defeat the patrol by the old gate",Courtyard="Clear the inner courtyard",
    BossReady="Assigning Guardian: waiting for the invited player",BossIntro="The Guardian approaches",
    Boss="Strike three projectiles back at the Guardian",Exit="The path is open — reach the glowing gate",
    Won="Causeway cleared",Lost="Team eliminated"}

function Director.new(session,world,Combat,config,GuardianPattern,HealingFlies,EnemyCarry,WalkerClubs,DragonFlight,BossIntro)
    local profile=config.Attacks[config.Enemy.attack]
    local self=setmetatable({session=session,world=world,config=config,Combat=Combat,enemies={},projectiles={},byUserId={},ownerNames={},
        stage='Approach',now=session.now or 0,bossHits=0,serial=0,route=config.Level,GuardianPattern=GuardianPattern,BossIntro=BossIntro,
        strikeProfile={reach=config.Enemy.range+1,width=profile.width,height=profile.height,
            windup=config.Enemy.windup,cooldown=config.Enemy.cooldown,recoveryPose=.17},random=math.random},Director)
    if self.route then
        self.flies=HealingFlies and HealingFlies.new(session,world,config)
        self.carry=EnemyCarry and EnemyCarry.new(self)
        self.clubs=WalkerClubs and WalkerClubs.new(self)
        self.dragons=DragonFlight and config.DragonFlight and DragonFlight.new(self)
        self:_enterZone(1)
    else self:_wave('Approach',{{id=-1,x=-24,z=-6},{id=-2,x=-18,z=7}}) end
    return self
end
function Director:_health(id,e)
    if e.rawLife~=nil and not e.boss then
        e.health=self.config.Enemy.hearts*e.rawLife/e.maxRawLife
        self.world:enemyHealth(id,e.rawLife,e.maxRawLife)
    else self.world:enemyHealth(id,e.health,e.boss and self.config.Boss.hits or self.config.Enemy.hearts) end
end
function Director:_log(kind,id,data)
    if self.session._record then self.session:_record(kind,id,data,self.now) end
end
function Director:_resetLocomotion(id,e)
    if e then e.runApproach=nil;e.rushing=nil end
    if self.config.Movement and self.world.resetLocomotion then
        self.world:resetLocomotion(id,self.world.actors and self.world.actors[id])
    end
end
function Director:_finishReaction(id,e)
    if e~=self.enemies[id] or e.dead or not e.reactionUntil or self.now<e.reactionUntil then return false end
    if e.rawLife~=nil then
        local before=e.rawLife
        e.rawLife=(self.Combat.recoverEnemy or self.Combat.recover)(e.rawLife);self:_health(id,e)
        self:_log('EnemyRecovery',id,{actorId=e.actorId,before=before,after=e.rawLife})
    end
    e.reactionUntil=nil;e.heavyReaction=nil;self.world:setReaction(id,false)
    return true
end
function Director:_wave(stage,roster)
    self.stage=stage; self.world:stage(stage)
    for _,r in ipairs(roster) do
        local previous=self.enemies[r.id]
        if previous and previous.ownerUserId then
            self.retiredOwners=self.retiredOwners or {}
            self.retiredOwners[previous.ownerUserId]=previous
        end
        assert(self.world:spawnEnemy(r.id,r.kind or 'Drone',{x=r.x,y=r.y or 3,z=r.z}),'Enemy spawn failed')
        local actorId=self.session.state.runId..':enemy:'..self.session.state.levelEpoch..':'..r.id
        if r.spawnSerial~=nil then
            assert(type(r.spawnSerial)=='number' and r.spawnSerial>=1 and r.spawnSerial%1==0,'Invalid enemy spawn serial')
            actorId=actorId..':spawn:'..r.spawnSerial
        end
        self.enemies[r.id]={health=self.config.Enemy.hearts,nextAttack=self.now,engaged=false,
            actorId=actorId,zoneIndex=self.zoneIndex,kind=r.kind,
            trajectory=r.trajectory,allowedDrop=r.allowedDrop,sourceProfile=r.sourceProfile,
            name=r.name or ({Pig="Marsh Raider",Walker="Long-legged Guard",Dragon="Winged Scout"})[r.kind]
                or (r.kind and (r.kind:gsub('(%l)(%u)','%1 %2'))) or "Rusty Guard"}
        local e=self.enemies[r.id]
        if self.config.SourceCombat and r.rawLife~=nil then
            assert(type(r.rawLife)=='number' and r.rawLife>=0 and r.rawLife<=255 and r.rawLife%1==0,'Invalid source Life')
            e.rawLife=r.rawLife;e.maxRawLife=math.floor(r.rawLife/16)*16+15
        end
        self.world:enemyIdentity(r.id,actorId)
        self:_health(r.id,e)
        self:_log('EnemySpawned',r.id,{actorId=actorId,kind=e.kind,rawLife=e.rawLife,health=e.health})
    end
end
function Director:_enterZone(index)
    self.zoneIndex=index
    if self.flies then self.flies:activate(index) end
    self.world:progress(index,false)
    self:_wave('Route',self.route.zones[index].enemies)
end
function Director:_zoneReached()
    local volume=self.route.zones[self.zoneIndex].exit
    for _,id in ipairs(self.session.order) do
        local hero=self.session.state.heroes[id]
        if hero.status=='Alive' and not self.session.combat[id].deathAt and self.world:reached(id,volume) then return true end
    end
    return false
end
function Director:interaction(slot)
    local carry=self.carry and self.carry:interaction(slot)
    if carry and carry.carrying then return carry end
    if self.guardian and self.stage=='Boss' then
        local interaction=self.guardian:interaction(slot)
        if interaction.available then return interaction end
    end
    local fly=self.flies and self.flies:interaction(slot)
    if fly and fly.available then return fly end
    local dragon=self.dragons and self.dragons:interaction(slot)
    if dragon and (dragon.available or dragon.carrying) then return dragon end
    local club=self.clubs and self.clubs:interaction(slot)
    if club and club.available then return club end
    return carry or {available=false}
end
function Director:interact(slot,now,attack)
    self.now=now
    if self.carry and self.carry:interaction(slot).carrying then return self.carry:interact(slot,now,attack) end
    if self.guardian and self.stage=='Boss' then
        if attack~='Punch' then return self.guardian:interaction(slot).carrying and 'HANDS_FULL' or 'NO_INTERACTION' end
        local result=self.guardian:interact(slot,now)
        if result=='OK' and self.clubs then self.clubs:drop(slot,'GuardianBall') end
        if result~='NO_INTERACTION' then return result end
    end
    if attack~='Punch' then return 'NO_INTERACTION' end
    if self.flies then
        local result=self.flies:interact(slot,now)
        if result~='NO_INTERACTION' then return result end
    end
    if self.dragons then
        local result=self.dragons:interact(slot,now,attack)
        if result~='NO_INTERACTION' then return result end
    end
    if self.clubs then
        local result=self.clubs:interact(slot,now,attack)
        if result~='NO_INTERACTION' then return result end
    end
    return self.carry and self.carry:interact(slot,now,attack) or 'NO_INTERACTION'
end
function Director:claim(userId,enemyId)
    if self.retiredOwners and self.retiredOwners[userId] then return 'ENEMY_LIFE_SPENT' end
    local owned=self.byUserId[userId]
    if owned then
        if self.enemies[owned].dead then return 'ENEMY_LIFE_SPENT' end
        if owned==enemyId then return 'OK' end
        return 'ENEMY_ALREADY_OWNED'
    end
    if self.result or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    if enemyId==-99 then return 'UNKNOWN_ENEMY' end
    local e=self.enemies[enemyId]
    if not e then return 'UNKNOWN_ENEMY' end
    if not e.dead and self.world:hazard(enemyId) then self:_kill(enemyId) end
    if e.dead then return 'ENEMY_DEAD' end
    if e.ownerUserId then return 'ENEMY_OCCUPIED' end
    if e.engaged then return 'ENEMY_ENGAGED' end
    e.ownerUserId=userId; e.connected=true; e.connectionEpoch=1; e.lastSeq=0; e.rushing=nil
    self:_resetLocomotion(enemyId,e)
    self.byUserId[userId]=enemyId
    self.world:move(enemyId,0,0)
    self.world:enemyIdentity(enemyId,e.actorId,self.ownerNames[userId])
    self:_log('EnemyClaimed',enemyId,{actorId=e.actorId,ownerUserId=userId,rawLife=e.rawLife,health=e.health})
    return 'OK'
end
function Director:connection(userId,connected)
    local retired=self.retiredOwners and self.retiredOwners[userId]
    if retired then
        if type(connected)~='boolean' then return 'INVALID_CONNECTION' end
        if retired.connected==connected then return 'NO_CHANGE' end
        retired.connected=connected;retired.connectionEpoch=(retired.connectionEpoch or 0)+1
        return 'OK'
    end
    local id=self.byUserId[userId]; local e=id and self.enemies[id]
    if not e then return 'UNKNOWN_ENEMY' end
    if type(connected)~='boolean' then return 'INVALID_CONNECTION' end
    if e.connected==connected then return 'NO_CHANGE' end
    e.connected=connected; e.connectionEpoch+=1; e.lastSeq=0; e.lastMove=nil
    self:_resetLocomotion(id,e)
    self.world:move(id,0,0)
    self:_log('EnemyConnection',id,{actorId=e.actorId,ownerUserId=userId,connected=connected,connectionEpoch=e.connectionEpoch})
    return 'OK'
end
function Director:controlled(userId)
    local id=self.byUserId[userId]; local e=self.retiredOwners and self.retiredOwners[userId] or id and self.enemies[id]
    if not e then return nil end
    return {enemyId=id,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,
        connected=e.connected,status=e.dead and 'Dead' or 'Alive',hearts=e.health,
        maxHearts=e.boss and self.config.Boss.hits or self.config.Enemy.hearts,
        template=e.boss and 'Boss' or 'Sentry',name=e.name,carryState=self.carry and self.carry:stateFor(id),dragonMode=self.dragons and self.dragons.states[id] and self.dragons.states[id].mode,
        movementKind=self.campaignEnemies and self.campaignEnemies:movementKind(id,e) or nil,
        reactionEpoch=e.reactionEpoch or 0,movementMode=self.world.movementMode and self.world:movementMode(id) or nil}
end
function Director:available(userId)
    local offers={}
    if self.byUserId[userId] or self.result or self.session.state.status~='Active' then return offers end
    for id,e in pairs(self.enemies) do
        if not e.boss and not e.dead and not e.engaged and not e.ownerUserId and not self.world:hazard(id) then
            offers[#offers+1]={enemyId=id,actorId=e.actorId,name=e.name,hearts=e.health,maxHearts=self.config.Enemy.hearts}
        end
    end
    table.sort(offers,function(a,b) return a.enemyId>b.enemyId end)
    return offers
end
function Director:closeTargetForAttack(targetIds)
    for _,id in ipairs(targetIds) do
        local e=self.enemies[id]
        if e and not e.dead and not (e.reactionUntil and self.now<e.reactionUntil) then e.engaged=true; return end
        local h=self.session.state.heroes[id]
        local c=self.session.combat[id]
        if h and h.status=='Alive' and not c.deathAt and not c.reactionEnd then return end
        local ball=self.projectiles[id]
        if (ball and not ball.reflected) or (id==-99 and self.stage=='Boss') then return end
    end
end
function Director:command(userId,payload,now,validator)
    local id=self.byUserId[userId]; local e=id and self.enemies[id]
    if not e then return 'UNKNOWN_ENEMY' end
    if type(validator)~='function' or not validator(payload) then return 'INVALID_INTENT' end
    if self.retiredOwners and self.retiredOwners[userId] then return 'STALE_ACTOR' end
    if payload.kind~='Move' and payload.kind~='Jump' and payload.kind~='Attack' then return 'INVALID_INTENT' end
    if payload.kind=='Attack' and payload.attack~='Punch' then return 'INVALID_INTENT' end
    if e.boss and payload.kind=='Jump' then return 'INVALID_INTENT' end
    if payload.runId~=self.session.state.runId then return 'WRONG_RUN' end
    if self.result or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    if not e.connected then return 'OFFLINE' end
    if e.dead then return 'NOT_ALIVE' end
    if e.boss and self.world:hazard(id) then self:_kill(id); return 'NOT_ALIVE' end
    if payload.actorId~=e.actorId or payload.attempt~=1 or payload.levelEpoch~=self.session.state.levelEpoch then return 'STALE_ACTOR' end
    if payload.connectionEpoch~=e.connectionEpoch then return 'STALE_CONNECTION' end
    if payload.seq<=e.lastSeq then return 'STALE_SEQUENCE' end
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now; e.lastSeq=payload.seq
    if self.carry and self.carry:blocksEnemy(id) then
        return self.carry:stateFor(id)=='Carried' and 'HELD' or 'THROWN'
    end
    if e.boss then
        if self.stage~='Boss' then return 'RUN_CLOSED' end
        if payload.kind=='Move' then
            local length=math.sqrt(payload.x^2+payload.z^2)
            if length>0 then
                e.aim={x=payload.x/length,z=payload.z/length}
                if self.world.aim then self.world:aim(id,e.aim.x,e.aim.z) end
            end
        else
            if now<self.nextShot then return 'COOLDOWN' end
            if self.guardian then return self.guardian:fire(e.aim) end
            self:_shoot(nil,e.aim); self.nextShot=now+self.config.Boss.interval
        end
        return 'OK'
    end
    if e.reactionUntil then return 'REACTION' end
    if self.campaignEnemies and self.campaignEnemies:owns(id,e) then
        return self.campaignEnemies:command(id,e,payload,now)
    end
    if self.dragons and e.kind=='Dragon' then
        local code=self.dragons:enemyCommand(id,e,payload,now)
        if code then return code end
    end
    if payload.kind=='Move' then
        e.lastMove=now; self.world:move(id,payload.x,payload.z,payload.run)
    elseif payload.kind=='Jump' then self.world:jump(id)
    else
        if e.windup or now<e.nextAttack then return 'COOLDOWN' end
        self:_beginStrike(id,e)
    end
    return 'OK'
end
function Director:_strikeTarget(id,profile)
    for _,target in ipairs(self.world:targets(id,profile)) do
        local enemy=self.enemies[target]
        local hero=self.session.state.heroes[target]
        local combat=self.session.combat[target]
        if enemy and not enemy.dead and not enemy.reactionUntil then return target end
        if hero and hero.status=='Alive' and combat and not combat.deathAt
            and (not combat.reactionEnd or combat.recover==true) then return target end
    end
end
function Director:_beginStrike(id,e,target)
    if self.dragons and e.kind=='Dragon' and self.dragons:beginCapture(id,e,target) then return end
    local action=self.config.Enemy.attack
    local tuning=self.strikeProfile
    local running=self.config.Movement and not e.boss and e.kind~='Dragon' and self.world.isRunning
        and self.world:isRunning(id)==true
    local sourceRush=e.kind=='Pig' and e.rushing and (not self.config.Movement or running)
    local sourceFamily=self.route and ((e.kind=='Pig' and self.config.Pig) or (e.kind=='Walker' and self.config.Walker))
    if running and not sourceRush then
        action='EnemyRunStrike';tuning=self.config.Attacks[action]
    elseif self.route and e.kind=='Dragon' and self.config.Dragon then
        action='DragonHeadbutt';tuning=self.config.Attacks[action]
    elseif sourceFamily then
        local light=e.kind=='Pig' and 'PigJab' or 'WalkerLight'
        local heavy=e.kind=='Pig' and 'PigHeavy' or 'WalkerHeavy'
        target=target or self:_strikeTarget(id,self.config.Attacks[light])
        local combat=target and self.session.combat[target]
        local ordinary=target and self.enemies[target]
        if not combat and ordinary and ordinary.rawLife~=nil then combat=ordinary end
        -- Prototype enemy3HP is not raw source Life; an unknown target uses jab.
        action=sourceRush and 'PigRush' or (combat and combat.rawLife%16<4 and heavy or light)
        tuning=self.config.Attacks[action]
    end
    e.engaged=true; e.rushing=nil; e.runApproach=nil; e.strikeRecoveryUntil=nil
    e.windup={at=self.now+tuning.windup,action=action,tuning=self.Combat.captureAttack(self.config,action,tuning)}
    self.world:move(id,0,0,false); self.world:cue(id,true)
    self:_log('EnemyAttackAccepted',id,{actorId=e.actorId,action=action,ownerUserId=e.ownerUserId,effectAt=e.windup.at})
end
function Director:_resolveStrike(id,e)
    local pending=e.windup
    e.windup=nil; e.nextAttack=self.now+pending.tuning.cooldown
    e.lastStrikeAction=pending.action; e.strikeRecoveryUntil=self.now+pending.tuning.recoveryPose
    local landed=false
    for _,target in ipairs(self.world:targets(id,pending.tuning)) do
        local hit=false
        if self.enemies[target] then hit=self:hit(id,target,pending.action,pending.tuning)
        elseif self.session.state.heroes[target] then hit=self.session:_hit(id,target,pending.action,pending.tuning) end
        if hit then landed=true;break end
    end
    if not landed then self:_log('EnemyAttackMiss',id,{actorId=e.actorId,action=pending.action}) end
end
function Director:_boss()
    if self.bossIntro or self.enemies[-99] then return end
    local controller=self.bossGate and self.bossGate(self.now) or {state='NPC'}
    if controller.state=='Waiting' then
        self.stage='BossReady'; self.world:stage('BossReady'); return
    end
    if self.clubs then self.clubs:bossIntro() end
    if self.route and self.BossIntro then
        -- Drop carried bodies and pending captures through their normal release
        -- path. Carry remains available after this single intro transition.
        if self.carry then
            local released={}
            for id,row in pairs(self.carry.states) do if row.mode=='Carried' then released[id]=true end end
            for _,row in ipairs(self.carry.pending) do released[row.id]=true end
            for id in pairs(released) do self.carry:forgetEnemy(id) end
        end
        self.bossController=controller
        self.stage='BossIntro';self.world:stage('BossIntro')
        self.bossIntro=self.BossIntro.new(self)
        return
    end
    self:_activateBoss(controller)
end
function Director:cancelBossIntro(reason)
    if self.bossIntro then return self.bossIntro:cancel(reason) end
end
function Director:_activateBoss(controller)
    if self.enemies[-99] then return end
    self.stage='Boss'; self.world:stage('Boss')
    local position=self.route and self.route.boss.position or {x=82,y=3,z=0}
    assert(self.world:spawnEnemy(-99,'Boss',position),'Boss spawn failed')
    local actorId=self.session.state.runId..':boss:'..self.session.state.levelEpoch
    local e={boss=true,actorId=actorId,health=self.config.Boss.hits,rawLife=self.route and self.config.Boss.rawLife,
        zoneIndex=self.zoneIndex,name="Causeway Guardian",aim={x=-1,z=0}}
    self.enemies[-99]=e
    if controller.state=='Human' then
        e.ownerUserId=controller.userId
        e.connected=self.ownerConnections==nil or self.ownerConnections[controller.userId]~=false
        e.connectionEpoch=1; e.lastSeq=0
        self.byUserId[controller.userId]=-99
    end
    self.world:enemyIdentity(-99,actorId,e.ownerUserId and self.ownerNames[e.ownerUserId])
    self.world:enemyHealth(-99,self.config.Boss.hits,self.config.Boss.hits)
    self:_log('BossAssigned',-99,{actorId=actorId,ownerUserId=e.ownerUserId,rawLife=e.rawLife,health=e.health})
    self.nextShot=self.now+1.8
    if self.route then
        assert(self.GuardianPattern,'Modern guardian pattern is required')
        self.guardian=self.GuardianPattern.new(self)
    end
end
function Director:isTarget(id)
    return self.enemies[id]~=nil or self.projectiles[id]~=nil or id==-99
end
function Director:_kill(id,cause)
    local e=self.enemies[id]
    if not e or e.dead then return end
    if self.carry then self.carry:forgetEnemy(id) end
    if self.dragons then self.dragons:forgetEnemy(id) end
    if self.campaignEnemies then self.campaignEnemies:forgetEnemy(id) end
    self:_resetLocomotion(id,e)
    e.dead=true; e.windup=nil; e.rushing=nil; e.strikeRecoveryUntil=nil; e.health=0
    if self.clubs and e.kind=='Walker' then self.clubs:walkerDefeated(id,self.world:position(id),cause) end
    if e.rawLife~=nil then e.rawLife=0 end
    self:_health(id,e)
    self.world:kill(id)
    self:_log('EnemyDeath',id,{actorId=e.actorId,cause=cause or 'Unknown',ownerUserId=e.ownerUserId,position=self.world:position(id)})
    if e.boss then
        self.stage='Exit'; self.world:stage('Exit')
    end
end
function Director:hit(attacker,target,action,tuning)
    if self.result then return false end
    if self.guardian and (self.projectiles[target] or target==-99) then return self.guardian:hit(attacker,target,action) end
    local ball=self.projectiles[target]
    if ball then
        if ball.reflected then return false end
        ball.reflected=true
        ball.reflectedAt=self.now
        self.world:projectile(target,ball.position,true)
        self.world:cue(attacker,false)
        return true
    end
    if target==-99 then
        if self.stage~='Boss' then return false end
        self.world:cue(-99,true)
        local profile=action=='Dash' and 22 or 18
        local responses=tuning and tuning.responses or self.config.Impulses
        local impulse=responses and responses[profile]
        if impulse then self.world:impulse(-99,attacker,impulse,profile,tuning and tuning.impulseDirection) end
        return true
    end
    local e=self.enemies[target]
    if e and e.rawLife~=nil and self.carry and self.carry:blocksEnemy(target) then return false end
    if e and e.rawLife~=nil then self:_finishReaction(target,e) end
    if not e or e.dead or (e.rawLife==nil and e.reactionUntil and self.now<e.reactionUntil) then return false end
    if self.carry then self.carry:forgetEnemy(target) end
    if self.campaignEnemies and self.campaignEnemies:owns(target,e) then self.campaignEnemies:onHit(target) end
    self:_resetLocomotion(target,e)
    e.reactionEpoch=(e.reactionEpoch or 0)+1
    e.engaged=true; e.windup=nil; e.rushing=nil; e.strikeRecoveryUntil=nil
    local family=(self.config.Pig and self.config.Pig.npcDamage[action] and self.config.Pig)
        or (self.config.Walker and self.config.Walker.npcDamage[action] and self.config.Walker)
        or (self.config.Dragon and self.config.Dragon.npcDamage[action] and self.config.Dragon)
    local runStrike=action=='EnemyRunStrike'
    local damage=(runStrike and self.config.Enemy.dashDamage) or (family and family.npcDamage[action]) or (action=='Club' and self.config.WalkerClub.npcDamage
        or (action=='Dash' and self.config.Enemy.dashDamage or self.config.Enemy.punchDamage))
    local before=e.rawLife or e.health
    local source=e.rawLife~=nil and self.Combat.hitEnemy(e.rawLife,action)
    if source then e.rawLife=source.rawLife else e.health=math.max(0,e.health-damage) end
    -- This cosmetic receipt comes from the actual successful effect result,
    -- never a later target-Life read. Captured tuning identifies one accepted
    -- server attack; body/actor/epoch prevent it crossing a replacement.
    if action=='Dash' and source and source.profile==3 and type(tuning)=='table' then
        local hero=self.session.state.heroes[attacker]
        local actor=self.world.actors[attacker]
        if hero and hero.status=='Alive' and actor and actor.model and actor.model.Parent
            and actor.model:GetAttribute('ActorId')==hero.actorId then
            actor.dashPresentationResult={branch='DashLowLifeTail',profile=source.profile,tuning=tuning,
                body=actor.model,actorId=hero.actorId,levelEpoch=self.session.state.levelEpoch,at=self.now}
        end
    end
    self:_health(target,e)
    self.world:cue(target,false)
    self:_log('EnemyHit',target,{actorId=e.actorId,attacker=attacker,target=target,action=action,
        before=before,after=e.rawLife or e.health,sourceRaw=source~=false and source~=nil,
        profile=source and source.profile or nil,dying=source and source.dying,position=self.world:position(target)})
    if self.campaignEnemies and self.campaignEnemies.afterHit and self.campaignEnemies:afterHit(target,e,attacker,action) then return true end
    if (source and source.dying) or (not source and e.health==0) then self:_kill(target,'Combat')
    else
        local policy=tuning and tuning.sourceCombat or self.config.SourceCombat
        local reaction=source and (source.heavyReaction and policy.npcHeavyReaction
            or policy.npcLightReaction) or ((tuning and tuning.reaction) or (family and self.config.Attacks[action].reaction)
            or (runStrike and self.config.Attacks[action].reaction)
            or (action=='Club' and self.config.Attacks.Club.reaction or self.config.Enemy.reaction)
        )
        e.heavyReaction=source and source.heavyReaction or nil
        e.reactionUntil=self.now+reaction
        if self.dragons then self.dragons:hitEnemy(target,source and source.heavyReaction) end
        self.world:move(target,0,0); self.world:setReaction(target,true)
        local profile=source and source.profile or (runStrike and 4) or (family and family.npcProfile[action] or (action=='Club' and 2 or (action=='Dash' and 22 or 18)))
        local responses=tuning and tuning.responses or self.config.Impulses
        local impulse=responses and responses[profile]
        if impulse then self.world:impulse(target,attacker,impulse,profile,tuning and tuning.impulseDirection) end
    end
    return true
end
function Director:applyThrowDamage(id,heroSlot)
    local e=self.enemies[id]
    if self.result or self.session.state.status~='Active' or not e or e.dead or e.kind~='Pig' then return false end
    local before=e.health
    local source=e.rawLife~=nil and self.Combat.hitEnemy(e.rawLife,'EnemyThrow')
    if source then e.rawLife=source.rawLife else e.health=math.max(0,e.health-self.config.EnemyCarry.throwDamage) end
    e.reactionEpoch=(e.reactionEpoch or 0)+1
    self:_health(id,e);self.world:cue(id,false)
    self.session:_record('EnemyThrowDamage',heroSlot,{enemyId=id,before=before,after=e.health,
        sourceProfile=self.config.EnemyCarry.sourceProfile,sourceRawDamage=self.config.EnemyCarry.sourceRawDamage})
    if (source and source.dying) or (not source and e.health==0) then self:_kill(id,'Combat') end
    return true
end
function Director:_nearest(position,standingEligibility)
    local selected,best=nil,math.huge
    for _,id in ipairs(self.session.order) do
        local h=self.session.state.heroes[id]
        local c=self.session.combat[id]
        if h.status=='Alive' and not c.deathAt and not (c.hitProtectedUntil and self.now<c.hitProtectedUntil)
            and (not standingEligibility or not c.reactionEnd or c.recover==true) then
            local d=distance(position,self.world:position(id))
            if d<best then selected,best=id,d end
        end
    end
    return selected,best
end
function Director:_enemies(dt)
    local living=0
    for id,e in pairs(self.enemies) do
        if not e.dead then
            local hazard=self.world:hazard(id)
            if hazard then self:_kill(id,hazard)
            else
                if not (self.dragons and self.dragons:isMounted(id)) then living+=1 end
                local carried=self.carry and self.carry:blocksEnemy(id)
                if carried then self:_resetLocomotion(id,e); e.strikeRecoveryUntil=nil end
                if not carried and e.reactionUntil and self.now>=e.reactionUntil then
                    self:_finishReaction(id,e)
                end
                if self.campaignEnemies and self.campaignEnemies:owns(id,e) then
                    self.campaignEnemies:enemyStep(id,e,dt)
                elseif self.dragons and e.kind=='Dragon' then
                    self.dragons:enemyStep(id,e,dt)
                elseif not carried and not e.reactionUntil then
                    if e.windup then
                        self.world:move(id,0,0)
                        if self.now>=e.windup.at then self:_resolveStrike(id,e) end
                    elseif e.ownerUserId then
                        if e.lastMove and self.now-e.lastMove>=(self.config.MoveTimeout or .35) then
                            e.lastMove=nil; self.world:move(id,0,0)
                        end
                    else
                        local walker=self.route and e.kind=='Walker' and self.config.Walker
                        local standing=walker or (self.route and e.kind=='Pig' and self.config.Pig)
                            or (self.route and e.kind=='Dragon' and self.config.Dragon)
                        local target,range=self:_nearest(self.world:position(id),standing~=nil and standing~=false)
                        local attackRange=walker and walker.range or self.config.Enemy.range
                        if walker and self.config.Movement and self.world.isRunning and self.world:isRunning(id) then
                            attackRange=math.min(attackRange,self.config.Attacks.EnemyRunStrike.reach)
                        end
                        -- Validate the approach before either melee or movement:
                        -- a newly invalid target cannot preserve an old running hop.
                        if e.rushing then
                            local a,b=self.world:position(id),target and self.world:position(target)
                            local c=target and self.session.combat[target]
                            local alignment=self.config.Pig.alignment
                            if not a or not b or math.abs(a.z-b.z)>alignment or math.abs(a.y-b.y)>alignment
                                or (c and c.reactionEnd) then self:_resetLocomotion(id,e) end
                        end
                        if target and walker and range<walker.minRange then
                            e.runApproach=nil
                            self.world:enemyRetreat(id,target,walker.retreatSpeed)
                        elseif target and range<=attackRange and self.now>=e.nextAttack then
                            self.world:face(id,target); self:_beginStrike(id,e,target)
                        elseif target and range>attackRange*.8 then
                            local speed=self.config.Enemy.speed
                            if walker and self.config.Movement then
                                if range>self.config.Movement.npcRunDistance then e.runApproach=true end
                                if e.runApproach then speed=self.config.Movement.enemyRunSpeed end
                            end
                            if self.route and self.config.Pig and e.kind=='Pig' then
                                local pig=self.config.Pig
                                local a,b=self.world:position(id),self.world:position(target)
                                local c=self.session.combat[target]
                                local aligned=a and b and math.abs(a.z-b.z)<=pig.alignment and math.abs(a.y-b.y)<=pig.alignment
                                if not aligned or (c and c.reactionEnd) then e.rushing=nil
                                elseif range>self.config.Enemy.range and self.zoneIndex>=pig.rushAfterZone
                                    and self.now>=e.nextAttack and not e.rushing and self.now>=(e.nextRushCheck or 0) then
                                    e.nextRushCheck=self.now+pig.decisionInterval
                                    if self.random(1,pig.rushRoll)==1 then e.rushing=true end
                                end
                                if e.rushing then speed=pig.rushSpeed end
                            end
                            self.world:enemyMove(id,target,speed)
                        else e.rushing=nil;e.runApproach=nil; self.world:move(id,0,0,false) end
                    end
                end
            end
        end
    end
    if living>0 and self.route then self.world:progress(self.zoneIndex,false) end
    if living==0 then
        if self.route then
            self.world:progress(self.zoneIndex,true)
            if self:_zoneReached() then
                if self.zoneIndex<#self.route.zones then self:_enterZone(self.zoneIndex+1)
                else self.zoneIndex=#self.route.zones+1;self.world:progress(self.zoneIndex,false);self:_boss() end
            end
        elseif self.stage=='Approach' then self:_wave('Courtyard',{{id=-3,x=22,z=-7},{id=-4,x=30,z=6}})
        elseif self.stage=='Courtyard' then self:_boss() end
    end
end
function Director:_shoot(target,aim)
    local origin=self.world:position(-99)
    if not origin then return end
    local destination=aim and {x=origin.x+aim.x*self.config.Boss.aggroRange,y=origin.y,z=origin.z+aim.z*self.config.Boss.aggroRange}
        or self.world:position(target)
    if not origin or not destination then return end
    if target then self.world:face(-99,target) end
    self.world:cue(-99,true)
    self.serial+=1
    local id=-1000-self.serial
    local start=towards(origin,destination,5)
    self.projectiles[id]={position=start,direction=destination,created=self.now,target=target,reflected=false}
    self.world:projectile(id,start,false)
end
function Director:_projectiles(dt)
    if self.guardian then self.guardian:step(self.now,dt);return end
    local boss=self.enemies[-99]
    if self.stage=='Boss' and boss and not boss.ownerUserId and self.now>=self.nextShot then
        local target,range=self:_nearest(self.world:position(-99))
        if target and range<=self.config.Boss.aggroRange then
            self:_shoot(target)
        end
        self.nextShot=self.now+self.config.Boss.interval
    end
    local remove={}
    for id,p in pairs(self.projectiles) do
        if self.stage~='Boss' then break end
        local destination=p.reflected and self.world:position(-99) or p.direction
        if not destination or self.now-(p.reflectedAt or p.created)>self.config.Boss.projectileLife then remove[#remove+1]=id
        else
            local speed=p.reflected and self.config.Boss.returnSpeed or self.config.Boss.projectileSpeed
            p.position=towards(p.position,destination,speed*dt)
            self.world:projectile(id,p.position,p.reflected)
            if p.reflected and self.stage=='Boss' and distance(p.position,destination)<2.5 then
                self.bossHits+=1; self.world:cue(-99,false)
                boss.health=self.config.Boss.hits-self.bossHits
                self.world:enemyHealth(-99,self.config.Boss.hits-self.bossHits,self.config.Boss.hits)
                remove[#remove+1]=id
                if self.bossHits>=self.config.Boss.hits then
                    self:_kill(-99)
                end
            elseif not p.reflected then
                local hit=false
                for _,hero in ipairs(self.session.order) do
                    if self.session.state.heroes[hero].status=='Alive' and distance(p.position,self.world:position(hero))<2.3 then
                        self.session:_hit(-99,hero,'Dash'); hit=true; break
                    end
                end
                if hit or distance(p.position,destination)<.1 then remove[#remove+1]=id end
            end
        end
    end
    for _,id in ipairs(remove) do self.projectiles[id]=nil; self.world:removeProjectile(id) end
    if self.stage=='Exit' then
        for id in pairs(self.projectiles) do self.world:removeProjectile(id) end
        self.projectiles={}
    end
end
function Director:step(now,dt)
    if self.result then
        self:cancelBossIntro('RunEnded')
        if self.flies then self.flies:close() end
        if self.carry then self.carry:close() end
        if self.clubs then self.clubs:close() end
        if self.dragons then self.dragons:close() end
        return
    end
    self.now=now
    if self.carry then self.carry:step(now) end
    if self.clubs then self.clubs:step(now) end
    if self.flies then self.flies:step(now) end
    if self.dragons then self.dragons:step(now,dt) end
    if self.session.state.status=='Lost' then
        self:cancelBossIntro('RunEnded')
        self.result='Lost'; self.stage='Lost'; self.world:stage('Lost')
        if self.guardian then self.guardian:step(now,0) end
        if self.dragons then self.dragons:close() end
        return
    end
    if self.stage=='Approach' or self.stage=='Courtyard' or self.stage=='Route' then self:_enemies(dt) end
    if self.dragons and self.stage~='Route' and self.stage~='Approach' and self.stage~='Courtyard' then
        for id,e in pairs(self.enemies) do
            if e.kind=='Dragon' and not e.dead then
                local hazard=self.world:hazard(id)
                if hazard then self:_kill(id,hazard)
                else self:_finishReaction(id,e);self.dragons:enemyStep(id,e,dt) end
            end
        end
    end
    if self.stage=='BossReady' then self:_boss() end
    if self.stage=='BossIntro' and self.bossIntro and self.bossIntro:step(now)=='Complete' then
        self:_activateBoss(self.bossController)
    end
    if self.stage=='Boss' and self.world:hazard(-99) then self:_kill(-99) end
    if self.stage=='Boss' or next(self.projectiles) then self:_projectiles(math.min(math.max(dt or 0,0),.1)) end
    if self.stage=='Exit' then
        for _,id in ipairs(self.session.order) do
            if self.session.state.heroes[id].status=='Alive' and not self.session.combat[id].deathAt and self.world:atExit(id) then
                self.result='Won'; self.stage='Won'; self.world:stage('Won')
                if self.flies then self.flies:close() end
                if self.carry then self.carry:close() end
                if self.clubs then self.clubs:close() end
                if self.dragons then self.dragons:close() end
                break
            end
        end
    end
end
function Director:snapshot()
    local enemies={}
    for id,e in pairs(self.enemies) do
        enemies[#enemies+1]={id=id,hearts=e.health,maxHearts=e.boss and self.config.Boss.hits or self.config.Enemy.hearts,
            dead=e.dead==true,attacking=e.windup~=nil,zoneIndex=e.zoneIndex,kind=e.kind,
            reactionEpoch=e.reactionEpoch or 0,movementMode=self.world.movementMode and self.world:movementMode(id) or nil,
            carryState=self.carry and self.carry:stateFor(id),dragonMode=self.dragons and self.dragons.states[id] and self.dragons.states[id].mode}
    end
    table.sort(enemies,function(a,b) return a.id>b.id end)
    local zone=self.route and self.route.zones[self.zoneIndex]
    local objective=objectives[self.stage]
    if self.route and self.stage=='Route' then objective=zone.objective
    elseif self.route and self.stage=='Boss' then objective="Dodge. Pick up a heavy ball and throw it at the Guardian." end
    local variation=self.route and self.route.variation
    return {stage=self.stage,objective=objective,enemies=enemies,bossHits=self.bossHits,
        bossMax=self.config.Boss.hits,result=self.result,zoneIndex=self.zoneIndex,zoneCount=self.route and #self.route.zones,
        zoneName=zone and zone.name,bossMechanic=self.route and 'PickupThrow',bossRawLife=self.enemies[-99] and self.enemies[-99].rawLife,
        healingFlies=self.flies and self.flies:snapshot(),bossIntro=self.bossIntro and self.bossIntro:snapshot(),
        variation=variation and {version=variation.version,seed=variation.seed,sectionChoices=table.clone(variation.sectionChoices)}}
end
return Director
