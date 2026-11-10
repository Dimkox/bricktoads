#!/usr/bin/env python3
"""Run the actual client under deterministic queued/later State delivery doubles.

This checks the test driver's handshake and enemy control envelope, not Roblox
network delivery or gameplay.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PRELUDE = r'''
local testCommand = {OnClientEvent = {}}
local testReply = {}
local menuReceived, discarded, readyCount, replyCount = 0, 0, 0, 0
local readyMarker, readyRenderCount, heartbeatMessages = nil, nil, 0
local testNow = 1
local testResponses, productionPackets, testModels = {}, {}, {}
function testCommand:IsA(name) return name == 'RemoteEvent' end
function testReply:IsA(name) return name == 'RemoteEvent' end
function testCommand.OnClientEvent:Connect(callback) self.callback = callback end
function testReply:FireServer(message)
    if message.type == 'Ready' then
        readyCount += 1
        readyMarker = message.state.commandListenerReady
        readyRenderCount = message.state.renderFrameCount
        -- The server may send its first command as soon as Ready is received.
        if testCommand.OnClientEvent.callback then
            testCommand.OnClientEvent.callback({id='1',kind='Menu',args={kind='SelectRole',role='Hero'}})
        else discarded += 1 end
    elseif message.type == 'Reply' then
        assert(message.ok == true, 'Command failed: ' .. tostring(message.result))
        testResponses[message.id] = message.result
        if message.id == '1' then
            assert(message.result.transmission.sent == true, 'Menu did not fire production intent')
            assert(message.result.transmission.serverAcceptance == 'Unknown', 'Client invented server acceptance')
        end
        replyCount += 1
    elseif message.type == 'Heartbeat' then
        assert(message.state.snapshot == nil, 'Heartbeat must not transmit full snapshots')
        assert(message.state.name == 'ActualTestClient' and message.state.scriptEnabled == true)
        heartbeatMessages += 1
    end
end
local testBridge = {Parent = true}
function testBridge:WaitForChild(name) return name == 'Command' and testCommand or testReply end
function testBridge:GetAttribute() return 'source' end
local playerScripts = {DescendantAdded = {Connect=function() end}}
function playerScripts:GetDescendants() return {} end
local player = {Name='ActualTestClient',UserId=-3}
function player:WaitForChild() return playerScripts end
local productionIntent = {}
function productionIntent:FireServer(message)
    productionPackets[#productionPackets + 1] = table.clone(message)
    if message.kind == 'SelectRole' then
        assert(message.groupId == 'group-1' and message.role == 'Hero', 'Incorrect production envelope')
        menuReceived += 1
    end
end
local function statePacket(seq)
    return {snapshotSeq=seq,groupId='group-1',status='Lobby',heroes={}}
end
local productionState = {OnClientEvent = {}}
function productionState.OnClientEvent:Connect(callback)
    self.callback = callback
    if EARLY_STATE then
        -- Model a queued first State delivered during listener registration.
        callback(statePacket(1))
    end
end
local remotes = {}
function remotes:WaitForChild(name) return name == 'Intent' and productionIntent or productionState end
local replicated = {}
function replicated:WaitForChild(name) return name == 'BrickToadsGame' and remotes or testBridge end
local function signal()
    return {Connect=function(self, callback) self.callback = callback end}
end
local runService = {IsStudio=function() return true end,Heartbeat=signal(),RenderStepped=signal()}
local services = {Players={LocalPlayer=player},ReplicatedStorage=replicated,
    RunService=runService,StudioTestService={},UserInputService={WindowFocused=signal(),WindowFocusReleased=signal()}}
local game = {GetService=function(_,name) return services[name] end}
local testActorFolder = {GetChildren=function() return testModels end}
local testWorld = {GetAttribute=function(_, name) return name == 'GroupId' and 'group-1' or nil end,
    FindFirstChild=function(_,name) return name == 'Actors' and testActorFolder or nil end}
local workspace = {GetServerTimeNow=function() return testNow end,
    FindFirstChild=function(_,name) return name == 'TestWorld' and testWorld or nil end}
local task = {spawn=function() end}
local script = {Enabled=true,Parent=true,GetFullName=function() return 'PlayerScripts.ScooterNetworkClient' end}
'''
EPILOGUE = r'''
assert(readyCount == 0, 'Ready must wait for rendering, even when State and Command are available')
runService.RenderStepped.callback()
assert(readyCount == 0, 'One rendered frame is insufficient')
runService.RenderStepped.callback()
if not EARLY_STATE then
    assert(readyCount == 0, 'Rendered frames cannot replace the first production snapshot')
    productionState.OnClientEvent.callback(statePacket(1))
end
runService.RenderStepped.callback()
productionState.OnClientEvent.callback(statePacket(2))
print('ready=' .. readyCount .. ' discarded=' .. discarded .. ' menuReceived=' .. menuReceived .. ' replies=' .. replyCount)
assert(readyCount == 1, 'Ready must be published exactly once after the first snapshot')
assert(discarded == 0 and menuReceived == 1 and replyCount == 1, 'Ready advertised before Command was armed')
assert(readyMarker == true, 'Ready did not prove command listener availability')
assert(readyRenderCount >= 2, 'Ready did not prove rendering started')
runService.Heartbeat.callback()
runService.Heartbeat.callback()
assert(heartbeatMessages == 1, 'Heartbeat diagnostics must be bounded to one per second')
testNow += 1.1
runService.Heartbeat.callback()
assert(heartbeatMessages == 2, 'Heartbeat diagnostics stopped')

-- The same actual source must use an enemy snapshot's real identity and preserve
-- pre/post-claim body evidence without inventing a player or acceptance result.
local enemyModel = {Name='Actor_-1',actorId='run:enemy:3:-1',controlled=false}
function enemyModel:IsA(name) return name == 'Model' end
function enemyModel:GetAttribute(name)
    if name == 'ActorId' then return self.actorId
    elseif name == 'EnemyKind' then return 'Invader'
    elseif name == 'ControlledByPlayer' then return self.controlled end
end
local enemyRoot = {Parent=enemyModel,Position={X=28,Y=3,Z=-10},AssemblyLinearVelocity={X=0,Y=0,Z=0},
    IsA=function(_,name) return name == 'BasePart' end}
function enemyModel:FindFirstChild(name) return name == 'HumanoidRootPart' and enemyRoot or nil end
testModels[1] = enemyModel
local function sendCommand(id,kind,args)
    testCommand.OnClientEvent.callback({id=id,kind=kind,args=args or {}})
    return assert(testResponses[id], 'Missing test command reply')
end
local function roleState(seq,role)
    return {snapshotSeq=seq,groupId='group-1',worldName='TestWorld',runId='run',levelEpoch=3,
        status='Active',view=role and 'Playing' or 'Spectating',heroes={},enemyRole=role,
        enemyOffers=role and {} or {{enemyId=-1,actorId=enemyModel.actorId}}}
end
productionState.OnClientEvent.callback(roleState(3))
local offered = sendCommand('offer','Status')
assert(offered.enemyBodies[1].offerActorId == enemyModel.actorId)
assert(offered.enemyBodies[1].bodyActorId == enemyModel.actorId and offered.enemyBodies[1].controlledByPlayer == false)
sendCommand('claim','Menu',{kind='ClaimEnemy',runId='run',levelEpoch=3,enemyId=-1})
local claimPacket = productionPackets[#productionPackets]
assert(claimPacket.kind == 'ClaimEnemy' and claimPacket.groupId == 'group-1' and claimPacket.actorId == nil)
local firstRole = {enemyId=-1,actorId=enemyModel.actorId,attempt=1,connectionEpoch=1,connected=true,
    status='Alive',template='Sentry',movementKind='Ground'}
enemyModel.controlled = true
productionState.OnClientEvent.callback(roleState(4,firstRole))
local moved = sendCommand('enemyMove','Actor',{kind='Move',x=0.5,z=-0.25,run=false})
local movePacket = moved.transmission.packet
assert(movePacket.groupId == 'group-1' and movePacket.runId == 'run' and movePacket.levelEpoch == 3)
assert(movePacket.actorId == enemyModel.actorId and movePacket.attempt == 1 and movePacket.connectionEpoch == 1 and movePacket.seq == 1)
assert(moved.state.body.actorId == offered.enemyBodies[1].bodyActorId and moved.state.body.controlledByPlayer == true)
local attacked = sendCommand('enemyAttack','Actor',{kind='Attack',attack='Punch'})
assert(attacked.transmission.packet.seq == 2 and attacked.transmission.serverAcceptance == 'Unknown')
local nextRole = table.clone(firstRole)
nextRole.connectionEpoch = 2
productionState.OnClientEvent.callback(roleState(5,nextRole))
firstRole.actorId = 'mutated-old-snapshot'
local reconnected = sendCommand('enemyJump','Actor',{kind='Jump'})
assert(reconnected.transmission.packet.seq == 1 and reconnected.transmission.packet.connectionEpoch == 2)
assert(reconnected.state.controlIdentity.role == 'Enemy' and reconnected.state.controlIdentity.enemyId == -1)
assert(reconnected.state.previousControlIdentity.actorId == enemyModel.actorId,
    'Later snapshots rewrote the immutable previous identity')
assert(reconnected.state.previousControlIdentity.connectionEpoch == 1 and reconnected.state.previousIdentitySequence == 2)
assert(table.isfrozen(reconnected.state.controlIdentity) and table.isfrozen(reconnected.state.previousControlIdentity))
print('enemy control envelope, same-body claim evidence and identity reset: PASS')
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', type=Path, default=ROOT / '.tools/luau-0.745/luau.exe')
    parser.add_argument('--client', type=Path, default=ROOT / 'tests/scooter_network/Client.client.luau')
    args = parser.parse_args()
    source = args.client.read_text(encoding='utf-8-sig')
    with tempfile.TemporaryDirectory(prefix='bricktoads-ready-order-') as temporary:
        for name, early in [('queued-state', True), ('later-state', False)]:
            probe = Path(temporary) / f'{name}.luau'
            probe.write_text(f'local EARLY_STATE = {str(early).lower()}\n' + PRELUDE + '\n' + source + '\n' + EPILOGUE,
                             encoding='utf-8')
            result = subprocess.run([str(args.luau.resolve()), str(probe)], text=True, capture_output=True)
            print(f'{name}: {"PASS" if result.returncode == 0 else "FAIL"}')
            print(result.stdout, end='')
            if result.stderr:
                print(result.stderr, end='')
            if result.returncode:
                return result.returncode
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
