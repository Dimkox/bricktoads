-- Original 3D tuning around the source's ground-ball pickup/throw guardian chain.
-- Authority and ordinary attack validation belong to Session/Director, never the client.
local GuardianPattern={}
GuardianPattern.__index=GuardianPattern

local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function point(p) return type(p)=='table' and finite(p.x) and finite(p.y) and finite(p.z) end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b)
    if not point(a) or not point(b) then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function towards(a,b,amount)
    local d=distance(a,b)
    if d==0 then return copy(b) end
    local t=math.min(1,amount/d)
    return {x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,z=a.z+(b.z-a.z)*t}
end
local function segmentDistance(a,b,p)
    if not point(p) then return math.huge end
    local x,y,z=b.x-a.x,b.y-a.y,b.z-a.z
    local length=x*x+y*y+z*z
    local t=length>0 and math.clamp(((p.x-a.x)*x+(p.y-a.y)*y+(p.z-a.z)*z)/length,0,1) or 0
    return distance({x=a.x+t*x,y=a.y+t*y,z=a.z+t*z},p)
end
local function ids(projectiles)
    local result={}
    for id in pairs(projectiles) do result[#result+1]=id end
    table.sort(result,function(a,b) return a>b end)
    return result
end

function GuardianPattern.new(director)
    local now=director.now or 0; local cfg=director.config.Boss
    local self=setmetatable({director=director,world=director.world,session=director.session,config=cfg,
        now=now,carriers={},nextShot=director.nextShot or now+(cfg.initial or 1.8),
        nextBall=now+(cfg.ballInterval or 8)},GuardianPattern)
    director.nextShot=self.nextShot
    local boss=director.enemies[-99]
    if boss and boss.rawLife==nil then boss.rawLife=math.max(0,47-16*(director.bossHits or 0)) end
    return self
end

function GuardianPattern:_active()
    local d=self.director; local boss=d.enemies[-99]
    return d.stage=='Boss' and not d.result and self.session.state.status=='Active' and boss and not boss.dead
end

function GuardianPattern:_hero(slot,held)
    local h=self.session.state.heroes[slot]; local combat=self.session.combat[slot]
    if not h or h.status~='Alive' or h.connected~=true or not combat or combat.deathAt then return nil end
    if held and (held.actorId~=h.actorId or held.attempt~=h.attempt or held.connectionEpoch~=h.connectionEpoch) then return nil end
    if not point(self.world:position(slot)) then return nil end
    return h
end

function GuardianPattern:_render(id,p)
    self.world:projectile(id,p.position,false,p.mode)
end

function GuardianPattern:_remove(id)
    local p=self.director.projectiles[id]
    if not p then return end
    if p.holder and self.carriers[p.holder]==id then self.carriers[p.holder]=nil end
    self.director.projectiles[id]=nil
    self.world:removeProjectile(id)
end

function GuardianPattern:_clear()
    for _,id in ipairs(ids(self.director.projectiles)) do self:_remove(id) end
    table.clear(self.carriers)
end

function GuardianPattern:_drop(id,p)
    if p.holder and self.carriers[p.holder]==id then self.carriers[p.holder]=nil end
    p.holder=nil; p.actorId=nil; p.attempt=nil; p.connectionEpoch=nil
    local ground=self.world:groundPosition(p.position)
    if not point(ground) or self.now>=p.expiresAt then self:_remove(id); return end
    p.mode='Ground'; p.position=copy(ground); p.direction=nil
    self:_render(id,p)
end

function GuardianPattern:_carried(slot)
    local id=self.carriers[slot]; local p=id and self.director.projectiles[id]
    if not p or p.mode~='Carried' or p.holder~=slot then self.carriers[slot]=nil; return nil end
    if self.now>=p.expiresAt or not self:_hero(slot,p) then self:_drop(id,p); return nil end
    return id,p
end

function GuardianPattern:_ground(slot)
    local position=self.world:position(slot); local selected,best=nil,math.huge
    for _,id in ipairs(ids(self.director.projectiles)) do
        local p=self.director.projectiles[id]
        if p.mode=='Ground' and self.now<p.expiresAt and math.abs(position.y-p.position.y)<=3.5 then
            local range=distance(position,p.position)
            if range<=(self.config.pickupRange or 5.5) and range<best then selected,best=id,range end
        end
    end
    return selected,selected and self.director.projectiles[selected]
end

function GuardianPattern:_spawn(mode,aim,target)
    local origin=self.world:position(-99)
    if not point(origin) then return false end
    local destination
    if target then
        local h=self.session.state.heroes[target]
        local combat=self.session.combat[target]
        local position=self.world:position(target)
        if not h or h.status~='Alive' or not combat or combat.deathAt or not point(position) then return false end
        destination=copy(position)
    elseif aim then
        local length=math.sqrt(aim.x^2+aim.z^2)
        destination={x=origin.x+aim.x/length*self.config.aggroRange,y=origin.y,
            z=origin.z+aim.z/length*self.config.aggroRange}
    end
    if not destination then return false end
    if mode=='Heavy' then
        destination=self.world:groundPosition(destination)
        if not point(destination) then return false end
        destination=copy(destination)
    end
    local d=self.director; local id
    repeat
        d.serial=math.max(0,d.serial or 0)+1; id=-1000-d.serial
    until not d.projectiles[id]
    local p={mode=mode,position=towards(origin,destination,5),direction=destination,target=target,
        created=self.now,expiresAt=self.now+(self.config.ballLife or 20)}
    d.projectiles[id]=p
    if target and not d.enemies[-99].ownerUserId and self.world.face then self.world:face(-99,target) end
    self.world:cue(-99,true); self:_render(id,p)
    return true
end

function GuardianPattern:fire(aim,target)
    if not self:_active() then return 'NOT_ALIVE' end
    local boss=self.director.enemies[-99]
    if boss.ownerUserId and boss.connected==false then return 'OFFLINE' end
    self.now=math.max(self.now,self.director.now or self.now)
    if self.now<self.nextShot then return 'COOLDOWN' end
    if aim and (type(aim)~='table' or not finite(aim.x) or not finite(aim.z) or aim.x^2+aim.z^2<=0) then return 'INVALID_AIM' end
    if not self:_spawn('Bullet',aim,target) then return 'NO_TARGET' end
    self.nextShot=self.now+self.config.interval; self.director.nextShot=self.nextShot
    return 'OK'
end

function GuardianPattern:hit(attacker,target,action)
    if self.director.projectiles[target] then return false end
    if target==-99 and self:_active() then self.world:cue(-99,true); return true end
    return false
end

function GuardianPattern:interaction(slot)
    if not self:_active() then return {available=false,carrying=false} end
    self.now=math.max(self.now,self.director.now or self.now)
    local carried=self:_carried(slot)
    if not self:_hero(slot) then return {available=false,carrying=false} end
    if carried then return {available=true,label='БРОСИТЬ ШАР',carrying=true} end
    if self:_ground(slot) then return {available=true,label='ВЗЯТЬ ШАР',carrying=false} end
    return {available=false,carrying=false}
end

function GuardianPattern:interact(slot,now)
    if not finite(now) or now<0 then return 'INVALID_TIME' end
    if not self:_active() then return 'NO_INTERACTION' end
    self.now=math.max(self.now,now,self.director.now or now)
    local id,p=self:_carried(slot)
    local h=self:_hero(slot)
    if not h then return 'NO_INTERACTION' end
    if p then
        -- BeginAttack is the authoritative shield transition. Failure keeps the
        -- ball carried; neither its flight nor the hold release has happened yet.
        local result=self.session:_event('BeginAttack',slot,{connectionEpoch=h.connectionEpoch})
        if result~='OK' then return result end
        self.world:hold(slot,false)
        self.carriers[slot]=nil
        p.mode='Thrown'; p.holder=nil; p.actorId=nil; p.attempt=nil; p.connectionEpoch=nil
        p.target=-99; p.direction=nil; p.created=self.now; p.expiresAt=self.now+(self.config.ballLife or 20)
        self:_render(id,p)
        return 'OK'
    end
    id,p=self:_ground(slot)
    if not p then return 'NO_INTERACTION' end
    p.mode='Carried'; p.holder=slot; p.actorId=h.actorId; p.attempt=h.attempt; p.connectionEpoch=h.connectionEpoch
    self.carriers[slot]=id
    local position=self.world:position(slot)
    p.position={x=position.x,y=position.y+2,z=position.z}
    self:_render(id,p)
    return 'OK'
end

function GuardianPattern:_impact(id)
    if not self:_active() then return end
    local d=self.director; local boss=d.enemies[-99]
    d.bossHits=(d.bossHits or 0)+1
    boss.rawLife=math.max(0,boss.rawLife-16)
    boss.health=math.max(0,(self.config.hits or 3)-d.bossHits)
    self.world:enemyHealth(-99,boss.health,self.config.hits or 3); self.world:cue(-99,false)
    self:_remove(id)
    if boss.rawLife==0 then d:_kill(-99); self:_clear() end
end

function GuardianPattern:step(now,dt)
    if not finite(now) or now<0 or (dt~=nil and (not finite(dt) or dt<0)) then return 'INVALID_TIME' end
    if now<self.now then return 'TIME_REVERSED' end
    self.now=now; dt=dt or 0
    if not self:_active() then self:_clear(); return 'OK' end
    local d=self.director; local boss=d.enemies[-99]
    for slot in pairs(self.carriers) do self:_carried(slot) end
    -- The finite special-shot deadline belongs to the server, including while a
    -- human owner is idle/offline. It does not supply ordinary human commands.
    if now>=self.nextBall then
        local target=d:_nearest(self.world:position(-99))
        if target then self:_spawn('Heavy',nil,target) end
        self.nextBall=now+(self.config.ballInterval or 8)
    end
    if not boss.ownerUserId and now>=self.nextShot then
        local target,range=d:_nearest(self.world:position(-99))
        if target and range<=self.config.aggroRange then self:fire(nil,target) end
    end
    for _,id in ipairs(ids(d.projectiles)) do
        if not self:_active() then self:_clear(); break end
        local p=d.projectiles[id]
        if p then
            if now>=p.expiresAt then self:_remove(id)
            elseif p.mode=='Carried' then
                local position=self.world:position(p.holder)
                p.position={x=position.x,y=position.y+2,z=position.z}; self:_render(id,p)
            elseif p.mode~='Ground' then
                local destination=p.mode=='Thrown' and self.world:position(-99) or p.direction
                if not point(destination) then self:_remove(id)
                else
                    local before=p.position
                    local speed=p.mode=='Thrown' and self.config.returnSpeed or self.config.projectileSpeed
                    p.position=towards(before,destination,speed*dt)
                    self:_render(id,p)
                    if p.mode=='Thrown' and segmentDistance(before,p.position,destination)<2.5 then
                        self:_impact(id)
                    elseif p.mode=='Heavy' then
                        if distance(p.position,destination)<.1 then
                            p.mode='Ground'; p.position=copy(destination); p.direction=nil; self:_render(id,p)
                        end
                    elseif p.mode=='Bullet' then
                        local hit=false
                        for _,slot in ipairs(self.session.order) do
                            local h=self.session.state.heroes[slot]; local combat=self.session.combat[slot]
                            if h.status=='Alive' and not combat.deathAt and segmentDistance(before,p.position,self.world:position(slot))<2.3 then
                                self.session:_hit(-99,slot,'Dash'); hit=true; break
                            end
                        end
                        if hit or distance(p.position,destination)<.1 then self:_remove(id) end
                    end
                end
            end
        end
    end
    return 'OK'
end

return GuardianPattern
