-- Disposable Studio instrumentation. Plans read runtime state and return only
-- ordinary input; the connected client uses its existing production sender.
assert(game:GetService('RunService'):IsStudio(),'Studio QA only')
local Players=game:GetService('Players')
local Storage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Early=require(script.Parent.campaign_early_course_pilot)
local Late=require(script.Parent.campaign_late_course_pilot)
local Combat=require(script.Parent.campaign_combat_pilot)
local Nav=require(script.Parent.route_navigation)
while not _G.BrickToadsFullCampaignHub do task.wait() end
local hub=_G.BrickToadsFullCampaignHub
local folder=Storage:FindFirstChild('BrickToadsFullCampaignQA') or Instance.new('Folder');folder.Name='BrickToadsFullCampaignQA';folder.Parent=Storage
local remote=folder:FindFirstChild('Plan') or Instance.new('RemoteFunction');remote.Name='Plan';remote.Parent=folder
local qa=_G.BrickToadsFullCampaignQA or {running=true,started=workspace:GetServerTimeNow(),stages={},samples={},last={},plans={},errors={},source='input-only client pilot'}
qa.policyLoads=(qa.policyLoads or 0)+1
_G.BrickToadsFullCampaignQA=qa
local argsOK,testArgs=pcall(function() return game:GetService('StudioTestService'):GetTestArgs() end)
testArgs=argsOK and type(testArgs)=='table' and testArgs or {}
qa.expectedPlayers=testArgs.expectedPlayers or 1
qa.registeredPlayers={}
for _,p in ipairs(Players:GetPlayers()) do qa.registeredPlayers[#qa.registeredPlayers+1]={name=p.Name,userId=p.UserId} end
qa.events=qa.events or {};qa.eventCounts=qa.eventCounts or {};qa.seenSeq=qa.seenSeq or 0
qa.decisionAt=qa.decisionAt or {}
local observerAt=0
local retained={CampaignStageStarted=true,CampaignStageCompleted=true,RunResult=true,CommitSpawn=true,
    Death=true,ConfirmedDeath=true,Eliminate=true,EnemyDeath=true,BossHit=true,GuardianBallThrown=true,FlyCaught=true,
    CampaignGroupStopped=true,CampaignGroupRewound=true,CampaignBombDefused=true,
    CampaignBossHit=true,CampaignBossAttack=true,CampaignBossDefeated=true,DragonFlightBlocked=true}
RunService.Heartbeat:Connect(function()
    local at=workspace:GetServerTimeNow();if at-observerAt<.25 then return end;observerAt=at
    local p=Players:GetPlayers()[1];local g=p and hub:selected(p);local c=g and g.controller
    if #qa.registeredPlayers~=#Players:GetPlayers() then
        qa.registeredPlayers={};for _,row in ipairs(Players:GetPlayers()) do qa.registeredPlayers[#qa.registeredPlayers+1]={name=row.Name,userId=row.UserId} end
    end
    if not c or not c.journal then return end
    qa.build=c.journal.context.build
    for _,e in ipairs(c.journal:snapshot().events) do
        if e.seq>qa.seenSeq then
            local epoch=tostring(e.levelEpoch or 0);local counts=qa.eventCounts[epoch] or {};qa.eventCounts[epoch]=counts
            counts[e.kind]=(counts[e.kind] or 0)+1
            if retained[e.kind] then qa.events[#qa.events+1]=e end
            qa.seenSeq=e.seq
        end
    end
end)
local read=game.ServerStorage:FindFirstChild('BrickToadsFullCampaignRead') or Instance.new('BindableFunction')
read.Name='BrickToadsFullCampaignRead';read.Parent=game.ServerStorage
local function cohortFor(c)
    local rows={}
    if c and c.current then for id,member in pairs(c.current.state.heroes) do rows[#rows+1]={slot=id,
        actorId=member.actorId,status=member.status,attempt=member.attempt,stock=member.respawns,
        rawLife=c.current.combat[id].rawLife,ownerUserId=c.owners[id] and c.owners[id].userId} end end
    return rows
end
read.OnInvoke=function(kind)
    local player=Players:GetPlayers()[1];local selected=player and hub:selected(player)
    if selected then qa.cohort=cohortFor(selected.controller) end
    local out={running=qa.running,current=qa.current,errors=qa.errors,result=qa.result,stages=qa.stages,
        navigation=qa.navigation,sampleCount=#qa.samples,policyLoads=qa.policyLoads,registeredPlayers=qa.registeredPlayers,
        expectedPlayers=qa.expectedPlayers,cohort=qa.cohort,build=qa.build,seed=qa.seed}
    if kind=='samples' then out.samples=qa.samples;out.events=qa.events;out.eventCounts=qa.eventCounts;out.jumpProbes=qa.jumpProbes end
    if kind=='archive' then
        out.samples={};out.events=qa.events;out.eventCounts=qa.eventCounts;out.jumpProbes=qa.jumpProbes
        out.sampleSelection='Every fifth one-second observation, all stage/boss-phase/attempt/stock transitions, and final30 observations'
        local previous
        for i,row in ipairs(qa.samples) do
            local signature=table.concat({tostring(row.index),tostring(row.boss and row.boss.bossPhase),
                tostring(row.attempt),tostring(row.stock)},':')
            if i%5==1 or signature~=previous or i>#qa.samples-30 then out.samples[#out.samples+1]=row end
            previous=signature
        end
    end
    if kind=='motion' then out.motion=qa.motion end
    if kind=='detail' then
        local p=Players:GetPlayers()[1];local g=p and hub:selected(p);local c=g and g.controller
        if c and c.current and c.director then
            local slot=c.ownerSlots[p.UserId];local a=g.world.actors[slot];out.groupId=g.id
            out.hero=c.current.state.heroes[slot];out.combat=c.current.combat[slot]
            out.notice=c.notices[p];out.outerNotice=hub.notices[p];out.enemies={}
            for id,e in pairs(c.director.enemies) do out.enemies[tostring(id)]={kind=e.kind,dead=e.dead,
                rawLife=e.rawLife,hearts=e.hearts,position=g.world:position(id),owner=e.ownerUserId} end
            if a then out.body={state=tostring(a.humanoid:GetState()),floor=tostring(a.humanoid.FloorMaterial),
                anchored=a.root.Anchored,platformStand=a.humanoid.PlatformStand,velocityY=a.root.AssemblyLinearVelocity.Y} end
            out.journal=c.journal and c.journal:snapshot()
            local modes=c.director.modes;local actor=modes and modes.actors[slot]
            if actor then out.modeActor={position=actor.position,velocity=actor.velocity,grounded=actor.grounded,
                progress=actor.progress,finished=actor.finished,mounted=actor.mounted,medium=actor.medium,
                room=modes.room,complete=modes.complete,mode=modes.mode} end
        end
    end
    return game.HttpService:JSONEncode(out)
end
local function point(x,y,z) return {x=x,y=y,z=z} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
local function neutral() return {x=0,z=0,jump=false,primary=false,run=false} end
local function normalize(p)
    p=p or neutral();local x,z=p.x or 0,p.z or 0;local n=math.sqrt(x*x+z*z)
    if n>1 then x,z=x/n,z/n end
    return {x=x,z=z,jump=p.jump==true,primary=p.primary==true,run=p.run==true,aimX=p.aimX,aimZ=p.aimZ}
end
local function floorRows(world)
    local rows={}
    for _,p in ipairs(world.floors or {}) do
        if p.Parent and p.CanCollide and p:GetAttribute('SurfaceId') then
            local q=p.Position-world.offset
            rows[#rows+1]={part=p,minX=q.X-p.Size.X/2,maxX=q.X+p.Size.X/2,
                minZ=q.Z-p.Size.Z/2,maxZ=q.Z+p.Size.Z/2,top=q.Y+p.Size.Y/2}
        end
    end
    table.sort(rows,function(a,b) return a.minX<b.minX end);return rows
end
local function foot(ctx,desired,combatPlan)
    local p=ctx.position;local a=ctx.world.actors[ctx.slot]
    if not p or not a then return neutral() end
    if ctx.modes and ctx.actor and ctx.actor.finished then
        local dx,dz=desired.x-p.x,desired.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
        local out=combatPlan or neutral()
        if not combatPlan then out.x,out.z=n>.7 and dx/math.max(n,1) or 0,n>.7 and dz/math.max(n,1) or 0 end
        return out
    end
    local planKey=ctx.stageToken..':'..tostring(ctx.slot)
    local state=qa.plans[planKey]
    local hero=ctx.session.state.heroes[ctx.slot]
    if not state or state.actorId~=hero.actorId then state={actorId=hero.actorId};qa.plans[planKey]=state end
    local v=a.root.AssemblyLinearVelocity
    local floors=floorRows(ctx.world)
    local support=Nav.currentFloor(p,floors,state.previousFloor)
    local beyondSupport=support and (desired.x<support.minX or desired.x>support.maxX
        or desired.z<support.minZ or desired.z>support.maxZ)
    local combat=ctx.session.combat[ctx.slot]
    local requested=a.locomotion and a.locomotion.runRequested
    local actualSpeed=math.sqrt(v.X*v.X+v.Z*v.Z)
    local canLaunch=a.humanoid.FloorMaterial~=Enum.Material.Air and not a.humanoid.PlatformStand
        and not combat.reactionEnd and not combat.deathAt and requested and actualSpeed>=18
    local nav=Nav.plan(p,desired,floors,state,ctx.now,{grounded=canLaunch,
        vy=v.Y,allowCrossing=true,jumpLead=3.2})
    if nav.phase=='No support' then
        local closest,best
        for _,f in ipairs(floors) do
            local x=math.clamp(p.x,f.minX,f.maxX);local z=math.clamp(p.z,f.minZ,f.maxZ)
            local gap=distance(p,{x=x,z=z})
            if gap<=3 and p.y>=f.top-2 and p.y<=f.top+4 and (not best or gap<best) then closest,best=f,gap end
        end
        if closest then
            nav.target=point(math.clamp(p.x,closest.minX+3,closest.maxX-3),closest.top+3,
                math.clamp(p.z,closest.minZ+3,closest.maxZ-3))
            nav.phase='Recover edge with ordinary input';nav.crossing=true;nav.jump=true
        end
    end
    local out=combatPlan or neutral();local target=nav.target
    -- Adjoining supports need route movement even without a gap. Preserve an
    -- accepted attack or an actual retreat/sidestep from the combat policy.
    local approachNextSupport=beyondSupport and not (combatPlan and (out.primary or out.evasion or out.hold or combat and combat.attack))
    if nav.crossing or nav.attackAllowed~=true or not combatPlan or approachNextSupport then
        local dx,dz=target.x-p.x,target.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
        out.x,out.z=n>.15 and dx/math.max(n,1) or 0,n>.15 and dz/math.max(n,1) or 0
    end
    if nav.attackAllowed~=true then out.primary=false;out.run=false end
    if nav.crossing then out.jump=nav.jump==true;out.run=true else out.jump=out.jump or nav.jump==true end
    qa.navigation={phase=nav.phase,target=target,fault=nav.fault}
    return out
end
local function plan(player)
    local group=hub:selected(player);if not group then return {sync=true} end
    local c,world=group.controller,group.world;local s,d=c.current,c.director
    if not s then
        local ready=0;for _,p in ipairs(Players:GetPlayers()) do if hub:selected(p)==group then ready+=1 end end
        if ready<qa.expectedPlayers then return {plan=neutral(),status='Awaiting full test cohort'} end
        return {start=true,groupId=group.id}
    end
    local slot=c.ownerSlots[player.UserId];local h=slot and s.state.heroes[slot]
    if c.faulted or c.finished or s.state.status~='Active' then
        qa.result=c.faulted and 'Faulted' or d and d.result or s.state.status
        qa.running=false
        if testArgs.endWhenDone and not qa.ending then
            qa.ending=true;task.delay(.5,function() game:GetService('StudioTestService'):EndTest(read:Invoke('archive')) end)
        end
        return {done=true,result=qa.result}
    end
    if not h or h.status~='Alive' then return {plan=neutral(),status=h and h.status or 'Spectator'} end
    local at=workspace:GetServerTimeNow();local index=c.campaignIndex or 1
    qa.seed=c.campaignSeed
    qa.cohort=cohortFor(c)
    local key=s.state.runId..':'..s.state.levelEpoch
    local leadSlot
    for id,member in pairs(s.state.heroes) do
        if member.status~='Eliminated' and member.connected and (not leadSlot or id<leadSlot) then leadSlot=id end
    end
    local finishLead
    local liveModes=d and d.modes
    for id,member in pairs(s.state.heroes) do
        local actor=liveModes and liveModes.actors[id]
        if actor and actor.finished and member.status=='Alive' and member.connected and not s.combat[id].deathAt
            and (not finishLead or id<finishLead) then finishLead=id end
    end
    leadSlot=finishLead or leadSlot
    qa.leadSlot=leadSlot
    if qa.last.key~=key then
        qa.stages[#qa.stages+1]={index=index,epoch=s.state.levelEpoch,runId=s.state.runId,at=at,
            actorId=h.actorId,attempt=h.attempt,stock=h.respawns,rawLife=s.combat[slot].rawLife,
            cohort=qa.cohort,source=group.controller.deps.Config.Level.id}
        qa.last={key=key,sampleAt=0}
    end
    local modes=d and d.modes;local a=modes and modes.actors[slot]
    local decisionKey=key..':'..tostring(slot)..':'..h.actorId
    local decisionDt=math.clamp(at-(qa.decisionAt[decisionKey] or at-.1),1/120,.25)
    qa.decisionAt[decisionKey]=at
    local ctx={controller=c,session=s,director=d,world=world,modes=modes,definition=c.deps.Config.Level,
        slot=slot,now=at,dt=decisionDt,stageToken=key,actor=a,position=world:position(slot)}
    if not ctx.position then return {plan=neutral(),status='Missing body'} end
    if index==1 and slot~=leadSlot then return {plan=neutral(),index=index,status='QA teammate waiting behind fighter'} end
    local targetId,targetPosition=Combat.target(ctx);local combatPlan=targetId and slot==leadSlot and Combat.plan(ctx) or nil
    local output
    if index==1 then
        local zone=ctx.definition.zones[d.zoneIndex]
        local box=(d.stage=='Exit' and ctx.definition.boss.exit) or (zone and zone.exit)
        local desired=targetPosition or (box and point((box.minX+box.maxX)/2,ctx.position.y,(box.minZ+box.maxZ)/2))
            or ctx.definition.boss.position
        output=foot(ctx,desired,combatPlan)
    elseif a and a.finished then
        output=slot==leadSlot and foot(ctx,targetPosition or ctx.definition.boss.position,combatPlan) or neutral()
    elseif ctx.definition.course.mount and a and not a.mounted and not d:_boardingCleared() then
        output=combatPlan or neutral()
    else
        output=(index<=7 and Early.plan(ctx) or Late.plan(ctx)) or neutral()
        if modes.mode=='Rope' and slot~=leadSlot then
            local x=slot==2 and 0 or -15;local z=slot==2 and -15 or 15
            output={x=math.clamp((x-a.position.x)*.8,-1,1),z=math.clamp((z-a.position.z)*.8,-1,1),run=false}
        end
        -- These courses permit evasion to the exit. Keep their ordinary
        -- movement policy active while roster AI continues acting normally.
    end
    output=normalize(output)
    if modes and modes.mode=='Race' and slot~=leadSlot then output.primary=false end
    if output.primary and combatPlan and type(targetId)=='number' and not d.guardian then
        local body=world.actors[slot]
        local carrying=d.carry and d.carry.holders and d.carry.holders[slot]
        if body and not carrying then
            for other,member in pairs(s.state.heroes) do
                local ally=other~=slot and member.status=='Alive' and world.actors[other]
                if ally then
                    local q=body.root.CFrame:PointToObjectSpace(ally.root.Position)
                    if -q.Z>=0 and -q.Z<=9 and math.abs(q.X)<=4 and math.abs(q.Y)<=4 then output.primary=false;break end
                end
            end
        end
    end
    qa.jumpProbes=qa.jumpProbes or {}
    local physical=world.actors[slot]
    local lastJump=qa.jumpProbes[#qa.jumpProbes]
    if physical and lastJump and not lastJump.after and at-lastJump.at<.5
        and physical.root.AssemblyLinearVelocity.Y>10 then
        lastJump.after={at=at,position=ctx.position,velocityY=physical.root.AssemblyLinearVelocity.Y,
            state=tostring(physical.humanoid:GetState()),actorId=h.actorId,attempt=h.attempt,stock=h.respawns}
    end
    if physical and output.jump and physical.humanoid:GetState()==Enum.HumanoidStateType.Climbing
        and (#qa.jumpProbes==0 or at-lastJump.at>.5) then
        qa.jumpProbes[#qa.jumpProbes+1]={at=at,position=ctx.position,velocityY=physical.root.AssemblyLinearVelocity.Y,
            state=tostring(physical.humanoid:GetState()),floor=tostring(physical.humanoid.FloorMaterial),
            actorId=h.actorId,attempt=h.attempt,stock=h.respawns,runId=s.state.runId}
    end
    if output.primary and output.x==0 and output.z==0 and output.aimX then
        output.x,output.z=output.aimX*.03,(output.aimZ or 0)*.03
    end
    if physical then
        qa.motion=qa.motion or {}
        qa.motion[#qa.motion+1]={at=at,position=ctx.position,velocity={x=physical.root.AssemblyLinearVelocity.X,
            y=physical.root.AssemblyLinearVelocity.Y,z=physical.root.AssemblyLinearVelocity.Z},
            state=tostring(physical.humanoid:GetState()),floor=tostring(physical.humanoid.FloorMaterial),
            phase=qa.navigation and qa.navigation.phase,plan=output,attempt=h.attempt,stock=h.respawns,
            reaction=ctx.session.combat[slot].reactionEnd,notice=c.notices[player],slot=slot,decisionDt=decisionDt}
        if #qa.motion>900 then table.remove(qa.motion,1) end
    end
    if at-qa.last.sampleAt>=1 then
        qa.last.sampleAt=at
        qa.samples[#qa.samples+1]={at=at,index=index,epoch=s.state.levelEpoch,stage=d.stage,p=ctx.position,
            attempt=h.attempt,stock=h.respawns,rawLife=s.combat[slot].rawLife,actorId=h.actorId,
            target=targetId,plan=output,notice=c.notices[player],boss=d.boss and d.boss:snapshot() or nil,
            guardianHits=d.bossHits,mode=modes and {room=modes.room,progress=a and a.progress,complete=modes.complete} or nil}
        if #qa.samples>6000 then table.remove(qa.samples,1) end
    end
    qa.current={index=index,epoch=s.state.levelEpoch,stage=d.stage,position=ctx.position,runId=s.state.runId,
        actorId=h.actorId,attempt=h.attempt,stock=h.respawns,rawLife=s.combat[slot].rawLife,target=targetId,
        boss=d.boss and d.boss:snapshot() or nil,guardianHits=d.bossHits,plan=output,notice=c.notices[player],slot=slot}
    return {plan=output,index=index,status=s.state.status}
end
remote.OnServerInvoke=function(player)
    if not qa.running then return {done=true,result='Stopped'} end
    local ok,value=xpcall(function() return plan(player) end,debug.traceback)
    if not ok then qa.errors[#qa.errors+1]=tostring(value);qa.running=false;return {done=true,result='PlannerError',error=tostring(value)} end
    return value
end
qa.stop=function() qa.running=false end
print('[FULL-CAMPAIGN-QA] read-only planner bridge ready')
