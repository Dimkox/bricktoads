-- Test-only observer/input policy. Local run-up memory sequences normal inputs;
-- this module never sends an intent or mutates
-- a Session, Director, actor, mode, projectile, course, resource, or clock.
--
-- plan({controller?, session?, director?, world?, modes?, definition?, now,
--       slot, dt?}) -> {x, z, jump, primary, run, aimX?, aimZ?, evasion?, hold?}
-- evasion/hold are QA composition hints; the bridge removes them before input.
-- primary means the existing public Punch input. Running may make Session
-- select its ordinary run strike. The harness must send all inputs through
-- the authorized hero intent path, including identity/sequence validation.
-- aimX/aimZ describe a normal facing direction, never a target or hit packet.
-- target(ctx) -> enemyId/flyId, position is a read-only composition query. A nil
-- target leaves route steering to the separate QA traversal pilot. In
-- particular, this policy does not replace platform/gap navigation.
local Pilot = {}
local runUps = setmetatable({}, {__mode='k'})

local function clearRunUp(c)
    local slots = runUps[c.session]
    if slots then slots[c.slot] = nil end
end

local function finite(n)
    return type(n) == 'number' and n == n and math.abs(n) < math.huge
end
local function point(p)
    return type(p) == 'table' and finite(p.x) and finite(p.y) and finite(p.z)
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function flatDistance(a, b) return math.sqrt((a.x-b.x)^2 + (a.z-b.z)^2) end
local function distance(a, b) return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2) end
local function unit(x, z)
    local length = math.sqrt(x*x + z*z)
    if length < .001 then return 1, 0 end
    return x/length, z/length
end
local function neutral() return {x=0, z=0, jump=false, primary=false, run=false} end
local function context(ctx)
    local controller = ctx.controller or {}
    local session = ctx.session or controller.current
    local director = ctx.director or controller.director
    local world = ctx.world or controller.world or (session and session.world)
    if not session or not director or not world or type(world.position) ~= 'function' then return nil end
    local slot = ctx.slot
    local hero = session.state and session.state.heroes and session.state.heroes[slot]
    local combat = session.combat and session.combat[slot]
    local now = finite(ctx.now) and ctx.now or session.now or 0
    if not hero or hero.status ~= 'Alive' or hero.connected ~= true or not combat
        or combat.deathAt or session.state.status ~= 'Active' or director.closed or director.result then return nil end
    local p = world:position(slot)
    if not point(p) then return nil end
    local modes = ctx.modes or director.modes
    local modeActor = modes and modes.actors and modes.actors[slot]
    local config = session.config or director.config or {}
    return {session=session, director=director, ordinary=director.ordinary or director,
        world=world, modes=modes, modeActor=modeActor, config=config,
        definition=ctx.definition or director.definition or director.route or config.Level or {},
        hero=hero, combat=combat, slot=slot, now=now, position=p,
        dt=finite(ctx.dt) and clamp(ctx.dt, .005, .25) or 1/30}
end
local function special(c)
    local s = c.modeActor
    if not s or s.finished or c.modes.mode == 'Finale' then return false end
    local mode = c.modes.mode
    if mode == 'Speeder' or mode == 'Surf' or mode == 'Jet' then return s.mounted == true end
    return true
end
local function carried(c)
    local carry = c.director.carry or c.ordinary.carry
    local id = carry and carry.holders and carry.holders[c.slot]
    return id and carry.states and carry.states[id]
end
local function healingTarget(c)
    local flies = c.director.flies or c.ordinary.flies
    if not flies or flies.closed or (c.combat.rawLife or 47) > 39 then return nil end
    for id, enemy in pairs(c.director.enemies or c.ordinary.enemies or {}) do
        local q = not enemy.dead and c.world:position(id)
        if point(q) and distance(c.position,q) < 10 then return nil end
    end
    local cfg = flies.config or c.config.HealingFlies or {}
    local selectedRow, selectedPoint, best
    for _, row in ipairs(flies.rows or {}) do
        if row.active and not row.consumed then
            local q = {x=row.x,y=row.y+math.sin((flies.now or c.now)*(cfg.bobSpeed or 2)+row.zone)
                *(cfg.bobHeight or .25),z=row.z}
            local range = distance(c.position,q)
            if range < 70 and (not best or range < best) then selectedRow,selectedPoint,best = row,q,range end
        end
    end
    return selectedRow,selectedPoint
end
local function selected(c)
    local d, p = c.director, c.position
    local boss = d.boss
    if boss and not boss.defeated and boss.state ~= 'Chase' and boss.state ~= 'Closed' then
        local q = c.world:position(-99)
        if point(q) then return -99, q, (d.enemies or {})[-99], boss end
    end
    if d.stage == 'Boss' and d.guardian then
        local q = c.world:position(-99)
        if point(q) then return -99, q, (d.enemies or {})[-99], d.guardian end
    end
    local held = carried(c)
    if held and held.mode == 'Carried' then
        local q = c.world:position(held.id)
        if point(q) then return held.id, q, (d.enemies or {})[held.id] end
    end
    local fly, flyPosition = healingTarget(c)
    if fly then return fly.id,flyPosition,{healingFly=true} end
    local best, bestPosition, bestEnemy, score
    local mode = c.modes and c.modes.mode
    for id, enemy in pairs(d.enemies or c.ordinary.enemies or {}) do
        local dragon = c.ordinary.dragons and c.ordinary.dragons.states and c.ordinary.dragons.states[id]
        if not enemy.dead and not enemy.boss and not (dragon and dragon.mode == 'Mounted') then
            local q = c.world:position(id)
            if point(q) then
                local dy, range = q.y-p.y, flatDistance(p, q)
                local reachable = true
                if special(c) then
                    if mode == 'Rope' then
                        -- Begin swinging before the rope reaches a fixed wall
                        -- actor; it continues descending while ordinary AI runs.
                        reachable = dy >= -24 and dy <= 5 and range <= 48
                    elseif c.modeActor.mounted then
                        -- Vehicle RocketRats are scripted flyovers. The route
                        -- pilot dodges their accepted drops while AI continues.
                        reachable = enemy.kind ~= 'RocketRat' and range < 9 and math.abs(dy) < 5
                    elseif c.modeActor.medium == 'Water' then
                        reachable = range < 38 and math.abs(dy) < 22
                    elseif mode == 'Ascent' or mode == 'Tower' or mode == 'Race' then
                        reachable = math.abs(dy) <= 7 and range < 28
                    end
                end
                local value = range + math.abs(dy)*1.7
                if reachable and (not score or value < score or value == score and id > best) then
                    best, bestPosition, bestEnemy, score = id, q, enemy, value
                end
            end
        end
    end
    return best, bestPosition, bestEnemy
end

function Pilot.target(ctx)
    local c = context(ctx)
    if not c then return nil end
    local id, q = selected(c)
    -- Do not expose a mutable world position owned by a fake world or adapter.
    return id, q and {x=q.x, y=q.y, z=q.z} or nil
end

local function safeDestination(c, q)
    local d, p = c.definition, c.position
    local boss = c.director.boss
    local bounds = boss and boss.arena
    if bounds and finite(bounds.minX) and finite(bounds.maxX) and finite(bounds.minZ) and finite(bounds.maxZ) then
        return {x=clamp(q.x, bounds.minX+1, bounds.maxX-1), y=q.y,
            z=clamp(q.z, bounds.minZ+1, bounds.maxZ-1)}
    end
    if c.director.stage == 'Boss' and d.boss and d.boss.platform then
        local f = d.boss.platform
        return {x=clamp(q.x, f.x-f.w/2+4, f.x+f.w/2-4), y=q.y,
            z=clamp(q.z, f.z-f.d/2+4, f.z+f.d/2-4)}
    end
    if d.mode == 'Causeway' or not c.modes then
        -- Combat retreats stay on their current authored floor. Actual gap
        -- crossings remain the route driver's native jump responsibility.
        for _, zone in ipairs(d.zones or {}) do
            for _, f in ipairs(zone.platforms or {}) do
                if p.x >= f.x-f.w/2-.2 and p.x <= f.x+f.w/2+.2
                    and p.z >= f.z-f.d/2-.2 and p.z <= f.z+f.d/2+.2
                    and math.abs(p.y-(f.y+f.h/2+3)) < 5 then
                    return {x=clamp(q.x, f.x-f.w/2+2.2, f.x+f.w/2-2.2), y=q.y,
                        z=clamp(q.z, f.z-f.d/2+2, f.z+f.d/2-2)}
                end
            end
        end
    end
    return {x=q.x, y=q.y, z=q.z}
end
local function steering(c, q, intent)
    q = safeDestination(c, q)
    local p, s = c.position, c.modeActor
    local dx, dz = q.x-p.x, q.z-p.z
    if special(c) and s.medium == 'Water' then
        -- Swim Z is the ordinary up/down input, not world depth.
        local v = s.velocity or {}
        dx = dx - (v.x or 0)*.24
        dz = p.y-q.y + (v.y or 0)*.24 + .4
        local n = math.max(1, math.sqrt(dx*dx+dz*dz))
        intent.x, intent.z = dx/n, dz/n
    elseif special(c) and c.modes.mode == 'Tower' then
        local theta = math.atan2(p.z, p.x)
        local x = -math.sin(theta)*dx + math.cos(theta)*dz
        local z = math.cos(theta)*dx + math.sin(theta)*dz
        local n = math.max(1, math.sqrt(x*x+z*z))
        intent.x, intent.z = x/n, z/n
    elseif special(c) and c.modes.mode == 'Rope' then
        local v = s.velocity or {}
        local n = math.max(1, math.sqrt(dx*dx+dz*dz))
        intent.x = clamp(dx/n-(v.x or 0)*.10, -1, 1)
        intent.z = clamp(dz/n-(v.z or 0)*.10, -1, 1)
    else
        local n = math.max(1, math.sqrt(dx*dx+dz*dz))
        intent.x, intent.z = dx/n, dz/n
    end
    local magnitude = math.sqrt(intent.x^2+intent.z^2)
    if magnitude > 1 then intent.x, intent.z = intent.x/magnitude, intent.z/magnitude end
    return intent
end
local function away(c, center, radius)
    local p = c.position
    local x, z = unit(p.x-center.x, p.z-center.z)
    return {x=center.x+x*radius, y=p.y, z=center.z+z*radius}
end
local function retreatCandidates(c, q, radius)
    local candidates={away(c,q,radius)}
    for _, axis in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        candidates[#candidates+1]={x=q.x+axis[1]*radius,y=c.position.y,z=q.z+axis[2]*radius}
    end
    local ax,az=unit(c.position.x-q.x,c.position.z-q.z)
    for step=1,5 do
        local angle=step*math.pi/12
        for _,sign in ipairs({-1,1}) do
            local cosine,sine=math.cos(angle),math.sin(angle)*sign
            candidates[#candidates+1]={x=q.x+(ax*cosine-az*sine)*radius,y=c.position.y,
                z=q.z+(ax*sine+az*cosine)*radius}
        end
    end
    return candidates
end
local function sideways(c, origin, aim, amount)
    local p = c.position
    local ax, az = unit(aim.x or 1, aim.z or 0)
    local side = (p.x-origin.x)*-az + (p.z-origin.z)*ax
    local sign = side < 0 and -1 or 1
    local a = safeDestination(c, {x=p.x-az*sign*amount, y=p.y, z=p.z+ax*sign*amount})
    if flatDistance(a, p) < amount*.35 then
        a = safeDestination(c, {x=p.x+az*sign*amount, y=p.y, z=p.z-ax*sign*amount})
    end
    return a
end
local function attackThreat(c, source, a, state)
    if not a or not a.move or state ~= 'Tell' and state ~= 'Active' then return nil end
    local p, m = c.position, a.move
    local origin = a.origin or source
    local destination = a.destination or source
    local aim = a.aim or {x=1,z=0}
    if not point(origin) or math.abs(p.y-origin.y) > 9 then return nil end
    if m.projectile or m.shots then
        local ax, az = unit(aim.x, aim.z)
        local front = (p.x-origin.x)*ax + (p.z-origin.z)*az
        local side = math.abs((p.x-origin.x)*-az + (p.z-origin.z)*ax)
        if front > -2 and side < 4 then return sideways(c, origin, aim, 7) end
    elseif m.reach then
        local ax, az = unit(aim.x, aim.z)
        local front = (p.x-origin.x)*ax + (p.z-origin.z)*az
        local side = math.abs((p.x-origin.x)*-az + (p.z-origin.z)*ax)
        if front > -1 and front < m.reach+2 and side < (m.width or 3)+2 then
            return sideways(c, origin, aim, (m.width or 3)+4)
        end
    elseif m.lift ~= nil then
        local r = m.radius or 3
        if point(destination) and flatDistance(p, destination) < r+2.5 then return away(c, destination, r+3.5) end
    elseif m.radial then
        if flatDistance(p, origin) < m.radial+2 then return away(c, origin, m.radial+3) end
    elseif m.speed then
        local ax, az = unit(aim.x, aim.z)
        local front = (p.x-origin.x)*ax + (p.z-origin.z)*az
        local side = math.abs((p.x-origin.x)*-az + (p.z-origin.z)*ax)
        if front > -2 and front < m.speed*m.active+3 and side < (m.radius or 3)+2 then
            return sideways(c, origin, aim, (m.radius or 3)+4)
        end
    elseif m.orbit then
        local r = m.orbit+(m.radius or 3)+2
        if flatDistance(p, origin) < r then return away(c, origin, r+1) end
    end
    return nil
end
local function projectileThreat(c, collection)
    for _, shot in pairs(collection or {}) do
        if point(shot.position) and shot.mode ~= 'Ground' and shot.mode ~= 'Carried'
            and shot.mode ~= 'Thrown' and not shot.reflected and not (shot.hits and shot.hits[c.slot])
            and (not shot.expiresAt or shot.expiresAt > c.now) then
            local q, p, direction = shot.position, c.position, shot.direction
            if point(direction) and (shot.mode == 'Bullet' or shot.mode == 'Heavy') then
                direction = {x=direction.x-q.x,z=direction.z-q.z}
            end
            if type(direction) == 'table' and finite(direction.x) and finite(direction.z)
                and math.abs(p.y-q.y) < 4.5 then
                local ax, az = unit(direction.x, direction.z)
                local front = (p.x-q.x)*ax + (p.z-q.z)*az
                local side = math.abs((p.x-q.x)*-az + (p.z-q.z)*ax)
                local speed = shot.speed or (shot.mode == 'Bullet' and 12 or 42)
                if front > -2.5 and front < speed*.55+3 and side < 3.5 then
                    return sideways(c, q, {x=ax,z=az}, 7)
                end
            end
        end
    end
    return nil
end
local function ready(c)
    return not c.combat.attack and not c.combat.reactionEnd and c.now >= (c.combat.nextAttack or 0)
end
local function facing(c, q, threshold)
    local actor = c.world.actors and c.world.actors[c.slot]
    local look = actor and actor.root and actor.root.CFrame and actor.root.CFrame.LookVector
    -- Numeric/fake worlds have no native facing observation. Live Studio does.
    if not look or not finite(look.X) or not finite(look.Z) then return true end
    local length = math.sqrt(look.X^2+look.Z^2)
    if length < .001 or flatDistance(c.position,q) < .1 then return true end
    local dx,dz = unit(q.x-c.position.x,q.z-c.position.z)
    return (look.X*dx+look.Z*dz)/length >= threshold
end
local function nativeRun(c, q)
    if special(c) or not c.config.Movement then return false end
    local actor = c.world.actors and c.world.actors[c.slot]
    local row = actor and actor.locomotion
    local root, humanoid = actor and actor.root, actor and actor.humanoid
    if not row or row.runRequested ~= true or row.airSpeed or not finite(row.at)
        or c.now < row.at or c.now-row.at >= (c.config.MoveTimeout or .35)
        or not root or not root.Parent or root.Anchored or not humanoid
        or humanoid.PlatformStand or (humanoid.Health or 0) <= 0 then return false end
    local material = humanoid.FloorMaterial
    if material == nil or material == 'Air' or tostring(material) == 'Enum.Material.Air' then return false end
    local velocity = root.AssemblyLinearVelocity
    if not velocity or not finite(velocity.X) or not finite(velocity.Y) or not finite(velocity.Z)
        or velocity.Y > 1 then return false end
    local mode = actor.model and type(actor.model.GetAttribute) == 'function'
        and actor.model:GetAttribute('MovementMode') or nil
    if row.groundRun ~= true and mode ~= 'Run' then return false end
    local dx,dz = unit(q.x-c.position.x,q.z-c.position.z)
    local movement = c.config.Movement
    return velocity.X*dx+velocity.Z*dz >= (movement.heroRunSpeed or 24)*(movement.runThresholdRatio or .75)
end
local function runUp(c, id, q, enemy, intent)
    local slots = runUps[c.session]
    local state = slots and slots[c.slot]
    local identity = table.concat({tostring(c.session.state.runId),tostring(c.session.state.levelEpoch),
        tostring(c.hero.actorId),tostring(c.hero.attempt),tostring(id),tostring(enemy and enemy.actorId)},':')
    if state and (state.identity ~= identity or c.now < state.started) then clearRunUp(c);state=nil end
    -- Ordinary Dragons hover above the same support. Their reachable Dash
    -- height does not make the grounded hero's run-up an airborne action.
    local runHeight=enemy and enemy.kind=='Dragon' and c.config.Attacks and c.config.Attacks.Dash
        and (c.config.Attacks.Dash.height or 4)-.15 or .8
    if special(c) or not c.config.Movement or not enemy or enemy.boss or (enemy.rawLife or 0) < 8
        or enemy.reactionUntil and enemy.reactionUntil > c.now
        or math.abs(c.position.y-q.y) > runHeight or not ready(c) then clearRunUp(c);return nil end
    local body = c.world.actors and c.world.actors[c.slot]
    local root, humanoid = body and body.root, body and body.humanoid
    if not root or not root.Parent or root.Anchored or not humanoid or humanoid.PlatformStand
        or (humanoid.Health or 0) <= 0 then clearRunUp(c);return nil end
    local material, velocity = humanoid.FloorMaterial, root.AssemblyLinearVelocity
    if material == nil or material == 'Air' or tostring(material) == 'Enum.Material.Air'
        or not velocity or not finite(velocity.Y) or math.abs(velocity.Y) > 1 then clearRunUp(c);return nil end
    local range = flatDistance(c.position,q)
    if not state and (range > 10 or nativeRun(c,q)) then return nil end
    -- Side boundaries can leave room along the floor even when straight back
    -- is unsafe. The chosen endpoint remains private and fixed for this phase.
    local candidates = state and {state.goal} or retreatCandidates(c,q,12)
    local goal
    for _, zone in ipairs(c.definition.zones or {}) do
        for _, floor in ipairs(zone.platforms or {}) do
            local minX,maxX = floor.x-floor.w/2+3,floor.x+floor.w/2-3
            local minZ,maxZ = floor.z-floor.d/2+3,floor.z+floor.d/2-3
            if c.position.x >= minX and c.position.x <= maxX and c.position.z >= minZ and c.position.z <= maxZ
                and q.x >= minX and q.x <= maxX and q.z >= minZ and q.z <= maxZ
                and math.abs(c.position.y-(floor.y+floor.h/2+3)) < 1 then
                for _, candidate in ipairs(candidates) do
                    local dot=(candidate.x-c.position.x)*(q.x-c.position.x)
                        +(candidate.z-c.position.z)*(q.z-c.position.z)
                    if candidate.x >= minX and candidate.x <= maxX and candidate.z >= minZ and candidate.z <= maxZ
                        and (state or dot <= 0) then goal=candidate;break end
                end
            end
            if goal then break end
        end
        if goal then break end
    end
    if not goal then clearRunUp(c);return nil end
    if not state then
        state={identity=identity,goal={x=goal.x,y=goal.y,z=goal.z},phase='Backoff',started=c.now}
        if not slots then slots={};runUps[c.session]=slots end
        slots[c.slot]=state
    end
    if state.phase == 'Backoff' and (range >= 11.5 or flatDistance(c.position,state.goal) < .8) then
        state.phase='Approach'
    end
    if state.phase == 'Backoff' then
        intent.evasion=true
        return steering(c,state.goal,intent)
    end
    -- Keep requesting ordinary Run through turning and acceleration. Only the
    -- existing observed-native-run guard above may actually issue the strike.
    steering(c,q,intent)
    intent.run=true
    return intent
end
local function stepOffEnemy(c, q, enemy, intent)
    local p=c.position
    if not enemy or enemy.boss or special(c) or p.y-q.y<=3.5 or flatDistance(p,q)>=3 then return nil end
    local body=c.world.actors and c.world.actors[c.slot]
    if not body or not body.root or not body.root.Parent or body.root.Anchored or not body.humanoid
        or body.humanoid.PlatformStand or (body.humanoid.Health or 0)<=0 then return nil end
    local material=body.humanoid.FloorMaterial
    if material==nil or material=='Air' or tostring(material)=='Enum.Material.Air' then return nil end
    local candidates=retreatCandidates(c,q,7)
    -- A near-exact stack has no stable away axis. Include both inward
    -- diagonals at an edge; the strict support/direction gates still decide.
    local diagonal=7/math.sqrt(2)
    for _,axis in ipairs({{1,1},{-1,1},{1,-1},{-1,-1}}) do
        candidates[#candidates+1]={x=q.x+axis[1]*diagonal,y=p.y,z=q.z+axis[2]*diagonal}
    end
    for _,zone in ipairs(c.definition.zones or {}) do
        for _,floor in ipairs(zone.platforms or {}) do
            local minX,maxX=floor.x-floor.w/2+3,floor.x+floor.w/2-3
            local minZ,maxZ=floor.z-floor.d/2+3,floor.z+floor.d/2-3
            local base=floor.y+floor.h/2+3
            -- Actors can stand near the authored edge, including on an NPC.
            -- Observe the whole support; retreat goals keep the inner margin.
            local observed=.001
            if p.x>=minX-3-observed and p.x<=maxX+3+observed and p.z>=minZ-3-observed and p.z<=maxZ+3+observed and p.y<=base+12
                and q.x>=minX-3-observed and q.x<=maxX+3+observed and q.z>=minZ-3-observed and q.z<=maxZ+3+observed and math.abs(q.y-base)<1.5 then
                for _,goal in ipairs(candidates) do
                    local dot=(goal.x-p.x)*(q.x-p.x)+(goal.z-p.z)*(q.z-p.z)
                    if goal.x>=minX and goal.x<=maxX and goal.z>=minZ and goal.z<=maxZ and dot<=0 then
                        clearRunUp(c)
                        intent.evasion=true
                        return steering(c,goal,intent)
                    end
                end
            end
        end
    end
    return nil
end
local function pigSpacing(c, q, enemy, intent)
    local cfg = c.config.EnemyCarry
    if not enemy or enemy.kind ~= 'Pig' or enemy.boss or not cfg or not finite(cfg.range)
        or enemy.reactionUntil and enemy.reactionUntil > c.now
        or special(c) or not ready(c) or math.abs(c.position.y-q.y) > .8 then return nil end
    local actor = c.world.actors and c.world.actors[c.slot]
    local root, humanoid = actor and actor.root, actor and actor.humanoid
    if not root or not root.Parent or root.Anchored or not humanoid or humanoid.PlatformStand
        or (humanoid.Health or 0) <= 0 then return nil end
    local material, velocity = humanoid.FloorMaterial, root.AssemblyLinearVelocity
    if material == nil or material == 'Air' or tostring(material) == 'Enum.Material.Air'
        or not velocity or not finite(velocity.Y) or math.abs(velocity.Y) > 1 then return nil end
    local range = flatDistance(c.position,q)
    if range > cfg.range+1.5 then return nil end
    local retreat = away(c,q,cfg.range+1.1)
    local supported = false
    for _, zone in ipairs(c.definition.zones or {}) do
        for _, floor in ipairs(zone.platforms or {}) do
            local minX,maxX = floor.x-floor.w/2+2.5,floor.x+floor.w/2-2.5
            local minZ,maxZ = floor.z-floor.d/2+2.5,floor.z+floor.d/2-2.5
            if c.position.x >= minX and c.position.x <= maxX and c.position.z >= minZ and c.position.z <= maxZ
                and retreat.x >= minX and retreat.x <= maxX and retreat.z >= minZ and retreat.z <= maxZ
                and math.abs(c.position.y-(floor.y+floor.h/2+3)) < 1 then supported = true;break end
        end
        if supported then break end
    end
    if not supported then return nil end
    if range <= cfg.range+.7 then intent.evasion=true;return steering(c,retreat,intent) end
    if not facing(c,q,.90) then
        -- Turn through ordinary native movement without closing the pickup
        -- margin before AutoRotate has actually faced the selected Pig.
        intent.x,intent.z = intent.aimX*.08,intent.aimZ*.08
        return intent
    end
    return nil
end
local slaughterEvasions = setmetatable({}, {__mode='k'})
local function slaughterEvasion(c, boss, q)
    if not boss or boss.kind ~= 'GeneralSlaughter' or special(c)
        or not finite(boss.attackSerial) then return nil end
    local body = c.world.actors and c.world.actors[c.slot]
    local root, humanoid = body and body.root, body and body.humanoid
    if not root or not root.Parent or root.Anchored or not humanoid
        or humanoid.PlatformStand or (humanoid.Health or 0) <= 0 then return nil end
    local material = humanoid.FloorMaterial
    if material == nil or material == 'Air' or tostring(material) == 'Enum.Material.Air' then return nil end
    local arena, p = boss.arena, c.position
    if not arena or not finite(arena.minX) or not finite(arena.maxX)
        or not finite(arena.minZ) or not finite(arena.maxZ)
        or arena.maxX-arena.minX <= 2 or arena.maxZ-arena.minZ <= 2 then return nil end
    local preempt = boss.state == 'Ready' and boss.attackSerial%2 == 1
        and finite(boss.readyAt) and boss.readyAt-c.now <= .35
    local attack = boss.attack
    if not preempt and (boss.state ~= 'Tell' and boss.state ~= 'Active'
        or not attack or not attack.move or not point(attack.origin)
        or not attack.aim or not finite(attack.aim.x) or not finite(attack.aim.z)) then return nil end
    -- Ready movement establishes accepted momentum before the short Headbutt
    -- tell. The source boss still chooses its own aim at the actual Tell.
    local ax, az, serial
    if preempt then ax,az = unit(p.x-q.x,p.z-q.z);serial = boss.attackSerial+1
    else ax,az = unit(attack.aim.x,attack.aim.z);serial = boss.attackSerial end
    local sx, sz = -az, ax
    local function clearance(x, z)
        local result = math.huge
        if x > 0 then result = math.min(result,(arena.maxX-1-p.x)/x)
        elseif x < 0 then result = math.min(result,(arena.minX+1-p.x)/x) end
        if z > 0 then result = math.min(result,(arena.maxZ-1-p.z)/z)
        elseif z < 0 then result = math.min(result,(arena.minZ+1-p.z)/z) end
        return math.max(0,result)
    end
    local slots = slaughterEvasions[c.session]
    if not slots then slots = {};slaughterEvasions[c.session] = slots end
    local identity = table.concat({tostring(c.session.state.runId),tostring(c.session.state.levelEpoch),
        tostring(c.hero.actorId),tostring(c.hero.attempt)},':')
    local state = slots[c.slot]
    if not state or state.identity ~= identity or state.boss ~= boss or state.serial ~= serial then
        local plus, minus = clearance(sx,sz), clearance(-sx,-sz)
        local sign = plus >= minus and 1 or -1
        local v = root.AssemblyLinearVelocity
        local momentum = v and finite(v.X) and finite(v.Z) and v.X*sx+v.Z*sz or 0
        if preempt and math.abs(momentum) > 1 and plus > 10 and minus > 10 then
            sign = momentum > 0 and 1 or -1
        end
        state = {identity=identity,boss=boss,serial=serial,x=sx*sign,z=sz*sign}
        slots[c.slot] = state
    else
        -- Keep the selected world-side through Tell and near the arena edge;
        -- recomputing an escape target each frame can reverse into the strike.
        if sx*state.x+sz*state.z < 0 then sx,sz = -sx,-sz end
        state.x,state.z = sx,sz
    end
    local safe = false
    if not preempt then
        local origin, m = attack.origin, attack.move
        local front = (p.x-origin.x)*ax+(p.z-origin.z)*az
        local side = math.abs((p.x-origin.x)*-az+(p.z-origin.z)*ax)
        local enemy = boss.enemies and boss.enemies[-99]
        local phaseSpeed = enemy and (enemy.progress or 0) >= 120 and 1.2 or 1
        local extent = m.reach or (m.speed or 0)*(m.active or 0)*phaseSpeed
        safe = side > (m.width or m.radius or 3)+3 or front < -3 or front > extent+5
    end
    local intent = neutral()
    intent.run,intent.evasion = true,true
    -- A bounded one-packet delay budget; this is QA input planning, not a
    -- modification to support, movement physics, attack state or resources.
    local speed = (c.config.Movement or {}).heroRunSpeed or 24
    if not safe and clearance(state.x,state.z) >= speed*(.133+c.dt+.025) then
        intent.x,intent.z = state.x,state.z
    end
    return intent
end
local function guardianPlan(c, q)
    local intent, d, p = neutral(), c.director, c.position
    intent.aimX, intent.aimZ = unit(q.x-p.x, q.z-p.z)
    local guardian = d.guardian
    local bullets={}
    for id,shot in pairs(d.projectiles or {}) do if shot.mode=='Bullet' then bullets[id]=shot end end
    local danger=projectileThreat(c,bullets)
    if danger then intent.evasion=true;return steering(c,danger,intent) end
    local id = guardian.carriers and guardian.carriers[c.slot]
    local ball = id and d.projectiles and d.projectiles[id]
    if ball and ball.mode == 'Carried' then
        if facing(c,q,.95) then intent.primary = ready(c)
        else intent.x,intent.z = intent.aimX*.08,intent.aimZ*.08 end
        return intent
    end
    local ground, range
    for _, candidate in pairs(d.projectiles or {}) do
        if candidate.mode == 'Ground' and point(candidate.position)
            and (not candidate.expiresAt or candidate.expiresAt > c.now) then
            local n = distance(p, candidate.position)
            if not range or n < range then ground, range = candidate.position, n end
        end
    end
    if ground then
        if range <= ((c.config.Boss or {}).pickupRange or 5.5) and math.abs(p.y-ground.y) <= 3.5 then
            intent.primary = ready(c)
        else steering(c, ground, intent) end
    else
        -- Stay within the Guardian's normal aggro range on supported arena
        -- ground. Its own nextBall/nextShot clocks remain entirely untouched.
        steering(c, {x=q.x-24,y=p.y,z=q.z+math.sin(c.now*1.3)*6}, intent)
    end
    return intent
end

function Pilot.plan(ctx)
    local c = context(ctx)
    local intent = neutral()
    if not c or c.combat.reactionEnd then return intent end
    -- Ordinary hit detection samples the actor's facing at the accepted
    -- windup deadline. A new dodge/target must not turn that attack away.
    if c.combat.attack then clearRunUp(c);intent.hold=true;return intent end
    local flies = c.director.flies or c.ordinary.flies
    local carry = c.director.carry or c.ordinary.carry
    if flies and flies.pendingBySlot and flies.pendingBySlot[c.slot]
        or carry and carry.pendingBySlot and carry.pendingBySlot[c.slot] then clearRunUp(c);intent.hold=true;return intent end
    local id, q, enemy, boss = selected(c)
    if not id then return intent end
    if c.director.guardian and id == -99 then clearRunUp(c);return guardianPlan(c, q) end
    local p, ordinary = c.position, c.ordinary
    intent.aimX, intent.aimZ = unit(q.x-p.x, q.z-p.z)
    if enemy and enemy.healingFly then
        clearRunUp(c)
        local cfg = c.config.HealingFlies or {}
        if ready(c) and distance(p,q) < (cfg.range or 6)-.3 and math.abs(p.y-q.y) <= (cfg.height or 3)
            and facing(c,q,math.max(cfg.facingDot or .25,.65)) then
            intent.primary = true
            intent.x,intent.z = intent.aimX*.08,intent.aimZ*.08
            return intent
        end
        return steering(c,q,intent)
    end
    local held = carried(c)
    if held and held.mode == 'Carried' then clearRunUp(c);intent.primary = ready(c); return intent end
    local dragon = ordinary.dragons and ordinary.dragons.heroes and ordinary.dragons.heroes[c.slot]
    if dragon then
        clearRunUp(c)
        -- Captured actors have no attack input. Mounted actors fire through
        -- their pre-existing primary action and never receive target IDs.
        intent.primary = dragon.mode == 'Mounted' and ready(c) and flatDistance(p,q) < 50
        return intent
    end
    local slaughter = slaughterEvasion(c,boss,q)
    if slaughter then clearRunUp(c);return slaughter end
    local stepOff=stepOffEnemy(c,q,enemy,intent)
    if stepOff then return stepOff end
    local range, height = flatDistance(p,q), math.abs(p.y-q.y)
    local vulnerable = not boss or boss.state == 'Ready' or boss.state == 'Recovery'
        or boss.state == 'Reaction' and boss.lightReaction == true
    local dash = c.config.Attacks and c.config.Attacks.Dash
    if dash and ready(c) and vulnerable and range <= (dash.reach or 8)-.35
        and height <= (dash.height or 4)-.15 and facing(c,q,.90) and nativeRun(c,q) then
        -- This is still the public Punch input. Preserve the real run in the
        -- preceding Move; Session alone selects its existing Dash/run strike.
        intent.x,intent.z = intent.aimX,intent.aimZ
        intent.run,intent.primary = true,true
        clearRunUp(c)
        return intent
    end
    local approach = not boss and runUp(c,id,q,enemy,intent) or nil
    if approach then return approach end
    local spacing = pigSpacing(c,q,enemy,intent)
    if spacing then return spacing end
    local punch = c.config.Attacks and c.config.Attacks.Punch or {windup=.1,reach=6,height=4}
    local ownWindup = punch.windup or .1
    local clubs = ordinary.clubs
    if clubs and clubs.equipment and clubs.equipment[c.slot] then
        ownWindup = ((c.config.Attacks or {}).Club or {}).windup or ownWindup
    elseif enemy and enemy.kind == 'Pig' and c.config.EnemyCarry
        and range <= c.config.EnemyCarry.range and height <= c.config.EnemyCarry.height then
        ownWindup = math.max(ownWindup,c.config.EnemyCarry.windup or 0)
    end
    if not boss and enemy and not enemy.boss and enemy.windup and finite(enemy.windup.at)
        and not special(c) and ready(c) and range <= (punch.reach or 6)-.35
        and height <= (punch.height or 4)-.15 and facing(c,q,.90)
        and ownWindup+.05 < enemy.windup.at-c.now then
        -- A faster ordinary primary can interrupt the advertised strike. The
        -- real Session/Director still decides contact, reaction and damage.
        intent.primary = true
        intent.x,intent.z = intent.aimX*.08,intent.aimZ*.08
        return intent
    end
    local families = c.director.campaignEnemies or ordinary.campaignEnemies
    local familyState = families and families.states and families.states[id]
    local threat = boss and attackThreat(c, q, boss.attack, boss.state)
        or familyState and attackThreat(c, q, familyState.attack, familyState.mode)
    if not threat and enemy and enemy.windup and math.abs(p.y-q.y) < 5 and flatDistance(p,q) < 10 then
        -- The first-route families use their usual read-only windup record.
        threat = away(c, q, (enemy.windup.tuning and enemy.windup.tuning.reach or 7)+3)
    end
    threat = threat or projectileThreat(c, boss and boss.projectiles)
        or projectileThreat(c, families and families.projectiles)
    if threat then intent.evasion=true;return steering(c, threat, intent) end
    local cfg = c.config.Attacks and c.config.Attacks.Punch or {reach=6,height=4}
    if special(c) and c.modes.mode == 'Rope' then cfg = c.config.Attacks and c.config.Attacks.RopeStrike or cfg end
    -- Fixed shaft blasters sit exactly six studs from the rope's +/-16 swing
    -- limit, so use the actual attack reach rather than an inward margin.
    local reach = (cfg.reach or 6)-(special(c) and c.modes.mode == 'Rope' and 0 or .35)
    if boss and not vulnerable then
        -- Remain close enough to punish the actual recovery, without issuing
        -- attacks during active or heavy-reaction immunity.
        local destination = away(c, q, 8.5)
        intent.evasion=true
        return steering(c, destination, intent)
    end
    if ready(c) and vulnerable and range <= reach and height <= (cfg.height or 4)-.15 and facing(c,q,.90) then
        intent.primary = true
        -- The move refresh faces the enemy on native controls. Tiny motion
        -- avoids walking through it during the accepted attack's windup.
        intent.x, intent.z = intent.aimX*.08, intent.aimZ*.08
        return intent
    end
    local pigStance=enemy and enemy.kind=='Pig' and not enemy.boss and not special(c) and height<=.8
    local destination=pigStance and away(c,q,5) or q
    if c.combat.attack then
        -- Keep the accepted attack facing its normal target until its window
        -- resolves; retreating before the windup would turn it into a miss.
        intent.hold=true;return intent
    end
    if pigStance and range>=4.85 and range<=5.15 then
        intent.hold=true
        if not facing(c,q,.90) then intent.x,intent.z=intent.aimX*.03,intent.aimZ*.03 end
        return intent
    end
    if pigStance and range<5 then intent.evasion=true end
    if not pigStance and not ready(c) and range < 4.5
        and not (enemy and enemy.reactionUntil and enemy.reactionUntil > c.now) then
        destination = away(c, q, 8)
        intent.evasion=true
    end
    steering(c, destination, intent)
    -- Preserve an already observed run through the small interval between the
    -- approach threshold and Dash reach. Close non-run primary remains usable.
    intent.run = not special(c) and (range > 9 or range > reach and nativeRun(c,q))
    local s = c.modeActor
    intent.jump = q.y-p.y > 3.8 and q.y-p.y < 9 and range < 7
        and (not s or s.grounded == true) and ready(c)
    return intent
end

return Pilot
