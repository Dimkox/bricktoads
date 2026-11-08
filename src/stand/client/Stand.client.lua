-- Input and presentation only. The server owns actors, targets, damage and respawns.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("CombatStand")
local intent=remotes:WaitForChild("Intent")
local stateRemote=remotes:WaitForChild("State")
local gui=Instance.new("ScreenGui"); gui.Name="CombatStandHUD"; gui.ResetOnSpawn=false
local snapshot,mine,sequence,identity=nil,nil,0,nil
local keys,touchVector,drag={z=0},Vector2.new(),nil
local function label(parent,name,text,size,position)
    local t=Instance.new("TextLabel"); t.Name=name; t.Text=text; t.Size=size; t.Position=position
    t.BackgroundTransparency=1; t.TextColor3=Color3.fromRGB(240,244,249)
    t.TextSize=14; t.Font=Enum.Font.Gotham; t.TextWrapped=true; t.Parent=parent
    return t
end
local panel=Instance.new("Frame"); panel.Name="Status"; panel.Size=UDim2.new(1,-24,0,112)
panel.Position=UDim2.fromOffset(12,12); panel.BackgroundColor3=Color3.fromRGB(22,32,45); panel.Parent=gui
label(panel,"Title","BRICK TOADS · ТЕСТОВЫЙ СТЕНД",UDim2.new(1,-12,0,24),UDim2.fromOffset(6,2))
local fills={}
for i=1,5 do
    local x=8+(i-1)*29
    local background=label(panel,"Heart"..i,"♥",UDim2.fromOffset(26,28),UDim2.fromOffset(x,26))
    background.TextColor3=Color3.fromRGB(80,88,99); background.TextSize=26
    local clip=Instance.new("Frame"); clip.BackgroundTransparency=1; clip.ClipsDescendants=true
    clip.Size=UDim2.fromOffset(26,28); clip.Parent=background
    local fill=label(clip,"Fill","♥",UDim2.fromOffset(26,28),UDim2.fromOffset(0,0))
    fill.TextSize=26; fill.TextColor3=Color3.fromRGB(241,100,104); fills[i]=clip
end
local health=label(panel,"Values","",UDim2.new(1,-164,0,34),UDim2.fromOffset(156,24))
local status=label(panel,"Detail","Ожидание сервера",UDim2.new(1,-12,0,48),UDim2.fromOffset(6,60))
local function button(name,text,size,position,callback)
    local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.Size=size; b.Position=position
    b.BackgroundColor3=Color3.fromRGB(54,85,112); b.TextColor3=Color3.new(1,1,1)
    b.TextSize=15; b.TextWrapped=true; b.Font=Enum.Font.GothamBold; b.Parent=gui
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,10); corner.Parent=b
    b.Activated:Connect(callback)
    return b
end
local function send(kind, extra)
    if not snapshot or not mine or mine.status~="Alive" or not mine.connected then return end
    sequence=sequence+1
    local p={kind=kind,runId=snapshot.runId,actorId=mine.actorId,attempt=mine.attempt,
        levelEpoch=snapshot.levelEpoch,connectionEpoch=mine.connectionEpoch,seq=sequence}
    for k,v in pairs(extra or {}) do p[k]=v end
    intent:FireServer(p)
end
local start=button("Start","Старт",UDim2.fromOffset(180,44),UDim2.new(0.5,-90,1,-230),function()
    intent:FireServer({kind="Start"})
end)
button("Punch","Удар · F",UDim2.fromOffset(76,60),UDim2.new(1,-170,1,-174),function() send("Attack",{attack="Punch"}) end)
button("Dash","Таран · R",UDim2.fromOffset(76,60),UDim2.new(1,-86,1,-174),function() send("Attack",{attack="Dash"}) end)
button("Jump","Прыжок",UDim2.fromOffset(160,52),UDim2.new(1,-170,1,-106),function() send("Jump") end)
local pad=Instance.new("Frame"); pad.Name="MovePad"; pad.Active=true
pad.Size=UDim2.fromOffset(132,132); pad.Position=UDim2.new(0,20,1,-190)
pad.BackgroundColor3=Color3.fromRGB(37,53,70); pad.BackgroundTransparency=0.15; pad.Parent=gui
local round=Instance.new("UICorner"); round.CornerRadius=UDim.new(1,0); round.Parent=pad
label(pad,"Hint","ДВИЖЕНИЕ\nW A S D",UDim2.fromScale(1,1),UDim2.fromOffset(0,0))
local knob=Instance.new("Frame"); knob.Name="Knob"; knob.Size=UDim2.fromOffset(30,30)
knob.AnchorPoint=Vector2.new(0.5,0.5); knob.Position=UDim2.fromScale(0.5,0.5)
knob.BackgroundColor3=Color3.fromRGB(119,169,202); knob.Parent=pad
local knobRound=Instance.new("UICorner"); knobRound.CornerRadius=UDim.new(1,0); knobRound.Parent=knob
local function dragTo(input)
    local center=pad.AbsolutePosition+pad.AbsoluteSize/2
    local delta=(Vector2.new(input.Position.X,input.Position.Y)-center)/50
    if delta.Magnitude>1 then delta=delta.Unit end
    touchVector=delta
    knob.Position=UDim2.new(0.5,delta.X*42,0.5,delta.Y*42)
end
pad.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=input; dragTo(input)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if drag and (input==drag or (drag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then dragTo(input) end
end)
UserInputService.InputBegan:Connect(function(input,processed)
    if processed then return end
    keys[input.KeyCode]=true
    if input.KeyCode==Enum.KeyCode.F then send("Attack",{attack="Punch"})
    elseif input.KeyCode==Enum.KeyCode.R then send("Attack",{attack="Dash"})
    elseif input.KeyCode==Enum.KeyCode.Space then send("Jump") end
end)
UserInputService.InputEnded:Connect(function(input)
    keys[input.KeyCode]=nil
    if input==drag then drag=nil; touchVector=Vector2.new(); knob.Position=UDim2.fromScale(0.5,0.5) end
end)
UserInputService.WindowFocusReleased:Connect(function()
    keys={}; drag=nil; touchVector=Vector2.new(); knob.Position=UDim2.fromScale(0.5,0.5)
end)
local cameraActor=nil
stateRemote.OnClientEvent:Connect(function(data)
    snapshot=data; mine=nil
    for _,h in ipairs(data.heroes or {}) do if h.slot==data.mine then mine=h end end
    local token=mine and (data.runId..":"..tostring(mine.actorId)..":"..mine.connectionEpoch) or nil
    if token~=identity then identity=token; sequence=0 end
    start.Visible=data.canStart==true
    start.Text=data.status=="Lost" and "Новая игра" or ("Старт · "..math.min(data.online or 0,3).."/3")
    local actors=workspace:FindFirstChild("CombatStandWorld")
    actors=actors and actors:FindFirstChild("Actors")
    local chosen=nil
    if actors then
        for _,model in ipairs(actors:GetChildren()) do
            if mine and model:GetAttribute("ActorId")==mine.actorId then chosen=model; break end
        end
        if not chosen then
            for _,model in ipairs(actors:GetChildren()) do
                local h=model:FindFirstChildOfClass("Humanoid")
                if h and h.Health>0 then chosen=model; break end
            end
        end
    end
    if chosen and chosen~=cameraActor then
        cameraActor=chosen
        local camera=workspace.CurrentCamera
        camera.CameraType=Enum.CameraType.Custom
        camera.CameraSubject=chosen:FindFirstChildOfClass("Humanoid")
        local root=chosen:FindFirstChild("HumanoidRootPart")
        if root then camera.CFrame=CFrame.lookAt(root.Position+Vector3.new(0,16,22),root.Position) end
    end
end)
local elapsed,syncElapsed=0,0
RunService.RenderStepped:Connect(function(dt)
    elapsed=elapsed+dt; syncElapsed=syncElapsed+dt
    if syncElapsed>=1 then syncElapsed=0; if not snapshot then intent:FireServer({kind="Sync"}) end end
    if elapsed>=0.1 then
        elapsed=0
        local function down(key) return keys[key] and 1 or 0 end
        local x=down(Enum.KeyCode.D)-down(Enum.KeyCode.A)+touchVector.X
        local z=down(Enum.KeyCode.S)-down(Enum.KeyCode.W)+touchVector.Y
        if UserInputService:GetFocusedTextBox() then x,z=0,0 end
        local camera=workspace.CurrentCamera
        local forward=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
        if forward.Magnitude<0.01 then forward=Vector3.new(0,0,-1) else forward=forward.Unit end
        local right=Vector3.new(-forward.Z,0,forward.X)
        local direction=right*x-forward*z
        if direction.Magnitude>1 then direction=direction.Unit end
        send("Move",{x=direction.X,z=direction.Z})
    end
    local hp=mine and mine.hearts or 0
    for i,fill in ipairs(fills) do fill.Size=UDim2.fromOffset(26*math.clamp(hp-(i-1),0,1),28) end
    if mine then
        health.Text=string.format("%.2f / 5\nLife %d · возвраты %d",hp,mine.rawLife,mine.respawns)
        local protection=mine.shield and (" · "..mine.shield.." "..string.format("%.1f",math.max(0,mine.shieldUntil-workspace:GetServerTimeNow()))) or ""
        status.Text="P"..mine.slot.." · "..mine.status..protection.."\n3D-параметры экспериментальные"
    else
        health.Text=""
        status.Text=snapshot and (snapshot.status=="Lobby" and "Соберите 1–3 клиента, затем нажмите Старт" or "Наблюдение · состав уже зафиксирован") or "Ожидание сервера"
    end
    if snapshot and snapshot.fault then status.Text="ОШИБКА СТЕНДА · подробности в Server Output" end
end)
gui.Parent=player:WaitForChild("PlayerGui")
intent:FireServer({kind="Sync"})
