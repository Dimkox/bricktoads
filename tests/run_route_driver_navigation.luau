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
local combat = {lastAttack = -100}
local enemy = {x = 40, y = 3, z = 0}
check(Nav.queueAttack(combat, 'R', 'Pig4', 'body1', 1), 'One attack can be queued')
local pendingAttack = Nav.attackPlan({x = 35, y = 3, z = 0}, enemy, combat, 1.8, 1.1)
check(pendingAttack.target == enemy and not pendingAttack.retreat and not pendingAttack.attackReady,
    'Delayed poll beyond0.35s must still approach the queued enemy, never retreat and fire away')
check(combat.lastAttack == -100, 'Queuing must not start the actual attack clock')
check(not Nav.queueAttack(combat, 'R', 'Walker6', 'body1', 1.9) and combat.pending.target == 'Pig4',
    'Pending attack keeps the same enemy even after the keyboard queue is drained')
Nav.observeAttack(combat, 'R', 2)
check(combat.lastAttack == 2 and not combat.pending, 'Observed synthetic InputBegan starts the cooldown')
check(not Nav.attackPlan({x = 35, y = 3, z = 0}, enemy, combat, 2.2, 1.1).retreat,
    'Hero faces the target through the actual Dash windup')
check(Nav.attackPlan({x = 35, y = 3, z = 0}, enemy, combat, 2.5, 1.1).retreat,
    'Retreat begins only after actual follow-through')
check(Nav.attackPlan({x = 35, y = 3, z = 0}, enemy, combat, 3.2, 1.1).attackReady,
    'Next attack becomes ready from the real key time')
local data = {status = 'Active', groupId = 'g', runId = 'r', levelEpoch = 1}
local h = {status = 'Alive', connected = true, actorId = 'a', attempt = 1, connectionEpoch = 1}
local identity = Nav.identity(data, h)
check(Nav.canPoll(data, h, identity), 'Current living actor can relay keys')
local replacement = table.clone(h); replacement.attempt = 2
check(not Nav.canPoll(data, replacement, identity), 'Fresh respawn snapshot blocks old queued controls before next tick')
data.view = 'Spectating'
check(not Nav.canPoll(data, h, identity), 'Non-playing view cannot relay gameplay keys')
local edgeFloor = {minX = -82, maxX = 4, minZ = -26, maxZ = 26, top = 0}
local edgePosition = {x = -26.624, y = 3, z = -26.6503}
local edgeRecovery = Nav.plan(edgePosition, {x = 2, y = 3, z = 0}, {edgeFloor}, {}, 1, {grounded = true, vy = 0})
check(edgeRecovery.phase == 'Recover support edge' and edgeRecovery.target.z >= -24 and not edgeRecovery.attackAllowed,
    'Observed grounded body overhang at Z-26.6503 must move inward onto support, not park forever')
check(Nav.plan({x = -26, y = 7, z = -26.65}, enemy, {edgeFloor}, {}, 1,
    {grounded = false}).phase == 'No support', 'Falling actor outside support cannot use edge recovery')
check(Nav.plan({x = -26, y = 3, z = -29}, enemy, {edgeFloor}, {}, 1,
    {grounded = true}).phase == 'No support', 'Grounded claim far outside footprint cannot recover blindly')
check(Nav.plan({x = 50, y = 3, z = 0}, enemy, floors, {previousFloor = floors[1]}, 1,
    {grounded = false}).phase == 'No support', 'Previous floor does not authorize blind walking in a gap')
local staged = {lastAttack = -100, stage = 'Route'}
Nav.queueAttack(staged, 'R', 'Pig4', identity, 1)
data.view, data.level = 'Playing', {stage = 'BossReady'}
check(not Nav.canPoll(data, h, identity, staged.stage), 'Poll blocks old queued Route R at a new stage before tick')
check(Nav.syncStage(staged, 'BossReady') and not staged.pending,
    'Route to BossReady clears pending R even if the keyboard queue was already drained')
Nav.syncStage(staged, 'Boss')
check(Nav.queueAttack(staged, 'F', nil, identity, 2), 'Boss interaction F is not deadlocked by the old Route R')
local lostAttack = Nav.attackPlan({x = 35, y = 3, z = 0}, enemy, staged, 3.5, .65)
check(lostAttack.fault and lostAttack.target.x == 35 and not staged.pending,
    'Drained attack with no observed key stops safely after1.4s instead of retaining pending until300s')
local delayedJump = table.clone(j)
delayedJump.at, delayedJump.launchY, delayedJump.maxRise = 0, 3, 0
check(Nav.jumpOutcome(delayedJump, {x = 52.246, y = 2.79, z = 0}, false, -1, .349) == nil,
    'Observed client sample0.349s behind a successful server jump must not cause early NO_OBSERVED_ASCENT')
check(Nav.jumpOutcome(delayedJump, {x = 50, y = 8, z = 0}, false, 20, .55) == nil,
    'Delayed ascent at0.55s remains pending')
check(Nav.jumpOutcome(delayedJump, {x = 44.4, y = 3, z = 0}, true, 0, 1.2) == 'LANDED',
    'Delayed grounded landing at1.2s confirms the correct destination')
local skippedArc = table.clone(j)
skippedArc.at, skippedArc.launchY, skippedArc.maxRise = 0, 3, 0
check(Nav.jumpOutcome(skippedArc, {x = 44.4, y = 3, z = 0}, true, 0, 1.2) == 'LANDED',
    'Grounded destination confirms landing even when replication skipped the ascent samples')
local absentJump = table.clone(skippedArc)
check(Nav.jumpOutcome(absentJump, {x = 54, y = 3, z = 0}, true, 0, 1.99) == nil,
    'No-ascent observation remains pending within the bounded feedback window')
check(Nav.jumpOutcome(absentJump, {x = 54, y = 3, z = 0}, true, 0, 2) == 'NO_OBSERVED_ASCENT',
    'No ascent fails at the finite2.0s deadline')
local fallingJump = table.clone(skippedArc)
check(Nav.jumpOutcome(fallingJump, {x = 50, y = 0, z = 0}, false, -10, .55) == nil,
    'Early stale below-edge sample waits for authoritative feedback to arrive')
check(Nav.jumpOutcome(fallingJump, {x = 50, y = 0, z = 0}, false, -10, 2) == 'FELL_BELOW_LANDING',
    'Still below the landing at deadline remains a bounded failure')
local delayedFlight = {jump = table.clone(j)}
delayedFlight.jump.at = 0
check(Nav.plan({x = 50, y = 7, z = 0}, enemy, floors, delayedFlight, 1.8,
    {grounded = false}).phase == 'Flight', 'Navigation preserves the accepted flight throughout its2s observation window')
local definition = require('../src/server/gameplay/CampaignDefinition').build(1, 303307263)
local seamFloors = {}
for zi = 1, 2 do
    local f = definition.zones[zi].platforms[1]
    seamFloors[zi] = {minX=f.x-f.w/2, maxX=f.x+f.w/2, minZ=f.z-f.d/2, maxZ=f.z+f.d/2, top=f.y+f.h/2}
end
check(seamFloors[1].maxX == -2 and seamFloors[2].minX == -2 and seamFloors[2].minZ == -14,
    'Attempt13 seed has an adjoining seam with a narrower destination, not an X gap')
local patrol = definition.zones[2].enemies[1]
local function crossingZ(from, target, edge)
    return from.z + (target.z-from.z)*(edge-from.x)/(target.x-from.x)
end
-- The terminal poses are real retained observations. Replaying their Z values
-- from the safe takeoff-side inset is a planner contract, not a native cause claim.
for _, observed in ipairs({
    {x=-.2360484004020691, y=-36.62171173095703, z=-16.640233993530273},
    {x=-.10371075570583344, y=-36.49592971801758, z=-17.368358612060547},
}) do
    check(Nav.plan(observed, patrol, seamFloors, {}, 1, {grounded=false}).phase == 'No support',
        'A recorded fallen body must not be treated as supported at the adjoining seam')
    local p = {x=seamFloors[1].maxX-2.2, y=3, z=observed.z}
    check(crossingZ(p, patrol, -2) < seamFloors[2].minZ,
        'Direct approach from the retained fall lane crosses outside the next floor')
    local aligned = Nav.plan(p, patrol, seamFloors, {}, 1, {})
    check(aligned.target.x <= p.x and aligned.target.z >= -12 and aligned.target.z <= 20
        and aligned.crossing and not aligned.attackAllowed and not aligned.jump,
        'Narrow adjoining support requires lateral alignment on the current floor before advancing')
    p.z = -11
    local walk = Nav.plan(p, {x=patrol.x,y=3,z=observed.z}, seamFloors, {}, 1, {})
    check(walk.target.x > -2 and crossingZ(p, walk.target, -2) >= -12
        and not walk.crossing and not walk.jump,
        'Once aligned, ordinary walking keeps the segment through the shared corridor without jumping')
end
local mirrored = {}
for i, f in ipairs(seamFloors) do
    mirrored[i] = {minX=f.minX,maxX=f.maxX,minZ=-f.maxZ,maxZ=-f.minZ,top=f.top}
end
local mirror = Nav.plan({x=-4.2,y=3,z=16.640233993530273}, {x=patrol.x,y=3,z=-patrol.z}, mirrored, {}, 1, {})
check(mirror.target.x <= -4.2 and mirror.target.z <= 12 and mirror.crossing and not mirror.jump,
    'Mirrored narrowing aligns away from the positive Z edge before forward walking')
local reversed = {}
for i = #seamFloors, 1, -1 do
    local f = seamFloors[i]
    reversed[#reversed+1] = {minX=-f.maxX,maxX=-f.minX,minZ=f.minZ,maxZ=f.maxZ,top=f.top}
end
local backward = Nav.plan({x=4.2,y=3,z=-16.640233993530273}, {x=-patrol.x,y=3,z=patrol.z}, reversed, {}, 1, {})
check(backward.target.x >= 4.2 and backward.target.z >= -12 and backward.crossing and not backward.jump,
    'Backward adjoining traversal also aligns on the current side of a narrowing seam')
local disjoint = {{minX=0,maxX=10,minZ=-5,maxZ=5,top=0}, {minX=10,maxX=20,minZ=10,maxZ=20,top=0}}
local blockedSeam = Nav.plan({x=8,y=3,z=0}, {x=15,y=3,z=15}, disjoint, {}, 1, {})
check(blockedSeam.phase == 'No shared crossing' and blockedSeam.target.x == 8
    and blockedSeam.target.z == 0 and not blockedSeam.attackAllowed and not blockedSeam.jump,
    'Touching X bounds do not authorize crossing when the Z corridors do not overlap')
local restricted = Nav.plan({x=-4.2,y=3,z=-16.64}, patrol, seamFloors, {}, 1, {allowCrossing=false})
check(not restricted.crossing and restricted.target.x < -2 and not restricted.jump,
    'Disabled route crossing still confines an adjoining approach to its current support')
for _, reverseX in ipairs({false, true}) do for _, mirrorZ in ipairs({false, true}) do
    local observed = reverseX and reversed or seamFloors
    local low, high = -12, 20
    if mirrorZ then
        local rows = {}
        for i, f in ipairs(observed) do rows[i]={minX=f.minX,maxX=f.maxX,minZ=-f.maxZ,maxZ=-f.minZ,top=f.top} end
        observed, low, high = rows, -20, 12
    end
    local p = {x=reverseX and 4.2 or -4.2,y=3,z=mirrorZ and high+.01 or low-.01}
    local desired = {x=reverseX and -20 or 20,y=3,z=mirrorZ and high or low}
    local align = Nav.plan(p, desired, observed, {}, 1, {})
    local delta = math.sqrt((align.target.x-p.x)^2+(align.target.z-p.z)^2)
    check(align.phase == 'Align adjoining support' and delta > .15
        and align.target.z > low and align.target.z < high and not align.jump,
        'Each mirrored/reverse seam target must clear the real bridge .15 movement deadzone')
end end
for _, width in ipairs({0, .2}) do
    local narrow = {{minX=0,maxX=10,minZ=-10,maxZ=10,top=0}, {minX=10,maxX=20,minZ=0,maxZ=4+width,top=0}}
    local hold = Nav.plan({x=7.8,y=3,z=1.99}, {x=15,y=3,z=2}, narrow, {}, 1, {})
    check(hold.phase == 'No shared crossing' and hold.target.x == 7.8 and hold.target.z == 1.99 and not hold.jump,
        'An unaligned corridor too narrow for an interior target beyond the deadzone must hold conservatively')
end
local slowReverse = {x=55.302,y=3,z=-3.923}
local slowState = {}
local stagedRunUp = Nav.plan(slowReverse,{x=45,y=3,z=-4.14},floors,slowState,1,
    {grounded=false,vy=0,jumpLead=3.2})
check(stagedRunUp.phase=='Stage gap run-up' and stagedRunUp.target.x>=61 and not stagedRunUp.jump
    and stagedRunUp.crossing and not stagedRunUp.attackAllowed,
    'Observed unqualified walking approach at55.302 must first move inward, not toward edge53.7')
local continueRunUp = Nav.plan({x=58,y=3,z=-4.14},{x=45,y=3,z=-4.14},floors,slowState,1.2,
    {grounded=true,vy=0,jumpLead=3.2})
check(continueRunUp.phase=='Stage gap run-up' and continueRunUp.target.x>=61 and not continueRunUp.jump,
    'Run-up staging persists until its supported reversal point even after speed qualifies')
local finishRunUp = Nav.plan({x=61,y=3,z=-4.14},{x=45,y=3,z=-4.14},floors,slowState,1.4,
    {grounded=true,vy=0,jumpLead=3.2})
check(finishRunUp.phase=='Approach gap' and finishRunUp.target.x<61 and not finishRunUp.jump,
    'Reached run-up point releases ordinary approach toward the same gap')
local readyReverse = Nav.plan({x=55.8,y=3,z=-4.14},{x=45,y=3,z=-4.14},floors,slowState,1.6,
    {grounded=true,vy=0,jumpLead=3.2})
check(readyReverse.jump and readyReverse.direction==-1,
    'Actual run-qualified return still requests the ordinary reverse Jump')
local mirrorFloors={{minX=-124,maxX=-53,minZ=-19,maxZ=19,top=0},
    {minX=-48,maxX=-4,minZ=-19,maxZ=19,top=0}}
local slowForward=Nav.plan({x=-55.302,y=3,z=-3.923},{x=-45,y=3,z=-4.14},mirrorFloors,{},1,
    {grounded=false,vy=0,jumpLead=3.2})
check(slowForward.phase=='Stage gap run-up' and slowForward.target.x<=-61 and not slowForward.jump,
    'Mirrored unqualified approach stages inward on the same current support')
local switched={}
Nav.plan(slowReverse,{x=45,y=3,z=-4.14},floors,switched,1,{grounded=false,vy=0,jumpLead=3.2})
check(Nav.plan(slowReverse,{x=70,y=3,z=0},floors,switched,1.1,{grounded=true,vy=0}).phase=='Walk'
    and switched.gapRunUp==nil,'A target on the current support cancels obsolete gap run-up staging')
check(Nav.plan({x=55.302,y=5,z=-3.923},{x=45,y=3,z=-4.14},floors,{},1,
    {grounded=false,vy=0,jumpLead=3.2}).phase~='Stage gap run-up',
    'An airborne-height observation cannot create a standing run-up claim')
check(Nav.plan({x=55.302,y=3,z=-3.923},{x=45,y=3,z=-4.14},floors,{},1,
    {grounded=false,vy=-3,jumpLead=3.2}).phase~='Stage gap run-up',
    'A descending observation cannot create a standing run-up claim')
for _,sign in ipairs({1,-1})do
    local pads=sign==1 and {{minX=224,maxX=258,minZ=-9,maxZ=9,top=0},
        {minX=262,maxX=289,minZ=-3,maxZ=15,top=2}} or
        {{minX=-289,maxX=-262,minZ=-3,maxZ=15,top=2},{minX=-258,maxX=-224,minZ=-9,maxZ=9,top=0}}
    for _,observed in ipairs({{x=267.798,y=5.897,z=.601},{x=267.951,y=9.328,z=.567}})do
        local jumpState={}
        Nav.plan({x=sign*255,y=3,z=.6},{x=sign*280,y=5,z=.6},pads,jumpState,1,{grounded=true,jumpLead=3.2})
        local retainedJump=jumpState.jump
        local p={x=sign*observed.x,y=observed.y,z=observed.z}
        local hold=Nav.plan(p,{x=sign*280,y=5,z=.6},pads,jumpState,1.6,{grounded=false,vy=25})
        check(hold.phase=='Flight' and hold.target.x==p.x and not hold.jump and not hold.attackAllowed
            and jumpState.jump==retainedJump,
            'Observed high landing-side body must hold X after passing target, never reverse across the gap or falsely clear flight')
    end
end
local landingPads={{minX=224,maxX=258,minZ=-9,maxZ=9,top=0},
    {minX=262,maxX=289,minZ=-3,maxZ=15,top=2}}
local function nativeLandingState()
    local s={};Nav.plan({x=255,y=3,z=.6},{x=280,y=5,z=.6},landingPads,s,1,{grounded=true,jumpLead=3.2});return s
end
local lowFlight=Nav.plan({x=268,y=3,z=.6},{x=280,y=5,z=.6},landingPads,nativeLandingState(),1.6,{grounded=false,vy=-30})
check(lowFlight.target.x==266,'A body below the destination cannot claim the landing-side hold')
local outsideFlight=Nav.plan({x=268,y=9,z=20},{x=280,y=5,z=.6},landingPads,nativeLandingState(),1.6,{grounded=false,vy=0})
check(outsideFlight.target.x==266,'A body outside the authored destination Z footprint cannot claim the landing-side hold')
local expired=nativeLandingState()
local afterExpiry=Nav.plan({x=268,y=9,z=.6},{x=280,y=5,z=.6},landingPads,expired,3.1,{grounded=false,vy=0})
check(expired.jump==nil and afterExpiry.phase~='Flight','Landing-side hold does not extend the existing two-second flight window')
local pending=nativeLandingState();pending.jump.awaitingInput=true
check(Nav.plan({x=268,y=9,z=.6},{x=280,y=5,z=.6},landingPads,pending,1.6,{grounded=false,vy=0}).target.x==266,
    'A jump still awaiting its input keeps its existing confirmation behavior')
print('PASS route driver navigation: ' .. count .. ' checks')
