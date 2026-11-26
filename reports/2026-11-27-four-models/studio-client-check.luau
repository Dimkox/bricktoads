local g=assert(workspace:WaitForChild('FourModelsQA',15))
workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,93,-24),Vector3.new(0,90,0))
local out={}
for _,model in g:GetChildren() do
 local imported=model:FindFirstChild('ImportedGeometry',true)
 assert(imported)
 local deadline=os.clock()+3
 local r
 repeat
  r={meshes=0,visible=0,fallback=0,hidden=0}
  for _,v in imported:GetChildren() do
   if v:IsA('MeshPart') then
    r.meshes+=1
    if v.LocalTransparencyModifier<.5 and v.Transparency<.5 then r.visible+=1 end
   elseif v:IsA('ObjectValue') and v.Value then
    r.fallback+=1
    if v.Value.LocalTransparencyModifier>.99 then r.hidden+=1 end
   end
  end
  if r.fallback>0 and r.hidden==r.fallback and r.meshes==r.visible then break end
  task.wait(.1)
 until os.clock()>deadline
 out[model.Name]=r
end
return game:GetService('HttpService'):JSONEncode(out)
