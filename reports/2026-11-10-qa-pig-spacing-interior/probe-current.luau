local Pilot=require('./candidate-combat')
local Rig=require('./candidate-foot')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),Definition.build(1,1158731273))
local p={x=47.37826156616211,y=3,z=11.006926536560059}
local q={x=p.x-.44514727263538223*2.8,y=3,z=p.z-.8954573723328658*2.8}
local floors={};for _,z in ipairs(Config.Level.zones)do for _,f in ipairs(z.platforms)do floors[#floors+1]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}end end
local h={actorId='original',status='Alive',connected=true,held=false,attempt=1,respawns=3}
local w={testFloors=floors,actors={[1]={model={GetAttribute=function(_,k)return k=='ActorId'and h.actorId or nil end},root={Parent=true,Anchored=false,CFrame={LookVector={X=-.44514727263538223,Z=-.8954573723328658}},AssemblyLinearVelocity={X=4.2485,Y=0,Z=15.4258}},humanoid={FloorMaterial='Slate',PlatformStand=false,Health=100},locomotion={runRequested=false}}}}
function w:position(id)return id==1 and p or q end
local c={slot=1,now=80.514638,dt=.134,world=w,position=p,definition=Config.Level,stageToken='first-Pig',
 session={config=Config,state={status='Active',runId='first-Pig',levelEpoch=1,heroes={[1]=h}},combat={[1]={rawLife=47,nextAttack=0}}},
 director={stage='Route',zoneIndex=2,enemies={[-5]={kind='Pig',rawLife=15,actorId='pig5',nextAttack=0}}}}
local tactical=Pilot.plan(c);assert(tactical.evasion and not tactical.jump,'Actual Combat first grounded Pig spacing')
local out=Rig.foot(c,q,tactical)
print('COMPOSITION',tactical.x,tactical.z,tactical.pigSpacing,out.x,out.z,Rig.qa.navigation.target.x,Rig.qa.navigation.target.z)
assert(out.x<=0 and out.z<0,'First grounded Pig spacing must prefer current-floor interior before outward escape')
