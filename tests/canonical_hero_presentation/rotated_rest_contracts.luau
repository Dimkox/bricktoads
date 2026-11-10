-- Focused rigid-transform double: unlike the older Euler-addition fixture,
-- rotation order and rotated translations are real matrix operations here.
-- Uses actual imported P1 rest transforms; does not simulate rendering/physics.
local Rigid={}
local function rigid(position,rotation)
    return setmetatable({Position=position,r=rotation or {1,0,0,0,1,0,0,0,1}},Rigid)
end
local function rotate(r,v)
    return vector(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,
        r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)
end
Rigid.__index=function(a,key)
    if key=='Rotation' then return rigid(vector(),a.r) end
    return Rigid[key]
end
function Rigid.__mul(a,b)
    local r={}
    for i=0,2 do for j=1,3 do
        r[i*3+j]=a.r[i*3+1]*b.r[j]+a.r[i*3+2]*b.r[3+j]+a.r[i*3+3]*b.r[6+j]
    end end
    local p=rotate(a.r,b.Position)
    return rigid(vector(a.Position.X+p.X,a.Position.Y+p.Y,a.Position.Z+p.Z),r)
end
function Rigid:Inverse()
    local a=self.r
    local r={a[1],a[4],a[7],a[2],a[5],a[8],a[3],a[6],a[9]}
    return rigid(rotate(r,vector(-self.Position.X,-self.Position.Y,-self.Position.Z)),r)
end
function Rigid:ToEulerAnglesXYZ()
    local r=self.r
    local y=math.asin(math.clamp(r[3],-1,1))
    if math.abs(math.cos(y))<1e-7 then return math.atan2(r[8],r[5]),y,0 end
    return math.atan2(-r[6],r[9]),y,math.atan2(-r[2],r[1])
end
local matrixCF={}
function matrixCF.new(x,y,z,...)
    local rotation={...}
    return rigid(type(x)=='table' and x or vector(x,y,z),#rotation>0 and rotation or nil)
end
function matrixCF.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return rigid(vector(),{cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,
        sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy})
end
-- Only subsequent fixtures use the matrix double. Earlier contract groups keep
-- their original lifetime/retarget fixtures and run unchanged.
frame=matrixCF.new
env.CFrame=matrixCF
local function near(a,b,message) assert(math.abs(a-b)<1e-4,(message or 'Transform mismatch')..': '..a..' vs '..b) end
local function sameFrame(a,b)
    near(a.Position.X,b.Position.X);near(a.Position.Y,b.Position.Y);near(a.Position.Z,b.Position.Z)
    for i=1,9 do near(a.r[i],b.r[i]) end
end
local function importedTemplates(legacy)
    local folder=canonicalTemplates()
    local model=folder.CanonicalPlayer1
    for _,row in ipairs(RotatedRestManifest.parts) do
        local part=model[row.name]
        part.CFrame=matrixCF.new(table.unpack(row.cframe));part.Size=vector(table.unpack(row.size))
        for _,attachment in ipairs(row.attachments) do
            part[attachment.name].CFrame=matrixCF.new(table.unpack(attachment.cframe))
        end
    end
    if legacy then model.Name='GreenToad';model.AppearanceProfile.Value='LegacyGeneratedGreen' end
    return folder
end
local function handPosition(a)
    -- Solve the actual Motor6D rest equation, Part0*C0 = Part1*C1.
    local frames={[a.model.Torso]=a.model.Torso.CFrame}
    local pending={}
    for _,part in ipairs(a.appearance.model:GetDescendants()) do
        if part:IsA('Motor6D') then pending[#pending+1]=part end
    end
    while #pending>0 do
        local progressed=false
        for i=#pending,1,-1 do
            local motor=pending[i]
            if frames[motor.Part0] then
                frames[motor.Part1]=frames[motor.Part0]*motor.C0*motor.C1:Inverse()
                table.remove(pending,i);progressed=true
            end
        end
        assert(progressed,'Cosmetic Motor6D graph must connect to the physical torso')
    end
    return frames[a.appearance.model.RightHand].Position
end

test('rigid transform fixture preserves noncommuting rotations and inverse translations',function()
    local down=matrixCF.new(0,-1,0)
    local pitch=matrixCF.Angles(math.pi/2,0,0)
    local turn=matrixCF.Angles(0,math.pi,0)
    near((pitch*turn*down).Position.Z,-1)
    near((turn*pitch*down).Position.Z,1)
    local transform=matrixCF.new(2,3,4)*matrixCF.Angles(.3,.7,-.2)
    sameFrame(transform*transform:Inverse(),matrixCF.new())
end)

test('actual imported Y180 rest frames send the source jab forward along face minusZ',function()
    local a=actor('matrix-source');assert(Appearance.attach(a,'Mr. Green',importedTemplates()))
    assert(a.appearance.joints.RightShoulder.base.r[1]<-.99,'Fixture must retain the imported Y180 attachment')
    local c=heroContext('matrix-source')
    Appearance.update(a,c)
    local rest=handPosition(a)
    c.attack=heroAttack(c.actorId,'HeroJab')
    Appearance.update(a,c)
    assert(a.appearance.sourcePose.frameId==0x19)
    local hand=handPosition(a)
    assert(hand.Z< -.5 and rest.Z-hand.Z>.5,
        'Source jab must extend in front of the face, not behind the body: '..hand.Z)
    assert(a.humanoid.Health==100 and a.model.Torso.CanCollide and not a.root.Anchored)
end)

test('canonical fallback also uses authored attachment axes with actual imported rest frames',function()
    local a=actor('matrix-fallback');assert(Appearance.attach(a,'Mr. Green',importedTemplates()))
    Appearance.update(a,heroContext('matrix-fallback'))
    local rest=handPosition(a)
    a.poseMotors['Right Shoulder'].joint.C0=matrixCF.Angles(1.6,0,0)
    Appearance.update(a)
    assert(a.appearance.sourcePose==nil)
    local hand=handPosition(a)
    assert(hand.Z< -.5 and rest.Z-hand.Z>.5,'Fallback shoulder pitch must also point forward')
    sameFrame(a.appearance.joints.RightShoulder.motor.C0,
        a.appearance.joints.RightShoulder.base*matrixCF.Angles(1.6,0,0))
end)

test('legacy profile retains the original pre-rest rotation and shoulder correction',function()
    local a=actor('matrix-legacy');assert(Appearance.attach(a,'Mr. Green',importedTemplates(true)))
    local delta=matrixCF.Angles(.3,.2,-.1)
    a.poseMotors['Right Shoulder'].joint.C0=delta
    Appearance.update(a)
    local joint=a.appearance.joints.RightShoulder
    local corrected=delta*matrixCF.Angles(0,0,-math.rad(45))
    sameFrame(joint.motor.C0,matrixCF.new(joint.base.Position)*corrected*joint.base.Rotation)
    local other=joint.base*corrected
    local difference=0
    for i=1,9 do difference=math.max(difference,math.abs(joint.motor.C0.r[i]-other.r[i])) end
    assert(difference>.1,'Legacy assertion must distinguish pre-rest and post-rest rotation')
end)
print('Rotated-rest appearance contracts: 4 passed')
