local run=require('./fixture')
local baseline=require('./baseline-policy')
local o=run(baseline,1158731273,.133,100,{packetDelay=.133,firstBody=true})
print('RESULT',o.result,o.elapsed,o.hero.attempt,o.hero.respawns,o.rawLife)
local shark,gear=0,0
local firstGear,lastShark
for _,e in ipairs(o.events)do
 if e.kind=='Hit' then
  print('HIT',e.now,e.data.attacker,e.data.action,e.data.before,e.data.after)
  if e.data.attacker==-4 then shark+=1;lastShark=e.now end
 end
 if e.kind=='CampaignHazardHit' then
  print('HAZARD',e.now,e.data.kind)
  if e.data.kind=='Gear' then gear+=1;firstGear=firstGear or e.now end
 end
end
assert(o.result=='FirstBodyEnded' and shark==1 and gear==1 and o.rawLife==0 and firstGear<lastShark,'Frozen negative counterexample changed')
print('PASS observed queued Gear then Shark negative control; NOT native ordering or acceptance')
