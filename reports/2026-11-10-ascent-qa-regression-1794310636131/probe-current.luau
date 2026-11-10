local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('./baseline-CampaignModes')
local Pilot=require('../../tools/qa/campaign_late_course_pilot')
local DT=1/60
local function fixture(seed,scenario)
 local d=Definition.build(8,seed);local w=FakeWorld.new();w.positions={};w.objects={};local m
 function w:findSafe(id) return m and m:respawnPosition(id) or table.clone(scenario=='Checkpoint' and d.course.checkpoints[2].position or d.spawn) end
 local spawn=w.spawn
 function w:spawn(id,actor,p,held) local okay=spawn(self,id,actor,p,held);if okay then self.positions[id]=table.clone(p) end;return okay end
 function w:position(id) return self.positions[id] end
 function w:campaignPose(id,p) self.positions[id]=table.clone(p) end
 function w:campaignObject(id,kind,p,size,metadata) self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata} end
 function w:campaignRemove(id) self.objects[id]=nil end
 function w:campaignRelease() end
 function w:move(id,x,z,run) return m and m:move(id,x,z,run) end
 function w:jump(id) return m and m:jump(id) end
 function w:impulse(id,attacker,response,profile,direction)
  self.impulses+=1;self.lastProfile=profile
  return m:impulse(id,{x=(direction and direction.x or 1)*(response.horizontal or 0),y=response.vertical or 0,z=(direction and direction.z or 0)*(response.horizontal or 0)})
 end
 local cfg=GameConfig(Base,d)
 local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'ascent-recovery-'..seed..'-'..scenario,w)
 s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK');m=Modes.new(s,w,d)
 return d,s,m,w
end
local failed=0
for _,seed in ipairs({1,2104255637}) do for _,cadence in ipairs({.08,.1,.133,.167}) do
 for _,scenario in ipairs({'Clean','Checkpoint','LeftHit'}) do
  local d,s,m,w=fixture(seed,scenario);local now,nextPlan,count=0,0,0;local hit=false
  while not m.complete and count<6000 do
   local a=m.actors[1]
   if scenario=='LeftHit' and not hit and now>4 and a.grounded and a.position.y>=45 then
    local accepted=Combat.captureAttack(s.config,'WalkerHeavy');accepted.impulseDirection={x=-1,z=0}
    assert(s:_hit(-9001,1,'WalkerHeavy',accepted),'Real source NPC hit must be accepted')
    hit=true
   end
   if now+1e-7>=nextPlan then
    local p=Pilot.plan({modes=m,definition=d,actor=a,slot=1,now=now,dt=cadence,stageToken='recovery'})
    m:move(1,p.x,p.z,p.run);if p.jump then m:jump(1) end;if p.primary then m:interact(1,now,'Punch') end
    nextPlan=now+cadence
   end
   now+=DT;s:step(now);m:step(now,DT);count+=1
   if s.state.heroes[1].status~='Alive' or s.state.heroes[1].attempt~=1 or s.combat[1].deathAt then break end
  end
  local a=m.actors[1];local safe=m.complete and a.grounded and a.position.y>=98.99 and a.support=='floor-'..#d.course.platforms
  if not safe then failed+=1 end
  print((safe and 'PASS' or 'FAIL')..' Ascent '..scenario..' seed '..seed..' cadence '..cadence..' frames '..count..' xyz '..a.position.x..','..a.position.y..','..a.position.z..' support '..tostring(a.support)..' grounded '..tostring(a.grounded)..' complete '..tostring(m.complete)..' hit '..tostring(hit)..' profile '..tostring(w.lastProfile)..' raw '..s.combat[1].rawLife)
 end
end end
assert(failed==0,tostring(failed)..' Ascent recovery/handoff failures')
