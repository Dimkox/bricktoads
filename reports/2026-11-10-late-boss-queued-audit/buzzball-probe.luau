-- Whole prepared Buzzball battle. No chase, course or full campaign claim.
local Fixture=require('./buzzball-fixture')
local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Foot=require('./buzzball-foot')
for _,delay in ipairs({0,.133})do
 local f=Fixture.new(0);local s,w,b=f.session,f.world,f.boss
 local now,nextPlan=f.base,f.base;local pending={};local seq=f.preSeq;local dt=1/120;local rejects={};local phases={}
 local initial=s.state.heroes[1];local initialActor=initial.actorId
 assert(b.kind=='Buzzball'and b.state=='Ready'and b.enemies[-99].rawLife==207 and b.enemies[-99].progress==nil)
 assert(s.combat[1].rawLife==47 and initial.attempt==1 and initial.respawns==3 and f.prepFalls==0)
 local function send(kind,extra,token)
  seq+=1;local p={kind=kind,runId=s.state.runId,actorId=token.actorId,attempt=token.attempt,
   levelEpoch=token.levelEpoch,connectionEpoch=token.connectionEpoch,seq=seq}
  for k,v in pairs(extra or{})do p[k]=v end
  local code=s:intent(1,p,now);if code~='OK'then rejects[code]=(rejects[code]or 0)+1 end
 end
 while now-f.base<300 and not b.defeated and s.state.status~='Lost'do
  phases[b:snapshot().bossPhase]=true
  while pending[1]and pending[1].at<=now+1e-8 do
   local q=table.remove(pending,1);send('Move',{x=q.p.x,z=q.p.z,run=q.p.run},q.token)
   if q.p.jump then send('Jump',nil,q.token)end
   if q.p.primary then send('Attack',{attack='Punch'},q.token)end
  end
  local h=s.state.heroes[1]
  if now>=nextPlan and h.status=='Alive'and not s.combat[1].deathAt then
   local c={slot=1,now=now,dt=.133,definition=f.definition,world=w,session=s,director=f.director,
    modes=f.modes,actor=f.actor,position=w:position(1),stageToken='prepared-buzzball11'}
   local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)
   assert(out==tactical,'Actual finished-Clinger foot composition preserves Combat plan')
   pending[#pending+1]={at=now+delay,p=out,token={actorId=h.actorId,attempt=h.attempt,
    connectionEpoch=h.connectionEpoch,levelEpoch=s.state.levelEpoch}}
   nextPlan=now+.133
  end
  now+=dt;f.advance(dt,now);s:step(now);b:step(now,dt)
 end
 local hits,bhits,underflows,deaths,starts,defeats=0,0,0,0,0,0
 for _,e in ipairs(s.logs)do
  if e.kind=='Hit'then hits+=1
  elseif e.kind=='CampaignBossHit'then bhits+=1;if e.data.underflow then underflows+=1 end
  elseif e.kind=='ConfirmedDeath'then deaths+=1
  elseif e.kind=='BuzzballBattleStarted'then starts+=1
  elseif e.kind=='CampaignBossDefeated'then defeats+=1 end
 end
 local h=s.state.heroes[1];local living=h.status=='Alive'and not s.combat[1].deathAt
 local result=b.defeated and living and'Won'or(s.state.status=='Lost'and'Lost'or'Incomplete300')
 assert(starts==1,'Exactly one explicit normal prepared finishChase transition')
 assert(h.attempt>=1 and h.attempt<=4 and h.respawns>=0 and h.respawns<=3 and h.attempt+h.respawns==4,'Canonical global appearance budget')
 assert(b.enemies[-99].progress==nil,'Buzzball has no reaction-progress counter')
 if result=='Won'then assert(defeats==1 and underflows==1 and b.enemies[-99].rawLife==0,'Natural no-progress boss defeat arithmetic')end
 assert(not rejects.RATE_LIMIT and not rejects.INVALID_INTENT and not rejects.OUT_OF_ORDER,'Normal source input validity/rate remains enforced')
 print('BUZZBALL_WHOLE','delay',delay,'result',result,'elapsed',now-f.base,'bossLife',b.enemies[-99].rawLife,
  'bossDefeated',b.defeated,'phase1Seen',phases[1]==true,'phase2Seen',phases[2]==true,
  'heroLife',s.combat[1].rawLife,'attempt',h.attempt,'stock',h.respawns,'sameInitialActor',h.actorId==initialActor,
  'heroHits',hits,'deaths',deaths,'bossHits',bhits,'underflows',underflows,'preparedChaseTransitions',starts)
 for code,n in pairs(rejects)do print('BUZZBALL_INPUT',delay,code,n)end
end
