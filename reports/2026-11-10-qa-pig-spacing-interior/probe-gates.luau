local Rig=require('./candidate-foot')
local serial,count=0,0
local function fixture(w,d)
 serial+=1;local id='gates'..serial
 return {slot=1,now=1,stageToken=id,position={x=w-1,y=3,z=d-1},world={testFloors={{minX=0,maxX=w,minZ=0,maxZ=d,top=0}},
  actors={[1]={model={GetAttribute=function(_,k)return k=='ActorId'and id or nil end},root={Parent=true,Anchored=false,AssemblyLinearVelocity={X=0,Y=0,Z=0}},
   humanoid={FloorMaterial='Slate',PlatformStand=false,Health=100},locomotion={runRequested=false}}}},
  session={state={heroes={[1]={actorId=id,status='Alive',connected=true}}},combat={[1]={rawLife=47}}}}
end
for _,size in ipairs({7,8,14,20,22})do
 local c=fixture(size,size);local p={x=1,z=1,evasion=true,pigSpacing=true}
 local out=Rig.foot(c,c.position,p);local goal=Rig.qa.navigation.target
 local margin=size>=8 and math.min(7,size/2-1)or 3
 assert(goal.x>=margin and goal.x<=size-margin and goal.z>=margin and goal.z<=size-margin,'Ordered dimension-capped Pig clamp')
 assert(out.x<=0 and out.z<=0 and not out.jump and not out.run and not out.primary,'Pig correction is ordinary inward walking')
 assert(out.pigSpacing==nil,'Internal hint does not leave actual Bridge result')
 assert(Rig.normalize({x=out.x,z=out.z,pigSpacing=true}).pigSpacing==nil,'Actual public normalization strips internal hint')
 count+=4
 local other=fixture(size,size);Rig.foot(other,other.position,{x=1,z=1,evasion=true})
 assert(Rig.qa.navigation.target.x==size-3 and Rig.qa.navigation.target.z==size-3,'Non-Pig hintless evasion retains exactly3studs')
 count+=1
end
local c=fixture(50,40);c.world.actors[1].humanoid.FloorMaterial='Air'
Rig.foot(c,c.position,{x=1,z=1,evasion=true,pigSpacing=true})
assert(Rig.qa.navigation.phase~='Evade on authored support','Airborne hint cannot enter grounded tactical priority');count+=1
local h=fixture(50,40);h.session.combat[1].attack={action='Dash'}
local out=Rig.foot(h,h.position,{x=1,z=1,evasion=true,pigSpacing=true,hold=true})
assert(out.x==0 and out.z==0 and not out.jump and not out.run,'Accepted attack hold retains precedence');count+=1
local stopped=fixture(50,40);stopped.position={x=43,y=3,z=33}
local zero=Rig.foot(stopped,stopped.position,{x=1,z=1,evasion=true,pigSpacing=true})
assert(zero.x==0 and zero.z==0,'At the reserved inset, clearance priority may stop; combat progress is not claimed');count+=1
print('PASS Pig hint dimension/gate/nonleak checks',count)
