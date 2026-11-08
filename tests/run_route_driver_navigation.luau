local ok, Nav = pcall(require, '../tools/studio_level_route_driver')
assert(ok, 'Route planner must load natively before any Roblox side effects: ' .. tostring(Nav))
local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local floors = {
    {minX = 4, maxX = 48, minZ = -19, maxZ = 19, top = 0},
    {minX = 53, maxX = 124, minZ = -19, maxZ = 19, top = 0},
}
local reverse = Nav.plan({x = 53.28, y = 3, z = 0}, {x = 45.63, y = 3, z = 0}, floors, {}, 1, {grounded = true})
check(reverse.crossing and reverse.jump and reverse.direction == -1 and reverse.target.x < 48,
    'Observed x53.28 -> enemy45.63 must jump backwards across48..53 before combat')
check(not reverse.attackAllowed, 'An enemy across the gap cannot trigger an attack or cooldown retreat')
local forward = Nav.plan({x = 46, y = 3, z = 0}, {x = 70, y = 3, z = 0}, floors, {}, 1, {grounded = true})
check(forward.jump and forward.direction == 1 and forward.target.x > 53, 'Forward jump targets the next support')
local approach = Nav.plan({x = 62, y = 3, z = 0}, {x = 40, y = 3, z = 0}, floors, {}, 1, {grounded = true})
check(approach.crossing and not approach.jump and approach.target.x > 53 and approach.target.x < 54,
    'Backward approach aims at the near edge, not the far edge of current support')
local airborne = Nav.plan({x = 53.28, y = 5, z = 0}, {x = 40, y = 3, z = 0}, floors, {}, 1, {grounded = false})
check(airborne.crossing and not airborne.jump, 'A falling actor cannot enqueue another jump')
local state = {}
Nav.plan({x = 53.28, y = 3, z = 0}, {x = 40, y = 3, z = 0}, floors, state, 1, {grounded = true})
local flight = Nav.plan({x = 50, y = 7, z = 0}, {x = 40, y = 3, z = 0}, floors, state, 1.2, {grounded = false})
check(flight.crossing and flight.direction == -1 and flight.target.x < 48, 'Reverse flight keeps destination while above the gap')
local j = state.jump
local waiting = {jump = table.clone(j)}
waiting.jump.awaitingInput = true
local missingInput = Nav.plan({x = 53.28, y = 3, z = 0}, {x = 40, y = 3, z = 0}, floors,
    waiting, 10, {grounded = true})
check(missingInput.fault and missingInput.target.x == 53.28 and not waiting.jump,
    'Unobserved queued jump expires safely instead of steering toward the abyss indefinitely')
check(not Nav.landed({x = 54, y = 3, z = 0}, j, true, 0), 'Original support is not a reverse landing')
check(not Nav.landed({x = 47, y = 8, z = 0}, j, true, 0), 'A high actor with stale grounded state is not landed')
check(not Nav.landed({x = 47, y = 3, z = 25}, j, true, 0), 'Landing must also be on destination Z support')
check(Nav.landed({x = 47, y = 3, z = 0}, j, true, 0), 'Reverse landing accepts grounded destination side')
local fs = {}; Nav.plan({x = 46, y = 3, z = 0}, {x = 70, y = 3, z = 0}, floors, fs, 1, {grounded = true})
check(not Nav.landed({x = 47, y = 3, z = 0}, fs.jump, true, 0), 'Original support is not a forward landing')
check(Nav.landed({x = 54, y = 3, z = 0}, fs.jump, true, 0), 'Forward landing accepts destination support')
local retreat = Nav.plan({x = 54, y = 3, z = 0}, {x = 50, y = 3, z = 0}, floors, {}, 1,
    {grounded = true, allowCrossing = false})
check(not retreat.crossing and not retreat.jump and retreat.target.x >= 55.2, 'Combat retreat remains on current support')
local adjacent = {{minX = 0, maxX = 10, minZ = -5, maxZ = 5, top = 0},
    {minX = 10, maxX = 20, minZ = -5, maxZ = 5, top = 0}}
check(Nav.plan({x = 12, y = 3, z = 0}, {x = 5, y = 3, z = 0}, adjacent, {}, 1, {}).target.x == 5,
    'Adjacent supports permit backward walking without clamping to current floor')
check(Nav.plan({x = 8, y = 3, z = 0}, {x = 15, y = 3, z = 0}, adjacent, {}, 1, {}).target.x == 15,
    'Adjacent supports permit forward walking')
local support = {}
local oldFloor = {part = support, minX = 53, maxX = 124, minZ = -19, maxZ = 19, top = 0}
local refreshedFloor = table.clone(oldFloor)
local observed = Nav.currentFloor({x = 51, y = 5, z = 0}, {floors[1], refreshedFloor}, oldFloor)
check(observed == refreshedFloor, 'Previous support survives rebuilt geometry observations by part identity')
local keys = Nav.keysForMove({x = -1, z = 0}, {x = 0, z = -1})
check(keys.A and not keys.D, 'Default camera projects -X to A')
keys = Nav.keysForMove({x = 1, z = 0}, {x = 1, z = 0})
check(keys.W and not keys.S, 'Rotated camera projects world-forward to W')
local expected = {}
local batch = Nav.inputBatch({D = true}, {A = true}, {'Space'}, expected, 10, true)
check(batch.actions[1].action == 'keyUp' and batch.actions[1].key_code == 'D', 'Batch releases prior held keys first')
check(expected.A.count == 1 and expected.Space.count == 1 and expected.A.expires > 10,
    'Synthetic expectations are registered before MCP executes keydown and jump')
check(#batch.heldKeys == 0 and batch.actions[#batch.actions].action == 'keyUp', 'Finite batch ends with no held movement')
check(Nav.consumeExpected(expected, 'A', 10.1) and not Nav.consumeExpected(expected, 'A', 10.1),
    'Only the exact counted synthetic keydown is consumed')
check(not Nav.consumeExpected(expected, 'Space', 20), 'Expired synthetic expectation cannot hide manual takeover')
local stopped = Nav.inputBatch({'W', 'A'}, {D = true}, {'R'}, {}, 10, false)
check(#stopped.actions == 2 and stopped.actions[1].action == 'keyUp' and stopped.actions[2].action == 'keyUp',
    'Stopped poll releases every held key and adds no commands')
print('PASS route driver navigation: ' .. count .. ' checks')
