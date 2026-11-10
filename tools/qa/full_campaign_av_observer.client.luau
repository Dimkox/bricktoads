-- Append to the disposable BrickToadsClient AFTER the normal client and input
-- adapter. Uses their existing locals; do not install as a separate LocalScript.
-- Studio-only observation: no gameplay, camera, visibility, audio or load writes.
-- Optional script attribute AVExpectedRunId binds the capture to a specific run.
-- _G.BrickToadsFullCampaignAV.summary() returns a detached, JSON-safe snapshot.
-- _G.BrickToadsFullCampaignAV.destroy() disconnects only this observer.
-- PlayerScripts.BrickToadsFullCampaignAV:Invoke('summary' | 'destroy') is local.
do (function()
    assert(RunService:IsStudio() and RunService:IsClient(), 'Studio client observer only')
    assert(gameAudio and castAssetVisibility and courseAssetVisibility and stateRemote, 'Append after BrickToadsClient')
    local previous = _G.BrickToadsFullCampaignAV
    if previous and type(previous.destroy) == 'function' then previous.destroy() end
    local Collection = game:GetService('CollectionService')
    local Log = game:GetService('LogService')
    local Errors = game:GetService('ScriptContext')
    local Content = game:GetService('ContentProvider') -- status reads only; never requests content
    local COURSE_TAG = 'BrickToadsCourseSkin'
    local COURSE_KINDS = {'Speeder', 'Surfboard', 'Jet', 'ClingerVehicle', 'Other'}
    local TAG, INTERVAL, SAMPLE_LIMIT, EVENT_LIMIT = 'BrickToadsCastSkin', .5, 12, 20
    local MAX_SECONDS = 10800
    local started = workspace:GetServerTimeNow()
    local boundRun = script:GetAttribute('AVExpectedRunId')
    assert(boundRun == nil or type(boundRun) == 'string' and #boundRun > 0, 'Invalid AVExpectedRunId')
    local boundGroup, lastIdentity, lastAt, currentIndex
    local connections, soundConnections, watchedSounds, jointHistory = {}, {}, {}, {}
    local out = {
        schema = 1, observer = 'ReadOnlyClientAV', startedAt = started, running = true,
        sampleInterval = INTERVAL, sampleLimitPerStage = SAMPLE_LIMIT, eventLimitPerStage = EVENT_LIMIT,
        stageCount = 13, stages = {}, transitions = {}, console = {}, consoleCount = 0,
        limitations = {
            'Samples and Sound.Played events prove observed runtime state, not human audibility or pixel correctness.',
            'Absent instances are not proof of asset-load failure or streaming; no stream-out reason is exposed.',
            'CharacterAppearance publishes Template/Appearance only; source frame and activeMorph are unavailable unless separately attributed.',
            'firstObservedLoadedAt is an observation timestamp, never an asset loading duration.',
            'knownFallbackTargets counts observed in-world references with matching current backlink/alpha metadata; it is not a gate API result.',
        },
    }
    for index = 1, 13 do
        out.stages[index] = {index = index, observed = false, sampleCount = 0, samples = {},
            consoleCount = 0, audioEventCount = 0, audioEvents = {}, sounds = {},
            gateStates = {}, visualStates = {}, maxParticles = 0, particleSamples = 0,
            courseKinds = {}, courseGateStates = {}, maxCourseTagged = 0, maxCourseStructures = 0,
            maxTaggedCast = 0, zeroTaggedSamples = 0, sourceStateUnavailableSamples = 0}
    end
    local function finite(v) return type(v) == 'number' and v == v and math.abs(v) < math.huge end
    local function num(v) return finite(v) and v or nil end
    local function text(v, limit) return type(v) == 'string' and string.sub(v, 1, limit or 240) or nil end
    local function ring(list, value, limit)
        list[#list + 1] = value
        if #list > limit then table.remove(list, 1) end
    end
    local function clone(value)
        if type(value) ~= 'table' then return value end
        local copy = {}
        for k, v in pairs(value) do copy[k] = clone(v) end
        return copy
    end
    local function connect(list, event, fn) list[#list + 1] = event:Connect(fn) end
    local function increment(map, key)
        -- Keys come from bounded current production enums/names, capped defensively.
        if type(key) ~= 'string' then key = 'Unavailable' end
        key = string.sub(key, 1, 120)
        if map[key] == nil then
            local count = 0
            for _ in pairs(map) do count += 1 end
            if count >= 64 then key = 'Other' end
        end
        map[key] = (map[key] or 0) + 1
    end
    local function stage()
        local data = snapshot -- the accepted production snapshot, never a second sync
        if type(data) ~= 'table' or type(data.level) ~= 'table'
            or type(data.runId) ~= 'string' or data.runId == '' or data.status == 'Lobby' then return end
        local index = data.level.campaignIndex or 1
        if not finite(index) or index % 1 ~= 0 or index < 1 or index > 13 then return end
        if boundRun and boundRun ~= data.runId or boundGroup and boundGroup ~= data.groupId then return end
        if not boundRun then boundRun = data.runId end
        if not boundGroup then boundGroup = data.groupId end
        local row = out.stages[index]
        local now = workspace:GetServerTimeNow()
        local identityKey = table.concat({data.runId, tostring(index), tostring(data.levelEpoch),
            tostring(data.level.stage), tostring(data.status), tostring(data.view)}, ':')
        if identityKey ~= lastIdentity then
            ring(out.transitions, {at = now, index = index, epoch = num(data.levelEpoch),
                stage = text(data.level.stage), status = text(data.status), view = text(data.view),
                snapshotSeq = num(data.snapshotSeq)}, 96)
            if currentIndex ~= index then jointHistory = {} end
            currentIndex, lastIdentity = index, identityKey
        end
        if not row.observed then row.firstObservedAt = now end
        row.observed, row.lastObservedAt = true, now
        row.levelName, row.mode = text(data.level.levelName), text(data.level.mode)
        out.runId, out.groupId, out.currentIndex, out.lastStatus = boundRun, boundGroup, index, text(data.status)
        return row, data, now
    end
    local function alpha(part)
        return 1 - (1 - part.Transparency) * (1 - part.LocalTransparencyModifier)
    end
    local function stringValue(parent, name)
        local v = parent:FindFirstChild(name)
        return v and v:IsA('StringValue') and text(v.Value) or nil
    end
    local function sourceAttrs(model)
        return {namespace = text(model:GetAttribute('SourceGraphicsNamespace')),
            frame = num(model:GetAttribute('SourceGraphicsFrame')), state = text(model:GetAttribute('VisualState')),
            activeMorph = text(model:GetAttribute('ActiveMorph'))}
    end
    local function soundSample(sound)
        local playback, loop = sound.PlaybackRegion, sound.LoopRegion
        return {name = text(sound.Name), soundId = text(sound.SoundId), loaded = sound.IsLoaded,
            timeLength = num(sound.TimeLength), playing = sound.IsPlaying, loudness = num(sound.PlaybackLoudness),
            timePosition = num(sound.TimePosition), volume = num(sound.Volume), playbackSpeed = num(sound.PlaybackSpeed),
            looped = sound.Looped, regionsEnabled = sound.PlaybackRegionsEnabled,
            playbackRegion = {min = num(playback.Min), max = num(playback.Max)},
            loopRegion = {min = num(loop.Min), max = num(loop.Max)}}
    end
    local function observeSound(row, sample, now, event)
        local key = sample.name
        local summary = row.sounds[key]
        if not summary then
            local count = 0
            for _ in pairs(row.sounds) do count += 1 end
            if count >= 16 then return end
            summary = {soundId = sample.soundId, samples = 0, loadedSamples = 0, playingSamples = 0,
                loudSamples = 0, playedEvents = 0, maxLoudness = 0, invalidPlayingRegionSamples = 0}
            row.sounds[key] = summary
        end
        if event == 'Played' then summary.playedEvents += 1 end
        if event then return end
        summary.samples += 1
        if sample.loaded then
            summary.loadedSamples += 1
            summary.firstObservedLoadedAt = summary.firstObservedLoadedAt or now
        end
        if sample.playing then summary.playingSamples += 1 end
        if (sample.loudness or 0) > 0 then summary.loudSamples += 1 end
        summary.maxLoudness = math.max(summary.maxLoudness, sample.loudness or 0)
        summary.last = sample
        if sample.playing and sample.loaded and (sample.timeLength or 0) > 0 and sample.regionsEnabled
            and ((sample.playbackRegion.max or 0) > sample.timeLength + .03
                or (sample.playbackRegion.max or 0) <= (sample.playbackRegion.min or 0)) then
            summary.invalidPlayingRegionSamples += 1
        end
    end
    local function watch(sound)
        if watchedSounds[sound] then return end
        watchedSounds[sound] = true
        for _, name in ipairs({'Played', 'Stopped', 'Ended', 'DidLoop', 'Loaded'}) do
            connect(soundConnections, sound[name], function()
                if not out.running then return end
                local row, _, now = stage()
                if not row then return end
                local sample = soundSample(sound)
                row.audioEventCount += 1
                observeSound(row, sample, now, name)
                ring(row.audioEvents, {at = now, event = name, sound = sample}, EVENT_LIMIT)
            end)
        end
    end
    local function sounds(row, now)
        local samples = {}
        for _, voice in ipairs(gameAudio.voices or {}) do
            if voice.sound and voice.sound.Parent then
                watch(voice.sound)
                local sample = soundSample(voice.sound)
                samples[#samples + 1] = sample
                observeSound(row, sample, now)
            end
        end
        local music = gameAudio.music and gameAudio.music.sound
        if music and music.Parent then
            watch(music)
            local sample = soundSample(music)
            samples[#samples + 1] = sample
            observeSound(row, sample, now)
        end
        return samples
    end
    local function findWorld(data)
        for _, child in ipairs(workspace:GetChildren()) do
            if child:GetAttribute('GroupId') == data.groupId and child:FindFirstChild('Actors') then return child end
        end
    end
    local function cast(world, row)
        local result = {taggedPresent = 0, rows = {}, truncated = 0}
        for _, skin in ipairs(Collection:GetTagged(TAG)) do
            if world and skin:IsDescendantOf(world) and skin:IsA('Model') then
                result.taggedPresent += 1
                if #result.rows < 32 then
                    local owner, gate = skin.Parent, castAssetVisibility.rows[skin]
                    local item = {name = text(skin.Name), skinId = text(skin:GetAttribute('CastSkinId')),
                        canonicalTag = skin:GetAttribute('CanonicalCastSkin') == true,
                        actorId = owner and text(tostring(owner:GetAttribute('ActorId'))),
                        kind = stringValue(skin, 'CastKind'), source = sourceAttrs(skin),
                        gateState = gate and gate.state or 'Untracked', attempts = gate and gate.entry and gate.entry.attempts,
                        meshParts = 0, visibleMeshParts = 0, fallbackTargets = 0, visibleFallbackTargets = 0}
                    for _, part in ipairs(skin:GetDescendants()) do
                        if part:IsA('MeshPart') then
                            item.meshParts += 1
                            if alpha(part) < .99 then item.visibleMeshParts += 1 end
                        end
                    end
                    for _, ref in ipairs(skin:GetChildren()) do
                        if ref:IsA('ObjectValue') and ref.Name == 'CastFallbackTarget' and ref.Value
                            and ref.Value:IsA('BasePart') and ref.Value:IsDescendantOf(workspace) then
                            item.fallbackTargets += 1
                            if alpha(ref.Value) < .99 then item.visibleFallbackTargets += 1 end
                        end
                    end
                    item.visibility = item.meshParts == 0 and 'PresentSkinWithoutMeshes'
                        or item.visibleMeshParts > 0 and (item.visibleFallbackTargets > 0 and 'CanonicalAndFallback' or 'Canonical')
                        or item.visibleFallbackTargets > 0 and 'Fallback' or 'NoVisibleParts'
                    increment(row.gateStates, item.gateState)
                    increment(row.visualStates, item.source.state)
                    result.rows[#result.rows + 1] = item
                else result.truncated += 1 end
            end
        end
        row.maxTaggedCast = math.max(row.maxTaggedCast, result.taggedPresent)
        if result.taggedPresent == 0 then row.zeroTaggedSamples += 1 end
        return result
    end
    local function course(world, row)
        local result = {gate = courseAssetVisibility:diagnostics(), taggedPresent = 0, rows = {}, truncated = 0,
            byKind = {}, structures = {geometryPresent = false, modelsPresent = 0, modelsInspected = 0,
                uninspectedModels = 0, parts = 0, inspectedParts = 0, uninspectedParts = 0, visibleParts = 0, unsafeParts = 0}}
        for _, kind in ipairs(COURSE_KINDS) do
            result.byKind[kind] = {instances = 0, ready = 0, pending = 0, failed = 0, untracked = 0,
                meshParts = 0, visibleMeshParts = 0, fallbackTargets = 0, knownFallbackTargets = 0, visibleFallbackTargets = 0}
        end
        local function content(list, role, id)
            if type(id) ~= 'string' or id == '' then return end
            local ok, status = pcall(function() return Content:GetAssetFetchStatus(id) end)
            list[#list + 1] = {role = role, id = text(id, 512), status = ok and text(tostring(status)) or 'ReadUnavailable',
                readError = not ok and text(tostring(status), 120) or nil}
        end
        for _, skin in ipairs(Collection:GetTagged(COURSE_TAG)) do
            if world and skin:IsA('Model') and skin:IsDescendantOf(world) then
                result.taggedPresent += 1
                local kind = stringValue(skin, 'CourseKind')
                local counts = result.byKind[kind] or result.byKind.Other
                local gate = courseAssetVisibility.rows[skin]
                local id = skin:GetAttribute('CourseSkinId')
                local item = {kind = kind, skinId = text(id), canonicalTag = skin:GetAttribute('CanonicalCourseSkin') == true,
                    ownerProfile = skin.Parent and text(skin.Parent:GetAttribute('CourseAppearance')),
                    gateState = gate and gate.state or 'Untracked', entryState = gate and gate.entry and text(gate.entry.state),
                    attempts = gate and gate.entry and num(gate.entry.attempts),
                    meshParts = 0, visibleMeshParts = 0, meshes = {}, meshDetailsTruncated = 0,
                    fallbackTargets = 0, knownFallbackTargets = 0, visibleFallbackTargets = 0,
                    fallbacks = {}, fallbackDetailsTruncated = 0}
                local keep = #result.rows < 16
                for _, p in ipairs(skin:GetDescendants()) do
                    if p:IsA('MeshPart') then
                        item.meshParts += 1
                        if alpha(p) < .99 then item.visibleMeshParts += 1 end
                        if keep and #item.meshes < 8 then
                            local detail = {name = text(p.Name), transparency = num(p.Transparency),
                                localTransparencyModifier = num(p.LocalTransparencyModifier), effectiveAlpha = num(alpha(p)),
                                visibleTransparency = num(p:GetAttribute('CourseVisibleTransparency')), contents = {}}
                            content(detail.contents, 'MeshId', p.MeshId)
                            content(detail.contents, 'TextureID', p.TextureID)
                            for _, surface in ipairs(p:GetChildren()) do
                                if surface:IsA('SurfaceAppearance') then
                                    for _, map in ipairs({'ColorMap', 'NormalMap', 'RoughnessMap', 'MetalnessMap'}) do
                                        -- Each native course resource has one SurfaceAppearance; cap corrupted duplicates.
                                        if #detail.contents < 10 then content(detail.contents, map, surface[map]) end
                                    end
                                end
                            end
                            item.meshes[#item.meshes + 1] = detail
                        else item.meshDetailsTruncated += 1 end
                    end
                end
                for _, ref in ipairs(skin:GetChildren()) do
                    local p = ref:IsA('ObjectValue') and ref.Name == 'CourseFallbackTarget' and ref.Value
                    if p and p:IsA('BasePart') and p:IsDescendantOf(workspace) then
                        item.fallbackTargets += 1
                        local backlink, declared = p:GetAttribute('CourseFallbackOwner'), p:GetAttribute('CourseFallbackTransparency')
                        local inWorld = p:IsDescendantOf(world)
                        local known = inWorld and backlink == id and finite(declared) and declared >= 0 and declared <= 1
                        if known then item.knownFallbackTargets += 1 end
                        if alpha(p) < .99 then item.visibleFallbackTargets += 1 end
                        if keep and #item.fallbacks < 4 then
                            item.fallbacks[#item.fallbacks + 1] = {name = text(p.Name), inWorld = inWorld, known = known,
                                owner = text(backlink), declaredTransparency = num(declared), transparency = num(p.Transparency),
                                localTransparencyModifier = num(p.LocalTransparencyModifier), effectiveAlpha = num(alpha(p)),
                                gateSavedLocalAlpha = gate and gate.fallbackSaved and num(gate.fallbackSaved[p])}
                        else item.fallbackDetailsTruncated += 1 end
                    end
                end
                item.visibility = item.meshParts == 0 and 'PresentSkinWithoutMeshes'
                    or item.visibleMeshParts > 0 and (item.visibleFallbackTargets > 0 and 'CanonicalAndFallback' or 'Canonical')
                    or item.visibleFallbackTargets > 0 and 'Fallback' or 'NoVisibleParts'
                counts.instances += 1
                local state = string.lower(item.gateState)
                if counts[state] ~= nil then counts[state] += 1 else counts.untracked += 1 end
                for _, key in ipairs({'meshParts', 'visibleMeshParts', 'fallbackTargets', 'knownFallbackTargets', 'visibleFallbackTargets'}) do
                    counts[key] += item[key]
                end
                increment(row.courseGateStates, item.gateState)
                if keep then result.rows[#result.rows + 1] = item else result.truncated += 1 end
            end
        end
        result.presence = not world and 'WorldNotPresent'
            or result.taggedPresent == 0 and 'NoTaggedCourseSkinsOnClient' or 'TaggedCourseSkinsPresent'
        local geometry = world and world:FindFirstChild('Geometry')
        local structures = result.structures
        structures.geometryPresent = geometry ~= nil
        if geometry then
            for _, model in ipairs(geometry:GetChildren()) do
                if model:IsA('Model') and model:GetAttribute('CourseAppearance') == 'AuthoredIndustrialCourseStructure' then
                    structures.modelsPresent += 1
                    if structures.modelsInspected < 128 then
                        structures.modelsInspected += 1
                        local inspected = 0
                        for _, p in ipairs(model:GetDescendants()) do
                            if p:IsA('BasePart') then
                                structures.parts += 1
                                if inspected < 64 then
                                    inspected += 1; structures.inspectedParts += 1
                                    if alpha(p) < .99 then structures.visibleParts += 1 end
                                    if p.CanCollide or p.CanTouch or p.CanQuery or not p.Anchored then structures.unsafeParts += 1 end
                                else structures.uninspectedParts += 1 end
                            end
                        end
                    else structures.uninspectedModels += 1 end
                end
            end
        end
        structures.partCountComplete = structures.uninspectedModels == 0 and structures.uninspectedParts == 0
        row.maxCourseTagged = math.max(row.maxCourseTagged, result.taggedPresent)
        row.maxCourseStructures = math.max(row.maxCourseStructures, structures.modelsPresent)
        for _, kind in ipairs(COURSE_KINDS) do
            local counts = result.byKind[kind]
            local summary = row.courseKinds[kind]
            if not summary then
                summary = {samples = 0, maxInstances = 0, absentSamples = 0, readySamples = 0, pendingSamples = 0,
                    failedSamples = 0, canonicalVisibleSamples = 0, fallbackVisibleSamples = 0, knownFallbackSamples = 0}
                row.courseKinds[kind] = summary
            end
            summary.samples += 1; summary.maxInstances = math.max(summary.maxInstances, counts.instances)
            if counts.instances == 0 then summary.absentSamples += 1 end
            if counts.ready > 0 then summary.readySamples += 1 end
            if counts.pending > 0 then summary.pendingSamples += 1 end
            if counts.failed > 0 then summary.failedSamples += 1 end
            if counts.visibleMeshParts > 0 then summary.canonicalVisibleSamples += 1 end
            if counts.visibleFallbackTargets > 0 then summary.fallbackVisibleSamples += 1 end
            if counts.knownFallbackTargets > 0 then summary.knownFallbackSamples += 1 end
        end
        return result
    end
    local function actors(world, data, row)
        local folder = world and world:FindFirstChild('Actors')
        local byActor, byName = {}, {}
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                byActor[tostring(model:GetAttribute('ActorId'))], byName[model.Name] = model, model
            end
        end
        local result = {heroes = {}, liveEnemiesExpected = 0, liveEnemiesPresent = 0,
            presentEnemiesWithoutTaggedSkin = 0, absentEnemyModels = {}, absentEnemyModelsTruncated = 0}
        for _, enemy in ipairs(data.level.enemies or {}) do
            if enemy.dead ~= true then
                result.liveEnemiesExpected += 1
                local model = enemy.actorId and byActor[tostring(enemy.actorId)] or byName['Actor_' .. tostring(enemy.id)]
                if model then
                    result.liveEnemiesPresent += 1
                    local tagged = false
                    for _, child in ipairs(model:GetChildren()) do if Collection:HasTag(child, TAG) then tagged = true end end
                    if not tagged then result.presentEnemiesWithoutTaggedSkin += 1 end
                elseif #result.absentEnemyModels < 24 then
                    result.absentEnemyModels[#result.absentEnemyModels + 1] = {id = num(enemy.id), kind = text(enemy.kind),
                        state = 'ModelAbsentClientReasonUnknown', streamingPossible = workspace.StreamingEnabled}
                else result.absentEnemyModelsTruncated += 1 end
            end
        end
        result.castPresence = not folder and 'WorldOrActorsNotPresent'
            or result.liveEnemiesExpected == 0 and 'NoLiveEnemiesInSnapshot'
            or result.liveEnemiesPresent == 0 and 'LiveEnemyModelsNotPresent'
            or 'LiveEnemyModelsPresent'
        for index = 1, math.min(#(data.heroes or {}), 3) do
            local hero = data.heroes[index]
            local model = hero.actorId and byActor[tostring(hero.actorId)]
            local item = {slot = num(hero.slot), actorId = text(hero.actorId), status = text(hero.status), present = model ~= nil}
            if model then
                item.template, item.appearance = text(model:GetAttribute('Template')), text(model:GetAttribute('Appearance'))
                item.source = sourceAttrs(model)
                item.sourceStatePublished = item.source.frame ~= nil or item.source.state ~= nil
                item.baseMeshParts, item.visibleBaseMeshParts, item.changedJoints, item.morphs = 0, 0, 0, {}
                local appearance
                for _, child in ipairs(model:GetChildren()) do
                    if child:IsA('Model') and stringValue(child, 'AppearanceProfile') then appearance = child; break end
                end
                if appearance then
                    item.resourceName = text(appearance.Name)
                    item.resourceProfile = stringValue(appearance, 'AppearanceProfile')
                    item.resourceSource = sourceAttrs(appearance)
                    item.paletteAdaptation = text(appearance:GetAttribute('PaletteAdaptation'))
                    local prior = jointHistory[hero.slot]
                    local nextJoints = {actorId = hero.actorId, motors = {}}
                    for _, child in ipairs(appearance:GetDescendants()) do
                        if child:IsA('Motor6D') then
                            nextJoints.motors[child.Name] = child.C0
                            if prior and prior.actorId == hero.actorId and prior.motors[child.Name]
                                and prior.motors[child.Name] ~= child.C0 then item.changedJoints += 1 end
                        elseif child:IsA('MeshPart') and child.Parent == appearance then
                            item.baseMeshParts += 1
                            if alpha(child) < .99 then item.visibleBaseMeshParts += 1 end
                        elseif child:IsA('Model') and stringValue(child, 'MorphKind') and #item.morphs < 8 then
                            local p = child:FindFirstChild('Morph')
                            item.morphs[#item.morphs + 1] = {kind = stringValue(child, 'MorphKind'),
                                present = p ~= nil, visible = p ~= nil and p:IsA('BasePart') and alpha(p) < .99}
                        end
                    end
                    jointHistory[hero.slot] = nextJoints
                end
                if not item.sourceStatePublished then row.sourceStateUnavailableSamples += 1 end
            else
                item.absence = 'ModelAbsentClientReasonUnknown'
                item.streamingPossible = workspace.StreamingEnabled
            end
            result.heroes[#result.heroes + 1] = item
        end
        return result
    end
    local function particles(data, row)
        local folder = workspace:FindFirstChild('BrickToadsLocalEffects')
        local result = {present = folder ~= nil, matchingGroup = folder ~= nil and folder:GetAttribute('GroupId') == data.groupId,
            parts = 0, visibleParts = 0, unsafeParts = 0, kinds = {}}
        if folder and result.matchingGroup then
            for _, p in ipairs(folder:GetChildren()) do
                if p:IsA('BasePart') then
                    result.parts += 1
                    if alpha(p) < .99 then result.visibleParts += 1 end
                    if p.CanCollide or p.CanTouch or p.CanQuery or not p.Anchored then result.unsafeParts += 1 end
                    increment(result.kinds, p.Name)
                end
            end
        end
        row.maxParticles = math.max(row.maxParticles, result.parts)
        if result.parts > 0 then row.particleSamples += 1 end
        return result
    end
    local function sample(force)
        if not out.running then return end
        local row, data, now = stage()
        if not row or not force and lastAt and now - lastAt < INTERVAL then return end
        lastAt = now
        local world = findWorld(data)
        local item = {at = now, snapshotSeq = num(data.snapshotSeq), epoch = num(data.levelEpoch),
            status = text(data.status), stage = text(data.level.stage), view = text(data.view),
            worldPresent = world ~= nil, streamingEnabled = workspace.StreamingEnabled,
            audio = gameAudio:diagnostics(), muted = gameAudio.muted, musicMuted = gameAudio.musicMuted,
            gate = castAssetVisibility:diagnostics(), sounds = sounds(row, now),
            cast = cast(world, row), course = course(world, row),
            actors = actors(world, data, row), particles = particles(data, row)}
        row.sampleCount += 1
        if not row.firstSample then row.firstSample = item end
        ring(row.samples, item, SAMPLE_LIMIT)
    end
    local function console(kind, message, stack, source)
        if not out.running then return end
        local row, _, now = stage()
        out.consoleCount += 1
        if row then row.consoleCount += 1 end
        ring(out.console, {at = now or workspace:GetServerTimeNow(), index = row and row.index,
            kind = kind, message = text(message, 900), stack = text(stack, 1800), source = text(source, 240)}, 64)
    end
    connect(connections, Log.MessageOut, function(message, kind)
        if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
            console(tostring(kind), message)
        end
    end)
    connect(connections, Errors.Error, function(message, stack, source)
        console('ScriptContext.Error', message, stack, source and source:GetFullName())
    end)
    local api = {}
    local endpoint = Instance.new('BindableFunction')
    endpoint.Name = 'BrickToadsFullCampaignAV'
    endpoint.Parent = player:FindFirstChild('PlayerScripts') or script.Parent
    function api.summary()
        local result = clone(out)
        result.exportedAt = workspace:GetServerTimeNow()
        result.observedStageCount = 0
        for _, row in ipairs(result.stages) do if row.observed then result.observedStageCount += 1 end end
        return result
    end
    function api.destroy(reason)
        if not out.running then return api.summary() end
        -- A malformed/destroying runtime object must not defeat teardown.
        pcall(sample, true)
        out.running, out.stoppedAt, out.stopReason = false, workspace:GetServerTimeNow(), text(reason) or 'Requested'
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, connection in ipairs(soundConnections) do connection:Disconnect() end
        table.clear(connections); table.clear(soundConnections); table.clear(watchedSounds); table.clear(jointHistory)
        endpoint:Destroy()
        -- Keep the detached final summary callable through _G after teardown.
        return api.summary()
    end
    endpoint.OnInvoke = function(command)
        if command == 'destroy' then return api.destroy('BindableFunction') end
        assert(command == nil or command == 'summary', 'Unknown AV observer command')
        return api.summary()
    end
    _G.BrickToadsFullCampaignAV = api
    connect(connections, stateRemote.OnClientEvent, function()
        -- Production's existing handler owns validation and snapshot acceptance.
        task.defer(function() if out.running then stage() end end)
    end)
    connect(connections, RunService.Heartbeat, function()
        if workspace:GetServerTimeNow() - started >= MAX_SECONDS then api.destroy('TimeBound'); return end
        local ok, problem = pcall(sample, false)
        if not ok then console('ObserverError', tostring(problem)); api.destroy('ObserverError') end
    end)
    connect(connections, script.Destroying, function() api.destroy('ClientDestroyed') end)
    sample(true)
end)() end
