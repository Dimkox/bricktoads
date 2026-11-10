
local folder=Instance.new("Folder");folder.Name="GuardianVisualReview";folder.Parent=workspace
local A=require(game.ServerScriptService.BrickToads.gameplay.GuardianAppearance)
local rows={}
local function actor(name,x,shot)
 local m=Instance.new("Model");m.Name=name;m.Parent=folder
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.CFrame=CFrame.new(x,3,-180);root.Parent=m
 local a={model=m,root=root};assert(A.attach(a));A.health(a,3,3,0)
 if shot then A.shot(a,"Bullet",0)end
 local state=a.guardianAppearance
 for _,row in ipairs(state.rows)do
  row.part.CFrame=root.CFrame*row.motor.C0*row.motor.C1:Inverse()
  if row.flash then row.flash.CFrame=row.part.CFrame*row.part.MuzzleRigAttachment.CFrame end
 end
 for _,p in m:GetDescendants()do if p:IsA("BasePart")then p.Anchored=true end end
 local base=Instance.new("Part");base.Name=name.."Plinth";base.Size=Vector3.new(12,.4,12);base.CFrame=CFrame.new(x,-.2,-180);base.Anchored=true;base.Color=Color3.fromRGB(40,50,54);base.Parent=folder
 rows[#rows+1]={name=name,profile=state.profile,shotSerial=state.shotSerial}
end
actor("GuardianIdle",-7,false);actor("GuardianFiring",7,true)
local T={clearActors=function()end};require(game.ServerScriptService.BrickToads.gameplay.BossIntroWorld)(T)
local w=setmetatable({folder=folder,offset=Vector3.zero},{__index=T})
w:bossIntro({id="GuardianVisualLeg",runId="Visual",levelEpoch=1,active=true,counter=100,phase="BeforeCut",
 fearFrame=0x32,cameraCut=false,startedAt=0,bossPosition={x=2,y=3,z=-158},footFrame=0x12,events={},heroActors={}})
assert(#w.bossIntroParts==1)
local ground=Instance.new("Part");ground.Name="IntroLegPlinth";ground.Size=Vector3.new(11,.4,8);ground.CFrame=CFrame.new(-12,-.2,-158);ground.Anchored=true;ground.Color=Color3.fromRGB(40,50,54);ground.Parent=folder
game.Lighting.ClockTime=14;game.Lighting.Ambient=Color3.fromRGB(130,130,130);game.Lighting.OutdoorAmbient=Color3.fromRGB(160,160,160)
return game:GetService("HttpService"):JSONEncode({scope="Edit native resource/FK visual fixtures; not ordinary gameplay",actors=rows,introParts=#w.bossIntroParts})
