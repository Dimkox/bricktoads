
local H=game:GetService("HttpService")
local C=require(game.Players.LocalPlayer.PlayerScripts.BrickToads.SpectatorCamera)
local c=C.new();local function sync(run,world)
 c:sync({runId=run,levelEpoch=1,worldName=world,heroes={}},nil);c:refreshTargets()
end
local f=Instance.new("BindableFunction");f.Name="BossIntroCameraReview"
f.OnInvoke=function(mode)
 local cam=workspace.CurrentCamera;local old=cam.CFrame
 local run,world="Native-BossIntroEngineReview","BossIntroEngineReview"
 if mode=="other"then world="BossIntroOtherParty"elseif mode=="stale"then run="stale"end
 sync(run,world)
 if mode=="free"then c.mode="Free";c.freePosition=Vector3.zero end
 local applied=c:stepIntro(.016,cam)
 local row={mode=mode,applied=applied,intro=cam:GetAttribute("BossIntroId"),cf={cam.CFrame:GetComponents()}}
 cam.CFrame=old
 return H:JSONEncode(row)
end;f.Parent=game.Players.LocalPlayer.PlayerScripts
return "Native client camera probe ready"
