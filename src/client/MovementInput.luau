-- Native Bool actions own hardware/touch aggregation; this model owns tap timing.
local MovementInput={}
MovementInput.__index=MovementInput
local directions={Forward=true,Backward=true,Left=true,Right=true}
local opposite={Forward='Backward',Backward='Forward',Left='Right',Right='Left'}

function MovementInput.new()
    return setmetatable({down={},lastPress={},runDirection=nil},MovementInput)
end
function MovementInput:press(direction,now)
    if not directions[direction] or self.down[direction] then return false end
    local previous=self.lastPress[direction]
    self.down[direction]=true
    if self.runDirection and opposite[direction]==self.runDirection then self.runDirection=nil
    elseif not self.down[opposite[direction]] and previous and now>=previous and now-previous<=.25 then self.runDirection=direction end
    self.lastPress[direction]=now
    return true
end
function MovementInput:release(direction)
    if not self.down[direction] then return false end
    self.down[direction]=nil
    if self.runDirection==direction then self.runDirection=nil end
    return true
end
-- x/z are relative to the center of the pad, with 1 at its outer edge.
function MovementInput:setPad(x,z,begin,now)
    local ax,az=math.abs(x),math.abs(z)
    local px,pz=0,0
    if math.max(ax,az)>.13 then
        if ax>=az*.45 then px=math.sign(x) end
        if az>=ax*.45 then pz=math.sign(z) end
    end
    local changed=px~=(self.padX or 0) or pz~=(self.padZ or 0)
    if begin then
        self.padRun=(px~=0 or pz~=0) and self.tapX==px and self.tapZ==pz
            and self.tapAt~=nil and now-self.tapAt<=.32
        self.tapX,self.tapZ,self.tapAt=px,pz,now
    elseif px==0 and pz==0 then
        self.padRun=false
    end
    self.padX,self.padZ=px,pz
    return changed
end
function MovementInput:reset(held,keepPad)
    if not keepPad then self.padX,self.padZ=0,0 end
    self.padRun,self.tapAt=false,nil
    self.down,self.lastPress,self.runDirection={}, {}, nil
    for direction,value in pairs(held or {}) do if directions[direction] and value then self.down[direction]=true end end
end
function MovementInput:vector(forward,localAxes)
    if localAxes then forward=nil end
    local function down(direction) return self.down[direction] and 1 or 0 end
    local x=math.clamp(down('Right')-down('Left')+(self.padX or 0),-1,1)
    local z=math.clamp(down('Backward')-down('Forward')+(self.padZ or 0),-1,1)
    local length=math.sqrt(x*x+z*z)
    if length>1 then x,z=x/length,z/length end
    local fx,fz=forward and forward.x or 0,forward and forward.z or -1
    length=math.sqrt(fx*fx+fz*fz)
    if length<.01 then fx,fz,length=0,-1,1 end
    fx,fz=fx/length,fz/length
    local run=self.runDirection~=nil and self.down[self.runDirection]==true
        and not self.down[opposite[self.runDirection]] and (x~=0 or z~=0)
    return {x=-fz*x-fx*z,z=fx*x-fz*z,run=(run or self.padRun)==true and (x~=0 or z~=0)}
end
return MovementInput
