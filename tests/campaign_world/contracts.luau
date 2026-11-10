-- Real adapter functions, deliberately fake engine geometry. Native checks are separate.
local campaignWorld=World.new(Base,{FallY=-35,WalkSpeed=16,JumpPower=50},
    {name='CampaignAdapterContract',offset={x=90,y=20,z=1024}})
Base.spawn(campaignWorld,1,'same-actor',nil,false,'Mr. Green')
local modeCalls={}
campaignWorld.campaignModes={
    move=function(_,slot,x,z,run) modeCalls.move={slot,x,z,run};return true end,
    jump=function(_,slot) modeCalls.jump=slot;return true end,
}
campaignWorld:move(1,.5,-.5,true)
assert(modeCalls.move and modeCalls.move[1]==1 and modeCalls.move[4]==true,
    'campaign modes must receive validated movement before ordinary locomotion')
campaignWorld:jump(1)
assert(modeCalls.jump==1,'campaign jump must reach the active mode')
print('PASS campaign move/jump routing')

local originalActor=campaignWorld.actors[1]
local originalActorId=originalActor.model:GetAttribute('ActorId')
campaignWorld:campaignPose(1,{x=12,y=-50,z=4},'Rope',{x=0,y=-3,z=0})
eq(originalActor.root.Position,102,-30,1028,'campaign positions must stay in their group coordinates')
assert(campaignWorld.actors[1]==originalActor and originalActor.model:GetAttribute('ActorId')==originalActorId,
    'mode motion must preserve the body and actor identity')
assert(originalActor.root.Anchored and originalActor.model:GetAttribute('CampaignMode')=='Rope')
assert(campaignWorld:hazard(1)==nil,'negative-Y controlled descent must not use the causeway fall plane')
campaignWorld:campaignRelease(1)
assert(not originalActor.root.Anchored and originalActor.model:GetAttribute('CampaignMode')==nil)
assert(originalActor.root.networkOwner==nil,'released campaign body stays server-owned')
print('PASS same-body local poses, negative descent and release')

local acceptedImpulse
campaignWorld.campaignModes.impulse=function(_,slot,v) acceptedImpulse={slot=slot,v=v};return true end
campaignWorld:campaignPose(1,{x=12,y=3,z=4},'Ice',{x=2,y=0,z=0})
campaignWorld:impulse(1,999,{horizontal=20,vertical=11},4,{x=3,z=4})
assert(acceptedImpulse and acceptedImpulse.slot==1 and math.abs(acceptedImpulse.v.x-12)<1e-6
    and math.abs(acceptedImpulse.v.z-16)<1e-6 and acceptedImpulse.v.y==11,
    'anchored mode physics must receive the accepted directional knockback')
campaignWorld:campaignRelease(1)
print('PASS accepted mode knockback preserves horizontal direction and vertical effect')
campaignWorld.campaignModes.mode='Ice'
campaignWorld.campaignModes.actors={[1]={grounded=true,velocity={x=24,y=0,z=0},input={run=true},finished=false}}
campaignWorld:campaignPose(1,{x=12,y=3,z=4},'Ice',{x=24,y=0,z=0})
assert(campaignWorld:isRunning(1) and campaignWorld:movementMode(1)=='Run',
    'validated kinematic ground running must retain the real running mega attack')
campaignWorld.campaignModes.actors[1].grounded=false
assert(not campaignWorld:isRunning(1),'airborne mode movement must not unlock another running strike')
campaignWorld:campaignRelease(1)
print('PASS kinematic grounded run qualification')

campaignWorld:placeActor(1,{x=25,y=8,z=-5})
eq(originalActor.root.Position,115,28,1019,'boss charge placement uses local group coordinates')
assert(not originalActor.root.Anchored,'ordinary charge placement must not lock future physics')
print('PASS ordinary actor placement')

campaignWorld.campaignModes=nil
originalActor.locomotion={walkSpeed=9,airSpeed=9}
campaignWorld:campaignWalkSpeed(1,4)
assert(originalActor.locomotion.walkSpeed==4 and originalActor.locomotion.airSpeed==4,
    'claim-time cached locomotion cannot override the family profile on later movement')
campaignWorld:move(1,1,0,false)
assert(originalActor.humanoid.WalkSpeed==4,'human ground role must retain its family walk speed')
campaignWorld:campaignWalkSpeed(1,0)
campaignWorld:move(1,1,0,true)
assert(originalActor.humanoid.WalkSpeed==0,'a stationary turret must remain immobile under human movement')
print('PASS trusted campaign family movement budgets')
campaignWorld:clearActors()
assert(not next(campaignWorld.actors),'campaign cleanup removes old bodies')
local campaignDefinition={id='rope-test',name='Test Shaft',campaignIndex=2,mode='Rope',spawn={x=0,y=240,z=0},
    bounds={minX=-40,maxX=40,minY=-25,maxY=270,minZ=-40,maxZ=40},
    zones={{platforms={{x=0,y=236,z=0,w=20,h=2,d=24}},enemies={}}},
    course={platforms={{x=0,y=236,z=0,w=20,h=2,d=24}},media={}},
    boss={platform={x=0,y=-1,z=0,w=60,h=2,d=50},pad={x=20,y=.1,z=0,w=12,d=20}}}
local rendered=World.new(Base,{FallY=-35,Level=campaignDefinition,WalkSpeed=16,JumpPower=50},
    {name='CampaignGeometryContract',offset={x=70,y=10,z=512},campaignWorld=source(CampaignWorldSource)})
assert(rendered.campaignWorld and rendered.folder:GetAttribute('LevelName')=='Test Shaft')
eq(rendered.origins[2],70,250,512,'level spawn must use the new mode origin instead of the causeway')
assert(rendered:cameraBounds().maxY==280,'vertical camera bounds must include the rope anchor')
local lift=rendered:campaignObject('lift','Lift',{x=5,y=90,z=3},{x=15,y=1,z=14})
eq(lift.Position,75,100,515,'dynamic supports must be group-local exactly once')
assert(lift.CanCollide and lift:GetAttribute('SurfaceId')=='rope-test:dynamic:lift')
rendered:campaignRemove('lift')
for _,p in ipairs(rendered.allFloors) do assert(p~=lift,'removed dynamic support must not remain a respawn floor') end
print('PASS vertical geometry, spawn, camera and dynamic support scope')

local selectorSession={now=0,world={targets=function() return {-99} end},state={heroes={}},combat={}}
local selectorDirector={enemies={[-99]={boss=true}},selectBossAction=function(_,id,input)
    assert(id==-99 and input=='Punch');return 'HeroPowerPunch'
end}
source(SourceCombatSource).bind(selectorSession,selectorDirector,{SourceCombat={},Attacks={Punch={}}})
assert(selectorSession.attackSelector(1,'Punch')=='HeroPowerPunch',
    'accepted source boss finishers must route to the actual boss profile')
print('PASS boss action selection uses encounter profile')
print('Campaign world: 9 groups passed; engine physics is not emulated')
