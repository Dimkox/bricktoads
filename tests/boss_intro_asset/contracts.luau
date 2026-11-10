-- Run the actual loader with ServerStorage present, so the imported path is
-- exercised independently of the existing generic-foot world contracts.
function Vec.__add(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
local enums=setmetatable({},{__index=function(_,key)
    return setmetatable({},{__index=function(_,name)return name end})
end})
local env=setmetatable({game={GetService=function(_,name)assert(name=='ServerStorage');return storage end},
    Instance={new=function(class)return node(class)end},CFrame=cf,Vector3={new=vector},Color3=colors,Enum=enums},
    {__index=getfenv()})
local loader=assert(loadstring(IntroSource));setfenv(loader,env)
local World={}
World.__index=World
function World.new(z)
    return setmetatable({folder=node('Folder','PartyWorld',workspace),offset=vector(0,0,z or 0),
        actors={[1]={identity='same-hero',owner=531}},clears=0},World)
end
function World:clearActors()self.clears+=1 end
loader()(World)
local function state(id)
    return {id=id or 'run:intro',active=true,runId='run',levelEpoch=2,counter=100,phase='FootMotion',
        cameraCut=false,fearFrame=0x32,startedAt=3,bossPosition={x=628,y=3,z=0},footFrame=0x12}
end
local function resource()
    local previous=storage:FindFirstChild('BrickToadsBossTemplates')
    if previous then previous:Destroy()end
    local folder=node('Folder','BrickToadsBossTemplates',storage)
    local model=node('Model','BossWalkerIntroLeg',folder)
    tag(model,'StringValue','AppearanceProfile','CanonicalBossWalkerIntroLeg')
    tag(model,'NumberValue','AppearanceScale',1)
    tag(model,'StringValue','SourceAssetId','123456')
    tag(model,'StringValue','SourceGlbSha256',string.rep('a',64))
    tag(model,'StringValue','AssetManifestSha256',string.rep('b',64))
    local part=node('MeshPart','IntroLeg12',model);part._props.MeshId='rbxassetid://987654'
    part.TextureID='rbxassetid://987655';part.Size=vector(4,23.28,3);part.MeshSize=vector(2,11.64,1.5)
    part.CFrame=cf.new(2,11.64,1)*cf.Angles(0,math.pi,0)
    part.Color=colors.fromRGB(180,20,20);part.Transparency=.15;part.Anchored=true
    part.CanCollide=true;part.CanTouch=true;part.CanQuery=true;part.Massless=false
    local origin=node('Attachment','IntroOriginRigAttachment',part);origin.CFrame=part.CFrame:Inverse()
    local surface=node('SurfaceAppearance','SurfaceAppearance',part)
    surface.ColorMap='rbxassetid://987655';surface.Color=colors.fromRGB(255,255,255)
    return model,part
end
local function sameFrame(a,b)
    local av,bv={a:GetComponents()},{b:GetComponents()}
    for i=1,12 do assert(math.abs(av[i]-bv[i])<1e-5,'Unexpected intro transform component '..i)end
end
local function fallback(world)
    assert(#world.bossIntroParts>1,'Rejected intro resource must use the existing complete proxy')
    for _,row in ipairs(world.bossIntroParts)do assert(row.part:IsA('Part'),'Fallback must not retain imported content')end
end
local passed,failed=0,0
local function test(name,fn)
    local ok,reason=pcall(fn)
    if ok then passed+=1;print('PASS '..name)
    else failed+=1;print('FAIL '..name..': '..tostring(reason))end
end

test('valid imported leg preserves the source rest transform and nonphysical party-local lifecycle',function()
    local _,source=resource();local rest=source.CFrame
    local a,b=World.new(200),World.new(1200)
    a:bossIntro(state());b:bossIntro(state())
    assert(#a.bossIntroParts==1 and #b.bossIntroParts==1,'Valid uploaded intro leg must replace the generic foot')
    local mesh,other=a.bossIntroParts[1].part,b.bossIntroParts[1].part
    assert(mesh:IsA('MeshPart')and mesh~=source and mesh~=other)
    assert(mesh.MeshId==source.MeshId and mesh.TextureID==source.TextureID
        and mesh.SurfaceAppearance.ColorMap==source.SurfaceAppearance.ColorMap)
    assert(mesh.Anchored and mesh.Massless and not mesh.CanCollide and not mesh.CanTouch and not mesh.CanQuery)
    sameFrame(mesh.CFrame,cf.new(612,0,200)*rest)
    sameFrame(other.CFrame,cf.new(612,0,1200)*rest)
    sameFrame(source.CFrame,rest)
    local before=created;local beforeClones=cloned
    for counter=101,254 do local nextState=state();nextState.counter=counter;a:bossIntro(nextState)end
    assert(created==before and cloned==beforeClones,'Intro playback must reuse the preassembled leg and ripples')
    local old=a.bossIntroFolder;local otherFolder=b.bossIntroFolder
    a:clearActors();assert(a.clears==1 and not a.bossIntroFolder and old.destroyed)
    assert(b.bossIntroFolder==otherFolder and not otherFolder.destroyed and not other.destroyed)
    assert(a.actors[1].identity=='same-hero'and a.actors[1].owner==531)
    b:bossIntro(nil);assert(otherFolder.destroyed)
end)

local rejected={
    {'nested collider under origin',function(m,p)local c=node('Part','HiddenCollider',p.IntroOriginRigAttachment);c.CanCollide=true end},
    {'nested behavior under appearance',function(m,p)node('Script','HiddenBehavior',p.SurfaceAppearance)end},
    {'nested behavior under metadata',function(m)node('Script','HiddenBehavior',m.AppearanceProfile)end},
    {'unknown metadata name',function(m)tag(m,'StringValue','UnknownTemplateContent','unexpected')end},
    {'duplicate profile metadata',function(m)tag(m,'StringValue','AppearanceProfile','CanonicalBossWalkerIntroLeg')end},
    {'duplicate scale metadata',function(m)tag(m,'NumberValue','AppearanceScale',1)end},
    {'zero uploaded mesh ID',function(m,p)p._props.MeshId='rbxassetid://0'end},
    {'invalid imported mesh extent',function(m,p)p.MeshSize=vector(2,0,1)end},
    {'duplicate surface appearance',function(m,p)node('SurfaceAppearance','SurfaceAppearance',p)end},
    {'unexpected direct behavior',function(m,p)node('Script','HiddenBehavior',p)end},
    {'invisible source mesh',function(m,p)p.Transparency=1 end},
    {'missing intro origin',function(m,p)p.IntroOriginRigAttachment:Destroy()end},
    {'misaligned intro origin',function(m,p)p.IntroOriginRigAttachment.CFrame=cf.new(0,0,1)end},
}
for _,row in ipairs(rejected)do
    test('reject '..row[1]..' before cloning and retain fallback',function()
        local model,part=resource();row[2](model,part)
        local before=cloned;local world=World.new(200)
        world:bossIntro(state());fallback(world)
        assert(cloned==before,'Invalid nested content must be rejected before Clone')
        assert(world.actors[1].identity=='same-hero'and world.actors[1].owner==531)
        world:clearActors()
    end)
end

test('missing resource uses the scoped fallback',function()
    local folder=storage:FindFirstChild('BrickToadsBossTemplates');if folder then folder:Destroy()end
    local world=World.new(200);world:bossIntro(state());fallback(world);world:clearActors()
end)
test('missing native MeshSize surface preserves a valid imported leg',function()
    local _,part=resource();part.MeshSize=nil
    local world=World.new(200);world:bossIntro(state())
    assert(#world.bossIntroParts==1 and world.bossIntroParts[1].part:IsA('MeshPart'))
    world:clearActors()
end)
print('BossIntro asset contracts: '..passed..' passed, '..failed..' failed')
assert(failed==0,'Imported intro-leg validation accepted malformed resources')
