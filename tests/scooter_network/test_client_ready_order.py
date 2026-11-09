#!/usr/bin/env python3
"""Run the actual client under deterministic queued/later State delivery doubles.

This checks the test driver's handshake, not Roblox network delivery or gameplay.
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
        assert(message.id == '1' and message.ok == true, 'Menu reply failed')
        assert(message.result.transmission.sent == true, 'Menu did not fire production intent')
        assert(message.result.transmission.serverAcceptance == 'Unknown', 'Client invented server acceptance')
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
local workspace = {GetServerTimeNow=function() return testNow end,FindFirstChild=function() return nil end}
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
