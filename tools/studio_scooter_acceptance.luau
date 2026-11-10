-- Test-only native acceptance. Install only in an owned saved-file helper.
-- Preparation selects stage 3; the pilot issues validated inputs only thereafter.
local Acceptance={}
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local function clamp(v,a,b)return math.clamp(v,a,b)end
local function sign(v)return v>0 and 1 or v<0 and -1 or 0 end
function Acceptance.install(hub)
    local b=Instance.new('BindableFunction');b.Name='BrickToadsScooterAcceptance';b.Parent=game.ServerStorage
    local serial=0;local fakes={};local pilot;local history={};local sequence={};local codes={}
    local function group()
        local player=assert(Players:GetPlayers()[1],'One real client is required')
        return assert(hub:selected(player)),player
    end
    local function state()
        local g=group();local c=g.controller;local s=c.current
        local heroes={};local enemies={}
        if s then
            for _,slot in ipairs(s.order)do local h=s.state.heroes[slot]
                heroes[#heroes+1]={slot=slot,actorId=h.actorId,attempt=h.attempt,status=h.status,
                    respawns=h.respawns,rawLife=s.combat[slot].rawLife,connected=h.connected,
                    position=c.world:position(slot),mode=c.world:movementMode(slot)}
            end
        end
        if c.director then for id,e in pairs(c.director.enemies)do
            enemies[#enemies+1]={id=id,kind=e.kind,actorId=e.actorId,rawLife=e.rawLife,
                dead=e.dead==true,engaged=e.engaged==true,owner=e.ownerUserId,position=c.world:position(id)}
        end end
        local offers={}
        if c.director then for _,o in ipairs(c.director:available(909999))do
            offers[#offers+1]={enemyId=o.enemyId,template=o.template,actorId=o.actorId}
        end end
        return {clock=workspace:GetServerTimeNow(),source=hub.deps.BuildId,campaignIndex=c.campaignIndex,
            state=s and s.state.status,levelEpoch=s and s.state.levelEpoch,runId=s and s.state.runId,
            stage=c.director and c.director.stage,heroes=heroes,enemies=enemies,offers=offers,faulted=c.faulted,
            modes=c.director and c.director.modes and c.director.modes:snapshot(),
            pilot=pilot and {active=pilot.active,phase=pilot.phase,elapsed=(pilot.endedAt or workspace:GetServerTimeNow())-pilot.started,
                result=pilot.result,fault=pilot.fault,seed=pilot.seed},codes=codes}
    end
    local function input(c,slot,kind,fields)
        local s=c.current;local h=s.state.heroes[slot];local p
        for user,owned in pairs(c.ownerSlots)do if owned==slot then p=c.players[user];break end end
        assert(p,'Missing owner')
        sequence[slot]=math.max(sequence[slot] or 0,s.lastSeq[slot] or 0)+1
        local packet={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=sequence[slot]}
        for k,v in pairs(fields or {})do packet[k]=v end
        local result=c:handle(p,packet,Players:GetPlayers())
        codes[result]=(codes[result]or 0)+1
        return result
    end
    local function prepare(args)
        if pilot then pilot.active=false end;pilot=nil
        local g,player=group();local c=g.controller
        c:_closeDirector('AcceptanceScenarioReplaced');c.current=nil;c.director=nil
        for _,p in ipairs(fakes)do hub:leave(p)end;fakes={}
        local owners={player};serial+=1
        for slot=2,args.count or 1 do
            local p={UserId=-900000-serial*10-slot,DisplayName='Native Pilot '..slot,
                Name='NativePilot'..slot,Parent=Players}
            assert(hub:join(p));fakes[#fakes+1]=p;owners[#owners+1]=p
        end
        for _,p in ipairs(owners)do c.preferences[p.UserId]='Hero';c.choices[p.UserId]='Mr. Green'end
        assert(c:_begin(player,owners)=='OK')
        c.campaignSeed=args.seed or 41
        c:_advanceCampaign(workspace:GetServerTimeNow());c:_advanceCampaign(workspace:GetServerTimeNow())
        sequence={};codes={};history={}
        return state()
    end
    local function lanePlan(course)
        local groups={}
        for _,h in ipairs(course.hazards)do if h.d<40 or h.kind=='Overhead'then
            local g=groups[#groups]
            if not g or h.x-g.lastX>40 then g={hazards={},lastX=h.x};groups[#groups+1]=g end
            g.hazards[#g.hazards+1]=h;g.lastX=h.x
        end end
        local lanes={-14,0,14};local costs={}
        for gi=#groups,1,-1 do costs[gi]={}
            for li,lane in ipairs(lanes)do
                local valid=true
                for _,h in ipairs(groups[gi].hazards)do if math.abs(lane-h.z)<=h.d/2+1.3 then valid=false end end
                if valid then local future=0
                    if costs[gi+1]then future=math.huge;for ni,nlane in ipairs(lanes)do
                        future=math.min(future,(costs[gi+1][ni]or math.huge)+math.abs(nlane-lane))
                    end end
                    costs[gi][li]=future
                end
            end
        end
        local previous=0
        for gi,g in ipairs(groups)do local best=math.huge
            for li,lane in ipairs(lanes)do local score=(costs[gi][li]or math.huge)+math.abs(lane-previous)
                if score<best then best=score;g.lane=lane end
            end
            assert(g.lane,'No planned lane');previous=g.lane
        end
        return groups
    end
    local function drive()
        local g=group();local c=g.controller;local s=c.current;local d=c.director
        assert(c.campaignIndex==3 and s.state.status=='Active','Prepare stage 3 first')
        pilot={active=true,phase='EntryCombat',started=workspace:GetServerTimeNow(),seed=c.campaignSeed,
            groups=lanePlan(d.definition.course),lastInput=0,initial=state(),lastRecord=0}
        return state()
    end
    local function record()
        if #history<500 then history[#history+1]=state()end
    end
    local connection=RunService.Heartbeat:Connect(function()
        if not pilot or not pilot.active then return end
        local ok,err=xpcall(function()
            local now=workspace:GetServerTimeNow();local g=group();local c=g.controller
            if c.campaignIndex==4 then
                pilot.active=false;pilot.endedAt=now;pilot.phase='NextStage';pilot.result='StageAdvanced';record();return
            end
            if c.faulted or c.current.state.status~='Active'then
                pilot.active=false;pilot.endedAt=now;pilot.result='Stopped';record();return
            end
            if now-pilot.started>55 then pilot.active=false;pilot.endedAt=now;pilot.result='Timeout';record();return end
            if now-pilot.lastRecord>=.25 then pilot.lastRecord=now;record()end
            if now-pilot.lastInput<.075 then return end;pilot.lastInput=now
            local s,d=c.current,c.director;local mode=d.modes;local course=d.definition.course
            local entry
            for id,e in pairs(d.enemies)do if not e.dead and not e.encounter then entry=id;break end end
            if entry then
                pilot.phase='EntryCombat'
                local p=c.world:position(1);local target=c.world:position(entry)
                local dx,dz=target.x-p.x,target.z-p.z;local distance=math.sqrt(dx*dx+dz*dz)
                if distance>3.2 then input(c,1,'Move',{x=dx/math.max(distance,1),z=dz/math.max(distance,1),run=false})
                else
                    input(c,1,'Move',{x=dx/math.max(distance,1)*.1,z=dz/math.max(distance,1)*.1,run=false})
                    input(c,1,'Attack',{attack='Punch'})
                end
                return
            end
            local allNear=true
            for _,slot in ipairs(s.order)do
                local a=mode.actors[slot];local p=c.world:position(slot)
                if not a.mounted and math.sqrt((p.x-course.mount.x)^2+(p.z-course.mount.z)^2)>4 then allNear=false end
            end
            for _,slot in ipairs(s.order)do
                local h=s.state.heroes[slot];local a=mode.actors[slot]
                if h.status=='Alive'and not s.combat[slot].deathAt then
                    if not a.mounted then
                        pilot.phase='Boarding';local p=c.world:position(slot)
                        local dx,dz=course.mount.x-p.x,course.mount.z-p.z;local distance=math.sqrt(dx*dx+dz*dz)
                        if distance>3.5 then input(c,slot,'Move',{x=dx/math.max(distance,1),z=dz/math.max(distance,1),run=false})
                        else input(c,slot,'Move',{x=0,z=0,run=false});if allNear then input(c,slot,'Attack',{attack='Punch'})end end
                    elseif not a.finished then
                        pilot.phase='Riding';local target=0
                        for _,g in ipairs(pilot.groups)do if a.position.x<=g.lastX+4 then target=g.lane;break end end
                        local jump=false
                        for _,hazard in ipairs(course.hazards)do local dx=hazard.x-a.position.x
                            if hazard.kind=='LowBarrier'and dx<=12 and dx>3 and a.grounded then jump=true end
                        end
                        for _,shot in pairs(d.campaignEnemies and d.campaignEnemies.projectiles or {})do
                            local p=shot.position
                            if p and shot.mode=='Obstacle'and p.x-a.position.x<16 and p.x-a.position.x>2 and a.grounded then jump=true end
                        end
                        if a.position.x>course.finishPoint.x-30 then target=0 end
                        input(c,slot,'Move',{x=0,z=clamp((target-a.position.z)*2,-1,1),run=false})
                        if jump then input(c,slot,'Jump')end
                    end
                end
            end
        end,debug.traceback)
        if not ok then pilot.active=false;pilot.endedAt=workspace:GetServerTimeNow();pilot.result='FixtureFault';pilot.fault=err end
    end)
    b.OnInvoke=function(op,args)
        if op=='prepare'then return prepare(args or {})
        elseif op=='menu'then
            if pilot then pilot.active=false end;pilot=nil
            local g=group();local c=g.controller;c:_closeDirector('AcceptanceScenarioReplaced')
            c.current=nil;c.director=nil;c.finished=false;c.world:clearActors()
            for _,p in ipairs(fakes)do hub:leave(p)end;fakes={};sequence={};codes={};history={}
            return state()
        elseif op=='stage'then
            local g=group();local c=g.controller;assert(c.current and c.campaignIndex==1,'Start normally from the UI first')
            c.campaignSeed=args and args.seed or 41
            c:_advanceCampaign(workspace:GetServerTimeNow());c:_advanceCampaign(workspace:GetServerTimeNow())
            return state()
        elseif op=='definition'then local g=group();return g.controller.deps.Config.Level
        elseif op=='drive'then return drive()
        elseif op=='state'then return state()
        elseif op=='history'then return {current=state(),history=history,initial=pilot and pilot.initial}
        elseif op=='input'then local g=group();return input(g.controller,args.slot,args.kind,args.fields)
        elseif op=='close'then if pilot then pilot.active=false end;connection:Disconnect();b:Destroy();return 'Closed'
        else error('Unknown acceptance operation')end
    end
end
return Acceptance
