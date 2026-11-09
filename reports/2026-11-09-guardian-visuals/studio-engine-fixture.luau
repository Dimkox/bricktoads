
local H=game:GetService("HttpService");local p=game.ServerScriptService.BrickToads;local g=p.gameplay;local r=p.CombatRuntime
local W=require(g.GameWorld);require(g.BossIntroWorld)(W)
local cfg=require(g.GameConfig)(require(r.Config),require(g.LevelDefinition));local GA=require(g.GuardianAppearance)
local function world(name,z)return W.new(require(r.RobloxWorld),cfg,{name=name,offset={z=z},
 characterAppearance=require(g.CharacterAppearance),guardianAppearance=GA})end
local w,w2=world("GuardianVisualEngineReview",-360),world("GuardianVisualOtherParty",-720)
local s=require(r.Session).new(require(p.RunLifecycle),require(r.Combat),cfg,{{userId=1,template="Mr. Green"},{userId=2,template="Mr. Yellow"}},
 "GuardianVisualNative",w,nil,{groupId="review",levelId="causeway-1"});s:step(100)
local d=require(g.LevelDirector).new(s,w,require(r.Combat),cfg,require(g.GuardianPattern),require(g.HealingFlies),
 require(g.EnemyCarry),require(g.WalkerClubs),require(g.DragonFlight),require(g.BossIntro)(require(g.CanonicalAnimation)))
require(g.SourceCombat).bind(s,d,cfg)
local pos=cfg.Level.boss.position
local floor=Instance.new("Part");floor.Name="PreparedSupport";floor.Size=Vector3.new(48,1,34);floor.Anchored=true
floor.CFrame=CFrame.new(Vector3.new(pos.x-18,pos.y-3.5,pos.z)+w.offset);floor.Parent=w.geometry
for id,a in w.actors do if id>0 then a.model:PivotTo(CFrame.new(Vector3.new(pos.x-18,pos.y,pos.z+(id-1.5)*7)+w.offset)*CFrame.Angles(0,-math.pi/2,0))end end
assert(w2:spawnEnemy(-99,"Boss",pos))
local results={scope="Prepared native Session/Director/World fixture with fixture support/positioning and advanced time; accepted fire, ball pickup/throw and actual collision resolution; not a full normal-input route"}
local function sample(a)
 local st=assert(a.guardianAppearance);local rows={}
 local mesh,motors,welds,physical=0,0,0,0
 for _,v in a.model:GetDescendants()do
  if v:IsA("BasePart")and v.CanCollide then physical+=1 end
 end
 for _,v in st.model:GetDescendants()do
  if v:IsA("BasePart")then assert(not v.Anchored and v.Massless and not v.CanCollide and not v.CanTouch and not v.CanQuery)end
  if v:IsA("MeshPart")then mesh+=1 elseif v:IsA("Motor6D")then motors+=1 elseif v:IsA("WeldConstraint")then welds+=1 end
 end
 for i,row in ipairs(st.rows)do
  local muzzle=row.part:FindFirstChild("MuzzleRigAttachment")
  rows[i]={name=row.part.Name,recoil=(row.motor.C0.Position-row.base.Position).Z,
   flash=row.flash and row.flash.Transparency,untinted=row.part.Color==row.color,
   jointError=((row.motor.Part0.CFrame*row.motor.C0).Position-(row.motor.Part1.CFrame*row.motor.C1).Position).Magnitude,
   muzzleError=muzzle and (row.flash.Position-(row.part.CFrame*muzzle.CFrame).Position).Magnitude}
 end
 local owner=false;pcall(function()owner=a.root:GetNetworkOwner()==nil and not a.root:GetNetworkOwnershipAuto()end)
 return {profile=st.profile,meshes=mesh,motors=motors,welds=welds,physicalColliders=physical,
 hp=a.humanoid.Health,shotSerial=st.shotSerial,normalizedHealth=st.normalizedHealth,rows=rows,
 manualServerOwner=owner,assemblyRoot=a.root.AssemblyRootPart==a.root,legacyAbsent=a.model:FindFirstChild("GuardianBase")==nil}
end
local function render(dt)w:updatePresentation(s,dt or 0,d.enemies)end
local function advance(dt)
 s.now+=dt;d.now=s.now;d.guardian:step(s.now,dt);render(dt)
end
local f=Instance.new("BindableFunction");f.Name="GuardianVisualEngineFixture"
f.OnInvoke=function(cmd,value)
 if cmd=="begin"then
 task.wait(.3);w.actors[1].humanoid.Health=37
 d.bossGate=function()return {state="Human",userId=999}end;d:_boss()
 s.now=100+100/60+1e-7;d:step(s.now,.016);render(.016)
 local count=0;for _,v in w.bossIntroFolder:GetDescendants()do if v:IsA("BasePart")then count+=1;assert(v.Anchored and v.Massless and not v.CanCollide and not v.CanTouch and not v.CanQuery)end end
 assert(#w.bossIntroParts==1 and w.bossIntroParts[1].part.Name=="IntroLeg12" and count==3)
 results.intro={counter=100,meshParts=#w.bossIntroParts,totalParts=count,texture=w.bossIntroParts[1].part.TextureID}
 s.now=100+255/60+1e-7;d:step(s.now,.016);render(.016);task.wait(.08)
 assert(d.stage=="Boss" and d.enemies[-99].ownerUserId==999 and not w.bossIntroFolder)
 results.initial=sample(w.actors[-99]);assert(results.initial.meshes==3 and results.initial.motors==3 and results.initial.welds==2 and results.initial.manualServerOwner and results.initial.legacyAbsent)
 results.otherBefore=sample(w2.actors[-99]);return H:JSONEncode({intro=results.intro,initial=results.initial})
 elseif cmd=="battle"then
 local a=w.actors[-99];local st=a.guardianAppearance;local pattern=d.guardian
 s.now+=2;d.now=s.now
 assert(pattern:fire({x=-1,z=0})=="OK");task.wait(.06)
 results.bullet=sample(a);assert(results.bullet.shotSerial==1 and results.bullet.rows[2].recoil>.24 and results.bullet.rows[2].flash==0 and results.bullet.rows[3].recoil==0)
 for id in pairs(d.projectiles)do pattern:_remove(id)end
 for _=1,4 do render(.1)end;task.wait(.04)
 pattern:hit(1,-99,"Punch");results.blocked=sample(a)
 assert(results.blocked.shotSerial==1 and results.blocked.rows[2].recoil==0 and results.blocked.rows[2].flash==1 and not st.hurtAt)
 results.rounds={}
 for round=1,3 do
  assert(pattern:_spawn("Heavy",nil,1));local shot=sample(a)
  if round==1 then assert(shot.shotSerial==2 and shot.rows[3].recoil>.24 and shot.rows[3].flash==0);results.heavy=shot end
  local ground=false
  for _=1,50 do advance(.1);if pattern:interaction(1).available then ground=true;break end end
  assert(ground,"Heavy ball did not become available")
  assert(pattern:interact(1,s.now)=="OK");assert(pattern:interaction(1).carrying)
  s.now+=.02;d.now=s.now;assert(pattern:interact(1,s.now)=="OK")
  local before=d.enemies[-99].rawLife
  for _=1,40 do advance(.05);if d.enemies[-99].rawLife<before then break end end
  local row={rawLife=d.enemies[-99].rawLife,hits=d.bossHits,stage=d.stage,presentation=sample(a)}
  assert(row.rawLife==({31,15,0})[round]);results.rounds[#results.rounds+1]=row
  if round<3 then
   for _=1,5 do render(.1)end;task.wait(.03)
   local restored=sample(a);for _,part in ipairs(restored.rows)do assert(part.untinted and part.recoil==0 and (part.flash==nil or part.flash==1))end
  end
 end
 results.otherAfter=sample(w2.actors[-99])
 assert(results.otherAfter.shotSerial==0 and results.otherAfter.normalizedHealth==1)
 results.heroHP=w.actors[1].humanoid.Health;results.otherHeroHP=w.actors[2].humanoid.Health
 results.resources=s.state.heroes[1];results.bossOwner=d.enemies[-99].ownerUserId
 assert(results.heroHP==37 and results.otherHeroHP==100 and results.resources.attempt==1 and results.resources.respawns==3 and results.bossOwner==999)
 assert(d.stage=="Exit" and not next(d.projectiles))
 results.passed=true;return H:JSONEncode(results)
 elseif cmd=="destroy"then d:cancelBossIntro("ReviewDone");w:clearActors();w.folder:Destroy();w2:clearActors();w2.folder:Destroy();f:Destroy();return "destroyed"end
 return "unknown"
end;f.Parent=game.ServerStorage
return "Guardian native fixture ready"
