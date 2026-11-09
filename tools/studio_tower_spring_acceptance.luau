-- Studio-only prepared acceptance. Execute on the server after syncing sources.
-- Synthetic Session roster, selected stages/course times and takeoff poses are
-- explicit. This is native geometry/runtime evidence, not network/device input
-- acceptance or a route clear. No health, stock, attempt or actor-ID writes.
assert(game:GetService('RunService'):IsStudio(), 'Studio acceptance only')
local Http=game:GetService('HttpService')
local project=game:GetService('ServerScriptService'):WaitForChild('BrickToads')
local G,R=project.gameplay,project.CombatRuntime
local World=require(G.GameWorld)
require(G.DragonWorld)(World)
local Session=require(R.Session)
local Combat=require(R.Combat)
local definitions=require(G.CampaignDefinition)
local deps={CampaignDefinition=definitions,CampaignModes=require(G.CampaignModes),CampaignBoss=require(G.CampaignBoss),
    CampaignEnemies=require(G.CampaignEnemies),Director=require(G.LevelDirector),GuardianPattern=require(G.GuardianPattern),
    HealingFlies=require(G.HealingFlies),EnemyCarry=require(G.EnemyCarry),WalkerClubs=require(G.WalkerClubs),
    DragonFlight=require(G.DragonFlight),BossIntro=require(G.BossIntro)}
local result={sourceSha256=require(project.BuildInfo).sourceSha256,checks={},geometry={},jumps={},cleanup={},
    fixture='Prepared stages12/8, course times and takeoff poses; real Session Jump, CampaignDirector, GameWorld, CampaignWorld and native Models',
    limitations='Synthetic server roster; ordinary AI deliberately unstepped in isolated worlds; no network, keyboard, touch or full-route acceptance'}
local created={}
local function check(name,condition)
    assert(condition,name)
    result.checks[#result.checks+1]=name
end
local function near(a,b) return math.abs(a-b)<.001 end
local function vector(v) return {x=v.X,y=v.Y,z=v.Z} end
local function samePoint(a,b) return (a-b).Magnitude<.001 end
local function sameFrame(a,b)
    return samePoint(a.Position,b.Position) and samePoint(a.RightVector,b.RightVector) and samePoint(a.LookVector,b.LookVector)
end
local function resources(f)
    local h=f.session.state.heroes[1]
    return {runId=f.session.state.runId,levelEpoch=f.session.state.levelEpoch,actorId=h.actorId,
        attempt=h.attempt,rawLife=f.session.combat[1].rawLife,respawns=h.respawns,health=h.health,status=h.status}
end
local function preserved(f,before,label)
    local after=resources(f)
    for key,value in pairs(before) do check(label..' preserves '..key,after[key]==value) end
    check(label..' preserves native body',f.world.actors[1]==f.body and f.body.model==f.model)
    return after
end
local function begin(index,offset)
    local definition=definitions.build(index,11939)
    local config=require(G.GameConfig)(require(R.Config),definition)
    local world=World.new(require(R.RobloxWorld),config,{name='BrickToadsTowerSpringQA_'..index..'_'..Http:GenerateGUID(false),
        offset={x=0,y=32,z=offset},characterAppearance=require(G.CharacterAppearance),
        guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    local f={definition=definition,config=config,world=world,now=workspace:GetServerTimeNow(),seq=0}
    created[#created+1]=f
    f.session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'}},
        'native-spring-'..index..'-'..Http:GenerateGUID(false),world,nil,{groupId='native-spring-fixture',levelId=definition.id})
    check('stage '..index..' initial spawn',f.session:step(f.now)=='OK')
    f.director=require(G.CampaignDirector).new(f.session,world,Combat,config,deps)
    require(G.SourceCombat).bind(f.session,f.director,config)
    f.session.contextualAttack=function(slot,now,action) return f.director:interact(slot,now,action) end
    f.modes=f.director.modes
    f.body=assert(world.actors[1],'Real Session must spawn a native body')
    f.model=f.body.model
    check('stage '..index..' native Model',f.model:IsA('Model') and f.model:IsDescendantOf(workspace)
        and f.body.root:IsA('BasePart') and f.body.humanoid:IsA('Humanoid'))
    f.baseline=resources(f)
    return f
end
local function courseTime(f,seconds)
    -- Explicit prepared phase selection; ordinary combat is not advanced.
    f.modes.elapsed=seconds
    f.modes.rotation=seconds*(f.definition.course.rotationSpeed or 0)
    f.modes.previousRotation=f.modes.rotation
    f.modes:_objects(0)
end
local function object(f,id)
    return assert(f.world.campaignWorld.objects[id],'Missing native object '..id).part
end
local function raySupport(f,position,expected,label)
    local hit=workspace:Raycast(position,Vector3.new(0,-3.7,0),f.world.ray)
    check(label..' native support',hit~=nil and hit.Instance==expected and hit.Normal.Y>.99)
    return {name=hit.Instance.Name,surface=hit.Instance:GetAttribute('SurfaceId'),position=vector(hit.Position)}
end
local function towerGeometry(f,seconds)
    courseTime(f,seconds)
    local frames={}
    for n,spring in ipairs(f.definition.course.springs) do
        local platform=assert(f.definition.course.towerPlatforms[spring.towerPlatform],'Spring needs an authored platform binding')
        -- Expected pose derives independently from the authored platform and
        -- selected rotation, never from Modes:_springPose or rendered spring.
        local angle=platform.angle+seconds*f.definition.course.rotationSpeed
        local expected=CFrame.new(math.cos(angle)*platform.radius,spring.y,math.sin(angle)*platform.radius)
            *CFrame.Angles(0,-angle,0)+f.world.offset
        local part=object(f,'spring-'..n)
        local support=object(f,'tower-'..spring.towerPlatform)
        local label='Tower spring '..n..' at '..seconds..'s'
        check(label..' native CFrame',sameFrame(part.CFrame,expected))
        check(label..' remains noncollidable',not part.CanCollide and not part.CanQuery)
        check(label..' platform remains collidable',support.CanCollide and support.CanQuery)
        local hit=raySupport(f,expected.Position,support,label)
        frames[n]=part.CFrame
        result.geometry[#result.geometry+1]={stage=12,spring=n,time=seconds,rotation=f.modes.rotation,
            cframe={part.CFrame:GetComponents()},support=hit}
    end
    return frames
end
local function prepareTakeoff(f,position,expectedSupport,supportId,label)
    -- One explicit takeoff pose per case, never navigation by repeated teleport.
    local s=f.modes.actors[1]
    s.position={x=position.X-f.world.offset.X,y=position.Y-f.world.offset.Y,z=position.Z-f.world.offset.Z}
    s.previous=table.clone(s.position);s.velocity={x=0,y=0,z=0}
    s.grounded=false;s.support=nil;s.airSpeed=nil;s.external=nil
    s.input={x=0,z=0,run=false,at=f.modes.now}
    f.modes:_ground(s,s.previous,0)
    check(label..' real mode grounding',s.grounded and (not supportId or s.support==supportId))
    check(label..' native pose',f.world:campaignPose(1,s.position,f.definition.mode,s.velocity))
    check(label..' native position',samePoint(f.body.root.Position,position))
    check(label..' World grounded ray',f.world:campaignGrounded(1))
    return raySupport(f,position,expectedSupport,label)
end
local function jumpInput(f)
    f.seq+=1;f.now+=.01
    local h=f.session.state.heroes[1]
    return f.session:intent(1,{kind='Jump',runId=f.session.state.runId,actorId=h.actorId,attempt=h.attempt,
        levelEpoch=f.session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=f.seq},f.now)
end
local function jumpCase(f,label,position,support,supportId,power)
    local nativeSupport=prepareTakeoff(f,position,support,supportId,label)
    local before=resources(f)
    check(label..' baseline unchanged',before.actorId==f.baseline.actorId and before.attempt==f.baseline.attempt
        and before.rawLife==f.baseline.rawLife and before.respawns==f.baseline.respawns)
    local startY=f.body.root.Position.Y
    local code=jumpInput(f)
    local s=f.modes.actors[1]
    local launch=s.velocity.y
    check(label..' validated Session Jump',code=='OK')
    check(label..' launch power '..power,near(launch,power) and not s.grounded and s.support==nil)
    f.now+=1/60
    check(label..' Session slice',f.session:step(f.now)=='OK')
    f.modes:step(f.now,1/60)
    f.world:updatePresentation(f.session,1/60,f.director.enemies)
    check(label..' native Model rises',f.body.root.Position.Y>startY+.5 and f.body.campaignVelocity.Y>0)
    local airborneVelocity=s.velocity.y
    local airborneCode=jumpInput(f)
    -- Session acknowledges a valid Jump packet; the existing course API
    -- rejects the airborne effect by retaining velocity, not by an error code.
    check(label..' airborne second jump adds no impulse',airborneCode=='OK' and not s.grounded and near(s.velocity.y,airborneVelocity))
    local after=preserved(f,before,label)
    result.jumps[#result.jumps+1]={case=label,stage=f.definition.campaignIndex,launchVelocity=launch,
        nativeRise=f.body.root.Position.Y-startY,nativeVelocity=vector(f.body.campaignVelocity),
        sessionJump=code,airborneJump=airborneCode,airborneImpulseRejected=true,support=nativeSupport,before=before,after=after}
end
local ok,err=xpcall(function()
    local tower=begin(12,61440)
    check('Tower has both springs',#tower.definition.course.springs==2)
    local first=towerGeometry(tower,0)
    local rotated=towerGeometry(tower,5)
    for n=1,2 do
        check('Tower spring '..n..' travels with rotation',(first[n].Position-rotated[n].Position).Magnitude>10)
        check('Tower spring '..n..' rotates its footprint',(first[n].RightVector-rotated[n].RightVector).Magnitude>.5)
    end
    for n,spring in ipairs(tower.definition.course.springs) do
        courseTime(tower,6+n)
        local part=object(tower,'spring-'..n)
        local support=object(tower,'tower-'..spring.towerPlatform)
        jumpCase(tower,'Tower spring '..n,part.Position,support,'tower-'..spring.towerPlatform,65)
        courseTime(tower,6+n+.25)
        part=object(tower,'spring-'..n)
        -- Seven local studs is outside the preserved 4+1-stud spring margin,
        -- while remaining on its actual nine-stud-halfwidth native platform.
        jumpCase(tower,'Tower off-pad '..n,part.CFrame:PointToWorldSpace(Vector3.new(7,0,0)),support,
            'tower-'..spring.towerPlatform,52)
    end
    preserved(tower,tower.baseline,'Tower complete fixture')
    local ascent=begin(8,61952)
    check('Ascent keeps its static spring',#ascent.definition.course.springs==1)
    courseTime(ascent,0)
    local fixed=object(ascent,'spring-1').CFrame
    courseTime(ascent,5)
    local part=object(ascent,'spring-1')
    check('Ascent spring stays static',sameFrame(fixed,part.CFrame))
    local hit=workspace:Raycast(part.Position,Vector3.new(0,-3.7,0),ascent.world.ray)
    check('Ascent spring has native support',hit~=nil and hit.Normal.Y>.99)
    result.geometry[#result.geometry+1]={stage=8,spring=1,time=5,cframe={part.CFrame:GetComponents()},static=true}
    jumpCase(ascent,'Ascent static spring',part.Position,hit.Instance,nil,68)
    preserved(ascent,ascent.baseline,'Ascent complete fixture')
    result.status='PASS'
end,debug.traceback)
if not ok then result.status='FAIL';result.error=tostring(err) end
for _,f in ipairs(created) do
    local row={stage=f.definition.campaignIndex,errors={}}
    local function teardown(name,callback)
        local closed,closeError=pcall(callback)
        if not closed then row.errors[#row.errors+1]=name..': '..tostring(closeError) end
    end
    if f.director then teardown('director close',function() f.director:close('AcceptanceClosed') end) end
    teardown('actor clear',function() f.world:clearActors() end)
    teardown('world destroy',function() f.world.folder:Destroy() end)
    row.worldRemoved=f.world.folder.Parent==nil
    row.actorRegistryEmpty=next(f.world.actors)==nil
    row.nativeBodyRemoved=not f.body or (f.body.model.Parent==nil and f.body.root.Parent==nil)
    row.pass=#row.errors==0 and row.worldRemoved and row.actorRegistryEmpty and row.nativeBodyRemoved
    result.cleanup[#result.cleanup+1]=row
    if not row.pass then result.status='FAIL';result.cleanupFailed=true end
end
_G.BrickToadsTowerSpringAcceptance=result
return Http:JSONEncode(result)
