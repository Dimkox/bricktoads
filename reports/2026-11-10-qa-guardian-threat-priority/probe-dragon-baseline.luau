local Pilot=require('./combat-baseline-2e6f')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),require('../../src/server/gameplay/LevelDefinition'))
local function freeze(t,seen)
 if type(t)~='table' or table.isfrozen(t)then return t end;seen=seen or{};if seen[t]then return t end;seen[t]=true
 for _,v in pairs(t)do freeze(v,seen)end;return table.freeze(t)
end
local function fixture()
 local positions={[1]={x=630,y=3,z=0},[-99]={x=654,y=3,z=0}}
 local c={slot=1,now=100,dt=.133,definition={zones={{platforms={{x=630,y=-1,z=0,w=90,h=2,d=50}}}}},
  session={state={status='Active',runId='guardian-threat',levelEpoch=1,heroes={[1]={status='Alive',connected=true,actorId='hero1',attempt=1,respawns=3}}},config=Config,combat={[1]={rawLife=47,nextAttack=0}}},
  director={stage='Boss',guardian={carriers={}},enemies={[-99]={boss=true,rawLife=47}},projectiles={}},
  world={actors={[1]={root={Parent=true,Anchored=false,CFrame={LookVector={X=1,Z=0}},AssemblyLinearVelocity={X=0,Y=0,Z=0}},
    humanoid={Health=100,PlatformStand=false,FloorMaterial='Slate'}}},position=function(_,id)return positions[id]end}}
 return c,positions
end
local count=0
local function check(v,m)assert(v,m);count+=1 end
local function incoming(c)
 c.director.projectiles[-100]={mode='Bullet',position={x=633,y=3,z=0},direction={x=625,y=3,z=0},expiresAt=110}
end
-- Source-calibrated close Dragon tell: the generic direct retreat cannot
-- leave a6stud frontal volume during a .16s remaining control window, while
-- perpendicular walking16stud/s clears its3stud side bound.
do
 local c,p=fixture();c.director={enemies={[-10]={kind='Dragon',rawLife=47,actorId='dragon',windup={at=100.16,tuning=Config.Attacks.DragonHeadbutt}}}}
 p[1]={x=271,y=5,z=6.6};p[-10]={x=273,y=6.5,z=6}
 c.definition={zones={{platforms={{x=275.5,y=1,z=6,w=27,h=2,d=18}}}}}
 c.world.actors[-10]={root={CFrame={LookVector={X=-1,Z=0}}}}
 c.world.actors[1].locomotion={runRequested=true,groundRun=true,at=100}
 c.world.actors[1].root.AssemblyLinearVelocity={X=24,Y=0,Z=0};freeze(c)
 local plan=Pilot.plan(c)
 check(plan.evasion and not plan.primary,'An advertised close Dragon tell must precede an observed-run Dash attempt')
 check(math.abs(plan.x)<.01 and math.abs(plan.z)>.99,'Dragon tell evasion is perpendicular to the real frozen strike facing')
 local x,z=p[1].x+plan.x*16*.16,p[1].z+plan.z*16*.16
 check(math.abs(z-p[-10].z)>Config.Attacks.DragonHeadbutt.width,'Calibrated walking clears side bound before the held tell deadline')
 check(x>=265 and x<=286 and z>=0 and z<=12,'Evasion endpoint remains inside the same authored3stud inset')
end
print('PASS Guardian/Dragon threat priority '..count)
