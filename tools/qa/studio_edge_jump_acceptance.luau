-- Isolated native unit fixture only. Never counts as a campaign playthrough.
-- Install as a Script beside owned BaselineWorld/FixedWorld ModuleScripts and
-- Result BindableFunction. The installer clones the real production adapters;
-- only BaselineWorld has the new climbing-support acceptance removed.
-- Initial synthetic-body poses are explicit fixture preparation. After that,
-- movement/jumps use ordinary World APIs and native physics without state forcing.
assert(game:GetService('RunService'):IsStudio(),'Studio fixture only')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Lighting=game:GetService('Lighting')
local owner=script.Parent
local resultFunction=owner:WaitForChild('Result')
local project=game.ServerScriptService:WaitForChild('BrickToads')
local Base=require(project.CombatRuntime.RobloxWorld)
local Baseline,Fixed=require(owner.BaselineWorld),require(owner.FixedWorld)
local CharacterAppearance=require(project.gameplay.CharacterAppearance)
local result={status='Running',kind='isolated-native-edge-jump-unit-fixture',
    preparation='Two synthetic R6 bodies begin just beyond the edge at local (46.7,3,-3.5528), fall without movement, then steer into the floor face below its top. No Humanoid state is forced.',
    limitations='Prepared unit fixture only; no campaign clear, actual player input, client/network/device or full-playthrough claim.',
    cases={},cleanup={}}
resultFunction.OnInvoke=function() return Http:JSONEncode(result) end
local fixtures={}
local function snapshot(body,world)
    local p=body.root.Position-world.offset;local v=body.root.AssemblyLinearVelocity
    return {position={x=p.X,y=p.Y,z=p.Z},velocity={x=v.X,y=v.Y,z=v.Z},
        state=body.humanoid:GetState().Name,floor=body.humanoid.FloorMaterial.Name,
        health=body.humanoid.Health,anchored=body.root.Anchored,platformStand=body.humanoid.PlatformStand,
        consumed=body.routeJumpSupport and body.routeJumpSupport.consumed or false,
        groundedAt=body.routeJumpSupport and body.routeJumpSupport.groundedAt or nil}
end
local function footprintSupport(fixture)
    local root,world=fixture.body.root,fixture.world
    local right=Vector3.new(root.CFrame.RightVector.X,0,root.CFrame.RightVector.Z)*(root.Size.X/2)
    local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)*(root.Size.Z/2)
    for _,offset in ipairs({Vector3.zero,forward,-forward,right,-right,right+forward,right-forward,-right+forward,-right-forward}) do
        local hit=workspace:Raycast(root.Position+offset,Vector3.new(0,-3.4,0),world.ray)
        if hit and hit.Normal.Y>=.95 and not hit.Instance:GetAttribute('Hazard') and hit.Instance:GetAttribute('SurfaceId') then return true end
    end
    return false
end
local function construct(class,label,z)
    -- The production constructor has synchronous presentation side effects.
    -- Restore them before yielding so the running campaign sees no change.
    local light,atmosphereBefore={},{}
    for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do light[key]=Lighting[key] end
    local atmosphere=assert(Lighting:FindFirstChild('CausewayAtmosphere'),'Existing production lighting required')
    for _,key in ipairs({'Density','Offset','Color','Decay','Glare','Haze'}) do atmosphereBefore[key]=atmosphere[key] end
    assert(not workspace:FindFirstChild('Baseplate') and not workspace:FindFirstChild('SpawnLocation'),'Do not allow the constructor to remove another world default')
    local definition=require(project.gameplay.LevelDefinition)
    local fixture={name=owner.Name..'_'..label,label=label}
    fixtures[#fixtures+1]=fixture
    local okay,world=pcall(class.new,Base,{FallY=-20,WalkSpeed=16,JumpPower=50,MoveTimeout=.35,
        Movement={heroRunSpeed=24,enemyRunSpeed=16,runThresholdRatio=.75},Level=definition},
        {name=fixture.name,offset={x=0,y=100,z=z},characterAppearance=CharacterAppearance})
    for key,value in pairs(light) do Lighting[key]=value end
    for key,value in pairs(atmosphereBefore) do atmosphere[key]=value end
    assert(okay,world)
    fixture.world=world
    -- Replace geometry only in this newly owned fixture world, retaining the
    -- production route's real physical floor shapes for the observed gap.
    world.geometry:ClearAllChildren();world.allFloors={};world.floors={}
    for n,row in ipairs({{25,-1,42},{88,1,76}}) do
        local floor=Instance.new('Part');floor.Name='FixtureSupport'..n
        floor.Size=Vector3.new(row[3],2,38);floor.CFrame=CFrame.new(Vector3.new(row[1],row[2],0)+world.offset)
        floor.Anchored=true;floor.CanCollide=true;floor.Material=Enum.Material.Slate
        floor:SetAttribute('SurfaceId','isolated-edge-'..n);floor:SetAttribute('ZoneIndex',1);floor.Parent=world.geometry
        world.allFloors[#world.allFloors+1]=floor;world.floors[#world.floors+1]=floor
    end
    assert(world:spawn(1,'native-edge-'..label,nil,false,'Mr. Green'),'Fixture spawn failed')
    fixture.body=world.actors[1]
    local p=world.offset+Vector3.new(46.7,3,-3.5528)
    fixture.body.model:PivotTo(CFrame.lookAt(p,p+Vector3.xAxis))
    fixture.body.root.AssemblyLinearVelocity=Vector3.zero
    fixture.body.root.AssemblyAngularVelocity=Vector3.zero
    fixture.start=snapshot(fixture.body,world)
    fixture.phase='Drop';fixture.trace={};fixture.nextTrace=0
    return fixture
end
local function naturallyClimbing(fixture)
    local body=fixture.body
    return body.humanoid:GetState()==Enum.HumanoidStateType.Climbing
        and body.humanoid.FloorMaterial==Enum.Material.Air
        and math.abs(body.root.AssemblyLinearVelocity.Y)<1 and footprintSupport(fixture)
end
local okay,failure=xpcall(function()
    local baseline=construct(Baseline,'baseline',24000)
    local fixed=construct(Fixed,'fixed',26000)
    result.cases.baseline={initial=baseline.start};result.cases.fixed={initial=fixed.start}
    local start=workspace:GetServerTimeNow()
    while workspace:GetServerTimeNow()-start<5 do
        local elapsed=workspace:GetServerTimeNow()-start
        for _,fixture in ipairs(fixtures) do
            local y=fixture.body.root.Position.Y-fixture.world.offset.Y
            if fixture.phase=='Drop' and y<=.9 then fixture.phase='Backstep' end
            if naturallyClimbing(fixture) then fixture.phase='Found' end
            fixture.world:move(1,fixture.phase=='Backstep' and -1 or 0,0,false)
            if elapsed>=fixture.nextTrace then
                local row=snapshot(fixture.body,fixture.world);row.elapsed=elapsed;row.phase=fixture.phase
                fixture.trace[#fixture.trace+1]=row;fixture.nextTrace=elapsed+.1
            end
        end
        RunService.Heartbeat:Wait()
        if baseline.phase=='Found' and fixed.phase=='Found' then break end
    end
    for _,fixture in ipairs(fixtures) do fixture.world:move(1,0,0,false) end
    -- Native contact must persist after ordinary movement stops.
    local settle=workspace:GetServerTimeNow()
    while workspace:GetServerTimeNow()-settle<.25 do RunService.Heartbeat:Wait() end
    result.cases.baseline.before=snapshot(baseline.body,baseline.world)
    result.cases.fixed.before=snapshot(fixed.body,fixed.world)
    result.cases.baseline.safeFootprint=footprintSupport(baseline)
    result.cases.fixed.safeFootprint=footprintSupport(fixed)
    result.cases.baseline.trace=baseline.trace;result.cases.fixed.trace=fixed.trace
    if not naturallyClimbing(baseline) or not naturallyClimbing(fixed) then
        result.status='NotReproduced'
        result.reason='Both prepared native bodies did not naturally retain Climbing/Air with safe footprint; no forced-state substitute was used.'
        return
    end
    for _,fixture in ipairs(fixtures) do
        fixture.world:jump(1)
        result.cases[fixture.label].immediate=snapshot(fixture.body,fixture.world)
        fixture.maxY=fixture.body.root.Position.Y
    end
    local flightStart=workspace:GetServerTimeNow();local repeated=false
    while workspace:GetServerTimeNow()-flightStart<.35 do
        RunService.Heartbeat:Wait()
        for _,fixture in ipairs(fixtures) do fixture.maxY=math.max(fixture.maxY,fixture.body.root.Position.Y) end
        if not repeated and workspace:GetServerTimeNow()-flightStart>=.1 then
            result.cases.fixed.repeatBefore=snapshot(fixed.body,fixed.world)
            fixed.world:jump(1)
            result.cases.fixed.repeatAfter=snapshot(fixed.body,fixed.world)
            repeated=true
        end
    end
    for _,fixture in ipairs(fixtures) do
        local case=result.cases[fixture.label]
        case.after=snapshot(fixture.body,fixture.world)
        case.maxRise=fixture.maxY-fixture.world.offset.Y-case.before.position.y
    end
    local old,new=result.cases.baseline,result.cases.fixed
    result.checks={baselineRejected=math.abs(old.immediate.velocity.y-old.before.velocity.y)<.001,
        fixedJumpPower=math.abs(new.immediate.velocity.y-50)<.001,
        nativeRise=new.maxRise>2,
        consumedWithoutGroundHistory=new.immediate.consumed and new.immediate.groundedAt==nil,
        noAirJump=math.abs(new.repeatAfter.velocity.y-new.repeatBefore.velocity.y)<.001}
    result.status='Passed'
    for _,value in pairs(result.checks) do if not value then result.status='Failed' end end
end,debug.traceback)
if not okay then result.status='Error';result.error=tostring(failure) end
for _,fixture in ipairs(fixtures) do
    local world=fixture.world
    if world and world.folder and world.folder.Parent then world.folder:Destroy() end
    local left=workspace:FindFirstChild(fixture.name)
    if left then left:Destroy() end
    result.cleanup[fixture.label]=workspace:FindFirstChild(fixture.name)==nil
end
result.finishedAt=DateTime.now():ToIsoDate()
resultFunction:SetAttribute('Status',result.status)
