-- Normal movement only after the initial spawn. Real Session owns the catch,
-- paid retry and its finite shield; the world double only stores body poses.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
return function(Definition,Modes)
    local definition=Definition.build(11,41)
    local world=FakeWorld.new();world.positions={}
    local modes,orb
    function world:findSafe(id) return modes and modes:respawnPosition(id) or table.clone(definition.spawn) end
    local spawn=world.spawn
    function world:spawn(id,actor,p,held)
        local ok=spawn(self,id,actor,p,held)
        if ok then self.positions[id]=table.clone(p) end
        return ok
    end
    function world:position(id) return self.positions[id] end
    function world:campaignPose(id,p) self.positions[id]=table.clone(p) end
    function world:campaignObject() end
    function world:campaignRemove() end
    function world:campaignRelease() end
    local session=Session.new(Core,Combat,GameConfig(Base,definition),{{userId=1,template='Mr. Green'}},'clinger-endpoint',world)
    assert(session:step(0)=='OK');modes=Modes.new(session,world,definition)
    modes.chaseActor=function(p) orb=table.clone(p) end
    local now=0
    local function step(x,z)
        if x then assert(modes:move(1,x,z,false)) end
        now+=1/60;assert(session:step(now)=='OK');modes:step(now,1/60)
    end
    -- The first ordinary catch buys exactly one retry. Its ordinary shield can
    -- let the moving orb pass; wait until that real orb reaches the route end.
    for _=1,2400 do step() end
    local hero=session.state.heroes[1]
    assert(hero.status=='Alive' and hero.attempt==2 and hero.respawns==2 and not hero.shield)
    assert(orb and distance(orb,definition.course.finishPoint)<.001 and not modes.complete)
    local actor=hero.actorId
    for _=1,5000 do
        if modes.complete or session.state.heroes[1].status~='Alive' then break end
        local segment=definition.course.path[modes.actors[1].segment]
        step(segment and segment.direction.x or 0,segment and segment.direction.z or 0)
    end
    hero=session.state.heroes[1]
    assert(not modes.complete and hero.status=='AwaitingRespawn',
        'the actual orb waiting at the route endpoint must catch the rider before course completion')
    assert(hero.actorId==nil and world.actors[1].id==actor and hero.attempt==2 and hero.respawns==2 and world.spawns==2,
        'endpoint contact cannot create a replacement body or spend its next reserve early')
    assert(modes.chaseLife==207 and session.combat[1].rawLife==0)
    print('PASS real Session clinger retry shield cannot erase endpoint orb contact')
    return 1
end
