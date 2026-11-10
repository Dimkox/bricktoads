local Fixture=require('./fixture')
local Pilot=require('../../tools/qa/campaign_early_course_pilot')
local failures=0
for _,seed in ipairs({1006313601,1,41})do
 for _,cadence in ipairs({.1,.133,.167})do
 for _,delay in ipairs({0,.133})do
  local def,s,d,w=Fixture.new(seed);local now,nextPlan,inputs=0,0,0;local m=d.modes
  local hero=s.state.heroes[1];local actorId=hero.actorId;local pending={}
  assert(#def.zones[1].enemies==10,'All authored NPCs must exist')
  while now<30 and not m.complete and hero.status=='Alive'and hero.attempt==1 and not s.combat[1].deathAt do
   if now>=nextPlan then
    local out=Pilot.plan({definition=def,modes=m,actor=m.actors[1],slot=1,world=w,director=d,session=s,now=now,dt=cadence,stageToken='rope-patrol-'..seed..'-'..cadence})
    local n=math.max(1,math.sqrt(out.x*out.x+out.z*out.z))
    pending[#pending+1]={at=now+delay,x=out.x/n,z=out.z/n,run=out.run}
    assert(not out.jump and not out.primary,'Focused patrol uses only ordinary Move')
    inputs+=1;nextPlan=now+cadence
   end
   while pending[1] and pending[1].at<=now+1e-8 do local move=table.remove(pending,1);local code=Fixture.send(s,{kind='Move',x=move.x,z=move.z,run=move.run},now);assert(code=='OK' or code=='REACTION','Only valid ordinary Move or reaction refusal: '..tostring(code))end
   now+=1/60;s:step(now);d:step(now,1/60)
  end
  local hits={};for _,e in ipairs(s.logs)do if e.kind=='Hit'then hits[#hits+1]={at=e.now,action=e.data.action,attacker=e.data.attacker,before=e.data.before,after=e.data.after}end end
  local okay=m.complete and hero.status=='Alive'and hero.actorId==actorId and hero.attempt==1 and hero.respawns==3 and s.combat[1].rawLife>=31 and not s.combat[1].deathAt
  if not okay then failures+=1 end
  print((okay and'PASS'or'FAIL')..' Rope seed'..seed..' cadence'..cadence..' delay'..delay..' time'..string.format('%.3f',now)..' Life'..s.combat[1].rawLife..' attempt'..hero.attempt..' stock'..hero.respawns..' hits'..#hits..' Move'..inputs..' xyz'..m.actors[1].position.x..','..m.actors[1].position.y..','..m.actors[1].position.z)
  for _,hit in ipairs(hits)do print(' HIT',hit.at,hit.attacker,hit.action,hit.before,hit.after)end
 end
 end
end
assert(failures==0,tostring(failures)..' original-body Rope failures')
