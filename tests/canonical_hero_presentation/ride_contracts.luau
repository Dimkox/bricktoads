-- Actual uploaded rest transforms/sizes; matrix equations, no engine-lag emulation.
local function rideTemplates()
    local folder=canonicalTemplates()
    local brown=folder.CanonicalPlayer1:Clone();brown.Name='CanonicalPlayerBrown';brown.Parent=folder
    local names={['Mr. Green']='CanonicalPlayer1',['Mr. Yellow']='CanonicalPlayer2',['Mr. Brown']='CanonicalPlayerBrown'}
    for hero,manifest in pairs(RideRestManifests)do
        local model=folder[names[hero]]
        for _,row in ipairs(manifest.parts)do
            local p=assert(model[row.name]);p.CFrame=matrixCF.new(table.unpack(row.cframe));p.Size=vector(table.unpack(row.size))
            for _,a in ipairs(row.attachments)do p[a.name].CFrame=matrixCF.new(table.unpack(a.cframe))end
        end
    end
    return folder
end
local function rideActor(id,hero,torso)
    local a=actor(id);a.model.Torso.CFrame=torso or matrixCF.new(0,3,0)
    assert(Appearance.attach(a,hero or'Mr. Green',rideTemplates()))
    return a
end
local function soleHeights(a)
    local frames={[a.model.Torso]=a.model.Torso.CFrame};local motors={}
    for _,m in ipairs(a.appearance.model:GetDescendants())do if m:IsA('Motor6D')then motors[#motors+1]=m end end
    while #motors>0 do
        local progressed=false
        for i=#motors,1,-1 do local m=motors[i]
            if frames[m.Part0]then frames[m.Part1]=frames[m.Part0]*m.C0*m.C1:Inverse();table.remove(motors,i);progressed=true end
        end
        assert(progressed,'Disconnected cosmetic test graph')
    end
    local heights={}
    for _,name in ipairs({'LeftFoot','RightFoot'})do
        local p=a.appearance.model[name];local f=assert(frames[p]);local low=math.huge
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            low=math.min(low,(f*matrixCF.new(p.Size.X*x/2,p.Size.Y*y/2,p.Size.Z*z/2)).Position.Y)
        end end end
        heights[#heights+1]=low
    end
    return math.min(heights[1],heights[2]),heights
end
test('all three actual hero palettes align posed Ride soles to the supplied world deck using cosmetic Root only',function()
    for _,hero in ipairs({'Mr. Green','Mr. Yellow','Mr. Brown'})do
        local id='ride-'..hero
        local a=rideActor(id,hero,matrixCF.new(40,3,-12)*matrixCF.Angles(.2,1.3,-.15))
        local physical={};for name,row in pairs(a.poseMotors)do physical[name]=row.joint.C0 end
        local c=heroContext(id,.5);c.visualState='Ride';c.rideDeckY=2.75
        local original=geometrySnapshot(a);Appearance.update(a,c)
        assert(a.appearance.sourcePose.kind=='Ride')
        local low=soleHeights(a);near(low,c.rideDeckY,'Lowest Ride sole must meet the world deck')
        for name,row in pairs(a.poseMotors)do assert(row.joint.C0==physical[name],'Physical '..name..' changed')end
        sameGeometry(original);assert(a.humanoid.Health==100 and a.model.Torso.CanCollide and not a.root.Anchored)
    end
end)
test('Ride alignment ignores stale cosmetic Part CFrames and repeats without accumulating an offset',function()
    local a=rideActor('ride-stale');local c=heroContext('ride-stale',.5);c.visualState='Ride';c.rideDeckY=1.1
    Appearance.update(a,c);local first=a.appearance.rootJoint.motor.C0
    for i=1,50 do
        for _,p in ipairs(a.appearance.model:GetChildren())do if p:IsA('MeshPart')then p.CFrame=matrixCF.new(i*13,500+i,-500)end end
        Appearance.update(a,c);sameFrame(a.appearance.rootJoint.motor.C0,first);near(soleHeights(a),1.1)
    end
    c.rideDeckY=2.4;Appearance.update(a,c);near(soleHeights(a),2.4)
end)
test('only a current canonical Ride pose with a finite deck may change the cosmetic root offset',function()
    for _,kind in ipairs({'Idle','Dead','Reaction','Carried','DragonMounted','DragonCaptured','Swim','Rope'})do
        local a=rideActor('ride-guard-'..kind);local c=heroContext('ride-guard-'..kind,.5)
        if kind~='Idle'then c.visualState=kind end;c.rideDeckY=100
        Appearance.update(a,c);sameFrame(a.appearance.rootJoint.motor.C0,a.appearance.rootJoint.base)
    end
    for _,deck in ipairs({false,0/0,math.huge,-math.huge})do
        local a=rideActor('ride-invalid');local c=heroContext('ride-invalid',.5);c.visualState='Ride';c.rideDeckY=deck
        Appearance.update(a,c);sameFrame(a.appearance.rootJoint.motor.C0,a.appearance.rootJoint.base)
    end
    local a=rideActor('ride-leave');local c=heroContext('ride-leave',.5);c.visualState='Ride';c.rideDeckY=3
    Appearance.update(a,c);c.visualState=nil;Appearance.update(a,c)
    sameFrame(a.appearance.rootJoint.motor.C0,a.appearance.rootJoint.base)
    c.visualState='Ride';Appearance.update(a,c);Appearance.update(a)
    sameFrame(a.appearance.rootJoint.motor.C0,a.appearance.rootJoint.base)
end)
test('Ride deck alignment is independent across actors at different world elevations and clears on detach',function()
    local a=rideActor('ride-a',nil,matrixCF.new(0,3,0));local b=rideActor('ride-b',nil,matrixCF.new(512,103,512))
    local first=heroContext('ride-a',.5);first.visualState='Ride';first.rideDeckY=.8
    local second=heroContext('ride-b',.5);second.visualState='Ride';second.rideDeckY=100.8
    Appearance.update(a,first);Appearance.update(b,second)
    near(soleHeights(a),.8);near(soleHeights(b),100.8)
    sameFrame(a.appearance.rootJoint.motor.C0,b.appearance.rootJoint.motor.C0)
    local saved=a.appearance;Appearance.detach(a);assert(saved.model.destroyed and not a.appearance)
    near(soleHeights(b),100.8)
end)
print('Ride deck alignment: 4 groups passed; physical simulation and native pixel fit remain separate')
