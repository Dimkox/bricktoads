-- Main playable BrickToads runtime. The client supplies intent, never hit results.
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local HttpService=game:GetService('HttpService')
Players.CharacterAutoLoads=false
local runtime=script.Parent:WaitForChild('CombatRuntime')
local gameplay=script.Parent:WaitForChild('gameplay')
local worldType=require(gameplay.GameWorld)
require(gameplay.DragonWorld)(worldType)
local config=require(gameplay.GameConfig)(require(runtime.Config),require(gameplay.LevelDefinition))
local buildInfo=script.Parent:FindFirstChild('BuildInfo')
local buildId=buildInfo and require(buildInfo).sourceSha256 or 'unpackaged-source'
local controller=require(gameplay.MatchHub).new({Core=require(script.Parent.RunLifecycle),
    Combat=require(runtime.Combat),Session=require(runtime.Session),Registry=require(runtime.ConnectionRegistry),
    Config=config,Controller=require(gameplay.GameController),Director=require(gameplay.LevelDirector),BossQueue=require(gameplay.BossQueue),
    GuardianPattern=require(gameplay.GuardianPattern),HealingFlies=require(gameplay.HealingFlies),
    EnemyCarry=require(gameplay.EnemyCarry),
    WalkerClubs=require(gameplay.WalkerClubs),
    SourceCombat=require(gameplay.SourceCombat),DragonFlight=require(gameplay.DragonFlight),
    LevelVariation=require(gameplay.LevelVariation),
    RunJournal=require(gameplay.RunJournal),BuildId=buildId,
    clock=function() return workspace:GetServerTimeNow() end,guid=function() return HttpService:GenerateGUID(false) end},
    function(index,groupId)
        -- Migrate this runtime's older saved preview once; its unscoped floor
        -- would otherwise overlap the first group's independently owned arena.
        if index==1 then
            local legacy=workspace:FindFirstChild('BrickToadsWorld')
            if legacy and legacy:GetAttribute('OriginalArt')==true
                and legacy:GetAttribute('LevelName')=='Затопленный тракт' and legacy:GetAttribute('GroupId')==nil then
                legacy:Destroy()
            end
        end
        local world=worldType.new(require(runtime.RobloxWorld),config,{
            name='BrickToadsWorld_'..groupId,offset={x=0,y=0,z=(index-1)*config.Groups.spacing},
            characterAppearance=require(gameplay.CharacterAppearance)})
        world.folder:SetAttribute('GroupId',groupId)
        return world
    end)
if RunService:IsStudio() then
    -- Read-only server-side export. No remote, gameplay mutation or test control.
    local diagnostics=Instance.new('BindableFunction')
    diagnostics.Name='BrickToadsDiagnostics';diagnostics.Parent=game:GetService('ServerStorage')
    diagnostics.OnInvoke=function(groupId)
        if type(groupId)~='string' then return nil end
        local group=controller.groups[groupId]
        if not group then return nil end
        local run=group.controller
        return {sourceSha256=buildId,placeId=game.PlaceId,placeVersion=game.PlaceVersion,
            loggerFailures=run.current and (run.current.loggerFailures or 0) or 0,
            current=run.journal and run.journal:snapshot(),previous=run.previousJournal and run.previousJournal:snapshot()}
    end
end
local remotes=Instance.new('Folder'); remotes.Name='BrickToadsGame'; remotes.Parent=ReplicatedStorage
local intent=Instance.new('RemoteEvent'); intent.Name='Intent'; intent.Parent=remotes
local state=Instance.new('RemoteEvent'); state.Name='State'; state.Parent=remotes
local fault,lastBroadcast=nil,0
local function replicationFocus(player)
    local group=controller:selected(player)
    if not group then return end
    local world=group.world
    local slot=controller:controlledSlot(player.UserId)
    local actor=slot and world.actors[slot]
    if not actor or not actor.root.Parent then
        actor=nil
        for id,candidate in pairs(world.actors) do
            if id>0 and candidate.root.Parent and candidate.humanoid.Health>0 then actor=candidate; break end
        end
    end
    local focus=actor and actor.root or world.floors[1]
    if player.ReplicationFocus~=focus then player.ReplicationFocus=focus end
end
local function broadcast(requester)
    local players=Players:GetPlayers()
    for _,player in ipairs(requester and {requester} or players) do
        if player.Parent==Players then
            local snapshot=controller:snapshot(player,players)
            if snapshot then snapshot.fault=snapshot.fault==true or fault~=nil; state:FireClient(player,snapshot) end
        end
    end
end
local function joined(player)
    if player.Parent~=Players then return end
    if player.Character then player.Character:Destroy(); player.Character=nil end
    controller:join(player); replicationFocus(player); broadcast(player)
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player) controller:leave(player) end)
for _,player in ipairs(Players:GetPlayers()) do joined(player) end
intent.OnServerEvent:Connect(function(player,payload)
    if player.Parent~=Players or fault then return end
    local ok,code=xpcall(function() return controller:handle(player,payload,Players:GetPlayers()) end,debug.traceback)
    if not ok then fault=tostring(code); warn('[BrickToads] '..fault); return end
    if type(payload)=='table' and (payload.kind=='Sync' or payload.kind=='Start' or payload.kind=='SelectHero'
        or payload.kind=='SelectRole' or payload.kind=='ClaimEnemy' or payload.kind=='ChooseView'
        or payload.kind=='QueueBoss' or payload.kind=='CancelBossQueue' or payload.kind=='ReplyBoss' or payload.kind=='ConnectBoss'
        or payload.kind=='CreateGroup' or payload.kind=='JoinGroup'
        or ((payload.kind=='Attack' or payload.kind=='Jump') and (code=='OK' or code=='NOT_RUNNING'
            or code=='REACTION' or code=='COOLDOWN' or code=='HELD' or code=='THROWN'))) then
        if code~='RATE_LIMIT' and code~='STALE_CONNECTION' then broadcast(player) end
    end
end)
RunService.Heartbeat:Connect(function(dt)
    local at=workspace:GetServerTimeNow()
    if not fault then
        local ok,err=xpcall(function()
            controller:step(at,dt)
        end,debug.traceback)
        if not ok then fault=tostring(err); warn('[BrickToads] '..fault) end
    end
    for _,player in ipairs(Players:GetPlayers()) do replicationFocus(player) end
    if at-lastBroadcast>=config.SnapshotInterval then lastBroadcast=at; broadcast() end
end)
print('[BrickToads] playable causeway ready')
