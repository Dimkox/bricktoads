local root=game.ServerScriptService.BrickToads
local gameplay=root.gameplay
local runtime=root.CombatRuntime
local World=require(gameplay.GameWorld)
local config=require(gameplay.GameConfig)(require(runtime.Config),require(gameplay.LevelDefinition))
local function make(i)
local route=require(gameplay.CampaignDefinition).build(i,41)
local w=World.new(require(runtime.RobloxWorld),table.clone(config),{name='ModelQA'..i,offset={x=4000+i*200, y=0,z=6000},castAppearance=require(gameplay.CanonicalCastAppearance),campaignWorld=require(gameplay.CampaignWorld)})
assert(w:rebuildLevel(route))
return w,route
end
local totals={}
for _,index in {10,12} do
 local w,r=make(index)
 for _,e in r.zones[1].enemies do
  if e.kind=='Scuzz' or e.kind=='Swellcheeks' and e.sourceVariant==3 then
   assert(w:spawnEnemy(e.id,e.kind,e));local a=w.actors[e.id]
   a.root.Anchored=true
   local visible=a.shadowCloud or a.scuzz.model
   local imp=visible:WaitForChild('ImportedGeometry',8)
   local joint=a.scuzz and imp:FindFirstChild('Chest',true) or visible:FindFirstChild('MouthLowerJoint',true)
   local start=a.scuzz and joint.CFrame or joint.C0
   local name=a.scuzz and 'Attack68' or 'Gas';local state={mode='Active',attack={name=name,move={tell=.5,active=.6,recovery=.5},at=0,untilAt=.6}}
   w:updatePresentation({now=.20,combat={},state={heroes={},levelEpoch=1}},.1,{[e.id]=e},{campaignEnemies={states={[e.id]=state}}})
   local now=a.scuzz and joint.CFrame or joint.C0
   assert(not start:FuzzyEq(now,.00001),'unchanged '..name)
   totals[name]=true
   if a.scuzz then
    state.attack.name='Attack66';w:updatePresentation({now=.29,combat={},state={heroes={},levelEpoch=1}},.1,{[e.id]=e},{campaignEnemies={states={[e.id]=state}}});assert(not now:FuzzyEq(joint.CFrame,.00001));totals.Attack66=true
   end
   break
  end
 end
 w.folder:Destroy()
end
return game:GetService('HttpService'):JSONEncode(totals)
