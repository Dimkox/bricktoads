local Pilot=require('../../tools/qa/campaign_combat_pilot')
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
for _,groundX in ipairs({634,640})do
 local c,p=fixture();incoming(c);c.director.projectiles[-101]={mode='Ground',position={x=groundX,y=1.2,z=0},expiresAt=110};freeze(c)
 local plan=Pilot.plan(c)
 check(plan.evasion and not plan.primary,'An incoming Guardian Bullet must take priority over a Ground ball pickup or chase')
 check(math.abs(plan.z)>.99 and math.abs(plan.x)<.01 and not plan.jump and not plan.run,'Ordinary perpendicular walking clears the advertised Bullet line')
 check(c.session.combat[1].rawLife==47 and c.session.state.heroes[1].respawns==3,'Read-only plan preserves original resources')
end
do
 local c=fixture();incoming(c);c.director.projectiles[-101]={mode='Carried',position={x=630,y=5,z=0},expiresAt=110};c.director.guardian.carriers[1]=-101;freeze(c)
 local plan=Pilot.plan(c);check(plan.evasion and not plan.primary,'Carrying a return ball does not override an imminent Bullet dodge')
end
do
 local c=fixture();c.director.projectiles[-101]={mode='Heavy',position={x=630,y=5,z=0},direction={x=630,y=1.2,z=0},expiresAt=110};freeze(c)
 local plan=Pilot.plan(c);check(not plan.evasion,'Guardian Heavy is the harmless return ball, not a damaging Bullet')
end
do
 local c=fixture();c.director.projectiles[-101]={mode='Ground',position={x=634,y=1.2,z=0},expiresAt=110};freeze(c)
 local plan=Pilot.plan(c);check(plan.primary and not plan.evasion,'Ordinary safe Ground pickup remains available')
end
do
 local c=fixture();c.director.projectiles[-101]={mode='Carried',position={x=630,y=5,z=0},expiresAt=110};c.director.guardian.carriers[1]=-101;freeze(c)
 local plan=Pilot.plan(c);check(plan.primary and not plan.evasion,'Ordinary safe carried-ball return remains available')
end
print('PASS retained Guardian Bullet priority10 assertions')
