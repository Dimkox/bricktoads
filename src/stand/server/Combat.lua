-- Source arithmetic is independent from the stand's physical and UI calibration.
local Combat = {}
-- Trusted server actions; public input validation remains in Session.
-- Pig animation40 does not satisfy the hero Dash animation16 finisher condition.
local fixedProfiles = {Punch=18,Club=20,PigJab=18,PigHeavy=20,PigRush=22}
local function life(value)
    assert(type(value) == "number" and value == value and value >= 0
        and value <= 47 and value % 1 == 0, "raw Life must be an integer in 0..47")
end

function Combat.damage(old, damage)
    life(old)
    assert(damage == 4 or damage == 16 or damage == 255, "unsupported hero damage profile")
    if old < damage then return 0, true end
    local result = old - damage
    if math.floor(result / 16) ~= math.floor(old / 16) then
        result = math.floor(result / 16) * 16 + 15
    end
    return result, false
end

function Combat.hit(old, action, shield)
    life(old)
    assert(fixedProfiles[action] ~= nil or action == "Dash", "unsupported action")
    assert(shield == nil or shield == "Normal" or shield == "Emergency", "unsupported shield")
    local profile = fixedProfiles[action] or (old < 16 and 21 or 22)
    local damage = profile == 18 and 4 or (profile == 21 and 255 or 16)
    local raw, dying = Combat.damage(old, damage)
    if shield then raw, dying = old, false end
    return {
        rawLife=raw, dying=dying, profile=profile, rawDamage=damage,
        impulse=shield ~= "Emergency", blocked=shield ~= nil,
        recover=profile == 18 and not dying and shield == nil,
        heavyReaction=profile ~= 18,
    }
end

function Combat.recover(raw)
    life(raw)
    return math.floor(raw / 8) * 8 + 7
end

function Combat.hearts(raw)
    life(raw)
    return 5 * raw / 47
end

return Combat
