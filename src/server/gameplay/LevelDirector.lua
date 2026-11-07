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
    Boss='Отбейте ударом три снаряда обратно в стража',Exit='Путь открыт — доберитесь до светящихся ворот',
    Won='Тракт пройден',Lost='Команда выбыла'}

function Director.new(session,world,Combat,config)
    local profile=config.Attacks[config.Enemy.attack]
    local self=setmetatable({session=session,world=world,config=config,enemies={},projectiles={},byUserId={},ownerNames={},
        stage='Approach',now=session.now or 0,bossHits=0,serial=0,
        strikeProfile={reach=config.Enemy.range+1,width=profile.width,height=profile.height}},Director)
    self:_wave('Approach',{{id=-1,x=-24,z=-6},{id=-2,x=-18,z=7}})
    return self
end
function Director:_wave(stage,roster)
    self.stage=stage; self.world:stage(stage)
    for _,r in ipairs(roster) do
        assert(self.world:spawnEnemy(r.id,'Drone',{x=r.x,y=3,z=r.z}),'Enemy spawn failed')
        local actorId=self.session.state.runId..':enemy:'..self.session.state.levelEpoch..':'..r.id
        self.enemies[r.id]={health=self.config.Enemy.hearts,nextAttack=self.now,engaged=false,
            actorId=actorId,name='Ржавый дозорный'}
        self.world:enemyIdentity(r.id,actorId)
        self.world:enemyHealth(r.id,self.config.Enemy.hearts,self.config.Enemy.hearts)
    end
end
function Director:claim(userId,enemyId)
    local owned=self.byUserId[userId]
    if owned then
        if self.enemies[owned].dead then return 'ENEMY_LIFE_SPENT' end
        if owned==enemyId then return 'OK' end
        return 'ENEMY_ALREADY_OWNED'
    end
    if self.result or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    local e=self.enemies[enemyId]
    if not e then return 'UNKNOWN_ENEMY' end
    if not e.dead and self.world:hazard(enemyId) then self:_kill(enemyId) end
    if e.dead then return 'ENEMY_DEAD' end
    if e.ownerUserId then return 'ENEMY_OCCUPIED' end
    if e.engaged then return 'ENEMY_ENGAGED' end
    e.ownerUserId=userId; e.connected=true; e.connectionEpoch=1; e.lastSeq=0
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
        maxHearts=self.config.Enemy.hearts,template='Sentry',name=e.name}
end
function Director:available(userId)
    local offers={}
    if self.byUserId[userId] or self.result or self.session.state.status~='Active' then return offers end
    for id,e in pairs(self.enemies) do
        if not e.dead and not e.engaged and not e.ownerUserId and not self.world:hazard(id) then
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
    if payload.runId~=self.session.state.runId then return 'WRONG_RUN' end
    if self.result or self.session.state.status~='Active' then return 'RUN_CLOSED' end
    if not e.connected then return 'OFFLINE' end
    if e.dead then return 'NOT_ALIVE' end
    if payload.actorId~=e.actorId or payload.attempt~=1 or payload.levelEpoch~=self.session.state.levelEpoch then return 'STALE_ACTOR' end
    if payload.connectionEpoch~=e.connectionEpoch then return 'STALE_CONNECTION' end
    if payload.seq<=e.lastSeq then return 'STALE_SEQUENCE' end
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now; e.lastSeq=payload.seq
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
function Director:_beginStrike(id,e)
    e.engaged=true; e.windup={at=self.now+self.config.Enemy.windup}
    self.world:move(id,0,0); self.world:cue(id,true)
end
function Director:_resolveStrike(id,e)
    e.windup=nil; e.nextAttack=self.now+self.config.Enemy.cooldown
    for _,target in ipairs(self.world:targets(id,self.strikeProfile)) do
        local hit=false
        if self.enemies[target] then hit=self:hit(id,target,self.config.Enemy.attack)
        elseif self.session.state.heroes[target] then hit=self.session:_hit(id,target,self.config.Enemy.attack) end
        if hit then break end
    end
end
function Director:_boss()
    self.stage='Boss'; self.world:stage('Boss')
    assert(self.world:spawnEnemy(-99,'Boss',{x=82,y=3,z=0}),'Boss spawn failed')
    self.world:enemyHealth(-99,self.config.Boss.hits,self.config.Boss.hits)
    self.nextShot=self.now+1.8
end
function Director:isTarget(id)
    return self.enemies[id]~=nil or self.projectiles[id]~=nil or id==-99
end
function Director:_kill(id)
    local e=self.enemies[id]
    if not e or e.dead then return end
    e.dead=true; e.windup=nil; e.health=0
    self.world:enemyHealth(id,0,self.config.Enemy.hearts)
    self.world:kill(id)
end
function Director:hit(attacker,target,action)
    if self.result then return false end
    local ball=self.projectiles[target]
    if ball then
        if ball.reflected then return false end
        ball.reflected=true
        ball.reflectedAt=self.now
        self.world:projectile(target,ball.position,true)
        self.world:cue(attacker,false)
        return true
    end
    if target==-99 and self.stage=='Boss' then self.world:cue(-99,true); return true end
    local e=self.enemies[target]
    if not e or e.dead or (e.reactionUntil and self.now<e.reactionUntil) then return false end
    e.engaged=true; e.windup=nil
    e.health=math.max(0,e.health-(action=='Dash' and self.config.Enemy.dashDamage or self.config.Enemy.punchDamage))
    self.world:enemyHealth(target,e.health,self.config.Enemy.hearts)
    self.world:cue(target,false)
    if e.health==0 then self:_kill(target)
    else
        e.reactionUntil=self.now+self.config.Enemy.reaction
        self.world:move(target,0,0); self.world:setReaction(target,true)
        local profile=action=='Dash' and 22 or 18
        if self.config.Impulses then self.world:impulse(target,attacker,self.config.Impulses[profile],profile) end
    end
    return true
end
function Director:_nearest(position)
    local selected,best=nil,math.huge
    for _,id in ipairs(self.session.order) do
        local h=self.session.state.heroes[id]
        if h.status=='Alive' and not self.session.combat[id].deathAt then
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
            if self.world:hazard(id) then self:_kill(id)
            else
                living+=1
                if e.reactionUntil and self.now>=e.reactionUntil then
                    e.reactionUntil=nil; self.world:setReaction(id,false)
                end
                if not e.reactionUntil then
                    if e.windup then
                        self.world:move(id,0,0)
                        if self.now>=e.windup.at then self:_resolveStrike(id,e) end
                    elseif e.ownerUserId then
                        if e.lastMove and self.now-e.lastMove>=(self.config.MoveTimeout or .35) then
                            e.lastMove=nil; self.world:move(id,0,0)
                        end
                    else
                        local target,range=self:_nearest(self.world:position(id))
                        if target and range<=self.config.Enemy.range and self.now>=e.nextAttack then
                            self.world:face(id,target); self:_beginStrike(id,e)
                        elseif target and range>self.config.Enemy.range*.8 then
                            self.world:enemyMove(id,target,self.config.Enemy.speed)
                        else self.world:move(id,0,0) end
                    end
                end
            end
        end
    end
    if living==0 then
        if self.stage=='Approach' then self:_wave('Courtyard',{{id=-3,x=22,z=-7},{id=-4,x=30,z=6}})
        elseif self.stage=='Courtyard' then self:_boss() end
    end
end
function Director:_projectiles(dt)
    if self.stage=='Boss' and self.now>=self.nextShot then
        local target,range=self:_nearest(self.world:position(-99))
        if target and range<=self.config.Boss.aggroRange then
            self.world:face(-99,target); self.world:cue(-99,true)
            local origin=self.world:position(-99)
            local destination=self.world:position(target)
            self.serial+=1
            local id=-1000-self.serial
            local start=towards(origin,destination,5)
            self.projectiles[id]={position=start,direction=destination,created=self.now,target=target,reflected=false}
            self.world:projectile(id,start,false)
        end
        self.nextShot=self.now+self.config.Boss.interval
    end
    local remove={}
    for id,p in pairs(self.projectiles) do
        local destination=p.reflected and self.world:position(-99) or p.direction
        if not destination or self.now-(p.reflectedAt or p.created)>self.config.Boss.projectileLife then remove[#remove+1]=id
        else
            local speed=p.reflected and self.config.Boss.returnSpeed or self.config.Boss.projectileSpeed
            p.position=towards(p.position,destination,speed*dt)
            self.world:projectile(id,p.position,p.reflected)
            if p.reflected and self.stage=='Boss' and distance(p.position,destination)<2.5 then
                self.bossHits+=1; self.world:cue(-99,false)
                self.world:enemyHealth(-99,self.config.Boss.hits-self.bossHits,self.config.Boss.hits)
                remove[#remove+1]=id
                if self.bossHits>=self.config.Boss.hits then
                    self.world:kill(-99); self.stage='Exit'; self.world:stage('Exit')
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
    if self.result then return end
    self.now=now
    if self.session.state.status=='Lost' then
        self.result='Lost'; self.stage='Lost'; self.world:stage('Lost'); return
    end
    if self.stage=='Approach' or self.stage=='Courtyard' then self:_enemies() end
    if self.stage=='Boss' or next(self.projectiles) then self:_projectiles(math.min(math.max(dt or 0,0),.1)) end
    if self.stage=='Exit' then
        for _,id in ipairs(self.session.order) do
            if self.session.state.heroes[id].status=='Alive' and not self.session.combat[id].deathAt and self.world:atExit(id) then
                self.result='Won'; self.stage='Won'; self.world:stage('Won'); break
            end
        end
    end
end
function Director:snapshot()
    local enemies={}
    for id,e in pairs(self.enemies) do
        enemies[#enemies+1]={id=id,hearts=e.health,maxHearts=self.config.Enemy.hearts,dead=e.dead==true,attacking=e.windup~=nil}
    end
    table.sort(enemies,function(a,b) return a.id>b.id end)
    return {stage=self.stage,objective=objectives[self.stage],enemies=enemies,bossHits=self.bossHits,
        bossMax=self.config.Boss.hits,result=self.result}
end
return Director
