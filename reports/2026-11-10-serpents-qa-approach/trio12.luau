local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Pilot=require('./early-candidate')
local DT=1/60
local function fixture(index,seed,cohort)
    local d=Definition.build(index,seed);local w=FakeWorld.new();w.positions={};w.objects={};w.ordinary={}
    local mode
    function w:findSafe(id) if mode then return mode:respawnPosition(id) end;local p=table.clone(d.spawn);p.z=((id-1)-((cohort or 1)-1)/2)*4;return p end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held) local ok=spawn(self,id,actor,p,held);if ok then self.positions[id]=table.clone(p) end;return ok end
    function w:position(id) return self.positions[id] end
    function w:campaignPose(id,p) self.positions[id]=table.clone(p);self.ordinary[id]=nil end
    function w:campaignObject(id,kind,p,size,metadata) self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata} end
    function w:campaignRemove(id) self.objects[id]=nil end
    function w:campaignRelease() end
    function w:move(id,x,z,run)
        if mode and mode:move(id,x,z,run) then return end
        self.ordinary[id]={x=x,z=z,speed=run and 24 or 16}
    end
    function w:jump(id) if mode then mode:jump(id) end end
    function w:impulse(id,attacker,response)
        self.impulses+=1
        if mode then mode:impulse(id,{x=response.horizontal or 0,y=response.vertical or 0,z=0}) end
    end
    local cfg=GameConfig(Base,d)
    local roster={};for id=1,cohort or 1 do roster[#roster+1]={userId=id,template='Mr. Green'} end
    local s=Session.new(Core,Combat,cfg,roster,'early-course-probe-'..index..'-'..seed,w)
    s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK')
    mode=Modes.new(s,w,d)
    return d,s,mode,w
end

local failures=0
for _,cadence in ipairs({.08,.1,.133,.167}) do for _,seed in ipairs({1,41,934247736}) do
    local d,s,m,w=fixture(6,seed,3);local now,nextPlan,count=0,0,0;local dead
    while not m.complete and count<12000 do
        if now+1e-7>=nextPlan then
            for slot=1,3 do
                local p=Pilot.plan({definition=d,modes=m,actor=m.actors[slot],slot=slot,now=now,dt=DT,world=w,stageToken='cohort-'..cadence..'-'..seed})
                w:move(slot,p.x,p.z,p.run);if p.jump then w:jump(slot) end
            end
            nextPlan=now+cadence
        end
        now+=DT;s:step(now);m:step(now,DT);count+=1
        for slot=1,3 do if s.state.heroes[slot].status~='Alive' or s.state.heroes[slot].attempt~=1 or s.combat[slot].deathAt then dead=slot end end
        if dead then break end
    end
    if m.complete and not dead then print('PASS 3-hero Serpents cadence '..cadence..' seed '..seed..' frames '..count)
    else failures+=1;print('FAIL 3-hero Serpents cadence '..cadence..' seed '..seed..' room '..m.room..' dead '..tostring(dead))
        for slot=1,3 do local a=m.actors[slot];print(' slot '..slot..' xyz '..a.position.x..','..a.position.y..','..a.position.z..' support '..tostring(a.support)) end
    end
end end
assert(failures==0,tostring(failures)..' 3-hero failures')
