-- Stand-only entry point. The normal development place does not include this directory.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
Players.CharacterAutoLoads=false
local Config=require(script.Parent.Config)
local Core=require(script.Parent.RunLifecycle)
local Combat=require(script.Parent.Combat)
local Session=require(script.Parent.Session)
local World=require(script.Parent.RobloxWorld)
local world=World.new(Config)
local remotes=Instance.new("Folder"); remotes.Name="CombatStand"; remotes.Parent=ReplicatedStorage
local intent=Instance.new("RemoteEvent"); intent.Name="Intent"; intent.Parent=remotes
local stateRemote=Instance.new("RemoteEvent"); stateRemote.Name="State"; stateRemote.Parent=remotes
local current,ownerSlots,arrivals,buckets,notices=nil,{},{},{},{}
local joinSerial,lastBroadcast,fault=0,0,nil
local function now() return workspace:GetServerTimeNow() end
local function online()
    local result=Players:GetPlayers()
    table.sort(result,function(a,b) return (arrivals[a] or 0)<(arrivals[b] or 0) end)
    return result
end
local function logger(row)
    print("[BT-STAND] "..HttpService:JSONEncode(row))
    if row.kind=="Hit" then world:cue(row.userId,row.data.blocked) end
end
local function broadcast(requester)
    local list=online()
    local snapshot=current and current:snapshot() or {status="Lobby",heroes={},now=now()}
    snapshot.calibration=Config.Calibration; snapshot.online=#list
    snapshot.host=list[1] and list[1].UserId
    snapshot.fault=fault
    -- Sync and rejected Start are replies to one caller. Keep periodic updates
    -- and a successful new run global without allowing request-driven fanout.
    for _,player in ipairs(requester and {requester} or list) do
        snapshot.mine=ownerSlots[player.UserId]
        snapshot.canStart=list[1]==player and (not current or current.state.status=="Lost")
        snapshot.notice=notices[player]
        stateRemote:FireClient(player,snapshot)
    end
end
local function begin(player)
    local list=online()
    if list[1]~=player then return "HOST_ONLY" end
    if current and current.state.status~="Lost" then return "RUN_ACTIVE" end
    world:clearActors(); ownerSlots={}; fault=nil
    local roster={}; local templates={"Mr. Green","Mr. Yellow","Mr. Brown"}
    for index=1,math.min(3,#list) do
        local owner=list[index]
        -- Internal positive slots also work with Studio's synthetic negative account IDs.
        ownerSlots[owner.UserId]=index
        world.names[index]=owner.DisplayName.." @"..owner.Name
        roster[index]={userId=index,template=templates[index]}
    end
    current=Session.new(Core,Combat,Config,roster,HttpService:GenerateGUID(false),world,logger)
    current:step(now())
    return "OK"
end
local function joined(player)
    joinSerial=joinSerial+1; arrivals[player]=joinSerial
    if player.Character then player.Character:Destroy(); player.Character=nil end
    local slot=ownerSlots[player.UserId]
    if current and slot and current.state.status=="Active" then
        local h=current.state.heroes[slot]
        if h.connected then current:connection(slot,false,now()) end
        current:connection(slot,true,now())
    end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
    local slot=ownerSlots[player.UserId]
    -- A late removal from an older connection must not disconnect a newer Player object.
    local replacement=false
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.UserId==player.UserId and (arrivals[p] or 0)>(arrivals[player] or 0) then replacement=true end
    end
    if current and slot and current.state.status=="Active" and not replacement then current:connection(slot,false,now()) end
    arrivals[player]=nil; buckets[player]=nil; notices[player]=nil
end)
for _,player in ipairs(Players:GetPlayers()) do joined(player) end
intent.OnServerEvent:Connect(function(player,payload)
    local at=now()
    local bucket=buckets[player] or {tokens=Config.MaxIntentRate,last=at}
    bucket.tokens=math.min(Config.MaxIntentRate,bucket.tokens+(at-bucket.last)*Config.MaxIntentRate)
    bucket.last=at; buckets[player]=bucket
    if bucket.tokens<1 then return end
    bucket.tokens=bucket.tokens-1
    if type(payload)~="table" or type(payload.kind)~="string" then return end
    if payload.kind=="Sync" or payload.kind=="Start" then
        local count=0; for _ in pairs(payload) do count=count+1; if count>1 then return end end
        if payload.kind=="Start" then
            local code=begin(player)
            if code=="OK" then notices[player]=nil; broadcast(); return end
            notices[player]=code
        end
        broadcast(player); return
    end
    if fault or not current then return end
    local slot=ownerSlots[player.UserId]
    if not slot then return end
    local code=current:intent(slot,payload,at)
    if code=="OK" then notices[player]=nil else notices[player]=code end
end)
RunService.Heartbeat:Connect(function()
    local at=now()
    if current and not fault then
        local ok,err=xpcall(function() current:step(at) end,debug.traceback)
        if not ok then fault=tostring(err); warn("[BT-STAND] STOPPED: "..fault) end
    end
    if at-lastBroadcast>=Config.SnapshotInterval then lastBroadcast=at; broadcast() end
end)

-- Trusted scenario preparation is server-local, absent outside Studio, never a RemoteEvent.
if RunService:IsStudio() then
    local diagnostics=Instance.new("BindableFunction")
    diagnostics.Name="Diagnostics"; diagnostics.Parent=script.Parent
    local function active(slot)
        assert(current and not fault,"Start a healthy session first")
        local h=assert(current.state.heroes[slot],"Unknown slot")
        local c=current.combat[slot]
        assert(h.status=="Alive" and not h.shield and not c.attack and not c.reactionEnd and not c.deathAt,
            "Scenario preparation requires an alive idle actor without a shield")
        return c
    end
    local function setLife(slot,value)
        local c=active(slot); Combat.hearts(value)
        c.rawLife=value
        assert(current:_event("SetHealth",slot,{health=Combat.hearts(value)})=="OK")
        current:_record("DiagnosticLife",slot,{raw=value})
    end
    diagnostics.OnInvoke=function(command,a,b,c,d,e)
        if command=="Reset" then
            if current then logger({kind="DiagnosticReset",runId=current.state.runId,now=now()}) end
            current=nil; ownerSlots={}; fault=nil; world:clearActors(); broadcast(); return "LOBBY"
        end
        assert(current,"Start a session first")
        if command=="Dump" then
            return HttpService:JSONEncode({placeId=game.PlaceId,placeVersion=game.PlaceVersion,
                jobId=game.JobId,calibration=Config.Calibration,snapshot=current:snapshot(),events=current.logs})
        elseif command=="NoSafe" then
            assert(type(a)=="boolean","NoSafe expects boolean")
            world:noSafe(a); current:_record("DiagnosticNoSafe",1,{enabled=a})
        elseif command=="Life" then setLife(a,b)
        elseif command=="Pose" then
            active(a)
            for _,v in ipairs({b,c,d,e}) do assert(type(v)=="number" and v==v and math.abs(v)<=1000,"Invalid pose") end
            world:move(a,0,0); world:pose(a,b,c,d,e)
            current:_record("DiagnosticPose",a,{position={b,c,d},yaw=e})
        elseif command=="Case" then
            assert(a=="Safe" or a=="Edge" or a=="Dash16" or a=="Dash15","Unknown case")
            assert(b~=c,"Two different slots required"); active(b); active(c)
            setLife(b,47); setLife(c,a=="Dash16" and 16 or (a=="Dash15" and 15 or 47))
            world:move(b,0,0); world:move(c,0,0)
            world:pose(b,a=="Edge" and 30 or -5,3,0,-90)
            world:pose(c,a=="Edge" and 35.5 or 0,3,0,90)
            current:_record("DiagnosticCase",b,{name=a,target=c})
        else error("Unknown diagnostic command") end
        broadcast(); return "OK"
    end
end
print("[BT-STAND] ready for lobby; calibration is experimental; no engine acceptance is implied")
