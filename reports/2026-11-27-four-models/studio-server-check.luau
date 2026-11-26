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
local gallery=Instance.new('Model');gallery.Name='FourModelsQA';gallery.ModelStreamingMode=Enum.ModelStreamingMode.Persistent;gallery.Parent=workspace
local locations={RatPod=-11,Meteorite=-4,ScuzzVisual=3,ShadowCloud=10}
local function check(model,name,holder)
local limit=os.clock()+25
repeat task.wait(.1) until model:FindFirstChild('ImportedGeometry') or os.clock()>limit
local imported=assert(model:FindFirstChild('ImportedGeometry'),'Missing detailed '..name)
local count=0
for _,v in imported:GetChildren() do if v:IsA('MeshPart') then assert(v.Size.Magnitude>0 and not v.CanCollide and not v.CanTouch and not v.CanQuery);count+=1 end end
if not gallery:FindFirstChild(name) then
 local obj=holder:Clone()
 local g=Instance.new('Model');g.Name=name;g.Parent=gallery;obj.Parent=g
 for _,v in g:GetDescendants() do if v:IsA('BasePart') then v.Anchored=true end end
 g:PivotTo(CFrame.new(locations[name],90,0))
end
return count
end
local out={}
for _,i in ipairs({3,7,10,12}) do
local w,r=make(i)
if i==3 or i==7 then
local kind=i==3 and 'RatPod' or 'Meteorite'
local h
for _,v in ipairs(r.course.hazards) do if v.kind==kind then h=v end end
assert(h)
local p=w:campaignObject('qa',kind,h,{w=h.w,h=h.h,d=h.d},{role='Hazard',hazard=true,velocity={x=0,y=0,z=1}})
local model=assert(p:FindFirstChildOfClass('Model'))
local imported=check(model,kind,p)
local count=0
for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then assert(not v.CanCollide and not v.CanTouch and not v.CanQuery);count+=1 end end
w:campaignAirImpact('qa')
assert(model:GetAttribute('ImpactShown'))
w:campaignRemove('qa')
assert(p.Parent==nil)
out[kind]={visualParts=count,imported=imported}
else
for _,e in ipairs(r.zones[1].enemies) do if e.kind=='Scuzz' or (e.kind=='Swellcheeks' and e.sourceVariant==3) then
assert(w:spawnEnemy(e.id,e.kind,e))
local a=w.actors[e.id];local model=assert(a.shadowCloud or (a.scuzz and a.scuzz.model))
local imported=check(model,model.Name,a.model)
local num=0
for _,v in ipairs(model:GetDescendants()) do if v:IsA('BasePart') then assert(not v.CanCollide and not v.CanTouch and not v.CanQuery);num+=1 end end
if a.scuzz then a.scuzz.pose('Attack66',.5); a.scuzz.pose('Attack68',.7) end
if a.shadowCloud then w:projectile(-6100,e,false,'GasCloud',e.id);assert(w.actors[-6100].shadowGas);w:removeProjectile(-6100) end
out[model.Name]={visualParts=num,imported=imported}
end end
end
w.folder:Destroy()
end
return game:GetService('HttpService'):JSONEncode(out)
