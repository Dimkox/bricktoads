-- Confirmed presentation only. This module never sends input or changes actors.
local Feedback={}
Feedback.__index=Feedback
local messages={DragonMounted='ВЕРХОМ НА ДРАКОНЕ',DragonCaptured='ВАС СХВАТИЛИ',
    DragonReleased='СНОВА НА НОГАХ',DragonFireHit='ПОПАДАНИЕ ОГНЁМ',AttackMiss='ПРОМАХ',EnemyAttackMiss='ПРОМАХ',EnemyDeath='ПРОТИВНИК ПОВЕРЖЕН',
    EnemyClaimed='РОЛЬ ПОЛУЧЕНА',FlyCaught='ЗДОРОВЬЕ ВОССТАНОВЛЕНО',ClubEquipped='ДУБИНА В РУКАХ',
    ClubDropped='ДУБИНА ВЫПАЛА',ClubSwingHit='УДАР ДУБИНОЙ',EnemyGrabbed='ПРОТИВНИК СХВАЧЕН',
    EnemyThrown='ПРОТИВНИК БРОШЕН',EnemyDropped='ПРОТИВНИК ОСВОБОЖДЁН',RelocateToSafety='БЕЗОПАСНАЯ ОПОРА',
    GuardianBallPickedUp='ШАР В РУКАХ',GuardianBallThrown='ШАР БРОШЕН',BossHit='ПОПАДАНИЕ В СТРАЖА',
    BossShielded='СТРАЖ ЗАЩИЩЁН',BossWarning='ТЯЖЁЛЫЙ ШАР — УКЛОНЯЙТЕСЬ'}
local global={RunResult=true,EnemyDeath=true,BossHit=true,BossShielded=true,BossWarning=true}
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

function Feedback:sync(data)
    if type(data)~='table' or not integer(data.snapshotSeq) or data.snapshotSeq<1
        or (self.snapshotSeq and data.snapshotSeq<=self.snapshotSeq) then return {},false end
    self.snapshotSeq=data.snapshotSeq
    if not identity(data.runId) then self.scope=nil;self.cursor=0;return {},true end
    local group=data.groupId or 'combat-stand'
    if not identity(group) then return {},false end
    local feed=data.feedback
    if type(feed)~='table' or not integer(feed.latestSeq) or type(feed.events)~='table'
        or #feed.events>12 or not finite(data.now) then return {},true end
    local scope=tostring(#group)..':'..group..':'..data.runId
    if self.scope~=scope then self.scope=scope;self.cursor=feed.latestSeq;return {},true end
    if feed.latestSeq<=self.cursor then return {},true end
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
                if event.blocked then message,style='ЗАЩИТА','shield'
                elseif event.slot==ownSlot then message,style='ПОЛУЧЕН УРОН','damage'
                else message,style='ПОПАДАНИЕ','success' end
            elseif event.kind=='CommitSpawn' and finite(event.attempt) and event.attempt>1 then
                message,style='ВОЗВРАЩЕНИЕ','success'
            elseif event.kind=='RunResult' then
                if event.result=='Won' then message,style='ПОБЕДА','success'
                elseif event.result=='Lost' then message,style='ПОРАЖЕНИЕ','damage' end
            elseif event.kind=='BossWarning' then style='shield' end
            if message then result[#result+1]={seq=event.seq,kind=event.kind,text=message,style=style} end
        end
    end
    self.cursor=feed.latestSeq
    return result,true
end

function Feedback.hint(data)
    data=type(data)=='table' and data or {}
    if type(data.enemyRole)=='table' and data.enemyRole.template=='Boss' then return 'ОГОНЬ: стреляйте в героев' end
    if type(data.interaction)=='table' and data.interaction.available and type(data.interaction.label)=='string' then
        return data.interaction.label..' — кнопка действия'
    end
    if type(data.interaction)=='table' and data.interaction.carrying and type(data.interaction.label)=='string' then return data.interaction.label end
    if data.mine then return 'УДАР: атака или действие рядом' end
    if data.enemyRole then return 'УДАР: остановите героев' end
    return 'Выберите роль или наблюдайте'
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
        if current and ordinary and actor.dragonMode~='Mounted' and actor.dead~=true and actor.alive~=false
            and actor.status~='Dead' and actor.status~='Eliminated' then count+=1 end
    end
    return count
end

return Feedback
