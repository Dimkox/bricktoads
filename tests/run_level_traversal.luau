local Level=require('../src/server/gameplay/LevelDefinition')
local Config=require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),Level)
-- Independent ballistic envelope for the authored route at default Roblox gravity.
-- This is a geometry budget, not an engine landing or networking simulation.
local gravity,takeoffLead,landingInset=196.2,2.5,.5
local gaps=0
for _,zone in ipairs(Level.zones) do
    for i=1,#zone.platforms-1 do
        local a,b=zone.platforms[i],zone.platforms[i+1]
        local from=a.x+a.w/2;local to=b.x-b.w/2
        if to>from then
            local dy=(b.y+b.h/2)-(a.y+a.h/2)
            local discriminant=Config.JumpPower^2-2*gravity*dy
            assert(discriminant>=0,'The next support is above the calibrated jump apex: '..zone.id)
            local flight=(Config.JumpPower+math.sqrt(discriminant))/gravity
            local available=Config.WalkSpeed*flight
            local required=to-from+takeoffLead+landingInset
            assert(available>=required,string.format('%s jump needs %.2f studs including takeoff/landing space, has %.2f',zone.id,required,available))
            gaps+=1
        end
    end
end
assert(gaps==5,'Every authored physical gap must be covered')
print('PASS all5 route gaps fit the main-game jump envelope with takeoff and landing space')
