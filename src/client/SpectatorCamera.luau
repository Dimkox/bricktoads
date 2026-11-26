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
        touchX = 0, touchZ = 0, refreshElapsed = 1}, SpectatorCamera)
end

function SpectatorCamera:resetInput()
    self.keys, self.touchX, self.touchZ = {}, 0, 0
end

function SpectatorCamera:setEnabled(enabled)
    if self.enabled and not enabled then
        self.mode, self.freePosition = "Follow", nil
        self:resetInput()
    end
    self.enabled = enabled == true
end

function SpectatorCamera:sync(snapshot, controlled)
    if self.runId ~= snapshot.runId or self.levelEpoch ~= snapshot.levelEpoch
        or self.worldName ~= snapshot.worldName or self.groupId ~= snapshot.groupId then
        self.mode, self.selectedActorId, self.point, self.freePosition = "Follow", nil, nil, nil
        self.models, self.targets = {}, {}
        self.followedModel = nil
        self:resetInput()
        self.refreshElapsed = 1
    end
    self.runId, self.levelEpoch = snapshot.runId, snapshot.levelEpoch
    self.worldName, self.groupId = snapshot.worldName, snapshot.groupId
    self.snapshot, self.controlled, self.bounds = snapshot, controlled, snapshot.cameraBounds
    if controlled and controlled.status == "Alive" and controlled.connected and not controlled.dying then
        self.mode, self.freePosition = "Follow", nil
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
    self.mode, self.freePosition = "Follow", nil
    self:resetInput()
    return self.selectedActorId
end

function SpectatorCamera:isFree()
    return self.mode == "Free"
end

function SpectatorCamera:toggleFree(camera)
    if not self.enabled or not camera or not self.bounds then return end
    self:resetInput()
    if self:isFree() then self.mode, self.freePosition = "Follow", nil; return end
    self.mode = "Free"
    local p = camera.Focus.Position
    self.freePosition = Vector3.new(SpectatorCamera.clampAxes(p.X, p.Y, p.Z, self.bounds))
end

function SpectatorCamera:setKey(key, down)
    if self.enabled and self:isFree() then self.keys[key] = down or nil end
end

function SpectatorCamera:setTouch(x, z)
    if self.enabled and self:isFree() then self.touchX, self.touchZ = x, z end
end

-- A server-owned actor is not LocalPlayer.Character. Give CameraModule a real
-- subject even before spawn, and leave its orbit, zoom and occlusion intact.
function SpectatorCamera:anchorAt(position)
    if not self.anchor then
        local anchor = Instance.new("Part")
        anchor.Name = "BrickToadsCameraFocus"
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
        anchor.Transparency, anchor.CastShadow = 1, false
        anchor.CFrame = CFrame.new(position)
        anchor.Parent = workspace
        self.anchor = anchor
    elseif self.anchor.Position ~= position then
        self.anchor.CFrame = CFrame.new(position)
    end
    return self.anchor
end

function SpectatorCamera:moveFreeFocus(dt, camera)
    local function down(key) return self.keys[key] and 1 or 0 end
    local x = down("D") - down("A") + self.touchX
    local z = down("S") - down("W") + self.touchZ
    local lift = math.clamp(down("E") - down("Q") + down("Up") - down("Down"), -1, 1)
    local length = math.max(1, math.sqrt(x*x + z*z))
    local axis = camera.CFrame.RightVector
    local right = Vector3.new(axis.X, 0, axis.Z)
    right = right.Magnitude > 0.001 and right.Unit or Vector3.new(1, 0, 0)
    local back = Vector3.new(-right.Z, 0, right.X)
    local movement = (right*x + back*z) * (1/length) + Vector3.new(0, lift, 0)
    local p = self.freePosition + movement * (math.min(dt, 0.1) * 34)
    self.freePosition = Vector3.new(SpectatorCamera.clampAxes(p.X, p.Y, p.Z, self.bounds))
    return self:anchorAt(self.freePosition)
end

function SpectatorCamera:followSubject()
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
    if targetModel and targetModel.Parent then
        local head = targetModel:FindFirstChild("Head")
        local subject = head and head:IsA("BasePart") and head or targetModel:FindFirstChild("HumanoidRootPart")
        if subject then
            self.point = subject.Position
            self.followedModel = targetModel
            return subject
        end
    end
    self.followedModel = nil
    if not self.point then
        local bounds = self.worldName and self.bounds
        self.point = bounds and Vector3.new((bounds.minX + bounds.maxX)/2, bounds.minY - 5, (bounds.minZ + bounds.maxZ)/2)
            or Vector3.new(-45, 2, 0)
    end
    return self:anchorAt(self.point)
end

function SpectatorCamera:step(dt, camera)
    if not camera then return end
    self.refreshElapsed += dt
    if self.refreshElapsed >= 0.2 then self.refreshElapsed = 0; self:refreshTargets() end
    local subject
    if self:isFree() and self.freePosition then
        self.followedModel = nil
        subject = self:moveFreeFocus(dt, camera)
    else
        subject = self:followSubject()
    end
    if camera.CameraSubject ~= subject then camera.CameraSubject = subject end
    if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
    if self.camera ~= camera or self.reportedMode ~= self.mode then
        camera:SetAttribute("SpectatorMode", self.mode)
        self.camera, self.reportedMode = camera, self.mode
    end
end

function SpectatorCamera:destroy()
    if self.anchor then self.anchor:Destroy(); self.anchor = nil end
end

return SpectatorCamera
