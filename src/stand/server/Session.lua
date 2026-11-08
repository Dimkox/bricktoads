-- Synchronous coordinator: World methods must not yield or partially commit a failed spawn.
local Session = {}
Session.__index = Session
local common = {kind=true,runId=true,actorId=true,attempt=true,levelEpoch=true,connectionEpoch=true,seq=true}
local extras = {Attack={attack=true},Move={x=true,z=true},Jump={}}
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function integer(n) return finite(n) and n>=1 and n<=1000000000 and n%1==0 end
local function valid(p)
    if type(p)~="table" or not extras[p.kind] then return false end
    local count=0
    for k,v in pairs(p) do
        count=count+1
        if count>9 or not (common[k] or extras[p.kind][k]) or type(v)=="table" then return false end
    end
    if type(p.runId)~="string" or #p.runId>160 or type(p.actorId)~="string" or #p.actorId>160
        or not integer(p.attempt) or not integer(p.levelEpoch) or not integer(p.connectionEpoch)
        or not integer(p.seq) then return false end
    if p.kind=="Attack" then return p.attack=="Punch" or p.attack=="Dash" end
    if p.kind=="Move" then return finite(p.x) and finite(p.z) and p.x*p.x+p.z*p.z<=1.01 end
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

function Session:_record(kind, uid, data, at)
    local h=self.state.heroes[uid]
    local row={kind=kind,userId=uid,now=at or self.now,runId=self.state.runId,groupId=self.state.groupId,
        levelEpoch=self.state.levelEpoch,revision=self.state.revision,
        actorId=h and h.actorId,attempt=h and h.attempt,respawns=h and h.respawns,
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
    self.world:hold(uid,not safe)
end

function Session:_die(uid, reason)
    local h=self.state.heroes[uid]
    if h.status~="Alive" then return end
    if self:_event("Death",uid)~="OK" then return end
    self.combat[uid]={rawLife=0,nextAttack=self.now}
    self.lastMove[uid]=nil
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
        self.world:move(uid,0,0)
    end
    return code
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
        self.world:move(uid,p.x,p.z)
    elseif p.kind=="Jump" then
        self.world:jump(uid)
    else
        if now<c.nextAttack or c.attack then return "COOLDOWN" end
        if self.contextualAttack then
            local interaction=self.contextualAttack(uid,now,p.attack)
            if interaction~='NO_INTERACTION' then
                if interaction=='OK' then
                    c.nextAttack=math.max(c.nextAttack,now+self.config.Attacks[p.attack].cooldown)
                    self:_record('InteractionAccepted',uid,{action=p.attack,seq=p.seq})
                end
                return interaction
            end
        end
        code=self:_event("BeginAttack",uid,{connectionEpoch=h.connectionEpoch})
        if code~="OK" then return code end
        self.world:hold(uid,false)
        local action=self.attackSelector and self.attackSelector(uid,p.attack) or p.attack
        local cfg=self.config.Attacks[action]
        assert(cfg,'Unknown trusted action')
        c.nextAttack=now+cfg.cooldown
        c.attack={action=action,inputAction=p.attack,tuning=self.Combat.captureAttack(self.config,action,cfg),actorId=h.actorId,at=now+cfg.windup,
            untilTime=now+cfg.windup+cfg.window,order=self.serial}
        self:_record("AttackAccepted",uid,{action=action,inputAction=p.attack,seq=p.seq})
    end
    return "OK"
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
        self.world:impulse(target,attacker,impulse,result.profile)
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
                self.world:move(uid,0,0); self.lastMove[uid]=nil
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
    for _,uid in ipairs(self.order) do
        local h=self.state.heroes[uid]
        local c=self.combat[uid]
        heroes[#heroes+1]={slot=uid,actorId=h.actorId,attempt=h.attempt,
            connectionEpoch=h.connectionEpoch,connected=h.connected,status=h.status,view=h.view,
            hearts=self.Combat.hearts(c.rawLife),rawLife=c.rawLife,respawns=h.respawns,
            shield=h.shield and h.shield.kind,shieldUntil=h.shield and h.shield.deadline,
            dying=c.deathAt~=nil}
    end
    return {runId=self.state.runId,levelEpoch=self.state.levelEpoch,status=self.state.status,
        now=self.now,heroes=heroes,calibration=self.config.Calibration}
end

return Session
