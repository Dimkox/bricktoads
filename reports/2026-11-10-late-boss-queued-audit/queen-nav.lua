-- Temporary keyboard acceptance planner; native require has no Roblox side effects.
local Nav = {}
local function clamp(value, low, high) return math.max(low, math.min(high, value)) end
local function point(x, y, z) return {x = x, y = y, z = z} end
local function inside(p, floor, margin)
    return p.x >= floor.minX - margin and p.x <= floor.maxX + margin
        and p.z >= floor.minZ - margin and p.z <= floor.maxZ + margin
end
function Nav.currentFloor(position, floors, previous)
    for i, floor in ipairs(floors) do if inside(position, floor, .2) then return floor, i end end
    for i, floor in ipairs(floors) do
        if previous and (floor == previous or floor.part ~= nil and floor.part == previous.part
            or floor.part == nil and previous.part == nil and floor.minX == previous.minX
                and floor.maxX == previous.maxX and floor.minZ == previous.minZ
                and floor.maxZ == previous.maxZ and floor.top == previous.top) then return floor, i end
    end
end
function Nav.landed(position, jump, grounded, vy)
    if not jump or not grounded or math.abs(vy or 0) >= 3 then return false end
    local passed = jump.direction == 1 and position.x >= jump.landingX + .25
        or jump.direction == -1 and position.x <= jump.landingX - .25
    return passed and inside(position, jump.floor, 0) and math.abs(position.y - jump.landingY) < .75
end
function Nav.jumpOutcome(jump, position, grounded, vy, now)
    jump.maxRise = math.max(jump.maxRise or 0, position.y - jump.launchY)
    local elapsed = now - jump.at
    -- Client observations can arrive after server-owned flight, or skip its arc.
    if elapsed > .2 and Nav.landed(position, jump, grounded, vy) then return 'LANDED' end
    if elapsed < 2 then return nil end
    if position.y < math.min(jump.launchY, jump.landingY) - 1 then return 'FELL_BELOW_LANDING'
    elseif jump.maxRise < .4 then return 'NO_OBSERVED_ASCENT'
    else return 'LANDING_NOT_CONFIRMED' end
end
function Nav.plan(position, desired, floors, state, now, options)
    options = options or {}
    local jump = state.jump
    if jump then
        if jump.awaitingInput and now - jump.at > (options.inputTimeout or 1.4) then
            state.jump = nil
            return {target = position, crossing = true, attackAllowed = false,
                phase = 'Input confirmation timeout', fault = 'Jump key was not observed'}
        end
        if not jump.awaitingInput and Nav.landed(position, jump, options.grounded, options.vy) then state.jump = nil
        elseif jump.awaitingInput or now - jump.at < 2 then
            local target=jump.target
            local passedTarget=jump.direction==1 and position.x>=target.x or jump.direction==-1 and position.x<=target.x
            if not jump.awaitingInput and passedTarget and inside(position,jump.floor,-2)
                and position.y>=jump.landingY-.75 then
                -- A native body can still be above the authored landing height
                -- on an NPC. Hold over the destination instead of reversing
                -- toward the gap; strict landing and timeout remain unchanged.
                target=point(position.x,target.y,target.z)
            end
            return {target = target, crossing = true, attackAllowed = false, direction = jump.direction, phase = 'Flight'}
        else state.jump = nil end
    end
    local current, index = Nav.currentFloor(position, floors, state.previousFloor)
    if current and not inside(position, current, .2) then current, index = nil, nil end
    if not current and options.grounded and math.abs(options.vy or 0) <= 1 then
        local closest, distance
        for _, floor in ipairs(floors) do
            local dx = position.x - clamp(position.x, floor.minX, floor.maxX)
            local dz = position.z - clamp(position.z, floor.minZ, floor.maxZ)
            local outside = math.sqrt(dx * dx + dz * dz)
            if outside <= 1.1 and math.abs(position.y - (floor.top + 3)) < .75
                and (not distance or outside < distance) then closest, distance = floor, outside end
        end
        if closest then
            state.previousFloor = closest
            return {target = point(clamp(position.x, closest.minX + 2.2, closest.maxX - 1), position.y,
                clamp(position.z, closest.minZ + 2, closest.maxZ - 2)),
                crossing = false, attackAllowed = false, phase = 'Recover support edge'}
        end
    end
    if not current then return {target = position, crossing = false, attackAllowed = false, phase = 'No support'} end
    state.previousFloor = current
    local direction = desired.x < position.x and -1 or 1
    local neighbor = floors[index + direction]
    local beyond = direction == 1 and desired.x > current.maxX or direction == -1 and desired.x < current.minX
    local gap = neighbor and (direction == 1 and neighbor.minX > current.maxX + .2
        or direction == -1 and neighbor.maxX < current.minX - .2)
    local runUp = state.gapRunUp
    if runUp and (options.allowCrossing == false or not beyond or not gap or runUp.direction ~= direction
        or runUp.minX ~= current.minX or runUp.maxX ~= current.maxX) then state.gapRunUp=nil;runUp=nil end
    if options.allowCrossing ~= false and beyond and neighbor and not gap then
        local low, high = math.max(current.minZ, neighbor.minZ) + 2, math.min(current.maxZ, neighbor.maxZ) - 2
        if low > high then return {target = position, crossing = true, attackAllowed = false, phase = 'No shared crossing'} end
        local z = clamp(desired.z, low, high)
        -- Adjoining floors can narrow sideways even without an X gap. Align
        -- on the current support before ordinary walking crosses that seam.
        if position.z < low or position.z > high then
            local inset = math.min(.25, (high-low)/2)
            if inset <= .15 then return {target = position, crossing = true, attackAllowed = false, phase = 'No shared crossing'} end
            -- Target beyond the bridge's .15-stud movement deadzone while
            -- retaining the full two-stud corridor on either support.
            z = clamp(z, low+inset, high-inset)
            return {target = point(clamp(position.x, current.minX + 2.2, current.maxX - 2.2), current.top + 3, z),
                crossing = true, attackAllowed = false, direction = direction, phase = 'Align adjoining support'}
        end
        return {target = point(desired.x, desired.y, z), crossing = false, attackAllowed = true,
            direction = direction, phase = 'Walk'}
    end
    if options.allowCrossing ~= false and beyond and gap then
        local low, high = math.max(current.minZ, neighbor.minZ) + 2, math.min(current.maxZ, neighbor.maxZ) - 2
        if low > high then return {target = position, crossing = true, attackAllowed = false, phase = 'No shared crossing'} end
        local z = clamp(desired.z, low, high)
        local edge = direction == 1 and current.maxX or current.minX
        local target = point(edge - direction * .7, current.top + 3, z)
        local close = direction == 1 and position.x >= edge - (options.jumpLead or 2.5)
            or direction == -1 and position.x <= edge + (options.jumpLead or 2.5)
        if not runUp and close and options.grounded == false and math.abs(options.vy or 0)<1
            and math.abs(position.y-(current.top+3))<.75 then
            -- The caller's launch flag also requires real running speed. A
            -- nearby walking body first stages inward instead of running off
            -- the edge while the previous movement packet is still held.
            runUp={direction=direction,minX=current.minX,maxX=current.maxX,
                target=point(clamp(edge-direction*8,current.minX+2.2,current.maxX-2.2),current.top+3,z)}
            state.gapRunUp=runUp
        end
        if runUp then
            if math.abs(position.x-runUp.target.x)>.6 or math.abs(position.z-runUp.target.z)>1.5 then
                return {target=runUp.target,crossing=true,attackAllowed=false,direction=direction,phase='Stage gap run-up'}
            end
            state.gapRunUp=nil
        end
        if close and options.grounded and math.abs(position.z - z) < 1.5 and now - (state.lastJump or -100) > .7 then
            local landingX = direction == 1 and neighbor.minX or neighbor.maxX
            target = point(landingX + direction * 4, neighbor.top + 3, z)
            state.lastJump = now
            state.jump = {at = now, direction = direction, floor = neighbor, target = target,
                landingX = landingX, landingY = neighbor.top + 3, launchY = position.y}
            return {target = target, crossing = true, attackAllowed = false, direction = direction, phase = 'Jump', jump = true}
        end
        return {target = target, crossing = true, attackAllowed = false, direction = direction, phase = 'Approach gap'}
    end
    local x = desired.x
    if options.allowCrossing == false or not beyond or not neighbor then x = clamp(x, current.minX + 2.2, current.maxX - 1) end
    return {target = point(x, desired.y, clamp(desired.z, current.minZ + 2, current.maxZ - 2)),
        crossing = false, attackAllowed = true, direction = direction, phase = 'Walk'}
end
function Nav.keysForMove(direction, forward)
    local fx, fz = forward.x or 0, forward.z or -1
    local magnitude = math.sqrt(fx * fx + fz * fz)
    if magnitude < .001 then fx, fz, magnitude = 0, -1, 1 end
    fx, fz = fx / magnitude, fz / magnitude
    local x = (direction.x or 0) * -fz + (direction.z or 0) * fx
    local z = -(direction.x or 0) * fx - (direction.z or 0) * fz
    return {A = x < -.25 or nil, D = x > .25 or nil, W = z < -.25 or nil, S = z > .25 or nil}
end
local function keySet(keys)
    local result = {}
    for key, value in pairs(keys or {}) do
        if type(key) == 'number' then result[value] = true elseif value then result[key] = true end
    end
    return result
end
function Nav.consumeExpected(expected, key, now)
    local entry = expected[key]
    if not entry or entry.expires < now or entry.count <= 0 then expected[key] = nil; return false end
    entry.count -= 1
    if entry.count == 0 then expected[key] = nil end
    return true
end
function Nav.queueAttack(state, key, target, identity, now)
    if state.pending then return false end
    state.pending = {key = key, target = target, identity = identity, stage = state.stage, queuedAt = now}
    return true
end
function Nav.observeAttack(state, key, now)
    state.lastAttack = now
    if state.pending and state.pending.key == key then state.pending = nil end
end
function Nav.attackInputExpired(state, now)
    if state.pending and now - state.pending.queuedAt > 1.4 then state.pending = nil; return true end
    return false
end
function Nav.attackPlan(position, enemy, state, now, cooldown)
    if Nav.attackInputExpired(state, now) then
        return {target = position, retreat = false, attackReady = false, fault = 'Attack key was not observed'}
    end
    if state.pending then return {target = enemy, retreat = false, attackReady = false} end
    local elapsed = now - (state.lastAttack or -100)
    local retreat = elapsed >= .35 and elapsed < cooldown
    local target = enemy
    if retreat then
        local dx, dz = enemy.x - position.x, enemy.z - position.z
        local length = math.sqrt(dx * dx + dz * dz)
        if length > .01 then target = point(position.x - dx / length * 3, position.y, position.z - dz / length * 3) end
    end
    return {target = target, retreat = retreat, attackReady = elapsed >= cooldown}
end
function Nav.identity(data, h)
    if not data or not h then return nil end
    return table.concat({tostring(data.groupId), tostring(data.runId), tostring(h.actorId), tostring(h.attempt),
        tostring(h.connectionEpoch), tostring(data.levelEpoch)}, ':')
end
function Nav.syncStage(state, stage)
    if state.stage == stage then return false end
    state.stage, state.pending = stage, nil
    return true
end
function Nav.canPoll(data, h, identity, stage)
    return data ~= nil and h ~= nil and data.status == 'Active' and not data.fault
        and (data.view == nil or data.view == 'Playing') and h.status == 'Alive' and h.connected == true
        and not h.dying and Nav.identity(data, h) == identity
        and (stage == nil or (data.level or {}).stage == stage)
end
function Nav.inputBatch(heldKeys, desiredKeys, pulses, expected, now, running, duration)
    local actions, held = {}, keySet(heldKeys)
    local function add(action, key) table.insert(actions, {action = action, key_code = key}) end
    local orderedHeld = {}; for key in pairs(held) do table.insert(orderedHeld, key) end; table.sort(orderedHeld)
    for _, key in ipairs(orderedHeld) do add('keyUp', key) end
    if not running then return {actions = actions, heldKeys = {}} end
    local function expect(key)
        local entry = expected[key]
        expected[key] = {count = (entry and entry.expires >= now and entry.count or 0) + 1, expires = now + 3}
    end
    local movement = {}
    for _, key in ipairs({'W', 'A', 'S', 'D'}) do
        if desiredKeys[key] then expect(key); add('keyDown', key); table.insert(movement, key) end
    end
    if #pulses > 0 and pulses[1] ~= 'Space' and #movement > 0 then table.insert(actions, {action = 'wait', wait_time_ms = 40}) end
    for _, key in ipairs(pulses) do expect(key); add('keyPress', key) end
    if #movement > 0 then
        table.insert(actions, {action = 'wait', wait_time_ms = duration or 120})
        for _, key in ipairs(movement) do add('keyUp', key) end
    end
    return {actions = actions, heldKeys = {}}
end
return Nav
