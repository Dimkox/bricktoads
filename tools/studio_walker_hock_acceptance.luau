-- Run in Studio against the packaged gameplay modules.
local appearance=require(game.ServerScriptService:FindFirstChild("CanonicalCastAppearance",true))
local actor={model=Instance.new("Model"),root=Instance.new("Part")}
actor.root.Anchored=true
actor.root.Name="HumanoidRootPart"
actor.root.Parent=actor.model
local torso=Instance.new("Part")
torso.Name="Torso"
torso.Transparency=.2
torso.Parent=actor.model
assert(appearance.attach(actor,"Walker"))
local skin=actor.castAppearance
local rig=skin.walkerRig
assert(rig.model.Carapace:FindFirstChildOfClass("SpecialMesh").MeshType==Enum.MeshType.Sphere)
assert(torso.Transparency==1 and #rig.legs==2 and #rig.model:GetChildren()>=20)
local c={kind="Walker",actorId="field-test",levelEpoch=1,now=1,dt=.04,speed=0}
appearance.update(actor,c)
local function angles()
    local out={}
    for i,v in ipairs(rig.legs) do out[i]=math.deg(math.acos(v.hock.C0.YVector.Y)) end
    return out
end
local idle=angles()
c.now=1.22;c.reacting=true;c.reactionProgress=.25
appearance.update(actor,c)
local hit=angles()
for i=1,2 do assert(hit[i]>idle[i]+40) end
c.now=1.26;c.reactionHeavy=true
appearance.update(actor,c)
local heavy=angles()
for i=1,2 do assert(heavy[i]>hit[i]) end
c.now=2.4;c.reacting=false
appearance.update(actor,c)
local rest=angles()
for i=1,2 do assert(math.abs(rest[i]-idle[i])<.001) end
for _,part in rig.model:GetChildren() do assert(part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery) end
appearance.detach(actor)
assert(math.abs(torso.Transparency-.2)<.001 and not actor.castAppearance)
actor.model:Destroy()
return {idle=idle,hit=hit,heavy=heavy,recovered=rest}
