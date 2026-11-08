-- TEMPORARY Studio client acceptance helper. Evaluate on a client, then inspect
-- _G.LevelRouteDriver.latest / .checkpoints. Only production Move/Jump/Attack are sent.
-- _G.LevelRouteDriver.stop('manual') stops it. autoCombat / autoBoss may be disabled.
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local player = Players.LocalPlayer
assert(player, 'Evaluate this helper on a client')
local previous = _G.LevelRouteDriver
if previous and previous.stop then previous.stop('replaced') end
local remotes = ReplicatedStorage:WaitForChild('BrickToadsGame')
local wire = remotes:WaitForChild('Intent')
local driver = {running = true, autoCombat = true, autoBoss = true, latest = nil,
    checkpoints = {}, jumps = {}, stopOnJumpFailure = true, jumpLead = 2.5,
    status = 'Waiting for production State', seq = math.max(1000000, previous and previous.seq or 0), started = os.clock()}
_G.LevelRouteDriver = driver
local stateConnection
local lastAttack, lastJump, lastCheckpoint, lastIdentity = -100, -100, '', nil
local jumpTarget, jumpUntil, previousFloor = nil, 0, nil
local faceSince
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

local function send(kind, extra)
    local data, h = driver.latest, hero()
    if not data or not h or data.status ~= 'Active' or h.status ~= 'Alive' or not h.connected or h.dying then return end
    driver.seq += 1
    local packet = {kind = kind, groupId = data.groupId, runId = data.runId, actorId = h.actorId,
        attempt = h.attempt, levelEpoch = data.levelEpoch, connectionEpoch = h.connectionEpoch, seq = driver.seq}
    for key, value in pairs(extra or {}) do packet[key] = value end
    wire:FireServer(packet)
end

function driver.stop(reason)
    if not driver.running then return end
    send('Move', {x = 0, z = 0})
    driver.running = false
    driver.status = reason or 'Stopped'
    log(driver.status)
    if stateConnection then stateConnection:Disconnect() end
end

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
    if sample.t > .2 and jumpTrial.maxRise > .4 and position.X >= jumpTrial.landingX + .25
        and (grounded or (math.abs(position.Y - jumpTrial.landingY) < .4 and math.abs(velocity.Y) < 3)) then
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
    send('Move', {x = direction.X, z = direction.Z})
    driver.target = target
end

local function navigate(position, desired, floors, now)
    if jumpTarget and now < jumpUntil then
        if position.X < jumpTarget.X or position.Y > jumpTarget.Y + .6 then
            moveToward(position, jumpTarget); return
        end
        jumpTarget = nil
    end
    local current, index
    for i, floor in ipairs(floors) do
        if position.X >= floor.minX - .2 and position.X <= floor.maxX + .2
            and position.Z >= floor.minZ - .2 and position.Z <= floor.maxZ + .2 then
            current, index = floor, i; previousFloor = floor; break
        end
    end
    current = current or previousFloor
    if not current then moveToward(position, desired); return end
    if not index then for i, floor in ipairs(floors) do if floor.part == current.part then index = i; break end end end
    local nextFloor = index and floors[index + 1]
    if nextFloor and desired.X > current.maxX and nextFloor.minX > current.maxX + .2 then
        local low, high = math.max(current.minZ, nextFloor.minZ) + 2, math.min(current.maxZ, nextFloor.maxZ) - 2
        local crossingZ = low <= high and math.clamp(desired.Z, low, high) or (current.minZ + current.maxZ) / 2
        local edge = Vector3.new(current.maxX - .7, current.top + 3, crossingZ)
        if position.X >= current.maxX - driver.jumpLead and math.abs(position.Z - crossingZ) < 1.5 and now - lastJump > .7 then
            lastJump = now
            jumpTarget = Vector3.new(nextFloor.minX + 4, nextFloor.top + 3, crossingZ)
            jumpUntil = now + 1.25
            jumpTrial = {at = now, launchY = position.Y, landingX = nextFloor.minX,
                landingY = nextFloor.top + 3, maxRise = 0, samples = {}, start = driver.physical,
                sentSeq = driver.seq + 1, from = current.part.Name, fromMaxX = current.maxX, toMinX = nextFloor.minX}
            table.insert(driver.jumps, jumpTrial)
            send('Jump')
            log('Jump SENT at X=' .. string.format('%.2f', position.X) .. ' to ' .. string.format('%.2f', jumpTarget.X))
            moveToward(position, jumpTarget)
        else moveToward(position, edge, .05) end
        return
    end
    -- Combat retreat stays on its current support. Forward travel may continue
    -- across an adjacent flat support; true gaps always use the branch above.
    local x = desired.X
    if not nextFloor or desired.X <= current.maxX then x = math.clamp(x, current.minX + 2.2, current.maxX - 1) end
    local z = math.clamp(desired.Z, current.minZ + 2, current.maxZ - 2)
    moveToward(position, Vector3.new(x, desired.Y, z))
end

local function nearestEnemy(data, actors, position)
    local ids = {}
    for _, enemy in ipairs((data.level or {}).enemies or {}) do
        if enemy.id ~= -99 and not enemy.dead and (enemy.hearts or 0) > 0
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
    local data, h = driver.latest, hero()
    if not data or not h then driver.status = 'Waiting for an assigned hero'; return end
    if h.status ~= 'Alive' or h.dying or not h.connected then driver.status = 'Waiting for living connected hero'; return end
    local body, actors, offset, floors = scene(data, h)
    if not body then driver.status = 'Waiting for streamed actor/world'; return end
    local identity = table.concat({tostring(data.groupId), tostring(h.actorId), tostring(h.attempt), tostring(h.connectionEpoch)}, ':')
    if identity ~= lastIdentity then
        if jumpTrial then
            jumpTrial.result = 'ACTOR_REPLACED'
            jumpTrial = nil
            if driver.stopOnJumpFailure then driver.stop('PAUSED: actor replaced during jump'); return end
        end
        lastIdentity = identity; previousFloor, jumpTarget = nil, nil
        log('Body ' .. identity)
    end
    local position, level = root(body).Position, data.level or {}
    driver.position = position - offset
    local humanoid = body:FindFirstChildOfClass('Humanoid')
    local velocity = root(body).AssemblyLinearVelocity
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
        local attack
        if enemy and driver.autoCombat then
            local toward = flat(enemy - position)
            desired = enemy
            if range < 7.7 and math.abs(enemy.Y - position.Y) < 5 then
                if now - lastAttack >= 1.1 then
                    faceSince = faceSince or now
                    if now - faceSince >= .15 then attack = 'Dash'; lastAttack = now; faceSince = nil end
                elseif now - lastAttack < .35 then faceSince = nil; desired = enemy
                elseif toward.Magnitude > .01 then faceSince = nil; desired = position - toward.Unit * 3 end
            end
        end
        navigate(position, desired, floors, now)
        if attack then send('Attack', {attack = attack}) end
    elseif level.stage == 'Boss' and driver.autoBoss then
        driver.status = 'Guardian pickup/throw'
        local interaction = data.interaction or {}
        if interaction.available and now - lastAttack >= .65 then
            send('Attack', {attack = 'Punch'}); lastAttack = now
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
        navigate(position, desired, floors, now)
    elseif level.stage == 'Exit' then
        driver.status = 'Walking to earned exit'
        navigate(position, Vector3.new(680, 3, 0) + offset, floors, now)
    else driver.status = 'Waiting at ' .. tostring(level.stage); send('Move', {x = 0, z = 0}) end
end

task.spawn(function()
    log('Started input-only driver; no world/state mutations')
    while driver.running do
        if os.clock() - driver.started > 180 then driver.stop('TIMEOUT after 180s'); break end
        local ok, failure = pcall(tick, os.clock())
        if not ok then driver.stop('DRIVER ERROR: ' .. tostring(failure)); break end
        task.wait(1 / 15)
    end
end)
return driver
