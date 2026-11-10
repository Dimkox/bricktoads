local pilot=require('../../tools/qa/campaign_early_course_pilot')
local function clone(v) if type(v)~='table' then return v end;local c={};for k,x in pairs(v) do c[k]=clone(x) end;return c end
local function freeze(v,seen) if type(v)~='table' then return v end;seen=seen or {};if seen[v] then return v end;seen[v]=true;for _,x in pairs(v) do freeze(x,seen) end;table.freeze(v);return v end
local function fixture(mode)
    local d={mode=mode,course={hazards={},mount={x=24,y=3,z=0},mountRange=7,finishPoint={x=500,y=3,z=0},speed=32,maxSpeed=48,acceleration=.35,steerSpeed=22,laneLimit=18,jumpSpeed=42,ramps={},altitudeMin=5,altitudeMax=31}}
    if mode=='Jet' then d.course.speed=35;d.course.maxSpeed=52;d.course.acceleration=.45 end
    local a={attempt=1,mounted=true,grounded=true,position={x=100,y=mode=='Jet' and 17 or 3,z=0},velocity={x=d.course.speed,y=0,z=0}}
    local m={actors={[1]=a},elapsed=2,room=1,projectiles={},vehicleGroup={serial=0,phase='Riding',speed=d.course.speed,elapsed=2}}
    return {definition=d,modes=m,actor=a,slot=1,now=10,dt=1/60,director={campaignEnemies={now=10,projectiles={}}},stageToken='live-probe'}
end
local function obstacle(x,z,y)
    return {mode='Obstacle',position={x=x,y=y or 3,z=z},direction={x=1,z=0},speed=0,groundY=3,created=10,lastAt=10,expiresAt=14}
end
local failures=0
local function check(name,fn) local okay,err=pcall(fn);if okay then print('PASS '..name) else failures+=1;print('FAIL '..name..': '..tostring(err)) end end
check('Speeder avoids live accepted drop with authored safe lane',function()
    local c=fixture('Speeder');c.definition.course.hazards={{kind='Wall',x=124,y=3,z=-14,w=3,h=18,d=12}}
    c.director.campaignEnemies.projectiles[-6002]=obstacle(124,0)
    local p=pilot.plan(freeze(c));assert(p.z>0,'live drop must select +Z; -Z is occupied by authored wall')
end)
check('Surf avoids live accepted swept launcher shot',function()
    local c=fixture('Surf');c.modes.projectiles['course-shot-1']={position={x=124,y=3,z=0},velocity={x=-5,y=0,z=0},expires=4,kind='Rocket'}
    local p=pilot.plan(freeze(c));assert(p.z~=0,'live approaching shot requires depth avoidance')
end)
check('Jet search observes accepted launcher velocity',function()
    local c=fixture('Jet');c.modes.projectiles['course-shot-1']={position={x=122.5,y=17,z=2},velocity={x=-10,y=0,z=-5},expires=4,kind='Rocket'}
    local p=pilot.plan(freeze(c));assert(p.z~=0,'jet must leave intercepted altitude')
end)
check('Jet search observes live falling obstacle',function()
    local c=fixture('Jet');c.director.campaignEnemies.projectiles[-6002]=obstacle(117,0,25)
    local p=pilot.plan(freeze(c));assert(p.z~=0,'jet must avoid projected falling obstacle')
end)
check('Expired accepted effects do not divert course',function()
    local c=fixture('Speeder');local shot=obstacle(124,0);shot.expiresAt=9;c.director.campaignEnemies.projectiles[-6002]=shot
    assert(pilot.plan(freeze(c)).z==0)
end)
check('Live dodge cannot select a known authored crash when no clear replacement exists',function()
    local c=fixture('Speeder');c.definition.course.hazards={{kind='Wall',x=130,y=3,z=0,w=3,h=18,d=44}}
    c.director.campaignEnemies.projectiles[-6002]=obstacle(124,0)
    assert(pilot.plan(freeze(c)).z==0,'No safe forecast replacement must preserve the ordinary route input')
end)
check('Surviving rider lane cache resets after cohort rewind',function()
    local c=fixture('Speeder');c.actor.position.x=70
    c.definition.course.hazards={{kind='Wall',x=100,y=3,z=0,w=3,h=18,d=12},{kind='Wall',x=200,y=3,z=-12,w=3,h=18,d=12}}
    local first=pilot.plan(c);assert(first.z>0,'fixture must first prefer +Z')
    c.actor.position.x=250;pilot.plan(c)
    c.actor.position.x=70;c.modes.vehicleGroup.serial=1
    assert(pilot.plan(c).z==first.z,'unchanged actor attempt must resume the correct earlier lane')
end)
check('Jet rewind invalidates same-attempt cached input immediately',function()
    local c=fixture('Jet');assert(pilot.plan(c).z==0)
    c.now+=.01;c.modes.vehicleGroup.serial=1
    c.modes.projectiles['course-shot-1']={position={x=122.5,y=17,z=2},velocity={x=-10,y=0,z=-5},expires=4,kind='Rocket'}
    assert(pilot.plan(c).z~=0,'rewind must replan before old .1s input cache expires')
end)
assert(failures==0,tostring(failures)..' live QA probe failures')
