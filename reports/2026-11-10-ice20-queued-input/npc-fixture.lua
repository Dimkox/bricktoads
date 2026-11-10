local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Families=require('../../src/server/gameplay/CampaignEnemies')
local Director=require('../../src/server/gameplay/LevelDirector')
local CampaignDirector=require('../../src/server/gameplay/CampaignDirector')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local SourceCombat=require('../../src/server/gameplay/SourceCombat')
local FakeWorld=require('../../tests/stand/FakeWorld')
local function fixture(seed)
 local def=Definition.build(4,seed);local w=FakeWorld.new();w.positions={};w.names={};w.objects={};w.aims={}
 function w:position(id)return self.positions[id]end
 function w:findSafe(id)if self.campaignModes then return self.campaignModes:respawnPosition(id)end;local p=table.clone(def.spawn);p.z-=6;return p end
 local spawn=w.spawn
 function w:spawn(id,actor,p,held)local ok=spawn(self,id,actor,p,held);if ok then self.positions[id]=table.clone(p or def.spawn)end;return ok end
 function w:spawnEnemy(id,kind,p)self.positions[id]=table.clone(p);self.actors[id]={id=id,alive=true,kind=kind};return true end
 function w:campaignPose(id,p,mode,v)
  self.positions[id]=table.clone(p);if v and v.x*v.x+v.z*v.z>.000001 then local n=math.sqrt(v.x*v.x+v.z*v.z);self.aims[id]={x=v.x/n,z=v.z/n}end
 end
 function w:campaignRelease()end
 function w:campaignObject(id,kind,p)self.objects[id]={kind=kind,position=table.clone(p)}end
 function w:campaignRemove(id)self.objects[id]=nil end
 function w:stage()end
 function w:progress()end
 function w:reached()return false end
 function w:atExit()return false end
 function w:enemyIdentity()end
 function w:enemyHealth()end
 function w:campaignWalkSpeed(id,speed)self.groundSpeeds=self.groundSpeeds or {};self.groundSpeeds[id]=speed end
 function w:enemyMove(id,target,speed)local p,q=self.positions[id],self.positions[target];local dx,dz=q.x-p.x,q.z-p.z;local n=math.max(1,math.sqrt(dx*dx+dz*dz));dx,dz=dx/n,dz/n
 for _,side in ipairs({0,.85,-.85})do local x,z=p.x+dx*3-dz*side,p.z+dz*3+dx*side;local safe=false;for _,f in ipairs(def.course.platforms)do if math.abs(x-f.x)<=f.w/2 and math.abs(z-f.z)<=f.d/2 and p.y+1-(f.y+f.h/2)>=0 and p.y+1-(f.y+f.h/2)<=6 then safe=true;break end end;if not safe then dx,dz=0,0;break end end
 self.groundInputs=self.groundInputs or {};self.groundInputs[id]={x=dx,z=dz,speed=speed}end
 function w:advanceGround(dt)for id,m in pairs(self.groundInputs or {})do local p=self.positions[id];local x,z=p.x+m.x*m.speed*dt,p.z+m.z*m.speed*dt;for _,f in ipairs(def.course.platforms)do if math.abs(x-f.x)<=f.w/2 and math.abs(z-f.z)<=f.d/2 then p.x,p.z,p.y=x,z,f.y+f.h/2+3;break end end end end
 function w:face(id,target)local p,q=self.positions[id],self.positions[target];local dx,dz=q.x-p.x,q.z-p.z;local n=math.sqrt(dx*dx+dz*dz);self.aims[id]={x=n>0 and dx/n or 1,z=n>0 and dz/n or 0}end
 function w:aim(id,x,z)self.aims[id]={x=x,z=z}end
 function w:cue()end
 function w:projectile()end
 function w:removeProjectile()end
 function w:placeActor(id,p)self.positions[id]=table.clone(p);return true end
 function w:move(id,x,z,run)if id<0 then self.groundInputs=self.groundInputs or {};self.groundInputs[id]={x=x,z=z,speed=4};return end;if id>0 and self.campaignModes then self.campaignModes:move(id,x,z,run)end end
 function w:jump(id)if self.campaignModes then self.campaignModes:jump(id)end end
 function w:targets(id,shape)
  local out={};local p=self.positions[id];local a=self.aims[id]or{x=1,z=0}
  for other,q in pairs(self.positions)do if other~=id and self.actors[other]and self.actors[other].alive then local dx,dz=q.x-p.x,q.z-p.z;local front=dx*a.x+dz*a.z;local side=dx*-a.z+dz*a.x
   if front>=0 and front<=shape.reach and math.abs(side)<=shape.width and math.abs(q.y-p.y)<=shape.height then out[#out+1]=other end
  end end;table.sort(out);return out
 end
 function w:impulse(id,attacker,tuning,profile,direction)
  self.impulses+=1;if id>0 and self.campaignModes then local n=direction or self.aims[attacker];if n then self.campaignModes:impulse(id,{x=n.x*tuning.horizontal,y=tuning.vertical,z=n.z*tuning.horizontal})end end
 end
 local cfg=GameConfig(Base,def);local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'ice19-npc-'..seed,w);s:step(0)
 local d=CampaignDirector.new(s,w,Combat,cfg,{Director=Director,CampaignModes=Modes,CampaignEnemies=Families})
 local oldHit=s._hit;s._hit=function(self,attacker,target,action,tuning)if target<0 then return d:hit(attacker,target,action,tuning)end;return oldHit(self,attacker,target,action,tuning)end
 s.contextualAttack=function(slot,now,action)return d:interact(slot,now,action)end;SourceCombat.bind(s,d,cfg)
 return def,s,d,w
end
local function send(s,p,now)
 local h=s.state.heroes[1];local packet={runId=s.state.runId,levelEpoch=s.state.levelEpoch,actorId=h.actorId,attempt=h.attempt,connectionEpoch=h.connectionEpoch,seq=(s.lastSeq[1]or 0)+1}
 for k,v in pairs(p)do packet[k]=v end;return s:intent(1,packet,now)
end

return {new=fixture,send=send}
