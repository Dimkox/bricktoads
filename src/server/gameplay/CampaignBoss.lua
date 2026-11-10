-- Original 3D encounters. Source byte arithmetic, C0/80 Life thresholds and
-- 0583 reaction progress are measured; seconds/studs, move bindings and attack
-- vulnerability windows are Roblox tuning (research/2026-11-09-campaign-bosses.md).
-- Session owns hero shields, damage, death and respawn. This object owns no hero resources.
local Boss={}
Boss.__index=Boss
local profiles={
    BigBlag={life=255,first='Hop',second='BellyDrop',name='Big Blag'},
    RoboManus={life=15,progress=true,first='Burst',second='Jump',name='Robo-Manus'},
    GeneralSlaughter={life=255,progress=true,first='Charge',second='Headbutt',name='General Slaughter'},
    Buzzball={life=207,first='Roll',second='Bounce',name='Buzzball'},
    DarkQueen={life=15,progress=true,first='Sweep',second='Spin',name='Dark Queen'},
}
local moves={
    Hop={tell=.55,active=.65,recovery=.8,radius=5,lift=6,damage='PigHeavy'},
    BellyDrop={tell=.8,active=.85,recovery=1.05,radius=7,lift=12,damage='WalkerHeavy'},
    Burst={tell=.45,active=.55,recovery=.8,shots=3,damage='DragonFire'},
    Jump={tell=.65,active=.8,recovery=.9,radius=6,lift=10,damage='WalkerHeavy'},
    Charge={tell=.65,active=.75,recovery=1.0,speed=38,radius=3.2,damage='PigRush'},
    Headbutt={tell=.35,active=.2,recovery=.65,reach=7,width=3.5,height=4,damage='PigHeavy'},
    Roll={tell=.45,active=1.0,recovery=.85,speed=32,radius=3,damage='DragonHeadbutt'},
    Bounce={tell=.55,active=.85,recovery=.8,radius=5.5,lift=9,damage='DragonFire'},
    Sweep={tell=.4,active=.25,recovery=.7,reach=8,width=4,height=4,damage='WalkerHeavy'},
    Spin={tell=.7,active=1.8,recovery=1.1,radius=3.2,orbit=8,damage='PigRush'},
}
local damageByAction={Punch=2,HeroJab=2,HeroKick=8,HeroUppercut=16,HeroPowerPunch=255,HeroBoot=255,HeroElbow=8,
    Club=16,PigJab=2,PigHeavy=16,PigRush=16,WalkerLight=2,WalkerHeavy=16,
    DragonHeadbutt=16,DragonFire=16,EnemyThrow=4,EnemyRunStrike=16}
local responseByAction={Punch=0,HeroJab=0,HeroKick=1,HeroUppercut=2,HeroPowerPunch=3,HeroBoot=6,HeroElbow=10,
    Club=2,PigJab=0,PigHeavy=2,PigRush=4,WalkerLight=0,WalkerHeavy=2,
    DragonHeadbutt=4,DragonFire=4,EnemyRunStrike=4}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function point(p) return type(p)=='table' and finite(p.x) and finite(p.y) and finite(p.z) end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b)
    if not point(a) or not point(b) then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function segmentDistance(a,b,p)
    if not point(a) or not point(b) or not point(p) then return math.huge end
    local x,y,z=b.x-a.x,b.y-a.y,b.z-a.z;local length=x*x+y*y+z*z
    local t=length>0 and math.clamp(((p.x-a.x)*x+(p.y-a.y)*y+(p.z-a.z)*z)/length,0,1) or 0
    return distance({x=a.x+t*x,y=a.y+t*y,z=a.z+t*z},p)
end
local function aimVector(aim)
    if type(aim)~='table' or not finite(aim.x) or not finite(aim.z) then return nil end
    local length=math.sqrt(aim.x^2+aim.z^2)
    if not finite(length) or length<.001 then return nil end
    return {x=aim.x/length,z=aim.z/length}
end
local function byteDamage(raw,damage)
    if raw<damage then return 0,true end
    local after=raw-damage
    if math.floor(after/16)~=math.floor(raw/16) then after=math.floor(after/16)*16+15 end
    return after,false
end

function Boss.new(session,world,config,definition)
    local authored=definition.boss or {};local profile=assert(profiles[authored.type],'Unknown campaign boss')
    local now=session.now or 0;local origin=authored.position or {x=0,y=3,z=0}
    assert(point(origin),'Boss position must be finite')
    local gate=definition.bossGate or {};local actorId=session.state.runId..':boss:'..session.state.levelEpoch..':'..authored.type
    local arena=definition.arena
    local platform=authored.platform
    if not arena and type(platform)=='table' and finite(platform.x) and finite(platform.z)
        and finite(platform.w) and finite(platform.d) and platform.w>6 and platform.d>6 then
        arena={minX=platform.x-platform.w/2+3,maxX=platform.x+platform.w/2-3,
            minZ=platform.z-platform.d/2+3,maxZ=platform.z+platform.d/2-3}
    end
    local enemy={boss=true,kind=authored.type,name=profile.name,actorId=actorId,rawLife=profile.life,
        maxRawLife=profile.life,health=profile.life,maxHealth=profile.life,progress=profile.progress and 0 or nil,
        ownerUserId=gate.ownerUserId,connected=gate.connected~=false,connectionEpoch=gate.connectionEpoch or 1,lastSeq=0,dead=false}
    local self=setmetatable({session=session,world=world,config=config,definition=definition,profile=profile,
        kind=authored.type,enemies={[-99]=enemy},projectiles={},byUserId={},now=now,serial=0,attackSerial=0,
        state=authored.type=='Buzzball' and authored.chaseComplete~=true and 'Chase' or 'Ready',readyAt=now+.5,
        origin=copy(origin),arena=arena or {},defeated=false,ownerName=gate.ownerName},Boss)
    if gate.ownerUserId then self.byUserId[gate.ownerUserId]=-99 end
    assert(world:spawnEnemy(-99,authored.type,origin),'Campaign boss spawn failed')
    -- Campaign bosses accept ordinary human movement between attacks. The
    -- stationary first guardian uses a different constructor and keeps its cap.
    if world.campaignWalkSpeed then world:campaignWalkSpeed(-99,config.Enemy.speed) end
    if world.enemyIdentity then world:enemyIdentity(-99,actorId,gate.ownerName) end
    self:_health();self:_log('CampaignBossSpawned',{bossType=self.kind,rawLife=enemy.rawLife,progress=enemy.progress})
    return self
end
function Boss:_log(kind,data)
    if self.session._record then self.session:_record(kind,-99,data,self.now) end
end
function Boss:_active() return not self.closed and not self.defeated and self.session.state.status=='Active' end
function Boss:_health()
    local e=self.enemies[-99];e.health=e.rawLife
    self.world:enemyHealth(-99,e.rawLife,e.maxRawLife)
end
function Boss:_phase()
    local e=self.enemies[-99]
    if self.kind=='BigBlag' then return e.rawLife>=192 and 1 or e.rawLife>=128 and 2 or 3 end
    if self.kind=='Buzzball' then return e.rawLife>=128 and 1 or 2 end
    return (e.progress or 0)>=120 and 2 or 1
end
function Boss:_bound(p)
    local a=self.arena;local o=self.origin
    return {x=math.clamp(p.x,a.minX or o.x-28,a.maxX or o.x+28),y=p.y,
        z=math.clamp(p.z,a.minZ or o.z-22,a.maxZ or o.z+22)}
end
function Boss:_contain()
    -- The source encounter is camera/arena locked. Constrain the boss body in
    -- every combat state, including physical knockback, so a reaction cannot
    -- strand it beneath its finite authored platform. Chase owns another route.
    if self.state=='Chase' then return end
    local p=self.world:position(-99);if not point(p) then return end
    local bounded=self:_bound(p);bounded.y=math.max(p.y,self.origin.y)
    if distance(p,bounded)>.001 then self.world:placeActor(-99,bounded) end
end
function Boss:_targets()
    local ids={}
    for _,id in ipairs(self.session.order) do
        local h=self.session.state.heroes[id];local c=self.session.combat[id]
        if h and h.status=='Alive' and c and not c.deathAt and point(self.world:position(id)) then ids[#ids+1]=id end
    end
    for id,e in pairs(self.externalEnemies or {}) do
        if id~=-99 and not e.dead and point(self.world:position(id)) then ids[#ids+1]=id end
    end
    table.sort(ids);return ids
end
function Boss:_nearest()
    local origin=self.world:position(-99);local selected,best=nil,math.huge
    for _,id in ipairs(self:_targets()) do
        local range=distance(origin,self.world:position(id))
        if range<best then selected,best=id,range end
    end
    return selected,best
end
function Boss:_finishReaction()
    if finite(self.session.now) then self.now=math.max(self.now,self.session.now) end
    if not self:_active() or self.state~='Reaction' or self.now<self.reactionUntil then return false end
    local e=self.enemies[-99];e.rawLife=math.floor(e.rawLife/8)*8+7
    self.state='Ready';self.reactionUntil=nil;self.lightReaction=nil;self.heavyReaction=nil;self.readyAt=self.now+.25
    if self.world.setReaction then self.world:setReaction(-99,false) end;self:_health()
    return true
end
function Boss:canMove(now)
    if now~=nil then
        if not finite(now) or now<self.now then return false end
        self.now=now
    end
    self:_finishReaction()
    return self:_active() and self.state=='Ready'
end
function Boss:_damage(target,action,hitSet,tuning)
    if hitSet[target] then return end
    hitSet[target]=true
    tuning=tuning or self.config.Attacks[action] or self.config.Attacks.Dash
    if self.session.state.heroes[target] then self.session:_hit(-99,target,action,tuning)
    elseif self.enemyHit then self.enemyHit(-99,target,action,tuning) end
end
function Boss:_sweep(before,after,radius,attack)
    for _,id in ipairs(self:_targets()) do
        if segmentDistance(before,after,self.world:position(id))<=radius then self:_damage(id,attack.move.damage,attack.hits) end
    end
end
function Boss:_radial(center,radius,attack)
    for _,id in ipairs(self:_targets()) do
        local p=self.world:position(id)
        if math.abs(p.y-center.y)<=3.5 and (p.x-center.x)^2+(p.z-center.z)^2<=radius^2 then
            self:_damage(id,attack.move.damage,attack.hits)
        end
    end
end
function Boss:_melee(attack)
    local p=self.world:position(-99);local m=attack.move
    for _,id in ipairs(self:_targets()) do
        local q=self.world:position(id);local x,z=q.x-p.x,q.z-p.z
        local forward=x*attack.aim.x+z*attack.aim.z;local side=x*attack.aim.z-z*attack.aim.x
        if forward>=0 and forward<=m.reach and math.abs(side)<=m.width and math.abs(q.y-p.y)<=m.height then
            self:_damage(id,m.damage,attack.hits)
        end
    end
end
function Boss:_removeProjectile(id)
    if not self.projectiles[id] then return end
    self.projectiles[id]=nil;self.world:removeProjectile(id)
end
function Boss:_clearProjectiles()
    local ids={};for id in pairs(self.projectiles) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do self:_removeProjectile(id) end
end
function Boss:_projectile(attack,at,index)
    self.serial+=1;local id=-4001-self.serial*2;local origin=copy(self.world:position(-99))
    local angle=(index-2)*.10;local c,s=math.cos(angle),math.sin(angle)
    local aim={x=attack.aim.x*c-attack.aim.z*s,z=attack.aim.x*s+attack.aim.z*c}
    -- The accepted bolt keeps its own response and spread direction even if
    -- its controller turns, disconnects or starts another attack before impact.
    local tuning=table.clone(self.config.Attacks[attack.move.damage] or self.config.Attacks.Dash)
    tuning.impulseDirection={x=aim.x,z=aim.z}
    local p={position=origin,direction=aim,created=at,lastAt=at,expiresAt=at+2.5,action=attack.move.damage,
        tuning=tuning,hits={},attackSerial=attack.serial}
    self.projectiles[id]=p;self.world:projectile(id,p.position,false,'RoboBolt')
end
function Boss:_projectiles(now)
    local ids={};for id in pairs(self.projectiles) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do
        local p=self.projectiles[id];local duration=math.max(0,math.min(now,p.expiresAt)-p.lastAt)
        local before=p.position
        local after={x=before.x+p.direction.x*42*duration,y=before.y,z=before.z+p.direction.z*42*duration}
        local best,bestDistance=nil,math.huge
        for _,target in ipairs(self:_targets()) do
            local q=self.world:position(target)
            if segmentDistance(before,after,q)<=2.1
                and not (self.world.campaignProjectileBlocked and self.world:campaignProjectileBlocked(before,q)) then
                local d=distance(before,q);if d<bestDistance then best,bestDistance=target,d end
            end
        end
        if best then self:_damage(best,p.action,p.hits,p.tuning);self:_removeProjectile(id)
        elseif now>=p.expiresAt or self.world.campaignProjectileBlocked and self.world:campaignProjectileBlocked(before,after) then self:_removeProjectile(id)
        else p.position=after;p.lastAt=now;self.world:projectile(id,after,false,'RoboBolt') end
    end
end
function Boss:_begin(name,aim,target)
    if not self:_active() then return 'RUN_CLOSED' end
    if self.state~='Ready' then return 'COOLDOWN' end
    local origin=self.world:position(-99);if not point(origin) then return 'NO_TARGET' end
    local direction=aimVector(aim)
    if aim~=nil and not direction then return 'INVALID_AIM' end
    if not direction then
        target=target or self:_nearest();local p=target and self.world:position(target)
        if not point(p) then return 'NO_TARGET' end
        direction=aimVector({x=p.x-origin.x,z=p.z-origin.z}) or {x=1,z=0}
    end
    local m=moves[name];local destination
    if target then destination=copy(self.world:position(target))
    else destination={x=origin.x+direction.x*12,y=origin.y,z=origin.z+direction.z*12} end
    destination.y=origin.y;destination=self:_bound(destination)
    self.attackSerial+=1
    self.attack={name=name,move=m,aim=direction,target=target,origin=copy(origin),destination=destination,
        tellAt=self.now+m.tell,activeUntil=self.now+m.tell+m.active,
        recoveryUntil=self.now+m.tell+m.active+m.recovery,hits={},shots=0,serial=self.attackSerial,lastAt=self.now+m.tell}
    self.state='Tell';self.enemies[-99].engaged=true;self.lastMove=nil
    if self.world.move then self.world:move(-99,0,0) end
    if self.world.aim then self.world:aim(-99,direction.x,direction.z) end
    if target and self.world.face then self.world:face(-99,target) end
    self.world:cue(-99,true)
    if self.world.bossTell then self.world:bossTell(name,destination,m.radius or m.reach or 3,self.attack.tellAt) end
    self:_log('CampaignBossAttack',{bossType=self.kind,attack=name,serial=self.attackSerial,phase=self:_phase(),effectAt=self.attack.tellAt})
    return 'OK'
end
function Boss:command(action,aim,now)
    if now~=nil then
        if not finite(now) or now<0 then return 'INVALID_TIME' end
        if now<self.now then return 'TIME_REVERSED' end
        self.now=now
    elseif finite(self.session.now) then self.now=math.max(self.now,self.session.now) end
    if not self:_active() then return 'RUN_CLOSED' end
    local e=self.enemies[-99]
    if e.ownerUserId and not e.connected then return 'OFFLINE' end
    if action~='Punch' and action~='Dash' then return 'INVALID_ACTION' end
    self:_finishReaction()
    return self:_begin(self:_chooseAttack(action),aim)
end
function Boss:_chooseAttack(action)
    if action=='Dash' then return self.profile.second end
    if self.kind=='BigBlag' and self:_phase()==1 then return 'Hop' end
    return self.attackSerial%2==0 and self.profile.first or self.profile.second
end
function Boss:_motion(attack,at)
    local m=attack.move;local t=math.clamp((at-attack.tellAt)/m.active,0,1);local p
    if m.lift then
        p={x=attack.origin.x+(attack.destination.x-attack.origin.x)*t,
            y=attack.origin.y+math.sin(t*math.pi)*m.lift,z=attack.origin.z+(attack.destination.z-attack.origin.z)*t}
    elseif m.speed then
        local speed=m.speed*(self:_phase()==2 and self.kind=='GeneralSlaughter' and 1.2 or 1)
        p={x=attack.origin.x+attack.aim.x*speed*(at-attack.tellAt),y=attack.origin.y,
            z=attack.origin.z+attack.aim.z*speed*(at-attack.tellAt)}
    elseif m.orbit then
        p={x=attack.origin.x+math.sin(t*math.pi*4)*m.orbit,y=attack.origin.y,
            z=attack.origin.z+(1-math.cos(t*math.pi*4))*m.orbit*.5}
    else return copy(self.world:position(-99)) end
    return self:_bound(p)
end
function Boss:_attackStep(now)
    local a=self.attack;if not a then return end
    if self.state=='Tell' and now>=a.tellAt then self.state='Active';self.world:cue(-99,false) end
    if self.state=='Active' then
        local m=a.move;local untilAt=math.min(now,a.activeUntil)
        if m.shots then
            for index=a.shots+1,m.shots do
                local at=a.tellAt+(index-1)*.18
                if at>untilAt then break end
                self:_projectile(a,at,index);a.shots=index
            end
        elseif m.reach then self:_melee(a)
        elseif m.orbit then
            -- Curved spin is subdivided, so a coarse frame cannot cut through
            -- the orbit and strike a target the actual path never crossed.
            local cursor=a.lastAt
            while cursor<untilAt do
                local nextAt=math.min(untilAt,cursor+.05)
                local before=self:_motion(a,cursor);local after=self:_motion(a,nextAt)
                self:_sweep(before,after,m.radius,a);cursor=nextAt
            end
            self.world:placeActor(-99,self:_motion(a,untilAt))
        elseif m.speed then
            local before=self:_motion(a,a.lastAt);local after=self:_motion(a,untilAt)
            self:_sweep(before,after,m.radius,a);self.world:placeActor(-99,after)
        elseif m.lift then self.world:placeActor(-99,self:_motion(a,untilAt)) end
        a.lastAt=untilAt
        if now>=a.activeUntil then
            if m.lift then self:_radial(a.destination,m.radius,a) end
            self.state='Recovery';self.world:cue(-99,false)
        end
    end
    if self.state=='Recovery' and now>=a.recoveryUntil then
        self.state='Ready';self.attack=nil;self.readyAt=now+.25
    end
end
function Boss:_defeat()
    if self.defeated then return end
    self.defeated=true;self.state='Defeated';self.attack=nil;self.lastMove=nil
    local e=self.enemies[-99];e.dead=true;e.rawLife=0;self:_health();self:_clearProjectiles()
    self.world:cue(-99,false);if self.world.kill then self.world:kill(-99) end
    self:_log('CampaignBossDefeated',{bossType=self.kind,progress=e.progress})
end
function Boss:hit(attacker,target,action,tuning)
    self:_finishReaction()
    if target~=-99 or attacker==-99 or not self:_active()
        or self.state~='Ready' and self.state~='Recovery' and not (self.state=='Reaction' and self.lightReaction) then return false end
    local origin=self.world:position(attacker);local destination=self.world:position(-99)
    local cfg=self.config.Attacks[action];local damage=damageByAction[action]
    if action=='Dash' then damage=self.enemies[-99].rawLife<16 and 255 or 16 end
    if not cfg or not damage or not point(origin) or not point(destination) then return false end
    local geometry=tuning or cfg
    -- Only server projectile collision code supplies this contact point. Public
    -- intents cannot carry tuning, target IDs or collision coordinates.
    local impact=tuning and tuning.impactPosition
    local reach=finite(geometry.reach) and geometry.reach or cfg.reach or 6
    local height=finite(geometry.height) and geometry.height or cfg.height or 4
    if impact~=nil then
        if not point(impact) or distance(impact,destination)>2.5 then return false end
    elseif distance(origin,destination)>reach+1 or math.abs(origin.y-destination.y)>height then return false end
    if impact==nil and self.world.targets then
        local visible=false
        for _,id in ipairs(self.world:targets(attacker,geometry)) do if id==-99 then visible=true;break end end
        if not visible then return false end
    end
    local hero=self.session.state.heroes[attacker];local enemy=self.externalEnemies and self.externalEnemies[attacker]
    if hero then
        local c=self.session.combat[attacker]
        if hero.status~='Alive' or not c or c.deathAt then return false end
    elseif not enemy or enemy.dead and impact==nil then return false end
    local e=self.enemies[-99];local before=e.rawLife;local after,underflow=byteDamage(before,damage)
    e.rawLife=after
    self:_log('CampaignBossHit',{attacker=attacker,action=action,before=before,after=after,underflow=underflow,progress=e.progress})
    if underflow and (not self.profile.progress or e.progress>=240) then self:_defeat();return true end
    if underflow then e.progress+=12 end
    self.attack=nil;self.state='Reaction';self.lightReaction=damage==2;self.heavyReaction=damage~=2
    self.reactionUntil=self.now+(self.lightReaction and 1.05 or .4)
    self.world:cue(-99,false);if self.world.setReaction then self.world:setReaction(-99,true) end
    local response=responseByAction[action] or (action=='Dash' and (damage==255 and 3 or 4))
    local impulse=response and self.config.Impulses[response]
    if impulse and self.world.impulse then self.world:impulse(-99,attacker,impulse,response) end
    self:_health();return true
end
function Boss:selectAction(input)
    self:_finishReaction()
    local raw=self.enemies[-99].rawLife
    local heavy=self.state=='Reaction' and self.heavyReaction==true
    if input=='Dash' then return heavy and 'HeroBoot' or 'Dash' end
    if heavy then return raw<8 and 'HeroBoot' or 'HeroKick' end
    if raw<4 then return 'HeroPowerPunch' end
    if raw%16<4 then return 'HeroUppercut' end
    return 'HeroJab'
end
function Boss:finishChase()
    if not self:_active() then return 'RUN_CLOSED' end
    if self.state~='Chase' then return 'NO_CHANGE' end
    self.state='Ready';self.readyAt=self.now+.5
    self:_log('BuzzballBattleStarted',{actorId=self.enemies[-99].actorId,rawLife=self.enemies[-99].rawLife})
    return 'OK'
end
function Boss:step(now,dt)
    if not finite(now) or now<0 or dt~=nil and (not finite(dt) or dt<0) then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now
    if not self:_active() then self:_clearProjectiles();return 'OK' end
    self:_contain()
    self:_finishReaction()
    if self.lastMove and now-self.lastMove>=(self.config.MoveTimeout or .35) then
        self.lastMove=nil
        if self.world.move then self.world:move(-99,0,0,false) end
    end
    self:_attackStep(now);self:_projectiles(now)
    local e=self.enemies[-99]
    if self.state=='Ready' and not e.ownerUserId and now>=self.readyAt then
        local target,range=self:_nearest()
        if target and range<=80 then
            local name=self:_chooseAttack('Punch')
            self:_begin(name,nil,target)
        end
    end
    return 'OK'
end
function Boss:available() return {} end
function Boss:claim() return 'UNKNOWN_ENEMY' end
function Boss:connection(userId,connected)
    local e=self.enemies[-99]
    if userId~=e.ownerUserId then return 'UNKNOWN_ENEMY' end
    if type(connected)~='boolean' then return 'INVALID_CONNECTION' end
    if e.connected==connected then return 'NO_CHANGE' end
    e.connected=connected;e.connectionEpoch+=1;e.lastSeq=0;self.lastMove=nil
    if self.world.move then self.world:move(-99,0,0) end
    return 'OK'
end
function Boss:controlled(userId)
    local e=self.enemies[-99];if e.ownerUserId~=userId then return nil end
    return {enemyId=-99,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,connected=e.connected,
        status=e.dead and 'Dead' or 'Alive',template='Boss',name=self.ownerName or e.name,
        hearts=e.rawLife,maxHearts=e.maxRawLife,rawLife=e.rawLife,progress=e.progress,maxProgress=self.profile.progress and 240 or nil,
        bossType=self.kind,bossState=self.state,bossPhase=self:_phase()}
end
function Boss:snapshot()
    local e=self.enemies[-99]
    return {bossType=self.kind,bossName=e.name,bossRawLife=e.rawLife,bossMaxRawLife=e.maxRawLife,
        rawLife=e.rawLife,maxRawLife=e.maxRawLife,progress=e.progress,maxProgress=self.profile.progress and 240 or nil,
        bossProgress=e.progress,bossMaxProgress=self.profile.progress and 240 or nil,bossPhase=self:_phase(),
        bossState=self.state,bossAttack=self.attack and self.attack.name,bossDefeated=self.defeated,
        bossVulnerable=self:_active() and (self.state=='Ready' or self.state=='Recovery' or self.state=='Reaction' and self.lightReaction),projectiles=(function()
            local n=0;for _ in pairs(self.projectiles) do n+=1 end;return n end)()}
end
function Boss:close(reason)
    if self.closed then return end
    self.closed=reason or 'Closed';self.state='Closed';self.attack=nil;self.lastMove=nil;self:_clearProjectiles()
    self.world:cue(-99,false);if self.world.move then self.world:move(-99,0,0) end
    if self.world.setReaction then self.world:setReaction(-99,false) end
end
return Boss
