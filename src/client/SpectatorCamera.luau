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
    if self.runId ~= snapshot.runId or self.levelEpoch ~= snapshot.levelEpoch then
        self.mode, self.selectedActorId, self.point, self.freePosition = "Follow", nil, nil, nil
        self:resetInput()
        self.refreshElapsed = 1
    end
    self.runId, self.levelEpoch = snapshot.runId, snapshot.levelEpoch
    self.snapshot, self.controlled, self.bounds = snapshot, controlled, snapshot.cameraBounds
    if controlled and controlled.status == "Alive" and controlled.connected and not controlled.dying then
        self.mode = "Follow"
        self:resetInput()
    end
end

function SpectatorCamera:refreshTargets()
    local world = workspace:FindFirstChild("BrickToadsWorld") or workspace:FindFirstChild("CombatStandWorld")
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

function SpectatorCamera:step(dt, camera)
    if not camera then return end
    self.refreshElapsed += dt
    if self.refreshElapsed >= 0.2 then self.refreshElapsed = 0; self:refreshTargets() end
    camera.CameraType = Enum.CameraType.Scriptable
    camera:SetAttribute("SpectatorMode", self.mode)
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
        camera.CFrame = CFrame.lookAt(self.point + Vector3.new(0, 23, 30), self.point)
    elseif not self.point then
        camera.CFrame = CFrame.lookAt(Vector3.new(-55, 30, 36), Vector3.new(-45, 2, 0))
    end
end

return SpectatorCamera
