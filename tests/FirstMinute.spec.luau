return function(Tracker)
    local now, serial, events = 100, 0, {}
    local timers = {}
    local function log(player, name, session, step, label, route)
        table.insert(events, {player=player, name=name, session=session, step=step, label=label, route=route})
    end
    local tracker = Tracker.new(function() return now end, function()
        serial += 1
        return tostring(serial)
    end, log, nil, function(delay, callback) table.insert(timers, {delay=delay, callback=callback}) end)
    local host, teammate = {}, {}
    local function steps(player, name)
        local result = {}
        for _, event in ipairs(events) do
            if event.player == player and event.name == name then table.insert(result, event.step) end
        end
        return table.concat(result, ",")
    end
    tracker:join(host)
    tracker:join(host)
    tracker:join(teammate)
    tracker:startPressed(host)
    tracker:spawned(host)
    tracker:spawned(teammate)
    tracker:enemyHit(host, false)
    tracker:enemyHit(host, true)
    tracker:enemyHit(host, true)
    tracker:enemyHit(teammate, true)
    assert(steps(host, "FirstMinute") == "1,2,3,4,5")
    assert(steps(host, "FirstMinuteGameplay") == "1,2,3,4")
    assert(steps(teammate, "FirstMinute") == "1")
    assert(steps(teammate, "FirstMinuteGameplay") == "1,2,3,4")
    for _, e in ipairs(events) do assert(e.session == (e.player == host and "1" or "2")) end
    local late = {}
    tracker:join(late)
    tracker:enemyDefeated(late)
    now = 159.99
    tracker:startPressed(late)
    now = 160.01
    tracker:spawned(late)
    assert(steps(late, "FirstMinute") == "1,2")
    tracker:leave(late)
    tracker:spawned(late)
    tracker:join(late)
    tracker:startPressed(late)
    assert(events[#events].session == "4")
    local attempted, sent, warnings = 0, {}, {}
    local unreliable = Tracker.new(function() return 1 end, function() return "test" end,
        function(_, name, _, step)
            if name ~= "FirstMinute" then return end
            attempted += 1
            if attempted <= 2 then error("temporary") end
            table.insert(sent, step)
        end, function(message) table.insert(warnings, message) end)
    unreliable:join(host)
    unreliable:startPressed(host)
    assert(#warnings == 1 and #sent == 0)
    unreliable:spawned(host)
    assert(table.concat(sent, ",") == "1,2,3")
    unreliable:enemyDefeated(host)
    assert(#sent == 3)
    local reads = 0
    local ad = {GetJoinData=function()
        reads += 1
        return {LaunchData="speeder"}
    end}
    now = 200
    assert(tracker:join(ad) == "speeder" and tracker:join(ad) == "speeder" and reads == 1)
    for _, value in ipairs({"Speeder", " speeder", "", "other", 5, {route="speeder"}}) do
        assert(tracker:join({GetJoinData=function() return {LaunchData=value} end}) == "untagged")
    end
    assert(tracker:join({GetJoinData=function() error("no join data") end}) == "untagged")
    tracker:spawned(ad)
    tracker:enemyHit(ad, true)
    assert(steps(ad, "FirstMinuteProgress") == "1,2")
    tracker:boarded(ad)
    tracker:passedFirstWall(ad)
    tracker:passedFirstWall(ad)
    assert(steps(ad, "FirstMinuteProgress") == "1,2,3,4")
    assert(steps(ad, "FirstMinute") == "1")
    assert(steps(ad, "EntryStart120s") == "")
    assert(steps(host, "FirstMinuteProgress") == "1,2,3,4")
    for _, e in ipairs(events) do
        assert(e.route == (e.player == ad and "speeder" or "untagged"))
    end
    local early, exact = {}, {}
    tracker:join(early)
    tracker:join(exact)
    now = 229.9
    tracker:leave(early)
    now = 230
    tracker:leave(exact)
    now = 260.02 -- scheduled callbacks run on the next heartbeat
    for _, timer in ipairs(timers) do timer.callback() end
    assert(steps(early, "EntryRetention120s") == "1")
    assert(steps(exact, "EntryRetention120s") == "1,2")
    assert(steps(ad, "EntryRetention120s") == "1,2,3")
    now = 319.99
    tracker:leave(ad)
    local oldTimers = #timers
    now = 320
    tracker:join(ad)
    for i=1,oldTimers do timers[i].callback() end
    assert(steps(ad, "EntryRetention120s") == "1,2,3,1")
    local slow = {GetJoinData=function() return {LaunchData="speeder"} end}
    tracker:join(slow)
    tracker:spawned(slow)
    now = 395
    tracker:boarded(slow)
    now = 440
    tracker:passedFirstWall(slow)
    assert(steps(slow, "EntryProgress120s") == "1,2,3,4")
    assert(steps(slow, "FirstMinuteProgress") == "1,2")
    now = 440.02
    for _, timer in ipairs(timers) do timer.callback() end
    tracker:leave(slow)
    assert(steps(slow, "EntryRetention120s") == "1,2,3,4")
    local over = {}
    tracker:join(over)
    now += 119.99
    tracker:startPressed(over)
    tracker:spawned(over)
    now += .02
    tracker:enemyHit(over, true)
    assert(steps(over, "EntryProgress120s") == "1,2")
    assert(steps(over, "EntryStart120s") == "1,2" and steps(over, "FirstMinute") == "1")
    local idle = {}
    tracker:join(idle)
    now += 120.01
    tracker:startPressed(idle)
    assert(steps(idle, "EntryStart120s") == "1")
    print("PASS first-minute funnels preserve real event order, visit identity, timeout and party ownership")
end
