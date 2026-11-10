-- The mode may rewind bodies, while the real lifecycle alone replaces dead
-- actors and spends stock. This is separate from the kinematic fixture tests.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
return function(Definition,Modes)
    local d=Definition.build(3,41);local w=FakeWorld.new();w.positions={};w.spawnCounts={}
    local m
    function w:findSafe(id) return m and m:respawnPosition(id) or table.clone(d.spawn) end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held)
        local ok=spawn(self,id,actor,p,held)
        if ok then self.positions[id]=table.clone(p);self.spawnCounts[id]=(self.spawnCounts[id] or 0)+1 end
        return ok
    end
    function w:position(id) return self.positions[id] end
    function w:campaignPose(id,p) self.positions[id]=table.clone(p) end
    function w:campaignObject() end
    function w:campaignRelease() end
    function w:campaignRemove() end
    local cfg=GameConfig(Base,d)
    local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Yellow'},
        {userId=3,template='Mr. Brown'}},'vehicle-lifecycle',w)
    assert(s:step(0)=='OK');m=Modes.new(s,w,d)
    local now=5
    local function step(dt) now+=dt;assert(s:step(now)=='OK');m:step(now,dt) end
    step(0)
    for _=1,4 do s:_die(3,'LifecycleFixture');step(1/60) end
    assert(s.state.heroes[3].status=='Eliminated' and s.state.heroes[3].respawns==0)
    assert(s:_hit(-1,2,'Punch'));step(1)
    local survivor=s.state.heroes[2];local actor,attempt,stock=survivor.actorId,survivor.attempt,survivor.respawns
    local life=s.combat[2].rawLife;local spawns=w.spawnCounts[2]
    for _,id in ipairs({1,2}) do w.positions[id]=table.clone(d.course.mount);assert(m:interact(id,now,'Punch')=='OK') end
    local h=d.course.hazards[1];m.actors[1].position={x=h.x-2,y=h.y,z=h.z};step(1/60)
    assert(s.state.heroes[1].status=='AwaitingRespawn' and m.vehicleGroup.phase=='Stopped')
    for _=1,65 do step(1/60) end
    assert(m.vehicleGroup.phase=='Riding' and m.vehicleGroup.serial==1)
    assert(s.state.heroes[1].attempt==2 and s.state.heroes[1].respawns==2 and w.spawnCounts[1]==2)
    assert(survivor.actorId==actor and survivor.attempt==attempt and survivor.respawns==stock)
    assert(s.combat[2].rawLife==life and w.spawnCounts[2]==spawns,'rewind cannot heal or respawn a survivor')
    assert(s.state.heroes[3].status=='Eliminated' and w.spawnCounts[3]==4,'rewind cannot resurrect an eliminated hero')
    print('PASS real Session vehicle rewind preserves survivors and spends one collided respawn')
    s:_die(1,'EngineDeath');step(1/60)
    assert(m.vehicleGroup.phase=='Stopped' and m.vehicleGroup.serial==2,'external Session death must stop the same riding cohort')
    for _=1,65 do step(1/60) end
    assert(m.vehicleGroup.phase=='Riding' and m.vehicleGroup.serial==2)
    assert(s.state.heroes[1].attempt==3 and s.state.heroes[1].respawns==1 and w.spawnCounts[1]==3)
    assert(survivor.actorId==actor and survivor.attempt==attempt and survivor.respawns==stock)
    assert(s.combat[2].rawLife==life and w.spawnCounts[2]==spawns)
    assert(s.state.heroes[3].status=='Eliminated' and w.spawnCounts[3]==4)
    print('PASS real Session external engine death rewinds once without a second charge or survivor replacement')
    return 2
end
