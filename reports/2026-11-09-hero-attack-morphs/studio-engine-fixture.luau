
local H=game:GetService("HttpService")
local project=game.ServerScriptService.BrickToads
local A=require(project.gameplay.CharacterAppearance)
local W=require(project.gameplay.GameWorld)
local cfg=require(project.gameplay.GameConfig)(require(project.CombatRuntime.Config),require(project.gameplay.LevelDefinition))
local w=W.new(require(project.CombatRuntime.RobloxWorld),cfg,{name="HeroMorphEngineReview",offset={x=0,y=0,z=-180},characterAppearance=A})
assert(w:spawn(1,80001,nil,false,"Mr. Green"));assert(w:spawn(2,80002,nil,false,"Mr. Yellow"))
local s={now=100,sourceCombat=true,combat={[1]={},[2]={}}}
local function tick(n) s.now+=n or .01;w:updatePresentation(s,.016,{}) end
local function sample(id)
 local a=w.actors[id];local t=a.appearance;local p=t.sourcePose;local parts,motors,colliders=0,0,0
 for _,v in a.model:GetDescendants() do
  if v:IsA("BasePart") and v.CanCollide then colliders+=1 end
  if v:IsA("MeshPart") then parts+=1;assert(not v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery and v.Massless) end
  if v:IsA("Motor6D") then motors+=1 end
 end
 local morphs={}
 for k,r in t.morphs do morphs[k]={visible=r.part.Transparency,original=r.originalPart.Transparency,
    jointError=((r.joint.Part0.CFrame*r.joint.C0).Position-(r.joint.Part1.CFrame*r.joint.C1).Position).Magnitude} end
 return {id=id,actorId=a.model:GetAttribute("ActorId"),active=t.activeMorph,frame=p and p.frameId,kind=p and p.kind,
  fallback=t.sourceFallback,morphs=morphs,meshes=parts,motors=motors,colliders=colliders,hp=a.humanoid.Health,
  manualServerOwner=a.root:GetNetworkOwner()==nil and not a.root:GetNetworkOwnershipAuto(),
  assemblyRoot=a.root.AssemblyRootPart==a.root,grounded=a.humanoid.FloorMaterial~=Enum.Material.Air}
end
local function begin(id,action)
 local at=s.now
 s.combat[id]={attack={action=action,actorId=w.actors[id].model:GetAttribute("ActorId"),at=at+.1,tuning={windup=.1}}}
 tick(.001)
end
local function expect(id,kind)
 local v=sample(id);assert(v.active==kind,"wrong morph "..tostring(v.active).." vs "..tostring(kind))
 assert(v.meshes==17 and v.manualServerOwner and v.assemblyRoot)
 for k,r in v.morphs do assert(r.visible==(k==kind and 0 or 1),"morph visibility "..k) end
 return v
end
local f=Instance.new("BindableFunction");f.Name="HeroMorphEngineFixture"
f.OnInvoke=function(cmd)
 if cmd=="inspect" then return H:JSONEncode({one=sample(1),two=sample(2)}) end
 if cmd=="destroy" then w:clearActors();w.folder:Destroy();f:Destroy();return "destroyed" end
 if cmd=="run" then
  task.wait(.4);tick();w.actors[1].humanoid.Health=37
  local result={scope="Prepared native World/server fixture from freshly reopened serialized place; clock advanced explicitly; no claim of physical touch or complete normal-input combat"}
  result.initial={one=expect(1,nil),two=expect(2,nil)}
  begin(1,"HeroPowerPunch");result.fistWindup=expect(1,nil);tick(.5);task.wait(.05);result.fistActive=expect(1,"PowerFist")
  assert(result.fistActive.frame==0x1C and result.fistActive.morphs.PowerFist.original==1)
  assert(sample(2).active==nil and sample(2).morphs.PowerFist.original==0)
  tick(1);task.wait(.05);result.fistEnd=expect(1,nil);assert(result.fistEnd.morphs.PowerFist.original==0)
  begin(1,"HeroBoot");tick(.1);result.bootWindup=expect(1,nil);assert(result.bootWindup.frame==0x1F)
  tick(.4);task.wait(.05);result.bootActive=expect(1,"BigBoot");assert(result.bootActive.frame==0x1E and result.bootActive.morphs.BigBoot.original==1)
  begin(2,"HeroPowerPunch");tick(.5);task.wait(.05);result.playerTwo=expect(2,"PowerFist")
  s.combat[1]={reactionEnd=s.now+1,reactionEpoch=1};tick();result.interrupted=expect(1,nil);assert(result.interrupted.morphs.BigBoot.original==0)
  s.combat[1]={};tick();begin(1,"HeroPowerPunch");tick(.5);expect(1,"PowerFist")
  assert(w:equipClub("morph-review-club",1));tick();task.wait(.05);result.club=expect(1,nil);assert(result.club.morphs.PowerFist.original==0)
  w:unequipClub("morph-review-club")
  s.combat[1]={};tick();begin(1,"HeroBoot");tick(.5);expect(1,"BigBoot")
  A.update(w.actors[1],nil);result.noContext=expect(1,nil);assert(result.noContext.morphs.BigBoot.original==0)
  s.combat[1]={};tick();begin(1,"HeroBoot");tick(.5);expect(1,"BigBoot")
  
  s.combat[1]={deathAt=s.now};tick();result.deathPriority=expect(1,nil);assert(result.deathPriority.fallback=="Dead")
  s.combat[1]={};tick();local hand=w.actors[1].appearance.model.RightHand;hand.Transparency=.25
  begin(1,"HeroPowerPunch");tick(.5);expect(1,"PowerFist");tick(1);result.partialTransparency=expect(1,nil)
  assert(result.partialTransparency.morphs.PowerFist.original==.25);hand.Transparency=0
  begin(1,"HeroBoot");tick(.5);expect(1,"BigBoot");w:jump(1);task.wait(.12);tick()
  result.airborne=expect(1,nil);assert(result.airborne.fallback=="Airborne" and not result.airborne.grounded)
  task.wait(.8);s.combat[1]={};tick()
  local old=w.actors[1].model;local oldState=w.actors[1].appearance;local other=w.actors[2].model
  assert(w:spawn(1,80003,nil,false,"Mr. Green"));task.wait(.3);s.combat[1]={};tick()
  result.replacement=expect(1,nil);result.replacement.oldDestroyed=old.Parent==nil;result.replacement.otherSame=w.actors[2].model==other
  assert(result.replacement.oldDestroyed and result.replacement.otherSame)
  result.hpBeforeReplace=result.club.hp;result.otherHp=sample(2).hp
  assert(result.hpBeforeReplace==37 and result.otherHp==100)
  result.passed=true
  return H:JSONEncode(result)
 end
 return "unknown command"
end
f.Parent=game.ServerStorage
return "Hero morph engine fixture ready"
