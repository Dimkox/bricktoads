-- Presentation-only camera. It never knows about remotes or combat intents.
local SpectatorCamera = {}
SpectatorCamera.__index = SpectatorCamera

function SpectatorCamera.clampAxes(x, y, z, bounds)
    if not bounds then return x, y, z end
    return math.clamp(x, bounds.minX, bounds.maxX), math.clamp(y, bounds.minY, bounds.maxY),
        math.clamp(z, bounds.minZ, bounds.maxZ)
end

function SpectatorCamera.followTargets(heroes, models)
    local targets = {}
    for _, hero in ipairs(heroes or {}) do
        if hero.status == "Alive" and not hero.dying and models[hero.actorId] then
            table.insert(targets, {hero = hero, model = models[hero.actorId]})
        end
    end
    return targets
end

function SpectatorCamera.new()
    return setmetatable({mode = "Follow", enabled = false, keys = {}, targets = {},
        touchX = 0, touchZ = 0, yaw = 0, pitch = -math.atan2(23, 30), refreshElapsed = 1}, SpectatorCamera)
end

function SpectatorCamera:resetInput()
    self.keys, self.touchX, self.touchZ = {}, 0, 0
end

function SpectatorCamera:setEnabled(enabled)
    if self.enabled and not enabled then self:resetInput() end
    self.enabled = enabled == true
end

function SpectatorCamera:sync(snapshot, controlled)
    if self.runId ~= snapshot.runId or self.levelEpoch ~= snapshot.levelEpoch
        or self.worldName ~= snapshot.worldName or self.groupId ~= snapshot.groupId then
        self.mode, self.selectedActorId, self.point, self.freePosition = "Follow", nil, nil, nil
        self.models, self.targets = {}, {}
        self.introCameraId,self.introCounter,self.introShake=nil,nil,nil
        self:resetInput()
        self.refreshElapsed = 1
    end
    self.runId, self.levelEpoch = snapshot.runId, snapshot.levelEpoch
    self.worldName, self.groupId = snapshot.worldName, snapshot.groupId
    self.snapshot, self.controlled, self.bounds = snapshot, controlled, snapshot.cameraBounds
    local mode=snapshot.level and snapshot.level.modeState
    local serial=mode and mode.camera and mode.camera.rewindSerial
    if serial~=nil and self.vehicleRewindSerial~=nil and serial~=self.vehicleRewindSerial then self.point=nil end
    self.vehicleRewindSerial=serial
    if controlled and controlled.status == "Alive" and controlled.connected and not controlled.dying then
        self.mode = "Follow"
        self:resetInput()
    end
end

function SpectatorCamera:refreshTargets()
    local world
    if self.worldName then world = workspace:FindFirstChild(self.worldName)
    else world = workspace:FindFirstChild("BrickToadsWorld") or workspace:FindFirstChild("CombatStandWorld") end
    local actors = world and world:FindFirstChild("Actors")
    local models = {}
    for _, model in ipairs(actors and actors:GetChildren() or {}) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
            local id = model:GetAttribute("ActorId")
            if id then models[id] = model end
        end
    end
    self.models = models
    self.targets = SpectatorCamera.followTargets(self.snapshot and self.snapshot.heroes, models)
end

function SpectatorCamera:nextHero()
    if #self.targets == 0 then self.selectedActorId = nil; return nil end
    local current = 0
    for i, target in ipairs(self.targets) do
        if target.hero.actorId == self.selectedActorId then current = i; break end
    end
    self.selectedActorId = self.targets[current % #self.targets + 1].hero.actorId
    self.mode, self.point = "Follow", nil
    self:resetInput()
    return self.selectedActorId
end

function SpectatorCamera:isFree()
    return self.mode == "Free"
end

function SpectatorCamera:toggleFree(camera)
    if not self.enabled or not camera or not self.bounds then return end
    self:resetInput()
    if self:isFree() then self.mode = "Follow"; self.point = nil; return end
    self.mode = "Free"
    local p, look = camera.CFrame.Position, camera.CFrame.LookVector
    local x, y, z = SpectatorCamera.clampAxes(p.X, p.Y, p.Z, self.bounds)
    self.freePosition = Vector3.new(x, y, z)
    self.yaw = math.atan2(-look.X, -look.Z)
    self.pitch = math.asin(math.clamp(look.Y, -1, 1))
end

function SpectatorCamera:setKey(key, down)
    if self.enabled and self:isFree() then self.keys[key] = down or nil end
end

function SpectatorCamera:setTouch(x, z)
    if self.enabled and self:isFree() then self.touchX, self.touchZ = x, z end
end

function SpectatorCamera:rotate(amount)
    if self.enabled and self:isFree() then self.yaw += amount end
end

function SpectatorCamera:stepIntro(dt,camera)
    local function release()
        self.introCameraId,self.introCounter,self.introShake=nil,nil,nil
        camera:SetAttribute('BossIntroId',nil)
        return false
    end
    if self:isFree() or not self.worldName then return release() end
    local world=workspace:FindFirstChild(self.worldName)
    local intro=world and world:FindFirstChild('BossIntro')
    if not intro or intro:GetAttribute('Active')~=true or intro:GetAttribute('RunId')~=self.runId
        or intro:GetAttribute('LevelEpoch')~=self.levelEpoch then return release() end
    local counter,id,focus=intro:GetAttribute('Counter'),intro:GetAttribute('IntroId'),intro:GetAttribute('Focus')
    local function finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
    local focusType=typeof(focus)
    if not finite(counter) or counter%1~=0 or counter<1 or counter>=255 or type(id)~='string'
        or (focusType~='Vector3' and focusType~='table')
        or not finite(focus.X) or not finite(focus.Y) or not finite(focus.Z) then return release() end
    if self.introCameraId~=id then
        self.introCameraId,self.introCounter,self.introShake=id,counter,0
    end
    for _,mark in ipairs({0x30,0x64})do
        if self.introCounter<mark and counter>=mark then self.introShake=.16 end
    end
    self.introCounter=counter
    self.introShake=math.max(0,(self.introShake or 0)-math.clamp(dt,0,.1))
    local cut=intro:GetAttribute('CameraCut')==true
    local target,offset=focus,Vector3.new(-19,15,27)
    if not cut then
        local controlled=self.controlled
        local model=controlled and self.models and self.models[controlled.actorId]
        if not model and self.targets[1] then model=self.targets[1].model end
        local root=model and model.Parent and model:FindFirstChild('HumanoidRootPart')
        if root then
            local distance=(root.Position-focus).Magnitude
            target=(root.Position+focus)/2
            offset=Vector3.new(14,math.max(16,distance*.35),math.max(28,distance*.7))
        else offset=Vector3.new(15,18,30) end
    end
    -- Camera distance, short shake and perspective are authored3D adaptation.
    -- The server's source counter determines the two impacts and the E0 cut.
    local shake=math.sin((.16-self.introShake)*100)*self.introShake*1.25
    camera.CFrame=CFrame.lookAt(target+offset+Vector3.new(shake,0,0),target)
    camera:SetAttribute('BossIntroId',id)
    return true
end

function SpectatorCamera:step(dt, camera)
    if not camera then return end
    self.refreshElapsed += dt
    if self.refreshElapsed >= 0.2 then self.refreshElapsed = 0; self:refreshTargets() end
    camera.CameraType = Enum.CameraType.Scriptable
    camera:SetAttribute("SpectatorMode", self.mode)
    if self:stepIntro(dt,camera) then return end
    if self:isFree() and self.freePosition then
        if self.enabled then
            local function down(key) return self.keys[key] and 1 or 0 end
            local x = down("D") - down("A") + self.touchX
            local z = down("S") - down("W") + self.touchZ
            local horizontal = Vector2.new(x, z)
            if horizontal.Magnitude > 1 then horizontal = horizontal.Unit end
            self.yaw += (down("Left") - down("Right")) * dt * 1.6
            local forward = Vector3.new(-math.sin(self.yaw), 0, -math.cos(self.yaw))
            local right = Vector3.new(math.cos(self.yaw), 0, -math.sin(self.yaw))
            local lift = math.clamp(down("E") - down("Q") + down("Up") - down("Down"), -1, 1)
            self.freePosition += (right * horizontal.X - forward * horizontal.Y + Vector3.new(0, lift, 0)) * math.min(dt, 0.1) * 34
        end
        local p = self.freePosition
        local x, y, z = SpectatorCamera.clampAxes(p.X, p.Y, p.Z, self.bounds)
        self.freePosition = Vector3.new(x, y, z)
        camera.CFrame = CFrame.new(self.freePosition) * CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(self.pitch, 0, 0)
        return
    end
    local targetModel
    local controlled = self.controlled
    if controlled and controlled.status == "Alive" and controlled.connected and not controlled.dying then
        targetModel = self.models and self.models[controlled.actorId]
    else
        for _, target in ipairs(self.targets) do
            if target.hero.actorId == self.selectedActorId then targetModel = target.model; break end
        end
        if not targetModel and self.targets[1] then
            targetModel, self.selectedActorId = self.targets[1].model, self.targets[1].hero.actorId
        end
    end
    local root = targetModel and targetModel.Parent and targetModel:FindFirstChild("HumanoidRootPart")
    if root then
        local target = root.Position + Vector3.new(0, 2, 0)
        self.point = self.point and self.point:Lerp(target, 1 - math.exp(-dt * 7)) or target
        local level=self.snapshot and self.snapshot.level
        local mode=level and level.modeState
        local actor
        for _,candidate in ipairs(mode and mode.actors or {}) do
            if candidate.actorId==targetModel:GetAttribute('ActorId') then actor=candidate;break end
        end
        local offset,focus=Vector3.new(0,23,30),self.point
        if actor and not actor.finished then
            if mode.mode=='Tower' then
                local world=workspace:FindFirstChild(self.worldName)
                local geometry=world and world:FindFirstChild('Geometry')
                local core=geometry and geometry:FindFirstChild('SpireCore')
                if core then
                    local relative=self.point-core.Position
                    local angle=math.atan2(relative.Z,relative.X)
                    offset=Vector3.new(math.cos(angle)*43,19,math.sin(angle)*43)
                end
            elseif mode.mode=='Clinger' then offset=Vector3.new(0,46,5)
            elseif mode.mode=='Rope' then offset=Vector3.new(0,8,43);focus=self.point+Vector3.new(0,-5,0)
            elseif mode.mode=='Speeder' or mode.mode=='Surf' or mode.mode=='Jet' then
                offset=Vector3.new(10,16,43);focus=self.point+Vector3.new(12,0,0)
            elseif mode.mode=='Tubes' or mode.mode=='Race' or mode.mode=='Ascent' then offset=Vector3.new(0,15,40) end
        end
        camera.CFrame = CFrame.lookAt(self.point + offset, focus)
    elseif not self.point then
        if self.worldName and self.bounds then
            local bounds = self.bounds
            local target = Vector3.new((bounds.minX + bounds.maxX) / 2, bounds.minY - 5, (bounds.minZ + bounds.maxZ) / 2)
            camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 23, 30), target)
        else
            camera.CFrame = CFrame.lookAt(Vector3.new(-55, 30, 36), Vector3.new(-45, 2, 0))
        end
    end
end

return SpectatorCamera
