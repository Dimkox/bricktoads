-- Normal spawn, real Session identities/intents and Modes fixed-step physics.
-- Only the Roblox presentation boundary is fake. A queued plan models the
-- measured request-to-Move delay; accepted movement is retained between packets.
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../../tests/stand/FakeWorld')
local Pilot=require('./early-candidate')
local DT=1/60
local function case(seed,cadence,lag,phase,lagStart)
    local d=Definition.build(6,seed)
    local w=FakeWorld.new();w.positions={};w.objects={};local modes
    function w:findSafe(id)return modes and modes:respawnPosition(id) or table.clone(d.spawn)end
    local spawn=w.spawn
    function w:spawn(id,actor,p,held)local ok=spawn(self,id,actor,p,held);if ok then self.positions[id]=table.clone(p)end;return ok end
    function w:position(id)return self.positions[id]end
    function w:observe(id)local p=self.positions[id];return {position=p and {p.x,p.y,p.z}}end
    function w:campaignPose(id,p)self.positions[id]=table.clone(p)end
    function w:campaignObject(id,kind,p,size,metadata)self.objects[id]={kind=kind,position=table.clone(p),size=size,metadata=metadata}end
    function w:campaignRemove(id)self.objects[id]=nil end
    function w:campaignRelease()end
    function w:move(id,x,z,run)if modes then modes:move(id,x,z,run)end end
    function w:jump(id)if modes then modes:jump(id)end end
    function w:impulse()self.impulses+=1 end
    local cfg=GameConfig(Base,d);local events={}
    local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'serpent-lag-'..seed,w,function(row)events[#events+1]=row end)
    s.sourceCombat=cfg.SourceCombat;assert(s:step(0)=='OK');modes=Modes.new(s,w,d)
    local now,nextPlan,seq=0,phase,0;local queue={};local room4Arrival,room4Edge,trace={},{},{}
    local targetRoom=lagStart==226 and 4 or 1
    local targetSupport='floor-'..(targetRoom*2-1)
    local targetX=(targetRoom-1)*80+9.1
    local settled=false
    local function send(kind,extra)
        local h=s.state.heroes[1];seq+=1
        local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
        for k,v in pairs(extra or{})do p[k]=v end
        s:intent(1,p,now)
    end
    for frame=1,12000 do
        local a=modes.actors[1]
        if now+1e-7>=nextPlan then
            local p=Pilot.plan({definition=d,modes=modes,actor=a,slot=1,now=now,dt=cadence,world=w,stageToken='lag'})
            local length=math.sqrt(p.x*p.x+p.z*p.z);if length>1 then p.x/=length;p.z/=length end
            queue[#queue+1]={at=now+(a.position.x>=(lagStart or -math.huge) and lag or 0),p=p}
            if a.position.x>225 and a.position.x<253 then trace[#trace+1]={at=now,x=a.position.x,y=a.position.y,vx=a.velocity.x,input=a.input.x,support=a.support,planned=p.x,jump=p.jump}end
            nextPlan=now+cadence
        end
        while queue[1] and queue[1].at<=now+1e-7 do
            local p=table.remove(queue,1).p
            send('Move',{x=p.x,z=p.z,run=p.run})
            if p.jump then send('Jump')end
        end
        if a.grounded and a.support=='floor-7' then
            if not room4Arrival.at then room4Arrival={at=now,x=a.position.x,y=a.position.y,vx=a.velocity.x,accepted=a.input.x}end
            room4Edge={at=now,x=a.position.x,y=a.position.y}
        end
        -- Bound this regression to approach braking. Boarding forecasts assume
        -- a prompt Jump and are verified by the existing whole-course probes;
        -- this case adds transport delay only until the entry staging point.
        if a.grounded and a.support==targetSupport and math.abs(a.position.x-targetX)<=.15
            and math.abs(a.input.x)<1e-6 then settled=true;break end
        now+=DT;s:step(now);modes:step(now,DT)
        if modes.complete or s.state.heroes[1].attempt~=1 or s.state.heroes[1].status~='Alive' or s.combat[1].deathAt then break end
    end
    local deaths=0;for _,e in ipairs(events)do if e.kind=='ConfirmedDeath'then deaths+=1 end end
    local h,a=s.state.heroes[1],modes.actors[1]
    local okay=settled and deaths==0 and h.attempt==1 and h.respawns==3 and s.combat[1].rawLife==47 and (targetRoom==1 or room4Arrival.at~=nil)
    print((okay and 'PASS' or 'FAIL')..' Serpents approach lag seed='..seed..' cadence='..cadence..' delay='..lag..' lagStart='..tostring(lagStart)..' phase='..phase..' time='..now..' room='..modes.room..' xyz='..a.position.x..','..a.position.y..','..a.position.z..' attempt='..h.attempt..' stock='..h.respawns..' deaths='..deaths)
    print(' ROOM4 arrival='..tostring(room4Arrival.at)..' x='..tostring(room4Arrival.x)..' vx='..tostring(room4Arrival.vx)..' lastGround='..tostring(room4Edge.x))
    if not okay and room4Arrival.at then for _,r in ipairs(trace)do print(' TRACE '..r.at..' xyz='..r.x..','..r.y..' vx='..r.vx..' accepted='..r.input..' planned='..r.planned..' jump='..tostring(r.jump)..' support='..tostring(r.support))end end
    return okay
end
local failed=0
for _,lagStart in ipairs({0,226})do for _,cadence in ipairs({.133,.15})do for _,phase in ipairs({0,.05})do
    if not case(1259618153,cadence,cadence,phase,lagStart)then failed+=1 end
end end end
assert(failed==0,tostring(failed)..' Serpents delayed-input failures')
