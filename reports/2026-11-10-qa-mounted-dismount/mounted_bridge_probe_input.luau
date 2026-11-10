local foot=require('./mounted_bridge_foot')
local Definition=require('../src/server/gameplay/CampaignDefinition')
local def=Definition.build(1,303307263)
local floors={}
for _,zone in ipairs(def.zones)do for _,f in ipairs(zone.platforms)do floors[#floors+1]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}end end
local function fixture(link,x,y,z)
 local ctx={position={x=x or 271.300048828125,y=y or 7.699996948242188,z=z or 4.000001430511475},slot=2,now=1,stageToken='actual13',
  session={state={heroes={[2]={actorId='actual13hero2'}}},combat={[2]={}}},world={testFloors=floors,actors={}}}
 ctx.world.actors[2]={model={GetAttribute=function(_,name)assert(name=='DragonLink');return link end},
  root={AssemblyLinearVelocity={X=0,Y=0,Z=0}},humanoid={FloorMaterial='Slate',PlatformStand=link~=nil}}
 return ctx
end
local desired={x=370,y=5,z=4}
local c=fixture('Mounted');local out=foot(c,desired,nil)
assert(out.x<0 and out.z<0 and not out.jump and not out.primary and not out.run,'Actual mounted edge pose must walk/fly inward through normal Move before safe dismount')
c=fixture('Mounted',268.8,nil,3.8);out=foot(c,desired,nil)
assert(out.jump and out.x==0 and out.z==0 and not out.primary and not out.run,'A mounted actor strictly over authored support must request normal Jump dismount')
c=fixture('Captured');out=foot(c,desired,nil)
assert(not out.jump and out.x==0 and out.z==0,'Captured actors never receive dismount Jump')
c=fixture(nil,268.8,3);out=foot(c,desired,nil)
assert(not out.jump,'Cleared mounted attribute must not repeat dismount while ordinary navigation is not launching')
c=fixture('Mounted',274.5);out=foot(c,desired,nil)
assert(not out.jump,'No dismount over the authored gap')
c=fixture('Mounted',268.8,25);out=foot(c,desired,nil)
assert(not out.jump,'No high unsupported dismount')
print('Actual bridge mounted/support contract GREEN6')
