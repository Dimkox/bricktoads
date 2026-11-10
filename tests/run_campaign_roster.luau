local Combat=require('../src/stand/server/Combat')
local function eq(a,b,label) assert(a==b,(label or '')..' expected '..tostring(b)..', got '..tostring(a)) end
for _,raw in ipairs({63,79,111,255}) do
    local ok,result=pcall(Combat.hitEnemy,raw,'HeroJab')
    assert(ok,'ordinary byte Life '..raw..' must be supported')
    eq(result.rawLife,raw-2);eq(result.dying,false)
    eq(Combat.recoverEnemy(raw-2),raw)
end
assert(not pcall(Combat.hit,63,'Punch'),'hero Life must retain its 47 guard')
assert(not pcall(Combat.hearts,63),'hero display must retain its five heart guard')
eq(Combat.hitEnemy(79,'RopeStrike').rawLife,71)
eq(Combat.hitEnemy(15,'RopeBoot').dying,true)
eq(Combat.hit(47,'RopeStrike').profile,25);eq(Combat.hit(47,'RopeStrike').dying,true)
eq(Combat.hit(47,'RopeBoot').profile,31);eq(Combat.hit(47,'RopeBoot').rawLife,31)
eq(Combat.hitEnemy(79,'RopeClaw').rawLife,71);eq(Combat.hit(47,'RopeClaw').profile,25)
local Config=require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),require('../src/server/gameplay/LevelDefinition'))
assert(Config.Attacks.RopeStrike and Config.Attacks.RopeBoot,'trusted rope attack geometry required')
assert(Config.Attacks.RopeClaw and Config.Attacks.RopeClaw.height>Config.Attacks.RopeStrike.height,'claw must expose its distinct contact shape')
assert(Config.Impulses[7] and Config.Impulses[13] and Config.Impulses[25] and Config.Impulses[31],'rope responses required')
local Roster=require('../src/server/gameplay/CampaignRoster')
local Definition=require('../src/server/gameplay/CampaignDefinition')
local seen={}
for index=2,13 do
    local d=Roster.apply(Definition.build(index,19),index)
    for _,zone in ipairs(d.zones) do for _,e in ipairs(zone.enemies) do
        if Roster.profiles[e.kind] then
            assert(e.sourceProfile and e.sourceProfile.source,'source profile '..e.kind)
            assert(e.rawLife>=0 and e.rawLife<=255)
            seen[e.kind]=true
        end
    end end
    if index==2 then
        assert(seen.Raven and seen.LargeRaven and seen.RetroBlaster and seen.SaturnToadtrap,'rope roles must be actual ordinary actors')
        for _,h in ipairs(d.course.hazards) do assert(h.kind~='Raven' and h.kind~='Toadtrap','ordinary foe must not also be a static damage box') end
        for _,emitter in ipairs(d.course.emitters or {}) do assert(emitter.kind~='RetroBlaster','ordinary blaster must not also emit duplicate mode damage') end
        local count=#d.zones[1].enemies;Roster.apply(d,index);eq(#d.zones[1].enemies,count,'idempotent roster')
    end
    if index==12 then
        local life={}
        for _,e in ipairs(d.zones[1].enemies) do life[e.kind..':'..e.rawLife]=true end
        assert(life['Hordhead:47'] and life['Hordhead:63'],'both authored Hordhead Life variants')
        assert(life['Swellcheeks:47'] and life['Swellcheeks:79'] and life['Swellcheeks:111'],'all authored Swellcheeks Life variants')
    end
end
for _,kind in ipairs({'SentryDrone','Slug','GasTurret','Robot','Electrofish','Duck'}) do eq(Roster.profiles[kind].lifeVariants[1],15,kind) end
eq(Roster.profiles.Invader.loaderLife,255);eq(Roster.profiles.Invader.lifeMode,'LinkedLife')
eq(table.concat(Roster.profiles.Hordhead.lifeVariants,','),'47,63')
eq(table.concat(Roster.profiles.Swellcheeks.lifeVariants,','),'47,79,111')
print('CampaignRoster: byte arithmetic and source profile contracts passed')
