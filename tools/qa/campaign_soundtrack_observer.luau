-- Attach after GameAudio:sync in the disposable Studio client. Read-only.
local Http = game:GetService("HttpService")
local catalog = require(game.ReplicatedStorage.BrickToads.AudioCatalog)
local events, cues, mismatches = {}, {}, {}
local lastState
local firstAt = workspace:GetServerTimeNow()
local read = Instance.new("BindableFunction")
read.Name = "ReadCampaignSoundtrack"
read.OnInvoke = function()
    return Http:JSONEncode({events=events,cues=cues,mismatches=mismatches})
end
read.Parent = game.Players.LocalPlayer.PlayerScripts

return function(audio, snapshot)
    local level = snapshot.level or {}
    local index = level.campaignIndex
    local stage = level.stage
    local expected
    if snapshot.status == "Lobby" then
        expected = "Lobby"
    elseif snapshot.status == "Won" or snapshot.status == "Lost" then
        expected = "Result"
    elseif snapshot.status == "Active" and index and snapshot.view ~= "Menu" then
        local boss = stage == "Boss" or stage == "BossIntro" or (stage == "BossReady" and index ~= 11)
        expected = (boss and "Boss" or "Level") .. index
    end
    if not expected then return end
    local sound = audio.music.sound
    local row = assert(catalog.music[expected])
    local now = workspace:GetServerTimeNow()
    local playing = sound.IsPlaying and sound.IsLoaded and sound.SoundId == catalog.assets.music
        and math.abs(sound.LoopRegion.Min-row.start) < .001
        and math.abs(sound.LoopRegion.Max-row.finish) < .001
        and math.abs(sound.PlaybackRegion.Min-row.start) < .001
        and math.abs(sound.PlaybackRegion.Max-row.finish) < .001
    local correct = playing and audio.musicKey == expected
    local state = table.concat({tostring(index), tostring(stage), expected}, "/")
    if state ~= lastState then
        table.insert(events,{t=now-firstAt,stage=stage,index=index,key=audio.musicKey,expected=expected,
            firstSnapshotMatched=correct,pos=sound.TimePosition,seq=snapshot.snapshotSeq,
            runId=snapshot.runId,age=now-(snapshot.serverNow or snapshot.now or now)})
        lastState=state
    end
    local entry = cues[expected] or {samples=0,correct=0,peak=0,start=row.start,finish=row.finish}
    cues[expected]=entry
    entry.samples+=1
    if correct then
        entry.correct+=1
        if sound.TimePosition > row.start+.015 and sound.TimePosition < row.finish then
            entry.peak=math.max(entry.peak,sound.PlaybackLoudness)
        end
    elseif #mismatches<48 then
        table.insert(mismatches,{t=now-firstAt,state=state,key=audio.musicKey,loaded=sound.IsLoaded,
            playing=sound.IsPlaying,seq=snapshot.snapshotSeq})
    end
end
