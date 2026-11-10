-- Original Session/Modes/NPC source. Delivery precedes planning, then physics.
local Fixture=require('./npc-fixture')
local Pilot=require('./baseline-policy')
local failures=0
for _,cadence in ipairs({.133,.167,.2})do for _,hold in ipairs({.133,.167,.2})do
 local def,s,d,w=Fixture.new(1158731273);local m=d.modes;local now,nextPlan=0,0
 local original=s.state.heroes[1].actorId;local pending={};local serial,accepted=0,0;local hits={};local ring={}
 local oldImpulse=w.impulse
 function w:impulse(id,attacker,...)
  local a=m.actors[1];hits[#hits+1]={at=now,attacker=attacker,x=a.position.x,y=a.position.y,z=a.position.z}
  return oldImpulse(self,id,attacker,...)
 end
 while now<40 and not m.complete and s.state.heroes[1].status=='Alive'and s.state.heroes[1].attempt==1 and not s.combat[1].deathAt do
  -- A newer urgent Move/Jump supersedes older unsent regular movement. Its
  -- sequence must never let a stale delayed plan overwrite the newer one.
  table.sort(pending,function(a,b)return a.at==b.at and a.serial<b.serial or a.at<b.at end)
  while pending[1]and pending[1].at<=now+1e-8 do
   local q=table.remove(pending,1)
   if q.serial>accepted then
    accepted=q.serial
    Fixture.send(s,{kind='Move',x=q.x,z=q.z,run=q.run},now)
    if q.jump then Fixture.send(s,{kind='Jump'},now)end
   end
  end
  if now+1e-8>=nextPlan then
   local a=m.actors[1];local out=Pilot.plan({definition=def,modes=m,actor=a,slot=1,world=w,director=d,session=s,now=now,dt=cadence,stageToken='ice20-queued'})
   local n=math.max(1,math.sqrt(out.x*out.x+out.z*out.z));serial+=1
   pending[#pending+1]={serial=serial,at=now+(out.jump and 2/60 or hold),x=out.x/n,z=out.z/n,run=out.run,jump=out.jump}
   ring[#ring+1]={at=now,x=a.position.x,y=a.position.y,z=a.position.z,vx=a.velocity.x,vy=a.velocity.y,vz=a.velocity.z,jump=out.jump,xInput=out.x,zInput=out.z,support=a.support}
   if #ring>14 then table.remove(ring,1)end
   nextPlan=now+cadence
  end
  now+=1/60;s:step(now);d:step(now,1/60);w:advanceGround(1/60)
 end
 local hero=s.state.heroes[1];local okay=m.complete and hero.actorId==original and hero.attempt==1 and hero.respawns==3 and not s.combat[1].deathAt
 if not okay then failures+=1 end
 print((okay and'PASS'or'FAIL')..' QueuedIce cadence='..cadence..' hold='..hold..' time='..now..' Life='..s.combat[1].rawLife..' hits='..#hits)
 if not okay then
  for _,e in ipairs(s.logs)do if e.kind=='CampaignHazardHit'then print(' HAZARD',e.now,e.data.kind)end end
  for _,h in ipairs(hits)do print(' HIT',h.at,h.attacker,h.x,h.y,h.z)end
  for _,f in ipairs(ring)do print(' FRAME',f.at,f.x,f.y,f.z,f.vx,f.vy,f.vz,f.support,f.jump,f.xInput,f.zInput)end
 end
end end
print('TOTAL_FAILURES',failures)
