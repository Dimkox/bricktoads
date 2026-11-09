-- Test-only pilots. Inputs are the only bot mutations; the world boundary
-- supplies ordinary flat-foot physics and Session owns all damage/resources.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
local DT=1/60
local jetPlan=require('./JetPlanner')
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function sign(v) return v>0 and 1 or v<0 and -1 or 0 end
local function fixture(Definition,Modes,index,seed)
    local d=Definition.build(index,seed);local w=FakeWorld.new();w.positions={};w.objects={};w.ordinary={}
    local mode
    function w:findSafe(id) return mode and mode:respawnPosition(id) or table.clone(d.spawn) end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held) local ok=spawn(self,id,actor,p,held);if ok then self.positions[id]=table.clone(p) end;return ok end
    function w:position(id) return self.positions[id] end
    function w:campaignPose(id,p) self.positions[id]=table.clone(p);self.ordinary[id]=nil end
    function w:campaignObject(id,kind,p,size,metadata) self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata} end
    function w:campaignRemove(id) self.objects[id]=nil end
    function w:campaignRelease() end
    function w:move(id,x,z,run)
        if mode and mode:move(id,x,z,run) then return end
        self.ordinary[id]={x=x,z=z,speed=run and 24 or 16}
    end
    function w:jump(id) if mode then mode:jump(id) end end
    function w:impulse(id,attacker,response)
        self.impulses+=1
        if mode then mode:impulse(id,{x=response.horizontal or 0,y=response.vertical or 0,z=0}) end
    end
    local cfg=GameConfig(Base,d)
    local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'course-driver-'..index..'-'..seed,w)
    s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK')
    mode=Modes.new(s,w,d)
    local now=0
    local function step(x,z,jump,primary)
        local length=math.sqrt(x*x+z*z);if length>1 then x,z=x/length,z/length end
        w:move(1,x,z,false);if jump then w:jump(1) end
        if primary then mode:interact(1,now,'Punch') end
        for id,input in pairs(w.ordinary) do local p=w.positions[id]
            p.x+=input.x*input.speed*DT;p.z+=input.z*input.speed*DT
        end
        now+=DT;assert(s:step(now)=='OK');mode:step(now,DT)
        local h=s.state.heroes[1];local a=mode.actors[1]
        local detail=''
        if h.status~='Alive' or s.combat[1].deathAt then
            for n=math.max(1,#s.logs-8),#s.logs do local row=s.logs[n];detail..=' '..row.kind..'@'..row.now..'/'..tostring(row.data and (row.data.kind or row.data.reason or row.data.ramp)) end
            for _,obstacle in ipairs(d.course.hazards) do if math.abs(obstacle.x-a.position.x)<15 then detail..=' hazard '..obstacle.kind..' x='..obstacle.x..' z='..obstacle.z end end
        end
        assert(h.status=='Alive' and h.attempt==1 and not s.combat[1].deathAt,
            'course '..index..' seed '..seed..' died at t='..now..' p='..a.position.x..','..a.position.y..','..a.position.z..' raw='..s.combat[1].rawLife..detail)
    end
    return d,s,mode,step
end
local function rope(Definition,Modes,seed)
    local _,s,m,step=fixture(Definition,Modes,2,seed)
    for _=1,3000 do
        if m.complete then return s end
        local a=m.actors[1]
        -- Reach the outer swing arc before the first wall trap; continuing
        -- descent changes the intercept of non-homing blaster projectiles.
        step(a.position.x<15 and 1 or 0,a.position.z<15 and 1 or 0,false,false)
    end
    error('Rope did not finish')
end
local function riding(Definition,Modes,index,seed)
    local d,s,m,step=fixture(Definition,Modes,index,seed)
    local groups={}
    for _,h in ipairs(d.course.hazards) do if h.d<40 or h.kind=='Overhead' then
        local g=groups[#groups]
        if not g or h.x-g.lastX>40 then g={hazards={},lastX=h.x};groups[#groups+1]=g end
        g.hazards[#g.hazards+1]=h;g.lastX=h.x
    end end
    local lanes={-14,0,14};local costs={}
    for gi=#groups,1,-1 do costs[gi]={}
        for li,lane in ipairs(lanes) do
            local valid=true;for _,h in ipairs(groups[gi].hazards) do if math.abs(lane-h.z)<=h.d/2+1.3 then valid=false end end
            if valid then local future=0
                if costs[gi+1] then future=math.huge;for ni,nlane in ipairs(lanes) do future=math.min(future,(costs[gi+1][ni] or math.huge)+math.abs(nlane-lane)) end end
                costs[gi][li]=future
            end
        end
    end
    local previous=0
    for gi,g in ipairs(groups) do local best=math.huge
        for li,lane in ipairs(lanes) do local score=(costs[gi][li] or math.huge)+math.abs(lane-previous)
            if score<best then best=score;g.lane=lane end
        end
        previous=g.lane or 0
    end
    local groupIndex=1;local jetInput=0;local jetCountdown=0
    for _=1,4000 do
        if m.complete then return s end
        local a=m.actors[1]
        if not a.mounted then step(1,0,false,true)
        elseif index==7 then
            if jetCountdown<=0 then jetInput=jetPlan(d,m,a);jetCountdown=6 end
            jetCountdown-=1;step(0,jetInput,false,false)
        else
            local nearest
            for _,h in ipairs(d.course.hazards) do local dx=h.x-a.position.x
                if dx>=-4 and dx<=65 then
                    nearest=nearest or h
                end
            end
            while groups[groupIndex] and a.position.x>groups[groupIndex].lastX+4 do groupIndex+=1 end
            local target=groups[groupIndex] and groups[groupIndex].lane or 0
            local jump=false
            if nearest and (nearest.kind=='LowBarrier' or nearest.kind=='Log') and nearest.x-a.position.x<=12
                and nearest.x-a.position.x>3 and a.grounded then jump=true end
            local steer=math.abs(target-a.position.z)>.2 and sign(target-a.position.z) or 0
            if a.position.x>d.course.finishPoint.x-30 then steer=clamp(-a.position.z*.8,-1,1) end
            step(0,steer,jump,false)
        end
    end
    error('Ride did not finish '..index..' seed '..seed)
end
local function clinger(Definition,Modes,seed)
    local d,s,m,step=fixture(Definition,Modes,11,seed)
    for _=1,5000 do
        if m.complete then return s end
        local path=d.course.path[m.actors[1].segment]
        step(path and path.direction.x or 0,path and path.direction.z or 0,false,false)
    end
    error('Clinger did not finish')
end
return function(Definition,Modes)
    local count=0
    for _,entry in ipairs({{'Rope',rope},{'Speeder',function(a,b,s) return riding(a,b,3,s) end},
        {'Surf',function(a,b,s) return riding(a,b,5,s) end},{'Clinger',clinger},{'Jet',function(a,b,s) return riding(a,b,7,s) end}}) do
        for _,seed in ipairs({1,41,8125}) do
            local session=entry[2](Definition,Modes,seed);count+=1
            assert(session.state.heroes[1].respawns==3)
            print('PASS normal-input '..entry[1]..' course seed '..seed..' rawLife '..session.combat[1].rawLife)
        end
    end
    return count
end
