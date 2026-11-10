-- Studio QA only: observe the live course and return ordinary player inputs.
-- This module never calls a controller, moves a body, or changes game state.
-- Navigation follows the normal-input proofs in tests/campaign_modes.
local Pilot = {}
local states = setmetatable({}, { __mode = 'k' })

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function sign(value)
    return value > 0 and 1 or value < 0 and -1 or 0
end

local function input(x, z, jump, primary)
    local length = math.sqrt(x * x + z * z)
    if length > 1 then x, z = x / length, z / length end
    return { x = x, z = z, jump = jump == true, primary = primary == true, run = false }
end

local function stateFor(modes, slot, actor, token)
    local group = states[modes]
    if not group then group = {}; states[modes] = group end
    local state = group[slot]
    if not state or state.actorId ~= actor.actorId or state.attempt ~= actor.attempt or state.token ~= token then
        state = { actorId = actor.actorId, attempt = actor.attempt, token = token, hazard = 1 }
        group[slot] = state
    end
    return state
end

local function ascent(actor)
    local errorZ = -5 - actor.position.z
    local z = math.abs(errorZ) > .15 and sign(errorZ) or 0
    local x = actor.position.y > 95 and (actor.position.x > -7.8 and -1 or 0) or 0
    return input(x, z, actor.grounded and actor.position.y < 98)
end

local function tubes(modes, course, actor, state)
    local hazard = course.hazards[state.hazard]
    while hazard and actor.position.x > hazard.x + 8 do
        state.hazard += 1
        state.passing = false
        hazard = course.hazards[state.hazard]
    end
    local desired = 15
    if hazard and hazard.z == 0 and not state.passing and hazard.x - actor.position.x < 32 then
        local motion = hazard.motion
        local phase = (modes.elapsed / motion.period * math.pi * 2 + motion.phase) % (math.pi * 2)
        local distance = hazard.x - 12 - actor.position.x
        desired = clamp(distance * 2, -6, 15)
        if math.abs(distance) < 1.2 and math.abs(actor.velocity.x) < 3 and phase > 2.9 and phase < 3.2 then
            state.passing = true
            desired = 15
        end
    end
    if actor.medium ~= 'Water' then return input(desired / 16, 0) end
    local current = {}
    for _, water in ipairs(course.media) do
        if actor.position.x >= water.minX and actor.position.x <= water.maxX then
            current = water.current or current
            break
        end
    end
    local x = clamp((desired * 1.4 - (current.x or 0)) / 28 + (desired - actor.velocity.x) * .2, -1, 1)
    local z = clamp((actor.position.y - 3) * .4 + actor.velocity.y * .3 + (3 + (current.y or 0)) / 28, -1, 1)
    return input(x, z)
end

local function race(ctx, modes, course, actor, state)
    local bomb = course.bombs[modes.bombIndex]
    if not bomb then
        local finish = course.finishPoint
        return input(clamp((finish.x - actor.position.x) * .5, -1, 1), clamp((finish.z - actor.position.z) * .5, -1, 1))
    end
    if state.bomb ~= modes.bombIndex then
        state.bomb = modes.bombIndex
        state.phase = 'Align'
        state.takeoffY = actor.position.y
    end
    local dx = bomb.position.x - actor.position.x
    local x, primary = clamp(dx * .25, -1, 1), false
    -- Held input can last several physics frames. Approach the edge with
    -- proportional steering and turn inward as soon as descent is observed;
    -- an extra full-speed outward packet can otherwise skip the bomb's floor.
    local function leaveFloor()
        state.phase = 'Out'
        state.takeoffY = actor.position.y
        local index = actor.support and tonumber(string.match(actor.support, '^floor%-(%d+)$'))
        local floor = index and course.platforms[index]
        state.edgeZ = floor and floor.z + floor.d / 2 + .6 or 14.6
    end
    if actor.grounded and actor.position.y <= bomb.position.y + .1 then state.phase = 'Defuse' end
    if state.phase == 'Align' then
        if math.abs(dx) < .3 and actor.grounded then leaveFloor() end
    elseif state.phase == 'Out' then
        if actor.position.y < state.takeoffY - .5 then state.phase = 'In' end
    elseif state.phase == 'In' then
        if actor.grounded and actor.position.y < state.takeoffY - .5 then
            leaveFloor()
        end
    end
    local targetZ = state.phase == 'Out' and state.edgeZ or 0
    local z = clamp((targetZ - actor.position.z) * .25, -1, 1)
    if state.phase == 'Defuse' then
        primary = modes:interaction(ctx.slot).available == true
    end
    return input(x, z, false, primary)
end

local function tower(modes, course, actor)
    local radius = math.sqrt(actor.position.x ^ 2 + actor.position.z ^ 2)
    local wind = math.sin(modes.elapsed * .8 + (course.windPhase or 0)) * course.windForce
    return input(1, clamp((23 - radius) * 1.7 - wind / 8, -1, 1), actor.grounded)
end

function Pilot.plan(ctx)
    local modes = ctx.modes
    local definition = ctx.definition
    local actor = ctx.actor or (modes and modes.actors[ctx.slot])
    -- Returning nil leaves arena combat and later campaign transitions to the
    -- harness. Completing a course is always the real Modes implementation's job.
    if not modes or not actor or actor.finished or modes.closed then return nil end
    local course = definition.course
    local mode = definition.mode
    if mode == 'Ascent' then return ascent(actor) end
    if mode == 'Tower' then return tower(modes, course, actor) end
    if mode == 'Clinger' then
        local segment = course.path[actor.segment]
        return input(segment and segment.direction.x or 0, segment and segment.direction.z or 0)
    end
    if mode == 'Finale' then
        local finish = course.finishPoint
        return input(clamp((finish.x - actor.position.x) * .5, -1, 1), clamp((finish.z - actor.position.z) * .5, -1, 1))
    end
    if mode == 'Tubes' or mode == 'Race' then
        local state = stateFor(modes, ctx.slot, actor, ctx.stageToken)
        if mode == 'Tubes' then return tubes(modes, course, actor, state) end
        return race(ctx, modes, course, actor, state)
    end
    return nil
end

return Pilot
