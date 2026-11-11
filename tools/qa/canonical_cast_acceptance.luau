-- Prepared visual fixture only: no campaign completion or human-input claim.
local SS=game:GetService('ServerStorage')
local QA=assert(SS:FindFirstChild('BrickToadsVisualQA'))
local Cast=require(QA.Modules.CanonicalCastAppearance)
local Hero=require(QA.Modules.CharacterAppearance)
assert(not workspace:FindFirstChild('BrickToadsCastGallery'))
local gallery=Instance.new('Folder');gallery.Name='BrickToadsCastGallery';gallery.Parent=workspace
local report={scope='Prepared native cosmetic rig, source-state and resource acceptance',
    placeId=game.PlaceId,rows={},errors={},createdAt=os.time(),assets={cast='98861636357152',
        playerTwo='129170231871567',brown='84225513587808'}}
local function part(m,name,size,frame,alpha)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Transparency=alpha or 0
    p.Anchored=false;p.CanCollide=name=='Torso';p.CanTouch=false;p.CanQuery=false;p.Parent=m;return p
end
local function fixture(name,position)
    local m=Instance.new('Model');m.Name=name;m:SetAttribute('ActorId','visual:'..name)
    local root=part(m,'HumanoidRootPart',Vector3.new(2,2,1),CFrame.new(position),1);root.Anchored=true
    local torso=part(m,'Torso',Vector3.new(2,2,1),CFrame.new(position))
    local definitions={{'Head',Vector3.new(2,1,1),Vector3.new(0,1.5,0),'Neck',Vector3.new(0,1,0),Vector3.new(0,-.5,0)},
        {'Left Arm',Vector3.new(1,2,1),Vector3.new(-1.5,0,0),'Left Shoulder',Vector3.new(-1,.5,0),Vector3.new(.5,.5,0)},
        {'Right Arm',Vector3.new(1,2,1),Vector3.new(1.5,0,0),'Right Shoulder',Vector3.new(1,.5,0),Vector3.new(-.5,.5,0)},
        {'Left Leg',Vector3.new(1,2,1),Vector3.new(-.5,-2,0),'Left Hip',Vector3.new(-.5,-1,0),Vector3.new(0,1,0)},
        {'Right Leg',Vector3.new(1,2,1),Vector3.new(.5,-2,0),'Right Hip',Vector3.new(.5,-1,0),Vector3.new(0,1,0)}}
    local r=Instance.new('Motor6D');r.Name='RootJoint';r.Part0=root;r.Part1=torso;r.Parent=torso
    for _,d in ipairs(definitions) do local p=part(m,d[1],d[2],CFrame.new(position+d[3]))
        local j=Instance.new('Motor6D');j.Name=d[4];j.Part0=torso;j.Part1=p;j.C0=CFrame.new(d[5]);j.C1=CFrame.new(d[6]);j.Parent=torso end
    local h=Instance.new('Humanoid');h.BreakJointsOnDeath=false;h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;h.Parent=m
    m.PrimaryPart=root
    return {model=m,root=root,humanoid=h},torso
end
local function solve(m)
    for _=1,8 do for _,j in ipairs(m:GetDescendants()) do
        if j:IsA('Motor6D') and j.Part0 and j.Part1 then j.Part1.CFrame=j.Part0.CFrame*j.C0*j.C1:Inverse() end
    end end
end
local function label(m,text)
    local b=Instance.new('BillboardGui');b.Name='FixtureLabel';b.Size=UDim2.fromOffset(150,24)
    b.StudsOffset=Vector3.new(0,5,0);b.AlwaysOnTop=false;b.Parent=m.PrimaryPart
    local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1
    t.Text=text;t.TextColor3=Color3.new(1,1,1);t.TextStrokeTransparency=.25;t.TextSize=16;t.Parent=b
end
local actions={Pig='PigJab',Walker='WalkerHeavy',Dragon='DragonHeadbutt',BigBlag='Hop',RoboManus='Burst',
    GeneralSlaughter='Charge',DarkQueen='Sweep',Raven='Swoop',Shark='Bite',Snowman='Snowball'}
local flying={Dragon=true,Raven=true,LargeRaven=true,FlyingHead=true,Swellcheeks=true,HealingFly=true}
local swimming={Shark=true,Hammerfish=true,Electrofish=true,Duck=true}
local templates=SS.BrickToadsCastTemplates:GetChildren();table.sort(templates,function(a,b)return a.Name<b.Name end)
for index,t in ipairs(templates) do
    local ok,err=pcall(function()
        local origin=Vector3.new(9000+(index-1)%6*20,3,math.floor((index-1)/6)*25)
        local a,torso=fixture(t.Name,origin);local health=a.humanoid.Health;local size=torso.Size
        local attached,reason=Cast.attach(a,t.Name)
        local attempts=0
        while not attached and reason=='CAST_ASSETS_LOADING' and attempts<30 do
            task.wait(.1);attempts+=1;attached,reason=Cast.attach(a,t.Name)
        end
        assert(attached,reason);local skin=a.castAppearance;local changes=0
        local c={kind=t.Name,actorId=a.model:GetAttribute('ActorId'),levelEpoch=1,now=100,dt=.1,speed=9,
            mode=flying[t.Name] and 'Fly' or swimming[t.Name] and 'Swim' or 'Walk'}
        Cast.update(a,c);assert(skin.pose,'A real resource must receive a valid presentation')
        local neutral={};for name,j in pairs(skin.joints) do neutral[name]=j.motor.C0 end
        c.now=100.15;c.reacting=true;Cast.update(a,c)
        for name,j in pairs(skin.joints) do if j.motor.C0~=neutral[name] then changes+=1 end end
        assert(changes>0,'Reaction must visibly articulate the skin')
        c.now=100.2;c.reacting=false;c.dead=true;Cast.update(a,c);assert(skin.pose.state=='Dead')
        c.now=100.3;c.dead=false;Cast.update(a,c)
        if actions[t.Name] then
            c.attack={name=actions[t.Name],start=100.3,actorId=c.actorId,levelEpoch=1};c.phase='Tell';Cast.update(a,c)
            c.now=100.52;c.phase='Active';Cast.update(a,c)
        end
        local meshes=0;for _,p in ipairs(skin.model:GetDescendants()) do if p:IsA('MeshPart') then
            meshes+=1;assert(p.Massless and not p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
            assert(p.MeshId:match('^rbxassetid://%d+$'))
            assert(p:FindFirstChildOfClass('SurfaceAppearance') or p.TextureID:match('^rbxassetid://%d+$'),
                'Expected native PBR surface or imported base-colour texture')
        end end
        assert(a.humanoid.Health==health and torso.Size==size and torso.CanCollide and a.root.Anchored)
        solve(a.model);a.model.Parent=gallery;label(a.model,t.Name)
        report.rows[#report.rows+1]={kind=t.Name,meshes=meshes,reactionChangedMotors=changes,
            frame=skin.pose.frameId,namespace=skin.pose.namespace,state=skin.pose.state,colliderPreserved=true}
    end)
    if not ok then report.errors[#report.errors+1]={kind=t.Name,error=tostring(err)} end
    if index%4==0 then task.wait() end
end
local heroStates={'Idle','Folded1F','Fear32','Fear33'}
for hi,template in ipairs({'Mr. Green','Mr. Yellow','Mr. Brown'}) do
    for si,pose in ipairs(heroStates) do
        local ok,err=pcall(function()
            local a,torso=fixture(template..'_'..pose,Vector3.new(9000+(si-1)*14,3,-26-hi*17))
            local health=a.humanoid.Health;assert(Hero.attach(a,template))
            local c={enabled=true,actorId=a.model:GetAttribute('ActorId'),now=0,dt=0,grounded=true,mode='Idle',speed=0}
            if pose=='Folded1F' then c.attack={action='HeroBoot',actorId=c.actorId,at=.1,tuning={windup=.1}}
            elseif pose=='Fear32' or pose=='Fear33' then c.fearIntro={id='visualIntro',actorId=c.actorId,
                counter=pose=='Fear32' and 1 or 0xE1,frameId=pose=='Fear32' and 0x32 or 0x33} end
            Hero.update(a,c);assert(a.appearance.sourcePose,'Canonical hero pose missing')
            local source=a.appearance.sourcePose
            if pose=='Folded1F' then assert(source.frameId==0x1F)
            elseif pose=='Fear32' then assert(source.frameId==0x32 and a.appearance.activeMorph=='FearBeforeCut')
            elseif pose=='Fear33' then assert(source.frameId==0x33 and a.appearance.activeMorph=='FearAfterCut') end
            assert(a.humanoid.Health==health and torso.CanCollide)
            solve(a.model);a.model.Parent=gallery;label(a.model,template..' '..pose)
            report.rows[#report.rows+1]={kind=template,pose=pose,frame=source.frameId,morph=a.appearance.activeMorph,
                colliderPreserved=true,skin=a.appearance.sourceTemplate.Name}
        end)
        if not ok then report.errors[#report.errors+1]={kind=template,pose=pose,error=tostring(err)} end
        task.wait()
    end
end
local result=Instance.new('StringValue');result.Name='Result';result.Value=game:GetService('HttpService'):JSONEncode(report);result.Parent=QA
return {rows=#report.rows,errors=report.errors,gallery=gallery:GetFullName()}
