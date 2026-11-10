local Fixture=require('./fixture-preemptive')
local Pilot=require('./baseline-combat')
local Foot=require('./actual-foot')
for _,preDeaths in ipairs({0,2})do
for _,delay in ipairs({0,.133})do
 local f=Fixture.new(preDeaths);local s,w,b=f.session,f.world,f.boss;local now,nextPlan=f.base,f.base;local pending={};local seq=f.preSeq;local latch=nil;local strategies={preempt=0,evade=0,safeHold=0,boundaryHold=0};local dt=1/120;local rejects={}
 assert(b.enemies[-99].rawLife==255 and b.enemies[-99].progress==0 and b.state=='Ready','Natural source constructor, no prepared phase/HP')
 assert(s.combat[1].rawLife==47 and s.state.heroes[1].attempt==1+preDeaths and s.state.heroes[1].respawns==3-preDeaths,'Only normal pre-test Fall/respawn changes resources')
 local oldRecord=s._record
 function s:_record(kind,id,data,at)
  oldRecord(self,kind,id,data,at)
  if kind=='Hit'or kind=='ConfirmedDeath'then
   local p=w:position(1);local v=w.vel[1];local m=w.inputs[1];local a=b.attack
   print('STRATEGY_EVENT',preDeaths,delay,now-f.base,kind,data.action or data.reason or'',data.before or-1,data.after or-1,b.state,b.attackSerial,p.x,p.y,p.z,v.x,v.y,v.z,m.x,m.z,m.run,a and a.aim.x or 0,a and a.aim.z or 0)
  end
 end
 local function send(kind,extra,token)
  seq+=1;local h=token;local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=h.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
  for k,v in pairs(extra or{})do p[k]=v end;local code=s:intent(1,p,now);if code~='OK'then rejects[code]=(rejects[code]or 0)+1 end;return code
 end
 while now-f.base<600 and not b.defeated and s.state.status~='Lost'do
  while pending[1]and pending[1].at<=now+1e-8 do local q=table.remove(pending,1);send('Move',{x=q.p.x,z=q.p.z,run=q.p.run},q.token);if q.p.jump then send('Jump',nil,q.token)end;if q.p.primary then send('Attack',{attack='Punch'},q.token)end end
  if now>=nextPlan and s.state.heroes[1].status=='Alive'and not s.combat[1].deathAt then
   local c={slot=1,now=now,dt=.133,definition=f.definition,world=w,session=s,director=f.director,modes=f.modes,actor=f.actor,position=w:position(1),stageToken='boss10'}
   local tactical=Pilot.plan(c)
   local body,combat,p,q=w.actors[1],s.combat[1],w:position(1),w:position(-99)
   local grounded=body.humanoid.FloorMaterial~='Air'and not body.humanoid.PlatformStand
   local preempt=b.state=='Ready'and b.attackSerial%2==1 and b.readyAt-now<=.35
   local attack=b.attack
   if grounded and not combat.attack and not combat.reactionEnd and(preempt or b.state=='Tell'or b.state=='Active')then
    local ax,az,serial
    if preempt then ax,az=p.x-q.x,p.z-q.z;serial=b.attackSerial+1
    else ax,az=attack.aim.x,attack.aim.z;serial=b.attackSerial end
    local n=math.max(.001,math.sqrt(ax*ax+az*az));ax,az=ax/n,az/n
    local sx,sz=-az,ax
    local function clearance(x,z)
     local a=b.arena;local result=math.huge
     if x>0 then result=math.min(result,(a.maxX-1-p.x)/x)elseif x<0 then result=math.min(result,(a.minX+1-p.x)/x)end
     if z>0 then result=math.min(result,(a.maxZ-1-p.z)/z)elseif z<0 then result=math.min(result,(a.minZ+1-p.z)/z)end
     return math.max(0,result)
    end
    if not latch or latch.serial~=serial then
     local plus,minus=clearance(sx,sz),clearance(-sx,-sz);local sign=plus>=minus and 1 or-1
     local v=w.vel[1];local momentum=v.x*sx+v.z*sz
     if preempt and math.abs(momentum)>1 and plus>10 and minus>10 then sign=momentum>0 and 1 or-1 end
     latch={serial=serial,sign=sign,x=sx*sign,z=sz*sign}
    elseif preempt then
     if sx*latch.x+sz*latch.z<0 then sx,sz=-sx,-sz end
     latch.x,latch.z=sx,sz
    else
     if sx*latch.x+sz*latch.z<0 then sx,sz=-sx,-sz end
     latch.x,latch.z=sx,sz
    end
    local safe=false
    if not preempt then
     local origin=attack.origin;local front=(p.x-origin.x)*ax+(p.z-origin.z)*az
     local side=math.abs((p.x-origin.x)*-az+(p.z-origin.z)*ax)
     local m=attack.move;local extent=m.reach or(m.speed*m.active*(b:_phase()==2 and 1.2 or 1))
     safe=side>(m.width or m.radius)+3 or front< -3 or front>extent+5
    end
    tactical={x=latch.x,z=latch.z,run=true,primary=false,jump=false,evasion=true}
    if safe then tactical.x,tactical.z=0,0;strategies.safeHold+=1
    elseif clearance(latch.x,latch.z)<24*(delay+.133+.025)then tactical.x,tactical.z=0,0;strategies.boundaryHold+=1
    elseif preempt then strategies.preempt+=1 else strategies.evade+=1 end
   end
   local out=Foot.foot(c,w:position(-99),tactical)
   assert(out==tactical,'Finished Race body uses actual foot early return, not grounded forced-walk composition')
   local h=s.state.heroes[1]
   pending[#pending+1]={at=now+delay,p=out,token={actorId=h.actorId,attempt=h.attempt,connectionEpoch=h.connectionEpoch,levelEpoch=s.state.levelEpoch}};nextPlan=now+.133
  end
  now+=dt;f.advance(dt,now);s:step(now);b:step(now,dt)
 end
 local hits,accepted,bhits,underflows=0,0,0,0
 for _,e in ipairs(s.logs)do if e.kind=='Hit'then hits+=1 elseif e.kind=='AttackAccepted'then accepted+=1 elseif e.kind=='CampaignBossHit'then bhits+=1;if e.data.underflow then underflows+=1 end end end
 print('WHOLE_PREEMPTIVE delay',delay,'result',b.defeated and'Won'or s.state.status,'elapsed',now-f.base,'bossLife',b.enemies[-99].rawLife,'progress',b.enemies[-99].progress,'phase',b:snapshot().bossPhase,'heroLife',s.combat[1].rawLife,'attempt',s.state.heroes[1].attempt,'stock',s.state.heroes[1].respawns,'heroHits',hits,'preDeaths',preDeaths,'prepFalls',f.prepFalls,'preemptPlans',strategies.preempt,'evadePlans',strategies.evade,'safeHolds',strategies.safeHold,'boundaryHolds',strategies.boundaryHold,'acceptedPrimary',accepted,'bossHits',bhits,'underflows',underflows)
 for code,n in pairs(rejects)do print('INPUT_RECEIPT',delay,code,n)end
 assert(not rejects.RATE_LIMIT and not rejects.INVALID_INTENT and not rejects.OUT_OF_ORDER,'Normal source input validity/rate remains enforced')
end

end
