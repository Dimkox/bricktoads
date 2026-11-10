local Fixture=require('./queen-fixture')
local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Foot=require('./queen-foot')
for _,delay in ipairs({0,.133})do
 local f=Fixture.new(0);local s,w,b=f.session,f.world,f.boss;local now,nextPlan=f.base,f.base;local pending={};local seq=0;local dt=1/120;local rejects={};local latch=nil
 assert(b.enemies[-99].rawLife==15 and b.enemies[-99].progress==0 and b.state=='Ready','Natural source constructor, no prepared phase/HP')
 assert(s.combat[1].rawLife==47 and s.state.heroes[1].attempt==1 and s.state.heroes[1].respawns==3,'Fresh natural Session resources')
 local function send(kind,extra,token)
  seq+=1;local h=token;local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=h.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
  for k,v in pairs(extra or{})do p[k]=v end;local code=s:intent(1,p,now);if code~='OK'then rejects[code]=(rejects[code]or 0)+1 end;return code
 end
 while now-f.base<300 and not b.defeated and s.state.status~='Lost'do
  while pending[1]and pending[1].at<=now+1e-8 do local q=table.remove(pending,1);send('Move',{x=q.p.x,z=q.p.z,run=q.p.run},q.token);if q.p.jump then send('Jump',nil,q.token)end;if q.p.primary then send('Attack',{attack='Punch'},q.token)end end
  if now>=nextPlan and s.state.heroes[1].status=='Alive'and not s.combat[1].deathAt then
   local c={slot=1,now=now,dt=.133,definition=f.definition,world=w,session=s,director=f.director,modes=f.modes,actor=f.actor,position=w:position(1),stageToken='queen13'}
   local tactical=Pilot.plan(c)
   local p,q=w:position(1),w:position(-99);local body=w.actors[1];local combat=s.combat[1]
   local preempt=b.state=='Ready'and b.readyAt-now<=.35
   local active=b.state=='Tell'or b.state=='Active'
   if not combat.attack and not combat.reactionEnd and body.humanoid.FloorMaterial~='Air'and not body.humanoid.PlatformStand and(preempt or active)then
    local a=b.attack;local name=preempt and(b.attackSerial%2==0 and'Sweep'or'Spin')or a.name
    local serial=preempt and b.attackSerial+1 or b.attackSerial
    local origin=preempt and q or a.origin
    local identity=s.state.heroes[1].actorId..':'..serial..':'..name
    local function unit(x,z)local n=math.max(.001,math.sqrt(x*x+z*z));return x/n,z/n end
    local function available(o,x,z)
     local v=math.huge;local r=b.arena
     if x>0 then v=math.min(v,(r.maxX-1-o.x)/x)elseif x<0 then v=math.min(v,(r.minX+1-o.x)/x)end
     if z>0 then v=math.min(v,(r.maxZ-1-o.z)/z)elseif z<0 then v=math.min(v,(r.minZ+1-o.z)/z)end
     return math.max(0,v)
    end
    local safe=false;local x,z=0,0
    if name=='Sweep'then
     local ax,az;if preempt then ax,az=unit(p.x-q.x,p.z-q.z)else ax,az=a.aim.x,a.aim.z end
     local sx,sz=-az,ax
     if not latch or latch.identity~=identity then
      local plus,minus=available(p,sx,sz),available(p,-sx,-sz);local sign=plus>=minus and 1 or-1
      local v=w.vel[1];local momentum=v.x*sx+v.z*sz
      if preempt and math.abs(momentum)>1 and plus>10 and minus>10 then sign=momentum>0 and 1 or-1 end
      latch={identity=identity,x=sx*sign,z=sz*sign}
     else if sx*latch.x+sz*latch.z<0 then sx,sz=-sx,-sz end;latch.x,latch.z=sx,sz end
     if not preempt then
      local front=(p.x-origin.x)*ax+(p.z-origin.z)*az
      local side=math.abs((p.x-origin.x)*az-(p.z-origin.z)*ax)
      safe=side>7 or front< -3 or front>13
     end
     if not safe and available(p,latch.x,latch.z)>=24*(delay+.133+.025)then x,z=latch.x,latch.z end
    else
     if not latch or latch.identity~=identity then
      local ax,az=unit(p.x-origin.x,p.z-origin.z);local best=math.huge
      for _,axis in ipairs({{ax,az},{1,0},{-1,0},{0,1},{0,-1}})do
       if available(origin,axis[1],axis[2])>=16 then
        local gx,gz=origin.x+axis[1]*16,origin.z+axis[2]*16
        local cost=(gx-p.x)^2+(gz-p.z)^2
        if cost<best then best=cost;latch={identity=identity,x=axis[1],z=axis[2]}end
       end
      end
     end
     local distance=math.sqrt((p.x-origin.x)^2+(p.z-origin.z)^2)
     safe=distance>=14.2
     if not safe and latch and latch.identity==identity then
      x,z=unit(origin.x+latch.x*16-p.x,origin.z+latch.z*16-p.z)
      if available(p,x,z)<24*(delay+.133+.025)then x,z=0,0 end
     end
    end
    tactical={x=x,z=z,run=true,primary=false,jump=false,evasion=true}
   end
   local out=Foot.foot(c,w:position(-99),tactical)
   assert(out==tactical,'Prepared finished Finale observation uses actual foot early return, not grounded forced-walk composition')
   local h=s.state.heroes[1]
   pending[#pending+1]={at=now+delay,p=out,token={actorId=h.actorId,attempt=h.attempt,connectionEpoch=h.connectionEpoch,levelEpoch=s.state.levelEpoch}};nextPlan=now+.133
  end
  now+=dt;f.advance(dt,now);s:step(now);b:step(now,dt)
 end
 assert(s.state.heroes[1].attempt<=4 and s.state.heroes[1].respawns>=0,'Original normal resource budget')
 local heroDeaths,appearances=0,0
 for _,e in ipairs(s.logs)do if e.kind=='ConfirmedDeath'then heroDeaths+=1 elseif e.kind=='CommitSpawn'then appearances+=1 end end
 assert(s.state.heroes[1].attempt==appearances and s.state.heroes[1].respawns==4-appearances,'Only committed source appearances spend reserves')
 assert(heroDeaths>=appearances-1 and heroDeaths<=appearances,'Final elimination grants no replacement')
 local hits,accepted,bhits,underflows=0,0,0,0
 for _,e in ipairs(s.logs)do if e.kind=='Hit'then hits+=1 elseif e.kind=='AttackAccepted'then accepted+=1 elseif e.kind=='CampaignBossHit'then bhits+=1;if e.data.underflow then underflows+=1 end end end
 print('QUEEN13_ONE_STRATEGY delay',delay,'result',b.defeated and'Won'or s.state.status,'elapsed',now-f.base,'bossLife',b.enemies[-99].rawLife,'progress',b.enemies[-99].progress,'phase',b:snapshot().bossPhase,'heroLife',s.combat[1].rawLife,'attempt',s.state.heroes[1].attempt,'stock',s.state.heroes[1].respawns,'heroHits',hits,'acceptedPrimary',accepted,'bossHits',bhits,'underflows',underflows,'confirmedDeaths',heroDeaths)
 for code,n in pairs(rejects)do print('INPUT_RECEIPT',delay,code,n)end
 assert(not rejects.RATE_LIMIT and not rejects.INVALID_INTENT and not rejects.OUT_OF_ORDER,'Normal source input validity/rate remains enforced')
end
