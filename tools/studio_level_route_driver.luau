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
        elseif jump.awaitingInput or now - jump.at < 1.4 then
            return {target = jump.target, crossing = true, attackAllowed = false, direction = jump.direction, phase = 'Flight'}
        else state.jump = nil end
    end
    local current, index = Nav.currentFloor(position, floors, state.previousFloor)
    if not current then return {target = position, crossing = false, attackAllowed = false, phase = 'No support'} end
    state.previousFloor = current
    local direction = desired.x < position.x and -1 or 1
    local neighbor = floors[index + direction]
    local beyond = direction == 1 and desired.x > current.maxX or direction == -1 and desired.x < current.minX
    local gap = neighbor and (direction == 1 and neighbor.minX > current.maxX + .2
        or direction == -1 and neighbor.maxX < current.minX - .2)
    if options.allowCrossing ~= false and beyond and gap then
        local low, high = math.max(current.minZ, neighbor.minZ) + 2, math.min(current.maxZ, neighbor.maxZ) - 2
        if low > high then return {target = position, crossing = true, attackAllowed = false, phase = 'No shared crossing'} end
        local z = clamp(desired.z, low, high)
        local edge = direction == 1 and current.maxX or current.minX
        local target = point(edge - direction * .7, current.top + 3, z)
        local close = direction == 1 and position.x >= edge - (options.jumpLead or 2.5)
            or direction == -1 and position.x <= edge + (options.jumpLead or 2.5)
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
if not game then return Nav end

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')
local player = Players.LocalPlayer
assert(player, 'Evaluate this helper on a client')
local previous = _G.LevelRouteDriver
if previous and previous.stop then previous.stop('replaced') end
local remotes = ReplicatedStorage:WaitForChild('BrickToadsGame')
local driver = {running = true, autoCombat = true, autoBoss = true, latest = nil,
    checkpoints = {}, jumps = {}, stopOnJumpFailure = true, jumpLead = 2.5, timeoutSeconds = 300,
    status = 'Waiting for production State', started = os.clock(), inputQueue = {},
    desiredMove = Vector3.zero, expectedSyntheticKey = {}}
_G.LevelRouteDriver = driver
local stateConnection, inputConnection
local lastAttack, lastCheckpoint, lastIdentity = -100, '', nil
local navigation = {}
local jumpTrial
local exitTargets = {{2, 0}, {122, 0}, {234, 0}, {358, -6}, {484, 0}, {588, 0}}

local function log(message)
    local entry = {at = os.clock() - driver.started, message = message}
    table.insert(driver.checkpoints, entry)
    if #driver.checkpoints > 160 then table.remove(driver.checkpoints, 1) end
    print('[LEVEL-ROUTE-QA] ' .. string.format('%.1f ', entry.at) .. message)
end

local function hero()
    local data = driver.latest
    if not data then return nil end
    for _, value in ipairs(data.heroes or {}) do if value.slot == data.mine then return value end end
end

local function queueKey(key)
    for _, entry in ipairs(driver.inputQueue) do if entry.key == key then return end end
    table.insert(driver.inputQueue, {key = key, identity = lastIdentity})
end

function driver.stop(reason)
    if not driver.running then return end
    driver.running, driver.desiredMove, driver.inputQueue = false, Vector3.zero, {}
    driver.status = reason or 'Stopped'
    log(driver.status)
    if stateConnection then stateConnection:Disconnect() end
    if inputConnection then inputConnection:Disconnect() end
end

local function plain(v) return point(v.X, v.Y, v.Z) end
function driver:pollInputs(heldKeys)
    local camera = workspace.CurrentCamera
    local forward = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    local keys = Nav.keysForMove(plain(self.desiredMove), plain(forward))
    local pulses, jumping = {}, false
    for _, entry in ipairs(self.inputQueue) do
        if entry.identity == lastIdentity then
            table.insert(pulses, entry.key)
            if entry.key == 'Space' then jumping = true end
        end
    end
    self.inputQueue = {}
    local batch = Nav.inputBatch(heldKeys, keys, pulses, self.expectedSyntheticKey, os.clock(), self.running,
        jumping and 650 or 120)
    batch.running, batch.status = self.running, self.status
    batch.summary = {position = self.physical, target = self.target and plain(self.target),
        phase = self.navigationPhase, queued = #pulses, jumps = #self.jumps}
    return batch
end
inputConnection = UserInputService.InputBegan:Connect(function(input)
    local key = input.KeyCode.Name
    if key == 'F8' then driver.stop('Manual input took over'); return end
    if key == 'W' or key == 'A' or key == 'S' or key == 'D' or key == 'F' or key == 'R' or key == 'Space' then
        if not Nav.consumeExpected(driver.expectedSyntheticKey, key, os.clock()) then
            driver.stop('Manual input took over'); return
        end
        if key == 'Space' and navigation.jump and navigation.jump.awaitingInput then
            navigation.jump.awaitingInput, navigation.jump.at = nil, os.clock()
            jumpTrial = {at = os.clock(), launchY = driver.worldPosition.Y, direction = navigation.jump.direction,
                landingX = navigation.jump.landingX, landingY = navigation.jump.landingY,
                floor = navigation.jump.floor, maxRise = 0, samples = {}, start = driver.physical}
            table.insert(driver.jumps, jumpTrial)
            log('Jump KEY ' .. tostring(jumpTrial.direction) .. ' at X=' .. string.format('%.2f', driver.worldPosition.X))
        end
    end
end)

stateConnection = remotes:WaitForChild('State').OnClientEvent:Connect(function(data)
    if type(data) ~= 'table' then return end
    driver.latest = data
    local h = hero()
    local level = data.level or {}
    local checkpoint = table.concat({tostring(data.groupId), tostring(level.zoneIndex), tostring(level.stage),
        tostring(h and h.attempt), tostring(h and h.status), tostring(level.bossHits), tostring(data.notice)}, ':')
    if checkpoint ~= lastCheckpoint then
        lastCheckpoint = checkpoint
        log(checkpoint)
    end
    if data.fault then driver.stop('FAULT: ' .. tostring(data.fault))
    elseif data.status == 'Won' or data.status == 'Lost' then driver.stop('OBSERVED ' .. data.status) end
end)

local function root(model)
    return model and model:FindFirstChild('HumanoidRootPart')
end

local function scene(data, h)
    local world = workspace:FindFirstChild(data.worldName or '')
    local actors, geometry = world and world:FindFirstChild('Actors'), world and world:FindFirstChild('Geometry')
    if not actors or not geometry then return nil end
    local body
    for _, model in ipairs(actors:GetChildren()) do
        if model:GetAttribute('ActorId') == h.actorId then body = model; break end
    end
    if not root(body) then return nil end
    local offset, floors = Vector3.zero, {}
    for _, part in ipairs(geometry:GetChildren()) do
        if part:IsA('BasePart') and part.Name == 'DistrictSupport' then
            if part:GetAttribute('ZoneIndex') == 1 then offset = part.Position - Vector3.new(-39, -1, 0) end
            if (part:GetAttribute('ZoneIndex') or 99) <= ((data.level or {}).zoneIndex or 1) then
                table.insert(floors, {part = part, minX = part.Position.X - part.Size.X / 2,
                    maxX = part.Position.X + part.Size.X / 2, minZ = part.Position.Z - part.Size.Z / 2,
                    maxZ = part.Position.Z + part.Size.Z / 2, top = part.Position.Y + part.Size.Y / 2})
            end
        end
    end
    table.sort(floors, function(a, b) return a.minX < b.minX end)
    return body, actors, offset, floors
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function observeJump(body, position, offset, h, now)
    if not jumpTrial then return end
    local part, humanoid = root(body), body:FindFirstChildOfClass('Humanoid')
    local velocity, localPosition = part.AssemblyLinearVelocity, position - offset
    local grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
    jumpTrial.maxRise = math.max(jumpTrial.maxRise, position.Y - jumpTrial.launchY)
    local sample = {t = now - jumpTrial.at, x = localPosition.X, y = localPosition.Y, z = localPosition.Z,
        vx = velocity.X, vy = velocity.Y, vz = velocity.Z, grounded = grounded,
        humanoidState = humanoid and humanoid:GetState().Name,
        platformStand = humanoid and humanoid.PlatformStand, anchored = part.Anchored,
        attempt = h.attempt, notice = driver.latest.notice}
    table.insert(jumpTrial.samples, sample)
    local result
    if sample.t > .2 and jumpTrial.maxRise > .4 and Nav.landed(plain(position), jumpTrial, grounded, velocity.Y) then
        result = 'LANDED'
    elseif sample.t > .3 and jumpTrial.maxRise < .4 then result = 'NO_OBSERVED_ASCENT'
    elseif sample.t > .2 and position.Y < math.min(jumpTrial.launchY, jumpTrial.landingY) - 1 then result = 'FELL_BELOW_LANDING'
    elseif sample.t > 1.4 then result = 'LANDING_NOT_CONFIRMED' end
    if result then
        jumpTrial.result = result
        log('Jump ' .. result .. ' maxRise=' .. string.format('%.2f', jumpTrial.maxRise)
            .. ' x/y=' .. string.format('%.2f/%.2f', localPosition.X, localPosition.Y))
        jumpTrial = nil
        if result ~= 'LANDED' and driver.stopOnJumpFailure then driver.stop('PAUSED after failed jump: ' .. result) end
    end
end

local function moveToward(position, target, stopDistance)
    local delta = flat(target - position)
    local direction = delta.Magnitude > (stopDistance or .6) and delta.Unit or Vector3.zero
    driver.desiredMove = direction
    driver.target = target
end

local function applyPlan(position, plan)
    if plan.fault then driver.stop('PAUSED: ' .. plan.fault); return end
    driver.navigationPhase = plan.phase
    moveToward(position, Vector3.new(plan.target.x, plan.target.y, plan.target.z), plan.crossing and .05 or .6)
    if plan.jump then navigation.jump.awaitingInput = true; queueKey('Space') end
end

local function nearestEnemy(data, actors, position)
    local ids = {}
    for _, enemy in ipairs((data.level or {}).enemies or {}) do
        -- Source Life0 remains a living combat actor until actual underflow.
        if enemy.id ~= -99 and not enemy.dead
            and (enemy.zoneIndex == nil or enemy.zoneIndex == data.level.zoneIndex) then ids[enemy.id] = true end
    end
    local best, range
    for _, model in ipairs(actors:GetChildren()) do
        local kind, part = model:GetAttribute('EnemyKind'), root(model)
        if part and (kind == 'Pig' or kind == 'Walker' or kind == 'Dragon') then
            local id = tonumber(tostring(model:GetAttribute('ActorId')):match(':(%-?%d+)$'))
            if ids[id] then
                local distance = (part.Position - position).Magnitude
                if not range or distance < range then best, range = part.Position, distance end
            end
        end
    end
    return best, range
end

local function tick(now)
    driver.desiredMove = Vector3.zero
    local data, h = driver.latest, hero()
    if not data or not h then driver.status = 'Waiting for an assigned hero'; return end
    if data.status ~= 'Active' or h.status ~= 'Alive' or h.dying or not h.connected then
        driver.inputQueue = {}; driver.status = 'Waiting for living connected hero'; return
    end
    local body, actors, offset, floors = scene(data, h)
    if not body then driver.inputQueue = {}; driver.status = 'Waiting for streamed actor/world'; return end
    local identity = table.concat({tostring(data.groupId), tostring(data.runId), tostring(h.actorId), tostring(h.attempt),
        tostring(h.connectionEpoch), tostring(data.levelEpoch)}, ':')
    if identity ~= lastIdentity then
        if jumpTrial then
            jumpTrial.result = 'ACTOR_REPLACED'
            jumpTrial = nil
            if driver.stopOnJumpFailure then driver.stop('PAUSED: actor replaced during jump'); return end
        end
        lastIdentity, navigation, driver.inputQueue = identity, {}, {}
        log('Body ' .. identity)
    end
    local position, level = root(body).Position, data.level or {}
    driver.position, driver.worldPosition = position - offset, position
    local humanoid = body:FindFirstChildOfClass('Humanoid')
    local velocity = root(body).AssemblyLinearVelocity
    local options = {grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air,
        vy = velocity.Y, jumpLead = driver.jumpLead}
    driver.physical = {x = driver.position.X, y = driver.position.Y, z = driver.position.Z,
        vx = velocity.X, vy = velocity.Y, vz = velocity.Z,
        floor = humanoid and humanoid.FloorMaterial.Name, state = humanoid and humanoid:GetState().Name,
        anchored = root(body).Anchored, platformStand = humanoid and humanoid.PlatformStand,
        snapshotAge = data.now and workspace:GetServerTimeNow() - data.now, notice = data.notice}
    observeJump(body, position, offset, h, now)
    if not driver.running then return end
    if level.stage == 'Route' then
        driver.status = 'Route zone ' .. tostring(level.zoneIndex)
        local destination = exitTargets[level.zoneIndex or 1] or exitTargets[6]
        local desired = Vector3.new(destination[1], 3, destination[2]) + offset
        local enemy, range = nearestEnemy(data, actors, position)
        if enemy and driver.autoCombat then desired = enemy end
        local plan = Nav.plan(plain(position), plain(desired), floors, navigation, now, options)
        -- Crossing wins before combat, including any cooldown retreat.
        if enemy and driver.autoCombat and plan.attackAllowed then
            local toward = flat(enemy - position)
            if range < 7.7 and math.abs(enemy.Y - position.Y) < 5 then
                if now - lastAttack >= 1.1 then
                    local facing = flat(root(body).CFrame.LookVector)
                    if toward.Magnitude > .01 and facing.Magnitude > .01 and facing.Unit:Dot(toward.Unit) > .65 then
                        queueKey('R'); lastAttack = now
                    end
                elseif now - lastAttack >= .35 and toward.Magnitude > .01 then
                    desired = position - toward.Unit * 3
                    options.allowCrossing = false
                    plan = Nav.plan(plain(position), plain(desired), floors, navigation, now, options)
                end
            end
        end
        if plan.crossing then
            for i = #driver.inputQueue, 1, -1 do
                if driver.inputQueue[i].key ~= 'Space' then table.remove(driver.inputQueue, i) end
            end
        end
        applyPlan(position, plan)
    elseif level.stage == 'Boss' and driver.autoBoss then
        driver.status = 'Guardian pickup/throw'
        local interaction = data.interaction or {}
        if interaction.available and now - lastAttack >= .65 then
            queueKey('F'); lastAttack = now
            log('Interaction ' .. tostring(interaction.label))
        end
        local desired = Vector3.new(600, 3, math.sin(now * 1.8) * 8) + offset
        if not interaction.carrying then
            local best
            for _, model in ipairs(actors:GetChildren()) do
                local part = root(model)
                if part and model:GetAttribute('ProjectileMode') == 'Ground' then
                    local distance = (part.Position - position).Magnitude
                    if not best or distance < best then best = distance; desired = part.Position end
                end
            end
        end
        applyPlan(position, Nav.plan(plain(position), plain(desired), floors, navigation, now, options))
    elseif level.stage == 'Exit' then
        driver.status = 'Walking to earned exit'
        applyPlan(position, Nav.plan(plain(position), plain(Vector3.new(680, 3, 0) + offset), floors, navigation, now, options))
    else driver.inputQueue = {}; driver.status = 'Waiting at ' .. tostring(level.stage) end
end

task.spawn(function()
    log('Started keyboard planner; relay pollInputs through ordinary client controls')
    while driver.running do
        if os.clock() - driver.started > driver.timeoutSeconds then driver.stop('TIMEOUT after '..driver.timeoutSeconds..'s'); break end
        local ok, failure = pcall(tick, os.clock())
        if not ok then driver.stop('DRIVER ERROR: ' .. tostring(failure)); break end
        task.wait(1 / 15)
    end
end)
return driver
