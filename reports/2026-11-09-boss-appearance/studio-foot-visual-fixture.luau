
local folder=workspace.HeroFearVisualReview
local T={clearActors=function()end};require(game.ServerScriptService.BrickToads.gameplay.BossIntroWorld)(T)
local w=setmetatable({folder=folder,offset=Vector3.zero},{__index=T})
w:bossIntro({id="VisualFoot12",runId="Visual",levelEpoch=1,active=true,counter=100,phase="BeforeCut",
 fearFrame=0x32,cameraCut=false,startedAt=0,bossPosition={x=9,y=3,z=-164},footFrame=0x12,events={},heroActors={}})
local platform=Instance.new("Part");platform.Name="FootVisualSupport";platform.Size=Vector3.new(20,1,16);platform.Anchored=true
platform.CFrame=CFrame.new(-7,-.5,-164);platform.Color=Color3.fromRGB(40,50,54);platform.Parent=folder
local count=0
for _,p in w.bossIntroFolder:GetDescendants()do if p:IsA("BasePart")then
 count+=1;assert(p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery)end end
return game:GetService("HttpService"):JSONEncode({scope="Edit-time native source100/foot12 prop visual",parts=count,nonphysical=true})
