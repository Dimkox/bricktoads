local Fixture=require('./npc-fixture')
local Pilot=require('./candidate-policy')
local failures=0
for _,cadence in ipairs({.1,.133,.167})do for _,delay in ipairs({0,.5,1,1.5,2,2.5})do
 local def,s,d,w=Fixture.new(990047694);local m=d.modes;local now,nextPlan,inputs=0,delay,0
 local hero=s.state.heroes[1];local actorId=hero.actorId
 while now<40 and not m.complete and s.state.heroes[1].status=='Alive'and s.state.heroes[1].attempt==1 and not s.combat[1].deathAt do
  if now+1e-8>=nextPlan then
   local a=m.actors[1];local out=Pilot.plan({definition=def,modes=m,actor=a,slot=1,world=w,director=d,session=s,now=now,dt=cadence,stageToken='ice19-npc'})
   local n=math.max(1,math.sqrt(out.x*out.x+out.z*out.z))
   Fixture.send(s,{kind='Move',x=out.x/n,z=out.z/n,run=out.run},now)
   if out.jump then Fixture.send(s,{kind='Jump'},now)end
   if out.primary then Fixture.send(s,{kind='Attack',attack='Punch'},now)end
   inputs+=1;nextPlan=now+cadence
  end
  now+=1/60;s:step(now);d:step(now,1/60);w:advanceGround(1/60)
 end
 local hits={};for _,e in ipairs(s.logs)do if e.kind=='Hit'then hits[#hits+1]=e end end
 hero=s.state.heroes[1];local okay=m.complete and hero.actorId==actorId and hero.attempt==1 and hero.respawns==3 and not s.combat[1].deathAt
 if not okay then failures+=1 end
 print((okay and'PASS'or'FAIL')..' IceNPC cadence'..cadence..' delay'..delay..' time'..now..' Life'..s.combat[1].rawLife..' attempt'..hero.attempt..' hits'..#hits)
 for _,e in ipairs(hits)do print(' HIT',e.now,e.data.attacker,e.data.action,e.data.before,e.data.after)end
end end
print('TOTAL_FAILURES',failures)
