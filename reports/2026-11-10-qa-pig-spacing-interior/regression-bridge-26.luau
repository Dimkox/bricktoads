local Rig=require('./candidate-foot')
local d=require('../../src/server/gameplay/CampaignDefinition').build(1,503914550)
local floors={}
for _,zone in ipairs(d.zones)do for _,f in ipairs(zone.platforms)do floors[#floors+1]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}end end
local function freeze(t,seen)
 if type(t)~='table'or table.isfrozen(t)then return t end;seen=seen or{};if seen[t]then return t end;seen[t]=true
 for _,v in pairs(t)do freeze(v,seen)end;return table.freeze(t)
end
local count,failed=0,0
local function check(ok,label)count+=1;if not ok then failed+=1;print('FAIL',label)end end
local serial=0
local function context()
 serial+=1
 local actorId='original-'..serial
 return{slot=1,position={x=285.0016784667969,y=2.9717209339141846,z=3.399744749069214},now=1.1,stageToken='case'..serial,
 world={testFloors=floors,actors={[1]={model={GetAttribute=function(_,key)return key=='ActorId'and actorId or nil end},
 root={Parent=true,Anchored=false,AssemblyLinearVelocity={X=24,Y=0,Z=0}},locomotion={runRequested=true},
 humanoid={FloorMaterial='Slate',PlatformStand=false,Health=100}}}},
 session={state={heroes={[1]={actorId=actorId,status='Alive',connected=true,held=false}}},combat={[1]={rawLife=47}}}}
end
local desired={x=289.0016784667969,y=4.630172967910767,z=3.399744749069214}
local c=context();local plan={x=1,z=0,aimX=1,aimZ=0,primary=true,run=true,jump=false}
local out=Rig.foot(freeze(c),desired,plan)
check(out==plan and out.primary and out.run and not out.jump and out.x==1 and out.z==0,'Validated running primary crosses range to enemy without being replaced by a navigation Jump')
check(Rig.states[c.stageToken..':1'].jump==nil,'Prioritized ready Dash never invents a new navigation flight')
local ev=context();ev.world.actors[1].root.AssemblyLinearVelocity={X=-2.029468536376953,Y=.7461084127426147,Z=15.711499214172363};ev.world.actors[1].locomotion.runRequested=false
local retreat={x=-.0875886439351671,z=.9961567293622016,primary=true,run=true,jump=true,evasion=true}
local safe=Rig.foot(freeze(ev),desired,retreat)
check(safe.x<-.9 and safe.z>0 and safe.z<.4 and not safe.primary and not safe.run and not safe.jump,'Near-edge evasion moves inward toward current support inset without run/attack/jump')
check(Rig.states[ev.stageToken..':1'].jump==nil and Rig.states[ev.stageToken..':1'].gapRunUp==nil,'Evasion precedes navigation mutation or run-up staging')
for _,alter in ipairs({
 function(x)x.position.x=287 end,
 function(x)x.position.y=9 end,
 function(x)x.world.actors[1].root.Parent=false end,
 function(x)x.world.actors[1].root.Anchored=true end,
 function(x)x.world.actors[1].humanoid.PlatformStand=true end,
 function(x)x.world.actors[1].humanoid.FloorMaterial='Air'end,
 function(x)x.world.actors[1].humanoid.FloorMaterial=nil end,
 function(x)x.world.actors[1].humanoid.Health=0 end,
 function(x)x.world.actors[1].root.AssemblyLinearVelocity.Y=4 end,
 function(x)x.session.state.heroes[1].connected=false end,
 function(x)x.session.state.heroes[1].status='Eliminated'end,
 function(x)x.session.state.heroes[1].held=true end,
 function(x)x.session.state.heroes[1].actorId='replacement'end,
 function(x)x.session.combat[1].reactionEnd=5 end,
 function(x)x.session.combat[1].deathAt=5 end,
})do
 local x=context();alter(x);Rig.foot(freeze(x),desired,{x=1,z=0,primary=true,run=true,jump=false})
 check(Rig.qa.navigation.phase~='Running strike on authored support','Unsupported/stale/locked bodies do not receive tactical priority')
end
for _,alter in ipairs({
 function(x,p)x.world.actors[1].root.AssemblyLinearVelocity.X=17 end,
 function(x,p)x.world.actors[1].locomotion.runRequested=false end,
 function(x,p)p.run=false end,
 function(x,p)x.session.combat[1].attack={action='Punch'}end,
})do
 local x=context();local p={x=1,z=0,primary=true,run=true,jump=false};alter(x,p);Rig.foot(freeze(x),desired,p)
 check(Rig.qa.navigation.phase~='Running strike on authored support','Only an already qualified ready running primary receives strike priority')
end
local flying=context();local st={actorId=flying.session.state.heroes[1].actorId}
Rig.nav.plan(flying.position,desired,floors,st,.9,{grounded=true,jumpLead=3.2})
assert(st.jump,'Prepared navigation request')
Rig.states[flying.stageToken..':1']=st
local originalJump=st.jump
Rig.foot(freeze(flying),desired,{x=1,z=0,primary=true,run=true,jump=false})
check(st.jump==originalJump and Rig.qa.navigation.phase=='Flight','Existing flight is neither cleared nor falsely declared landed by priority')
local active=context();active.session.combat[1].attack={action='Dash'}
local stopped=Rig.foot(freeze(active),desired,{x=0,z=0,primary=false,run=false,jump=false,hold=true})
check(stopped.x==0 and stopped.z==0 and not stopped.run and not stopped.jump and not stopped.primary,'Follow-up accepted attack hold is not replaced by movement or Jump')
local airborne=context();local flight={actorId=airborne.session.state.heroes[1].actorId}
Rig.nav.plan(airborne.position,desired,floors,flight,.9,{grounded=true,jumpLead=3.2})
Rig.states[airborne.stageToken..':1']=flight;airborne.session.combat[1].attack={action='Dash'}
local prior=flight.jump
Rig.foot(freeze(airborne),desired,{x=0,z=0,primary=false,run=false,jump=false,hold=true})
check(flight.jump==prior and Rig.qa.navigation.phase=='Flight','Attack hold never clears or falsifies an existing flight')
assert(failed==0,'Grounded combat composition failures: '..failed..'/'..count)
print('Grounded combat composition GREEN',count)
