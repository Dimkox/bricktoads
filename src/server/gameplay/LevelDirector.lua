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
local objectives={Approach='Разбейте дозор у старых ворот',Courtyard='Освободите внутренний двор',
    BossReady='Назначаем стража: ожидаем ответ приглашённого игрока',
    Boss='Отбейте ударом три снаряда обратно в стража',Exit='Путь открыт — доберитесь до светящихся ворот',
    Won='Тракт пройден',Lost='Команда выбыла'}

function Director.new(session,world,Combat,config,GuardianPattern,HealingFlies,EnemyCarry,WalkerClubs)
    local profile=config.Attacks[config.Enemy.attack]
    local self=setmetatable({session=session,world=world,config=config,enemies={},projectiles={},byUserId={},ownerNames={},
        stage='Approach',now=session.now or 0,bossHits=0,serial=0,route=config.Level,GuardianPattern=GuardianPattern,
        strikeProfile={reach=config.Enemy.range+1,width=profile.width,height=profile.height,
            windup=config.Enemy.windup,cooldown=config.Enemy.cooldown,recoveryPose=.17},random=math.random},Director)
    if self.route then
        self.flies=HealingFlies and HealingFlies.new(session,world,config)
        self.carry=EnemyCarry and EnemyCarry.new(self)
        self.clubs=WalkerClubs and WalkerClubs.new(self)
        self:_enterZone(1)
    else self:_wave('Approach',{{id=-1,x=-24,z=-6},{id=-2,x=-18,z=7}}) end
    return self
end
function Director:_wave(stage,roster)
    self.stage=stage; self.world:stage(stage)
    for _,r in ipairs(roster) do
        assert(self.world:spawnEnemy(r.id,r.kind or 'Drone',{x=r.x,y=r.y or 3,z=r.z}),'Enemy spawn failed')
        local actorId=self.session.state.runId..':enemy:'..self.session.state.levelEpoch..':'..r.id
        self.enemies[r.id]={health=self.config.Enemy.hearts,nextAttack=self.now,engaged=false,
            actorId=actorId,zoneIndex=self.zoneIndex,kind=r.kind,
            name=({Pig='Болотный налётчик',Walker='Длинноногий дозорный',Dragon='Крылатый разведчик'})[r.kind] or 'Ржавый дозорный'}
        self.world:enemyIdentity(r.id,actorId)
        self.world:enemyHealth(r.id,self.config.Enemy.hearts,self.config.Enemy.hearts)
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
    if self.clubs then
        local result=self.clubs:interact(slot,now,attack)
        if result~='NO_INTERACTION' then return result end
    end
    return self.carry and self.carry:interact(slot,now,attack) or 'NO_INTERACTION'
end
function Director:claim(userId,enemyId)
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
    self.byUserId[userId]=enemyId
    self.world:move(enemyId,0,0)
    self.world:enemyIdentity(enemyId,e.actorId,self.ownerNames[userId])
    return 'OK'
end
function Director:connection(userId,connected)
    local id=self.byUserId[userId]; local e=id and self.enemies[id]
    if not e then return 'UNKNOWN_ENEMY' end
    if type(connected)~='boolean' then return 'INVALID_CONNECTION' end
    if e.connected==connected then return 'NO_CHANGE' end
    e.connected=connected; e.connectionEpoch+=1; e.lastSeq=0; e.lastMove=nil
    self.world:move(id,0,0)
    return 'OK'
end
function Director:controlled(userId)
    local id=self.byUserId[userId]; local e=id and self.enemies[id]
    if not e then return nil end
    return {enemyId=id,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,
        connected=e.connected,status=e.dead and 'Dead' or 'Alive',hearts=e.health,
        maxHearts=e.boss and self.config.Boss.hits or self.config.Enemy.hearts,
        template=e.boss and 'Boss' or 'Sentry',name=e.name,carryState=self.carry and self.carry:stateFor(id)}
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
    if payload.kind=='Move' then
        e.lastMove=now; self.world:move(id,payload.x,payload.z)
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
    local action=self.config.Enemy.attack
    local tuning=self.strikeProfile
    if self.route and self.config.Pig and e.kind=='Pig' then
        target=target or self:_strikeTarget(id,self.config.Attacks.PigJab)
        local combat=target and self.session.combat[target]
        -- Prototype enemy3HP is not raw source Life; an unknown target uses jab.
        action=e.rushing and 'PigRush' or (combat and combat.rawLife%16<4 and 'PigHeavy' or 'PigJab')
        tuning=self.config.Attacks[action]
    end
    e.engaged=true; e.rushing=nil; e.strikeRecoveryUntil=nil
    e.windup={at=self.now+tuning.windup,action=action,tuning=table.clone(tuning)}
    self.world:move(id,0,0); self.world:cue(id,true)
end
function Director:_resolveStrike(id,e)
    local pending=e.windup
    e.windup=nil; e.nextAttack=self.now+pending.tuning.cooldown
    e.lastStrikeAction=pending.action; e.strikeRecoveryUntil=self.now+pending.tuning.recoveryPose
    for _,target in ipairs(self.world:targets(id,pending.tuning)) do
        local hit=false
        if self.enemies[target] then hit=self:hit(id,target,pending.action)
        elseif self.session.state.heroes[target] then hit=self.session:_hit(id,target,pending.action) end
        if hit then break end
    end
end
function Director:_boss()
    local controller=self.bossGate and self.bossGate(self.now) or {state='NPC'}
    if controller.state=='Waiting' then
        self.stage='BossReady'; self.world:stage('BossReady'); return
    end
    self.stage='Boss'; self.world:stage('Boss')
    if self.clubs then self.clubs:bossIntro() end
    local position=self.route and self.route.boss.position or {x=82,y=3,z=0}
    assert(self.world:spawnEnemy(-99,'Boss',position),'Boss spawn failed')
    local actorId=self.session.state.runId..':boss:'..self.session.state.levelEpoch
    local e={boss=true,actorId=actorId,health=self.config.Boss.hits,rawLife=self.route and self.config.Boss.rawLife,
        zoneIndex=self.zoneIndex,name='Страж переправы',aim={x=-1,z=0}}
    self.enemies[-99]=e
    if controller.state=='Human' then
        e.ownerUserId=controller.userId
        e.connected=self.ownerConnections==nil or self.ownerConnections[controller.userId]~=false
        e.connectionEpoch=1; e.lastSeq=0
        self.byUserId[controller.userId]=-99
    end
    self.world:enemyIdentity(-99,actorId,e.ownerUserId and self.ownerNames[e.ownerUserId])
    self.world:enemyHealth(-99,self.config.Boss.hits,self.config.Boss.hits)
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
    e.dead=true; e.windup=nil; e.rushing=nil; e.strikeRecoveryUntil=nil; e.health=0
    if self.clubs and e.kind=='Walker' then self.clubs:walkerDefeated(id,self.world:position(id),cause) end
    if e.boss and self.route then e.rawLife=0 end
    self.world:enemyHealth(id,0,e.boss and self.config.Boss.hits or self.config.Enemy.hearts)
    self.world:kill(id)
    if e.boss then
        self.stage='Exit'; self.world:stage('Exit')
    end
end
function Director:hit(attacker,target,action)
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
        if self.config.Impulses then
            local profile=action=='Dash' and 22 or 18
            self.world:impulse(-99,attacker,self.config.Impulses[profile],profile)
        end
        return true
    end
    local e=self.enemies[target]
    if not e or e.dead or (e.reactionUntil and self.now<e.reactionUntil) then return false end
    if self.carry then self.carry:forgetEnemy(target) end
    e.reactionEpoch=(e.reactionEpoch or 0)+1
    e.engaged=true; e.windup=nil; e.rushing=nil; e.strikeRecoveryUntil=nil
    local pig=self.config.Pig and self.config.Pig.npcDamage[action]
    local damage=pig or (action=='Club' and self.config.WalkerClub.npcDamage
        or (action=='Dash' and self.config.Enemy.dashDamage or self.config.Enemy.punchDamage))
    e.health=math.max(0,e.health-damage)
    self.world:enemyHealth(target,e.health,self.config.Enemy.hearts)
    self.world:cue(target,false)
    if e.health==0 then self:_kill(target,'Combat')
    else
        local reaction=pig and self.config.Attacks[action].reaction
            or (action=='Club' and self.config.Attacks.Club.reaction or self.config.Enemy.reaction)
        e.reactionUntil=self.now+reaction
        self.world:move(target,0,0); self.world:setReaction(target,true)
        local profile=pig and self.config.Pig.npcProfile[action] or (action=='Club' and 2 or (action=='Dash' and 22 or 18))
        if self.config.Impulses then self.world:impulse(target,attacker,self.config.Impulses[profile],profile) end
    end
    return true
end
function Director:applyThrowDamage(id,heroSlot)
    local e=self.enemies[id]
    if self.result or self.session.state.status~='Active' or not e or e.dead or e.kind~='Pig' then return false end
    local before=e.health
    e.health=math.max(0,e.health-self.config.EnemyCarry.throwDamage)
    e.reactionEpoch=(e.reactionEpoch or 0)+1
    self.world:enemyHealth(id,e.health,self.config.Enemy.hearts);self.world:cue(id,false)
    self.session:_record('EnemyThrowDamage',heroSlot,{enemyId=id,before=before,after=e.health,
        sourceProfile=self.config.EnemyCarry.sourceProfile,sourceRawDamage=self.config.EnemyCarry.sourceRawDamage})
    if e.health==0 then self:_kill(id) end
    return true
end
function Director:_nearest(position,pigEligibility)
    local selected,best=nil,math.huge
    for _,id in ipairs(self.session.order) do
        local h=self.session.state.heroes[id]
        local c=self.session.combat[id]
        if h.status=='Alive' and not c.deathAt
            and (not pigEligibility or not c.reactionEnd or c.recover==true) then
            local d=distance(position,self.world:position(id))
            if d<best then selected,best=id,d end
        end
    end
    return selected,best
end
function Director:_enemies()
    local living=0
    for id,e in pairs(self.enemies) do
        if not e.dead then
            local hazard=self.world:hazard(id)
            if hazard then self:_kill(id,hazard)
            else
                living+=1
                local carried=self.carry and self.carry:blocksEnemy(id)
                if carried then e.rushing=nil; e.strikeRecoveryUntil=nil end
                if not carried and e.reactionUntil and self.now>=e.reactionUntil then
                    e.reactionUntil=nil; self.world:setReaction(id,false)
                end
                if not carried and not e.reactionUntil then
                    if e.windup then
                        self.world:move(id,0,0)
                        if self.now>=e.windup.at then self:_resolveStrike(id,e) end
                    elseif e.ownerUserId then
                        if e.lastMove and self.now-e.lastMove>=(self.config.MoveTimeout or .35) then
                            e.lastMove=nil; self.world:move(id,0,0)
                        end
                    else
                        local target,range=self:_nearest(self.world:position(id),self.route and self.config.Pig and e.kind=='Pig')
                        -- Validate the approach before either melee or movement:
                        -- a newly invalid target cannot preserve an old running hop.
                        if e.rushing then
                            local a,b=self.world:position(id),target and self.world:position(target)
                            local c=target and self.session.combat[target]
                            local alignment=self.config.Pig.alignment
                            if not a or not b or math.abs(a.z-b.z)>alignment or math.abs(a.y-b.y)>alignment
                                or (c and c.reactionEnd) then e.rushing=nil end
                        end
                        if target and range<=self.config.Enemy.range and self.now>=e.nextAttack then
                            self.world:face(id,target); self:_beginStrike(id,e,target)
                        elseif target and range>self.config.Enemy.range*.8 then
                            local speed=self.config.Enemy.speed
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
                        else e.rushing=nil; self.world:move(id,0,0) end
                    end
                end
            end
        end
    end
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
        if self.flies then self.flies:close() end
        if self.carry then self.carry:close() end
        if self.clubs then self.clubs:close() end
        return
    end
    self.now=now
    if self.carry then self.carry:step(now) end
    if self.clubs then self.clubs:step(now) end
    if self.flies then self.flies:step(now) end
    if self.session.state.status=='Lost' then
        self.result='Lost'; self.stage='Lost'; self.world:stage('Lost'); return
    end
    if self.stage=='Approach' or self.stage=='Courtyard' or self.stage=='Route' then self:_enemies() end
    if self.stage=='BossReady' then self:_boss() end
    if self.stage=='Boss' and self.world:hazard(-99) then self:_kill(-99) end
    if self.stage=='Boss' or next(self.projectiles) then self:_projectiles(math.min(math.max(dt or 0,0),.1)) end
    if self.stage=='Exit' then
        for _,id in ipairs(self.session.order) do
            if self.session.state.heroes[id].status=='Alive' and not self.session.combat[id].deathAt and self.world:atExit(id) then
                self.result='Won'; self.stage='Won'; self.world:stage('Won')
                if self.flies then self.flies:close() end
                if self.carry then self.carry:close() end
                if self.clubs then self.clubs:close() end
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
            carryState=self.carry and self.carry:stateFor(id)}
    end
    table.sort(enemies,function(a,b) return a.id>b.id end)
    local zone=self.route and self.route.zones[self.zoneIndex]
    local objective=objectives[self.stage]
    if self.route and self.stage=='Route' then objective=zone.objective
    elseif self.route and self.stage=='Boss' then objective='Уклоняйтесь. Возьмите тяжёлый шар и бросьте в стража.' end
    return {stage=self.stage,objective=objective,enemies=enemies,bossHits=self.bossHits,
        bossMax=self.config.Boss.hits,result=self.result,zoneIndex=self.zoneIndex,zoneCount=self.route and #self.route.zones,
        zoneName=zone and zone.name,bossMechanic=self.route and 'PickupThrow',bossRawLife=self.enemies[-99] and self.enemies[-99].rawLife,
        healingFlies=self.flies and self.flies:snapshot()}
end
return Director
