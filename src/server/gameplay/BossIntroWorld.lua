-- Party-owned, cosmetic-only Boss Walker INTRO boundary. No hero assembly,
-- ownership, collision, damage, Lighting or Camera is changed here.
-- Replicated interface: world.folder/BossIntro (Folder) exposes Active(bool),
-- IntroId(string), RunId(string), LevelEpoch(number), Counter(number), Phase(string),
-- CameraCut(bool, latched from E0), FearFrame(number), StartedAt(server seconds),
-- and Focus(Vector3: group-local boss position + group offset + 6 vertical studs).
-- The folder is destroyed on FF/cancellation/clearActors; clients must release
-- their intro view when it disappears. World.bossIntroState contains plain data.
return function(World)
    if World.bossIntro then return World end
    local previousClear=World.clearActors
    local steel=Color3.fromRGB(81,93,101)
    local dark=Color3.fromRGB(33,39,44)
    local copper=Color3.fromRGB(184,119,57)
    local light=Color3.fromRGB(255,194,87)
    local function piece(parent,name,size,offset,color,shape)
        local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color
        p.Material=Enum.Material.Metal;p.Anchored=true;p.Massless=true
        p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=true
        p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
        if shape then p.Shape=shape end
        p.CFrame=offset;p.Parent=parent
        return {part=p,offset=offset}
    end
    local function makeFoot(folder)
        local model=Instance.new('Model');model.Name='IntroFoot12';model.Parent=folder
        model:SetAttribute('SourceFrame',0x12)
        model:SetAttribute('SourceScaleHeroHeights',3.88)
        model:SetAttribute('Adaptation','Authored 3D cosmetic path; no stomp damage')
        local parts={}
        local function add(name,x,y,z,sx,sy,sz,color,shape)
            parts[#parts+1]=piece(model,name,Vector3.new(sx,sy,sz),CFrame.new(x,y,z),color,shape)
        end
        -- A six-stud local hero reference yields a 23.28-stud silhouette.
        -- Original mechanical boot forms retain frame12's exaggerated scale.
        add('Sole',-1,1.05,0,12,2.1,8.8,dark)
        add('ToeArmor',-3.7,3.1,0,7,2.2,9.2,steel)
        add('HeelArmor',3.4,3.5,0,3.8,3.2,8.4,steel)
        add('Instep',0,5.2,0,5.8,3.6,7.8,copper)
        add('AnkleJoint',2,7.5,0,5.2,4.2,6.3,dark,Enum.PartType.Ball)
        add('ShinArmor',2,15.1,0,5.9,13.4,6.7,steel)
        add('ShinInset',-1.04,15.3,0,.32,9.8,3.2,copper)
        add('UpperBand',2,22.24,0,6.5,2.08,7.3,dark)
        for _,side in ipairs({-1,1}) do
            add('Piston'..side,2.1,14.5,side*3.65,1.2,12.5,1.1,copper)
            add('AnkleBolt'..side,2,7.5,side*3.4,2.2,2.2,.55,light,Enum.PartType.Ball)
            add('ToeRidge'..side,-3.7,4.32,side*2.5,6.8,.35,.7,dark)
        end
        return parts
    end
    local function footFrame(state,offset)
        local c=state.counter==0xE0 and 0xDF or state.counter
        local p=state.bossPosition
        local x,y
        if c<0x64 then
            local t=math.clamp((c-0x50)/20,0,1)
            x=p.x-29+13*t;y=22*(1-t)^2
        elseif c<0xE0 then
            local t=(c-0x64)/(0xE0-0x64)
            x=p.x-16+16*t;y=4*math.sin(math.pi*t)
        else
            local t=math.clamp((c-0xE0)/30,0,1)
            x=p.x+10*t;y=17*t
        end
        return CFrame.new(Vector3.new(x,p.y-3+y,p.z)+offset)
    end
    function World:bossIntro(state)
        if not state then
            self.bossIntroState=nil
            if self.bossIntroFolder then self.bossIntroFolder:Destroy() end
            self.bossIntroFolder=nil;self.bossIntroParts=nil;self.bossIntroRipples=nil
            return
        end
        if self.bossIntroFolder and self.bossIntroFolder:GetAttribute('IntroId')~=state.id then self:bossIntro(nil) end
        if not self.bossIntroFolder then
            local folder=Instance.new('Folder');folder.Name='BossIntro';folder.Parent=self.folder
            folder:SetAttribute('IntroId',state.id)
            self.bossIntroFolder=folder;self.bossIntroParts=makeFoot(folder);self.bossIntroRipples={}
            -- Exactly two reused markers, even across skipped heartbeats.
            for _,counter in ipairs({0x30,0x64}) do
                local ring=piece(folder,'StompRipple'..counter,Vector3.new(.08,1,1),CFrame.new(),light,Enum.PartType.Cylinder).part
                ring.Material=Enum.Material.Neon;ring.CastShadow=false;ring.Transparency=1
                self.bossIntroRipples[counter]=ring
            end
        end
        self.bossIntroState=state
        local folder=self.bossIntroFolder
        folder:SetAttribute('Active',state.active==true)
        folder:SetAttribute('RunId',state.runId);folder:SetAttribute('LevelEpoch',state.levelEpoch)
        folder:SetAttribute('Counter',state.counter);folder:SetAttribute('Phase',state.phase)
        folder:SetAttribute('CameraCut',state.cameraCut==true);folder:SetAttribute('FearFrame',state.fearFrame)
        folder:SetAttribute('StartedAt',state.startedAt)
        local p=state.bossPosition
        folder:SetAttribute('Focus',Vector3.new(p.x,p.y+6,p.z)+self.offset)
        local frame=footFrame(state,self.offset)
        for _,row in ipairs(self.bossIntroParts) do
            row.part.CFrame=frame*row.offset
            row.part.Transparency=state.footFrame==0x12 and 0 or 1
        end
        for counter,ring in pairs(self.bossIntroRipples) do
            local age=state.counter-counter
            local visible=age>=0 and age<24
            ring.Transparency=visible and .2+.8*age/24 or 1
            local diameter=visible and 5+age*1.4 or 1
            ring.Size=Vector3.new(.08,diameter,diameter)
            local x=p.x-(counter==0x30 and 29 or 16)
            ring.CFrame=CFrame.new(Vector3.new(x,p.y-2.9,p.z)+self.offset)*CFrame.Angles(0,0,math.pi/2)
        end
    end
    function World:clearActors()
        self:bossIntro(nil)
        previousClear(self)
    end
    return World
end
