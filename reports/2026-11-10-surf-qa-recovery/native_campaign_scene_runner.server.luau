-- Prepared, isolated Studio acceptance. Never a complete campaign claim.
-- Adapted from native_ascent_finish_fixture.server.luau. The installer clones
-- production modules and frozen QA input policies before enabling this Script.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer(),'Studio Server only')
local Http=game:GetService('HttpService')
local Lighting=game:GetService('Lighting')
local owner=script.Parent
assert(owner:GetAttribute('Owner')=='native_campaign_scene','Owned fixture required')
local project=assert(owner:FindFirstChild('OwnedModules'))
local G,R=project.gameplay,project.CombatRuntime
local Late=require(owner.LatePilot)
local CombatPilot=require(owner.CombatPilot)
local Early=owner:FindFirstChild('EarlyPilot') and require(owner.EarlyPilot)
local Nav=require(owner.Nav)
local result={status='preparing',scenario='prepared_native_campaign_stage',
    stageIndex=assert(owner:GetAttribute('StageIndex')),seed=owner:GetAttribute('Seed') or 820297848,
    heroSlot=owner:GetAttribute('HeroSlot') or 3,inputCadence=owner:GetAttribute('InputCadence') or .1,
    sourceSha256=owner:GetAttribute('ProductionSourceSha256'),policySha256=owner:GetAttribute('PolicySha256'),
    preparation={authoredSpawn=true,preparedPoses=false,npcAI=true,bossAI=true,resourceWrites=false},
    limits={'Prepared stage-specific synthetic server roster, not registered clients or a continuous campaign',
        'Session/Director and presentation advance on real native Heartbeats; ordinary Move/Jump/Punch only',
        'Input dispatch is server-side at the stated cadence, without client/network latency'},
    events={},samples={},intentCounts={},frameStats={count=0,total=0,max=0},cleanup=false}
local output=owner:FindFirstChild('Result') or Instance.new('StringValue')
output.Name='Result';output.Parent=owner
local reader=owner:FindFirstChild('Read') or Instance.new('BindableFunction')
reader.Name='Read';reader.Parent=owner
local exported
local function save()
    exported=Http:JSONEncode(result)
    -- StringValue has a 200000-character cap. Full evidence stays in the
    -- ordinary Script closure and is exported through Read's bounded chunks.
    output.Value=Http:JSONEncode({status=result.status,stageIndex=result.stageIndex,elapsed=result.elapsed,
        samples=#result.samples,events=#result.events,bytes=#exported,error=result.error,cleanup=result.cleanup})
    owner:SetAttribute('Status',result.status)
end
reader.OnInvoke=function(kind,part)
    if kind=='full' then return exported or Http:JSONEncode(result) end
    if kind=='chunk' then local data=exported or Http:JSONEncode(result);local n=tonumber(part) or 1;return string.sub(data,(n-1)*25000+1,n*25000) end
    return Http:JSONEncode({status=result.status,stageIndex=result.stageIndex,seed=result.seed,
        elapsed=result.elapsed,last=result.last,samples=#result.samples,events=#result.events,
        error=result.error,bytes=exported and #exported or 0,cleanup=result.cleanup})
end
save()
local world,session,director
local ownedWorldName=owner.Name..'_World'
local reservedWorldName=false
local function point(x,y,z) return {x=x,y=y,z=z} end
local function plain(v) return {x=v.X,y=v.Y,z=v.Z} end
local function neutral() return {x=0,z=0,jump=false,primary=false,run=false} end
local function normalize(p)
    p=p or neutral();local x,z=p.x or 0,p.z or 0;local n=math.sqrt(x*x+z*z)
    if n>1 then x,z=x/n,z/n end
    return {x=x,z=z,jump=p.jump==true,primary=p.primary==true,run=p.run==true,aimX=p.aimX,aimZ=p.aimZ}
end
local plans={}
local function floorRows()
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
-- Frozen full_campaign_bridge.server.luau foot composition, including its
-- existing direct arena approach once the actual Modes actor is finished.
local function foot(ctx,desired,combatPlan)
    local p=ctx.position;local a=world.actors[ctx.slot]
    if not p or not a then return neutral() end
    if ctx.modes and ctx.actor and ctx.actor.finished then
        local dx,dz=desired.x-p.x,desired.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
        local out=combatPlan or neutral()
        if not combatPlan then out.x,out.z=n>.7 and dx/math.max(n,1) or 0,n>.7 and dz/math.max(n,1) or 0 end
        return out
    end
    local key=ctx.stageToken..':'..tostring(ctx.slot)
    local state=plans[key];local hero=session.state.heroes[ctx.slot]
    if not state or state.actorId~=hero.actorId then state={actorId=hero.actorId};plans[key]=state end
    local v=a.root.AssemblyLinearVelocity;local floors=floorRows()
    local support=Nav.currentFloor(p,floors,state.previousFloor)
    local beyond=support and (desired.x<support.minX or desired.x>support.maxX or desired.z<support.minZ or desired.z>support.maxZ)
    local combat=session.combat[ctx.slot];local requested=a.locomotion and a.locomotion.runRequested
    local canLaunch=a.humanoid.FloorMaterial~=Enum.Material.Air and not a.humanoid.PlatformStand
        and not combat.reactionEnd and not combat.deathAt and requested and math.sqrt(v.X*v.X+v.Z*v.Z)>=18
    local nav=Nav.plan(p,desired,floors,state,ctx.now,{grounded=canLaunch,vy=v.Y,allowCrossing=true,jumpLead=3.2})
    if nav.phase=='No support' then
        local closest,best
        for _,f in ipairs(floors) do
            local x=math.clamp(p.x,f.minX,f.maxX);local z=math.clamp(p.z,f.minZ,f.maxZ)
            local gap=math.sqrt((p.x-x)^2+(p.z-z)^2)
            if gap<=3 and p.y>=f.top-2 and p.y<=f.top+4 and (not best or gap<best) then closest,best=f,gap end
        end
        if closest then
            nav.target=point(math.clamp(p.x,closest.minX+3,closest.maxX-3),closest.top+3,math.clamp(p.z,closest.minZ+3,closest.maxZ-3))
            nav.phase='Recover edge with ordinary input';nav.crossing=true;nav.jump=true
        end
    end
    local out=combatPlan or neutral();local target=nav.target
    local approach=beyond and not (combatPlan and (out.primary or out.evasion or out.hold or combat and combat.attack))
    if nav.crossing or nav.attackAllowed~=true or not combatPlan or approach then
        local dx,dz=target.x-p.x,target.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
        out.x,out.z=n>.15 and dx/math.max(n,1) or 0,n>.15 and dz/math.max(n,1) or 0
    end
    if nav.attackAllowed~=true then out.primary=false;out.run=false end
    if nav.crossing then out.jump=nav.jump==true;out.run=true else out.jump=out.jump or nav.jump==true end
    result.navigation={phase=nav.phase,target=target,fault=nav.fault};return out
end
local function run()
    local definition=require(G.CampaignDefinition).build(result.stageIndex,result.seed)
    result.mode=definition.mode;result.definition=definition
    local config=require(G.GameConfig)(require(R.Config),definition)
    local World=require(G.GameWorld);require(G.DragonWorld)(World);require(G.BossIntroWorld)(World)
    for _,name in ipairs({'Baseplate','SpawnLocation'}) do assert(not workspace:FindFirstChild(name),'Refuse shared default migration: '..name) end
    local light,air={},{}
    for _,key in ipairs({'ClockTime','Brightness','Ambient','OutdoorAmbient','ColorShift_Top','GlobalShadows','FogColor','FogStart','FogEnd'}) do light[key]=Lighting[key] end
    local atmosphere=Lighting:FindFirstChild('CausewayAtmosphere')
    if atmosphere then for _,key in ipairs({'Density','Offset','Color','Decay','Glare','Haze'}) do air[key]=atmosphere[key] end end
    assert(not workspace:FindFirstChild(ownedWorldName),'Prepared world name already exists')
    reservedWorldName=true
    local okay,made=pcall(World.new,require(R.RobloxWorld),config,{name=ownedWorldName,
        offset={x=0,y=owner:GetAttribute('OffsetY') or 32,z=assert(owner:GetAttribute('OffsetZ'))},
        characterAppearance=require(G.CharacterAppearance),guardianAppearance=require(G.GuardianAppearance),campaignWorld=require(G.CampaignWorld)})
    for key,value in pairs(light) do Lighting[key]=value end
    if atmosphere then for key,value in pairs(air) do atmosphere[key]=value end
    else local created=Lighting:FindFirstChild('CausewayAtmosphere');if created then created:Destroy() end end
    result.preparation.lightingRestoredBeforeYield=true
    assert(okay,made);world=made;world.folder:SetAttribute('QAOwner',owner.Name)
    result.offset=plain(world.offset)
    local Session,Combat=require(R.Session),require(R.Combat)
    local slot=result.heroSlot
    local start=workspace:GetServerTimeNow()
    session=Session.new(require(project.RunLifecycle),Combat,config,{{userId=slot,template=slot==3 and 'Mr. Brown' or 'Mr. Green'}},
        'prepared-stage-'..result.stageIndex..'-'..Http:GenerateGUID(false),world,function(row)
            result.events[#result.events+1]=row
            if row.kind=='Hit' then world:cue(row.userId,row.data.blocked) end
        end,{groupId=owner.Name,levelId=definition.id})
    assert(session:step(start)=='OK')
    local deps={Director=require(G.LevelDirector),CampaignModes=require(G.CampaignModes),CampaignBoss=require(G.CampaignBoss),
        CampaignDefinition=require(G.CampaignDefinition),CampaignEnemies=require(G.CampaignEnemies),GuardianPattern=require(G.GuardianPattern),
        HealingFlies=require(G.HealingFlies),EnemyCarry=require(G.EnemyCarry),WalkerClubs=require(G.WalkerClubs),DragonFlight=require(G.DragonFlight),
        BossIntro=require(G.BossIntro)(require(G.CanonicalAnimation))}
    director=require(G.CampaignDirector).new(session,world,Combat,config,deps)
    local originalHit=session._hit
    session._hit=function(self,attacker,target,action,tuning)
        if type(target)=='number' and target<0 then return director:hit(attacker,target,action,tuning) end
        return originalHit(self,attacker,target,action,tuning)
    end
    session.contextualAttack=function(id,now,action) return director:interact(id,now,action) end
    require(G.SourceCombat).bind(session,director,config)
    result.runId=session.state.runId
    -- Resource scalars are captured, not aliases into the evolving lifecycle.
    local initialHero=session.state.heroes[slot]
    result.initial={actorId=initialHero.actorId,attempt=initialHero.attempt,stock=initialHero.respawns,
        status=initialHero.status,rawLife=session.combat[slot].rawLife,position=world:position(slot)}
    result.status='running';save()
    local seq,lastDecision,lastPrimary=0,start-result.inputCadence,-math.huge
    local nextSample=start;local nextSave=start;local lastSignature
    local plan=neutral()
    local function send(kind,extra,now)
        local hero=session.state.heroes[slot];seq+=1
        local packet={kind=kind,runId=session.state.runId,actorId=hero.actorId,attempt=hero.attempt,
            levelEpoch=session.state.levelEpoch,connectionEpoch=hero.connectionEpoch,seq=seq}
        for key,value in pairs(extra or {}) do packet[key]=value end
        local code=session:intent(slot,packet,now)
        local key=kind..':'..code;result.intentCounts[key]=(result.intentCounts[key] or 0)+1
        if code=='OK' and kind=='Attack' then
            local accepted=session.combat[slot].attack
            if accepted and accepted.actorId==hero.actorId then
                director.now=now;director:closeTargetForAttack(world:targets(slot,accepted.tuning or config.Attacks[accepted.action]))
            end
        end
    end
    local function sample(now)
        local hero=session.state.heroes[slot];local combat=session.combat[slot]
        local a=director.modes.actors[slot];local body=world.actors[slot]
        local enemies={}
        for id,e in pairs(director.enemies) do enemies[#enemies+1]={id=id,kind=e.kind,dead=e.dead,
            rawLife=e.rawLife,position=world:position(id)} end
        return {at=now,elapsed=now-start,stage=director.stage,result=director.result,modeComplete=director.modes.complete,
            actorId=hero.actorId,attempt=hero.attempt,stock=hero.respawns,status=hero.status,rawLife=combat.rawLife,
            reactionEnd=combat.reactionEnd,deathAt=combat.deathAt,position=world:position(slot),plan=plan,
            mode=a and {position=table.clone(a.position),velocity=table.clone(a.velocity),grounded=a.grounded,support=a.support,
                finished=a.finished,segment=a.segment,progress=a.progress,medium=a.medium,oxygen=a.oxygen},
            body=body and body.root.Parent and {position=plain(body.root.Position-world.offset),velocity=plain(body.root.AssemblyLinearVelocity),
                anchored=body.root.Anchored,platformStand=body.humanoid.PlatformStand,state=body.humanoid:GetState().Name,floor=body.humanoid.FloorMaterial.Name},
            boss=director.boss and director.boss:snapshot(),enemies=enemies}
    end
    while workspace:GetServerTimeNow()-start<(owner:GetAttribute('MaxSimTime') or 240) do
        local dt=RunService.Heartbeat:Wait();local now=workspace:GetServerTimeNow()
        result.frameStats.count+=1;result.frameStats.total+=dt;result.frameStats.max=math.max(result.frameStats.max,dt)
        director.now=now;session:step(now);director:step(now,dt)
        world:updatePresentation(session,dt,director.enemies)
        local hero=session.state.heroes[slot];local a=director.modes.actors[slot]
        if now-lastDecision>=result.inputCadence and hero.status=='Alive' and not session.combat[slot].deathAt and not director.result then
            local ctx={session=session,director=director,world=world,modes=director.modes,definition=definition,slot=slot,
                actor=a,position=world:position(slot),now=now,dt=now-lastDecision,stageToken=session.state.runId..':'..session.state.levelEpoch}
            lastDecision=now
            local target,q=CombatPilot.target(ctx);local fight=target and CombatPilot.plan(ctx) or nil
            if a and a.finished then plan=foot(ctx,q or definition.boss.position,fight)
            elseif definition.course.mount and a and not a.mounted and not director:_boardingCleared() then plan=fight or neutral()
            else
                plan=(result.stageIndex<=7 and Early and Early.plan(ctx) or Late.plan(ctx)) or neutral()
                local tubes=definition.mode=='Tubes' and owner:FindFirstChild('TubesArbitration')
                if tubes then plan=require(tubes).plan(ctx,plan) end
            end
            plan=normalize(plan)
            if plan.primary and plan.x==0 and plan.z==0 and plan.aimX then plan.x,plan.z=plan.aimX*.03,(plan.aimZ or 0)*.03 end
            send('Move',{x=plan.x,z=plan.z,run=plan.run},now)
            if plan.jump then send('Jump',nil,now) end
            if plan.primary and now-lastPrimary>=.13 then lastPrimary=now;send('Attack',{attack='Punch'},now) end
        end
        local signature=table.concat({director.stage,tostring(hero.attempt),tostring(hero.respawns),tostring(a and a.finished),
            tostring(director.boss and director.boss.phase)},':')
        if now>=nextSample or signature~=lastSignature or director.result or session.state.status=='Lost' then
            local row=sample(now);result.samples[#result.samples+1]=row;result.last=row;nextSample=now+.25;lastSignature=signature
        end
        result.elapsed=now-start
        if now>=nextSave then save();nextSave=now+1 end
        if director.result or session.state.status=='Lost' then
            result.result=director.result or session.state.status;result.status=result.result=='Won' and 'passed' or 'failed';break
        end
    end
    if result.status=='running' then result.status='timeout';result.result='Timeout' end
    result.terminal=result.last;result.finishedAt=workspace:GetServerTimeNow()
end
local okay,err=xpcall(run,debug.traceback)
if not okay then result.status='error';result.error=tostring(err) end
local cleaned,cleanupError=pcall(function()
    if director and not director.closed then director:close('OwnedPreparedFixtureCleanup') end
    if world then world:clearActors();world.folder:Destroy()
    elseif reservedWorldName then
        -- The constructor can fail after allocating the previously absent,
        -- exact owned name. Never search for or remove another world.
        local partial=workspace:FindFirstChild(ownedWorldName)
        if partial then partial:Destroy() end
    end
    if project.Parent then project:Destroy() end
end)
result.cleanup=cleaned;result.cleanupError=not cleaned and tostring(cleanupError) or nil
save()
