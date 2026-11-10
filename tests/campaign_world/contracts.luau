-- Real adapter functions, deliberately fake engine geometry. Native checks are separate.
local rawCFrameNew=env.CFrame.new
env.CFrame.new=function(...)
    local n=select('#',...);local first=...
    assert(n==0 or n==1 and type(first)=='table'and type(first.X)=='number'and type(first.Y)=='number'and type(first.Z)=='number'
        or n==3 or n==12,'CFrame.new requires zero, Vector3, three or twelve arguments')
    if n==3 or n==12 then for _,v in ipairs({...})do assert(type(v)=='number','CFrame.new coordinates must be numbers')end end
    return rawCFrameNew(...)
end
local ActualCourseAppearance=source(CourseAppearanceSource)
env.script={Parent={CourseAppearance='CourseAppearance'}}
env.require=function(name)assert(name=='CourseAppearance');return ActualCourseAppearance end
function Frame:GetComponents()
    local c,s=math.cos(self.rotationY or 0),math.sin(self.rotationY or 0)
    return self.Position.X,self.Position.Y,self.Position.Z,c,0,s,0,1,0,-s,0,c
end
function Frame.__add(a,b)
    local r=frame(a.Position+b);r.rotationX,r.rotationY,r.rotationZ=a.rotationX,a.rotationY,a.rotationZ;return r
end
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

-- The serpent renderer owns only a cosmetic assembly, never a support collider.
local priorIsA=Node.IsA
function Node:IsA(class) return class=='BasePart' and self.ClassName=='MeshPart' or priorIsA(self,class) end
local priorFrameIndex=Frame.__index
Frame.__index=function(self,key)
    if key=='Rotation' then local r=frame();r.rotationX,r.rotationY,r.rotationZ=self.rotationX,self.rotationY,self.rotationZ;return r end
    return priorFrameIndex[key]
end
function Frame:PointToWorldSpace(p)
    local a=self.rotationY or 0
    return self.Position+vector(p.X*math.cos(a)+p.Z*math.sin(a),p.Y,-p.X*math.sin(a)+p.Z*math.cos(a))
end
local function cloneNode(original)
    local c=node(original.ClassName,original.Name)
    for k,v in pairs(original) do if k~='children' and k~='_parent' and k~='attributes' then c[k]=v end end
    c.attributes=table.clone(original.attributes)
    for _,child in ipairs(original:GetChildren()) do cloneNode(child).Parent=c end
    return c
end
function Node:Clone() return cloneNode(self) end
local castStorage=node('ServerStorage');local sourceTemplates=node('Folder','BrickToadsCastTemplates',castStorage)
local sourceSnake=node('Model','Snake',sourceTemplates)
local sourceBody=node('MeshPart','Body',sourceSnake);sourceBody.Size=vector(2,2,8);sourceBody.CFrame=frame();sourceBody.Transparency=0
local sourcePivot=node('Attachment','CastRigAttachment',sourceBody);sourcePivot.CFrame=frame(0,1,0)
local oldGetService=env.game.GetService
env.game.GetService=function(self,name) if name=='ServerStorage' then return castStorage end;return oldGetService(self,name) end
local overlayCalls={attach=0,detach=0,updates={}}
local expectedSerpentScale=1.75
rendered.castAppearance={
    attach=function(actor,kind,templates)
        overlayCalls.attach+=1;assert(kind=='Snake' and templates.Parent==nil,'Scaled templates must stay outside DataModel')
        local t=assert(templates:FindFirstChild('Snake'));local p=t:FindFirstChild('Body')
        assert(p.Size.X==2*expectedSerpentScale and p.Size.Y==2*expectedSerpentScale and p.Size.Z==8*expectedSerpentScale,'Uniform scale must precede attachment')
        assert(p.CastRigAttachment.CFrame.Position.Y==expectedSerpentScale,'Source pivot positions must scale with geometry')
        assert(p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery)
        actor.castAppearance={model=t:Clone()};actor.castAppearance.model.Parent=actor.model
        overlayCalls.temporary=templates;overlayCalls.actor=actor
        return true
    end,
    detach=function(actor) overlayCalls.detach+=1;actor.castAppearance.model:Destroy();actor.castAppearance=nil end,
    update=function(actor,context) overlayCalls.updates[#overlayCalls.updates+1]={actor=actor,context=context} end,
}
local previousFloorCount=#rendered.allFloors
local snakeCollider=rendered:campaignObject('snake-art','Serpent',{x=4,y=30,z=8},{x=14,y=1,z=12})
local snakeRow=rendered.campaignWorld.objects['snake-art']
assert(overlayCalls.attach==1 and snakeRow.serpent,'Serpent support never acquired the imported skin')
assert(snakeCollider.Size.X==14 and snakeCollider.Size.Y==1 and snakeCollider.Size.Z==12 and snakeCollider.CanCollide and snakeCollider.CanQuery)
assert(snakeCollider:GetAttribute('SurfaceId')=='rope-test:dynamic:snake-art','Cosmetics changed support identity')
assert(#rendered.allFloors==previousFloorCount+1 and rendered.allFloors[#rendered.allFloors]==snakeCollider,'Cosmetic proxy became a playable floor')
local proxy=overlayCalls.actor;assert(proxy.root.Anchored and not proxy.root.CanCollide and not proxy.root.CanQuery and proxy.root.Transparency==1)
eq(proxy.root.CFrame.Position,74,38.75,520,'Snake back top must meet the original support top')
assert(math.abs((proxy.root.CFrame.rotationY or 0)-math.pi/2)<1e-6,'Snake head and tail must lie along support X')
assert(sourceBody.Size.X==2 and sourceBody.CastRigAttachment.CFrame.Position.Y==1,'Shared uploaded template was resized')
rendered.campaignWorld:step(25)
assert(overlayCalls.updates[#overlayCalls.updates].context.now==25,'Snake pose must use actual world time')
rendered:campaignObject('snake-art','Serpent',{x=14,y=32,z=9},{x=14,y=1,z=12})
assert(overlayCalls.attach==1,'Position changes must retain the same cached cosmetic assembly')
eq(proxy.root.CFrame.Position,84,40.75,521,'Moving support failed to carry its cosmetic proxy')
local temporary=overlayCalls.temporary;local model=proxy.model
rendered:campaignRemove('snake-art')
assert(model.destroyed and temporary.destroyed and overlayCalls.detach==1 and snakeCollider.destroyed,'Removed support leaked owned serpent art')
for _,p in ipairs(rendered.allFloors) do assert(p~=snakeCollider) end
print('PASS serpent imported overlay scales before attachment, preserves support and cleans up movement')

rendered:campaignObject('replacement-art','Serpent',{x=0,y=20,z=0},{x=14,y=1,z=12})
local owned=overlayCalls.actor.model;local ownedTemporary=overlayCalls.temporary
rendered:campaignObject('replacement-art','Lift',{x=0,y=20,z=0},{x=14,y=1,z=12})
assert(owned.destroyed and ownedTemporary.destroyed,'Kind replacement leaked serpent assembly')
rendered:campaignObject('close-art','Serpent',{x=0,y=20,z=0},{x=14,y=1,z=12})
owned=overlayCalls.actor.model;ownedTemporary=overlayCalls.temporary
rendered.campaignWorld:close()
assert(owned.destroyed and ownedTemporary.destroyed and not next(rendered.campaignWorld.objects),'Course close leaked serpent art')
print('PASS serpent kind replacement and course close destroy only owned visuals')

rendered:campaignObject('resize-art','Serpent',{x=0,y=20,z=0},{x=14,y=1,z=12})
owned=overlayCalls.actor.model;ownedTemporary=overlayCalls.temporary
expectedSerpentScale=3.5
rendered:campaignObject('resize-art','Serpent',{x=0,y=20,z=0},{x=28,y=1,z=12})
assert(owned.destroyed and ownedTemporary.destroyed and overlayCalls.actor.model~=owned,
    'Size changes must rebuild a pre-scaled skin rather than rescale cached joint bases')
rendered:campaignRemove('resize-art');expectedSerpentScale=1.75
local attach=rendered.castAppearance.attach;local rejectedProxy,rejectedTemporary
rendered.castAppearance.attach=function(actor,_,templates)
    rejectedProxy,rejectedTemporary=actor.model,templates;return false
end
local fallback=rendered:campaignObject('rejected-art','Serpent',{x=0,y=20,z=0},{x=14,y=1,z=12})
assert(not rendered.campaignWorld.objects['rejected-art'].serpent and rejectedProxy.destroyed and rejectedTemporary.destroyed,
    'Rejected imported art leaked a temporary model or proxy')
assert(fallback.Transparency~=1 and fallback.CanCollide and fallback.CanQuery,
    'Rejected imported art must retain the visible original support')
rendered.castAppearance.attach=attach;rendered:campaignRemove('rejected-art')
print('PASS serpent resize rebuilds cached geometry and failed imports preserve visible physical support')

-- The new presentation adapter must leave the actual hazard/support registry alone.
local courseTemplates=node('Folder','BrickToadsCourseTemplates',castStorage)
local vehicleTemplate=node('Model','Speeder',courseTemplates)
for name,text in pairs({AppearanceProfile='CanonicalCourseVehicle',CourseKind='Speeder',
    SourcePin='f1a43b69577246850d136473700a333b3cdfe93f'})do
    local n=node('StringValue',name,vehicleTemplate);n.Value=text
end
for name,value in pairs({DeckTop=0,DeckLength=6,DeckWidth=3})do
    local n=node('NumberValue',name,vehicleTemplate);n.Value=value
end
local deck=node('MeshPart','Deck',vehicleTemplate);deck.Size=vector(3,.4,6);deck.CFrame=frame(0,-.2,0)
deck.MeshId='rbxassetid://1234';deck.Transparency=0
env.game.GetService=function(self,name)
    if name=='ServerStorage'then return castStorage end
    if name=='CollectionService'then return {AddTag=function(_,model,tag)model:SetAttribute('TestTag',tag)end}end
    return oldGetService(self,name)
end
local floorCount=#rendered.floors
local vehicle=rendered:campaignObject('actual-vehicle','Speeder',{x=10,y=.4,z=4},{w=6,h=.9,d=3},{collidable=false})
local vehicleRow=rendered.campaignWorld.objects['actual-vehicle'];local ownedVehicle=assert(vehicleRow.courseAppearance).model
assert(#rendered.floors==floorCount and #rendered.allFloors==floorCount,'Vehicle art became a respawn surface')
assert(not vehicle.CanCollide and not vehicle.CanQuery and vehicle.Size.X==6 and vehicle.Size.Y==.9 and vehicle.Size.Z==3)
rendered:campaignObject('actual-vehicle','Wall',{x=10,y=3,z=4},{w=3,h=18,d=12},{alpha=.1,collidable=false})
assert(ownedVehicle.destroyed and vehicle.destroyed,'Vehicle kind replacement leaked its cosmetic model')
local wallRow=rendered.campaignWorld.objects['actual-vehicle'];local wall=wallRow.part
assert(wallRow.courseAppearance and not wall.CanCollide and not wall.CanQuery and #rendered.floors==floorCount)
local moving=rendered:campaignObject('actual-moving-wall','MovingWall',{x=0,y=6,z=10},{w=4,h=14,d=5},{collidable=true})
local movingRow=rendered.campaignWorld.objects['actual-moving-wall'];local oldModel=movingRow.courseAppearance.model
assert(moving.CanCollide and moving.CanQuery and moving:GetAttribute('SurfaceId')=='rope-test:dynamic:actual-moving-wall')
assert(rendered.floors[#rendered.floors]==moving and #rendered.floors==floorCount+1)
rendered:campaignObject('actual-moving-wall','MovingWall',{x=20,y=8,z=12},{w=4,h=14,d=5},{collidable=true,yaw=.7})
assert(movingRow.courseAppearance.model==oldModel and movingRow.part==moving,'Motion must reuse the original collider and cosmetic model')
local pose=movingRow.courseAppearance.rows[1].part.CFrame
eq(pose.Position,90,18,524,'Wall cosmetic lost group offset or dynamic movement')
assert(math.abs(pose.rotationY-.7)<1e-6,'Moving wall cosmetic lost yaw')
rendered:campaignObject('actual-moving-wall','MovingWall',{x=20,y=8,z=12},{w=6,h=16,d=7},{collidable=true})
assert(oldModel.destroyed and movingRow.part==moving and #rendered.floors==floorCount+1,'Resize replaced or duplicated a physical support')
ownedVehicle=wallRow.courseAppearance.model;oldModel=movingRow.courseAppearance.model
rendered.campaignWorld:close()
assert(ownedVehicle.destroyed and oldModel.destroyed and moving.destroyed and #rendered.floors==floorCount,
    'Course close leaked appearance or retained an obsolete physical floor')
print('PASS vehicle and volumetric structure lifecycle preserve exact colliders, floor membership and group coordinates')

local surfTemplate=vehicleTemplate:Clone();surfTemplate.Name='Surfboard';surfTemplate.CourseKind.Value='Surfboard';surfTemplate.Parent=courseTemplates
rendered.campaignWorld.route.course.media={{kind='Water',minX=0,maxX=20,minZ=-5,maxZ=5,minY=-3,maxY=4}}
local surf=rendered:campaignObject('water-fit','Surfboard',{x=10,y=.4,z=0},{w=6,h=.9,d=3},{collidable=false})
local surfRow=rendered.campaignWorld.objects['water-fit'];local surfSkin=assert(surfRow.courseAppearance)
assert(math.abs(surfSkin.deckWorldY-14.1)<1e-6,'Surf deck must clear the covering water top plus group elevation')
assert(not surf.CanCollide and not surf.CanQuery and #rendered.floors==floorCount,'Water fit changed physical support membership')
rendered:campaignObject('water-fit','Surfboard',{x=30,y=.4,z=0},{w=6,h=.9,d=3},{collidable=false})
assert(surfRow.courseAppearance==surfSkin and math.abs(surfSkin.deckWorldY-10.43)<1e-6,
    'Leaving water must recompute placement from the anchor plane without rebuilding the skin')
rendered:campaignRemove('water-fit')
print('PASS surf placement uses only covering actual route water and retains scoped collider physics')
