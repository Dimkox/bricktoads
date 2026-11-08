-- Source arithmetic is independent from the stand's physical and UI calibration.
local Combat = {}
-- Trusted server actions; public input validation remains in Session.
-- Pig animation40 does not satisfy the hero Dash animation16 finisher condition.
local fixedProfiles = {Punch=18,Club=20,PigJab=18,PigHeavy=20,PigRush=22,WalkerLight=18,WalkerHeavy=20,DragonHeadbutt=22,DragonFire=22,
    HeroJab=18,HeroKick=19,HeroUppercut=20,HeroPowerPunch=21,HeroBoot=24,HeroElbow=28}
local ordinaryProfiles={Punch=0,HeroJab=0,HeroKick=1,HeroUppercut=2,HeroPowerPunch=3,HeroBoot=6,HeroElbow=10,
    Club=2,PigJab=0,PigHeavy=2,PigRush=4,WalkerLight=0,WalkerHeavy=2,DragonHeadbutt=4,DragonFire=4,EnemyThrow=17}
local ordinaryDamage={[0]=2,[1]=8,[2]=16,[3]=255,[4]=16,[6]=255,[10]=8,[17]=4}
local function life(value)
    assert(type(value) == "number" and value == value and value >= 0
        and value <= 47 and value % 1 == 0, "raw Life must be an integer in 0..47")
end

function Combat.damage(old, damage)
    life(old)
    assert(damage == 2 or damage == 4 or damage == 8 or damage == 16 or damage == 255, "unsupported damage profile")
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
    local damage = profile==18 and 4 or ((profile==19 or profile==28) and 8 or ((profile==21 or profile==24) and 255 or 16))
    local raw, dying = Combat.damage(old, damage)
    if shield then raw, dying = old, false end
    return {
        rawLife=raw, dying=dying, profile=profile, rawDamage=damage,
        impulse=shield ~= "Emergency", blocked=shield ~= nil,
        recover=profile == 18 and not dying and shield == nil,
        heavyReaction=profile ~= 18,
    }
end

function Combat.hitEnemy(old,action)
    life(old)
    local profile=ordinaryProfiles[action]
    if action=='Dash' then profile=old<16 and 3 or 4 end
    assert(profile~=nil,'unsupported ordinary-target action')
    local damage=ordinaryDamage[profile]
    local raw,dying=Combat.damage(old,damage)
    return {rawLife=raw,dying=dying,profile=profile,rawDamage=damage,
        heavyReaction=profile~=0,recover=not dying}
end

function Combat.captureAttack(config,action,tuning)
    local result=table.clone(tuning or config.Attacks[action])
    local original=config.Attacks[action]
    if result.reaction==nil and original then result.reaction=original.reaction end
    result.deathDelay=config.DeathDelay
    result.sourceCombat=config.SourceCombat and table.clone(config.SourceCombat) or nil
    result.responses={}
    for profile,impulse in pairs(config.Impulses or {}) do
        local response=table.clone(impulse)
        response.profile=profile;result.responses[profile]=response
    end
    return result
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
