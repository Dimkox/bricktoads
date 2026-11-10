-- Confirmed client presentation only. No remotes, gameplay writes or world physics.
local Audio={}
Audio.__index=Audio
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function integer(v) return finite(v) and v>=0 and v<=1e12 and v%1==0 end
local function identity(v) return type(v)=='string' and #v>0 and #v<=160 end
local function asset(v) return type(v)=='string' and v:match('^rbxassetid://[1-9]%d*$')~=nil end
local function call(v,method,...) if v and type(v[method])=='function' then return pcall(v[method],v,...) end;return false end
local function region(row) return type(row)=='table' and finite(row.start) and finite(row.finish) and row.start>=0 and row.finish>row.start and row.finish<420 end
local function owner(data)
    if finite(data.mine) and type(data.heroes)=='table' then
        for i=1,math.min(#data.heroes,3) do local h=data.heroes[i];if type(h)=='table' and h.slot==data.mine then return h.slot,h.actorId,h.attempt end end
    end
    local e=data.enemyRole;if type(e)=='table' and finite(e.enemyId) then return e.enemyId,e.actorId,e.attempt end
end
local function defaultCatalog()
    if script then return require(game:GetService('ReplicatedStorage'):WaitForChild('BrickToads'):WaitForChild('AudioCatalog')) end
    return require('../shared/AudioCatalog')
end
local function defaultEffects(deps)
    local Effects=if script then require(script.Parent:WaitForChild('CombatEffects')) else require('./CombatEffects')
    return Effects.new(deps)
end
local function nativeFactory(deps)
    local soundService=deps.soundService or game:GetService('SoundService')
    local folder=Instance.new('Folder');folder.Name='BrickToadsLocalAudio';folder.Parent=soundService
    local function create(kind,index,assetId)
        local sound=Instance.new('Sound');sound.Name=kind=='music' and 'Music' or 'SFX_'..index
        sound.SoundId=assetId;sound.Volume=0;sound.PlaybackRegionsEnabled=true;sound.Parent=folder
        return {sound=sound,
            isLoaded=function() return sound.IsLoaded and sound.TimeLength>0 end,
            play=function(_,row,looped,volume)
                if not sound.IsLoaded or sound.TimeLength<row.finish-.02 then return false end
                sound:Stop();sound.PlaybackRegion=NumberRange.new(row.start,row.finish)
                sound.LoopRegion=NumberRange.new(row.start,row.finish);sound.Looped=looped
                sound.Volume=volume;sound.TimePosition=row.start;sound:Play();return true
            end,
            stop=function() sound:Stop() end,
            destroy=function() sound:Destroy() end}
    end
    return create,function() folder:Destroy() end
end
-- ClubSwingHit and DragonFireHit are journal supplements to an existing Hit /
-- EnemyHit; the base impact carries action/target and owns its one audiovisual cue.
local cues={Hit='Hit',EnemyHit='Hit',AttackMiss='Miss',EnemyAttackMiss='Miss',
    EnemyThrown='Throw',GuardianBallThrown='Throw',FlyCaught='Fly',StolenLifeRecovered='Fly',CommitSpawn='Spawn',
    CampaignGroupRewound='Spawn',BossWarning='BossWarning',BossHit='BossHit',BossShielded='Shield',
    CampaignGroupStopped='Crash',CampaignBombDefused='Bomb',EnemyDeath='EnemyDeath',
    ClubEquipped='Equip',RavenClawPickedUp='Equip',GuardianBallPickedUp='Equip',DragonMounted='Equip',
    LifeStolen='Death'}
local fx={Hit='hit',Shield='shield',Club='hit',Fly='heal',Spawn='spawn',BossWarning='warning',BossHit='hit',
    Crash='crash',Bomb='result',Victory='result',Defeat='death',Death='death',EnemyDeath='death'}

function Audio.new(deps,catalog)
    deps=deps or {};catalog=catalog or defaultCatalog()
    local self=setmetatable({catalog=catalog,voices={},nextVoice=1,cursor=nil,heroStates={},muted=false,musicMuted=false,
        effects=deps.effects or defaultEffects(deps),createVoice=deps.createVoice},Audio)
    if not self.createVoice and (asset((catalog.assets or {}).sfx) or asset((catalog.assets or {}).music)) then
        self.createVoice,self.cleanup=nativeFactory(deps)
    end
    if self.createVoice then
        local ids=catalog.assets or {}
        if asset(ids.sfx) then for i=1,8 do local ok,v=pcall(self.createVoice,'sfx',i,ids.sfx);if ok and v then self.voices[#self.voices+1]=v end end end
        if asset(ids.music) then local ok,v=pcall(self.createVoice,'music',1,ids.music);if ok then self.music=v end end
    end
    -- Preloading never schedules playback: an impact missed while loading stays missed.
    if not deps.createVoice and (#self.voices>0 or self.music) then
        local preload={}
        if self.voices[1] and self.voices[1].sound then preload[#preload+1]=self.voices[1].sound end
        if self.music and self.music.sound then preload[#preload+1]=self.music.sound end
        local provider=deps.contentProvider or game:GetService('ContentProvider')
        task.spawn(function() pcall(function() provider:PreloadAsync(preload) end) end)
    end
    return self
end
function Audio:_stop()
    for _,v in ipairs(self.voices) do call(v,'stop') end;call(self.music,'stop');self.musicKey=nil
end
function Audio:_reset(scope)
    self:_stop();call(self.effects,'reset');self.scope=scope;self.cursor=nil;self.heroStates={};self.bossState=nil;self.nextVoice=1
    if scope==nil then self.contextScope=nil;self.ownerSlot=nil;self.ownerActor=nil end
end
function Audio:_cue(key,event,data)
    if self.destroyed then return end
    local row=(self.catalog.cues or {})[key]
    if not self.muted and region(row) and #self.voices>0 then
        local voice=self.voices[self.nextVoice];self.nextVoice=self.nextVoice%#self.voices+1
        call(voice,'play',row,false,math.clamp(row.volume or .36,0,.7),key)
    end
    if fx[key] then call(self.effects,'emit',fx[key],event or {},data) end
end
function Audio:_music(data)
    local key
    local level=type(data.level)=='table' and data.level or {}
    local boss=type(level.boss)=='table' and level.boss or {}
    if data.status=='Won' or data.status=='Lost' then key='Result'
    elseif data.status=='Lobby' then key='Lobby'
    elseif data.status=='Active' and data.view~='Menu' then
        key=(level.stage=='Boss' or level.stage=='Chase' or level.stage=='BossReady'
            or level.bossType and boss.bossDefeated~=true) and 'Boss' or 'Level'
    end
    if self.muted or self.musicMuted then key=nil end
    if key~=self.musicKey then
        call(self.music,'stop');self.musicKey=nil
        local row=key and (self.catalog.music or {})[key]
        if region(row) then local ok,played=call(self.music,'play',row,true,math.clamp(row.volume or .22,0,.5),key);if ok and played then self.musicKey=key end end
    end
end
function Audio:_transitions(data,baseline,played)
    local nextHeroes={}
    for i=1,math.min(type(data.heroes)=='table' and #data.heroes or 0,3) do
        local hero=data.heroes[i]
        if type(hero)=='table' and finite(hero.slot) then
            local prev=self.heroStates[hero.slot]
            local dead=hero.dying==true or hero.status=='AwaitingRespawn' or hero.status=='Eliminated'
            local same=prev and (hero.actorId==nil or hero.actorId==prev.actorId) and hero.attempt==prev.attempt
            if not baseline and same and dead and not prev.dead then
                self:_cue('Death',{slot=hero.slot,actorId=hero.actorId or prev.actorId},data)
            end
            nextHeroes[hero.slot]={actorId=hero.actorId or prev and prev.actorId,attempt=hero.attempt,dead=dead}
        end
    end
    self.heroStates=nextHeroes
    local boss=type(data.level)=='table' and type(data.level.boss)=='table' and data.level.boss or nil
    if boss then
        local prev=self.bossState
        if not baseline and prev then
            if boss.bossState=='Tell' and (prev.state~='Tell' or prev.attack~=boss.bossAttack) and not played.BossWarning then
                self:_cue('BossWarning',{slot=-99},data)
            end
            if (finite(boss.rawLife) and finite(prev.life) and boss.rawLife<prev.life
                or finite(boss.progress) and finite(prev.progress) and boss.progress>prev.progress) and not played.BossHit then
                self:_cue('BossHit',{slot=-99},data)
            end
        end
        self.bossState={state=boss.bossState,attack=boss.bossAttack,life=boss.rawLife,progress=boss.progress}
    else self.bossState=nil end
end
function Audio:sync(data,_confirmed)
    if self.destroyed or type(data)~='table' or not integer(data.snapshotSeq) or data.snapshotSeq<1
        or self.snapshotSeq and data.snapshotSeq<=self.snapshotSeq then return false end
    self.snapshotSeq=data.snapshotSeq
    if not identity(data.groupId) or not finite(data.now) or data.status=='Faulted' then self:_reset(nil);return false end
    local slot,actor,attempt=owner(data)
    local run=identity(data.runId) and data.runId or data.status=='Lobby' and 'lobby' or nil
    if not run or run~='lobby' and not integer(data.levelEpoch) then self:_reset(nil);return false end
    local context=tostring(#data.groupId)..':'..data.groupId..':'..run..':'..tostring(data.levelEpoch)
    local replacedOwner=self.contextScope==context and self.ownerSlot==slot and identity(actor)
        and identity(self.ownerActor) and actor~=self.ownerActor
    local previousCursor=self.cursor
    local ownerKey=slot and tostring(slot)..':'..(identity(actor) and actor or self.ownerSlot==slot and self.ownerActor or 'pending') or 'spectator'
    self.ownerSlot,self.ownerActor=slot,identity(actor) and actor or self.ownerSlot==slot and self.ownerActor or nil
    local scope=context..':'..ownerKey
    local baseline=self.scope~=scope
    if baseline then self:_reset(scope) end
    self.contextScope=context
    call(self.effects,'sync',data)
    self:_music(data)
    local feed=data.feedback
    local validFeed=type(feed)=='table' and integer(feed.latestSeq) and type(feed.events)=='table' and #feed.events<=12
    baseline=baseline or self.cursor==nil
    local played={}
    local active=(data.status=='Active' and data.view~='Menu') or data.status=='Won' or data.status=='Lost'
    if validFeed then
        local minimum=if baseline then (replacedOwner and previousCursor or nil) else self.cursor
        if minimum and active and feed.latestSeq>minimum then
            local now=finite(data.serverNow) and math.max(data.now,data.serverNow) or data.now
            local pending,seen={},{}
            for _,e in ipairs(feed.events) do
                if type(e)=='table' and integer(e.seq) and e.seq>minimum and e.seq<=feed.latestSeq
                    and finite(e.now) and e.now<=now+.5 and now-e.now<=3 and e.levelEpoch==data.levelEpoch then pending[#pending+1]=e end
            end
            table.sort(pending,function(a,b) return a.seq<b.seq end)
            for _,e in ipairs(pending) do
                local relevant=true
                -- A new owner body still discards history. Only its new confirmed
                -- respawn, beyond the old cursor in this same context, may cross.
                if baseline then
                    relevant=e.kind=='CommitSpawn' and e.slot==slot and e.actorId==actor
                        and integer(e.attempt) and e.attempt>1 and e.attempt==attempt
                end
                if e.actorId then
                    for i=1,math.min(type(data.heroes)=='table' and #data.heroes or 0,3) do local h=data.heroes[i]
                        if h.slot==e.slot and identity(h.actorId) and h.actorId~=e.actorId then relevant=false end
                    end
                end
                if relevant and not seen[e.seq] then
                    seen[e.seq]=true
                    local key=cues[e.kind]
                    if e.kind=='Hit' or e.kind=='EnemyHit' then
                        key=e.blocked and 'Shield' or e.action=='Club' and 'Club' or 'Hit'
                    elseif e.kind=='RunResult' then key=e.result=='Won' and 'Victory' or e.result=='Lost' and 'Defeat' or nil end
                    if key then self:_cue(key,e,data);played[key]=true end
                end
            end
        end
        self.cursor=math.max(self.cursor or 0,feed.latestSeq)
    end
    self:_transitions(data,baseline or not active,played)
    return true
end
function Audio:setMuted(value) self.muted=value==true;if self.muted then self:_stop() end end
function Audio:setMusicMuted(value) self.musicMuted=value==true;if self.musicMuted then call(self.music,'stop');self.musicKey=nil end end
function Audio:setEffectsEnabled(value) call(self.effects,'setEnabled',value) end
function Audio:setReducedFlash(value) call(self.effects,'setReducedFlash',value) end
function Audio:diagnostics()
    local loaded=#self.voices==8 and self.music~=nil
    for _,v in ipairs(self.voices) do local ok,ready=call(v,'isLoaded');loaded=loaded and ok and ready==true end
    local ok,ready=call(self.music,'isLoaded');loaded=loaded and ok and ready==true
    return {ready=loaded and not self.destroyed,configured=asset((self.catalog.assets or {}).sfx) and asset((self.catalog.assets or {}).music),
        sfxVoices=#self.voices,sfxLimit=8,music=self.musicKey,scope=self.scope,cursor=self.cursor,destroyed=self.destroyed==true}
end
function Audio:destroy()
    if self.destroyed then return end
    self:_stop();for _,v in ipairs(self.voices) do call(v,'destroy') end;call(self.music,'destroy');call(self.effects,'destroy')
    if self.cleanup then pcall(self.cleanup) end;self.destroyed=true
end
return Audio
