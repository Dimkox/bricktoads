-- Numeric world adapter only. Real Session/Modes/Director/family AI own all
-- attacks, resources, reactions, scripted motion, hazard deaths and completion.
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local Director=require('../../src/server/gameplay/CampaignDirector')
local Fake=require('../../tests/stand/FakeWorld')
local Late=require('../../tools/qa/campaign_late_course_pilot')
local deps={Director=require('../../src/server/gameplay/LevelDirector'),CampaignModes=require('../../src/server/gameplay/CampaignModes'),
    CampaignEnemies=require('../../src/server/gameplay/CampaignEnemies'),CampaignBoss=require('../../src/server/gameplay/CampaignBoss')}
local function length(x,z)return math.sqrt(x*x+z*z)end
local function direction(x,z)local n=length(x,z);return n>.001 and x/n or 1,n>.001 and z/n or 0 end
local function body(id,p)
    return {id=id,alive=true,root={Parent=true,Anchored=false,CFrame={LookVector={X=1,Z=0}},
        AssemblyLinearVelocity={X=0,Y=0,Z=0}},humanoid={Health=100,PlatformStand=false,FloorMaterial='Ground'}}
end
return function(policy,seed,cadence,limit,options)
    options=options or {}
    local def=Definition.build(9,seed);local cfg=GameConfig(Base,def)
    local w=Fake.new();w.positions={};w.commands={};w.groundSpeeds={};w.physical={};local modes
    function w:findSafe(id)return modes and modes:respawnPosition(id) or {x=def.spawn.x,y=def.spawn.y,z=6}end
    function w:spawn(id,actor,p,held)
        self.spawns+=1;self.positions[id]=table.clone(p);self.actors[id]=body(actor,p);return true
    end
    function w:spawnEnemy(id,kind,p)self.positions[id]=table.clone(p);self.actors[id]=body(kind,p);return true end
    function w:position(id)local a=self.actors[id];return a and a.alive and self.positions[id] or nil end
    function w:enemyIdentity()end
    function w:enemyHealth()end
    function w:stage()end
    function w:progress()end
    function w:reached()return false end
    function w:campaignObject()end
    function w:campaignRemove()end
    function w:projectile()end
    function w:removeProjectile()end
    function w:cue()end
    function w:campaignProjectileBlocked()return false end -- No occlusion is conservative for live NPC shots.
    function w:face(id,target)local p,q=self:position(id),self:position(target);if p and q then self:aim(id,q.x-p.x,q.z-p.z)end end
    function w:aim(id,x,z)local a=self.actors[id];if a and length(x,z)>.001 then local dx,dz=direction(x,z);a.root.CFrame.LookVector={X=dx,Z=dz}end end
    function w:targets(id,geometry)
        local p=self:position(id);if not p then return{}end
        local look=self.actors[id].root.CFrame.LookVector;local candidates={}
        for target,a in pairs(self.actors)do local q=self:position(target)
            if target~=id and q then
                local x,z=q.x-p.x,q.z-p.z;local forward=x*look.X+z*look.Z;local side=x*look.Z-z*look.X
                if forward>=0 and forward<=geometry.reach and math.abs(side)<=geometry.width and math.abs(q.y-p.y)<=geometry.height then
                    candidates[#candidates+1]={id=target,d=(x*x+z*z+(q.y-p.y)^2)}
                end
            end
        end
        table.sort(candidates,function(a,b)return a.d<b.d or a.d==b.d and a.id<b.id end)
        local ids={};for _,a in ipairs(candidates)do ids[#ids+1]=a.id end;return ids
    end
    function w:campaignPose(id,p,mode,velocity)
        self.positions[id]=table.clone(p);local a=self.actors[id];a.campaignControl=mode;a.root.Anchored=true
        if velocity then self:aim(id,velocity.x or 0,velocity.z or 0)end
    end
    function w:campaignRelease(id)local a=self.actors[id];if a then a.campaignControl=nil;a.root.Anchored=false end end
    function w:placeActor(id,p)self.positions[id]=table.clone(p)end
    function w:campaignWalkSpeed(id,speed)self.groundSpeeds[id]=speed end
    function w:move(id,x,z,run)
        if modes and modes:move(id,x,z,run)then return end
        self.commands[id]={x=x,z=z,speed=self.groundSpeeds[id]or(run and 24 or 16)}
    end
    function w:enemyMove(id,target,speed)local p,q=self:position(id),self:position(target);if p and q then
        local x,z=direction(q.x-p.x,q.z-p.z);self.commands[id]={x=x,z=z,speed=speed};self:aim(id,x,z)
    end end
    function w:jump(id)if modes then modes:jump(id)end end
    function w:setReaction(id,active)local a=self.actors[id];if a then a.humanoid.PlatformStand=active end end
    function w:impulse(id,attacker,tuning,profile,accepted)
        local p,q=self:position(id),self:position(attacker);if not p or (not q and not accepted) then return end
        local x,z=accepted and accepted.x or p.x-(q and q.x or p.x-1),accepted and accepted.z or p.z-(q and q.z or p.z)
        x,z=direction(x,z)
        local v={x=x*(tuning.horizontal or 0),y=tuning.vertical or 0,z=z*(tuning.horizontal or 0)}
        if modes and modes:impulse(id,v)then return end
        self.physical[id]=v
    end
    function w:hazard(id)local p=self:position(id);if p and p.y<cfg.FallY then return'Fall'end end
    local counts={};local events={}
    local s=Session.new(Core,Combat,cfg,{{userId=3,template='Mr. Brown'}},'tubes-ai-'..seed..'-'..cadence,w,function(event)
        counts[event.kind]=(counts[event.kind]or 0)+1;events[#events+1]=event
    end)
    assert(s:step(0)=='OK');local d=Director.new(s,w,Combat,cfg,deps);modes=d.modes
    local hit=s._hit;s._hit=function(self,a,target,action,tuning)if target<0 then return d:hit(a,target,action,tuning)end;return hit(self,a,target,action,tuning)end
    s.contextualAttack=function(slot,now,action)return d:interact(slot,now,action)end
    require('../../src/server/gameplay/SourceCombat').bind(s,d,cfg)
    local firstActorId=s.state.heroes[3].actorId
    local now,seq,nextInput,lastPrimary=0,0,0,-100;local lastPlan;local samples={};local nextSample=0
    local queue={}
    local function send(kind,extra)
        local h=s.state.heroes[3];seq+=1
        local packet={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,
            connectionEpoch=h.connectionEpoch,seq=seq};for k,v in pairs(extra or{})do packet[k]=v end
        queue[#queue+1]={at=now+(options.packetDelay or 0),packet=packet}
        return "QUEUED"
    end
    for _=1,math.ceil((limit or 120)*60)do
        local h=s.state.heroes[3]
        if now>=nextInput and h.status=='Alive'and not s.combat[3].deathAt and not d.result then
            local a=modes.actors[3];local ctx={session=s,director=d,world=w,modes=modes,definition=def,actor=a,
                slot=3,now=now,dt=cadence,stageToken=s.state.runId,position=w:position(3)}
            local route=Late.plan(ctx)or{x=0,z=0};lastPlan=policy and policy.plan(ctx,route)or route
            send('Move',{x=lastPlan.x or 0,z=lastPlan.z or 0,run=lastPlan.run==true})
            if lastPlan.jump then send('Jump')end
            if lastPlan.primary and now-lastPrimary>=.13 then lastPrimary=now;send('Attack',{attack='Punch'})end
            nextInput=now+cadence-1e-7
        end
        while queue[1] and queue[1].at<=now+1e-7 do
            local item=table.remove(queue,1);s:intent(3,item.packet,now)
        end
        for id,a in pairs(w.actors)do
            if id<0 and a.alive and not a.campaignControl then
                local p=w.positions[id];local previous=p.y;local c=w.commands[id]or{x=0,z=0,speed=0};local v=w.physical[id]or{x=0,y=0,z=0}
                p.x+=((not a.humanoid.PlatformStand and c.x*c.speed or 0)+v.x)/60
                p.z+=((not a.humanoid.PlatformStand and c.z*c.speed or 0)+v.z)/60
                v.y-=150/60;p.y+=v.y/60;v.x*=math.exp(-3/60);v.z*=math.exp(-3/60)
                local top
                for _,f in ipairs(def.course.platforms)do local y=f.y+f.h/2+3
                    if p.x>=f.x-f.w/2 and p.x<=f.x+f.w/2 and p.z>=f.z-f.d/2 and p.z<=f.z+f.d/2
                        and previous>=y-.4 and p.y<=y+.12 and(not top or y>top)then top=y end
                end
                if top then p.y=top;v.y=0 end;w.physical[id]=v
            end
        end
        now+=1/60;assert(s:step(now)=='OK');d:step(now,1/60)
        if now>=nextSample then
            local a=modes.actors[3];local enemies={}
            for id,e in pairs(d.enemies)do enemies[#enemies+1]={id=id,kind=e.kind,dead=e.dead,rawLife=e.rawLife,
                position=w:position(id)and table.clone(w:position(id)),mode=d.campaignEnemies.states[id] and d.campaignEnemies.states[id].mode}end
            samples[#samples+1]={at=now,position=w:position(3)and table.clone(w:position(3)),rawLife=s.combat[3].rawLife,
                plan=lastPlan,medium=a and a.medium,oxygen=a and a.oxygen,attack=s.combat[3].attack,enemies=enemies}
            nextSample=now+.25
        end
        if d.result or s.state.status=='Lost' or (options.firstBody and (s.combat[3].deathAt or s.state.heroes[3].actorId~=firstActorId)) then return{result=d.result or (options.firstBody and 'FirstBodyEnded') or s.state.status,elapsed=now,
            hero=table.clone(s.state.heroes[3]),rawLife=s.combat[3].rawLife,position=w:position(3),
            counts=counts,events=events,plan=lastPlan,enemies=d.enemies,samples=samples}end
    end
    return{result='Timeout',elapsed=now,hero=table.clone(s.state.heroes[3]),rawLife=s.combat[3].rawLife,
        position=w:position(3),counts=counts,events=events,plan=lastPlan,enemies=d.enemies,samples=samples}
end
