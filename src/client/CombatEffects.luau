-- Local, bounded cosmetic geometry. This module never writes to gameplay actors.
local Effects={}
Effects.__index=Effects
local MAX_PARTICLES=24
local styles={
    hit={count=4,life=.22,radius=1.15,color={255,206,106}},
    shield={count=8,life=.32,radius=1.8,color={133,202,225}},
    heal={count=5,life=.48,radius=1.1,color={157,223,135}},
    spawn={count=6,life=.52,radius=1.6,color={178,220,154}},
    warning={count=6,life=.42,radius=2,color={232,177,104}},
    crash={count=5,life=.34,radius=1.8,color={224,155,116}},
    result={count=8,life=.62,radius=2.4,color={219,213,135}},
    death={count=4,life=.35,radius=1.2,color={177,168,162}},
}
local function finite(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
local function observedNow(data)
    if finite(data.now) and finite(data.serverNow) then return math.max(data.now,data.serverNow) end
    return finite(data.serverNow) and data.serverNow or data.now
end
local function dispose(handle) if handle and handle.destroy then pcall(function() handle:destroy() end) end end

local function native(deps)
    local workspace=deps.workspace or game:GetService('Workspace')
    local tweenService=deps.tweenService or game:GetService('TweenService')
    local debris=deps.debris or game:GetService('Debris')
    local folder
    local function container(group)
        if not folder or not folder.Parent then
            folder=Instance.new('Folder');folder.Name='BrickToadsLocalEffects';folder.Parent=deps.effectsParent or workspace
        end
        folder:SetAttribute('GroupId',group)
        return folder
    end
    local function position(event,data)
        if type(data.groupId)~='string' or data.groupId=='' then return nil end
        local world
        for _,child in ipairs(workspace:GetChildren()) do
            if child:GetAttribute('GroupId')==data.groupId and child:FindFirstChild('Actors') then world=child;break end
        end
        if not world then return nil end
        local actorId=event.actorId
        local slot=event.slot or data.mine or -99
        if not actorId then
            for _,hero in ipairs(data.heroes or {}) do if hero.slot==slot then actorId=hero.actorId;break end end
        end
        for _,model in ipairs(world.Actors:GetChildren()) do
            local matches=actorId and model:GetAttribute('ActorId')==actorId
                or not actorId and (model:GetAttribute('Slot')==slot or model.Name=='Actor_'..tostring(slot))
            if matches then
                local root=model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart
                if root and root:IsA('BasePart') then local p=root.Position;return {x=p.X,y=p.Y,z=p.Z} end
            end
        end
        return nil
    end
    local function particle(spec)
        local p=Instance.new('Part');p.Name='Cosmetic_'..spec.kind;p.Anchored=true
        p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Massless=true
        p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(unpack(spec.color))
        p.Size=Vector3.new(spec.size,spec.size,spec.size);p.Transparency=spec.transparency
        p.CFrame=CFrame.new(spec.x,spec.y,spec.z)*CFrame.Angles(0,0,spec.angle)
        p.Parent=container(spec.groupId)
        local tween=tweenService:Create(p,TweenInfo.new(spec.life,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {Transparency=1,Position=Vector3.new(spec.toX,spec.toY,spec.toZ),Size=p.Size*.35})
        tween:Play();debris:AddItem(p,spec.life+.08)
        return {destroy=function() tween:Cancel();p:Destroy() end}
    end
    return position,particle,function() if folder then folder:Destroy();folder=nil end end
end

function Effects.new(deps)
    deps=deps or {}
    local resolve,create,cleanup=deps.resolvePosition,deps.createParticle,nil
    if not resolve or not create then local r,c,d=native(deps);resolve=resolve or r;create=create or c;cleanup=d end
    return setmetatable({resolve=resolve,create=create,cleanup=cleanup,particles={},enabled=true,reduced=true},Effects)
end
function Effects:reset()
    for _,row in ipairs(self.particles) do dispose(row.handle) end
    self.particles={}
    if self.cleanup then self.cleanup() end
end
function Effects:sync(data)
    if self.destroyed then return end
    local now=type(data)=='table' and observedNow(data)
    if not finite(now) then return end
    for i=#self.particles,1,-1 do
        if self.particles[i].expires<=now then dispose(self.particles[i].handle);table.remove(self.particles,i) end
    end
end
function Effects:emit(kind,event,data)
    if self.destroyed or not self.enabled or type(data)~='table' or type(data.groupId)~='string' or data.groupId=='' then return false end
    local style=styles[kind];if not style then return false end
    local now=observedNow(data);if not finite(now) then return false end
    self:sync(data)
    local ok,p=pcall(self.resolve,event,data)
    if not ok or type(p)~='table' or not finite(p.x) or not finite(p.y) or not finite(p.z) then return false end
    for i=1,style.count do
        while #self.particles>=MAX_PARTICLES do dispose(table.remove(self.particles,1).handle) end
        local angle=(i-1)*math.pi*2/style.count
        local dx,dz=math.cos(angle),math.sin(angle)
        local ring=kind=='shield' or kind=='warning' or kind=='spawn'
        local start=ring and style.radius*.65 or .2
        local spec={kind=kind,groupId=data.groupId,life=style.life,color=style.color,
            size=ring and .18 or .24,transparency=self.reduced and .32 or .14,angle=angle,
            anchored=true,canCollide=false,canQuery=false,canTouch=false,
            x=p.x+dx*start,y=p.y+(kind=='result' and 1.8 or .25),z=p.z+dz*start,
            toX=p.x+dx*style.radius,toY=p.y+(kind=='heal' and 2.2 or kind=='result' and 3.2 or .5),toZ=p.z+dz*style.radius}
        local made,handle=pcall(self.create,spec)
        if made and handle then self.particles[#self.particles+1]={handle=handle,expires=now+style.life} end
    end
    return true
end
function Effects:setEnabled(value) self.enabled=value==true;if not self.enabled then self:reset() end end
function Effects:setReducedFlash(value) self.reduced=value~=false end
function Effects:diagnostics() return {live=#self.particles,limit=MAX_PARTICLES,enabled=self.enabled,destroyed=self.destroyed==true} end
function Effects:destroy() if self.destroyed then return end;self:reset();self.destroyed=true end
return Effects
