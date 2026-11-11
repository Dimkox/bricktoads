-- Actual imported Queen pivots and real rigid-transform FK. This validates
-- authored articulation/motor wiring, not native mesh rendering or NES angles.
local Rigid={}
local function rigid(position,rotation)
    return setmetatable({Position=position,r=rotation or{1,0,0,0,1,0,0,0,1}},Rigid)
end
local function rotate(r,v)
    return vector(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)
end
Rigid.__index=function(a,key)if key=='Rotation'then return rigid(vector(),a.r)end;return Rigid[key]end
function Rigid.__mul(a,b)
    local r={}
    for i=0,2 do for j=1,3 do r[i*3+j]=a.r[i*3+1]*b.r[j]+a.r[i*3+2]*b.r[3+j]+a.r[i*3+3]*b.r[6+j]end end
    local p=rotate(a.r,b.Position)
    return rigid(vector(a.Position.X+p.X,a.Position.Y+p.Y,a.Position.Z+p.Z),r)
end
function Rigid:Inverse()
    local a=self.r;local r={a[1],a[4],a[7],a[2],a[5],a[8],a[3],a[6],a[9]}
    return rigid(rotate(r,vector(-self.Position.X,-self.Position.Y,-self.Position.Z)),r)
end
function Rigid:GetComponents()return self.Position.X,self.Position.Y,self.Position.Z,table.unpack(self.r)end
local matrixCF={}
function matrixCF.new(x,y,z,...)
    local r={...};return rigid(type(x)=='table'and x or vector(x,y,z),#r>0 and r or nil)
end
function matrixCF.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return rigid(vector(),{cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy})
end
frame=matrixCF.new;env.CFrame=matrixCF
local function near(a,b,message)assert(math.abs(a-b)<1e-5,(message or'Transform mismatch')..': '..a..' vs '..b)end
local function sameFrame(a,b)
    near(a.Position.X,b.Position.X);near(a.Position.Y,b.Position.Y);near(a.Position.Z,b.Position.Z)
    for i=1,9 do near(a.r[i],b.r[i])end
end
local function queenTemplate()
    local folder=node('Folder');local m=node('Model','DarkQueen',folder)
    value(m,'AppearanceProfile','CanonicalNESCast');value(m,'CastKind','DarkQueen')
    value(m,'SourcePin','f1a43b69577246850d136473700a333b3cdfe93f')
    for _,row in ipairs(QueenManifest.parts)do
        local p=node('MeshPart',row.name,m);p._props.MeshId=row.meshId;p.Size=vector(table.unpack(row.size))
        p.CFrame=matrixCF.new(table.unpack(row.cframe));p.Transparency=row.transparency or 0
        value(p,'ParentSegment',row.parentSegment)
        for _,attachment in ipairs(row.attachments)do
            local a=node('Attachment',attachment.name,p);a.CFrame=matrixCF.new(table.unpack(attachment.cframe))
        end
    end
    assert(m.Hair and not m.Cape,'Use the actual imported Hair segment')
    return folder
end
local function queenContext(more)
    local c={kind='DarkQueen',actorId='queen',levelEpoch=1,now=10,speed=0,mode='Idle'}
    for k,v in pairs(more or{})do c[k]=v end;return c
end
local function forwardFrames(a)
    local frames={[a.model.Torso]=a.model.Torso.CFrame};local pending={}
    for _,j in pairs(a.castAppearance.joints)do pending[#pending+1]=j.motor end
    while #pending>0 do
        local progressed=false
        for i=#pending,1,-1 do
            local m=pending[i]
            if frames[m.Part0]then frames[m.Part1]=frames[m.Part0]*m.C0*m.C1:Inverse();table.remove(pending,i);progressed=true end
        end
        assert(progressed,'Queen motor graph disconnected')
    end
    return frames
end
check('Queen source81 and82 drive the imported Hair motor and preserve the physical rig',function()
    local a,t=actor();assert(A.attach(a,'DarkQueen',queenTemplate()));local state=a.castAppearance
    local physical=t.CFrame;local hair=assert(state.joints.Hair);local c1=hair.motor.C1
    for _,case in ipairs({{'Grounded',0x81,.1},{'Airborne',0x82,.4}})do
        A.update(a,queenContext({sourceState=case[1]}))
        assert(state.pose.frameId==case[2]and state.pose.adaptation=='Authored3DJointAngles')
        sameFrame(hair.motor.C0,hair.base*matrixCF.Angles(case[3],0,0))
        assert(hair.motor.Part0==state.model.Head and hair.motor.Part1==state.model.Hair and hair.motor.C1==c1)
        assert(t.CFrame==physical and t.CanCollide and a.humanoid.Health==47)
    end
end)
check('accepted Queen Spin retains authored Hair motion after the source clip ends and resets on interruption',function()
    local a=actor();assert(A.attach(a,'DarkQueen',queenTemplate()));local s=a.castAppearance;local hair=s.joints.Hair
    local attack={name='Spin',start=10,actorId='queen',levelEpoch=1}
    A.update(a,queenContext({attack=attack,phase='Tell'}));assert(s.pose.frameId==0x81)
    A.update(a,queenContext({now=12,attack=attack,phase='Active'}))
    assert(not s.pose.animationId and s.pose.actionBinding=='Authored3DSpin')
    sameFrame(hair.motor.C0,hair.base*matrixCF.Angles(.1+math.sin(8)*.08,0,0))
    local previous=hair.motor.C0
    A.update(a,queenContext({now=12.1,attack=attack,phase='Active'}))
    assert(hair.motor.C0.r[6]~=previous.r[6],'Accepted Spin Hair stopped after source playback')
    A.update(a,queenContext({now=12.2,attack=attack,phase='Active',reacting=true}))
    assert(s.pose.state=='Reaction'and not s.pose.animationId);sameFrame(hair.motor.C0,hair.base)
    A.update(a,queenContext({now=12.25,attack=attack,phase='Active'}))
    assert(not s.pose.actionBinding and not s.pose.animationId,'Interrupted Spin resumed the old authored action')
    sameFrame(hair.motor.C0,hair.base*matrixCF.Angles(.1,0,0))
    A.update(a,queenContext({now=12.3,attack=attack,dead=true}))
    assert(s.pose.state=='Dead');sameFrame(hair.motor.C0,hair.base)
    A.update(a,nil)
    local rest=forwardFrames(a)
    for _,j in pairs(s.joints)do
        sameFrame(j.motor.C0,j.base);sameFrame(rest[j.part],j.part.CFrame)
    end
    assert(s.pose==nil and s.model:GetAttribute('SourceGraphicsFrame')==nil)
end)
print('CanonicalCastAppearance: '..passed..' passed; '..failed..' failed')
assert(failed==0,'Canonical cast appearance contracts failed')
