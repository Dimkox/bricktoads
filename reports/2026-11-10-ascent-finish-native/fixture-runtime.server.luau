-- Isolated prepared server proof. Ordinary Session inputs from authored spawn;
-- fixed-step Modes simulation first, then real Heartbeats after native release.
-- Own cloned modules/world only. No Players, main hub, health or stock writes.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer(),'Studio Server only')
local Http=game:GetService('HttpService')
local folder=script.Parent
local output=folder:FindFirstChild('Result') or Instance.new('StringValue')
output.Name='Result';output.Parent=folder
folder:SetAttribute('Status','running')
local result={status='running',scenario='prepared_native_ascent_finish_handoff',cases={},
    oldPilotCommit='da2babf',sourceSha256=folder:GetAttribute('ProductionSourceSha256'),
    baselineModesSha256=folder:GetAttribute('BaselineModesSha256'),
    oldPilotSha256=folder:GetAttribute('OldPilotSha256'),seed=folder:GetAttribute('Seed') or 2104255637,
    limits={'Synthetic server roster; no actual Players, client/network or full-playthrough claim',
        'Real Modes/Session fixed-step inputs from authored spawn; no prepared hero poses',
        'NPC controllers are not constructed; authored geometry and course hazards remain active',
        'Course simulation advances faster than wall clock; post-release samples use actual physics Heartbeats'}}
local owned={}
local function plain(p) return {x=p.X,y=p.Y,z=p.Z} end
local function save() output.Value=Http:JSONEncode(result) end
local function runCase(label)
    -- MCP prepares these owned module clones before this ordinary Script runs;
    -- runtime Scripts cannot read or write protected ModuleScript.Source.
    local project=assert(folder:FindFirstChild('OwnedModules_'..label))
    owned[#owned+1]=project
    local G,R=project.gameplay,project.CombatRuntime
    local definition=require(G.CampaignDefinition).build(8,result.seed)
    local config=require(G.GameConfig)(require(R.Config),definition)
    local World=require(G.GameWorld)
    local Session,Combat=require(R.Session),require(R.Combat)
    for _,name in ipairs({'Baseplate','SpawnLocation'}) do assert(not workspace:FindFirstChild(name),'Refuse shared default migration: '..name) end
    local lighting=game:GetService('Lighting');local saved={}
    for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do saved[key]=lighting[key] end
    local atmosphere=lighting:FindFirstChild('CausewayAtmosphere');local savedAir={}
    if atmosphere then for _,key in ipairs({'Density','Offset','Color','Decay','Glare','Haze'}) do savedAir[key]=atmosphere[key] end end
    local made,world=pcall(World.new,require(R.RobloxWorld),config,{name='AscentFinishWorld_'..label..'_'..Http:GenerateGUID(false),
        offset={x=0,y=32,z=24576},campaignWorld=require(G.CampaignWorld)})
    for key,value in pairs(saved) do lighting[key]=value end
    if atmosphere then for key,value in pairs(savedAir) do atmosphere[key]=value end
    else local created=lighting:FindFirstChild('CausewayAtmosphere');if created then created:Destroy() end end
    assert(made,world);owned[#owned+1]=world.folder
    local case={label=label,intentCounts={},releaseSamples={},sourceMatchesBaseline=project:GetAttribute('MatchesBaseline')==true,
        startedAt=workspace:GetServerTimeNow(),preparation={authoredSpawn=true,preparedPoses=false,npcControllers=false}}
    result.cases[#result.cases+1]=case
    local session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=1,template='Mr. Green'}},
        'ascent-fixture-'..Http:GenerateGUID(false),world,nil,{groupId='isolated-ascent-fixture',levelId=definition.id})
    local now=0;assert(session:step(now)=='OK')
    local modes=require(G.CampaignModes).new(session,world,definition);world.campaignModes=modes
    local pilotModule=folder.OldPilot:Clone();pilotModule.Parent=project
    local pilot=require(pilotModule)
    local actor=assert(modes.actors[1]);local body=assert(world.actors[1]);local seq=0
    local initial={actorId=session.state.heroes[1].actorId,stock=session.state.heroes[1].respawns,
        attempt=session.state.heroes[1].attempt,rawLife=session.combat[1].rawLife,position=world:position(1)}
    case.initial=initial
    local finalFloor=assert(world.geometry:FindFirstChild('CourseSupport_'..#definition.course.platforms))
    local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances={world.geometry};overlap.RespectCanCollide=true
    local function sample()
        local position=body.root.Position-world.offset
        local floorPoint=finalFloor.CFrame:PointToObjectSpace(body.root.Position)
        local contacts={}
        for _,part in ipairs(body.model:GetDescendants()) do if part:IsA('BasePart') and part.CanCollide then
            for _,hit in ipairs(workspace:GetPartsInPart(part,overlap)) do
                contacts[#contacts+1]={bodyPart=part.Name,geometry=hit.Name}
            end
        end end
        return {at=workspace:GetServerTimeNow(),simulationNow=now,logicalPosition=table.clone(actor.position),
            physicalPosition=plain(position),velocity=plain(body.root.AssemblyLinearVelocity),
            grounded=actor.grounded,support=actor.support,finished=actor.finished,complete=modes.complete,
            anchored=body.root.Anchored,platformStand=body.humanoid.PlatformStand,
            nativeState=body.humanoid:GetState().Name,floorMaterial=tostring(body.humanoid.FloorMaterial),
            finalFloor={name=finalFloor.Name,top=finalFloor.Position.Y+finalFloor.Size.Y/2-world.offset.Y,
                standingY=finalFloor.Position.Y+finalFloor.Size.Y/2-world.offset.Y+3,
                rootInside=math.abs(floorPoint.X)<finalFloor.Size.X/2 and math.abs(floorPoint.Y)<finalFloor.Size.Y/2 and math.abs(floorPoint.Z)<finalFloor.Size.Z/2},
            collidableOverlaps=contacts,resources={actorId=session.state.heroes[1].actorId,
                stock=session.state.heroes[1].respawns,attempt=session.state.heroes[1].attempt,
                rawLife=session.combat[1].rawLife,status=session.state.heroes[1].status}}
    end
    local function send(kind,extra)
        seq+=1;local h=session.state.heroes[1]
        local p={kind=kind,runId=session.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=session.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
        for key,value in pairs(extra or {}) do p[key]=value end
        local code=session:intent(1,p,now)
        local key=kind..':'..code;case.intentCounts[key]=(case.intentCounts[key] or 0)+1
        assert(code=='OK','Unexpected ordinary input rejection: '..key)
    end
    -- The real safe-spawn search may choose X=-6.8 to avoid a low ceiling.
    -- Center with ordinary movement before invoking the unchanged old pilot.
    case.preparation.entryAlignment='Ordinary Move from actual safe spawn to center X0; no pose preparation'
    for frame=1,180 do
        local dx=-actor.position.x
        if math.abs(dx)<.08 then send('Move',{x=0,z=0,run=false});break end
        if frame%2==1 then send('Move',{x=math.clamp(dx*.4,-1,1),z=0,run=false}) end
        now+=1/60;assert(session:step(now)=='OK');modes:step(now,1/60)
    end
    case.aligned=sample()
    for frame=1,2400 do
        local p=pilot.plan({definition=definition,modes=modes,actor=actor,slot=1,now=now,dt=1/60,
            stageToken=label,world=world,position=world:position(1)})
        if frame%2==1 then send('Move',{x=p.x or 0,z=p.z or 0,run=p.run==true}) end
        if p.jump then send('Jump') end
        now+=1/60;assert(session:step(now)=='OK');modes:step(now,1/60)
        if actor.finished then case.release=sample();case.framesToRelease=frame;break end
        assert(session.state.heroes[1].status=='Alive','Ordinary course fixture lost hero before finish')
        if frame%120==0 then case.last=sample();save();task.wait() end
    end
    assert(case.release,'No normal-input course finish within40 simulated seconds')
    for _=1,30 do
        RunService.Heartbeat:Wait()
        case.releaseSamples[#case.releaseSamples+1]=sample()
    end
    case.minimumPostReleaseY=case.release.physicalPosition.y
    for _,row in ipairs(case.releaseSamples) do case.minimumPostReleaseY=math.min(case.minimumPostReleaseY,row.physicalPosition.y) end
    case.complete=true
    modes:close('OwnedFixtureCleanup');world:clearActors();world.folder:Destroy();project:Destroy()
    case.cleanup=true
end
local ok,err=xpcall(function()
    runCase('baseline')
    if folder:FindFirstChild('OwnedModules_fixed') then runCase('fixed') end
end,debug.traceback)
for _,object in ipairs(owned) do if object.Parent then object:Destroy() end end
result.status=ok and 'complete' or 'failed';result.error=not ok and tostring(err) or nil
result.cleanup=true;folder:SetAttribute('Status',result.status);save()
