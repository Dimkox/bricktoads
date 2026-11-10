-- Native prepared art/lifecycle fixture. Never joins a player or creates a Session.
-- Uses fresh actual modules and a private BaseWorld at X18000; avoids GameWorld.new
-- because that constructor changes Lighting and removes blank-place defaults.
assert(game:GetService('RunService'):IsStudio(),'Studio QA only')
local SS=game:GetService('ServerStorage')
assert(not SS:FindFirstChild('BrickToadsWorldElementsQA'),'Owned world QA already exists')
assert(not workspace:FindFirstChild('BrickToadsWorldElementsGallery'),'Owned world gallery already exists')
local baseplate,spawn=workspace:FindFirstChild('Baseplate'),workspace:FindFirstChild('SpawnLocation')
local lighting=game:GetService('Lighting')
local lightBefore={lighting.ClockTime,lighting.Brightness,lighting.FogStart,lighting.FogEnd}
local project=assert(game.ServerScriptService:FindFirstChild('BrickToads'))
local owner=Instance.new('Folder');owner.Name='BrickToadsWorldElementsQA';owner.Parent=SS
local modules=project.gameplay:Clone();modules.Name='Modules';modules.Parent=owner
local runtime=project.CombatRuntime:Clone();runtime.Name='Runtime';runtime.Parent=owner
for _,v in ipairs(owner:GetDescendants())do if v:IsA('BaseScript')then v.Disabled=true end end
local World=require(modules.GameWorld)
require(modules.DragonWorld)(World);require(modules.BossIntroWorld)(World)
local Base=require(runtime.RobloxWorld)
local route=require(modules.CampaignDefinition).build(1,1158731273)
local config=require(modules.GameConfig)(require(runtime.Config),route)
local world=Base.new(config);world.folder.Name='BrickToadsWorldElementsGallery'
world._base=Base;world.offset=Vector3.new(18000,0,0);world.baseFallY=config.FallY
world.characterAppearance=require(modules.CharacterAppearance);world.castAppearance=require(modules.CanonicalCastAppearance)
world.guardianAppearance=require(modules.GuardianAppearance)
world.enemyKinds={};world.enemyCarries={};world.clubItems={};world.equippedClubs={}
world.healingFlyVisuals={};world.healingEffects={};world.dragonFlights={};world.dragonLinks={};world.dragonFires={}
for key,name in pairs({clubItemFolder='ClubItems',healingFlyFolder='HealingFlies',
    healingEffectFolder='HealingEffects',dragonFireFolder='DragonFire'})do
    local f=Instance.new('Folder');f.Name=name;f.Parent=world.folder;world[key]=f
end
world.dragonOverlap=OverlapParams.new();world.dragonOverlap.FilterType=Enum.RaycastFilterType.Include
world.dragonOverlap.FilterDescendantsInstances={world.geometry};world.dragonOverlap.RespectCanCollide=true
setmetatable(world,{__index=function(_,key)return World[key]or Base[key]end})
assert(world:rebuildLevel(route))
local report={schema=1,placeId=game.PlaceId,createdAt=os.time(),rows={},environment={},errors={},
    scope='Prepared actual world-art paths and cleanup, not campaign, input or resource acceptance',
    limits={'Legacy environment decorations and projectile halos may remain queryable while noncolliding; these flags are reported explicitly.',
        'Projectile and item primitives are existing authored presentation, not detailed imported UHD meshes.',
        'Native availability/visibility of imported HealingFly and hero skins requires separate client evidence.',
        'Only this fixture private actor and folders are modified; no live player, Session, HP or stock writes.'}}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function validatePart(p)
    for _,n in ipairs({p.Size.X,p.Size.Y,p.Size.Z})do assert(finite(n)and n>0,'Invalid size '..p.Name)end
    for _,n in ipairs({p.CFrame:GetComponents()})do assert(finite(n),'Invalid frame '..p.Name)end
end
local function inspect(model,noncolliding)
    local out={parts=0,meshes=0,colliding=0,touching=0,queryable=0,anchored=0,massless=0,resources={}}
    for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
        validatePart(p);out.parts+=1
        if p.CanCollide then out.colliding+=1 end;if p.CanTouch then out.touching+=1 end
        if p.CanQuery then out.queryable+=1 end;if p.Anchored then out.anchored+=1 end;if p.Massless then out.massless+=1 end
        if noncolliding then assert(not p.CanCollide and not p.CanTouch,'Colliding/touching cosmetic '..p.Name)end
        if p:IsA('MeshPart')then
            out.meshes+=1;assert(p.MeshId:match('^rbxassetid://%d+$'),'Missing mesh '..p.Name)
            local surface=p:FindFirstChildOfClass('SurfaceAppearance')
            assert(p.TextureID:match('^rbxassetid://%d+$')or surface and surface.ColorMap:match('^rbxassetid://%d+$'),
                'Missing native texture '..p.Name)
            out.resources[#out.resources+1]={name=p.Name,mesh=p.MeshId,texture=p.TextureID,colorMap=surface and surface.ColorMap}
        end
    end end
    assert(out.parts>0,'Empty visual model');return out
end
local function check(name,fn)
    local ok,value=xpcall(fn,debug.traceback)
    if ok then value=value or{};value.kind=name;report.rows[#report.rows+1]=value
    else report.errors[#report.errors+1]={kind=name,error=tostring(value)}end
end
local function fingerprint()
    local rows={}
    for _,p in ipairs(world.geometry:GetDescendants())do if p:IsA('BasePart')then
        rows[#rows+1]=p.Name..':'..tostring(p.Size)..':'..tostring(p.CFrame)..':'..tostring(p.CanCollide)..':'..tostring(p.CanQuery)..':'..tostring(p:GetAttribute('SurfaceId'))
    end end
    table.sort(rows);return table.concat(rows,'|')
end
local beforeGeometry=fingerprint()
check('FirstLevelEnvironment',function()
    for _,p in ipairs(world.geometry:GetDescendants())do if p:IsA('BasePart')then
        validatePart(p);assert(p.Anchored and not p.CanTouch,'Unexpected environment physical mode')
        local row=report.environment[p.Name]or{count=0,colliding=0,queryable=0}
        report.environment[p.Name]=row;row.count+=1
        if p.CanCollide then row.colliding+=1 end;if p.CanQuery then row.queryable+=1 end
    end end
    local kinds=0;for _ in pairs(report.environment)do kinds+=1 end
    assert(kinds>10 and #world.allFloors>0 and #world.floors>0,'Incomplete first-level geometry')
    for _,p in ipairs(world.allFloors)do assert(p.Parent==world.geometry and p:GetAttribute('SurfaceId'),'Invalid actual support registry')end
    return {geometryKinds=kinds,allFloors=#world.allFloors,activeFloors=#world.floors,renderer='AuthoredPrimitiveDistrictEnvironment'}
end)

local modes={'Default','Reflected','Bullet','Heavy','Ground','Carried','Thrown','Bolt','Snowball','GasCloud','Obstacle','RoboBolt',
    'StolenLife','ReturningLife','RavenClaw','DeadRaven'}
for n,mode in ipairs(modes)do check('Projectile:'..mode,function()
    local id=-20000-n;local point={x=(n-1)%8*6,y=5,z=120+math.floor((n-1)/8)*12}
    local selected=mode
    if mode=='Default'or mode=='Reflected'then selected=nil end
    assert(world:projectile(id,point,mode=='Reflected',selected))
    local actor=world.actors[id];local result=inspect(actor.model,true)
    assert(actor.root.Anchored and not actor.root.CanQuery)
    assert((actor.root.Position-(Vector3.new(point.x,point.y,point.z)+world.offset)).Magnitude<1e-5,'Projectile lost private offset')
    point.x+=1;assert(world:projectile(id,point,mode=='Reflected',selected)and world.actors[id]==actor,'Projectile movement replaced its actor')
    local old=actor.model;world:removeProjectile(id);assert(old.Parent==nil and not world.actors[id],'Projectile removal leaked')
    world:projectile(id,point,mode=='Reflected',selected)
    result.lifecyclePassed=true;result.renderer='ExistingProjectilePrimitive';return result
end)end
check('GuardianBall:SameActorStateTransitions',function()
    local id=-20900;local point={x=50,y=5,z=120};local model
    for _,mode in ipairs({'Heavy','Ground','Carried','Thrown'})do
        assert(world:projectile(id,point,false,mode));local actor=world.actors[id]
        model=model or actor.model;assert(actor.model==model,'Ball state transition replaced actor')
        assert(model:GetAttribute('Pickup')==(mode=='Ground')and model:GetAttribute('Carried')==(mode=='Carried'))
        if actor.pickupLabel then assert(actor.pickupLabel.Parent.Enabled==(mode=='Ground'))end
    end
    local result=inspect(model,true);result.lifecyclePassed=true;return result
end)

local hero
check('PrivateCanonicalHeroSetup',function()
    world.origins[1]=Vector3.new(18012,3,150)
    assert(world:spawn(1,'world-elements-qa:hero',nil,true,'Mr. Green'))
    hero=world.actors[1];assert(hero.appearance and hero.root.Anchored)
    return {health=hero.humanoid.Health,actorId=hero.model:GetAttribute('ActorId'),renderer='PreparedCanonicalHero'}
end)
local health=hero and hero.humanoid.Health
check('WalkerClub:Ground',function()
    world:clubItem('qa-club',{x=0,y=2,z=150});local item=world.clubItems['qa-club'];local result=inspect(item.model,true)
    assert(item.model:GetAttribute('ItemKind')=='WalkerClub'and result.queryable==0)
    local old=item.model;world:clubItem('qa-club',{x=5,y=2,z=150});assert(world.clubItems['qa-club'].model==old)
    world:clubItem('qa-club',nil);assert(old.Parent==nil and not world.clubItems['qa-club'])
    world:clubItem('qa-club',{x=0,y=2,z=150});result.lifecyclePassed=true;return result
end)
check('WalkerClub:EquippedSwing',function()
    assert(hero and world:equipClub('qa-equipped',1))
    local equipped=world.equippedClubs['qa-equipped'];local result=inspect(equipped.model,true)
    assert(result.massless==result.parts and result.anchored==0 and result.queryable==0)
    assert(world:clubSwing('qa-equipped',1)and equipped.model:GetAttribute('Swinging')==true)
    local old=equipped.model;world:unequipClub('qa-equipped');assert(old.Parent==nil and not world.equippedClubs['qa-equipped'])
    assert(world:equipClub('qa-equipped',1));result.lifecyclePassed=true;return result
end)
check('RavenClaw:Equipped',function()
    assert(hero);world:campaignClaw(1,true)
    local claw=assert(hero.model:FindFirstChild('CampaignRavenClaw'));validatePart(claw)
    assert(not claw.CanCollide and not claw.CanTouch and not claw.CanQuery and claw.Massless and not claw.Anchored)
    world:campaignClaw(1,false);assert(claw.Parent==nil)
    world:campaignClaw(1,true);return {lifecyclePassed=true,renderer='ExistingEquippedPrimitive'}
end)
local session={now=100,sourceCombat=true,state={levelEpoch=1,heroes={[1]={status='Alive',actorId='world-elements-qa:hero',connected=true}}},
    combat={[1]={rawLife=47,reactionEpoch=0}}}
check('HealingFly:ActualSourceSkin',function()
    world:healingFly('qa-fly',{x=22,y=7,z=150});local fly=assert(world.healingFlyVisuals['qa-fly'])
    assert(not world.actors['qa-fly'],'Fly entered combat actor table')
    world:updatePresentation(session,.1,{},nil)
    local skin=assert(fly.castActor and fly.castActor.castAppearance,'Missing actual HealingFly skin')
    assert(skin.pose and skin.pose.kind=='HealingFly')
    local result=inspect(fly.model,true);result.sourceFrame=skin.pose.frameId;result.namespace=skin.pose.namespace
    local old=fly.model;world:healingFly('qa-fly',{x=24,y=8,z=150});assert(fly.model==old)
    assert((fly.root.Position-Vector3.new(18024,8,150)).Magnitude<1e-5,'Fly private offset incorrect')
    world:healingFly('qa-fly',nil);assert(old.Parent==nil and not world.healingFlyVisuals['qa-fly'])
    world:healingFly('qa-fly',{x=22,y=7,z=150});result.lifecyclePassed=true;return result
end)
check('HealingCatch:TongueFlashExpiry',function()
    assert(hero and world:catchFly(1,'qa-fly'))
    local count,model=0,nil;for m in pairs(world.healingEffects)do count+=1;model=m end
    assert(count==1 and model);local result=inspect(model,true);assert(result.queryable==0)
    for i=1,3 do session.now+=.1;world:updatePresentation(session,.1,{},nil)end
    assert(model.Parent==nil and next(world.healingEffects)==nil,'Finite catch effect did not expire')
    world:healingFly('qa-fly',{x=22,y=7,z=150});session.now+=.1;world:updatePresentation(session,.1,{},nil)
    result.lifecyclePassed=true;return result
end)
check('WalkerClub:FiniteRecovery',function()
    local equipped=assert(world.equippedClubs['qa-equipped'])
    assert(world:clubSwing('qa-equipped',1)and equipped.swingUntil
        and equipped.model:GetAttribute('Swinging')==true,'Start a real swing on the newly equipped model')
    for _=1,4 do session.now+=.1;world:updatePresentation(session,.1,{},nil)end
    assert(not equipped.swingUntil and equipped.model:GetAttribute('Swinging')==false,'Club swing failed to expire')
    return {lifecyclePassed=true}
end)
check('DragonFire:NativePrimitive',function()
    world:dragonFire('qa-fire',{x=30,y=6,z=150});local p=assert(world.dragonFires['qa-fire']);validatePart(p)
    assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
    world:dragonFire('qa-fire',{x=32,y=6,z=150});assert(world.dragonFires['qa-fire']==p)
    world:removeDragonFire('qa-fire');assert(p.Parent==nil)
    world:dragonFire('qa-fire',{x=30,y=6,z=150});return {lifecyclePassed=true,renderer='ExistingFireSphere'}
end)
check('GuardianIntro:FootAndRipples',function()
    local state={id='world-elements-qa:intro',runId='world-elements-qa',levelEpoch=1,active=true,
        counter=0x64,phase='Stomp',footFrame=0x12,cameraCut=false,fearFrame=0x32,startedAt=100,
        bossPosition={x=45,y=3,z=150}}
    world:bossIntro(state);local folder=assert(world.bossIntroFolder);local result=inspect(folder,true)
    assert(result.queryable==0 and folder:GetAttribute('IntroId')==state.id)
    state.counter=0x80;world:bossIntro(state);assert(world.bossIntroFolder==folder)
    world:bossIntro(nil);assert(folder.Parent==nil and not world.bossIntroFolder)
    world:bossIntro(state);result.lifecyclePassed=true;return result
end)
assert(not hero or hero.humanoid.Health==health,'Fixture changed its own hero HP unexpectedly')
assert(fingerprint()==beforeGeometry,'World props changed the private first-level geometry')
assert(workspace:FindFirstChild('Baseplate')==baseplate and workspace:FindFirstChild('SpawnLocation')==spawn,'Blank-place defaults changed')
assert(lighting.ClockTime==lightBefore[1]and lighting.Brightness==lightBefore[2]
    and lighting.FogStart==lightBefore[3]and lighting.FogEnd==lightBefore[4],'Global Lighting changed')
report.privateHeroHealthPreserved=true;report.environmentPreserved=true;report.globalDefaultsPreserved=true
local read=Instance.new('BindableFunction');read.Name='Read';read.Parent=owner
read.OnInvoke=function()return game:GetService('HttpService'):JSONEncode(report)end
local cleanup=Instance.new('BindableFunction');cleanup.Name='Cleanup';cleanup.Parent=owner
cleanup.OnInvoke=function()world:clearActors();world.folder:Destroy();owner:Destroy();return true end
return {rows=#report.rows,errors=report.errors,gallery=world.folder:GetFullName(),read=read:GetFullName()}
