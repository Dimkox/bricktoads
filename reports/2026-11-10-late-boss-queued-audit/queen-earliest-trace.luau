local Fixture=require('./queen-fixture')
local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Foot=require('./queen-foot')
for _,delay in ipairs({0,.133})do
 local f=Fixture.new(0);local s,w,b=f.session,f.world,f.boss;local now,nextPlan=f.base,f.base;local pending={};local seq=0;local dt=1/120;local rejects={}
 assert(b.enemies[-99].rawLife==15 and b.enemies[-99].progress==0 and b.state=='Ready','Natural source constructor, no prepared phase/HP')
 assert(s.combat[1].rawLife==47 and s.state.heroes[1].attempt==1 and s.state.heroes[1].respawns==3,'Fresh natural Session resources')
 local firstHit=false;local ring={};local oldRecord=s._record
 function s:_record(kind,id,data,at)
  oldRecord(self,kind,id,data,at)
  if kind=='Hit'and not firstHit then
   firstHit=true;local a=b.attack;local v=w.vel[1];local m=w.inputs[1];local h=w:position(1);local bp=w:position(-99)
   print('FIRST_QUEEN_HIT',delay,now-f.base,data.action,b.state,b.attackSerial,'hero',h.x,h.y,h.z,'boss',bp.x,bp.y,bp.z,'velocity',v.x,v.y,v.z,'accepted',m.x,m.z,m.run,'acceptedAt',m.at-f.base)
   if a then print('ATTACK_CLOCK',a.name,a.tellAt-f.base,a.activeUntil-f.base,'origin',a.origin.x,a.origin.z,'aim',a.aim.x,a.aim.z)end
   for _,r in ipairs(ring)do print('BEFORE_HIT',r.at,r.state,r.attack,r.x,r.z,r.bx,r.bz,r.vx,r.vz,r.px,r.pz,r.run,r.ix,r.iz,r.irun,r.issued)end
  end
 end
 local function send(kind,extra,token)
  seq+=1;local h=token;local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=h.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
  for k,v in pairs(extra or{})do p[k]=v end;local code=s:intent(1,p,now);if code~='OK'then rejects[code]=(rejects[code]or 0)+1 end;return code
 end
 while now-f.base<300 and not b.defeated and s.state.status~='Lost'do
  while pending[1]and pending[1].at<=now+1e-8 do local q=table.remove(pending,1);send('Move',{x=q.p.x,z=q.p.z,run=q.p.run},q.token);if q.p.jump then send('Jump',nil,q.token)end;if q.p.primary then send('Attack',{attack='Punch'},q.token)end end
  if now>=nextPlan and s.state.heroes[1].status=='Alive'and not s.combat[1].deathAt then
   local c={slot=1,now=now,dt=.133,definition=f.definition,world=w,session=s,director=f.director,modes=f.modes,actor=f.actor,position=w:position(1),stageToken='queen13'}
   local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)
   local p1,bp,v,m=w:position(1),w:position(-99),w.vel[1],w.inputs[1]
   ring[#ring+1]={at=now-f.base,state=b.state,attack=b.attack and b.attack.name,x=p1.x,z=p1.z,bx=bp.x,bz=bp.z,vx=v.x,vz=v.z,px=out.x,pz=out.z,run=out.run,ix=m.x,iz=m.z,irun=m.run,issued=m.at-f.base}
   if #ring>8 then table.remove(ring,1)end
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
 print('QUEEN13_BASELINE delay',delay,'result',b.defeated and'Won'or s.state.status,'elapsed',now-f.base,'bossLife',b.enemies[-99].rawLife,'progress',b.enemies[-99].progress,'phase',b:snapshot().bossPhase,'heroLife',s.combat[1].rawLife,'attempt',s.state.heroes[1].attempt,'stock',s.state.heroes[1].respawns,'heroHits',hits,'acceptedPrimary',accepted,'bossHits',bhits,'underflows',underflows,'confirmedDeaths',heroDeaths)
 for code,n in pairs(rejects)do print('INPUT_RECEIPT',delay,code,n)end
 assert(not rejects.RATE_LIMIT and not rejects.INVALID_INTENT and not rejects.OUT_OF_ORDER,'Normal source input validity/rate remains enforced')
end
