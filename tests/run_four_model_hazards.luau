-- Exercise the same finite hazard path, spawn threshold and retry serial used by the course.
local Modes=require('../src/server/gameplay/CampaignModes')
local Definition=require('../src/server/gameplay/CampaignDefinition')
for _,level in {3,7} do
    local route=Definition.build(level,41)
    local hazard
    for _,candidate in route.course.hazards do
        if candidate.kind=='RatPod' or candidate.kind=='Meteorite' then hazard=candidate end
    end
    assert(hazard)
    local courseObjects={}
    local world={
        campaignObject=function(_,id,_,p) courseObjects[id]=p end,
        campaignRemove=function(_,id) courseObjects[id]=nil end,
    }
    local rider={mounted=true,position={x=hazard.x-45,y=hazard.y,z=0}}
    local m=setmetatable({vehicleGroup={phase='Riding',serial=0},actors={rider},elapsed=0,
        airPasses={},hazards={},objects={},world=world},Modes)
    m:_airPass(hazard,0)
    local id=hazard.id..':0'
    assert(math.abs(courseObjects[id].z)==24)
    m.elapsed=1.2;m:_airPass(hazard,.02)
    assert(math.abs(courseObjects[id].z)<.001 and m.hazards[2].previous.z~=m.hazards[2].z)
    m.elapsed=2.5;m:_airPass(hazard,.02)
    assert(courseObjects[id]==nil)
    m.vehicleGroup.serial=1;m.vehicleGroup.phase='Rewinding'
    m:_airPass(hazard,.02)
    assert(next(courseObjects)==nil and next(m.airPasses)==nil)
    m.vehicleGroup.phase='Riding';m:_airPass(hazard,.02)
    assert(courseObjects[hazard.id..':1'])
end
print('PASS both air hazards cross once, expire and respawn on a new attempt')
