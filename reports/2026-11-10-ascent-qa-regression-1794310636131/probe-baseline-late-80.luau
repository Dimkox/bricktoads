-- Course-only reachability proof. Bots read state to plan and issue normal
-- move/jump inputs; Session owns real damage, reactions, shields and deaths.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
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
        if x~=nil then local length=math.sqrt(x*x+z*z);if length>1 then x,z=x/length,z/length end end
        if x~=nil then mode:move(1,x,z,false) end
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
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('./baseline-CampaignModes')
local Pilot=require('./baseline-policy')
local passed,failed=0,0
for _, index in ipairs({8,9,10,11,12}) do
    for _, seed in ipairs({1,41,8125,934247736}) do
        for _,cadence in ipairs({.08,.1,.133,.167}) do
            local d,s,m,step=fixture(Definition,Modes,index,seed)
            local count,nextPlan,lastJump,lastPrimary=0,0,-math.huge,-math.huge
            local ok,why=pcall(function()
                while not m.complete and count<10000 do
                    local now=count/60
                    if now+1e-7>=nextPlan then
                        nextPlan=now+cadence
                        local plan=Pilot.plan({modes=m,definition=d,slot=1,now=now,dt=cadence,stageToken=1})
                        assert(plan and plan.x*plan.x+plan.z*plan.z<=1.000001,'valid ordinary inputs required')
                        local jump=plan.jump
                        local primary=plan.primary and now-lastPrimary>=.13
                        if jump then lastJump=now end
                        if primary then lastPrimary=now end
                        step(plan.x,plan.z,jump,primary)
                    else step(nil,nil,false,false) end
                    count+=1
                end
                assert(m.complete,'late pilot stalled')
                assert(s.state.heroes[1].respawns==3,'late pilot spent respawn')
            end)
            if ok then passed+=1 else failed+=1 end
            local a=m.actors[1]
            print((ok and 'PASS' or 'FAIL')..' mode='..index..' seed='..seed..' cadence='..cadence..' frames='..count..' p='..a.position.x..','..a.position.y..','..a.position.z..' detail='..tostring(why))
        end
    end
end
print('RESULT pass='..passed..' fail='..failed)
assert(failed==0,'late coarse-cadence failures: '..failed)
