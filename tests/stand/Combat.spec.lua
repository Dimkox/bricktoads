-- Pure arithmetic and policy checks; these do not simulate Roblox physics.
return function(Combat)
    assert(type(Combat.damage) == "function", "Combat.damage must be implemented")
    local count = 0
    local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)); count = count + 1 end
    local v = Combat.hit(47, "Punch", nil)
    eq(v.rawLife, 43); eq(v.profile, 18); eq(v.dying, false); eq(Combat.recover(v.rawLife), 47)
    v = Combat.hit(47, "Dash", nil); eq(v.rawLife, 31); eq(v.profile, 22)
    v = Combat.hit(16, "Dash", nil); eq(v.rawLife, 15); eq(v.profile, 22)
    v = Combat.hit(15, "Dash", nil); eq(v.rawLife, 0); eq(v.profile, 21); eq(v.dying, true)
    local raw, dying = Combat.damage(4, 4); eq(raw, 0); eq(dying, false)
    raw, dying = Combat.damage(3, 4); eq(raw, 0); eq(dying, true)
    eq(Combat.recover(0), 7); eq(Combat.hearts(47), 5); eq(Combat.hearts(0), 0)
    eq(Combat.hearts(43), 215 / 47)
    v = Combat.hit(47, "Punch", "Normal")
    eq(v.rawLife, 47); eq(v.dying, false); eq(v.impulse, true); eq(v.recover, false)
    v = Combat.hit(15, "Dash", "Normal"); eq(v.rawLife, 15); eq(v.dying, false)
    v = Combat.hit(47, "Punch", "Emergency"); eq(v.impulse, false); eq(v.rawLife, 47)
    eq(pcall(Combat.hit, 0/0, "Punch"), false)
    eq(pcall(Combat.hit, 48, "Punch"), false)
    eq(pcall(Combat.hit, 47, "Forged"), false)
    -- Club is a trusted server action with its own hero-target profile, not Dash.
    v=Combat.hit(47,'Club',nil)
    eq(v.rawLife,31);eq(v.profile,20);eq(v.rawDamage,16);eq(v.recover,false);eq(v.heavyReaction,true)
    v=Combat.hit(15,'Club',nil)
    eq(v.rawLife,0);eq(v.profile,20);eq(v.rawDamage,16);eq(v.dying,true)
    v=Combat.hit(16,'Club',nil);eq(v.rawLife,15);eq(v.dying,false)
    v=Combat.hit(47,'Club','Normal');eq(v.rawLife,47);eq(v.impulse,true);eq(v.blocked,true)
    v=Combat.hit(47,'Club','Emergency');eq(v.rawLife,47);eq(v.impulse,false)
    -- Pig animation28/2A/40 source paths have fixed hero profiles18/20/22.
    -- Running finisher21 belongs to the hero's Dash, never these Pig actions.
    local pigCases={
        {old=0,jab=0,jabDying=true,heavy=0,heavyDying=true},
        {old=3,jab=0,jabDying=true,heavy=0,heavyDying=true},
        {old=4,jab=0,jabDying=false,heavy=0,heavyDying=true},
        {old=15,jab=11,jabDying=false,heavy=0,heavyDying=true},
        {old=16,jab=15,jabDying=false,heavy=15,heavyDying=false},
        {old=47,jab=43,jabDying=false,heavy=31,heavyDying=false},
    }
    for _,case in ipairs(pigCases) do
        for _,action in ipairs({'PigJab','PigHeavy','PigRush'}) do
            local light=action=='PigJab'
            for _,shieldName in ipairs({'None','Normal','Emergency'}) do
                local shield=shieldName~='None' and shieldName or nil
                v=Combat.hit(case.old,action,shield)
                eq(v.rawLife,shield and case.old or (light and case.jab or case.heavy))
                eq(v.dying,not shield and (light and case.jabDying or (not light and case.heavyDying)) or false)
                eq(v.profile,light and 18 or (action=='PigHeavy' and 20 or 22))
                eq(v.rawDamage,light and 4 or 16)
                eq(v.heavyReaction,not light)
                eq(v.recover,light and not shield and not case.jabDying or false)
                eq(v.impulse,shield~='Emergency');eq(v.blocked,shield~=nil)
            end
        end
    end
    -- Independent rows from the previously verified common-routine table, not a hitbox proof.
    local expected4 = {0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,15,15,15,15,16,17,18,19,20,21,22,23,24,25,26,27,31,31,31,31,32,33,34,35,36,37,38,39,40,41,42,43}
    local expected16 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31}
    for old = 0, 47 do
        local a, dead = Combat.damage(old, 4); eq(a, expected4[old+1]); eq(dead, old < 4)
        a, dead = Combat.damage(old, 16); eq(a, expected16[old+1]); eq(dead, old < 16)
        a, dead = Combat.damage(old, 255); eq(a, 0); eq(dead, true)
    end
    print("PASS Combat: " .. count .. " assertions")
    return count
end
