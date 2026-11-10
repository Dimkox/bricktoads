-- Real course/lifecycle inputs; fake only the Roblox actor presentation boundary.
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Pilot=require('./fixed-policy')
local DT=1/60
local function case(seed,cadence,cohort,delay,trace,outer,stagger,induce)
    outer=outer or DT;stagger=stagger or .021
    local d=Definition.build(4,seed);local w=FakeWorld.new();w.positions={};w.objects={};w.ordinary={}
    local modes
    function w:findSafe(id) if modes then return modes:respawnPosition(id) end;local p=table.clone(d.spawn);p.z=(id-(cohort+1)/2)*6;return p end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held)local ok=spawn(self,id,actor,p,held);if ok then self.positions[id]=table.clone(p)end;return ok end
    function w:position(id)return self.positions[id]end
    function w:observe(id)local a=modes and modes.actors[id];local p=a and a.position or self.positions[id];return {position=p and {p.x,p.y,p.z},modeTime=modes and modes.elapsed,phase=modes and modes.vehicleGroup and modes.vehicleGroup.phase}end
    function w:campaignPose(id,p)self.positions[id]=table.clone(p);self.ordinary[id]=nil end
    function w:campaignObject(id,kind,p,size,metadata)self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata}end
    function w:campaignRemove(id)self.objects[id]=nil end
    function w:campaignRelease()end
    function w:move(id,x,z,run)if modes and modes:move(id,x,z,run)then return end;self.ordinary[id]={x=x,z=z,speed=run and 24 or 16}end
    function w:jump(id)if modes then modes:jump(id)end end
    -- Course shots have synthetic attacker -9001 and no forced direction.
    -- Production falls back to Base, which ignores the anchored Modes body.
    -- The real Session reaction/reset still applies; do not invent a lift.
    function w:impulse()self.impulses+=1 end
    local cfg=GameConfig(Base,d);local roster={};for id=1,cohort do roster[#roster+1]={userId=id,template='Mr. Green'}end
    local events={}
    local s=Session.new(Core,Combat,cfg,roster,'surf-checkpoint-'..seed..'-'..cadence..'-'..delay,w,function(row)events[#events+1]=row end)
    s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK');modes=Modes.new(s,w,d)
    s.contextualAttack=function(slot,now,action)return modes:interact(slot,now,action)end
    local now=0;local seq,nextPlan,plans={},{},{}
    for slot=1,cohort do seq[slot]=0;nextPlan[slot]=delay+(slot-1)*stagger end
    local function send(slot,kind,extra)
        local h=s.state.heroes[slot];seq[slot]+=1
        local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq[slot]}
        for k,v in pairs(extra or{})do p[k]=v end
        s:intent(slot,p,now)
    end
    local samples={};local crossed={}
    for frame=1,math.ceil(120/outer) do
        for slot=1,cohort do
            local h=s.state.heroes[slot];local a=modes.actors[slot]
            if now+1e-7>=nextPlan[slot] and h.status=='Alive' and not s.combat[slot].deathAt and not a.finished then
                local p=Pilot.plan({definition=d,modes=modes,actor=a,slot=slot,now=now,dt=cadence,world=w,stageToken=1})
                local magnitude=math.sqrt(p.x*p.x+p.z*p.z);if magnitude>1 then p.x/=magnitude;p.z/=magnitude end
                -- Deliberately withhold one rider's ordinary Jump at the final
                -- Log, to exercise a genuine paid crash/rewind from CP3.
                if induce and slot==1 and modes.vehicleGroup.serial==0 and a.position.x>330 then p.jump=false end
                plans[slot]=p;send(slot,'Move',{x=p.x,z=p.z,run=p.run})
                if p.jump then send(slot,'Jump')end
                if p.primary then send(slot,'Attack',{attack='Punch'})end
                nextPlan[slot]=now+cadence
                if trace and a.position.x>275 then samples[#samples+1]={at=now,slot=slot,x=a.position.x,y=a.position.y,z=a.position.z,vy=a.velocity.y,jump=p.jump,steer=p.z,phase=modes.vehicleGroup.phase,speed=modes.vehicleGroup.speed,serial=modes.vehicleGroup.serial,shots=(function()local n=0;for _ in pairs(modes.projectiles)do n+=1 end;return n end)()}end
            end
        end
        for id,move in pairs(w.ordinary)do local p=w.positions[id];p.x+=move.x*move.speed*outer;p.z+=move.z*move.speed*outer end
        now+=outer;s:step(now);modes:step(now,outer)
        local finished=true;for slot=1,cohort do if not modes.actors[slot].finished and s.state.heroes[slot].status~='Eliminated'then finished=false end end
        for slot=1,cohort do local a=modes.actors[slot];if a.attempt==1 and a.position.x>=87 and a.position.y>=4.9 then crossed[slot]=true end end;local done=true;for slot=1,cohort do if not crossed[slot] then done=false end end;if done or s.state.status=='Lost' or #events>0 and events[#events].kind=='CampaignHazard' then break end
    end
    local deaths={}
    for _,e in ipairs(events)do if e.kind=='ConfirmedDeath'then deaths[#deaths+1]=e end end
    local allFinished=true;for slot=1,cohort do if not modes.actors[slot].finished then allFinished=false end end
    local expected=induce and 1 or 0
    local okay=#deaths==0;for slot=1,cohort do if not crossed[slot] then okay=false end end
    for slot=1,cohort do local h=s.state.heroes[slot]
        local spent=induce and slot==1 and 1 or 0
        if h.attempt~=1+spent or h.respawns~=3-spent then okay=false end
    end
    print((okay and'PASS'or'FAIL')..' Ice seed='..seed..' cadence='..cadence..' cohort='..cohort..' delay='..delay..' outer='..outer..' stagger='..stagger..' complete='..tostring(modes.complete)..' deaths='..#deaths..' elapsed='..now)
    for _,e in ipairs(deaths)do local p=e.data.observed.position;print(' DEATH slot='..e.userId..' t='..e.now..' reason='..e.data.reason..' xyz='..table.concat(p,','))end
    if trace then for _,a in ipairs(samples)do if a.x>328 and a.x<353 or a.serial>0 and a.x<300 then print(' TRACE t='..a.at..' slot='..a.slot..' xyz='..a.x..','..a.y..','..a.z..' vy='..a.vy..' jump='..tostring(a.jump)..' steer='..a.steer..' phase='..a.phase..' speed='..a.speed..' serial='..a.serial..' shots='..a.shots)end end end
    return okay
end
local failures=0
for _,outer in ipairs({1/60,.1})do for _,cadence in ipairs({.08,.133,.167})do for _,delay in ipairs({0,.5,1,1.5,2,2.5})do if not case(614217761,cadence,3,delay,false,outer,.021)then failures+=1 end end end end
assert(failures==0,tostring(failures)..' Ice first section failures')
