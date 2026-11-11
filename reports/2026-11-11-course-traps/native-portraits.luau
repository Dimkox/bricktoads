-- Native source-model visual review only. Normalized presentation sizes are
-- separate from the real renderer envelopes verified in prepared-native.json.
assert(game:GetService('RunService'):IsStudio(),'Studio only')
local SS=game:GetService('ServerStorage')
assert(not SS:FindFirstChild('BrickToadsCoursePropPortraitQA'))
assert(not workspace:FindFirstChild('BrickToadsCoursePropPortraits'))
local owner=Instance.new('Folder');owner.Name='BrickToadsCoursePropPortraitQA';owner.Parent=SS
local module=game.ServerScriptService.BrickToads.gameplay.CoursePropAppearance:Clone();module.Parent=owner
local Appearance=require(module)
local gallery=Instance.new('Model');gallery.Name='BrickToadsCoursePropPortraits';gallery.Parent=workspace
local floor=Instance.new('Part');floor.Name='PortraitDisplayFloor';floor.Size=Vector3.new(100,1,65)
floor.CFrame=CFrame.new(20000,-.55,0);floor.Anchored=true;floor.CanCollide=false;floor.CanTouch=false;floor.CanQuery=false
floor.Color=Color3.fromRGB(40,48,54);floor.Material=Enum.Material.SmoothPlastic;floor.Parent=gallery
local templates=SS.BrickToadsCoursePropTemplates:GetChildren();table.sort(templates,function(a,b)return a.Name<b.Name end)
local rows={}
for index,t in ipairs(templates)do
    local r=Vector3.new(t.ReferenceSizeX.Value,t.ReferenceSizeY.Value,t.ReferenceSizeZ.Value)
    local scale=8/math.max(r.X,r.Y,r.Z);local size=r*scale
    local x,z=20000+((index-1)%7-3)*12,(math.floor((index-1)/7)-1.5)*14
    local p=Instance.new('Part');p.Name='PortraitAnchor_'..t.Name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
    p.Transparency=0;p.Size=size;p.CFrame=CFrame.new(x,size.Y/2+.05,z)
    if t.FitMode.Value=='Tower'then p.Size=Vector3.new(size.Y,size.X,size.Z);p.CFrame*=CFrame.Angles(0,0,math.pi/2)end
    p.Parent=gallery
    local row={part=p,kind=t.Name,id='portrait-'..t.Name}
    Appearance.update(row,gallery,{alpha=0,hazard=true},.8)
    assert(row.coursePropAppearance,'Missing portrait '..t.Name)
    p.LocalTransparencyModifier=1
    rows[#rows+1]=row
end
local cleanup=Instance.new('BindableFunction');cleanup.Name='Cleanup';cleanup.Parent=owner
cleanup.OnInvoke=function()
    for _,row in ipairs(rows)do Appearance.remove(row);row.part:Destroy()end
    gallery:Destroy();owner:Destroy();return true
end
return{portraits=#rows,gallery=gallery:GetFullName(),scope='Normalized native source portraits; not actual gameplay fit or client visibility proof'}
