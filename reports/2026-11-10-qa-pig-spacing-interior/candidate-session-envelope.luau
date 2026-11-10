-- Conditional contact replay, not an NPC-AI or Roblox Humanoid reproduction.
-- Real Session, PigJab capture/profile, reaction/reset, Life and paid-death FSM.
-- Native presentation/ground response is mapped explicitly below.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Pilot=require('./candidate-combat')
local Rig=require('./candidate-foot')
local DT=1/60
local origin=80.514638
local hitAt=81.251055-origin
local native={
 {at=80.514638,x=.44514727263538223,z=.8954573723328658,evade=true},
 {at=80.660020,x=-.025218147506109203,z=-.07592130818393554},
 {at=80.786564,x=.9452106781465803,z=.3264609837602063,evade=true},
 {at=80.932066,x=-.04350822034035977,z=-.06713445287491888},
 {at=81.047461,x=-.04921405503466143,z=-.06307120410334113},
 {at=81.165668,x=.7780036926269531,z=-.005505561828613281,evade=true},
}
local function case(name,firstReplace,delivery,firstTellOverride)
 local d=Definition.build(1,1158731273);local cfg=GameConfig(Base,d)
 local w=FakeWorld.new();local p={x=47.37826156616211,y=2.9995784759521484,z=11.006926536560059}
 local v={x=4.24852180480957,y=0,z=15.425762176513672};local pending={};local input={x=0,z=0}
 function w:findSafe()return table.clone(p)end
 function w:position()return p end
 function w:observe()return{position={p.x,p.y,p.z},velocity={v.x,v.y,v.z}}end
 function w:move(_,x,z)input={x=x,z=z}end
 function w:impulse(_,_,response,profile)
  self.impulses+=1;assert(profile==18 and response.horizontal==9 and response.vertical==0,'Actual PigJab profile18')
  -- Outward diagonal is a transparent envelope, not an inferred NPC facing.
  local q=1/math.sqrt(2);v.x+=response.horizontal*q;v.z+=response.horizontal*q;v.y+=response.vertical
 end
 function w:hazard()return p.y<cfg.FallY and 'Fall' or nil end
 local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'contact-envelope-'..name..'-'..delivery,w)
 s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK')
 local now,seq,nextPlan,hit,contact,escaped=0,0,0,false,nil,false
 local h=s.state.heroes[1]
 w.testFloors={};for _,zone in ipairs(d.zones)do for _,f in ipairs(zone.platforms)do w.testFloors[#w.testFloors+1]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}end end
 w.actors[1].model={GetAttribute=function(_,k)return k=='ActorId'and h.actorId or nil end}
 w.actors[1].root={Parent=true,Anchored=false,CFrame={LookVector={X=-.44514727263538223,Z=-.8954573723328658}},AssemblyLinearVelocity={X=v.x,Y=0,Z=v.z}}
 w.actors[1].humanoid={FloorMaterial='Slate',PlatformStand=false,Health=100};w.actors[1].locomotion={runRequested=false}
 local q
 function w:position(id)return id==1 and p or q end
 local director={stage='Route',zoneIndex=2,enemies={[-5]={kind='Pig',rawLife=15,actorId='pig5',nextAttack=0}}}

 local function send(x,z)
  local h=s.state.heroes[1];seq+=1
  s:intent(1,{kind='Move',x=x,z=z,run=false,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
   levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq},now)
 end
 while now<2.5 and not s.combat[1].deathAt and s.state.heroes[1].status=='Alive'and s.state.heroes[1].attempt==1 do
  while pending[1]and pending[1].at<=now+1e-8 do local q=table.remove(pending,1);send(q.x,q.z)end
  if now+1e-8>=nextPlan and not hit then
   q={x=p.x-.44514727263538223*2.8,y=3,z=p.z-.8954573723328658*2.8}
   local body=w.actors[1];body.root.AssemblyLinearVelocity={X=v.x,Y=0,Z=v.z}
   if origin+now>=80.936640 then director.enemies[-5].windup={at=81.236640,action='PigJab',tuning=cfg.Attacks.PigJab}end
   local ctx={slot=1,now=origin+now,dt=.133,world=w,session=s,director=director,position=p,definition=d,stageToken=name..delivery}
   local tactical=Pilot.plan(ctx)
   if now==0 then assert(tactical.evasion,'First prepared ordinary Pig spacing must use actual Combat evasion')end
   local out=Rig.foot(ctx,q,tactical)
   pending[#pending+1]={at=now+delivery,x=out.x,z=out.z}
   nextPlan=now+.133
  end
  if not hit and now+1e-8>=hitAt then
   contact=table.clone(p)
   local captured=Combat.captureAttack(cfg,'PigJab',cfg.Attacks.PigJab)
   assert(s:_hit(-5,1,'PigJab',captured),'Accepted replay of original native contact')
   hit=true;assert(s.combat[1].rawLife==43 and s.combat[1].reactionEnd,'No HP fixture writes')
  end
  local grounded=p.x>=4 and p.x<=54 and p.z>=-23 and p.z<=17 and p.y>=2.99
  if not s.combat[1].reactionEnd and grounded then v.x=input.x*cfg.WalkSpeed;v.z=input.z*cfg.WalkSpeed end
  if grounded then p.y=3;v.y=0 else v.y-=196.2*DT;escaped=true end
  p.x+=v.x*DT;p.y+=v.y*DT;p.z+=v.z*DT
  now+=DT;s:step(now)
 end
 local deaths=0;for _,e in ipairs(s.logs)do if e.kind=='ConfirmedDeath'then deaths+=1 end end
 local safe=hit and not escaped and deaths==0 and p.x>=4 and p.x<=54 and p.z>=-23 and p.z<=17
 print((safe and'GREEN'or'RED')..' '..name..' delivery='..delivery..' elapsed='..now..' deaths='..deaths
  ..' contact='..contact.x..','..contact.z..' terminal='..p.x..','..p.y..','..p.z..' Life='..s.combat[1].rawLife)
 return safe
end
local green=0
for _,delay in ipairs({0,2/60,.08})do if case('actual-composition',nil,delay)then green+=1 end end
print('COMPOSED_ENVELOPE_GREEN',green)
assert(green==3,'Actual Combat -> extracted actual Bridge -> Session/profile envelope count')
