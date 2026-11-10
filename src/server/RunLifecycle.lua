-- Server-only lifecycle core. No Roblox instances, remotes, physics or damage coefficients.
-- Events represent decisions already authenticated by the server adapter.
local Core = {}
local MAX_HEALTH = 5
local INITIAL_RESPAWNS = 3
local NORMAL_SHIELD_SECONDS = 2
local EMERGENCY_SHIELD_SECONDS = 10
local TEMPLATES = { ["Mr. Green"] = true, ["Mr. Yellow"] = true, ["Mr. Brown"] = true }
local BASE_FIELDS = { id=true, runId=true, expectedRevision=true, kind=true, now=true }
local FIELDS = {
    SetInfiniteLives={userId=true,enabled=true},
    ReserveSpawn = {userId=true,connectionEpoch=true},
    CommitSpawn = {userId=true,token=true,actorId=true,safe=true},
    AbortSpawn = {userId=true,token=true},
    Death = {userId=true,actorId=true,attempt=true,levelEpoch=true},
    SetHealth = {userId=true,actorId=true,attempt=true,levelEpoch=true,health=true},
    BeginAttack = {userId=true,actorId=true,attempt=true,levelEpoch=true,connectionEpoch=true},
    Connection = {userId=true,connectionEpoch=true,connected=true},
    ExpireShield = {userId=true,actorId=true,attempt=true,levelEpoch=true},
    RelocateToSafety = {userId=true,actorId=true,attempt=true,levelEpoch=true,safe=true},
    AdvanceLevel = {userId=true,actorId=true,attempt=true,levelEpoch=true,levelId=true,destinationSafe=true,prerequisitesMet=true},
    ChooseView = {userId=true,view=true,connectionEpoch=true},
}

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function integer(value, minimum)
    return finite(value) and value >= minimum and value <= 9007199254740991 and value % 1 == 0
end
local function identifier(value)
    return type(value) == "string" and #value > 0 and #value <= 160
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

-- Length prefixes make strings containing separators unambiguous in replay fingerprints.
local function fingerprint(event)
    local keys = {}
    for key in pairs(event) do keys[#keys+1] = key end
    table.sort(keys)
    local pieces = {}
    for _, key in ipairs(keys) do
        local value = event[key]
        local encoded
        if type(value) == "string" then encoded = "s" .. #value .. ":" .. value
        elseif type(value) == "number" then encoded = "n" .. string.format("%.17g", value) .. ";"
        else encoded = value and "b1" or "b0" end
        pieces[#pieces+1] = #key .. ":" .. key .. encoded
    end
    return table.concat(pieces)
end

function Core.new(runId, groupId, roster, levelId)
    assert(identifier(runId) and identifier(groupId) and identifier(levelId), "Invalid run/group/level identifier")
    assert(type(roster) == "table" and #roster >= 1 and #roster <= 3, "Roster must contain 1–3 heroes")
    local count = 0
    for key in pairs(roster) do
        assert(integer(key, 1) and key <= #roster, "Roster must be a contiguous array")
        count = count + 1
    end
    assert(count == #roster, "Roster must be a contiguous array")
    local state = {
        runId=runId, groupId=groupId, levelId=levelId, levelEpoch=1,
        revision=0, time=0, status="Active", partyDissolved=false,
        heroes={}, receipts={}, seenActors={},
    }
    for _, member in ipairs(roster) do
        assert(type(member) == "table" and integer(member.userId, 1), "Invalid hero userId")
        assert(TEMPLATES[member.template] == true, "Unknown hero template")
        assert(state.heroes[member.userId] == nil, "Duplicate hero owner")
        state.heroes[member.userId] = {
            userId=member.userId, template=member.template, connected=true, connectionEpoch=1,
            status="AwaitingInitial", health=MAX_HEALTH, respawns=INITIAL_RESPAWNS, infiniteLives=false,
            attempt=0, retryReady=false, view="Playing",
        }
    end
    return state
end

local function validateEvent(event)
    if type(event) ~= "table" or not identifier(event.id) or not identifier(event.runId)
        or not identifier(event.kind) or not integer(event.expectedRevision, 0)
        or not finite(event.now) or event.now < 0 then return "INVALID_EVENT" end
    local allowed = FIELDS[event.kind]
    if not allowed then return "UNKNOWN_EVENT" end
    for key, value in pairs(event) do
        if type(key) ~= "string" or (not BASE_FIELDS[key] and not allowed[key]) then return "UNKNOWN_FIELD" end
        local kind = type(value)
        if kind ~= "string" and kind ~= "number" and kind ~= "boolean" then return "INVALID_EVENT" end
        if kind == "number" and not finite(value) then return "INVALID_EVENT" end
    end
    if not integer(event.userId, 1) then return "INVALID_EVENT" end
    if allowed.connectionEpoch and not integer(event.connectionEpoch, 1) then return "INVALID_EVENT" end
    if allowed.attempt and (not integer(event.attempt, 1) or not integer(event.levelEpoch, 1)
        or not identifier(event.actorId)) then return "INVALID_EVENT" end
    if allowed.token and not identifier(event.token) then return "INVALID_EVENT" end
    if allowed.safe and type(event.safe) ~= "boolean" then return "INVALID_EVENT" end
    if event.kind == "CommitSpawn" and not identifier(event.actorId) then return "INVALID_EVENT" end
    if event.kind == "Connection" and type(event.connected) ~= "boolean" then return "INVALID_EVENT" end
    if event.kind == "SetInfiniteLives" and type(event.enabled) ~= "boolean" then return "INVALID_EVENT" end
    if event.kind == "AdvanceLevel" and (not identifier(event.levelId)
        or type(event.destinationSafe) ~= "boolean" or type(event.prerequisitesMet) ~= "boolean") then return "INVALID_EVENT" end
    return nil
end

local function checkConnection(hero, event, requireOnline)
    if event.connectionEpoch ~= hero.connectionEpoch then return "STALE_CONNECTION" end
    if requireOnline and not hero.connected then return "OFFLINE" end
    return nil
end
local function checkActor(state, hero, event)
    if event.levelEpoch ~= state.levelEpoch then return "STALE_LEVEL" end
    if hero.status ~= "Alive" then return "NOT_ALIVE" end
    if event.actorId ~= hero.actorId or event.attempt ~= hero.attempt then return "STALE_ACTOR" end
    return nil
end
local function checkReservation(state, hero, event)
    local pending = hero.pending
    if not pending or pending.token ~= event.token or pending.levelEpoch ~= state.levelEpoch
        or pending.connectionEpoch ~= hero.connectionEpoch or pending.sourceAttempt ~= hero.attempt then
        return "STALE_RESERVATION"
    end
    if not hero.connected then return "OFFLINE" end
    return nil
end
local function clearEmergency(hero)
    hero.shield = nil
    hero.retryReady = false
    if hero.pending and hero.pending.kind == "Emergency" then hero.pending = nil end
end
local function closeIfDefeated(state)
    for _, hero in pairs(state.heroes) do
        if hero.status ~= "Eliminated" then return end
    end
    state.status = "Lost"
    state.partyDissolved = true
    for _, hero in pairs(state.heroes) do hero.view = "Menu" end
end
local function hasRespawn(hero)
    return hero.infiniteLives == true or hero.respawns > 0
end

-- Mutations are applied only to a private candidate snapshot and discarded on rejection.
local function execute(state, event)
    local hero = state.heroes[event.userId]
    if not hero then return "UNKNOWN_HERO" end
    local kind = event.kind
    if kind == "SetInfiniteLives" then
        if hero.status == "Eliminated" then return "ELIMINATED" end
        if hero.infiniteLives == event.enabled then return "NO_CHANGE" end
        hero.infiniteLives = event.enabled
        if not hasRespawn(hero) then
            hero.retryReady = false
            hero.pending = nil
            if hero.status == "AwaitingRespawn" then
                hero.status = "Eliminated"
                hero.view = "Choice"
                closeIfDefeated(state)
            end
        end
    elseif kind == "ReserveSpawn" then
        local problem = checkConnection(hero, event, true)
        if problem then return problem end
        if hero.pending then return "SPAWN_PENDING" end
        local spawnKind
        if hero.status == "AwaitingInitial" then spawnKind = "Initial"
        elseif hero.status == "AwaitingRespawn" and hasRespawn(hero) then spawnKind = "Respawn"
        elseif hero.status == "Alive" and hero.retryReady and hasRespawn(hero) then spawnKind = "Emergency"
        else return "SPAWN_NOT_ALLOWED" end
        hero.pending = {
            token = tostring(state.revision+1) .. ":" .. tostring(event.userId),
            kind=spawnKind, levelEpoch=state.levelEpoch,
            connectionEpoch=hero.connectionEpoch, sourceAttempt=hero.attempt,
        }
    elseif kind == "CommitSpawn" then
        local problem = checkReservation(state, hero, event)
        if problem then return problem end
        if state.seenActors[event.actorId] then return "ACTOR_ID_REUSED" end
        local spawnKind = hero.pending.kind
        if spawnKind == "Initial" and not event.safe then return "UNSAFE_INITIAL_SPAWN" end
        if spawnKind ~= "Initial" then
            if not hasRespawn(hero) then return "NO_RESPAWNS" end
            if not hero.infiniteLives then hero.respawns = hero.respawns - 1 end
        end
        hero.health = MAX_HEALTH
        hero.attempt = hero.attempt + 1
        hero.actorId = event.actorId
        hero.status = "Alive"
        hero.view = "Playing"
        hero.pending = nil
        hero.retryReady = false
        hero.shield = nil
        if spawnKind ~= "Initial" then
            hero.shield = {
                kind = event.safe and "Normal" or "Emergency",
                deadline = event.now + (event.safe and NORMAL_SHIELD_SECONDS or EMERGENCY_SHIELD_SECONDS),
            }
        end
        state.seenActors[event.actorId] = true
    elseif kind == "AbortSpawn" then
        local problem = checkReservation(state, hero, event)
        if problem then return problem end
        hero.pending = nil
    elseif kind == "Connection" then
        local problem = checkConnection(hero, event, false)
        if problem then return problem end
        if hero.connected == event.connected then return "NO_CHANGE" end
        hero.connected = event.connected
        hero.connectionEpoch = hero.connectionEpoch + 1
        hero.pending = nil
        hero.retryReady = false
    elseif kind == "ChooseView" then
        local problem = checkConnection(hero, event, true)
        if problem then return problem end
        if hero.status ~= "Eliminated" then return "NOT_ELIMINATED" end
        if event.view ~= "Menu" and event.view ~= "Spectating" then return "INVALID_VIEW" end
        hero.view = event.view
    else
        local problem = checkActor(state, hero, event)
        if problem then return problem end
        if kind == "Death" then
            hero.health = 0
            hero.actorId = nil
            hero.pending = nil
            hero.shield = nil
            hero.retryReady = false
            hero.status = hasRespawn(hero) and "AwaitingRespawn" or "Eliminated"
            if hero.status == "Eliminated" then hero.view = "Choice" end
            closeIfDefeated(state)
        elseif kind == "SetHealth" then
            if not finite(event.health) or event.health < 0 or event.health > MAX_HEALTH then return "INVALID_HEALTH" end
            if event.health < hero.health and hero.shield and event.now < hero.shield.deadline then return "PROTECTED" end
            hero.health = event.health
        elseif kind == "BeginAttack" then
            problem = checkConnection(hero, event, true)
            if problem then return problem end
            clearEmergency(hero)
        elseif kind == "ExpireShield" then
            if not hero.shield then return "NO_SHIELD" end
            if event.now < hero.shield.deadline then return "NOT_DUE" end
            hero.retryReady = hero.shield.kind == "Emergency" and hero.connected and hasRespawn(hero)
            hero.shield = nil
        elseif kind == "RelocateToSafety" then
            local emergency = (hero.shield and hero.shield.kind == "Emergency") or hero.retryReady
                or (hero.pending and hero.pending.kind == "Emergency")
            if not emergency then return "NOT_EMERGENCY" end
            if not event.safe then return "UNSAFE_DESTINATION" end
            clearEmergency(hero)
        elseif kind == "AdvanceLevel" then
            if not event.prerequisitesMet then return "EXIT_NOT_READY" end
            if not event.destinationSafe then return "UNSAFE_DESTINATION" end
            if event.levelId == state.levelId then return "SAME_LEVEL" end
            state.levelId = event.levelId
            state.levelEpoch = state.levelEpoch + 1
            for _, member in pairs(state.heroes) do
                member.pending = nil
                member.retryReady = false
                if member.status == "Alive" then
                    member.health = MAX_HEALTH
                    if member.shield and member.shield.kind == "Emergency" then member.shield = nil end
                end
            end
        end
    end
    return nil
end

function Core.apply(state, event)
    local problem = validateEvent(event)
    if problem then return state, problem, nil end
    if event.runId ~= state.runId then return state, "WRONG_RUN", nil end
    local signature = fingerprint(event)
    local previous = state.receipts[event.id]
    if previous then
        if previous.fingerprint ~= signature then return state, "EVENT_ID_REUSED", nil end
        return state, "REPLAY", copy(previous.ack)
    end
    if event.expectedRevision ~= state.revision then return state, "STALE_REVISION", nil end
    if state.status ~= "Active" then return state, "RUN_CLOSED", nil end
    if event.now < state.time then return state, "TIME_REVERSED", nil end
    local nextState = copy(state)
    problem = execute(nextState, event)
    if problem then return state, problem, nil end
    nextState.revision = state.revision + 1
    nextState.time = event.now
    local hero = nextState.heroes[event.userId]
    local ack = {
        eventId=event.id, kind=event.kind, revision=nextState.revision,
        runId=nextState.runId, levelEpoch=nextState.levelEpoch,
        actorId=hero.actorId, attempt=hero.attempt, respawns=hero.respawns, infiniteLives=hero.infiniteLives,
        token=hero.pending and hero.pending.token or nil,
    }
    nextState.receipts[event.id] = {fingerprint=signature, ack=copy(ack)}
    return nextState, "OK", ack
end

return Core
