-- Synchronous test double for effect ordering, never a substitute for engine physics.
local World = {}
World.__index = World
function World.new()
    return setmetatable({actors={}, safe=true, spawnFails=false, raceUnsafe=false,
        impulses=0, spawns=0, kills=0, relocations=0, moves=0, targetsFor={}, hazards={},actualRuns={}}, World)
end
function World:findSafe() if self.safe then return {safe=true} end end
function World:isSafe() return self.safe and not self.raceUnsafe end
function World:spawn(uid, id, point, held)
    if self.spawnFails or (point and not self:isSafe(point, uid)) then return false end
    self.spawns = self.spawns + 1
    self.actors[uid] = {id=id, held=held, alive=true}
    self.hazards[uid] = nil
    return true
end
function World:hold(uid, held) if self.actors[uid] then self.actors[uid].held = held end end
function World:move(uid, x, z, run)
    self.moves=self.moves+1;self.lastMove={uid,x,z,run}
    if x*x+z*z==0 or run~=true then self.actualRuns[uid]=nil end
end
function World:isRunning(uid) return self.actualRuns[uid]==true end
function World:movementMode(uid) return self:isRunning(uid) and 'Run' or 'Idle' end
function World:resetLocomotion(uid,reference)
    local actor=reference or self.actors[uid]
    self.lastReset={uid,actor};self.resets=(self.resets or 0)+1
    if actor==self.actors[uid] then self.actualRuns[uid]=nil end
end
function World:jump(uid) self.lastJump=uid end
function World:setReaction(uid, active) if self.actors[uid] then self.actors[uid].reaction=active end end
function World:targets(uid) return self.targetsFor[uid] or {} end
function World:impulse(uid, attacker, cfg, profile, impulseDirection)
    self.impulses=self.impulses+1; self.lastImpulse={uid,attacker}
    self.lastProfile=profile; self.lastCalibration=cfg
    self.lastImpulseDirection=type(impulseDirection)=='table' and table.clone(impulseDirection) or nil
end
function World:hazard(uid) return self.hazards[uid] end
function World:kill(uid) self.kills=self.kills+1; self.actors[uid].alive=false end
function World:relocate(uid, point)
    if not self:isSafe(point, uid) then return false end
    self.relocations=self.relocations+1
    return true
end
function World:observe(uid) return {actor=self.actors[uid] and self.actors[uid].id} end
return World
