-- Explicit Studio-only fixture: real runtime, geometry and raycasts; not a normal-input route clear.
-- Execute in a fresh Play server after syncing the exact packaged sources.
assert(game:GetService('RunService'):IsStudio(), 'Studio acceptance only')
local Http=game:GetService('HttpService')
local project=game:GetService('ServerScriptService'):WaitForChild('BrickToads')
local gameplay=project.gameplay
local runtime=project.CombatRuntime
local World=require(gameplay.GameWorld)
require(gameplay.DragonWorld)(World)
local canonical=require(gameplay.LevelDefinition)
local Variation=require(gameplay.LevelVariation)
local Config=require(gameplay.GameConfig)(require(runtime.Config),canonical)
local source=require(project.BuildInfo).sourceSha256
local result={sourceSha256=source,checks={},fixtures='Server-invoked isolated groups; prepared death and geometry samples; no full-route or physical-touch claim'}
local created={}
local function check(name,condition)
    assert(condition,name)
    result.checks[#result.checks+1]=name
end
local function near(a,b) return math.abs(a-b)<.001 end
local function vector(v) return {x=v.X,y=v.Y,z=v.Z} end
local function layout(world)
    local rows={}
    for _,p in ipairs(world.allFloors) do
        rows[#rows+1]={position=vector(p.Position),size=vector(p.Size),surface=p:GetAttribute('SurfaceId')}
    end
    return Http:JSONEncode(rows)
end
local function metadata(route)
    return {version=route.variation.version,seed=route.variation.seed,sectionChoices=table.clone(route.variation.sectionChoices)}
end
local function world(index,id,z)
    local w=World.new(require(runtime.RobloxWorld),Config,{name='BrickToadsSectionQA_'..id,offset={x=0,y=32,z=z or (16384+(index-1)*512)}})
    created[#created+1]=w
    return w
end
local ok,err=xpcall(function()
    local time=workspace:GetServerTimeNow()
    local deps={Core=require(project.RunLifecycle),Combat=require(runtime.Combat),Session=require(runtime.Session),
        Registry=require(runtime.ConnectionRegistry),Config=Config,Controller=require(gameplay.GameController),
        Director=require(gameplay.LevelDirector),BossQueue=require(gameplay.BossQueue),
        GuardianPattern=require(gameplay.GuardianPattern),HealingFlies=require(gameplay.HealingFlies),
        EnemyCarry=require(gameplay.EnemyCarry),WalkerClubs=require(gameplay.WalkerClubs),
        SourceCombat=require(gameplay.SourceCombat),DragonFlight=require(gameplay.DragonFlight),
        RunJournal=require(gameplay.RunJournal),BuildId=source,LevelVariation=Variation,
        clock=function() return time end,guid=function() return Http:GenerateGUID(false) end}
    local hub=require(gameplay.MatchHub).new(deps,world)
    local players={}
    for i=1,2 do
        players[i]={UserId=900000+i,Name='SectionFixture'..i,DisplayName='Section fixture '..i,Parent=game:GetService('Players')}
        check('join fixture '..i,hub:join(players[i]))
    end
    local function send(p,payload)
        time+=.1
        payload.groupId=hub.routes[p.UserId]
        return hub:handle(p,payload,players)
    end
    local a=hub.groups['group-1']
    local lobbyGeometry=a.world.geometry:GetChildren()[1]
    check('nonhost Start refused',send(players[2],{kind='Start'})=='HOST_ONLY')
    check('refused Start preserves lobby geometry',lobbyGeometry.Parent==a.world.geometry and a.controller.current==nil)
    check('create second group',send(players[2],{kind='CreateGroup',requestId='section-acceptance-second'})=='OK')
    local b=hub:selected(players[2])
    check('start first generated run',send(players[1],{kind='Start'})=='OK')
    check('start second generated run',send(players[2],{kind='Start'})=='OK')
    local first=a.controller.deps.Config.Level
    local second=b.controller.deps.Config.Level
    check('route is private to each controller/world',first~=second and a.world.config.Level==first and b.world.config.Level==second)
    check('canonical stays unchanged',canonical.variation==nil and Config.Level==canonical)
    check('folder carries actual run seed',a.world.folder:GetAttribute('LayoutSeed')==first.variation.seed)
    local beforeA,beforeB=layout(a.world),layout(b.world)
    local peerBody=b.world.actors[1]
    local oldBody=a.world.actors[1]
    local refused,reason=a.world:rebuildLevel(Variation.build(canonical,1))
    check('World rejects rebuild with actors',refused==false and reason=='ACTORS_PRESENT' and layout(a.world)==beforeA and a.world.config.Level==first)
    check('active Start refused',send(players[1],{kind='Start'})=='RUN_ACTIVE')
    check('active refusal preserves body and map',a.world.actors[1]==oldBody and layout(a.world)==beforeA)
    local hero=a.controller.current.state.heroes[1]
    local beforeRespawns=hero.respawns
    a.controller.current:_die(1,'Explicit section stability fixture')
    time+=.1;a.controller:step(time,.1)
    check('confirmed death respawns same route',a.controller.current.state.heroes[1].attempt==2
        and a.controller.current.state.heroes[1].respawns==beforeRespawns-1
        and a.world.config.Level==first and layout(a.world)==beforeA)
    local currentPlayer=players[1]
    hub:leave(currentPlayer)
    local replacement={UserId=currentPlayer.UserId,Name=currentPlayer.Name,DisplayName=currentPlayer.DisplayName,Parent=currentPlayer.Parent}
    players[1]=replacement;hub:join(replacement)
    check('rejoin retains route and run',a.world.config.Level==first and layout(a.world)==beforeA
        and a.controller.current.state.runId~=nil)
    local originalRun=a.controller.current.state.runId
    for _=1,3 do
        a.controller.current:_die(1,'Explicit end-of-run fixture')
        time+=.1;a.controller:step(time,.1)
    end
    check('ordinary resources end the prepared run',a.controller.current.state.status=='Lost')
    check('new Start accepted after loss',send(replacement,{kind='Start'})=='OK')
    local nextRoute=a.controller.deps.Config.Level
    check('new run selects a fresh server seed',a.controller.current.state.runId~=originalRun and nextRoute~=first
        and nextRoute.variation.seed==Variation.seedFromId(a.controller.current.state.runId))
    check('peer run and body survive rebuild',b.controller.deps.Config.Level==second and layout(b.world)==beforeB
        and b.world.actors[1]==peerBody and peerBody.root.Parent~=nil)
    local exposed=hub:snapshot(replacement,players).level.variation
    check('snapshot reports the actual route',exposed and exposed.seed==nextRoute.variation.seed
        and Http:JSONEncode(exposed.sectionChoices)==Http:JSONEncode(nextRoute.variation.sectionChoices))
    local logged
    for _,event in ipairs(a.controller.journal:snapshot().events) do
        if event.kind=='RunStarted' then logged=event.data.variation end
    end
    check('journal describes actual seed and sections',logged and Http:JSONEncode(logged.sectionChoices)==Http:JSONEncode(nextRoute.variation.sectionChoices)
        and logged.seed==nextRoute.variation.seed and logged.version==nextRoute.variation.version)
    result.runs={first=metadata(first),peer=metadata(second),next=metadata(nextRoute)}
    result.peerUnchanged=true

    -- A deterministic authored route permits matching every real collider to its source coordinates.
    local probe=world(3,'geometry',18432)
    local seedRoute=Variation.build(canonical,1)
    check('deterministic geometry rebuild',probe:rebuildLevel(seedRoute)==true)
    local floorIndex,coverCount,gapCount=0,0,0
    for zi,zone in ipairs(seedRoute.zones) do
        for _,p in ipairs(zone.platforms) do
            floorIndex+=1
            local actual=probe.allFloors[floorIndex]
            check('floor '..floorIndex..' matches local route and one offset',near(actual.Position.X,p.x)
                and near(actual.Position.Y,p.y+32) and near(actual.Position.Z,p.z+18432)
                and near(actual.Size.X,p.w) and near(actual.Size.Z,p.d))
        end
        for _,cover in ipairs(zone.obstacles or {}) do
            local origin=Vector3.new(cover.x,cover.y+32+cover.h/2+8,cover.z+18432)
            local hit=workspace:Raycast(origin,Vector3.new(0,-12,0),probe.ray)
            coverCount+=1
            check('cover '..coverCount..' is collidable district support',hit and hit.Instance.Name=='StoneCover'
                and hit.Instance.CanCollide and hit.Instance:GetAttribute('SurfaceId')==zone.id
                and near(hit.Position.Y,cover.y+32+cover.h/2))
        end
        for _,gap in ipairs(zone.gaps) do
            gapCount+=1
            local origin=Vector3.new((gap.minX+gap.maxX)/2,48,(gap.minZ+gap.maxZ)/2+18432)
            check('gap '..gapCount..' has no hidden collidable bridge',workspace:Raycast(origin,Vector3.new(0,-24,0),probe.ray)==nil)
        end
        task.wait()
    end
    check('probe includes real cover and all required gaps',coverCount>0 and gapCount==5)
    local reproduced=layout(probe)
    check('same seed rebuild accepted',probe:rebuildLevel(Variation.build(canonical,1))==true)
    check('same seed produces same physical geometry',layout(probe)==reproduced)
    check('different seed rebuild accepted',probe:rebuildLevel(Variation.build(canonical,2))==true)
    check('different seed changes physical geometry',layout(probe)~=reproduced)
    result.geometry={seed=1,coverCount=coverCount,gapCount=gapCount}
    result.status='PASS'
end,debug.traceback)
for _,w in ipairs(created) do
    pcall(function() w:clearActors() end)
    if w.folder.Parent then w.folder:Destroy() end
end
if not ok then result.status='FAIL';result.error=tostring(err) end
_G.BrickToadsSectionAcceptance=result
return Http:JSONEncode(result)
