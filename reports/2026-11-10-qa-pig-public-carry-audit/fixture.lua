local Session=require('../../src/stand/server/Session')
local Director=require('../../src/server/gameplay/LevelDirector')
local Carry=require('../../src/server/gameplay/EnemyCarry')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local Source=require('../../src/server/gameplay/SourceCombat')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local FakeWorld=require('../../tests/stand/FakeWorld')
local function new(raw)
 local definition=Definition.build(1,1158731273);local level=table.clone(definition);local zone=table.clone(definition.zones[2])
 local px,pz=47,10;local ax,az=-.44514727263538223,-.8954573723328658
 zone.enemies={{id=-5,kind='Pig',rawLife=raw,x=px+ax*2.8,y=3,z=pz+az*2.8}};level.zones={zone}
 local cfg=GameConfig(require('../../src/stand/server/Config'),level)
 local w=FakeWorld.new();w.positions={[1]={x=px,y=3,z=pz}};w.links={};w.front={[1]={x=ax,z=az}};w.grounded=true
 function w:findSafe()return table.clone(self.positions[1])end
 function w:position(id)return self.positions[id]end
 function w:spawnEnemy(id,kind,p)self.positions[id]=table.clone(p);self.actors[id]={alive=true};return true end
 function w:enemyIdentity()end;function w:enemyHealth()end;function w:stage()end;function w:progress()end;function w:reached()return false end;function w:cue()end
 function w:enemyMove()end;function w:face()end;function w:targets(id)return id==-5 and{1}or{}end
 function w:canGrabEnemy(slot,id,range,height,facing)
  local p,q=self.positions[slot],self.positions[id];local f=self.front[slot]
  if not self.grounded or not f or not p or not q then return false end
  local x,y,z=q.x-p.x,q.y-p.y,q.z-p.z;local n=math.sqrt(x*x+z*z)
  return x*x+y*y+z*z<=range*range and math.abs(y)<=height and(n<.001 or(f.x*x+f.z*z)/n>=facing)
 end
 function w:carryEnemy(id,slot)self.links[id]=slot;return true end
 function w:releaseEnemy(id)self.links[id]=nil;return true end
 local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'public-carry-'..raw,w);s:step(0)
 local h=s.state.heroes[1]
 w.actors[1].model={GetAttribute=function(_,k)return k=='ActorId'and h.actorId or nil end}
 w.actors[1].root={Parent=true,Anchored=false,CFrame={LookVector={X=ax,Z=az}},AssemblyLinearVelocity={X=0,Y=0,Z=0}}
 w.actors[1].humanoid={FloorMaterial='Slate',Health=100,PlatformStand=false};w.actors[1].locomotion={runRequested=false}
 local d=Director.new(s,w,Combat,cfg,nil,nil,Carry);d._zoneReached=function()return false end;d._boss=function()end
 Source.bind(s,d,cfg);s.contextualAttack=function(slot,now,action)return d:interact(slot,now,action)end
 local seq=0
 local function punch(now)
  seq+=1;local hero=s.state.heroes[1]
  return s:intent(1,{kind='Attack',attack='Punch',runId=s.state.runId,actorId=hero.actorId,attempt=hero.attempt,
   connectionEpoch=hero.connectionEpoch,levelEpoch=s.state.levelEpoch,seq=seq},now)
 end
 local function step(now)local dt=now-s.now;s:step(now);d:step(now,dt)end
 return{session=s,director=d,world=w,definition=level,punch=punch,step=step,heroId=h.actorId,pigId=d.enemies[-5].actorId}
end
return{new=new}
