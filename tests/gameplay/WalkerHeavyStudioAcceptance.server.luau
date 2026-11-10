-- Isolated engine fixture. It has no entrypoint in the normal playable build.
local RunService=game:GetService('RunService')
if not RunService:IsStudio() or not RunService:IsServer() then return end

local HttpService=game:GetService('HttpService')
local ServerStorage=game:GetService('ServerStorage')
local Players=game:GetService('Players')
Players.CharacterAutoLoads=false

local resultFolder=Instance.new('Folder')
resultFolder.Name='WalkerHeavyAcceptance_'..HttpService:GenerateGUID(false)
resultFolder.Parent=ServerStorage
local output=Instance.new('StringValue')
output.Name='Result'; output.Parent=resultFolder
local result={schema=1,status='running',scenario='isolated_npc_walker_heavy',checks={},
    placeId=game.PlaceId,placeVersion=game.PlaceVersion,studioVersion=version(),
    preparation={isolatedWorld=true,onlyWalkerFromFirstZone=true,walkerAnchored=true,
        heroUnanchoredDuringStrike=true,seedRawLife=35,heroX=-40,walkerX=-46,z=0,
        directHealthSeed=true,manualStrikeCall=false,manualHitCall=false},
    limits={'Not natural level progression','No player input, networking or device acceptance',
        'Anchored attacker; no retreat or gait acceptance','Embedded source receipt assumes no Studio source edits'}}
resultFolder:SetAttribute('Status','running')
local world,session,director
local started=workspace:GetServerTimeNow()

local function check(name,condition,observed)
    result.checks[#result.checks+1]={name=name,passed=condition==true,observed=observed}
    assert(condition,name)
end

local function vector(v) return {x=v.X,y=v.Y,z=v.Z} end
local function motorOffsets(actor)
    local offsets={}
    for name,motor in pairs(actor.poseMotors or {}) do
        local relative=motor.base:ToObjectSpace(motor.joint.C0)
        local _,angle=relative:ToAxisAngle()
        offsets[name]={angle=math.abs(angle),position=relative.Position.Magnitude}
    end
    return offsets
end

local function atRest(actor)
    local count=0
    for _,offset in pairs(motorOffsets(actor)) do
        count+=1
        if offset.angle>.02 or offset.position>.01 then return false end
    end
    return count==4
end

local function snapshot()
    local hero=world.actors[1]
    local enemy=world.actors[-3]
    local h,c=session.state.heroes[1],session.combat[1]
    local e=director and director.enemies[-3]
    return {now=session.now,rawLife=c.rawLife,attempt=h.attempt,respawns=h.respawns,
        actorId=h.actorId,shield=h.shield and h.shield.kind,heroPosition=vector(hero.root.Position),
        heroVelocity=vector(hero.root.AssemblyLinearVelocity),heroAnchored=hero.root.Anchored,
        platformStand=hero.humanoid.PlatformStand,humanoidState=hero.humanoid:GetState().Name,
        grounded=hero.humanoid.FloorMaterial~=Enum.Material.Air,heavyReactionEpoch=c.heavyReactionEpoch or 0,
        reactionEnd=c.reactionEnd,recover=c.recover,walkerPosition=enemy and vector(enemy.root.Position),
        walkerAction=e and e.windup and e.windup.action,
        walkerMotorOffsets=enemy and motorOffsets(enemy),
        pose=enemy and enemy.model:GetAttribute('PrimaryAttack'),phase=enemy and enemy.model:GetAttribute('AttackPhase')}
end

local function frame()
    local dt=RunService.Heartbeat:Wait()
    local now=workspace:GetServerTimeNow()-started
    assert(now<=10,'Fixture exceeded its 10-second deadline')
    assert(session:step(now)=='OK','Session stopped before acceptance completed')
    if director then
        director:step(now,dt)
        world:updatePresentation(session,dt,director.enemies)
    end
    result.lastFrame=snapshot()
end

local function untilCondition(predicate)
    while not predicate() do frame() end
end

local ok,err=xpcall(function()
    result.sourceManifest=HttpService:JSONDecode(script.Parent:WaitForChild('SourceManifest',2).Value)
    local project=game:GetService('ServerScriptService'):WaitForChild('BrickToads',2)
    local runtime=project.CombatRuntime
    local gameplay=project.gameplay
    local Core=require(project.RunLifecycle)
    local Combat=require(runtime.Combat)
    local Session=require(runtime.Session)
    local level=require(gameplay.LevelDefinition)
    -- Keep the real route geometry/configuration, isolating its existing Walker-3.
    local fixtureLevel=table.clone(level)
    fixtureLevel.zones=table.clone(level.zones)
    fixtureLevel.zones[1]=table.clone(level.zones[1])
    fixtureLevel.zones[1].enemies={table.clone(level.zones[1].enemies[3])}
    check('fixture uses the existing first-zone Walker',fixtureLevel.zones[1].enemies[1].id==-3
        and fixtureLevel.zones[1].enemies[1].kind=='Walker')
    local config=require(gameplay.GameConfig)(require(runtime.Config),fixtureLevel)
    world=require(gameplay.GameWorld).new(require(runtime.RobloxWorld),config,
        {name=resultFolder.Name,offset={x=0,y=0,z=4096}})
    session=Session.new(Core,Combat,config,{{userId=1,template='Mr. Green'}},resultFolder.Name,world)
    check('initial spawn commits',session:step(0)=='OK' and session.state.heroes[1].status=='Alive')
    local hero=world.actors[1]
    hero.root.Anchored=true
    hero.model:PivotTo(CFrame.lookAt(Vector3.new(-40,3,4096),Vector3.new(-46,3,4096)))
    -- This is an explicit fixture seed, not evidence of earning that health in combat.
    untilCondition(function() return session.state.heroes[1].shield==nil end)
    check('fixture health seed commits',session:_event('SetHealth',1,{health=Combat.hearts(35)})=='OK')
    session.combat[1].rawLife=35
    director=require(gameplay.LevelDirector).new(session,world,Combat,config)
    local walker=world.actors[-3]
    walker.root.Anchored=true
    walker.model:PivotTo(CFrame.lookAt(Vector3.new(-46,3,4096),Vector3.new(-40,3,4096)))
    hero.root.AssemblyLinearVelocity=Vector3.zero
    hero.root.AssemblyAngularVelocity=Vector3.zero
    world:hold(1,false)
    result.before=snapshot()
    local identity=session.state.heroes[1].actorId
    local enemyIdentity=director.enemies[-3].actorId
    frame()
    check('NPC selects Heavy through the ordinary AI step',director.enemies[-3].windup~=nil
        and director.enemies[-3].windup.action=='WalkerHeavy',snapshot())
    check('actual model presents a heavy windup',walker.model:GetAttribute('PrimaryAttack')=='WalkerHeavy'
        and walker.model:GetAttribute('AttackPhase')=='Windup',snapshot())
    local poseSampleAt=session.now+.1
    untilCondition(function() return session.now>=poseSampleAt end)
    result.windup=snapshot()
    local offsets=motorOffsets(walker)
    check('actual hip motors move during the heavy windup',director.enemies[-3].windup~=nil
        and offsets['Left Hip']~=nil and offsets['Right Hip']~=nil
        and offsets['Left Hip'].angle>.1 and offsets['Right Hip'].angle>.1,offsets)
    local hit
    untilCondition(function()
        for _,row in ipairs(session.logs) do
            if row.kind=='Hit' and row.userId==1 and row.data.action=='WalkerHeavy' then hit=row;return true end
        end
        return false
    end)
    result.hit=hit
    result.afterHit=snapshot()
    check('real hit geometry produces one profile20 hit35 to31',hit.data.attacker==-3 and hit.data.profile==20
        and hit.data.before==35 and hit.data.after==31 and hit.data.blocked==false,hit.data)
    check('heavy reaction reaches the unanchored engine body',not hero.root.Anchored
        and hero.humanoid.PlatformStand and session.combat[1].heavyReactionEpoch==1
        and not session.combat[1].recover,snapshot())
    local maxY,maxVelocityY=hero.root.Position.Y,hero.root.AssemblyLinearVelocity.Y
    local sampleUntil=session.now+.2
    repeat
        frame()
        maxY=math.max(maxY,hero.root.Position.Y)
        maxVelocityY=math.max(maxVelocityY,hero.root.AssemblyLinearVelocity.Y)
    until session.now>=sampleUntil
    check('engine observes an actual upward response',maxY>result.afterHit.heroPosition.y+.05 or maxVelocityY>1,
        {maxY=maxY,maxVelocityY=maxVelocityY})
    untilCondition(function() return session.combat[1].reactionEnd==nil end)
    result.afterRecovery=snapshot()
    local hits=0
    for _,row in ipairs(session.logs) do
        if row.kind=='Hit' then hits+=1 end
    end
    check('single strike does not heal or spend a respawn',hits==1 and session.combat[1].rawLife==31
        and session.state.heroes[1].respawns==3 and session.state.heroes[1].attempt==1
        and session.state.heroes[1].actorId==identity and world.actors[1]==hero
        and hero.root.Parent~=nil and hero.model.Parent==world.actorFolder
        and not hero.humanoid.PlatformStand,snapshot())
    check('same NPC stays alive without an owner or replacement',world.actors[-3]==walker
        and director.enemies[-3].actorId==enemyIdentity and not director.enemies[-3].dead
        and director.enemies[-3].health==3 and director.enemies[-3].ownerUserId==nil)
    check('finite heavy pose returns to idle',walker.model:GetAttribute('PrimaryAttack')==nil
        and walker.model:GetAttribute('AttackPhase')==nil,snapshot())
    untilCondition(function()
        assert(session.now<director.enemies[-3].nextAttack,'Motor pose did not settle before the next attack deadline')
        return atRest(walker)
    end)
    result.idle=snapshot()
    check('actual motors settle near their original frames',atRest(walker),motorOffsets(walker))
    untilCondition(function()
        local state=hero.humanoid:GetState().Name
        return hero.humanoid.FloorMaterial~=Enum.Material.Air
            and (state=='Running' or state=='RunningNoPhysics' or state=='Landed')
    end)
    result.physicalRecovery=snapshot()
    hits=0
    for _,row in ipairs(session.logs) do
        if row.kind=='Hit' then hits+=1 end
    end
    check('same living body reaches grounded non-reaction state after physics',world.actors[1]==hero
        and hero.root.Parent~=nil and hero.model.Parent==world.actorFolder and hero.humanoid.Health>0
        and not hero.root.Anchored and not hero.humanoid.PlatformStand and session.combat[1].reactionEnd==nil
        and session.state.heroes[1].actorId==identity and session.state.heroes[1].attempt==1
        and session.state.heroes[1].respawns==3 and session.combat[1].rawLife==31 and hits==1,snapshot())
end,debug.traceback)

result.elapsed=workspace:GetServerTimeNow()-started
result.status=ok and 'pass' or 'fail'
if not ok then result.error=tostring(err) end
if world then world.folder:Destroy() end
output.Value=HttpService:JSONEncode(result)
resultFolder:SetAttribute('Status',result.status)
if ok then print('[BT-WALKER-ACCEPTANCE] '..output.Value)
else warn('[BT-WALKER-ACCEPTANCE] '..output.Value) end
