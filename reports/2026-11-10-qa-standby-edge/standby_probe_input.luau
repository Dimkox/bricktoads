local dispatch=require('./standby_current')
local definition=require('../src/server/gameplay/CampaignDefinition').build(1,1259618153)
local f=definition.zones[1].platforms[1]
local function freeze(t,seen)
 if type(t)~='table'or table.isfrozen(t)then return t end;seen=seen or{};if seen[t]then return t end;seen[t]=true
 for _,v in pairs(t)do freeze(v,seen)end;return table.freeze(t)
end
local floor={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2,
 part={GetAttribute=function(_,key)assert(key=='SurfaceId');return'first-authored-support'end}}
local function fixture(x,y,z,slot)
 slot=slot or 2;local actorId='owned-actor-'..slot
 local c={slot=slot,position={x=x,y=y,z=z},definition=definition,
  controller={owners={[1]={userId=-101},[2]={userId=-102},[3]={userId=-103}}},
  session={state={heroes={[slot]={status='Alive',connected=true,actorId=actorId}}},combat={[slot]={}}},
  world={testFloors={floor},lastSupport={[slot]='first-authored-support'},actors={}}}
 c.world.actors[slot]={model={GetAttribute=function(_,key)return key=='ActorId'and actorId or nil end},
  root={Parent=true,Anchored=false,AssemblyLinearVelocity={X=0,Y=0,Z=0}},
  humanoid={Health=100,FloorMaterial='Slate',PlatformStand=false}}
 return c
end
local checks=0
local function check(value,message)assert(value,message);checks+=1 end
local function plan(c,index,lead)freeze(c);local result=dispatch(c,index or 1,lead or 1);return result and result.plan end
local function neutral(p)return p and p.x==0 and p.z==0 and not p.primary and not p.run and not p.jump end
check(floor.minX==-82 and floor.maxX==4 and floor.minZ==-26 and floor.maxZ==26,'Actual attempt14 seed geometry')
-- Exact respawn poses were not retained. These are source-derived nearest-safe
-- candidates from the recorded falls: same X, standing Y3, lateral inset1.2.
for _,x in ipairs({-42.95482635498047,-40.31071853637695,-37.28451156616211})do
 local c=fixture(x,3,-24.8);local p=plan(c)
 check(p.z>0 and p.x==0 and not p.primary and not p.run and not p.jump,'Near-edge paid-spawn candidate must request only ordinary inward Move')
end
check(neutral(plan(fixture(-65,3,0))),'Interior follower remains neutral')
check(dispatch(freeze(fixture(-40,3,-24.8)),1,2)==nil,'Current lead must bypass standby unchanged')
check(dispatch(freeze(fixture(-40,3,-24.8)),2,1)==nil,'Other stages must bypass standby unchanged')
local changedLead=fixture(-40,3,-24.8,1);local response=plan(changedLead,1,2)
check(response.z>0 and changedLead.controller.owners[1].userId==-101,'Different lead/cohort retains existing authority and only steers its own actor')
for _,p in ipairs({{-42.95482635498047,-39.35697937011719,-29.9942626953125},
 {-40.31071853637695,-35.40260314941406,-30.25383377075195},
 {-37.28451156616211,-42.1323356628418,-29.46527290344238},
 {-33.67818450927734,-36.11419677734375,-28.52650260925293}})do
 check(neutral(plan(fixture(p[1],p[2],p[3]))),'Recorded unsupported fall must not request a jump or blind recovery')
end
for _,point in ipairs({{-80.8,0},{2.8,0},{-40,24.8},{-80.8,-24.8},{2.8,24.8}})do
 local c=fixture(point[1],3,point[2]);local p=plan(c)
 local goalX=math.clamp(point[1],floor.minX+6,floor.maxX-6)
 local goalZ=math.clamp(point[2],floor.minZ+6,floor.maxZ-6)
 check(p.x*(goalX-point[1])+p.z*(goalZ-point[2])>0 and not p.primary and not p.run and not p.jump,'Each edge/corner steers toward an interior point on the same support')
end
for _,alter in ipairs({
 function(c)c.world.lastSupport[2]='different-support'end,
 function(c)c.world.lastSupport[2]=nil end,
 function(c)c.world.actors[2].root.Anchored=true end,
 function(c)c.world.actors[2].humanoid.PlatformStand=true end,
 function(c)c.world.actors[2].humanoid.FloorMaterial='Air'end,
 function(c)c.world.actors[2].root.AssemblyLinearVelocity.Y=-5 end,
 function(c)c.session.combat[2].reactionEnd=100 end,
 function(c)c.session.combat[2].deathAt=100 end,
 function(c)c.session.state.heroes[2].connected=false end,
 function(c)c.session.state.heroes[2].actorId='replacement-actor'end,
 function(c)c.world.actors[2].model.GetAttribute=function(_,key)return key=='DragonLink'and'Mounted'or'owned-actor-2'end end,
 function(c)c.world.actors[2].model.GetAttribute=function(_,key)return key=='DragonLink'and'Captured'or'owned-actor-2'end end,
})do
 local c=fixture(-40,3,-24.8);alter(c);check(neutral(plan(c)),'Unsupported, stale, airborne, reacting or linked followers stay neutral')
end
print('QA standby edge contract GREEN',checks)
