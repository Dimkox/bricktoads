-- Course-only reachability proof. Bots read state to plan and issue normal
-- move/jump inputs; Session owns real damage, reactions, shields and deaths.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
local DT=1/60
local function sign(v) return v>0 and 1 or v<0 and -1 or 0 end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function fixture(Definition,Modes,index,seed)
    local d=Definition.build(index,seed)
    local w=FakeWorld.new();w.positions={};w.objects={}
    local mode
    function w:findSafe(id) return mode and mode:respawnPosition(id) or table.clone(d.spawn) end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held)
        local ok=spawn(self,id,actor,p,held)
        if ok then self.positions[id]=table.clone(p) end
        return ok
    end
    function w:position(id) return self.positions[id] end
    function w:campaignPose(id,p) self.positions[id]=table.clone(p) end
    function w:campaignObject(id,kind,p,size,metadata) self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata} end
    function w:campaignRemove(id) self.objects[id]=nil end
    function w:campaignRelease() end
    function w:spawnEnemy(id,kind,p) self.actors[id]={id=id,kind=kind,alive=true};self.positions[id]=table.clone(p);return true end
    function w:enemyIdentity() end
    local cfg=GameConfig(Base,d)
    local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'platform-driver-'..index..'-'..seed,w)
    s.sourceCombat=cfg.SourceCombat
    assert(s:step(0)=='OK')
    mode=Modes.new(s,w,d)
    local now=0
    local function step(x,z,jump,interact)
        local length=math.sqrt(x*x+z*z);if length>1 then x,z=x/length,z/length end
        mode:move(1,x,z,false)
        if jump then mode:jump(1) end
        if interact then mode:interact(1,now,'Punch') end
        now+=DT
        assert(s:step(now)=='OK','Session closed unexpectedly')
        mode:step(now,DT)
        assert(s.state.heroes[1].attempt==1 and s.state.heroes[1].status=='Alive' and not s.combat[1].deathAt,
            'course death: '..tostring(index)..' seed '..seed..' at '..now..' x='..mode.actors[1].position.x..' y='..mode.actors[1].position.y..' z='..mode.actors[1].position.z..' raw='..s.combat[1].rawLife)
    end
    return d,s,mode,step
end
local function ice(Definition,Modes,seed)
    local d,s,m,step=fixture(Definition,Modes,4,seed)
    local hazardIndex=1;local planned=0;local targetZ=0
    for _=1,6000 do
        if m.complete then return s,m end
        local a=m.actors[1];local jump=false
        local h=d.course.hazards[hazardIndex]
        if h and a.position.x>h.x+7 then hazardIndex+=1;h=d.course.hazards[hazardIndex] end
        if not h then targetZ=0 end
        if h and planned~=hazardIndex and h.x-a.position.x<58 then
            local at=m.elapsed+(h.x-a.position.x)/math.max(18,a.velocity.x)
            local z=h.z
            if h.motion and h.motion.axis=='z' then z+=math.sin(at/h.motion.period*math.pi*2+h.motion.phase)*h.motion.amplitude end
            targetZ=z< -5 and 0 or -10;planned=hazardIndex
        end
        if a.grounded and a.support then
            local n=tonumber(string.match(a.support,'^floor%-(%d+)$'))
            if n and n<#d.course.platforms then local p=d.course.platforms[n]
                jump=p.x+p.w/2-a.position.x<4.7
            end
        end
        local steer=clamp((targetZ-a.position.z)*.6-a.velocity.z*.5,-1,1)
        step(1,steer,jump)
    end
    error('Ice did not finish seed '..seed..' at x='..m.actors[1].position.x)
end
local function ascent(Definition,Modes,seed)
    local _,s,m,step=fixture(Definition,Modes,8,seed)
    for _=1,6000 do
        if m.complete then return s,m end
        local a=m.actors[1];local zError=-5-a.position.z
        local iz=math.abs(zError)>.15 and sign(zError) or 0
        local ix=a.position.y>95 and (a.position.x>-7.8 and -1 or 0) or 0
        step(ix,iz,a.grounded and a.position.y<98)
    end
    error('Ascent did not finish seed '..seed..' at y='..m.actors[1].position.y)
end
local function tower(Definition,Modes,seed)
    local d,s,m,step=fixture(Definition,Modes,12,seed)
    for _=1,10000 do
        if m.complete then return s,m end
        local a=m.actors[1];local radius=math.sqrt(a.position.x^2+a.position.z^2)
        local wind=math.sin(m.elapsed*.8+(d.course.windPhase or 0))*d.course.windForce
        local radial=clamp((23-radius)*1.7-wind/8,-1,1)
        step(1,radial,a.grounded)
    end
    error('Tower did not finish seed '..seed..' at y='..m.actors[1].position.y)
end
local function tubes(Definition,Modes,seed)
    local d,s,m,step=fixture(Definition,Modes,9,seed)
    local hazardIndex=1;local passing=false
    for _=1,8000 do
        if m.complete then return s,m end
        local a=m.actors[1];local hazard=d.course.hazards[hazardIndex]
        if hazard and a.position.x>hazard.x+8 then hazardIndex+=1;hazard=d.course.hazards[hazardIndex];passing=false end
        local desired=15
        if hazard and hazard.z==0 and not passing and hazard.x-a.position.x<32 then
            local phase=(m.elapsed/hazard.motion.period*math.pi*2+hazard.motion.phase)%(math.pi*2)
            local distance=hazard.x-12-a.position.x
            desired=clamp(distance*2,-6,15)
            if math.abs(distance)<1.2 and math.abs(a.velocity.x)<3 and phase>2.9 and phase<3.2 then passing=true;desired=15 end
        end
        local x,z
        if a.medium=='Water' then
            local current={x=0,y=0}
            for _,water in ipairs(d.course.media) do
                if a.position.x>=water.minX and a.position.x<=water.maxX then current=water.current or current;break end
            end
            x=clamp((desired*1.4-(current.x or 0))/28+(desired-a.velocity.x)*.2,-1,1)
            z=clamp((a.position.y-3)*.4+a.velocity.y*.3+(3+(current.y or 0))/28,-1,1)
        else x=desired/16;z=0 end
        step(x,z,false)
    end
    error('Tubes did not finish seed '..seed..' at x='..m.actors[1].position.x)
end
local function race(Definition,Modes,seed)
    local d,s,m,step=fixture(Definition,Modes,10,seed)
    local stage='Align';local takeoffY=d.spawn.y;local lastBomb=1
    for _=1,8000 do
        if m.complete then return s,m end
        local a=m.actors[1];local bomb=d.course.bombs[m.bombIndex]
        if not bomb then step(0,0,false);continue end
        if m.bombIndex~=lastBomb then stage='Align';lastBomb=m.bombIndex;takeoffY=a.position.y end
        local dx=bomb.position.x-a.position.x;local ix=clamp(dx*.5,-1,1);local iz=0;local action=false
        if stage=='Align' then
            iz=clamp(-a.position.z*.5,-1,1)
            if math.abs(dx)<.3 and a.grounded then stage='Out' end
        elseif stage=='Out' then
            ix=0
            if a.grounded then takeoffY=a.position.y end
            iz=1
            if a.position.z>=15.7 then stage='In' end
            if a.grounded and a.position.y<=bomb.position.y+.1 then stage='Defuse' end
        elseif stage=='In' then
            ix=0
            iz=-1
            if a.grounded and a.position.y<takeoffY-.5 then
                stage=a.position.y<=bomb.position.y+.1 and 'Defuse' or 'Out'
            end
        else
            iz=clamp(-a.position.z*.5,-1,1)
            action=m:interaction(1).available
        end
        step(ix,iz,false,action)
    end
    error('Race did not finish seed '..seed..' at y='..m.actors[1].position.y..' bomb '..m.bombIndex..' stage '..stage)
end
return function(Definition,Modes)
    local count=0
    for _,entry in ipairs({{'Ascent',ascent},{'Tower',tower},{'Ice',ice},{'Tubes',tubes},{'Race',race}}) do
        for _,seed in ipairs({1,41,8125}) do
            local session=entry[2](Definition,Modes,seed);count+=1
            assert(session.state.heroes[1].respawns==3,'course driver must not spend a respawn')
            print('PASS normal-input '..entry[1]..' course seed '..seed..' rawLife '..session.combat[1].rawLife)
        end
    end
    return count
end
