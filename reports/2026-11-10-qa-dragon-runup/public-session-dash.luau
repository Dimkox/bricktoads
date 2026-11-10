local Flight=require('../../src/server/gameplay/DragonFlight')
local Director=require('../../src/server/gameplay/LevelDirector')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),require('../../src/server/gameplay/LevelDefinition'))
local FakeWorld=require('../../tests/stand/FakeWorld')
local SourceCombat=require('../../src/server/gameplay/SourceCombat')
local Pilot=require('../../tools/qa/campaign_combat_pilot')
    local function fixture()
        local w=FakeWorld.new();w.positions={[1]={x=265.2443542480469,y=4.974132537841797,z=.7214843034744263},[2]={x=-50,y=3,z=0}};w.grounded={};w.links={};w.shots={}
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
        local cfg=table.clone(Config);cfg.Level={zones={{enemies={{id=-1,kind='Dragon',x=272.2443542480469,y=6.632584571838379,z=.7214843034744263,rawLife=47},
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

-- Prepared canonical Session/Dragon fixture. The numeric world supplies a
-- physical run observation after accepted Move. This is not native physics,
-- AI-survival, or a continuous-playthrough claim; actor poses remain arranged
-- at fixture construction and resources are never assigned by the driver.
local d,s,w=fixture()
local h=s.state.heroes[1];local identity,attempt,stock,life=h.actorId,h.attempt,h.respawns,s.combat[1].rawLife
assert(attempt==1 and stock==3 and life==47 and d.enemies[-1].rawLife==47)
local actor=w.actors[1];actor.root={Parent=true,Anchored=false,AssemblyLinearVelocity={X=0,Y=0,Z=0},CFrame={LookVector={X=1,Z=0}}}
actor.locomotion={runRequested=false,groundRun=false,at=0}
actor.humanoid={Health=100,PlatformStand=false,FloorMaterial='Slate'}
actor.model={GetAttribute=function(_,key)return key=='MovementMode'and(actor.locomotion.groundRun and'Run'or'Walk')or nil end}
function w:move(slot,x,z,run)
 self.moves=self.moves+1;self.lastMove={slot,x,z,run}
 local body=self.actors[slot];if not body or not body.root then return end
 local n=math.sqrt(x*x+z*z);if n>1 then x,z=x/n,z/n end
 local speed=run and Config.Movement.heroRunSpeed or Config.WalkSpeed
 body.root.AssemblyLinearVelocity={X=x*speed,Y=0,Z=z*speed}
 body.locomotion={runRequested=run==true,groundRun=run==true and n>0,at=s.now}
end
function w:isRunning(slot)
 local a=self.actors[slot];local v=a.root.AssemblyLinearVelocity
 return a.locomotion.runRequested and a.locomotion.groundRun and not a.root.Anchored
  and not a.humanoid.PlatformStand and a.humanoid.FloorMaterial~='Air'
  and math.sqrt(v.X*v.X+v.Z*v.Z)>=Config.Movement.heroRunSpeed*Config.Movement.runThresholdRatio
end
-- Same front/side/vertical scalar geometry as RobloxWorld:targets; no ray
-- blocker is present in this deliberately clear numeric fixture.
function w:targets(slot,cfg)
 local p,q=self.positions[slot],self.positions[-1];if slot~=1 or not p or not q then return{}end
 local dx,dy,dz=q.x-p.x,q.y-p.y,q.z-p.z
 self.geometryObserved={front=dx,side=dz,height=dy,bound=cfg.height}
 return dx>=0 and dx<=cfg.reach and math.abs(dz)<=cfg.width and math.abs(dy)<=cfg.height and{-1}or{}
end
local function send(kind,extra,now)
 local packet={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,
  connectionEpoch=h.connectionEpoch,seq=(s.lastSeq[1]or 0)+1}
 for k,v in pairs(extra or{})do packet[k]=v end;return s:intent(1,packet,now)
end
assert(send('Move',{x=1,z=0,run=true},1)=='OK' and w:isRunning(1),'Normal accepted Run must precede the attack')
local plan=Pilot.plan({slot=1,now=1.01,session=s,director=d,world=w,definition=d.route,dt=.133})
assert(plan.primary and plan.run,'Observed grounded run at reachable Dragon height selects ordinary primary')
assert(send('Move',{x=plan.x,z=plan.z,run=plan.run},1.01)=='OK')
assert(send('Attack',{attack='Punch'},1.01)=='OK','Only public Punch is submitted')
local accepted;for _,e in ipairs(s.logs)do if e.kind=='AttackAccepted'then accepted=e.data end end
assert(accepted and accepted.action=='Dash' and accepted.inputAction=='Punch','Session selects Dash, never a custom attack packet')
d.now=1.20;s:step(1.20)
assert(w.geometryObserved.height>1.65 and w.geometryObserved.height<1.66 and w.geometryObserved.bound==Config.Attacks.Dash.height)
assert(d.enemies[-1].rawLife==31 and d.enemies[-1].heavyReaction,'Accepted Dash at real dy1.658 preserves source47to31 heavy response')
assert(h.actorId==identity and h.attempt==attempt and h.respawns==stock and s.combat[1].rawLife==life,'Original actor/Life/attempt/stock remain unchanged')
print('PASS public Session ordinary Run -> Punch -> Dash at dy1.658; enemy47to31, hero47/attempt1/stock3')
