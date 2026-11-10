-- Prepared one-Pig source encounter, fixed native corner/facing; mapped ground.
local Session=require('../../src/stand/server/Session')
local Director=require('../../src/server/gameplay/LevelDirector')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local SourceCombat=require('../../src/server/gameplay/SourceCombat')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Pilot=require('./candidate-combat')
local Rig=require('./candidate-foot')
local DT=1/60
local level=Definition.build(1,1158731273);local zone=table.clone(level.zones[2])
zone.enemies={{id=-5,kind='Pig',rawLife=15,x=47-.44514727263538223*2.8,y=3,z=10-.8954573723328658*2.8}}
level=table.clone(level);level.zones={zone};local cfg=GameConfig(require('../../src/stand/server/Config'),level)
local w=FakeWorld.new();w.positions={[1]={x=47,y=3,z=10}};w.inputs={};w.vel={[1]={x=0,y=0,z=0}};w.aims={[1]={x=-.44514727263538223,z=-.8954573723328658}}
w.testFloors={{minX=4,maxX=54,minZ=-23,maxZ=17,top=0}}
function w:findSafe()return table.clone(self.positions[1])end
function w:position(id)return self.positions[id]end
function w:spawnEnemy(id,kind,p)self.positions[id]=table.clone(p);self.actors[id]={alive=true};self.vel[id]={x=0,y=0,z=0};return true end
function w:enemyIdentity()end;function w:enemyHealth()end;function w:stage()end;function w:progress()end;function w:reached()return false end;function w:cue()end
function w:face(id,target)local p,q=self.positions[id],self.positions[target];local x,z=q.x-p.x,q.z-p.z;local n=math.max(.001,math.sqrt(x*x+z*z));self.aims[id]={x=x/n,z=z/n}end
function w:move(id,x,z,run)self.inputs[id]={x=x,z=z,speed=id==1 and(run and 24 or 16)or 9};if x*x+z*z>.001 then local n=math.sqrt(x*x+z*z);self.aims[id]={x=x/n,z=z/n}end end
function w:enemyMove(id,target,speed)local p,q=self.positions[id],self.positions[target];local dx,dz=q.x-p.x,q.z-p.z;local n=math.max(1,math.sqrt(dx*dx+dz*dz));self:move(id,dx/n,dz/n);self.inputs[id].speed=speed end
function w:targets(id,shape)local out={};local p=self.positions[id];local a=self.aims[id]or{x=1,z=0};for other,q in pairs(self.positions)do if other~=id and self.actors[other]and self.actors[other].alive then local x,z=q.x-p.x,q.z-p.z;local front=x*a.x+z*a.z;local side=-x*a.z+z*a.x;if front>=0 and front<=shape.reach and math.abs(side)<=shape.width and math.abs(q.y-p.y)<=shape.height then out[#out+1]=other end end end;return out end
function w:impulse(id,attacker,response)local v=self.vel[id];local a=self.aims[attacker]or{x=1,z=0};v.x+=a.x*response.horizontal;v.y+=response.vertical;v.z+=a.z*response.horizontal;self.impulses+=1 end
local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'Pig-corner-progress',w);s:step(0)
local h=s.state.heroes[1];w.actors[1].model={GetAttribute=function(_,k)return k=='ActorId'and h.actorId or nil end}
w.actors[1].root={Parent=true,Anchored=false,CFrame={LookVector={X=w.aims[1].x,Z=w.aims[1].z}},AssemblyLinearVelocity={X=0,Y=0,Z=0}}
w.actors[1].humanoid={FloorMaterial='Slate',PlatformStand=false,Health=100};w.actors[1].locomotion={runRequested=false}
local d=Director.new(s,w,Combat,cfg);d._zoneReached=function()return false end;d._boss=function()end
SourceCombat.bind(s,d,cfg);local old=s._hit;s._hit=function(self,a,b,action,tuning)if b<0 then return d:hit(a,b,action,tuning)end;return old(self,a,b,action,tuning)end
local now,nextPlan,seq,primaries=0,0,0,0
local function send(kind,out)seq+=1;local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq};for k,v in pairs(out or{})do p[k]=v end;return s:intent(1,p,now)end
while now<30 and not d.enemies[-5].dead and not s.combat[1].deathAt do
 if now+1e-8>=nextPlan then
  local p=w.positions[1];local v=w.vel[1];local a=w.actors[1];a.root.AssemblyLinearVelocity={X=v.x,Y=v.y,Z=v.z};a.root.CFrame.LookVector={X=w.aims[1].x,Z=w.aims[1].z}
  local ctx={slot=1,now=now,dt=.133,stageToken='corner-progress',session=s,director=d,world=w,position=p,definition=level}
  local tactical=Pilot.plan(ctx);local out=Rig.foot(ctx,w.positions[-5],tactical);send('Move',{x=out.x,z=out.z,run=out.run})
  if out.primary then primaries+=1;send('Attack',{attack='Punch'})end
  if out.jump then send('Jump')end;nextPlan=now+.133
 end
 for id,p in pairs(w.positions)do local m=w.inputs[id]or{x=0,z=0,speed=0};local v=w.vel[id];local locked=id==1 and s.combat[1].reactionEnd or id<0 and d.enemies[id].reactionUntil
  if not locked then v.x=m.x*m.speed;v.z=m.z*m.speed end
  p.x+=v.x*DT;p.z+=v.z*DT
 end
 now+=DT;s:step(now);d:step(now,DT)
end
local attacks,hits=0,0;for _,e in ipairs(s.logs)do if e.kind=='AttackAccepted'then attacks+=1 elseif e.kind=='Hit'then hits+=1 end end
print('CLOSED_LOOP',now,'PigDead',d.enemies[-5].dead,'PigLife',d.enemies[-5].rawLife,'primaryRequests',primaries,'acceptedPrimary',attacks,'heroHits',hits,'heroLife',s.combat[1].rawLife,'heroXZ',w.positions[1].x,w.positions[1].z)
assert(d.enemies[-5].dead or(d.enemies[-5].rawLife<15 and attacks>0),'Bounded30s ordinary contact must produce enemy death or an effective ordinary primary')
