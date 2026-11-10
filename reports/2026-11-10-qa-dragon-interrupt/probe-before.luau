local Flight=require('../../src/server/gameplay/DragonFlight')
local Director=require('../../src/server/gameplay/LevelDirector')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),require('../../src/server/gameplay/LevelDefinition'))
local FakeWorld=require('../../tests/stand/FakeWorld')
local SourceCombat=require('../../src/server/gameplay/SourceCombat')
local Current=require('./combat-priority-03be')
local RejectedPriority=require('./combat-priority-03be')
    local function fixture()
        local w=FakeWorld.new();w.positions={[1]={x=284.7751159667969,y=3,z=5.169754505157471},[2]={x=-50,y=3,z=0}};w.grounded={};w.links={};w.shots={}
        function w:spawnEnemy(id,kind,p) self.actors[id]={id=id,kind=kind,alive=true};self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity() end
        function w:position(id) return self.positions[id] end
        function w:stage() end
        function w:progress(index,complete) self.progressComplete=complete end
        function w:reached() return false end
        function w:enemyHealth() end
        function w:cue() end
        function w:face() end
        function w:enemyMove() end
        function w:dragonGrounded(id) return self.grounded[id]~=false end
        function w:dragonFloor() return 3 end
        function w:dragonAscentBlocked(id,height)
            self.ascentHeight=height
            return self.motionFailure=='ASCENT_BLOCKED'
        end
        function w:dragonMotion(id,x,z,y,speed)
            self.motion={id=id,x=x,z=z,y=y,speed=speed}
            if self.motionFailure then return false,self.motionFailure end
            return true
        end
        function w:stopDragon(id) self.stopped=id end
        function w:dragonLink(id,slot,mode) if self.linkFails then return false end;self.links[slot]={id=id,mode=mode};return true end
        function w:dragonUnlink(slot) self.links[slot]=nil;return true end
        function w:dragonCanMount(slot,id,range) return not self.mountBlocked and math.abs(self.positions[id].x-self.positions[slot].x)<=range end
        function w:dragonMuzzle(id) local p=self.positions[id];return {x=p.x,y=p.y,z=p.z},{x=1,y=0,z=0},self.muzzleBlocked end
        function w:dragonFire(id,p) self.shots[id]=p end
        function w:removeDragonFire(id) self.shots[id]=nil end
        function w:dragonFireTargets(from,to,radius,exclude) self.segment={from=from,to=to,exclude=exclude};return self.fireVictims or {},self.wallHit==true end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'flight-test',w)
        s:step(0)
        local cfg=table.clone(Config);cfg.Level={zones={{enemies={{id=-1,kind='Dragon',x=289.2751159667969,y=4.5,z=5.169754505157471,rawLife=47},
            {id=-2,kind='Pig',x=-30,y=3,z=0,rawLife=31}},exit={}}}}
        s.config=cfg
        local d=Director.new(s,w,Combat,cfg,nil,nil,nil,nil,Flight)
        SourceCombat.bind(s,d,cfg)
        s.contextualAttack=function(slot,now,action) return d:interact(slot,now,action) end
        local hit=s._hit
        s._hit=function(self,a,b,action,tuning) if b<0 then return d:hit(a,b,action,tuning) end;return hit(self,a,b,action,tuning) end
        local seq={0,0}
        local function intent(now,kind,attack,slot)
            slot=slot or 1;seq[slot]+=1;local h=s.state.heroes[slot]
            local p={kind=kind or 'Attack',attack=attack or 'Punch',runId=s.state.runId,
                levelEpoch=s.state.levelEpoch,actorId=h.actorId,attempt=h.attempt,connectionEpoch=h.connectionEpoch,seq=seq[slot]}
            if kind=='Move' then p.attack=nil;p.x=1;p.z=0 elseif kind=='Jump' then p.attack=nil end
            return s:intent(slot,p,now)
        end
        local function tick(now,dt) d.now=now;s:step(now);d:step(now,dt or .05) end
        local function mount(now)
            now=now or 1
            assert(d:hit(2,-1,'HeroUppercut'));tick(now)
            assert(intent(now,'Attack')=='OK','Grounded disabled Dragon must be mountable through public F')
        end
        return d,s,w,tick,intent,mount
    end


local function trial(policy,delay)
 local d,s,w=fixture();local h=s.state.heroes[1]
 local heroId,attempt,stock=h.actorId,h.attempt,h.respawns
 local held={x=0,z=0,run=false};local dt=1/600
 for _,id in ipairs({1,-1})do local a=w.actors[id];a.root={Parent=true,Anchored=false,CFrame={LookVector={X=id==1 and 1 or-1,Z=0}},AssemblyLinearVelocity={X=0,Y=0,Z=0}};a.humanoid={Health=100,PlatformStand=false,FloorMaterial='Slate'}end
 local actor=w.actors[1];actor.locomotion={runRequested=false,groundRun=false,at=0};actor.model={GetAttribute=function(_,key)return key=='MovementMode'and(held.run and'Run'or'Walk')or nil end}
 function w:move(id,x,z,run)
  if id~=1 then return end
  held={x=x,z=z,run=run==true};local n=math.max(1,math.sqrt(x*x+z*z));local speed=held.run and 24 or 16
  actor.root.AssemblyLinearVelocity={X=x/n*speed,Y=0,Z=z/n*speed};actor.locomotion={runRequested=held.run,groundRun=held.run and x*x+z*z>0,at=s.now}
  if x*x+z*z>0 then actor.root.CFrame.LookVector={X=x/n,Z=z/n}end
 end
 function w:isRunning()local v=actor.root.AssemblyLinearVelocity;return held.run and math.sqrt(v.X*v.X+v.Z*v.Z)>=18 end
 function w:face(id,target)local p,q=self.positions[id],self.positions[target];local dx,dz=q.x-p.x,q.z-p.z;local n=math.sqrt(dx*dx+dz*dz);self.actors[id].root.CFrame.LookVector={X=dx/n,Z=dz/n}end
 function w:targets(id,cfg)
  local target=id==1 and -1 or 1;local p,q=self.positions[id],self.positions[target];local aim=self.actors[id].root.CFrame.LookVector
  local dx,dz=q.x-p.x,q.z-p.z;local front=dx*aim.X+dz*aim.Z;local side=dx*-aim.Z+dz*aim.X
  return front>=0 and front<=cfg.reach and math.abs(side)<=cfg.width and math.abs(q.y-p.y)<=cfg.height and{target}or{}
 end
 -- Numeric adapter advances only the hero's ordinary held motion. It omits
 -- native body collision, gravity, slope and knockback; those are NOT claimed.
 local function advance()local v=actor.root.AssemblyLinearVelocity;local p=w.positions[1];p.x+=v.X*dt;p.z+=v.Z*dt end
 local function send(kind,extra,now)
  local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=(s.lastSeq[1]or 0)+1}
  for k,v in pairs(extra or{})do p[k]=v end;return s:intent(1,p,now)
 end
 assert(send('Move',{x=1,z=0,run=true},3)=='OK');d:step(3,0)
 local enemy=d.enemies[-1];assert(enemy.windup and enemy.windup.action=='DragonHeadbutt' and math.abs(enemy.windup.at-3.35)<1e-9)
 local plan=policy.plan({slot=1,now=3,dt=.133,definition={zones={{platforms={{x=285,y=-1,z=5.17,w=90,h=2,d=50}}}}},session=s,director=d,world=w})
 local delivered=false
 for frame=1,360 do
  local now=3+frame*dt;advance();d.now=now;s:step(now)
  if not delivered and now>=3+delay then
   assert(send('Move',{x=plan.x,z=plan.z,run=plan.run},now)=='OK')
   if plan.primary then assert(send('Attack',{attack='Punch'},now)=='OK')end
   delivered=true
  end
  d:step(now,dt)
 end
 local hitCount,accepted,acceptedAt,enemyHitAt,heroHitAt=0,nil,nil,nil,nil
 for _,event in ipairs(s.logs)do if event.kind=='Hit' and event.data.attacker==-1 then hitCount+=1;heroHitAt=event.now end;if event.kind=='AttackAccepted'then accepted=event.data.action;acceptedAt=event.now end;if event.kind=='EnemyHit'and event.userId==-1 then enemyHitAt=event.now end end
 assert(h.actorId==heroId and h.attempt==attempt and h.respawns==stock and stock==3,'No lifecycle resource changes')
 return{hits=hitCount,life=s.combat[1].rawLife,enemy=enemy.rawLife,primary=plan.primary,accepted=accepted,acceptedAt=acceptedAt,enemyHitAt=enemyHitAt,heroHitAt=heroHitAt,plan=plan}
end
for _,delay in ipairs({.133,.15,.167})do
 local old,new=trial(RejectedPriority,delay),trial(Current,delay)
 print('DELAY',delay,'rejected03',old.hits,old.life,old.enemy,old.accepted,'candidate',new.hits,new.life,new.enemy,new.accepted,'acceptAt',new.acceptedAt,'enemyHitAt',new.enemyHitAt,'heroHitAt',old.heroHitAt)
 assert(new.hits==0 and new.life==47 and new.enemy==31 and new.accepted=='Dash','Candidate must retain a no-Hit normal source interrupt in every paired response case')
 if delay==.167 then assert(old.hits==1 and old.life==31 and old.enemy==47 and old.accepted==nil,'Rejected unconditional priority must reproduce the real Headbutt Hit')
  assert(new.hits==0,'QA priority must not discard a still-available normal Dash interrupt and take the Headbutt')end
end
