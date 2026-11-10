local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Pilot=require('../../tools/qa/campaign_early_course_pilot')
local DT=1/60
local function fixture(index,seed)
    local d=Definition.build(index,seed);local w=FakeWorld.new();w.positions={};w.objects={};w.ordinary={}
    local mode
    function w:findSafe(id) return mode and mode:respawnPosition(id) or table.clone(d.spawn) end
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
    local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'early-course-probe-'..index..'-'..seed,w)
    s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK')
    mode=Modes.new(s,w,d)
    return d,s,mode,w
end

local failed=0
for _,index in ipairs({2,3,4,5,6}) do
for _,cadence in ipairs({.08,.1,.133,.167}) do
for _,seed in ipairs({1,41,8125,934247736,1134337449}) do
    local d,s,m,w=fixture(index,seed);local now,nextPlan,count=0,0,0;local jumps={};local lastSupport
    while not m.complete and count<12000 do
        local a=m.actors[1]
        if now+1e-7>=nextPlan then
            local p=Pilot.plan({definition=d,modes=m,actor=a,slot=1,now=now,dt=DT,world=w,stageToken='cadence-'..cadence..'-'..seed})
            w:move(1,p.x,p.z,p.run)
            if p.jump then
                jumps[#jumps+1]={now=now,x=a.position.x,y=a.position.y,z=a.position.z,support=a.support,room=m.room}
                w:jump(1)
            end
            if p.primary then m:interact(1,now,'Punch') end
            nextPlan=now+cadence
        end
        for id,ordinary in pairs(w.ordinary) do local native=w.positions[id]
            native.x+=ordinary.x*ordinary.speed*DT;native.z+=ordinary.z*ordinary.speed*DT
        end
        now+=DT;s:step(now);m:step(now,DT);count+=1
        if a.support~=lastSupport then lastSupport=a.support end
        if s.state.heroes[1].status~='Alive' or s.state.heroes[1].attempt~=1 or s.combat[1].deathAt then break end
    end
    local a=m.actors[1]
    if m.complete then print('PASS mode '..index..' cadence '..cadence..' seed '..seed..' frames '..count..' rawLife '..s.combat[1].rawLife)
    else
        failed+=1
        print('FAIL mode '..index..' cadence '..cadence..' seed '..seed..' frame '..count..' room '..m.room..' xyz '..a.position.x..','..a.position.y..','..a.position.z..' support '..tostring(a.support))
        for i=math.max(1,#jumps-4),#jumps do local j=jumps[i];print(' JUMP t='..j.now..' room='..j.room..' xyz='..j.x..','..j.y..','..j.z..' support='..tostring(j.support)) end
    end
end end end
assert(failed==0,tostring(failed)..' coarse cadence Jet failures')
