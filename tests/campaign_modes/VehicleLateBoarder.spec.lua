-- A living teammate on foot can still board after the final existing rider
-- spends its last life. Session alone owns identities, stock and run loss.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
local DT=1/60

return function(Definition,Modes)
    local passed,failures=0,{}
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name)
        else failures[#failures+1]=name..': '..tostring(err);print('FAIL '..failures[#failures]) end
    end
    local function fixture(index,count)
        local d=Definition.build(index,41)
        local w=FakeWorld.new();w.positions={};w.spawnCounts={}
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
        local roster={{userId=1,template='Mr. Green'}}
        if count==2 then roster[2]={userId=2,template='Mr. Yellow'} end
        local s=Session.new(Core,Combat,GameConfig(Base,d),roster,'vehicle-late-boarder-'..index..'-'..count,w)
        assert(s:step(0)=='OK');m=Modes.new(s,w,d)
        local now=0
        local function step(dt)
            now+=dt;assert(s:step(now)=='OK');m:step(now,dt)
        end
        -- Spend only the first hero's stock through the actual lifecycle.
        for _=1,3 do s:_die(1,'LateBoarderFixture');step(3) end
        assert(s.state.heroes[1].status=='Alive' and s.state.heroes[1].attempt==4
            and s.state.heroes[1].respawns==0 and w.spawnCounts[1]==4)
        step(3) -- The final committed spawn's ordinary shield must expire.
        w.positions[1]=table.clone(d.course.mount)
        assert(m:interact(1,now,'Punch')=='OK')
        -- Actual authored swept hazard dispatch confirms the mounted final death.
        local h=d.course.hazards[1]
        m.actors[1].position={x=h.x-2,y=h.y,z=h.z}
        step(DT)
        assert(s.state.heroes[1].status=='Eliminated' and s.state.heroes[1].actorId==nil)
        return d,s,w,m,step,now
    end

    for _,index in ipairs({3,5,7}) do
        test('stage '..index..' late foot teammate boards after the last rider is eliminated',function()
            local d,s,w,m,step,now=fixture(index,2)
            assert(s.state.status=='Active' and not m.complete)
            local hero=s.state.heroes[2]
            local actor,attempt,stock=hero.actorId,hero.attempt,hero.respawns
            local life,spawns=s.combat[2].rawLife,w.spawnCounts[2]
            assert(not m.actors[2].mounted and hero.status=='Alive')
            w.positions[2]=table.clone(d.course.mount)
            assert(m:interaction(2).available and m:interact(2,now,'Punch')=='OK')
            local boardedX=m.actors[2].position.x
            for _=1,65 do step(DT) end
            local current=s.state.heroes[2]
            assert(current.status=='Alive' and current.actorId==actor and current.attempt==attempt
                and current.respawns==stock and s.combat[2].rawLife==life and w.spawnCounts[2]==spawns,
                'boarding/restart cannot replace or heal the living teammate')
            assert(s.state.heroes[1].status=='Eliminated' and s.state.heroes[1].respawns==0
                and w.spawnCounts[1]==4,'boarding cannot revive the eliminated rider')
            assert(m.vehicleGroup.phase=='Riding' and m.vehicleGroup.speed>0
                and m.actors[2].position.x>boardedX,
                'living late boarder is frozen: phase='..m.vehicleGroup.phase
                    ..' x='..m.actors[2].position.x..' speed='..m.vehicleGroup.speed
                    ..' Session='..s.state.status..' actor='..current.actorId
                    ..' attempt='..current.attempt..' stock='..current.respawns)
            assert(not m.complete)
        end)
        test('stage '..index..' genuinely lost Session never restarts or revives a rider',function()
            local _,s,w,m,step=fixture(index,1)
            assert(s.state.status=='Lost' and not m.complete)
            for _=1,65 do m:step(s.now+DT,DT) end
            assert(s.state.status=='Lost' and s.state.heroes[1].status=='Eliminated'
                and s.state.heroes[1].respawns==0 and w.spawnCounts[1]==4 and not m.complete)
            assert(not m:interaction(1).available and m:interact(1,s.now,'Punch')=='NO_INTERACTION')
        end)
    end
    assert(#failures==0,table.concat(failures,'\n'))
    return passed
end
