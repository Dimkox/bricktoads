"""Run the actual appended observer against a read-only Luau runtime fixture.

No Roblox/Studio operations. Verifies evidence semantics, stage/event/sample
bounds, detached exports and teardown, including failure during the final sample.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
LUAU = ROOT / ".tools/luau-0.745/luau.exe"
OBSERVER = Path(__file__).with_name("full_campaign_av_observer.client.luau")

FIXTURE = r"""
local function signal()
    local s = {connections = {}}
    function s:Connect(fn)
        local c = {connected = true, fn = fn}
        function c:Disconnect() self.connected = false end
        self.connections[#self.connections + 1] = c
        return c
    end
    function s:fire(...)
        for _, c in ipairs(self.connections) do if c.connected then c.fn(...) end end
    end
    return s
end
local function node(kind, name, children, attrs)
    local n = {Name = name, children = children or {}, attrs = attrs or {}}
    function n:IsA(want) return kind == want or want == 'BasePart' and (kind == 'MeshPart' or kind == 'Part') end
    function n:GetAttribute(key) return self.attrs[key] end
    function n:GetChildren() return self.children end
    function n:FindFirstChild(name)
        for _, child in ipairs(self.children) do if child.Name == name then return child end end
    end
    function n:GetDescendants()
        local found = {}
        local function visit(parent)
            for _, child in ipairs(parent.children) do found[#found + 1] = child; visit(child) end
        end
        visit(self)
        return found
    end
    function n:IsDescendantOf(parent)
        local p = self.Parent
        while p do if p == parent then return true end; p = p.Parent end
        return false
    end
    function n:GetFullName() return self.Name end
    for _, child in ipairs(n.children) do child.Parent = n end
    return n
end
local function mesh(name, alpha)
    local m = node('MeshPart', name)
    m.Transparency, m.LocalTransparencyModifier = 0, alpha or 0
    return m
end
local profile = node('StringValue', 'AppearanceProfile'); profile.Value = 'CanonicalNESHero'
local motor = node('Motor6D', 'AppearanceWaist'); motor.C0 = 1
local heroChildren = {profile, motor}
for i = 1, 15 do heroChildren[#heroChildren + 1] = mesh('Body' .. i) end
local appearance = node('Model', 'CanonicalPlayer1Appearance', heroChildren)
local hero = node('Model', 'Actor_hero1', {appearance}, {ActorId = 'hero1', Template = 'Mr. Green', Appearance = 'CanonicalNESHero'})
local fallback = mesh('Fallback')
local ref = node('ObjectValue', 'CastFallbackTarget'); ref.Value = fallback
local skinMesh = mesh('Skin', 1)
local kind = node('StringValue', 'CastKind'); kind.Value = 'Pig'
local skin = node('Model', 'PigAppearance', {skinMesh, ref, kind},
    {CanonicalCastSkin = true, CastSkinId = 'skin1', SourceGraphicsNamespace = 'Pig', SourceGraphicsFrame = 1, VisualState = 'Walk'})
local enemy = node('Model', 'Actor_-1', {skin, fallback}, {ActorId = -1, CastAppearance = 'CanonicalNESCast'})
local actorFolder = node('Folder', 'Actors', {hero, enemy})
local courseKinds = {'Speeder', 'Surfboard', 'Jet', 'ClingerVehicle'}
local courseTags, courseRows, courseModels = {}, {}, {}
for i, name in ipairs(courseKinds) do
    local fallback = mesh('CourseFallback_' .. name, i == 1 and 1 or 0)
    fallback.attrs = {CourseFallbackOwner = name .. ':1', CourseFallbackTransparency = .25}
    fallback.Transparency = .25
    local ref = node('ObjectValue', 'CourseFallbackTarget'); ref.Value = fallback
    local part = mesh('CourseMesh_' .. name, (i == 2 or i == 3) and 1 or 0)
    part.MeshId, part.TextureID = 'rbxassetid://' .. (100 + i), ''
    local surface = node('SurfaceAppearance', 'SurfaceAppearance')
    surface.ColorMap, surface.NormalMap, surface.RoughnessMap, surface.MetalnessMap = 'rbxassetid://200', '', '', ''
    part.children = {surface}; surface.Parent = part
    local kind = node('StringValue', 'CourseKind'); kind.Value = name
    local skin = node('Model', name .. 'Appearance', {part, ref, kind},
        {CanonicalCourseSkin = true, CourseSkinId = name .. ':1'})
    local owner = node('Model', 'CourseVehicle_' .. name, {skin}, {CourseAppearance = 'CanonicalCourseVehicle'})
    courseTags[#courseTags + 1] = skin
    courseRows[skin] = {state = i == 2 and 'Pending' or i == 3 and 'Failed' or 'Ready',
        entry = {attempts = i}, fallbackSaved = {[fallback] = 0}}
    courseModels[#courseModels + 1] = owner
    courseModels[#courseModels + 1] = fallback
end
local structurePart = mesh('InsetCore')
structurePart.Anchored, structurePart.Massless = true, true
structurePart.CanCollide, structurePart.CanTouch, structurePart.CanQuery = false, false, false
courseModels[#courseModels + 1] = node('Model', 'CourseStructure_wall', {structurePart},
    {CourseAppearance = 'AuthoredIndustrialCourseStructure'})
local geometry = node('Folder', 'Geometry', courseModels)
local world = node('Folder', 'World', {actorFolder, geometry}, {GroupId = 'group1'})
local particle = node('Part', 'Cosmetic_hit')
particle.Transparency, particle.LocalTransparencyModifier = .32, 0
particle.CanCollide, particle.CanTouch, particle.CanQuery, particle.Anchored = false, false, false, true
local effects = node('Folder', 'BrickToadsLocalEffects', {particle}, {GroupId = 'group1'})
local workspace = node('Workspace', 'Workspace', {world, effects})
workspace.StreamingEnabled, workspace.now = true, 100
function workspace:GetServerTimeNow() return self.now end
local Collection = {tags = {skin}, courseTags = courseTags}
function Collection:GetTagged(tag) return tag == 'BrickToadsCourseSkin' and self.courseTags or self.tags end
function Collection:HasTag(target) return target == skin end
local Log, Errors = {MessageOut = signal()}, {Error = signal()}
local RunService = {Heartbeat = signal()}
function RunService:IsStudio() return true end
function RunService:IsClient() return true end
local stateRemote = {OnClientEvent = signal()}
local script = node('LocalScript', 'Client', {}, {AVExpectedRunId = 'run1'})
script.Destroying = signal()
local playerScripts = node('Folder', 'PlayerScripts')
local player = node('Player', 'LocalPlayer', {playerScripts})
local endpointCount, endpointDestroyed = 0, false
local Instance = {}
function Instance.new(kind)
    assert(kind == 'BindableFunction', 'Observer attempted an unexpected Instance write')
    endpointCount += 1
    return {Destroy = function(self) endpointDestroyed = true; self.Parent = nil end}
end
local _G = {}
local task = {defer = function(fn) fn() end}
local Enum = {MessageType = {MessageWarning = 'Warning', MessageError = 'Error'}}
local Content = {reads = 0}
function Content:GetAssetFetchStatus(id)
    self.reads += 1
    return id == 'rbxassetid://103' and 'Failure' or 'Success'
end
local game = {GetService = function(_, name)
    return assert(({CollectionService = Collection, LogService = Log, ScriptContext = Errors, ContentProvider = Content})[name], name)
end}
local function sound(name)
    local s = {Name = name, Parent = {}, SoundId = 'rbxassetid://1', IsLoaded = false, TimeLength = 0,
        IsPlaying = false, PlaybackLoudness = 0, TimePosition = 0, Volume = .22, PlaybackSpeed = 1,
        Looped = true, PlaybackRegionsEnabled = true, PlaybackRegion = {Min = 1, Max = 4}, LoopRegion = {Min = 1, Max = 4}}
    for _, event in ipairs({'Played', 'Stopped', 'Ended', 'DidLoop', 'Loaded'}) do s[event] = signal() end
    return s
end
local gameAudio = {voices = {}, music = {sound = sound('Music')}, muted = false, musicMuted = false}
for i = 1, 8 do gameAudio.voices[i] = {sound = sound('SFX_' .. i)} end
function gameAudio:diagnostics() return {ready = self.music.sound.IsLoaded, configured = true, sfxVoices = 8} end
local gateRow = {state = 'Pending', entry = {attempts = 1}}
local castAssetVisibility = {rows = {[skin] = gateRow}}
function castAssetVisibility:diagnostics() return {tracked = 1, pending = gateRow.state == 'Pending' and 1 or 0} end
local courseAssetVisibility = {rows = courseRows}
function courseAssetVisibility:diagnostics() return {tracked = 4, pending = 1, failed = 1, ready = 2} end
local snapshot = {status = 'Lobby'}
-- INSERT_OBSERVER_HERE
local api = assert(_G.BrickToadsFullCampaignAV)
assert(api.summary().observedStageCount == 0 and endpointCount == 1)
local function advance(index, live)
    snapshot = {status = 'Active', runId = 'run1', groupId = 'group1', levelEpoch = index, snapshotSeq = index,
        view = 'Playing', level = {campaignIndex = index, mode = 'Walk', stage = 'Route',
            enemies = live == false and {} or {{id = -1, kind = 'Pig', dead = false}}},
        heroes = {{slot = 1, actorId = 'hero1', status = 'Alive'}}}
    workspace.now += 1
    stateRemote.OnClientEvent:fire(snapshot)
    RunService.Heartbeat:fire()
end
advance(1)
local first = api.summary().stages[1].firstSample
assert(not first.audio.ready and not first.sounds[1].loaded and first.sounds[1].timeLength == 0)
assert(first.cast.rows[1].gateState == 'Pending' and first.cast.rows[1].visibility == 'Fallback')
assert(not first.actors.heroes[1].sourceStatePublished and first.actors.heroes[1].baseMeshParts == 15)
assert(first.particles.parts == 1 and first.particles.unsafeParts == 0)
assert(first.course.taggedPresent == 4 and #first.course.rows == 4 and first.course.gate.failed == 1)
assert(first.course.byKind.Speeder.visibleMeshParts == 1 and first.course.byKind.Speeder.visibleFallbackTargets == 0)
assert(first.course.byKind.Surfboard.pending == 1 and first.course.byKind.Surfboard.visibleFallbackTargets == 1)
assert(first.course.byKind.Jet.failed == 1 and first.course.byKind.Jet.visibleMeshParts == 0)
assert(first.course.byKind.ClingerVehicle.visibleMeshParts == 1 and first.course.byKind.ClingerVehicle.visibleFallbackTargets == 1)
assert(first.course.rows[1].fallbacks[1].localTransparencyModifier == 1 and first.course.rows[1].knownFallbackTargets == 1)
assert(first.course.rows[3].meshes[1].contents[1].status == 'Failure')
assert(first.course.structures.modelsPresent == 1 and first.course.structures.parts == 1 and first.course.structures.unsafeParts == 0)
assert(Content.reads > 0)
local music = gameAudio.music.sound
music.IsLoaded, music.TimeLength, music.IsPlaying, music.PlaybackLoudness = true, 42, true, 30
workspace.now += 1
music.Loaded:fire()
music.Played:fire()
for i = 1, 40 do music.Played:fire() end
for i = 1, 60 do motor.C0 += 1; workspace.now += 1; RunService.Heartbeat:fire() end
local one = api.summary().stages[1]
assert(one.sampleCount == 61 and #one.samples == 12 and not one.firstSample.sounds[1].loaded)
assert(one.sounds.Music.loadedSamples == 60 and one.sounds.Music.playedEvents == 41)
assert(one.sounds.Music.firstObservedLoadedAt == 103 and one.sounds.Music.maxLoudness == 30)
assert(one.sounds.Music.loadingLatency == nil and #one.audioEvents == 20 and one.audioEventCount == 42)
assert(one.samples[12].actors.heroes[1].changedJoints == 1)
assert(one.courseKinds.Speeder.maxInstances == 1 and one.courseKinds.Speeder.canonicalVisibleSamples == 61)
assert(one.courseKinds.Jet.failedSamples == 61 and one.maxCourseStructures == 1)
one.samples[12].sounds[1].name = 'Mutated export'
assert(api.summary().stages[1].samples[12].sounds[1].name ~= 'Mutated export')
Collection.tags = {}
Collection.courseTags = {}
advance(2, false)
local two = api.summary().stages[2].firstSample
assert(two.cast.taggedPresent == 0 and two.actors.castPresence == 'NoLiveEnemiesInSnapshot')
assert(two.course.taggedPresent == 0 and two.course.presence == 'NoTaggedCourseSkinsOnClient')
workspace.children = {}
advance(3)
local three = api.summary().stages[3].firstSample
assert(not three.worldPresent and three.actors.castPresence == 'WorldOrActorsNotPresent')
assert(three.actors.absentEnemyModels[1].state == 'ModelAbsentClientReasonUnknown')
assert(three.actors.absentEnemyModels[1].streamingPossible)
assert(not three.course.structures.geometryPresent and three.course.presence == 'WorldNotPresent')
workspace.children = {world, effects}
Collection.tags = {skin}
Collection.courseTags = courseTags
gateRow.state, skinMesh.LocalTransparencyModifier, fallback.LocalTransparencyModifier = 'Ready', 0, 1
for index = 4, 13 do advance(index) end
local all = api.summary()
assert(#all.stages == 13 and all.observedStageCount == 13)
assert(all.stages[4].firstSample.cast.rows[1].visibility == 'Canonical')
for i = 1, 100 do Log.MessageOut:fire('warning' .. i, Enum.MessageType.MessageWarning) end
assert(api.summary().consoleCount == 100 and #api.summary().console == 64)
snapshot.runId = 'foreign'
workspace.now += 1
RunService.Heartbeat:fire()
assert(api.summary().stages[13].sampleCount == 1)
snapshot.runId = 'run1'
-- Force the final sample to fail; cleanup still has to disconnect everything.
function gameAudio:diagnostics() error('Fixture teardown read failure') end
local final = api.destroy('Harness')
assert(not final.running and final.stopReason == 'Harness' and endpointDestroyed)
Log.MessageOut:fire('after teardown', Enum.MessageType.MessageError)
RunService.Heartbeat:fire()
music.Played:fire()
assert(api.summary().consoleCount == 100 and not api.summary().running)
for _, s in ipairs({RunService.Heartbeat, stateRemote.OnClientEvent, Log.MessageOut, Errors.Error, script.Destroying,
    music.Played, music.Loaded, music.Stopped, music.Ended, music.DidLoop}) do
    for _, c in ipairs(s.connections) do assert(not c.connected, 'Leaked observer connection') end
end
print('PASS: actual observer runtime,13-stage/sample/event/console bounds, real-state semantics, detached exports, teardown')
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', type=Path, default=LUAU)
    args = parser.parse_args()
    source = FIXTURE.replace("-- INSERT_OBSERVER_HERE", OBSERVER.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="bricktoads-av-") as tmp:
        target = Path(tmp) / "observer_fixture.luau"
        target.write_text(source, encoding="utf-8")
        result = subprocess.run([str(args.luau), str(target)], cwd=ROOT, check=False)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
