
local H=game:GetService("HttpService");local p=game.ServerScriptService.BrickToads;local g=p.gameplay;local r=p.CombatRuntime
local W=require(g.GameWorld);require(g.BossIntroWorld)(W)
local cfg=require(g.GameConfig)(require(r.Config),require(g.LevelDefinition))
local Intro=require(g.BossIntro)(require(g.CanonicalAnimation))
local function prepare(name,z)
 local w=W.new(require(r.RobloxWorld),cfg,{name=name,offset={z=z},characterAppearance=require(g.CharacterAppearance)})
 local s=require(r.Session).new(require(p.RunLifecycle),require(r.Combat),cfg,
 {{userId=1,template="Mr. Green"},{userId=2,template="Mr. Yellow"},{userId=3,template="Mr. Green"}},"Native-"..name,w,nil,{groupId=name,levelId="causeway-1"})
 s:step(100)
 local d=require(g.LevelDirector).new(s,w,require(r.Combat),cfg,require(g.GuardianPattern),require(g.HealingFlies),
 require(g.EnemyCarry),require(g.WalkerClubs),require(g.DragonFlight),Intro)
 require(g.SourceCombat).bind(s,d,cfg)
 return w,s,d
end
local w,s,d=prepare("BossIntroEngineReview",-360)
local w2,s2,d2=prepare("BossIntroOtherParty",-720)
local pos=cfg.Level.boss.position
local floor=Instance.new("Part");floor.Name="PreparedReviewSupport";floor.Size=Vector3.new(48,1,34);floor.Anchored=true
floor.CFrame=CFrame.new(Vector3.new(pos.x-18,pos.y-3.5,pos.z)+w.offset);floor.Parent=w.geometry
for id,a in w.actors do if id>0 then
 a.model:PivotTo(CFrame.new(Vector3.new(pos.x-18,pos.y,pos.z+(id-1.5)*7)+w.offset)*CFrame.Angles(0,-math.pi/2,0))
end end
local function sample(id)
 local a=w.actors[id];local state=a.appearance;local pose=state.sourcePose
 local n,motor=0,0
 for _,v in state.model:GetDescendants()do
 if v:IsA("MeshPart")then n+=1;assert(v.Massless and not v.CanCollide and not v.CanTouch and not v.CanQuery and not v.Anchored)end
 if v:IsA("Motor6D")then motor+=1 end
 end
 local morphs={};for kind,row in state.morphs do morphs[kind]={visible=row.part.Transparency,original=row.originalPart.Transparency,
 jointError=((row.joint.Part0.CFrame*row.joint.C0).Position-(row.joint.Part1.CFrame*row.joint.C1).Position).Magnitude}end
 return {actorId=a.model:GetAttribute("ActorId"),hp=a.humanoid.Health,rawLife=s.combat[id].rawLife,
 state=s.state.heroes[id],frame=pose and pose.frameId,kind=pose and pose.kind,morph=state.activeMorph,fallback=state.sourceFallback,
 meshes=n,cosmeticMotors=motor,morphs=morphs,manualServerOwner=a.root:GetNetworkOwner()==nil and not a.root:GetNetworkOwnershipAuto(),
 rootIsAssemblyRoot=a.root.AssemblyRootPart==a.root,grounded=a.humanoid.FloorMaterial~=Enum.Material.Air}
end
local function step(counter)
 local t=d.bossIntro.state.startedAt+counter/60+1e-7;s.now=t;d:step(t,.016);w:updatePresentation(s,.016,d.enemies);task.wait(.05)
 return {counter=counter,stage=d.stage,one=sample(1),two=sample(2),three=sample(3),intro=d.bossIntro:snapshot(),
 folder=w.folder:FindFirstChild("BossIntro")~=nil,bossExists=d.enemies[-99]~=nil}
end
local results={scope="Prepared native real Session/Director/World fixture, explicitly positioned actors/support and advanced intro clock; not a normal-input route"}
local f=Instance.new("BindableFunction");f.Name="BossIntroEngineFixture"
f.OnInvoke=function(cmd,value)
 if cmd=="begin"then
 task.wait(.4);w.actors[1].humanoid.Health=37
 results.before={one=sample(1),two=sample(2),otherFolder=w2.folder:FindFirstChild("BossIntro")~=nil}
 d.bossGate=function()return {state="Human",userId=999}end
 d:_boss();w:updatePresentation(s,.016,d.enemies);return H:JSONEncode({ready=true,bossPosition=pos,one=sample(1)})
 elseif cmd=="step"then local row=step(value);results[tostring(value)]=row;return H:JSONEncode(row)

 elseif cmd=="interruptions"then
  local a=w.actors[1];local c=s.combat[1];local r={}
  c.reactionEnd=s.now+1;c.reactionEpoch=1;w:updatePresentation(s,.016,d.enemies);r.reaction=sample(1)
  assert(r.reaction.morph==nil and r.reaction.fallback=="Reaction" and a.appearance.model.Head.Transparency==0)
  c.reactionEnd=nil;w:updatePresentation(s,.016,d.enemies);r.resumed=sample(1);assert(r.resumed.morph=="FearAfterCut")
  w:jump(1);task.wait(.12);w:updatePresentation(s,.016,d.enemies);r.air=sample(1)
  assert(r.air.morph==nil and r.air.fallback=="Airborne" and a.appearance.model.Head.Transparency==0)
  task.wait(.85);w:updatePresentation(s,.016,d.enemies);r.landed=sample(1);assert(r.landed.morph=="FearAfterCut")
  d:cancelBossIntro("NativeCancel");w:updatePresentation(s,.016,d.enemies);r.cancel=sample(1)
  assert(not w.folder:FindFirstChild("BossIntro") and not w.bossIntroState and r.cancel.morph==nil and a.appearance.model.Head.Transparency==0)
  r.hpRetained=a.humanoid.Health==37 and w.actors[2].humanoid.Health==100
  assert(r.hpRetained)
  -- A new prepared intro exercises the actual new-body guard independently.
  d.bossIntro=Intro.new(d);w:updatePresentation(s,.016,d.enemies)
  local old=a.model;assert(w:spawn(1,"NativeReviewReplacement",nil,false,"Mr. Green"));task.wait(.3)
  w:updatePresentation(s,.016,d.enemies);r.replacement=sample(1)
  assert(old.Parent==nil and r.replacement.morph==nil and r.replacement.manualServerOwner)
  d:cancelBossIntro("ReplacementReviewDone");w:updatePresentation(s,.016,d.enemies)
  results.interruptions=r;return H:JSONEncode(r)
 elseif cmd=="report"then
 results.otherPartyUntouched=w2.folder:FindFirstChild("BossIntro")==nil and w2.bossIntroState==nil and w2.actors[1].appearance.activeMorph==nil
 local e=d.enemies[-99];results.bossOwner=e and e.ownerUserId;results.passed=results.otherPartyUntouched and e and e.ownerUserId==999
 return H:JSONEncode(results)
 elseif cmd=="destroy"then d:cancelBossIntro("FixtureDone");w:clearActors();w.folder:Destroy();w2:clearActors();w2.folder:Destroy();f:Destroy();return "destroyed" end
 return "unknown command"
end
f.Parent=game.ServerStorage
return "Prepared real Session/Director/World boss fixture ready"
