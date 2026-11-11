-- Disposable Studio observer. It writes only its own tables and read Bindable.
-- No animation sampling, gameplay calls, source attributes, poses or resources.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer(),'Studio QA server only')
local Storage=game:GetService('ServerStorage')
local HttpService=game:GetService('HttpService')
local EXPECTED_SOURCE=assert(script:GetAttribute('ExpectedSourceSha256'),'ExpectedSourceSha256 required')
assert(type(EXPECTED_SOURCE)=='string' and #EXPECTED_SOURCE==64 and EXPECTED_SOURCE:match('^[0-9a-f]+$'),'Invalid ExpectedSourceSha256')
local expectedRun=script:GetAttribute('ExpectedRunId')
assert(expectedRun==nil or type(expectedRun)=='string' and #expectedRun>0,'Invalid ExpectedRunId')
assert(not Storage:FindFirstChild('BrickToadsFullCampaignPresentation'),'Presentation observer already exists')
local report={schema=1,expectedSourceSha256=EXPECTED_SOURCE,stages={},lifecycle={},details={},anomalies={},errors={},
    samples=0,skipped={},dropped={},limits={stageCount=13,familiesPerStage=32,framesPerFamily=48,
        signaturesPerFamily=12,detailRows=160,lifecycleRows=160,anomalyRows=40,errorRows=16},
    policy='Read actual server presentation tables and cosmetic Motor6D.C0 only; signatures are quantized observations, not source/timing equivalence',
    coverage='Sampled at most10Hz; missing states are unobserved, not failures; native client asset visibility/audio require separate client evidence'}
local stages,trackers,castTrackers,pending={},{},{},{}
local observedEpoch
local lastAt=-math.huge
local function number(v)return type(v)=='number' and v==v and math.abs(v)<math.huge and v or nil end
local function short(v)return type(v)=='string' and string.sub(v,1,160) or nil end
local function increment(t,key)t[key]=(t[key]or 0)+1 end
local function bounded(list,value,limit,kind)
    if #list>=limit then table.remove(list,1);increment(report.dropped,kind)end
    list[#list+1]=value
end
local function histogram(t,key,limit)
    key=short(key);if not key then return end
    if t[key]~=nil then t[key]+=1;return end
    local count=0;for _ in pairs(t)do count+=1 end
    if count<limit then t[key]=1 else increment(report.dropped,'histogramKeys')end
end
local function vector(v)return v and {x=number(v.X),y=number(v.Y),z=number(v.Z)}or nil end
local function dimensions(v)return string.format('%.4f/%.4f/%.4f',v.X,v.Y,v.Z)end
local function matrix(frame)
    local out={};for i,v in ipairs({frame:GetComponents()})do
        if not number(v)then return nil end
        out[i]=math.round(v*10000)/10000
    end
    return out
end
local function jointObservation(state)
    local names={};for name in pairs(state.joints or{})do if type(name)=='string'then names[#names+1]=name end end
    table.sort(names)
    local text,examples={},{}
    local count,invalid=0,0
    local function read(name,row)
        local motor=row and row.motor
        if not motor or not motor.Parent or not motor:IsA('Motor6D')then invalid+=1;return end
        local values=matrix(motor.C0);if not values then invalid+=1;return end
        count+=1;text[#text+1]=name..':'..table.concat(values,',')
        if #examples<3 then examples[#examples+1]={name=name,c0=values}end
    end
    for i=1,math.min(#names,32)do read(names[i],state.joints[names[i]])end
    if state.rootJoint then read('@Root',state.rootJoint)end
    -- This deterministic signature includes every observed cosmetic joint.
    -- It is deliberately not a cryptographic content hash.
    local value=17;local raw=table.concat(text,'|')
    for i=1,#raw do value=(value*131+string.byte(raw,i))%2147483647 end
    return {signature=string.format('c0-%08x-%d',value,count),joints=count,invalid=invalid,examples=examples}
end
local function cosmeticFlags(model)
    local parts,bad=0,0;local examples={}
    for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
        parts+=1
        if p.Anchored or p.CanCollide or p.CanTouch or p.CanQuery or not p.Massless then
            bad+=1;if #examples<3 then examples[#examples+1]={name=short(p.Name),anchored=p.Anchored,
                collide=p.CanCollide,touch=p.CanTouch,query=p.CanQuery,massless=p.Massless}end
        end
    end end
    return {parts=parts,flaggedParts=bad,examples=examples}
end
local function newFamily(kind)
    return {kind=kind,observations=0,sourcePoseObservations=0,withoutSourcePose=0,withoutFrameId=0,frames={},states={},
        frameBases={},namespaces={},morphs={},signatures={},jointChanges=0,lastSignature=nil,
        cosmeticFlagObservations=0,sourceFallbacks={}}
end
local function observeFamily(row,state,pose,morph)
    row.observations+=1
    if pose then
        row.sourcePoseObservations+=1
        if number(pose.frameId)then histogram(row.frames,tostring(pose.frameId),48)else row.withoutFrameId+=1 end
        histogram(row.states,pose.state or pose.kind,16)
        histogram(row.frameBases,pose.frameBasis,16)
        histogram(row.namespaces,pose.namespace,16)
    else row.withoutSourcePose+=1 end
    histogram(row.morphs,morph or 'None',8)
    histogram(row.sourceFallbacks,state.sourceFallback,16)
    local joints=jointObservation(state)
    histogram(row.signatures,joints.signature,12)
    if row.lastSignature and row.lastSignature~=joints.signature then row.jointChanges+=1 end
    row.lastSignature=joints.signature
    return joints
end
local function stageFor(index,epoch,at,controller)
    local row=stages[index]
    if not row then
        row={index=index,epoch=epoch,firstAt=at,lastAt=at,observations=0,heroes={},cast={},
            serpent={observations=0,maxSupports=0,maxOwnedSkins=0,maxProxies=0,maxTemporaryTemplates=0,
                skinMissingObservations=0,supportPhysicsObservations=0},qa={}}
        stages[index]=row;report.stages[#report.stages+1]=row
        bounded(report.lifecycle,{kind='StageObserved',index=index,epoch=epoch,at=at,
            runId=report.runId,mode=short(controller.deps.Config.Level.mode)},160,'lifecycle')
    end
    row.lastAt=at;row.observations+=1
    return row
end
local function anomaly(key,condition,context,at)
    if not condition then pending[key]=nil;return end
    local p=pending[key]
    if not p then
        local count,oldest,oldAt=0,nil,math.huge
        for name,row in pairs(pending)do count+=1;if row.since<oldAt then oldest,oldAt=name,row.since end end
        if count>=128 then pending[oldest]=nil;increment(report.dropped,'anomalyCandidates')end
        pending[key]={since=at};return
    end
    -- Require repeated stable living-body observations; a new stage or body
    -- receives a separate grace interval. This does not infer gameplay faults.
    if at-p.since>=.5 and not p.reported then
        p.reported=true;context.at=at;context.persisted=at-p.since
        bounded(report.anomalies,context,40,'anomalies')
    end
end
local function detail(at,index,slot,actorId,kind,state,pose,morph,joints,flags)
    bounded(report.details,{at=at,index=index,slot=slot,actorId=actorId,kind=kind,
        frameId=pose and number(pose.frameId),state=pose and short(pose.state or pose.kind),
        frameBasis=pose and short(pose.frameBasis),namespace=pose and short(pose.namespace),
        activeMorph=short(morph),sourceFallback=short(state.sourceFallback),
        c0=joints,cosmeticFlags=flags},160,'details')
end
local function mountedObservation(world,slot,actor,skin)
    if not skin.sourcePose or skin.sourcePose.kind~='Ride' then return end
    local objects=world.campaignWorld and world.campaignWorld.objects
    local row=objects and(objects['vehicle-'..tostring(slot)]or objects['clinger-'..tostring(slot)])
    local mount=row and row.courseAppearance
    if not mount or not number(mount.deckWorldY) then return end
    local lowest=math.huge
    for _,name in ipairs({'LeftFoot','RightFoot'})do
        local p=skin.model:FindFirstChild(name)
        if not p or not p:IsA('MeshPart') then return end
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            local v=p.CFrame*Vector3.new(p.Size.X*x/2,p.Size.Y*y/2,p.Size.Z*z/2)
            lowest=math.min(lowest,v.Y)
        end end end
    end
    local mode=world.campaignModes and world.campaignModes.actors[slot]
    return {kind=short(row.kind),deckY=mount.deckWorldY,soleY=lowest,gap=lowest-mount.deckWorldY,
        groundPlaneY=number(mount.groundPlaneY),meshBottomWorldY=number(mount.meshBottomWorldY),
        rootY=actor.root.Position.Y,verticalSpeed=mode and mode.velocity and number(mode.velocity.y),
        note='Actual server MeshPart corners at sample time; moving assemblies may be between presentation and solver updates'}
end
local function sample()
    local at=workspace:GetServerTimeNow()
    if at-lastAt<.1 then return end;lastAt=at
    local hub,qa=_G.BrickToadsFullCampaignHub,_G.BrickToadsFullCampaignQA
    if not hub or not qa or not qa.current then increment(report.skipped,'AwaitingQA');return end
    local run=qa.current.runId
    if type(run)~='string' or expectedRun and run~=expectedRun then increment(report.skipped,'OtherRun');return end
    if not report.runId then report.runId=run;expectedRun=run end
    for _,group in pairs(hub.groups or{})do
        local c=group.controller;local session=c and c.current
        if session and session.state.runId==report.runId then
            local index,epoch=c.campaignIndex,session.state.levelEpoch
            local lastStage=qa.stages and qa.stages[#qa.stages]
            if not number(index)or index%1~=0 or index<1 or index>13 or qa.current.index~=index
                or qa.current.epoch~=epoch or not lastStage or lastStage.index~=index or lastStage.epoch~=epoch then
                increment(report.skipped,'TransitionOrStaleQA');return
            end
            local source=c.journal and c.journal.context and c.journal.context.build or qa.build
            if not report.observedSourceSha256 and type(source)=='string'then report.observedSourceSha256=source end
            report.sourceMatches=source==EXPECTED_SOURCE
            if source~=report.observedSourceSha256 then increment(report.skipped,'SourceChanged');return end
            local development=c.deps.Config.Development or{}
            local infiniteHeroes=0;for _,hero in pairs(session.state.heroes)do if hero.infiniteLives==true then infiniteHeroes+=1 end end
            report.godMode={attribute=Storage:GetAttribute('BrickToadsGodMode')==true,
                configured=development.infiniteLives==true,allowed=development.allowInfiniteLives==true,
                infiniteHeroes=infiniteHeroes}
            report.qa={running=qa.running==true,result=short(qa.result),index=index,epoch=epoch,
                stage=short(qa.current.stage),sampleCount=#(qa.samples or{}),policyLoads=number(qa.policyLoads),
                plannerErrors=#(qa.errors or{}),sessionStatus=short(session.state.status),faulted=c.faulted==true}
            report.lastAt=at;report.samples+=1
            local stage=stageFor(index,epoch,at,c);stage.qa=report.qa;stage.godMode=report.godMode
            if observedEpoch~=epoch then observedEpoch=epoch;pending={};castTrackers={}end
            local world=group.world
            for _,slot in ipairs(session.order or{})do
                local h=session.state.heroes[slot];local actor=world.actors[slot]
                if h then
                    local identity=table.concat({tostring(h.actorId),tostring(h.status),tostring(h.attempt),tostring(epoch)},':')
                    local track=trackers[slot]
                    if not track or track.identity~=identity then
                        local sameBody=track and actor and track.model==actor.model
                        track={identity=identity,model=actor and actor.model,firstAt=at,
                            rootSize=sameBody and track.rootSize or actor and actor.root and dimensions(actor.root.Size)}
                        trackers[slot]=track
                        bounded(report.lifecycle,{kind='HeroLifecycle',at=at,index=index,epoch=epoch,slot=slot,
                            actorId=short(h.actorId),status=short(h.status),attempt=number(h.attempt),
                            stock=number(h.respawns),connected=h.connected==true},160,'lifecycle')
                    end
                    local combat=session.combat[slot]
                    local live=actor and actor.model.Parent and actor.root and actor.root.Parent and actor.humanoid
                        and actor.humanoid.Health>0 and actor.model:GetAttribute('ActorId')==h.actorId
                        and h.status=='Alive' and h.connected and not h.held and not (combat and combat.deathAt)
                        and session.state.status=='Active' and qa.running and at-track.firstAt>=.3
                    if live then
                        local skin=actor.appearance
                        if skin and skin.ownerModel==actor.model and skin.model.Parent==actor.model then
                            local row=stage.heroes[tostring(slot)]
                            if not row then row=newFamily(skin.heroTemplate or 'Hero');stage.heroes[tostring(slot)]=row end
                            local joints=observeFamily(row,skin,skin.sourcePose,skin.activeMorph)
                            local flags=cosmeticFlags(skin.model)
                            if flags.flaggedParts>0 then row.cosmeticFlagObservations+=1 end
                            local key=tostring(index)..':hero:'..tostring(slot)..':'..tostring(h.actorId)
                            anomaly(key..':flags',flags.flaggedParts>0,{kind='HeroCosmeticFlags',index=index,
                                epoch=epoch,slot=slot,actorId=short(h.actorId),flags=flags},at)
                            anomaly(key..':size',track.rootSize~=dimensions(actor.root.Size),{kind='PhysicalRootSizeChanged',
                                index=index,epoch=epoch,slot=slot,actorId=short(h.actorId),baseline=track.rootSize,
                                observed=dimensions(actor.root.Size)},at)
                            row.collider={rootSize=vector(actor.root.Size),rootCanCollide=actor.root.CanCollide,
                                rootAnchored=actor.root.Anchored,platformStand=actor.humanoid.PlatformStand}
                            local mounted=mountedObservation(world,slot,actor,skin)
                            if mounted then
                                row.mounts=row.mounts or{}
                                local m=row.mounts[mounted.kind]
                                if not m then m={observations=0,minGap=math.huge,maxGap=-math.huge};row.mounts[mounted.kind]=m end
                                m.observations+=1;m.minGap=math.min(m.minGap,mounted.gap);m.maxGap=math.max(m.maxGap,mounted.gap)
                                m.first=m.first or mounted;m.last=mounted
                                if mounted.verticalSpeed and math.abs(mounted.verticalSpeed)<.1 then
                                    m.flatObservations=(m.flatObservations or 0)+1
                                    m.flatMinGap=math.min(m.flatMinGap or math.huge,mounted.gap)
                                    m.flatMaxGap=math.max(m.flatMaxGap or-math.huge,mounted.gap)
                                end
                            end
                            local signature=table.concat({tostring(skin.sourcePose and skin.sourcePose.frameId),
                                tostring(skin.sourcePose and skin.sourcePose.kind),tostring(skin.activeMorph),joints.signature},':')
                            if track.detailSignature~=signature and at-(track.detailAt or 0)>=.5 then
                                track.detailSignature=signature;track.detailAt=at
                                detail(at,index,slot,short(h.actorId),row.kind,skin,skin.sourcePose,skin.activeMorph,joints,flags)
                            end
                        else increment(report.skipped,'HeroSkinUnavailable')end
                    else increment(report.skipped,'HeroTransientOrInactive')end
                end
            end
            for id,actor in pairs(world.actors or{})do if id<0 then
                local skin=actor.castAppearance
                if skin and actor.model.Parent and skin.ownerModel==actor.model and skin.model.Parent==actor.model then
                    local kind=short(skin.kind)or'Unknown'
                    local row=stage.cast[kind]
                    if not row then
                        local count=0;for _ in pairs(stage.cast)do count+=1 end
                        if count<32 then row=newFamily(kind);stage.cast[kind]=row end
                    end
                    if row then
                        local actorId=short(actor.model:GetAttribute('ActorId'))or tostring(id)
                        local identity=tostring(epoch)..':'..actorId
                        local track=castTrackers[id]
                        if not track or track.identity~=identity then
                            track={identity=identity,firstAt=at};castTrackers[id]=track
                            bounded(report.lifecycle,{kind='CastLifecycle',at=at,index=index,epoch=epoch,
                                slot=id,actorId=actorId,family=kind},160,'lifecycle')
                        end
                        local joints=observeFamily(row,skin,skin.pose,nil)
                        local flags=cosmeticFlags(skin.model)
                        if flags.flaggedParts>0 then row.cosmeticFlagObservations+=1 end
                        local alive=actor.humanoid and actor.humanoid.Health>0 and session.state.status=='Active'and qa.running
                            and at-track.firstAt>=.3 and skin.presentation and skin.presentation.actorId==actorId
                            and skin.presentation.levelEpoch==epoch
                        anomaly(tostring(index)..':cast:'..actorId,alive and flags.flaggedParts>0,
                            {kind='CastCosmeticFlags',index=index,epoch=epoch,actorId=actorId,family=kind,flags=flags},at)
                        if row.detailAt==nil or at-row.detailAt>=2 then
                            row.detailAt=at;detail(at,index,id,actorId,kind,skin,skin.pose,nil,joints,flags)
                        end
                    end
                end
            end end
            local counts={supports=0,skins=0,proxies=0,templates=0,missing=0,badSupport=0}
            local course=world.campaignWorld
            for _,object in pairs(course and course.objects or{})do if object.kind=='Serpent'then
                counts.supports+=1
                if not object.part.CanCollide or not object.part.Anchored then counts.badSupport+=1 end
                local skin=object.serpent
                if skin then
                    if skin.actor and skin.actor.castAppearance then counts.skins+=1 end
                    if skin.proxy and skin.proxy.Parent==world.geometry then counts.proxies+=1 end
                    if skin.temporary then counts.templates+=#skin.temporary:GetChildren()end
                else counts.missing+=1 end
            end end
            local serpent=stage.serpent;serpent.observations+=1
            serpent.maxSupports=math.max(serpent.maxSupports,counts.supports)
            serpent.maxOwnedSkins=math.max(serpent.maxOwnedSkins,counts.skins)
            serpent.maxProxies=math.max(serpent.maxProxies,counts.proxies)
            serpent.maxTemporaryTemplates=math.max(serpent.maxTemporaryTemplates,counts.templates)
            serpent.skinMissingObservations+=counts.missing;serpent.supportPhysicsObservations+=counts.badSupport
            serpent.latest=counts
            return
        end
    end
    increment(report.skipped,'NoMatchingSession')
end
local read=Instance.new('BindableFunction');read.Name='BrickToadsFullCampaignPresentation'
read.OnInvoke=function(kind)
    local out={schema=report.schema,expectedSourceSha256=EXPECTED_SOURCE,observedSourceSha256=report.observedSourceSha256,
        sourceMatches=report.sourceMatches,runId=report.runId,lastAt=report.lastAt,samples=report.samples,
        godMode=report.godMode,qa=report.qa,stages=report.stages,anomalies=report.anomalies,errors=report.errors,
        skipped=report.skipped,dropped=report.dropped,limits=report.limits,policy=report.policy,coverage=report.coverage}
    if kind=='details' or kind=='archive'then out.details=report.details;out.lifecycle=report.lifecycle end
    return HttpService:JSONEncode(out)
end
read.Parent=Storage
local heartbeat=RunService.Heartbeat:Connect(function()
    local ok,err=xpcall(sample,debug.traceback)
    if not ok then bounded(report.errors,{at=workspace:GetServerTimeNow(),error=string.sub(tostring(err),1,1200)},16,'errors')end
end)
script.Destroying:Connect(function()heartbeat:Disconnect();if read.Parent then read:Destroy()end end)
print('[FULL-CAMPAIGN-PRESENTATION] read-only observer ready')
