local run=require('./fixture')
local policy=require('./candidate-policy')
local failures=0
for _,cadence in ipairs({.1,.133,.167}) do
 for _,delay in ipairs({0,.133,.167}) do
  local o=run(policy,1158731273,cadence,100,{packetDelay=delay,firstBody=true})
  local shark,gear=0,0
  for _,e in ipairs(o.events)do
   if e.kind=='Hit' and e.data.attacker==-4 then shark+=1 end
   if e.kind=='CampaignHazardHit' and e.data.kind=='Gear' then gear+=1 end
  end
  print('CASE',cadence,delay,o.result,o.elapsed,o.hero.attempt,o.hero.respawns,o.rawLife,'Shark',shark,'Gear',gear)
  if o.result~='Won' or shark>0 or gear>0 then failures+=1 end
 end
end
print('FAILURES',failures)
assert(failures==0,'First body must finish without the Shark/Gear cascade')
