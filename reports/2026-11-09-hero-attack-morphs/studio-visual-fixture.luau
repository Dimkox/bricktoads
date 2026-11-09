
local root=Instance.new("Folder");root.Name="HeroMorphVisualReview";root.Parent=workspace
local A=require(game.ServerScriptService.BrickToads.gameplay.CharacterAppearance)
local rows={}
local function make(name,hero,action,pos)
 local model=Instance.new("Model");model.Name=name
 local torso=Instance.new("Part");torso.Name="Torso";torso.Anchored=true;torso.Transparency=1;torso.CanCollide=false;torso.CFrame=CFrame.new(pos);torso.Parent=model
 for _,n in {"Neck","Left Shoulder","Right Shoulder","Left Hip","Right Hip"} do local j=Instance.new("Motor6D");j.Name=n;j.C0=CFrame.new();j.Parent=torso end
 model.Parent=root
 local actor={model=model};assert(A.attach(actor,hero))
 local attack={action=action,actorId=80001,at=.1,tuning={windup=.1}}
 local c={enabled=true,actorId=80001,now=0,dt=.016,grounded=true,mode="Idle",speed=0,attack=attack}
 A.update(actor,c);c.now=.5;A.update(actor,c)
 local state=actor.appearance;local skin=state.model;local r=skin.LowerTorso.AppearanceRoot
 skin.LowerTorso.CFrame=torso.CFrame*r.C0*r.C1:Inverse()
 for _,n in {"Waist","Neck","LeftShoulder","RightShoulder","LeftElbow","RightElbow","LeftWrist","RightWrist","LeftHip","RightHip","LeftKnee","RightKnee","LeftAnkle","RightAnkle"}do local j=state.joints[n].motor;j.Part1.CFrame=j.Part0.CFrame*j.C0*j.C1:Inverse()end
 for _,row in state.morphs do local j=row.joint;j.Part1.CFrame=j.Part0.CFrame*j.C0*j.C1:Inverse()end
 for _,p in model:GetDescendants()do if p:IsA("BasePart")then p.Anchored=true end end
 local floor=Instance.new("Part");floor.Name=name.."Platform";floor.Size=Vector3.new(8,.3,12);floor.CFrame=CFrame.new(pos+Vector3.new(0,-3.2,-1.7));floor.Color=Color3.fromRGB(42,52,58);floor.Material=Enum.Material.Slate;floor.Anchored=true;floor.Parent=root
 local active=state.morphs[state.activeMorph]
 table.insert(rows,{name=name,frame=state.sourcePose.frameId,morph=state.activeMorph,
    morphPosition={active.part.Position.X,active.part.Position.Y,active.part.Position.Z},texture=active.part.TextureID})
end
make("GreenPowerFist","Mr. Green","HeroPowerPunch",Vector3.new(-5,6,-180))
make("GreenBigBoot","Mr. Green","HeroBoot",Vector3.new(5,6,-180))
make("PlayerTwoPowerFist","Mr. Yellow","HeroPowerPunch",Vector3.new(-5,6,-199))
make("PlayerTwoBigBoot","Mr. Yellow","HeroBoot",Vector3.new(5,6,-199))
game.Lighting.ClockTime=14;game.Lighting.Ambient=Color3.fromRGB(130,130,130);game.Lighting.OutdoorAmbient=Color3.fromRGB(160,160,160)
return game:GetService("HttpService"):JSONEncode({scope="Edit-time native resource/FK visual review, exact runtime pose sampling at source1C/1E; not Play physics",actors=rows})
