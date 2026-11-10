local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local Boss=require('../../src/server/gameplay/CampaignBoss')
local Source=require('../../src/server/gameplay/SourceCombat')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Config=require('../../src/server/gameplay/GameConfig')
local FakeWorld=require('../../tests/stand/FakeWorld')
local function new()
 local def=Definition.build(10,1158731273);def=table.clone(def);def.boss=table.clone(def.boss);def.boss.type=def.boss.kind
 local cfg=Config(require('../../src/stand/server/Config'),def);local f=def.boss.platform
 local bounds={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}
 local start={x=def.course.finishPoint.x,y=bounds.top+3,z=def.course.finishPoint.z}
 local w=FakeWorld.new();w.positions={};w.vel={};w.inputs={};w.testFloors={bounds};w.now=0
 function w:findSafe()return table.clone(start)end
 function w:position(id)return self.positions[id]end
 local function body(id,actor,p)
  w.positions[id]=table.clone(p);w.vel[id]={x=0,y=0,z=0};w.inputs[id]={x=0,z=0,run=false,at=0}
  actor.root={Parent=true,Anchored=false,CFrame={LookVector={X=1,Z=0}},AssemblyLinearVelocity={X=0,Y=0,Z=0}}
  actor.humanoid={Health=100,PlatformStand=false,FloorMaterial='Slate'};actor.locomotion={runRequested=false,groundRun=false,at=0}
  actor.model={GetAttribute=function(_,k)if k=='ActorId'then return actor.id elseif k=='MovementMode'then return w:isRunning(id)and'Run'or'Walk'end end}
 end
 local spawn=w.spawn
 function w:spawn(id,actorId,p,held)local ok=spawn(self,id,actorId,p,held);if ok then body(id,self.actors[id],p)end;return ok end
 function w:spawnEnemy(id,kind,p)self.actors[id]={alive=true,id='boss-body',kind=kind};body(id,self.actors[id],p);return true end
 function w:enemyIdentity(id,actorId)self.actors[id].id=actorId end
 function w:enemyHealth()end;function w:cue()end;function w:campaignWalkSpeed()end;function w:bossTell()end
 function w:projectile()end;function w:removeProjectile()end
 function w:placeActor(id,p)self.positions[id]=table.clone(p);return true end
 function w:aim(id,x,z)local n=math.max(.001,math.sqrt(x*x+z*z));self.actors[id].root.CFrame.LookVector={X=x/n,Z=z/n}end
 function w:face(id,target)local p,q=self.positions[id],self.positions[target];self:aim(id,q.x-p.x,q.z-p.z)end
 function w:move(id,x,z,run)
  self.inputs[id]={x=x,z=z,run=run==true,at=self.now};self.actors[id].locomotion={runRequested=run==true,groundRun=run==true,at=self.now}
  if x*x+z*z>.000001 then self:aim(id,x,z)end
 end
 function w:resetLocomotion(id)if self.actors[id]then self.actors[id].locomotion={runRequested=false,groundRun=false,at=self.now};self.inputs[id]={x=0,z=0,run=false,at=self.now}end end
 function w:setReaction(id,active)self.actors[id].reaction=active;self.actors[id].humanoid.PlatformStand=active end
 function w:isRunning(id)
  local a=self.actors[id];local m=self.inputs[id];local v=self.vel[id]
  return a and m and v and m.run and self.now-m.at<=cfg.MoveTimeout and a.humanoid.FloorMaterial~='Air'and not a.humanoid.PlatformStand and v.x*m.x+v.z*m.z>=18
 end
 function w:targets(id,shape)
  local out={};local p=self.positions[id];local a=self.actors[id].root.CFrame.LookVector
  for target,q in pairs(self.positions)do if target~=id and self.actors[target].alive then local x,z=q.x-p.x,q.z-p.z;local front=x*a.X+z*a.Z;local side=-x*a.Z+z*a.X
   if front>=0 and front<=(shape.reach or 6)and math.abs(side)<=(shape.width or 3)and math.abs(q.y-p.y)<=(shape.height or 4)then out[#out+1]=target end
  end end;table.sort(out);return out
 end
 function w:impulse(id,attacker,response)
  local a=self.actors[attacker].root.CFrame.LookVector;local v=self.vel[id]
  v.x+=a.X*response.horizontal;v.z+=a.Z*response.horizontal;v.y+=response.vertical;self.impulses+=1
 end
 function w:jump(id)if self.actors[id].humanoid.FloorMaterial~='Air'and not self.actors[id].humanoid.PlatformStand then self.vel[id].y=cfg.JumpPower end end
 function w:hazard(id)local p=self.positions[id];return p and p.y<cfg.FallY and'Fall'or nil end
 function w:observe(id)local p=self.positions[id];local v=self.vel[id];return{position={p.x,p.y,p.z},velocity={v.x,v.y,v.z}}end
 local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'Slaughter-source',w);s:step(0);w.now=2.1;s:step(2.1)
 local b=Boss.new(s,w,cfg,def)
 local d={boss=b,stage='Boss',enemies=b.enemies,ordinary={enemies={}},definition=def,config=cfg}
 function d:selectBossAction(_,input)return b:selectAction(input)end
 Source.bind(s,d,cfg)
 s.contextualAttack=function()return'NO_INTERACTION'end
 local oldHit=s._hit;s._hit=function(self,a,t,action,tuning)if t==-99 then b.now=self.now;return b:hit(a,t,action,tuning)end;return oldHit(self,a,t,action,tuning)end
 local function advance(dt,now)
  w.now=now
  for id,p in pairs(w.positions)do
   local a=w.actors[id];local v=w.vel[id];local m=w.inputs[id]
   local supported=p.x>=bounds.minX and p.x<=bounds.maxX and p.z>=bounds.minZ and p.z<=bounds.maxZ and p.y<=bounds.top+3+.001 and v.y<=0
   if supported then p.y=bounds.top+3;v.y=0;a.humanoid.FloorMaterial='Slate'else a.humanoid.FloorMaterial='Air';v.y-=196.2*dt end
   if not a.humanoid.PlatformStand then local speed=m.run and 24 or 16;v.x=m.x*speed;v.z=m.z*speed end
   p.x+=v.x*dt;p.y+=v.y*dt;p.z+=v.z*dt
   a.root.AssemblyLinearVelocity={X=v.x,Y=v.y,Z=v.z}
  end
 end
 return{definition=def,world=w,session=s,boss=b,director=d,advance=advance,base=2.1,actor={finished=true},modes={mode='Race'}}
end
return{new=new}
