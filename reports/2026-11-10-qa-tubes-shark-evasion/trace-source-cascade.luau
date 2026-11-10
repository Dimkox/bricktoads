local run=require('./fixture')
local baseline=require('./baseline-policy')
local o=run(baseline,1158731273,.167,100,{packetDelay=0})
print('RESULT',o.result,o.elapsed,o.hero.attempt,o.hero.respawns,o.rawLife)
local sharkAt,cascade=false,false
for _,e in ipairs(o.events)do
 if e.kind=='Hit' then
  print('HIT',e.now,e.data.attacker,e.data.action,e.data.before,e.data.after)
  if e.data.attacker==-4 then sharkAt=e.now end
 end
 if e.kind=='CampaignHazardHit' then
  print('HAZARD',e.now,e.data.kind)
  if e.data.kind=='Gear' and sharkAt and e.now-sharkAt<2 then cascade=true end
 end
end
assert(cascade,'Frozen Shark then Gear source counterexample changed')
print('PASS observed unqueued Shark then Gear cascade after normal entry retry; no native replay claim')
