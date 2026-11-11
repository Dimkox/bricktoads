-- Native geometry for authored campaign modes. Coordinates remain local to one party.
-- Mode simulation decides collisions/outcomes; this module never awards progress or lives.
local CampaignWorld={}
CampaignWorld.__index=CampaignWorld
local Workspace=game:GetService('Workspace')
local CourseAppearance=require(script.Parent.CourseAppearance)
local CoursePropAppearance=require(script.Parent.CoursePropAppearance)
local palettes={
    Rope={45,63,78},Speeder={106,75,47},Ice={133,185,206},Surf={42,124,141},
    Serpents={71,111,69},Jet={125,65,44},Ascent={76,88,107},Tubes={61,105,114},
    Race={139,98,54},Clinger={106,76,141},Tower={85,107,108},Finale={87,53,103},
}
local function vec(p,default)
    return Vector3.new(p.x or p.w or default,p.y or p.h or default,p.z or p.d or default)
end
local function makePart(parent,name,size,frame,color,collidable,material)
    local p=Instance.new('Part')
    p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true
    p.CanCollide=collidable==true;p.CanTouch=false;p.CanQuery=collidable==true
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent
    return p
end
local function caption(parent,text)
    local gui=Instance.new('BillboardGui');gui.Name='CourseLabel'
    gui.Size=UDim2.fromOffset(230,42);gui.StudsOffset=Vector3.new(0,3,0)
    gui.AlwaysOnTop=false;gui.MaxDistance=80;gui.Parent=parent
    local label=Instance.new('TextLabel');label.Name='Caption';label.Size=UDim2.fromScale(1,1)
    label.BackgroundTransparency=1;label.Text=text;label.TextColor3=Color3.fromRGB(231,244,221)
    label.TextStrokeTransparency=.4;label.Font=Enum.Font.GothamBold;label.TextSize=15
    label.TextWrapped=true;label.Parent=gui
    return label
end
function CampaignWorld.new(world,route)
    local self=setmetatable({world=world,route=route,objects={}},CampaignWorld)
    world.geometry:ClearAllChildren()
    world.allFloors={};world.floors={};world.gates={}
    local rgb=palettes[route.mode] or palettes.Ascent
    self.color=Color3.fromRGB(rgb[1],rgb[2],rgb[3])
    local function support(data,index)
        local material=route.mode=='Ice' and Enum.Material.Ice or Enum.Material.Metal
        local p=makePart(world.geometry,'CourseSupport_'..index,Vector3.new(data.w,data.h,data.d),
            CFrame.new(data.x,data.y,data.z)+world.offset,self.color,true,material)
        p:SetAttribute('SurfaceId',route.id..':'..index);p:SetAttribute('ZoneIndex',1)
        world.allFloors[#world.allFloors+1]=p;world.floors[#world.floors+1]=p
        return p
    end
    if not route.course.renderDynamicPlatforms then
        for i,data in ipairs(route.course.platforms or {}) do support(data,tostring(i)) end
    end
    -- The arrival ledge exists before mode creation, so transition/initial spawn
    -- preflight is based on real support, including a rope or rotating tower.
    support({x=route.spawn.x,y=route.spawn.y-4,z=route.spawn.z,w=18,h=2,d=24},'Arrival')
    support(route.boss.platform,'Arena')
    local p=route.boss.pad
    self.exit=makePart(world.geometry,'CampaignExitSeal',Vector3.new(p.w,.15,p.d),
        CFrame.new(p.x,p.y,p.z)+world.offset,Color3.fromRGB(154,249,130),false,Enum.Material.Neon)
    self.exit.Transparency=.7
    caption(self.exit,'EXIT')
    self.header=makePart(world.geometry,'CourseTitleMarker',Vector3.new(.4,.4,.4),
        CFrame.new(route.spawn.x,route.spawn.y+6,route.spawn.z)+world.offset,self.color,false)
    self.header.Transparency=1
    caption(self.header,tostring(route.campaignIndex)..' / 13  '..route.name)
    -- Decorative depth/walls do not bridge playable gaps or become safe supports.
    if route.mode=='Rope' then
        for _,side in ipairs({-1,1}) do
            makePart(world.geometry,'ShaftWall',Vector3.new(3,270,42),
                CFrame.new(side*27,125,0)+world.offset,Color3.fromRGB(34,43,53),false,Enum.Material.Rock)
        end
    elseif route.mode=='Tower' then
        makePart(world.geometry,'SpireCore',Vector3.new(22,125,22),
            CFrame.new(0,54,0)+world.offset,Color3.fromRGB(42,55,60),false,Enum.Material.Slate)
    elseif route.mode=='Speeder' or route.mode=='Jet' then
        local course=route.course
        for x=40,course.finishDistance or 420,28 do
            for _,side in ipairs({-1,1}) do
                makePart(world.geometry,'CourseLaneBeacon',Vector3.new(.5,3,.5),
                    CFrame.new(x,1,side*25)+world.offset,Color3.fromRGB(245,192,76),false,Enum.Material.Neon)
            end
        end
    elseif route.mode=='Clinger' then
        for n,segment in ipairs(route.course.path or {}) do
            local p=segment.from
            local arrow=segment.direction.x>0 and '→' or segment.direction.x<0 and '←'
                or segment.direction.z>0 and '↓' or '↑'
            local marker=makePart(world.geometry,'CircuitDirection_'..n,Vector3.new(.3,.3,.3),
                CFrame.new(p.x+segment.direction.x*5,p.y+.5,p.z+segment.direction.z*5)+world.offset,
                Color3.fromRGB(221,230,114),false)
            marker.Transparency=1;caption(marker,arrow)
        end
    end
    world.folder:SetAttribute('LevelName',route.name)
    world.folder:SetAttribute('CampaignIndex',route.campaignIndex)
    world.folder:SetAttribute('CampaignMode',route.mode)
    world.config.FallY=(route.bounds.minY or -40)-15+world.offset.Y
    return self
end

local surfaces={Serpent=true,Lift=true,TowerPlatform=true,Platform=true,IceBlock=true,Support=true}
local vehicles={Speeder=true,Surfboard=true,Jet=true,Board=true,ClingerVehicle=true}
local orbs={AirMine=true,Mine=true,Bomb=true,Buzzball=true,Orb=true,Snowball=true,Whirlpool=true}
local function scaledFrame(frame,scale)
    return CFrame.new(frame.Position*scale)*frame.Rotation
end
local function meshBounds(model)
    local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
    local bodyTop,count=-math.huge,0
    for _,p in ipairs(model:GetChildren())do if p:IsA('MeshPart')then
        count+=1
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            local point=p.CFrame:PointToWorldSpace(Vector3.new(p.Size.X*x/2,p.Size.Y*y/2,p.Size.Z*z/2))
            low=Vector3.new(math.min(low.X,point.X),math.min(low.Y,point.Y),math.min(low.Z,point.Z))
            high=Vector3.new(math.max(high.X,point.X),math.max(high.Y,point.Y),math.max(high.Z,point.Z))
            if p.Name=='Body'then bodyTop=math.max(bodyTop,point.Y)end
        end end end
    end end
    assert(count>0 and high.X>low.X and high.Z>low.Z and bodyTop>-math.huge,'Invalid serpent mesh bounds')
    return low,high,bodyTop
end
local function removeSerpent(row)
    local skin=row.serpent;if not skin then return end
    row.serpent=nil
    if skin.actor.castAppearance then pcall(skin.appearance.detach,skin.actor)end
    skin.proxy:Destroy();skin.temporary:Destroy()
    if row.part.Parent then row.part.Transparency=skin.previousTransparency end
end
local function prepareSerpent(self,row)
    local appearance=self.world.castAppearance
    if not appearance or type(appearance.attach)~='function' or type(appearance.update)~='function'
        or type(appearance.detach)~='function' then return end
    local templates=game:GetService('ServerStorage'):FindFirstChild('BrickToadsCastTemplates')
    local source=templates and templates:FindFirstChild('Snake')
    if not source or not source:IsA('Model')then return end
    local temporary,proxy,actor
    local ok,skin=pcall(function()
        temporary=Instance.new('Folder');temporary.Name='OwnedSerpentTemplate'
        local template=assert(source:Clone(),'Uncloneable serpent template');template.Parent=temporary
        local low,high,bodyTop=meshBounds(template)
        local size=row.part.Size
        local scale=math.min(size.X/(high.Z-low.Z),size.Z/(high.X-low.X))
        assert(scale>0 and scale<math.huge,'Invalid serpent fit')
        -- A caches immutable rest frames. Scale every mesh and pivot before it
        -- assembles the cosmetic rig; shared ServerStorage assets stay intact.
        for _,p in ipairs(template:GetDescendants())do
            if p:IsA('MeshPart')then
                p.Size=p.Size*scale;p.CFrame=scaledFrame(p.CFrame,scale)
                p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
            elseif p:IsA('Attachment')then p.CFrame=scaledFrame(p.CFrame,scale)end
        end
        proxy=Instance.new('Model');proxy.Name='SerpentAppearance_'..tostring(row.id)
        local torso=makePart(proxy,'Torso',Vector3.new(.05,.05,.05),CFrame.new(),self.color,false)
        torso.Transparency=1;torso.Massless=true
        actor={model=proxy,root=torso}
        assert(appearance.attach(actor,'Snake',temporary),'Invalid serpent skin')
        -- The NES body is a nametable path. This bounded3D support fit is an
        -- authored adaptation of the decoded head/link references, not its trace.
        proxy:SetAttribute('CosmeticAdaptation','SourceHeadLinkWithAuthored3DSerpentSupportFit')
        proxy:SetAttribute('SourceBodyTrace','UNKNOWN_NAMETABLE_BODY')
        local middle=(low.Z+high.Z)/2
        local fit=CFrame.new(0,size.Y/2-bodyTop*scale,0)*CFrame.Angles(0,math.pi/2,0)*CFrame.new(0,0,-middle*scale)
        return {actor=actor,proxy=proxy,temporary=temporary,appearance=appearance,fit=fit,size=size,
            previousTransparency=row.part.Transparency or 0}
    end)
    if not ok then
        if actor and actor.castAppearance then pcall(appearance.detach,actor)end
        if proxy then proxy:Destroy()end;if temporary then temporary:Destroy()end
        return
    end
    row.serpent=skin;skin.proxy.Parent=self.world.geometry
    if appearance.addFallback then appearance.addFallback(skin.actor,row.part) end
end
function CampaignWorld:_serpent(row,now)
    local skin=row.serpent;local size=row.part.Size
    if skin and (skin.size.X~=size.X or skin.size.Y~=size.Y or skin.size.Z~=size.Z)then removeSerpent(row);skin=nil end
    if not skin then prepareSerpent(self,row);skin=row.serpent end
    if not skin then return end
    skin.actor.root.CFrame=row.part.CFrame*skin.fit
    skin.appearance.update(skin.actor,{kind='Snake',actorId=self.route.id..':serpent:'..tostring(row.id),
        levelEpoch=self.route.campaignIndex,now=now or 0,dt=0,mode='Idle',speed=0})
end
CampaignWorld.bossNames={BigBlag='Big Blag',RoboManus='Robo-Manus',GeneralSlaughter='General Slaughter',
    Buzzball='Buzzball',DarkQueen='Dark Queen'}
function CampaignWorld.decorateActor(actor,kind)
    local torso=actor.model:FindFirstChild('Torso')
    if not torso then return end
    for _,p in ipairs(actor.model:GetDescendants()) do
        if p:IsA('BasePart') and p~=actor.root then p.Transparency=1 end
    end
    local function shape(name,size,offset,color,round)
        local p=makePart(actor.model,name,size,torso.CFrame*offset,color,false)
        p.Anchored=false;p.Massless=true;p.CanQuery=false
        if round then p.Shape=Enum.PartType.Ball end
        local motor=Instance.new('Motor6D');motor.Name=name..'Joint';motor.Part0=torso;motor.Part1=p
        motor.C0=offset;motor.C1=CFrame.new();motor.Parent=p
        return p
    end
    local purple=Color3.fromRGB(103,54,133)
    local red=Color3.fromRGB(148,52,45)
    local metal=Color3.fromRGB(58,67,75)
    local cream=Color3.fromRGB(218,194,143)
    if kind=='RacingRat' then
        local fur=Color3.fromRGB(143,100,62)
        shape('RacerBody',Vector3.new(3.2,2.2,4.1),CFrame.new(0,-.4,.2),fur,true)
        shape('RacerSnout',Vector3.new(2,1.9,2.5),CFrame.new(0,-.1,-2),fur,true)
        for _,side in ipairs({-1,1}) do
            shape('RacerEar'..side,Vector3.new(.9,.7,.7),CFrame.new(side*.8,.65,-1.9),Color3.fromRGB(205,150,121),true)
            for _,z in ipairs({-1,1}) do shape('RacerFoot'..side..z,Vector3.new(.7,1.3,.7),CFrame.new(side,-2.3,z),fur) end
        end
        shape('RacerTail',Vector3.new(.35,.35,4),CFrame.new(0,-1.4,3.8),Color3.fromRGB(190,140,113))
    elseif kind=='Buzzball' then
        shape('BuzzballShell',Vector3.new(6,6,6),CFrame.new(),purple,true)
        for n=1,8 do local a=n*math.pi/4
            shape('RadialSpike'..n,Vector3.new(.55,1.4,.55),CFrame.new(math.cos(a)*3,math.sin(a)*3,0)*CFrame.Angles(0,0,a-math.pi/2),cream)
        end
        shape('BuzzballCore',Vector3.new(2.8,2.8,.6),CFrame.new(0,0,-2.9),Color3.fromRGB(224,121,220),true)
    elseif kind=='BigBlag' then
        shape('BlagBody',Vector3.new(7.5,5.2,4),CFrame.new(0,.2,0),purple,true)
        shape('BlagBelly',Vector3.new(5.1,4,1.1),CFrame.new(0,-.1,-1.7),cream,true)
        shape('BlagHead',Vector3.new(4.6,2.2,3),CFrame.new(0,3.3,-.4),purple,true)
        for _,side in ipairs({-1,1}) do
            shape('BlagFist'..side,Vector3.new(2.5,2.3,2.5),CFrame.new(side*4,.3,-.2),purple,true)
            shape('BlagFoot'..side,Vector3.new(2.4,.8,2.7),CFrame.new(side*2,-2.4,-.5),purple,true)
        end
    elseif kind=='RoboManus' then
        shape('RobotTorso',Vector3.new(4.2,4.3,2.5),CFrame.new(0,.6,0),red)
        shape('RobotHead',Vector3.new(2.3,2,2),CFrame.new(0,3.7,0),metal)
        shape('RobotVisor',Vector3.new(1.8,.45,.3),CFrame.new(0,3.8,-1.05),Color3.fromRGB(255,186,56))
        for _,side in ipairs({-1,1}) do
            shape('RobotShoulder'..side,Vector3.new(2.2,2,2.6),CFrame.new(side*3,1.6,0),red)
            shape('RobotCannon'..side,Vector3.new(1.5,2,3.6),CFrame.new(side*3,-.1,-1),metal)
            shape('RobotLeg'..side,Vector3.new(1.5,2.4,1.7),CFrame.new(side*1.2,-1.6,0),metal)
        end
    elseif kind=='GeneralSlaughter' then
        shape('GeneralBody',Vector3.new(5.4,4.8,3.3),CFrame.new(0,.2,0),Color3.fromRGB(146,104,67),true)
        shape('GeneralHead',Vector3.new(3.7,2.4,3),CFrame.new(0,3.2,-.7),Color3.fromRGB(123,77,47),true)
        for _,side in ipairs({-1,1}) do
            shape('GeneralHorn'..side,Vector3.new(.7,2.2,.7),CFrame.new(side*1.9,4.2,-.8)*CFrame.Angles(0,0,-side*.65),cream)
            shape('GeneralHoof'..side,Vector3.new(1.7,1.1,2),CFrame.new(side*1.7,-2.4,-.3),metal)
        end
    elseif kind=='DarkQueen' then
        shape('QueenTorso',Vector3.new(2.7,3.1,1.7),CFrame.new(0,.5,0),purple)
        shape('QueenHead',Vector3.new(2.1,2.2,1.8),CFrame.new(0,3.1,-.1),cream,true)
        shape('QueenCape',Vector3.new(5.4,4.4,.55),CFrame.new(0,.4,.9),Color3.fromRGB(49,25,65))
        for _,side in ipairs({-1,1}) do
            shape('QueenArm'..side,Vector3.new(.9,2.8,.9),CFrame.new(side*1.9,.7,0)*CFrame.Angles(0,0,-side*.4),purple)
            shape('QueenBoot'..side,Vector3.new(1,2.5,1.2),CFrame.new(side*.7,-1.4,-.2),purple)
        end
        for n=-2,2 do shape('CrownPoint'..n,Vector3.new(.35,.7+math.abs(n)*.15,.35),CFrame.new(n*.4,4.5,-.1),Color3.fromRGB(227,178,45)) end
    else
        -- Ordinary family silhouettes remain separate from the physical collider.
        local bird=kind=='Raven' or kind=='LargeRaven'
        local color=kind=='Snowman' and Color3.fromRGB(217,237,241) or bird and Color3.fromRGB(42,45,70) or Color3.fromRGB(130,96,70)
        local winged=bird or kind=='FlyingHead' or kind=='SentryDrone'
        shape('CampaignEnemyBody',Vector3.new(2.8,3.2,2.4),CFrame.new(0,-.1,0),color,true)
        shape('CampaignEnemyHead',Vector3.new(2.3,1.9,2.1),CFrame.new(0,2.1,-.3),color,true)
        if winged then for _,side in ipairs({-1,1}) do
            shape('CampaignWing'..side,Vector3.new(3.5,.4,2),CFrame.new(side*2.2,1.1,0),metal)
        end end
        if bird then
            shape('RavenBeak',Vector3.new(1.4,.8,2.2),CFrame.new(0,2,-1.8),Color3.fromRGB(214,167,61))
            if kind=='LargeRaven' then shape('LargeRavenRuff',Vector3.new(4.1,1.2,3.5),CFrame.new(0,.6,0),color,true) end
        end
        if kind=='GasTurret' or kind=='Robot' or kind=='RocketRat' or kind=='RetroBlaster' then
            shape('CampaignWeapon',Vector3.new(1.2,1.2,3.5),CFrame.new(0,.6,-1.8),metal)
        end
        if kind=='SaturnToadtrap' then
            shape('TrapJaw',Vector3.new(3.2,1.1,3.8),CFrame.new(0,.1,-1.4),Color3.fromRGB(80,139,78),true)
        end
    end
end
function CampaignWorld:object(id,kind,point,size,metadata)
    if type(point)~='table' then return end
    metadata=metadata or {};size=size or {x=2,y=2,z=2}
    local row=self.objects[id]
    if row and row.kind~=kind then self:remove(id);row=nil end
    if not row then
        local collidable=metadata.collidable==true or surfaces[kind]==true
        local tint=surfaces[kind] and self.color or Color3.fromRGB(244,107,68)
        if kind=='Tower' then tint=Color3.fromRGB(42,55,60)
        elseif vehicles[kind] then tint=Color3.fromRGB(231,177,51)
        elseif kind=='Rope' then tint=Color3.fromRGB(205,193,136)
        elseif kind=='Water' then tint=Color3.fromRGB(47,144,178)
        elseif kind=='Telegraph' or kind=='Warning' then tint=Color3.fromRGB(255,207,69) end
        local item=kind=='Tower' and self.world.geometry:FindFirstChild('SpireCore')
            or makePart(self.world.geometry,'Campaign_'..kind..'_'..tostring(id),vec(size,2),CFrame.new(),tint,collidable,
                collidable and Enum.Material.Metal or Enum.Material.Neon)
        if orbs[kind] then item.Shape=Enum.PartType.Ball end
        if kind=='Water' then item.Material=Enum.Material.Glass;item.Transparency=.65 end
        if kind=='Rope' then item.Material=Enum.Material.Fabric end
        if collidable then
            item:SetAttribute('SurfaceId',self.route.id..':dynamic:'..tostring(id));item:SetAttribute('ZoneIndex',1)
            self.world.allFloors[#self.world.allFloors+1]=item
            self.world.floors[#self.world.floors+1]=item
        end
        row={kind=kind,part=item,id=id};self.objects[id]=row
        if metadata.label then row.label=caption(item,metadata.label) end
    end
    local yaw=metadata.yaw or point.yaw or 0
    row.part.Size=vec(size,2)
    row.part.CFrame=CFrame.new(point.x,point.y,point.z)*CFrame.Angles(0,yaw,0)+self.world.offset
    if kind=='Tower' then
        row.part.Shape=Enum.PartType.Cylinder
        row.part.Size=Vector3.new(size.h or size.y,size.w or size.x,size.d or size.z)
        row.part.CFrame=CFrame.new(point.x,point.y,point.z)*CFrame.Angles(0,0,math.pi/2)+self.world.offset
    end
    if kind=='Rope' and metadata.anchor and metadata.endpoint then
        local a=vec(metadata.anchor,0)+self.world.offset
        local b=vec(metadata.endpoint,0)+self.world.offset
        if (b-a).Magnitude>.01 then
            row.part.Size=Vector3.new(.18,.18,(b-a).Magnitude)
            row.part.CFrame=CFrame.lookAt((a+b)/2,b)
        end
    end
    if metadata.alpha then row.part.Transparency=metadata.alpha end
    if row.label and metadata.label then row.label.Text=metadata.label end
    row.expiresAt=metadata.expiresAt
    if kind=='Serpent'then self:_serpent(row,self.now or 0)end
    local waterSurfaceY
    if kind=='Surfboard'or kind=='Board'then
        for _,water in ipairs(self.route.course.media or{})do
            if water.kind=='Water'and point.x>=water.minX and point.x<=water.maxX
                and point.z>=water.minZ and point.z<=water.maxZ then
                waterSurfaceY=math.max(waterSurfaceY or-math.huge,water.maxY+self.world.offset.Y)
            end
        end
    end
    CourseAppearance.update(row,self.world.geometry,metadata,waterSurfaceY)
    CoursePropAppearance.update(row,self.world.geometry,metadata,self.now or 0)
    return row.part
end
function CampaignWorld:remove(id)
    local row=self.objects[id]
    if not row then return end
    removeSerpent(row)
    CourseAppearance.remove(row)
    CoursePropAppearance.remove(row)
    for _,floors in ipairs({self.world.allFloors,self.world.floors}) do
        for i=#floors,1,-1 do if floors[i]==row.part then table.remove(floors,i) end end
    end
    row.part:Destroy();self.objects[id]=nil
end
function CampaignWorld:step(now)
    self.now=now
    local expired={}
    for id,row in pairs(self.objects) do
        if row.expiresAt and now>=row.expiresAt then expired[#expired+1]=id end
    end
    for _,id in ipairs(expired) do self:remove(id) end
    for _,row in pairs(self.objects)do
        if row.kind=='Serpent'then self:_serpent(row,now)end
        CoursePropAppearance.step(row,now)
    end
end
function CampaignWorld:stage(name)
    self.world.stageName=name;self.world.folder:SetAttribute('Stage',name)
    self.exit.Transparency=(name=='Exit' or name=='Won') and .12 or .7
end
function CampaignWorld:close()
    local ids={};for id in pairs(self.objects) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do self:remove(id) end
end
return CampaignWorld
