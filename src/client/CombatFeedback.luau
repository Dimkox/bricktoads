-- Confirmed presentation only. This module never sends input or changes actors.
local Feedback={}
Feedback.__index=Feedback
local messages={DragonMounted="DRAGON MOUNTED",DragonCaptured="YOU WERE CAPTURED",
    DragonReleased="BACK ON FOOT",DragonFireHit="FIRE HIT",AttackMiss="MISS",EnemyAttackMiss="MISS",EnemyDeath="ENEMY DEFEATED",
    EnemyClaimed="ROLE CLAIMED",FlyCaught="HEALTH RESTORED",ClubEquipped="CLUB EQUIPPED",
    ClubDropped="CLUB DROPPED",ClubSwingHit="CLUB HIT",EnemyGrabbed="ENEMY GRABBED",
    EnemyThrown="ENEMY THROWN",EnemyDropped="ENEMY RELEASED",RelocateToSafety="SAFE SUPPORT",
    GuardianBallPickedUp="BALL PICKED UP",GuardianBallThrown="BALL THROWN",BossHit="GUARDIAN HIT",
    BossShielded="GUARDIAN PROTECTED",BossWarning="HEAVY BALL — DODGE"}
messages.LifeStolen='LIFE STOLEN';messages.StolenLifeRecovered='LIFE RECOVERED';messages.RavenClawPickedUp='RAVEN CLAW EQUIPPED'
messages.CampaignGroupStopped='CRASH · GROUP STOPPED';messages.CampaignGroupRewound='CHECKPOINT · READY'
messages.CampaignBombDefused='BOMB DEFUSED'
local global={RunResult=true,EnemyDeath=true,BossHit=true,BossShielded=true,BossWarning=true,
    CampaignGroupStopped=true,CampaignGroupRewound=true,CampaignBombDefused=true}
local actionMessages={NOT_RUNNING="Run first: double-tap a direction",REACTION="Wait until you recover",
    COOLDOWN="Wait before your next action",HELD="You are held · wait for release",
    THROWN="You are thrown · wait until landing"}
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function integer(v) return finite(v) and v>=0 and v<=1e12 and v%1==0 end
local function identity(v) return type(v)=='string' and #v>0 and #v<=160 end
local function owner(data)
    if finite(data.mine) and type(data.heroes)=='table' then
        for i=1,math.min(#data.heroes,3) do
            local hero=data.heroes[i]
            if type(hero)=='table' and hero.slot==data.mine then return hero.slot,hero.actorId end
        end
    end
    local enemy=data.enemyRole
    if type(enemy)=='table' and finite(enemy.enemyId) then return enemy.enemyId,enemy.actorId end
end

function Feedback.new() return setmetatable({cursor=0},Feedback) end

function Feedback:_actionFeedback(data,group,observedServerNow)
    local _,actor=owner(data)
    if not identity(actor) or (data.view~=nil and data.view~='Playing')
        or (data.status~=nil and data.status~='Active') then
        self.actionScope,self.actionCursor=nil,0;return nil
    end
    local scope=tostring(#group)..':'..group..':'..data.runId..':'..tostring(data.levelEpoch)..':'..actor
    local baseline=self.actionScope~=scope
    if baseline then self.actionScope,self.actionCursor=scope,0 end
    local row=data.actionFeedback
    local envelopeNow=finite(data.serverNow) and data.serverNow or data.now
    if type(row)~='table' or not integer(row.id) or row.id<1 or not actionMessages[row.code]
        or (row.kind~='Attack' and row.kind~='Jump') or row.groupId~=group or row.runId~=data.runId
        or row.actorId~=actor or not finite(row.expiresAt) or not finite(envelopeNow) then return nil end
    local now=finite(observedServerNow) and math.max(observedServerNow,envelopeNow) or envelopeNow
    local remaining=row.expiresAt-now
    if remaining<=0 or row.expiresAt-envelopeNow>1.400001 or row.id<=(self.actionCursor or 0) then return nil end
    self.actionCursor=row.id
    if baseline then return nil end
    return {kind='ActionResult',actionId=row.id,text=actionMessages[row.code],style='shield',
        duration=math.min(1.4,remaining),expiresAt=row.expiresAt}
end

function Feedback:sync(data,observedServerNow)
    if type(data)~='table' or not integer(data.snapshotSeq) or data.snapshotSeq<1
        or (self.snapshotSeq and data.snapshotSeq<=self.snapshotSeq) then return {},false end
    self.snapshotSeq=data.snapshotSeq
    if not identity(data.runId) then self.scope=nil;self.cursor=0;self.actionScope=nil;self.actionCursor=0;return {},true end
    local group=data.groupId or 'combat-stand'
    if not identity(group) then return {},false end
    local action=self:_actionFeedback(data,group,observedServerNow)
    local actionRows=action and {action} or {}
    local feed=data.feedback
    if type(feed)~='table' or not integer(feed.latestSeq) or type(feed.events)~='table'
        or #feed.events>12 or not finite(data.now) then return actionRows,true end
    local scope=tostring(#group)..':'..group..':'..data.runId
    if self.scope~=scope then self.scope=scope;self.cursor=feed.latestSeq;return actionRows,true end
    if feed.latestSeq<=self.cursor then return actionRows,true end
    local serverNow=finite(data.serverNow) and data.serverNow or data.now
    local ownSlot,ownActor=owner(data)
    local pending={}
    for _,event in ipairs(feed.events) do
        if type(event)=='table' and integer(event.seq) and event.seq>self.cursor and event.seq<=feed.latestSeq
            and finite(event.now) and event.now<=serverNow+.5 and serverNow-event.now<=3
            and event.levelEpoch==data.levelEpoch then pending[#pending+1]=event end
    end
    table.sort(pending,function(a,b) return a.seq<b.seq end)
    local result,seen={},{}
    for _,event in ipairs(pending) do
        local relevant=ownSlot==nil or global[event.kind] or event.slot==ownSlot or event.attacker==ownSlot
        if event.slot==ownSlot and event.actorId and ownActor and event.actorId~=ownActor then relevant=false end
        if not seen[event.seq] and relevant then
            seen[event.seq]=true
            local message,style=messages[event.kind],'neutral'
            if event.kind=='Hit' or event.kind=='EnemyHit' then
                if event.blocked then message,style="PROTECTED",'shield'
                elseif event.slot==ownSlot then message,style="DAMAGE TAKEN",'damage'
                else message,style="HIT",'success' end
            elseif event.kind=='CommitSpawn' and finite(event.attempt) and event.attempt>1 then
                message,style="RETURNED",'success'
            elseif event.kind=='RunResult' then
                if event.result=='Won' then message,style="VICTORY",'success'
                elseif event.result=='Lost' then message,style="DEFEAT",'damage' end
            elseif event.kind=='BossWarning' then style='shield' end
            if message then result[#result+1]={seq=event.seq,kind=event.kind,text=message,style=style} end
        end
    end
    self.cursor=feed.latestSeq
    if action then result[#result+1]=action end
    return result,true
end

function Feedback.hint(data,translate)
    local T=translate or function(source) return source end
    data=type(data)=='table' and data or {}
    if data.status=='Faulted' then return "Party stopped · start again" end
    if type(data.enemyRole)=='table' and data.enemyRole.template=='Boss' then
        return data.enemyRole.bossType and 'ATTACK: use your boss moves' or "FIRE: shoot at the heroes"
    end
    if data.enemyRole and data.enemyRole.resourceKind=='CourseRival' then return 'RACE: move and jump · punches can stun you' end
    local interaction=type(data.interaction)=='table' and data.interaction or {}
    if interaction.carrying and type(interaction.label)=='string' then
        return T(interaction.label)..(interaction.available and T(" — action button") or '')
    end
    local controlled=type(data.enemyRole)=='table' and data.enemyRole or nil
    if data.mine and type(data.heroes)=='table' then
        for i=1,math.min(#data.heroes,3) do
            local h=data.heroes[i]
            if type(h)=='table' and h.slot==data.mine then controlled=h;break end
        end
    end
    if controlled and controlled.status=='Alive' and controlled.connected~=false
        and controlled.movementMode=='Run' and (data.view==nil or data.view=='Playing') then
        return "MEGA: running strike"
    end
    if type(data.interaction)=='table' and data.interaction.available and type(data.interaction.label)=='string' then
        return T(data.interaction.label)..T(" — action button")
    end
    if data.mine and data.level and data.level.modeState then
        local hints={Rope='SWING · JUMP: push off · ATTACK: kick',Speeder='STEER · JUMP: clear barriers',
            Surf='STEER · JUMP: clear the water hazards',Jet='UP/DOWN: altitude · LEFT/RIGHT: speed',
            Ice='BRAKE EARLY · run and jump',Serpents='JUMP: ride the moving serpent',
            Ascent='JUMP: use lifts, fans and springs',Tubes='UP/DOWN: swim · JUMP: kick upward',
            Race='REACH THE BOMB · ATTACK: defuse',Clinger='HOLD THE ROUTE DIRECTION',Tower='LEFT/RIGHT: circle · JUMP: climb'}
        local unfinished=true
        for _,actor in ipairs(data.level.modeState.actors or {}) do
            if actor.slot==data.mine then unfinished=not actor.finished;break end
        end
        if unfinished and hints[data.level.mode] then return hints[data.level.mode] end
    end
    if data.mine then return "ATTACK: strike or interact nearby" end
    if data.enemyRole and data.enemyRole.movementKind=='Swim' then return 'LEFT/RIGHT: swim · UP/DOWN: dive or rise' end
    if data.enemyRole and data.enemyRole.movementKind=='Fly' then return 'MOVE: steer · JUMP: flap upward' end
    if data.enemyRole and data.enemyRole.movementKind=='Ride' then return 'SCRIPTED FLIGHT · ATTACK: drop one obstacle' end
    if data.enemyRole then return "ATTACK: stop the heroes" end
    return "Choose a role or watch"
end

function Feedback.aliveHeroes(heroes)
    local count=0
    for _,hero in ipairs(heroes or {}) do
        if hero.status=='Alive' and not hero.dying then count+=1 end
    end
    return count
end

function Feedback.remainingEnemies(level)
    local count=0
    for _,actor in ipairs(level.enemies or {}) do
        local current=actor.zoneIndex==nil or level.zoneIndex==nil or actor.zoneIndex==level.zoneIndex
        local ordinary=actor.boss~=true and actor.template~='Boss' and actor.id~=-99 and actor.enemyId~=-99
            and actor.courseRival~=true and actor.resourceKind~='CourseRival'
        if current and ordinary and actor.dragonMode~='Mounted' and actor.dead~=true and actor.alive~=false
            and actor.status~='Dead' and actor.status~='Eliminated' then count+=1 end
    end
    return count
end

return Feedback
