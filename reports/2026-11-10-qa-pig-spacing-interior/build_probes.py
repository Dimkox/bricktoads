from pathlib import Path
R=Path(__file__).resolve().parent
P=R.parents[1]
current=(R/'probe-baseline.luau').read_text().replace("require('./baseline-combat')","require('./candidate-combat')").replace("require('./baseline-foot')","require('./candidate-foot')")
(R/'probe-current.luau').write_text(current)
t=(P/'reports/2026-11-10-causeway-evade-interior-proof/probe-contact-envelope.luau').read_text()
t=t.replace("local DT=1/60", "local Pilot=require('./KIND-combat')\nlocal Rig=require('./KIND-foot')\nlocal DT=1/60")
t=t.replace("local now,seq,nextPlan,hit,contact,escaped=0,0,1,false,nil,false",'''local now,seq,nextPlan,hit,contact,escaped=0,0,0,false,nil,false
 local h=s.state.heroes[1]
 w.testFloors={};for _,zone in ipairs(d.zones)do for _,f in ipairs(zone.platforms)do w.testFloors[#w.testFloors+1]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}end end
 w.actors[1].model={GetAttribute=function(_,k)return k=='ActorId'and h.actorId or nil end}
 w.actors[1].root={Parent=true,Anchored=false,CFrame={LookVector={X=-.44514727263538223,Z=-.8954573723328658}},AssemblyLinearVelocity={X=v.x,Y=0,Z=v.z}}
 w.actors[1].humanoid={FloorMaterial='Slate',PlatformStand=false,Health=100};w.actors[1].locomotion={runRequested=false}
 local q
 function w:position(id)return id==1 and p or q end
 local director={stage='Route',zoneIndex=2,enemies={[-5]={kind='Pig',rawLife=15,actorId='pig5',nextAttack=0}}}
''')
start=t.index('  while native[nextPlan]')
end=t.index('  if not hit and ',start)
t=t[:start]+'''  if now+1e-8>=nextPlan and not hit then
   q={x=p.x-.44514727263538223*2.8,y=3,z=p.z-.8954573723328658*2.8}
   local body=w.actors[1];body.root.AssemblyLinearVelocity={X=v.x,Y=0,Z=v.z}
   if origin+now>=80.936640 then director.enemies[-5].windup={at=81.236640,action='PigJab',tuning=cfg.Attacks.PigJab}end
   local ctx={slot=1,now=origin+now,dt=.133,world=w,session=s,director=director,position=p,definition=d,stageToken=name..delivery}
   local tactical=Pilot.plan(ctx)
   if now==0 then assert(tactical.evasion,'First prepared ordinary Pig spacing must use actual Combat evasion')end
   local out=Rig.foot(ctx,q,tactical)
   pending[#pending+1]={at=now+delivery,x=out.x,z=out.z}
   nextPlan=now+.133
  end
'''+t[end:]
t=t[:t.index('local baseline=0;')]+'''local green=0
for _,delay in ipairs({0,2/60,.08})do if case('actual-composition',nil,delay)then green+=1 end end
print('COMPOSED_ENVELOPE_GREEN',green)
assert(green==EXPECTED,'Actual Combat -> extracted actual Bridge -> Session/profile envelope count')
'''
for kind,expected in [('baseline',1),('candidate',3)]:
 source=t.replace('KIND',kind).replace('==EXPECTED','=='+str(expected))
 (R/(kind+'-session-envelope.luau')).write_text(source)
if not(R/'candidate-combat.lua').exists():(R/'candidate-combat.lua').write_bytes((P/'tools/qa/campaign_combat_pilot.lua').read_bytes())
