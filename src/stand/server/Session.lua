-- Synchronous coordinator: World methods must not yield or partially commit a failed spawn.
local Session = {}
Session.__index = Session
local common = {kind=true,runId=true,actorId=true,attempt=true,levelEpoch=true,connectionEpoch=true,seq=true}
local extras = {Attack={attack=true},Move={x=true,z=true,run=true},Jump={}}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function integer(n) return finite(n) and n>=1 and n<=1000000000 and n%1==0 end
local function valid(p)
    if type(p)~="table" or not extras[p.kind] then return false end
    local count=0
    for k,v in pairs(p) do
        count=count+1
        if count>(p.kind=='Move' and 10 or 9) or not (common[k] or extras[p.kind][k]) or type(v)=="table" then return false end
    end
    if type(p.runId)~="string" or #p.runId>160 or type(p.actorId)~="string" or #p.actorId>160
        or not integer(p.attempt) or not integer(p.levelEpoch) or not integer(p.connectionEpoch)
        or not integer(p.seq) then return false end
    if p.kind=="Attack" then return p.attack=="Punch" or p.attack=="Dash" end
    if p.kind=="Move" then return finite(p.x) and finite(p.z) and p.x*p.x+p.z*p.z<=1.01
        and (p.run==nil or type(p.run)=='boolean') end
    return true
end

-- The ordinary-enemy controller uses the same untrusted intent schema.
Session.validIntent=valid

function Session.new(Core, Combat, Config, roster, runId, world, logger, context)
    context=context or {}
    local self=setmetatable({Core=Core,Combat=Combat,config=Config,world=world,logger=logger,
        state=Core.new(runId,context.groupId or "combat-stand",roster,context.levelId or "stand-1"),now=0,serial=0,
        order={},combat={},lastSeq={},nextSpawn={},lastMove={},buckets={},logs={}},Session)
    for _,member in ipairs(roster) do
        local uid=member.userId
        self.order[#self.order+1]=uid
        self.combat[uid]={rawLife=47,nextAttack=0}
    end
    return self
end

function Session:_clock(now)
    if not finite(now) or now<0 then return "INVALID_TIME" end
    if now<self.now then return "TIME_REVERSED" end
    self.now=now
    return "OK"
end

function Session:_resetLocomotion(uid)
    if self.config.Movement and self.world.resetLocomotion then
        self.world:resetLocomotion(uid,self.world.actors and self.world.actors[uid])
    end
end

function Session:_record(kind, uid, data, at)
    local h=self.state.heroes[uid]
    local row={kind=kind,userId=uid,now=at or self.now,runId=self.state.runId,groupId=self.state.groupId,
        levelEpoch=self.state.levelEpoch,revision=self.state.revision,
        actorId=h and h.actorId,attempt=h and h.attempt,respawns=h and h.respawns,
        infiniteLives=h and h.infiniteLives==true,
        rawLife=self.combat[uid] and self.combat[uid].rawLife,status=h and h.status,view=h and h.view,
        connected=h and h.connected,shieldKind=h and h.shield and h.shield.kind,
        shieldUntil=h and h.shield and h.shield.deadline,data=data}
    self.logs[#self.logs+1]=row
    if #self.logs>self.config.MaxLogEntries then table.remove(self.logs,1) end
    if self.logger then
        local ok=pcall(self.logger,row)
        if not ok then self.loggerFailures=(self.loggerFailures or 0)+1 end
    end
end

function Session:_event(kind, uid, fields)
    self.serial=self.serial+1
    local h=self.state.heroes[uid]
    local e={id="s-"..self.serial,runId=self.state.runId,expectedRevision=self.state.revision,
        now=self.now,kind=kind,userId=uid}
    if kind=="Death" or kind=="SetHealth" or kind=="BeginAttack" or kind=="ExpireShield"
        or kind=="RelocateToSafety" then
        e.actorId=h.actorId; e.attempt=h.attempt; e.levelEpoch=self.state.levelEpoch
    end
    for k,v in pairs(fields or {}) do e[k]=v end
    local state,code,ack=self.Core.apply(self.state,e)
    self.state=state
    self:_record(kind,uid,{code=code,eventId=e.id})
    return code,ack
end

-- Server-only development control; client intents cannot name this event or option.
function Session:setInfiniteLives(enabled)
    if type(enabled)~="boolean" then return "INVALID_OPTION" end
    if type(self.config.Development)~="table" or self.config.Development.allowInfiniteLives~=true then
        return "DEVELOPMENT_ONLY"
    end
    if self.state.status~="Active" then return "RUN_CLOSED" end
    for _,uid in ipairs(self.order) do
        local h=self.state.heroes[uid]
        if h.status~="Eliminated" and h.infiniteLives~=enabled then
            assert(self:_event("SetInfiniteLives",uid,{enabled=enabled})=="OK")
        end
    end
    return "OK"
end

function Session:_spawn(uid)
    local h=self.state.heroes[uid]
    if not h.connected or self.now<(self.nextSpawn[uid] or 0) then return end
    local point=self.world:findSafe(uid)
    if not point and h.status=="AwaitingInitial" then
        self.nextSpawn[uid]=self.now+self.config.SpawnRetry
        return
    end
    local code=self:_event("ReserveSpawn",uid,{connectionEpoch=h.connectionEpoch})
    if code~="OK" then return end
    local token=self.state.heroes[uid].pending.token
    self.serial=self.serial+1
    local actorId=self.state.runId..":actor:"..self.serial
    local safe=point~=nil
    local ok,spawned=pcall(function()
        if safe and not self.world:isSafe(point,uid) then return false end
        return self.world:spawn(uid,actorId,point,not safe,h.template)
    end)
    if not ok or not spawned then
        self:_event("AbortSpawn",uid,{token=token})
        self.nextSpawn[uid]=self.now+self.config.SpawnRetry
        self:_record("SpawnFailed",uid,{error=ok and "rejected" or tostring(spawned)})
        return
    end
    code=self:_event("CommitSpawn",uid,{token=token,actorId=actorId,safe=safe})
    assert(code=="OK","Synchronous spawn commit violated its reservation: "..code)
    self.combat[uid]={rawLife=47,nextAttack=self.now}
    self.lastSeq[uid]=0; self.lastMove[uid]=nil; self.nextSpawn[uid]=nil
    self:_resetLocomotion(uid)
    self.world:hold(uid,not safe)
end

function Session:_die(uid, reason)
    local h=self.state.heroes[uid]
    if h.status~="Alive" then return end
    if self:_event("Death",uid)~="OK" then return end
    self.combat[uid]={rawLife=0,nextAttack=self.now}
    self.lastMove[uid]=nil
    self:_resetLocomotion(uid)
    self.world:kill(uid)
    self:_record("ConfirmedDeath",uid,{reason=reason,actorId=h.actorId,observed=self.world:observe(uid)})
end

function Session:_finishReaction(uid)
    local c=self.combat[uid]
    if not c or not c.reactionEnd or c.deathAt or self.now<c.reactionEnd then return false end
    if c.recover then
        c.rawLife=self.Combat.recover(c.rawLife)
        assert(self:_event('SetHealth',uid,{health=self.Combat.hearts(c.rawLife)})=='OK')
    elseif self.sourceCombat and c.heavyReaction==true then
        c.hitProtectedUntil=c.reactionEnd+(c.reactionProtectionSeconds or self.sourceCombat.heavyProtection)
    end
    c.reactionEnd=nil;c.recover=nil;c.heavyReaction=nil;c.reactionProtectionSeconds=nil;self.world:setReaction(uid,false)
    return true
end

function Session:connection(uid, connected, now)
    if not self.state.heroes[uid] then return "UNKNOWN_HERO" end
    local code=self:_clock(now); if code~="OK" then return code end
    if type(connected)~="boolean" then return "INVALID_CONNECTION" end
    local h=self.state.heroes[uid]
    code=self:_event("Connection",uid,{connectionEpoch=h.connectionEpoch,connected=connected})
    if code=="OK" then
        self.lastSeq[uid]=0; self.buckets[uid]=nil; self.lastMove[uid]=nil
        self:_resetLocomotion(uid)
        self.world:move(uid,0,0)
    end
    return code
end

-- The controller has authenticated the completed exit and installed the next
-- geometry. Moving a living body is not a spawn and cannot spend a reserve.
function Session:advanceLevel(levelId, now, options)
    options=options or {}
    if self.state.status~='Active' then return 'RUN_CLOSED' end
    if options.prerequisitesMet~=true then return 'EXIT_NOT_READY' end
    if type(levelId)~='string' or #levelId==0 or #levelId>160 then return 'INVALID_LEVEL' end
    if levelId==self.state.levelId then return 'SAME_LEVEL' end
    local code=self:_clock(now);if code~='OK' then return code end
    local source,points
    points={}
    for _,uid in ipairs(self.order) do
        local hero=self.state.heroes[uid]
        if hero.status=='Alive' then
            if not self.combat[uid].deathAt then source=source or uid end
            local point=self.world:findSafe(uid)
            if not point or not self.world:isSafe(point,uid) then return 'UNSAFE_DESTINATION' end
            points[uid]=point
        end
    end
    if not source then return 'NO_SURVIVOR' end
    local hero=self.state.heroes[source]
    code=self:_event('AdvanceLevel',source,{actorId=hero.actorId,attempt=hero.attempt,
        levelEpoch=self.state.levelEpoch,levelId=levelId,destinationSafe=true,prerequisitesMet=true})
    if code~='OK' then return code end
    self.lastSeq={};self.lastMove={};self.buckets={};self.nextSpawn={}
    for _,uid in ipairs(self.order) do
        local member=self.state.heroes[uid]
        self.lastSeq[uid]=0
        if member.status=='Alive' then
            assert(self.world:relocate(uid,points[uid])==true,'Synchronous level relocation failed')
            local previous=self.combat[uid]
            if previous.deathAt then
                -- A different survivor can finish while this accepted lethal
                -- reaction is still playing. Preserve its original deadline.
                previous.attack=nil;previous.nextAttack=now
                assert(self:_event('SetHealth',uid,{health=self.Combat.hearts(previous.rawLife)})=='OK')
            else
                self.combat[uid]={rawLife=47,nextAttack=now}
                self.world:setReaction(uid,false)
            end
        else
            -- Awaiting respawns retain their pending resource obligation; an
            -- eliminated owner never receives a body at a level boundary.
            self.combat[uid]={rawLife=0,nextAttack=now}
        end
        self:_resetLocomotion(uid)
    end
    if self.world.finishLevelTransition then self.world:finishLevelTransition() end
    self:_record('LevelAdvanced',source,{levelId=levelId})
    return 'OK'
end

function Session:intent(uid, p, now)
    local h=self.state.heroes[uid]
    if not h then return "UNKNOWN_HERO" end
    if not valid(p) then return "INVALID_INTENT" end
    if p.runId~=self.state.runId then return "WRONG_RUN" end
    if self.state.status~="Active" then return "RUN_CLOSED" end
    if not h.connected then return "OFFLINE" end
    if h.status~="Alive" then return "NOT_ALIVE" end
    if p.actorId~=h.actorId or p.attempt~=h.attempt or p.levelEpoch~=self.state.levelEpoch then return "STALE_ACTOR" end
    if p.connectionEpoch~=h.connectionEpoch then return "STALE_CONNECTION" end
    if p.seq<=(self.lastSeq[uid] or 0) then return "STALE_SEQUENCE" end
    local code=self:_clock(now); if code~="OK" then return code end
    local b=self.buckets[uid] or {tokens=self.config.MaxIntentRate,last=now}
    b.tokens=math.min(self.config.MaxIntentRate,b.tokens+(now-b.last)*self.config.MaxIntentRate)
    b.last=now; self.buckets[uid]=b
    self.lastSeq[uid]=p.seq
    if b.tokens<1 then return "RATE_LIMIT" end
    b.tokens=b.tokens-1
    local c=self.combat[uid]
    if self.sourceCombat then self:_finishReaction(uid) end
    if self.contextualIntent then
        local result=self.contextualIntent(uid,p,now)
        if result~='NO_INTERACTION' then return result end
    end
    if c.reactionEnd or c.deathAt then return "REACTION" end
    if p.kind=="Move" then
        self.lastMove[uid]=now
        local run=p.run
        if self.groundRunAllowed and not self.groundRunAllowed(uid) then run=false end
        self.world:move(uid,p.x,p.z,run)
    elseif p.kind=="Jump" then
        self.world:jump(uid)
    else
        if now<c.nextAttack or c.attack then return "COOLDOWN" end
        local running=self.config.Movement and (self.canRunStrike and self.canRunStrike(uid)
            or (not self.canRunStrike and self.world.isRunning and self.world:isRunning(uid)))==true
        if not running and self.contextualAttack then
            local interaction=self.contextualAttack(uid,now,p.attack)
            if interaction~='NO_INTERACTION' then
                if interaction=='OK' then
                    self:_resetLocomotion(uid)
                    c.nextAttack=math.max(c.nextAttack,now+self.config.Attacks[p.attack].cooldown)
                    self:_record('InteractionAccepted',uid,{action=p.attack,seq=p.seq})
                end
                return interaction
            end
        end
        if self.config.Movement and p.attack=='Dash' and not running then return 'NOT_RUNNING' end
        code=self:_event("BeginAttack",uid,{connectionEpoch=h.connectionEpoch})
        if code~="OK" then return code end
        self.world:hold(uid,false)
        local input=running and 'Dash' or p.attack
        local action=self.attackSelector and self.attackSelector(uid,input) or input
        local cfg=self.config.Attacks[action]
        assert(cfg,'Unknown trusted action')
        c.nextAttack=now+cfg.cooldown
        c.attack={action=action,inputAction=p.attack,tuning=self.Combat.captureAttack(self.config,action,cfg),actorId=h.actorId,at=now+cfg.windup,
            untilTime=now+cfg.windup+cfg.window,order=self.serial}
        if running then self.world:move(uid,0,0,false);self.lastMove[uid]=nil end
        self:_record("AttackAccepted",uid,{action=action,inputAction=p.attack,seq=p.seq})
    end
    return "OK"
end

-- Invader health-bar links are trusted server objects, not public attack inputs.
-- The source subtracts/adds eight directly; returning at >= $30 consumes the
-- object without changing Life. Tokens are bound to this exact hero body.
-- main5713-5715 masks Life with $38; main5635-5648 skips subtraction when
-- that result is below7. Thus raw0..7 do not enter SBC8 (main5656-5659).
function Session:_stealLife(attacker,target)
    local h,c=self.state.heroes[target],self.combat[target]
    if self.state.status~='Active' or not h or h.status~='Alive' or not c or c.deathAt
        or not h.actorId or c.rawLife<8 or c.rawLife>47
        or h.shield and self.now<h.shield.deadline
        or c.hitProtectedUntil and self.now<c.hitProtectedUntil then return nil end
    local before=c.rawLife;local after=before-8
    if self:_event('SetHealth',target,{health=self.Combat.hearts(after)})~='OK' then return nil end
    c.rawLife=after
    local token={slot=target,combat=c,actorId=h.actorId,attempt=h.attempt,runId=self.state.runId,levelEpoch=self.state.levelEpoch}
    self.stolenLifeTokens=self.stolenLifeTokens or {};self.stolenLifeTokens[token]=true
    self:_record('LifeStolen',target,{attacker=attacker,before=before,after=after})
    return token
end
function Session:_discardStolenLife(token)
    if self.stolenLifeTokens then self.stolenLifeTokens[token]=nil end
end
function Session:_recoverStolenLife(token)
    if not self.stolenLifeTokens or not self.stolenLifeTokens[token] then return false end
    self.stolenLifeTokens[token]=nil
    local h,c=self.state.heroes[token.slot],self.combat[token.slot]
    if self.state.status~='Active' or self.state.runId~=token.runId or self.state.levelEpoch~=token.levelEpoch
        or not h or h.status~='Alive' or h.actorId~=token.actorId or h.attempt~=token.attempt
        or c~=token.combat or c.deathAt or c.rawLife+8>=48 then return false end
    local before=c.rawLife;local after=before+8
    if self:_event('SetHealth',token.slot,{health=self.Combat.hearts(after)})~='OK' then return false end
    c.rawLife=after;self:_record('StolenLifeRecovered',token.slot,{before=before,after=after})
    return true
end

function Session:_hit(attacker, target, action, tuning)
    local h=self.state.heroes[target]
    local c=self.combat[target]
    if not h or target==attacker or h.status~="Alive" or c.deathAt then return false end
    if self.sourceCombat then self:_finishReaction(target) end
    if c.reactionEnd and not self.sourceCombat then return false end
    if self.sourceCombat and c.hitProtectedUntil and self.now<c.hitProtectedUntil then return false end
    local shield=h.shield and self.now<h.shield.deadline and h.shield.kind or nil
    local before=c.rawLife
    local result=self.Combat.hit(before,action,shield)
    local cfg=tuning or self.config.Attacks[action]
    if not result.blocked then
        local code=self:_event("SetHealth",target,{health=self.Combat.hearts(result.rawLife)})
        if code~="OK" then return false end
        c.rawLife=result.rawLife
    end
    if result.impulse then
        if self.beforeHitImpulse then self.beforeHitImpulse(target) end
        self:_resetLocomotion(target)
        -- Pending contextual actions must still see an interrupt after recovery
        -- has cleared reactionEnd during a later (possibly long) server step.
        c.reactionEpoch=(c.reactionEpoch or 0)+1
        if result.heavyReaction then c.heavyReactionEpoch=(c.heavyReactionEpoch or 0)+1 end
        c.attack=nil
        c.recover=result.recover
        c.heavyReaction=result.heavyReaction
        local policy=cfg.sourceCombat or self.sourceCombat
        c.reactionProtectionSeconds=policy and policy.heavyProtection or nil
        c.reactionEnd=self.now+cfg.reaction
        c.deathAt=result.dying and self.now+(cfg.deathDelay or self.config.DeathDelay) or nil
        self.world:move(target,0,0)
        self.world:setReaction(target,true)
        local impulse=cfg.responses and cfg.responses[result.profile] or self.config.Impulses[result.profile]
        self.world:impulse(target,attacker,impulse,result.profile,cfg.impulseDirection)
    end
    self:_record("Hit",target,{attacker=attacker,action=action,profile=result.profile,
        before=before,after=c.rawLife,blocked=result.blocked,impulse=result.impulse,
        dying=result.dying,observed=self.world:observe(target)})
    return true
end

function Session:step(now)
    local code=self:_clock(now); if code~="OK" then return code end
    if self.state.status~="Active" then return "RUN_CLOSED" end
    -- Previous-frame deaths spawn here; a new death cannot respawn twice in this step.
    for _,uid in ipairs(self.order) do
        local h=self.state.heroes[uid]
        if h.status=="AwaitingInitial" or h.status=="AwaitingRespawn" then self:_spawn(uid) end
    end
    for _,uid in ipairs(self.order) do
        local h=self.state.heroes[uid]
        if h.status=="Alive" and h.shield then
            if h.shield.kind=="Emergency" then
                local point=self.world:findSafe(uid)
                if point and self.world:isSafe(point,uid) and self.world:relocate(uid,point) then
                    assert(self:_event("RelocateToSafety",uid,{safe=true})=="OK")
                    self.world:hold(uid,false)
                end
            end
            h=self.state.heroes[uid]
            if h.shield and now>=h.shield.deadline then
                assert(self:_event("ExpireShield",uid)=="OK")
                self.world:hold(uid,false)
                if self.state.heroes[uid].retryReady then self:_spawn(uid) end
            end
        elseif h.status=="Alive" and h.retryReady then
            self:_spawn(uid)
        end
        local c=self.combat[uid]
        if self.state.heroes[uid].status=="Alive" then
            if c.deathAt and now>=c.deathAt then
                self:_die(uid,"CombatUnderflow")
            elseif c.reactionEnd and not c.deathAt and now>=c.reactionEnd then
                self:_finishReaction(uid)
            end
        end
    end
    local due={}
    for _,uid in ipairs(self.order) do
        local a=self.combat[uid].attack
        if a and now>=a.at then due[#due+1]={uid=uid,attack=a} end
    end
    table.sort(due,function(a,b)
        if a.attack.at~=b.attack.at then return a.attack.at<b.attack.at end
        return a.attack.order<b.attack.order
    end)
    for _,entry in ipairs(due) do
        local uid,a=entry.uid,entry.attack
        local h=self.state.heroes[uid]
        if self.combat[uid].attack==a then
            self.combat[uid].attack=nil
            if h.status=="Alive" and h.actorId==a.actorId and now<=a.untilTime then
                self.combat[uid].lastStrikeAction=a.action
                self.combat[uid].strikeRecoveryUntil=now+((a.tuning and a.tuning.recoveryPose) or .17)
                local landed=false
                for _,target in ipairs(self.world:targets(uid,a.tuning or self.config.Attacks[a.action])) do
                    if self:_hit(uid,target,a.action,a.tuning) then landed=true;break end
                end
                if not landed then self:_record('AttackMiss',uid,{action=a.action}) end
            else self:_record("AttackExpired",uid,{action=a.action}) end
        end
    end
    for _,uid in ipairs(self.order) do
        local h=self.state.heroes[uid]
        if h.status=="Alive" then
            if self.lastMove[uid] and now-self.lastMove[uid]>=self.config.MoveTimeout then
                self.world:move(uid,0,0,false); self.lastMove[uid]=nil
            end
            local reason=self.world:hazard(uid)
            local held=h.shield and h.shield.kind=="Emergency" and now<h.shield.deadline
            if reason and (not held or reason=="ActorMissing") then self:_die(uid,reason) end
        end
    end
    return "OK"
end

function Session:snapshot()
    local heroes={}
    local infiniteLives=false
    for _,uid in ipairs(self.order) do
        local h=self.state.heroes[uid]
        local c=self.combat[uid]
        if h.infiniteLives==true and h.status~="Eliminated" then infiniteLives=true end
        heroes[#heroes+1]={slot=uid,actorId=h.actorId,attempt=h.attempt,
            connectionEpoch=h.connectionEpoch,connected=h.connected,status=h.status,view=h.view,
            hearts=self.Combat.hearts(c.rawLife),rawLife=c.rawLife,respawns=h.respawns,
            infiniteLives=h.infiniteLives==true,
            shield=h.shield and h.shield.kind,shieldUntil=h.shield and h.shield.deadline,
            dying=c.deathAt~=nil,reactionEpoch=c.reactionEpoch or 0,
            movementMode=self.world.movementMode and self.world:movementMode(uid) or nil}
    end
    return {runId=self.state.runId,levelEpoch=self.state.levelEpoch,status=self.state.status,
        now=self.now,heroes=heroes,infiniteLives=infiniteLives,calibration=self.config.Calibration}
end

return Session
