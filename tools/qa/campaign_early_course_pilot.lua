-- QA ONLY: normal-input pilots for an explicitly requested Studio playthrough.
-- This file is outside src and is never packaged into the player runtime.
-- The plan reads live state and returns inputs. It never writes game state,
-- invokes actions, moves actors, removes enemies, or changes course geometry.
--
-- API: require(...).plan({definition, modes, actor, slot, now, dt,
--                       stageToken, world, director?, position?, mustFight?})
-- definition/modes/actor/world are read-only references. Native position is
-- read through world:position(slot) only while a vehicle is not yet boarded.
-- The caller applies {x,z,jump,primary,run} through its ordinary input boundary.
-- yieldCombat is advisory for the caller's ordinary entry-combat pilot.
local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function sign(value)
    return value > 0 and 1 or value < 0 and -1 or 0
end

local function input(x, z, jump, primary)
    return {x = x or 0, z = z or 0, jump = jump == true, primary = primary == true, run = false}
end

-- Same input-only lane selection used by tests/campaign_modes/CourseDrivers.
local function laneGroups(course)
    local groups = {}
    for _, hazard in ipairs(course.hazards) do
        if hazard.d < 40 or hazard.kind == 'Overhead' then
            local group = groups[#groups]
            if not group or hazard.x - group.lastX > 40 then
                group = {hazards = {}, lastX = hazard.x}
                groups[#groups + 1] = group
            end
            group.hazards[#group.hazards + 1] = hazard
            group.lastX = hazard.x
        end
    end
    local lanes, costs = {-14, 0, 14}, {}
    for groupIndex = #groups, 1, -1 do
        costs[groupIndex] = {}
        for laneIndex, lane in ipairs(lanes) do
            local valid = true
            for _, hazard in ipairs(groups[groupIndex].hazards) do
                if math.abs(lane - hazard.z) <= hazard.d / 2 + 1.3 then valid = false end
            end
            if valid then
                local future = 0
                if costs[groupIndex + 1] then
                    future = math.huge
                    for nextIndex, nextLane in ipairs(lanes) do
                        future = math.min(future, (costs[groupIndex + 1][nextIndex] or math.huge) + math.abs(nextLane - lane))
                    end
                end
                costs[groupIndex][laneIndex] = future
            end
        end
    end
    local previous = 0
    for groupIndex, group in ipairs(groups) do
        local best = math.huge
        for laneIndex, lane in ipairs(lanes) do
            local score = (costs[groupIndex][laneIndex] or math.huge) + math.abs(lane - previous)
            if score < best then best, group.lane = score, lane end
        end
        previous = group.lane or 0
    end
    return groups
end

local FIXED = 1 / 60
-- Both production projectile stores use world-local coordinates. Their clocks
-- differ: course shots expire on modes.elapsed, enemy effects on enemy.now.
local function liveThreats(context)
    local threats, keys = {}, {}
    local modes = context.modes
    for id, shot in pairs(modes.projectiles or {}) do
        local remaining = shot.expires - modes.elapsed
        if remaining > 0 then
            local p, v = shot.position, shot.velocity
            local key = 'course:' .. tostring(id)
            threats[#threats + 1] = {x=p.x,y=p.y,z=p.z,vx=v.x,vy=v.y,vz=v.z,remaining=remaining,box=true}
            keys[#keys + 1] = key
        end
    end
    local enemies = context.director and context.director.campaignEnemies
    if enemies then
        for id, shot in pairs(enemies.projectiles or {}) do
            local remaining = shot.expiresAt - (enemies.now or context.now)
            if remaining > 0 then
                local p, direction = shot.position, shot.direction
                local obstacle = shot.mode == 'Obstacle'
                threats[#threats + 1] = {x=p.x,y=p.y,z=p.z,vx=direction.x*shot.speed,
                    vy=obstacle and -18 or 0,vz=direction.z*shot.speed,
                    groundY=obstacle and shot.groundY or nil,remaining=remaining,
                    radius=obstacle and 3 or shot.mode=='GasCloud' and 4 or 1.8}
                keys[#keys + 1] = 'enemy:' .. tostring(id)
            end
        end
    end
    table.sort(keys)
    return threats, table.concat(keys, '|')
end

local function relativeBox(x:number,y:number,z:number,dx:number,dy:number,dz:number,ex:number,ey:number,ez:number)
    local low, high = 0, 1
    for _, row in ipairs({{x,dx,ex},{y,dy,ey},{z,dz,ez}}) do
        local origin, delta, extent = row[1], row[2], row[3]
        if math.abs(delta) < 1e-8 then
            if math.abs(origin) > extent then return false end
        else
            local first, last = (-extent-origin)/delta, (extent-origin)/delta
            if first > last then first, last = last, first end
            low, high = math.max(low,first), math.min(high,last)
            if low > high then return false end
        end
    end
    return true
end

local function threatPosition(shot, at)
    local y = shot.y + shot.vy*at
    if shot.groundY then y = math.max(shot.groundY,y) end
    return shot.x+shot.vx*at,y,shot.z+shot.vz*at
end

local function liveHit(x0,y0,z0,x1,y1,z1,shot,from,to)
    if from > shot.remaining then return false end
    local sx0,sy0,sz0 = threatPosition(shot,from)
    local sx1,sy1,sz1 = threatPosition(shot,math.min(to,shot.remaining))
    local x,y,z = x0-sx0,y0-sy0,z0-sz0
    local dx,dy,dz = x1-sx1-x,y1-sy1-y,z1-sz1-z
    if shot.box then return relativeBox(x,y,z,dx,dy,dz,2.1,3,1.7) end
    local length = dx*dx+dy*dy+dz*dz
    local at = length > 0 and clamp(-(x*dx+y*dy+z*dz)/length,0,1) or 0
    -- Small QA reaction margin; the actual enemy collision remains unchanged.
    return (x+dx*at)^2+(y+dy*at)^2+(z+dz*at)^2 <= (shot.radius+.25)^2
end

local function futureSpeed(course,modes,at)
    local group = modes.vehicleGroup
    if not group then return math.min(course.maxSpeed,course.speed+(modes.elapsed+at)*course.acceleration) end
    local target = math.min(course.maxSpeed,course.speed+((group.elapsed or 0)+at)*course.acceleration)
    return math.min(target,(group.speed or course.speed)+((course.restart and course.restart.acceleration) or 110)*at)
end

local function jetHit(x0:number,y0:number,x1:number,y1:number,hazard:any,at:number)
    if hazard.kind == 'ElectricGate' and math.sin(at * 2) <= .1 then return false end
    local low, high = 0, 1
    for _, row in ipairs({{x0 - hazard.x, x1 - x0, hazard.w / 2 + 1.6},
        {y0 - hazard.y, y1 - y0, hazard.h / 2 + 2.85}}) do
        local start, delta, extent = row[1], row[2], row[3]
        if math.abs(delta) < 1e-8 then
            if math.abs(start) > extent then return false end
        else
            local first, last = (-extent - start) / delta, (extent - start) / delta
            if first > last then first, last = last, first end
            low, high = math.max(low, first), math.min(high, last)
            if low > high then return false end
        end
    end
    return true
end

-- Read-only, bounded receding input search from tests/campaign_modes/JetPlanner.
-- Candidate future positions are local numbers, never writes to the live actor.
local function jetInput(definition, modes, actor, threats,holdSeconds)
    local course = definition.course
    -- Search actions must remain safe for the interval for which an RPC may
    -- hold them. Physics still integrates at its ordinary fixed 60Hz step.
    local blockFrames=math.max(6,math.ceil(holdSeconds/FIXED-1e-7))
    local depth=math.ceil(1.8/(blockFrames*FIXED))
    local frontier = {{y = actor.position.y, vy = actor.velocity.y, cost = 0, first = 0}}
    local x, elapsed, fallback = actor.position.x, modes.elapsed, 0
    for _ = 1, depth do
        local nextStates, xEnd, timeEnd = {}, x, elapsed
        for _ = 1, blockFrames do
            timeEnd += FIXED
            xEnd += futureSpeed(course,modes,timeEnd-modes.elapsed) * FIXED
        end
        for _, state in ipairs(frontier) do
            for _, candidate in ipairs({-1, 0, 1}) do
                local y, vy, sx, at, alive = state.y, state.vy, x, elapsed, true
                for _ = 1, blockFrames do
                    local oldX, oldY = sx, y
                    at += FIXED
                    sx += futureSpeed(course,modes,at-modes.elapsed) * FIXED
                    vy = clamp(vy - candidate * 48 * FIXED, -17, 17) * math.exp(-2 * FIXED)
                    y = clamp(y + vy * FIXED, course.altitudeMin, course.altitudeMax)
                    for _, hazard in ipairs(course.hazards) do
                        if math.abs(hazard.x - sx) < 5 and jetHit(oldX, oldY, sx, y, hazard, at) then alive = false; break end
                    end
                    if alive then for _, shot in ipairs(threats) do
                        if liveHit(oldX,oldY,actor.position.z,sx,y,actor.position.z,shot,at-modes.elapsed-FIXED,at-modes.elapsed) then alive=false;break end
                    end end
                    if not alive then break end
                end
                if alive then
                    local target = xEnd > course.finishPoint.x - 72 and 5.5 or 17
                    local cost = state.cost + candidate * candidate * .005 + (y - target) ^ 2 * .0001
                    local priority = cost
                    for _, hazard in ipairs(course.hazards) do
                        local dx = hazard.x - xEnd
                        if dx > 0 and dx < 90 then priority += math.max(0, 7 - math.abs(y - hazard.y)) ^ 2 / (dx + 5) end
                    end
                    local row = {y = y, vy = vy, cost = cost, priority = priority,
                        first = state.depth and state.first or candidate, depth = true}
                    local key = math.floor(y * 2 + .5) .. ':' .. math.floor(vy + .5)
                    local old = nextStates[key]
                    if not old or row.priority < old.priority then nextStates[key] = row end
                end
            end
        end
        local states = {}
        for _, state in pairs(nextStates) do states[#states + 1] = state end
        if #states == 0 then return fallback end
        table.sort(states, function(a, b) return a.priority < b.priority end)
        while #states > 140 do table.remove(states) end
        fallback, frontier, x, elapsed = states[1].first, states, xEnd, timeEnd
    end
    return fallback
end

local function iceLaneClearance(course,modes,actor,hazard,target,cadence)
    local x,z,vx,vz=actor.position.x,actor.position.z,actor.velocity.x,actor.velocity.z
    local hold=math.max(1,math.ceil(math.max(.1,cadence or .1)/FIXED))
    local ax,az=0,0
    local clearance,crossed=math.huge,false
    for frame=1,240 do
        if (frame-1)%hold==0 then
            az=clamp((target-z)*.6-vz*.5,-1,1)
            local length=math.sqrt(1+az*az);ax,az=1/length,az/length
        end
        vx=clamp(vx+ax*course.acceleration*FIXED,-course.maxSpeed,course.maxSpeed)
        vz=clamp(vz+az*course.acceleration*FIXED,-course.maxSpeed,course.maxSpeed)
        local friction=math.exp(-course.friction*FIXED*.18)
        vx*=friction;vz*=friction;x+=vx*FIXED;z+=vz*FIXED
        if math.abs(x-hazard.x)<=hazard.w/2+2.1 then
            local motion=hazard.motion
            local hz=hazard.z+math.sin((modes.elapsed+frame*FIXED)/motion.period*math.pi*2+motion.phase)*motion.amplitude
            clearance=math.min(clearance,math.abs(z-hz)-hazard.d/2-1.5);crossed=true
        end
        if x>hazard.x+hazard.w/2+2.1 then break end
    end
    return crossed and clearance or -math.huge
end

local function ice(definition, modes, actor, state)
    local course, position, velocity = definition.course, actor.position, actor.velocity
    local forward=1
    local hazard = course.hazards[state.hazardIndex]
    while hazard and position.x > hazard.x + 7 do
        state.hazardIndex += 1
        hazard = course.hazards[state.hazardIndex]
    end
    if not hazard then state.targetZ = 0 end
    if hazard and (state.plannedHazard ~= state.hazardIndex or state.iceWaiting) and hazard.x - position.x < 58 then
        local at = modes.elapsed + (hazard.x - position.x) / math.max(18, velocity.x)
        local z = hazard.z
        if hazard.motion and hazard.motion.axis == 'z' then
            z += math.sin(at / hazard.motion.period * math.pi * 2 + hazard.motion.phase) * hazard.motion.amplitude
        end
        state.targetZ = z < -5 and 0 or -10
        if hazard.motion and hazard.motion.axis == 'z' and state.hazardIndex==1 then
            -- Predict the whole contact interval with actual Ice acceleration
            -- and the held input. The old single arrival estimate could select
            -- a Snowball reaction immediately before the next gap jump.
            local best=-math.huge
            for _,lane in ipairs({0,-10}) do
                local score=iceLaneClearance(course,modes,actor,hazard,lane,state.cadence)
                if score>best then best=score;state.targetZ=lane end
            end
            -- From rest, wait on the authored entry floor for a clear
            -- approach. Once gliding, a reaction can deny the gap Jump while
            -- the retained momentum carries the body off the takeoff edge.
            state.iceWaiting=position.x<hazard.x-25 and math.abs(velocity.x)<3 and best<.75
            if state.iceWaiting then forward=0 end
        else
            state.iceWaiting=false
        end
        state.plannedHazard = state.hazardIndex
    end
    local jump = false
    if actor.grounded and actor.support then
        local floorIndex = tonumber(string.match(actor.support, '^floor%-(%d+)$'))
        if floorIndex and floorIndex < #course.platforms then
            local floor = course.platforms[floorIndex]
            jump = floor.x + floor.w / 2 - position.x < 4.7
        end
    end
    return input(forward, clamp((state.targetZ - position.z) * .6 - velocity.z * .5, -1, 1), jump)
end

local function hazardPosition(hazard,at)
    local x,y,z = hazard.x,hazard.y,hazard.z
    local motion = hazard.motion
    if motion and motion.axis then
        local delta = math.sin(at/(motion.period or 3)*math.pi*2+(motion.phase or 0))*(motion.amplitude or 0)
        if motion.axis=='x' then x+=delta elseif motion.axis=='y' then y+=delta elseif motion.axis=='z' then z+=delta end
    end
    return x,y,z
end

local function forecastRide(definition,modes,actor,target,jump,threats)
    local course,step = definition.course,1/30
    local x,y,z,vy,grounded = actor.position.x,actor.position.y,actor.position.z,actor.velocity.y,actor.grounded
    local staticDanger,liveDanger = false,false
    for frame=1,45 do
        local from,to = (frame-1)*step,frame*step
        if grounded then
            local shouldJump = frame==1 and jump
            for _,hazard in ipairs(course.hazards) do
                local dx = hazard.x-x
                if (hazard.kind=='LowBarrier' or hazard.kind=='Log') and dx>3 and dx<=12 then shouldJump=true end
            end
            if shouldJump then vy=course.jumpSpeed;grounded=false end
        end
        local oldX,oldY,oldZ = x,y,z
        x += futureSpeed(course,modes,to)*step
        local steer = math.abs(target-z)>.2 and sign(target-z) or 0
        z = clamp(z+steer*course.steerSpeed*step,-course.laneLimit,course.laneLimit)
        for _,ramp in ipairs(course.ramps or {}) do
            if grounded and oldX<ramp.x and x>=ramp.x and math.abs(z-ramp.z)<=ramp.d/2 then vy=ramp.launchSpeed;grounded=false end
        end
        vy-=100*step;y+=vy*step
        if y<=3 then y=3;vy=0;grounded=true else grounded=false end
        if definition.mode=='Surf' then z=clamp(z+math.sin((modes.elapsed+to)*.9)*2*step,-course.laneLimit,course.laneLimit) end
        for _,hazard in ipairs(course.hazards) do
            if math.abs(hazard.x-x)<8 then
                local hx0,hy0,hz0 = hazardPosition(hazard,modes.elapsed+from)
                local hx1,hy1,hz1 = hazardPosition(hazard,modes.elapsed+to)
                local active = hazard.kind~='ElectricGate' or math.sin((modes.elapsed+to)*2)>.1
                if active and relativeBox(oldX-hx0,oldY-hy0,oldZ-hz0,
                    x-hx1-oldX+hx0,y-hy1-oldY+hy0,z-hz1-oldZ+hz0,
                    hazard.w/2+1.6,hazard.h/2+2.5,hazard.d/2+1.2) then staticDanger=true end
            end
        end
        for _,shot in ipairs(threats) do
            if liveHit(oldX,oldY,oldZ,x,y,z,shot,from,to) then liveDanger=true end
        end
    end
    return staticDanger,liveDanger
end

local function laneAllowed(group,lane)
    for _,hazard in ipairs(group and group.hazards or {}) do
        if math.abs(lane-hazard.z)<=hazard.d/2+1.3 then return false end
    end
    return true
end

local function avoidLiveRide(definition,modes,actor,target,jump,group,threats)
    if #threats==0 then return target,jump end
    local _,danger = forecastRide(definition,modes,actor,target,jump,threats)
    if not danger then return target,jump end
    local candidates = actor.position.x>definition.course.finishPoint.x-30 and {target,-7,7} or {target,-14,0,14}
    local bestTarget,bestJump,bestScore = target,jump,math.huge
    for _,lane in ipairs(candidates) do
        if laneAllowed(group,lane) then
            for _,extraJump in ipairs({false,true}) do
                if not extraJump or actor.grounded then
                    local action = jump or extraJump
                    local authored,live = forecastRide(definition,modes,actor,lane,action,threats)
                    -- Never trade a safe authored route for a known wall crash.
                    if not authored then
                        local score = (live and 100000 or 0)+math.abs(lane-target)*.02
                            +math.abs(lane-actor.position.z)*.005+(extraJump and .5 or 0)
                        if score<bestScore then bestTarget,bestJump,bestScore=lane,action,score end
                    end
                end
            end
        end
    end
    return bestTarget,bestJump
end

local function serpentPosition(support,elapsed)
    local path,speed = support.definition.path,support.definition.speed
    local lengths,total = {},0
    for index=1,#path do
        local a,b=path[index],path[index%#path+1]
        local length=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2+(b.z-a.z)^2)
        lengths[index]=length;total+=length
    end
    local travel=((elapsed+(support.phase or 0))*speed)%total
    for index,length in ipairs(lengths) do
        if travel<=length then
            local a,b=path[index],path[index%#path+1];local f=length==0 and 0 or travel/length
            return {x=a.x+(b.x-a.x)*f,y=a.y+(b.y-a.y)*f,z=a.z+(b.z-a.z)*f}
        end
        travel-=length
    end
    return path[1]
end

-- Predict only the ordinary jump's landing on one read-only support. Checking
-- its future pose avoids choosing an outbound head or far tail merely because
-- its current X is near the entry ledge. Airborne controls stay straight ahead.
local function serpentLanding(actor,course,positionAt,w,h,d)
    local x,y,z,vy=actor.position.x,actor.position.y,actor.position.z,course.jumpSpeed
    for frame=1,54 do
        local before=y;local at=frame*FIXED
        x+=course.maxSpeed*FIXED;vy-=course.gravity*FIXED;y+=vy*FIXED
        local p=positionAt(at);local top=p.y+h/2+3
        if vy<=0 and before>=top-.4 and y<=top+.12
            and math.abs(x-p.x)<=w/2-.7 and math.abs(z-p.z)<=d/2-.5 then return true end
    end
    return false
end

local function serpents(definition, modes, actor, state)
    -- The checkpoint room is shared. A teammate may open the next vault while
    -- this body is still riding the previous serpent; steer its physical room.
    local room=1
    for index=1,#definition.course.rooms-1 do
        if actor.position.x>=definition.course.rooms[index].exit.minX then room=index+1 else break end
    end
    if room ~= state.room then state.serpentStage, state.room = 'Approach', room end
    local base, position = (room - 1) * 80, actor.position
    local spike = definition.course.hazards[room]
    if not spike then return input() end
    local safeZ = spike.z == 0 and 4.6 or 0
    local dz = safeZ - position.z
    -- Bounded proportional input converges even when packets arrive 0.1-0.2s
    -- apart; full-axis bang-bang steering overshoots the old narrow deadband.
    local x,z,jump=0,math.abs(dz)>.10 and clamp(dz*.3,-1,1) or 0,false
    if state.serpentStage == 'Approach' then
        if math.abs(dz)>.18 then x=0
        else
            local dx=base+9.1-position.x
            -- A request can return one movement packet later. Ease in before
            -- the ledge's .9-stud target inset, including a full-speed arrival
            -- from the preceding room; the old gain still drove off its edge.
            x=math.abs(dx)>.10 and clamp(dx*.1,-1,1) or 0
            if math.abs(dx)<=.15 then x=0;state.serpentStage='Wait' end
        end
    elseif state.serpentStage == 'Wait' then
        if actor.grounded and math.abs(dz)<=.18 then
            for _,support in ipairs(modes.supports) do
                local data=support.definition
                if data.room==room and serpentLanding(actor,definition.course,function(at)
                    return serpentPosition(support,modes.elapsed+at)
                end,data.w,data.h,data.d) then
                    x,z,jump,state.serpentStage=1,0,true,'Board';break
                end
            end
        end
    elseif state.serpentStage == 'Board' then
        x,z=1,0
        if actor.grounded and actor.support and string.sub(actor.support, 1, 8) == 'serpent-' then state.serpentStage = 'Ride' end
    elseif state.serpentStage == 'Ride' then
        x = 1
        local carryZ=0
        for _,support in ipairs(modes.supports) do if support.id==actor.support then
            carryZ=(serpentPosition(support,modes.elapsed+FIXED).z-support.position.z)/FIXED;break
        end end
        z=clamp(dz*.3-carryZ/definition.course.maxSpeed,-.35,.35)
        if actor.support == 'serpent-' .. room then
            for _, head in ipairs(modes.supports) do
                if head.id == actor.support and head.position.x < base + 48 and position.x > head.position.x + 3 then x = 0 end
            end
        end
        local exitFloor=definition.course.platforms[room*2]
        if position.x>=base+52.5 and actor.grounded and exitFloor
            and serpentLanding(actor,definition.course,function() return exitFloor end,exitFloor.w,exitFloor.h,exitFloor.d) then
            x,z,jump,state.serpentStage=1,0,true,'Exit'
        end
    elseif state.serpentStage == 'Exit' then x,z=1,0 end
    return input(x, z, jump)
end

local lastModes, lastToken, states = nil, nil, {}
local function plan(context)
    local definition, modes = context.definition, context.modes
    if not definition or not definition.course or not modes then return input() end
    if modes ~= lastModes or context.stageToken ~= lastToken then
        states, lastModes, lastToken = {}, modes, context.stageToken
    end
    local slot = context.slot or 1
    local actor = context.actor or modes.actors[slot]
    if not actor or actor.finished then return input() end
    local state = states[slot]
    local vehicleSerial = modes.vehicleGroup and modes.vehicleGroup.serial
    if not state or state.attempt ~= actor.attempt or state.vehicleSerial ~= vehicleSerial then
        state = {attempt = actor.attempt, hazardIndex = 1, plannedHazard = 0, targetZ = 0,
            groupIndex = 1, serpentStage = 'Approach', room = modes.room, nextJetPlan = -math.huge,vehicleSerial=vehicleSerial}
        states[slot] = state
    end
    local now=context.now or modes.now or modes.elapsed
    if state.lastPlanAt and now>state.lastPlanAt then
        state.cadence=math.max(state.cadence or FIXED,clamp(now-state.lastPlanAt,FIXED,.3))
    end
    state.lastPlanAt=now
    local course, position = definition.course, actor.position
    if course.mount and not actor.mounted then
        if context.mustFight then
            local result = input()
            result.yieldCombat = true
            return result
        end
        local native = context.position or (context.world and context.world:position(slot)) or position
        local dx, dy, dz = course.mount.x - native.x, course.mount.y - native.y, course.mount.z - native.z
        local near = math.sqrt(dx * dx + dy * dy + dz * dz) <= course.mountRange * .9
        return input(clamp(dx * .5, -1, 1), clamp(dz * .5, -1, 1), false, near)
    end
    if course.mount and modes.vehicleGroup and modes.vehicleGroup.phase~='Riding' then
        state.nextJetPlan=-math.huge
        return input()
    end
    if definition.mode == 'Rope' then
        return input(position.x < 15 and 1 or 0, position.z < 15 and 1 or 0)
    elseif definition.mode == 'Ice' then return ice(definition, modes, actor, state)
    elseif definition.mode == 'Serpents' then return serpents(definition, modes, actor, state)
    elseif definition.mode == 'Jet' then
        local threats,signature = liveThreats(context)
        if now >= state.nextJetPlan or state.threatSignature~=signature then
            local hold=math.max(.1,math.min(.25,(state.cadence or .1)+FIXED))
            state.jetInput=jetInput(definition,modes,actor,threats,hold)
            state.nextJetPlan=now+((state.cadence or FIXED)>=.04 and 0 or .1)-1e-7
            state.threatSignature=signature
        end
        return input(0, state.jetInput)
    elseif definition.mode == 'Speeder' or definition.mode == 'Surf' then
        if not state.groups then state.groups = laneGroups(course) end
        local nearest
        for _, hazard in ipairs(course.hazards) do
            local dx = hazard.x - position.x
            if dx >= -4 and dx <= 65 then nearest = nearest or hazard end
        end
        state.groupIndex=1
        while state.groups[state.groupIndex] and position.x > state.groups[state.groupIndex].lastX + 4 do state.groupIndex += 1 end
        local target = state.groups[state.groupIndex] and state.groups[state.groupIndex].lane or 0
        local jumpLead=math.min(21,12+futureSpeed(course,modes,0)*math.max(0,(state.cadence or FIXED)-.1))
        -- A rewound Surf cohort can reach the next low Whirlpool before a
        -- rider on the opposite offset can clear its lane. It has the same
        -- authored vertical bounds as a Log, so use the ordinary jump there.
        local jump = nearest and (nearest.kind == 'LowBarrier' or nearest.kind == 'Log'
            or definition.mode=='Surf' and nearest.kind=='Whirlpool')
            and nearest.x - position.x <= jumpLead and nearest.x - position.x > 3 and actor.grounded
        if position.x > course.finishPoint.x - 30 then target=0 end
        local ordinaryTarget=target
        target,jump=avoidLiveRide(definition,modes,actor,target,jump,state.groups[state.groupIndex],liveThreats(context))
        local steer = math.abs(target - position.z) > .2 and sign(target - position.z) or 0
        if position.x > course.finishPoint.x - 30 and target==ordinaryTarget then steer = clamp(-position.z * .8, -1, 1) end
        return input(0, steer, jump)
    end
    return input()
end

return {plan = plan}
