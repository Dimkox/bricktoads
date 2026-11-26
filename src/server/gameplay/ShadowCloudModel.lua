-- BT-107. Closed-volume cosmetic fallback for the 0x62 BC/BD gas head.
local Cloud = {}

-- Local coordinates follow Roblox front (-Z). The lip faces screen right.
local lobes = {
    {0.15,1.02,0.23, 3.30,2.06,2.69, 107,143,27},
    {1.33,0.18,0.12, 2.49,2.60,2.84, 85,126,29},
    {0.76,-0.97,0.10, 2.53,2.14,2.66, 77,113,27},
    {-1.28,0.65,0.18, 2.50,2.15,2.73, 112,150,32},
    {-1.36,-0.88,0.35, 2.24,1.91,2.46, 71,111,24},
    {0.23,0.02,1.01, 2.93,2.74,1.57, 85,123,29},
}
local function ball(model,name,base,offset,size,color,movable)
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = Enum.PartType.Ball
    part.Size = size
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.CanCollide, part.CanTouch, part.CanQuery = false,false,false
    part.Anchored, part.Massless = false,true
    part.CFrame = base.CFrame * offset
    part.Parent = model
    local joint = Instance.new(movable and "Motor6D" or "Weld")
    joint.Name = name .. "Joint"
    joint.Part0, joint.Part1, joint.C0 = base,part,offset
    if movable then joint:SetAttribute("Rest",offset) end
    joint.Parent = part
    return part
end

local mouth = CFrame.new(-1.04,-0.44,-1.32) * CFrame.Angles(0,0,-0.26)
function Cloud.attach(parent,anchor)
    local model = Instance.new("Model")
    model.Name = "ShadowCloud"
    local core = ball(model,"Core",anchor,CFrame.identity,Vector3.new(4.10,3.45,2.78),Color3.fromRGB(61,92,24),true)
    model.PrimaryPart = core
    for i,l in ipairs(lobes) do
        local lobe = ball(model,"Lobe"..i,core,CFrame.new(l[1],l[2],l[3]),
            Vector3.new(l[4],l[5],l[6]),Color3.fromRGB(l[7],l[8],l[9]),true)
        for j = 1,3 do
            local angle = i*1.7+j*2.09
            local offset = CFrame.new(math.cos(angle)*l[4]*.28, math.sin(angle)*l[5]*.27, (i==6 and 1 or -1)*l[6]*.30)
            ball(model,"Fold"..i.."_"..j,lobe,offset,Vector3.new(l[4]*.48,l[5]*.51,l[6]*.46),
                Color3.fromRGB(l[7]+j*4,l[8]+j*4,l[9]),false)
        end
    end
    local rim = ball(model,"MouthRim",core,mouth,Vector3.new(2.14,2.51,.72),Color3.fromRGB(95,134,24),true)
    ball(model,"Gullet",rim,CFrame.new(0,0,-.18),Vector3.new(1.71,2.10,.46),Color3.fromRGB(21,32,11),false)
    ball(model,"Throat",rim,CFrame.new(-.06,.03,-.26),Vector3.new(1.37,1.77,.35),Color3.fromRGB(10,15,8),false)
    for _,sign in ipairs({-1,1}) do
        local name = sign==1 and "MouthUpper" or "MouthLower"
        ball(model,name,rim,CFrame.new(0,sign*1.04,-.12),Vector3.new(1.33,.42,.42),Color3.fromRGB(120,157,28),true)
    end
    for _,name in ipairs({"Aim","Mouth","GasOrigin","WindOrigin","HitFX"}) do
        local socket = Instance.new("Attachment")
        socket.Name = name
        socket.Parent = name=="HitFX" and core or rim
        socket.Position = name=="HitFX" and Vector3.new(0,.8,-1.22) or Vector3.new(0,0,-.55)
    end
    model.Parent = parent
    return model
end

local function offset(model,name,cf)
    local part = model:FindFirstChild(name)
    local joint = part and part:FindFirstChild(name.."Joint")
    if joint then joint.C0 = joint:GetAttribute("Rest") * cf end
end

function Cloud.pose(model,clip,phase)
    local t = math.clamp(phase or 0,0,1)
    local cycle,accent = math.sin(t*2*math.pi),math.sin(t*math.pi)
    local squeeze,open,lift,tilt = 0,0,0,0
    if clip=="GasTell" or clip=="WindTell" then squeeze=t; open=-t
    elseif clip=="GasRelease" then squeeze=1-t; open=1.3*t
    elseif clip=="GasRecover" then open=1.3*(1-t)
    elseif clip=="WindBlow" then open=.8+.2*cycle
    elseif clip=="WindStop" then open=.8*(1-t)
    elseif clip=="MouthPulse" then open=accent
    elseif clip=="TransitionBC" then squeeze=t; open=-t
    elseif clip=="TransitionBD" then squeeze=1-t; open=t-1
    elseif clip=="Turn" then tilt=.26*accent
    elseif clip=="Drift" then lift=.11*cycle; tilt=.08*cycle
    elseif clip=="HitLight" or clip=="HitHeavy" then tilt=accent*(clip=="HitHeavy" and -.32 or -.14)
    elseif clip=="Defeat" then tilt=.36*t; squeeze=t; lift=-.35*t
    else lift=.09*cycle end
    offset(model,"Core",CFrame.new(0,lift,0)*CFrame.Angles(0,0,tilt))
    for i,l in ipairs(lobes) do
        offset(model,"Lobe"..i,CFrame.new(-l[1]*.12*squeeze,-l[2]*.12*squeeze,0))
    end
    offset(model,"MouthUpper",CFrame.new(0,.15*open,0))
    offset(model,"MouthLower",CFrame.new(0,-.15*open,0))
    offset(model,"MouthRim",CFrame.new(0,0,-.13*open))
    if clip=="Defeat" or model:GetAttribute("Dispersing") then
        local surface=model:FindFirstChild("ImportedGeometry") or model
        for _,p in ipairs(surface:GetChildren()) do
            if p:IsA("BasePart") then p.Transparency=clip=="Defeat" and t or 0 end
        end
        model:SetAttribute("Dispersing",clip=="Defeat")
    end
end

function Cloud.attachGas(parent,anchor)
    local model = Instance.new("Model")
    model.Name = "GasCloud"
    for i=1,4 do
        local a=i*2.4
        ball(model,"Puff"..i,anchor,CFrame.new(.30*math.cos(a),.21*math.sin(a),.19*i-.4),
            Vector3.new(.85,.71,.76),Color3.fromRGB(143-i*10,164-i*8,47),false)
    end
    model.Parent=parent
    return model
end
return Cloud

