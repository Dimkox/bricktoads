-- Test-only real-client enemy/crash acceptance. Never included in production.
local Acceptance = {}
local RS, Players = game:GetService("RunService"), game:GetService("Players")
local Storage, STS = game:GetService("ReplicatedStorage"), game:GetService("StudioTestService")
local function copyPoint(p) return p and {x=p.x,y=p.y,z=p.z} end
local function distance(p,q) return math.sqrt((p.x-q.x)^2+(p.z-q.z)^2) end
function Acceptance.install(hub)
    if not RS:IsStudio() or not RS:IsServer() then return false end
    local argsOK,args=pcall(function() return STS:GetTestArgs() end)
    if not argsOK or type(args)~="table" or args.tag~="BrickToadsScooterRoleNetworkTest" then return false end
    local started,finished,serial=os.clock(),false,0
    local result={tag=args.tag,status="RUNNING",scenario=args.scenario,
        invaderOutcome=args.scenario=="InvaderDisconnect"and "Escape"or args.invaderOutcome or "Return",
        players=args.players,heroes=args.heroes,sourceId=hub.deps.BuildId,expectedSourceId=args.expectedSourceId,
        seed=args.seed or 41,checks={},commands={},trace={},heartbeats={},contacts={},startup={},departures={},
        preparation="Actual clients choose roles/heroes and Start. Only seed and two campaign advances prepare stage 3.",
        scope="Actual Studio clients and production Intent/State; no direct gameplay input, pose, health or stock injection.",
        skipped={"Physical touch/mobile hardware","Impaired networks","Registered-account reconnect"}}
    local bridge=Instance.new("Folder");bridge.Name="BrickToadsScooterNetworkTest"
    bridge:SetAttribute("SourceId",hub.deps.BuildId or "unknown");bridge:SetAttribute("Tag",args.tag);bridge.Parent=Storage
    local command=Instance.new("RemoteEvent");command.Name="Command";command.Parent=bridge
    local reply=Instance.new("RemoteEvent");reply.Name="Reply";reply.Parent=bridge
    local ready,pending,latest,lastSeen,lastBeat,departed={},{},{},{},{},{}
    local members,heroes,enemyPlayer,group,c,observer,ridingObserver
    local function real(p) return typeof(p)=="Instance" and p:IsA("Player") and p.Parent==Players and Players:GetPlayerByUserId(p.UserId)==p end
    Players.PlayerRemoving:Connect(function(player)
        if finished then return end
        local row={name=player.Name,userId=player.UserId,removingAt=workspace:GetServerTimeNow(),
            typeof=typeof(player),className=player.ClassName,wasCurrentAtEvent=hub.connections:isCurrent(player)}
        departed[player]=row;result.departures[#result.departures+1]=row
    end)
    local function remainingMembers()
        local active={};for _,player in ipairs(members or {})do if real(player)then active[#active+1]=player end end
        return active
    end
    local function state()
        if not c then return {at=workspace:GetServerTimeNow()} end
        local s,d=c.current,c.director;local hs,es,ps={},{},{}
        for _,slot in ipairs(s and s.order or {})do
            local h,a=s.state.heroes[slot],c.world.actors[slot];local root=a and a.root
            local anchored=root and root.Parent and root.Anchored or false
            local ownerOK,owner=false,nil
            if root and root.Parent and not anchored then ownerOK,owner=pcall(function() return root:GetNetworkOwner() end) end
            hs[#hs+1]={slot=slot,actorId=h.actorId,attempt=h.attempt,respawns=h.respawns,rawLife=s.combat[slot].rawLife,
                status=h.status,connected=h.connected,connectionEpoch=h.connectionEpoch,position=c.world:position(slot),
                bodyActorId=a and a.model:GetAttribute("ActorId"),bodyIsInstance=a~=nil and typeof(a.model)=="Instance",
                bodyInWorkspace=root~=nil and root:IsDescendantOf(workspace),anchored=anchored,
                ownershipKind=anchored and "AnchoredServerPose" or (ownerOK and (owner==nil and "MeasuredServerOwner" or "MeasuredClientOwner") or "Unavailable"),
                networkOwnerRead=ownerOK,serverOwned=anchored or ownerOK and owner==nil,notice=s.lastSeq[slot]}
        end
        for id,e in pairs(d and d.enemies or {})do
            local a=c.world.actors[id]
            es[#es+1]={id=id,kind=e.kind,actorId=e.actorId,ownerUserId=e.ownerUserId,dead=e.dead==true,
                engaged=e.engaged==true,connected=e.connected,connectionEpoch=e.connectionEpoch,
                rawLife=e.rawLife,lifeEscapeAt=e.lifeEscapeAt,position=c.world:position(id),
                bodyActorId=a and a.model:GetAttribute("ActorId"),lastSeq=e.lastSeq}
        end
        for id,p in pairs(d and d.campaignEnemies and d.campaignEnemies.projectiles or {})do
            ps[#ps+1]={id=id,owner=p.owner,actorId=p.actorId,mode=p.mode,position=copyPoint(p.position),created=p.created,expiresAt=p.expiresAt}
        end
        return {at=workspace:GetServerTimeNow(),sourceId=hub.deps.BuildId,groupId=group.id,worldName=c.world.folder.Name,
            runId=s and s.state.runId,levelEpoch=s and s.state.levelEpoch,status=s and s.state.status,
            campaignIndex=c.campaignIndex,faulted=c.faulted==true,heroes=hs,enemies=es,projectiles=ps,
            mode=d and d.modes and d.modes:snapshot()}
    end
    local function finish(status,err)
        if finished then return end;finished=true
        if observer then observer:Disconnect()end
        result.status,result.error,result.elapsedSeconds=status,err,os.clock()-started
        local ok,final=pcall(state);if ok then result.final=final else result.finalReadError=tostring(final)end
        if c and c.journal then local jok,j=pcall(function()return c.journal:snapshot()end);if jok then result.journal=j end end
        local passed,failed=0,0;for _,row in ipairs(result.checks)do if row.pass then passed+=1 else failed+=1 end end
        result.summary={passed=passed,failed=failed,samples=#result.trace,commands=#result.commands}
        print("[BT-SCOOTER-ROLE] "..status.." "..game:GetService("HttpService"):JSONEncode(result.summary))
        STS:EndTest(result)
    end
    task.delay(math.clamp(tonumber(args.timeoutSeconds)or 180,60,180),function()if not finished then finish("FAIL","Overall watchdog expired")end end)
    reply.OnServerEvent:Connect(function(p,m)
        if finished or not real(p)or type(m)~="table"then return end
        local now=workspace:GetServerTimeNow();lastSeen[p]={at=now,type=m.type,id=m.id}
        if (m.type=="Ready"or m.type=="Heartbeat")and type(m.state)=="table"then
            latest[p]=m.state
            if m.type=="Ready"then
                local armed=m.state.commandListenerReady==true and type(m.state.renderFrameCount)=="number"and m.state.renderFrameCount>=2
                result.startup[#result.startup+1]={name=p.Name,userId=p.UserId,at=now,elapsed=os.clock()-started,
                    armed=armed,sourceId=m.state.sourceId,renderFrameCount=m.state.renderFrameCount}
                if armed then ready[p]=true end
            else
                local beat={name=p.Name,userId=p.UserId,receivedAt=now,gap=lastBeat[p]and now-lastBeat[p].receivedAt,state=m.state,clientAt=m.clientAt}
                lastBeat[p]=beat;if #result.heartbeats<720 then result.heartbeats[#result.heartbeats+1]=beat end
            end
        elseif m.type=="Reply"and type(m.id)=="string"then
            local q=pending[m.id]
            if q and q.player==p and not q.reply then
                q.reply=m;q.evidence.receivedAt=now;q.evidence.replied=true;q.evidence.ok=m.ok==true;q.evidence.rtt=now-q.sentAt
                if not m.ok then q.evidence.error=tostring(m.result)end
                if m.ok and type(m.result)=="table"then latest[p]=q.kind=="Status"and m.result or m.result.state end
            end
        end
    end)
    local function check(name,expected,observed,pass)
        result.checks[#result.checks+1]={name=name,expected=expected,observed=observed,pass=pass==true,at=workspace:GetServerTimeNow()}
        if not pass then error(name,0)end
    end
    local function waitFor(name,seconds,predicate)
        local deadline=os.clock()+seconds;local observed
        repeat
            if finished then error("Test ended",0)end
            local pass,value=predicate();observed=value;if pass then return value end
            task.wait(.04)
        until os.clock()>=deadline
        check(name,"Observed within "..seconds.."s",observed,false)
    end
    local function send(p,kind,fields)
        assert(real(p),"Only actual current Player instances may receive commands")
        serial+=1;local id=tostring(serial);local now=workspace:GetServerTimeNow()
        local evidence={id=id,kind=kind,name=p.Name,userId=p.UserId,sentAt=now,replied=false,
            args=kind=="Drive"and{mode=fields.mode,fighterSlot=fields.fighterSlot,timeout=fields.timeout}or fields}
        local q={id=id,kind=kind,player=p,sentAt=now,evidence=evidence};pending[id]=q;result.commands[#result.commands+1]=evidence
        command:FireClient(p,{id=id,kind=kind,args=fields or {}});return q
    end
    local function await(q)
        local ok,err=pcall(function()waitFor("Actual client "..q.player.Name.." "..q.kind.." reply",10,function()return q.reply~=nil,q.evidence end)end)
        if not ok then q.evidence.timedOut=true;q.evidence.lastSeen=lastSeen[q.player];q.evidence.heartbeat=lastBeat[q.player];q.evidence.latest=latest[q.player];error(err,0)end
        pending[q.id]=nil;check("Actual client "..q.player.Name.." "..q.kind.." executes",true,q.reply.ok,q.reply.ok==true)
        return q.kind=="Status"and q.reply.result or q.reply.result.state
    end
    local function ask(p,kind,fields)return await(send(p,kind,fields))end
    local function askAll(list,kind,fields)
        local qs,out={},{};for i,p in ipairs(list)do qs[i]=send(p,kind,type(fields)=="function"and fields(p,i)or fields or {})end
        for i,q in ipairs(qs)do out[i]=await(q)end;return out
    end
    local function actor(p,kind,fields)
        local packet={kind=kind};for k,v in pairs(fields or {})do packet[k]=v end;return ask(p,"Actor",packet)
    end
    local function leaveActual(player)
        check("Departing participant is an actual current client",true,real(player),real(player))
        local departingSlot=c.ownerSlots[player.UserId]
        local beforeControlled=departingSlot and c.current.state.heroes[departingSlot]or c.director:controlled(player.UserId)
        local beforeEpoch=assert(beforeControlled and beforeControlled.connectionEpoch,"Departing role has no connection epoch")
        local rowBefore={at=workspace:GetServerTimeNow(),userId=player.UserId,name=player.Name,
            registryCurrent=hub.connections:isCurrent(player),connectionEpoch=beforeEpoch,state=state()}
        ask(player,"Leave")
        waitFor("Actual LeaveTest removes the Player and native connection",6,function()
            local slot=c.ownerSlots[player.UserId]
            local controlled=slot and c.current.state.heroes[slot]or c.director:controlled(player.UserId)
            return departed[player]~=nil and not real(player)and not hub.connections:isCurrent(player)
                and controlled~=nil and controlled.connected==false,
                {removingObserved=departed[player]~=nil,currentPlayer=real(player),
                    registryCurrent=hub.connections:isCurrent(player),controlled=controlled}
        end)
        local row=departed[player]
        row.before=rowBefore;row.observedDisconnectedAt=workspace:GetServerTimeNow()
        row.registryCurrentAfter=hub.connections:isCurrent(player);row.after=state()
        local controlled=departingSlot and c.current.state.heroes[departingSlot]or c.director:controlled(player.UserId)
        check("Actual departure advances the native role connection epoch",beforeEpoch+1,controlled.connectionEpoch,
            controlled.connected==false and controlled.connectionEpoch==beforeEpoch+1)
        for _,event in ipairs(c.current.logs)do
            if departingSlot and event.kind=="Connection"and event.userId==departingSlot and event.connected==false
                and event.data and event.data.code=="OK"then row.nativeConnectionEvent=event
            elseif not departingSlot and event.kind=="EnemyConnection"and event.data
                and event.data.ownerUserId==player.UserId and event.data.connected==false then row.nativeConnectionEvent=event end
        end
        check("Departure has the native connection journal event",true,row.nativeConnectionEvent~=nil,row.nativeConnectionEvent~=nil)
        check("Exactly one real participant departed",args.players-1,#Players:GetPlayers(),#Players:GetPlayers()==args.players-1)
        return row
    end
    local function synced(list)
        return waitFor("Clients observe exact production stage/identity",10,function()
            local ss=askAll(list,"Status");local valid=true
            for i,v in ipairs(ss)do local s=v.snapshot
                valid=valid and v.userId==list[i].UserId and v.sourceId==args.expectedSourceId and v.presentationDisabled
                    and s and s.groupId==group.id and s.runId==c.current.state.runId and s.levelEpoch==c.current.state.levelEpoch
                    and s.campaign and s.campaign.index==3 and not s.fault
            end
            return valid==true,ss
        end)
    end
    local function outcomeSynced()
        local reads=waitFor("Every actual client observes final authoritative outcome",8,function()
            local active=remainingMembers()
            local ss=askAll(active,"Status");local matches=#active==args.players-#result.departures;local details={}
            local session=c.current
            for index,value in ipairs(ss)do
                local snapshot=value.snapshot;local valid=real(active[index])and value.userId==active[index].UserId
                    and value.sourceId==args.expectedSourceId and snapshot~=nil
                    and snapshot.groupId==group.id and snapshot.worldName==c.world.folder.Name
                    and snapshot.runId==session.state.runId and snapshot.levelEpoch==session.state.levelEpoch
                    and not snapshot.fault and type(snapshot.heroes)=="table"and #snapshot.heroes==#session.order
                local compared={}
                for _,slot in ipairs(session.order)do
                    local current=session.state.heroes[slot];local seen
                    for _,hero in ipairs(snapshot and snapshot.heroes or {})do if hero.slot==slot then seen=hero;break end end
                    local heroMatches=seen~=nil and seen.actorId==current.actorId and seen.attempt==current.attempt
                        and seen.respawns==current.respawns and seen.status==current.status
                        and seen.connected==current.connected and seen.connectionEpoch==current.connectionEpoch
                        and(seen.rawLife==nil or seen.rawLife==session.combat[slot].rawLife)
                    compared[#compared+1]={slot=slot,pass=heroMatches,server={actorId=current.actorId,attempt=current.attempt,
                        respawns=current.respawns,rawLife=session.combat[slot].rawLife,status=current.status},client=seen}
                    valid=valid and heroMatches
                end
                local ownSlot=c.ownerSlots[active[index].UserId]
                if ownSlot then
                    local current=session.state.heroes[ownSlot]
                    valid=valid and snapshot.mine==ownSlot and value.body~=nil and value.body.actorId==current.actorId
                elseif active[index]==enemyPlayer then
                    local expected=c.director:controlled(enemyPlayer.UserId);local seen=snapshot and snapshot.enemyRole
                    valid=valid and expected~=nil and expected.status=="Dead"and seen~=nil
                        and seen.status=="Dead"and seen.actorId==expected.actorId
                end
                local expectedEnemy=enemyPlayer and c.director:controlled(enemyPlayer.UserId)
                if args.scenario=="InvaderDisconnect"and expectedEnemy and expectedEnemy.status=="Dead"then
                    local authoritative=c.director.enemies[expectedEnemy.enemyId];local seenEnemy
                    for _,enemy in ipairs(snapshot and snapshot.level and snapshot.level.enemies or {})do
                        if enemy.id==expectedEnemy.enemyId then seenEnemy=enemy;break end
                    end
                    local deathAt
                    for _,event in ipairs(session.logs)do
                        if event.kind=="EnemyDeath"and event.data and event.data.actorId==expectedEnemy.actorId then deathAt=event.now end
                    end
                    valid=valid and authoritative~=nil and seenEnemy~=nil and seenEnemy.dead==true
                        and seenEnemy.kind==authoritative.kind and type(snapshot.now)=="number"
                        and deathAt~=nil and snapshot.now>=deathAt
                end
                matches=matches and valid
                details[#details+1]={name=active[index].Name,userId=active[index].UserId,pass=valid,
                    snapshotSeq=snapshot and snapshot.snapshotSeq,heroes=compared,enemyRole=snapshot and snapshot.enemyRole}
            end
            if matches then return true,ss end
            return false,details
        end)
        result.finalClients=reads
        result.finalParticipantCount=#remainingMembers();result.finalOriginalParticipantCount=#reads
        check(result.lateArrival and "Final outcome replicated to every remaining original participant"
            or #result.departures>0 and "Final outcome replicated to every remaining actual participant"
            or "Final outcome replicated to every actual participant",args.players-#result.departures,#reads,
            #reads==args.players-#result.departures)
        return reads
    end
    local function approach(p,slot,targetSlot,range,seconds)
        local deadline=os.clock()+seconds
        repeat
            local from,to=c.world:position(slot),c.world:position(targetSlot);assert(from and to,"Approach body missing")
            local d=distance(from,to)
            if d<=range then actor(p,"Move",{x=0,z=0,run=false});return end
            actor(p,"Move",{x=(to.x-from.x)/math.max(d,1),z=(to.z-from.z)/math.max(d,1),run=false})
            task.wait(.1)
        until os.clock()>=deadline
        check("Actual client approaches target",range,distance(c.world:position(slot),c.world:position(targetSlot)),false)
    end
    local function findKind(kind)
        for id,e in pairs(c.director.enemies)do if e.kind==kind and not e.dead then return id,e end end
    end
    local function claim(kind)
        local id,e=waitFor("Existing "..kind.." offer",15,function()local n,v=findKind(kind);return n~=nil,n and{id=n,enemy=v}end)
        -- waitFor returns the value, not multiple Lua return values.
        e=id.enemy;id=id.id
        local body=c.world.actors[id];local actorId=e.actorId
        ask(enemyPlayer,"Menu",{kind="ClaimEnemy",runId=c.current.state.runId,levelEpoch=c.current.state.levelEpoch,enemyId=id})
        waitFor("Production claim owns original "..kind,3,function()return e.ownerUserId==enemyPlayer.UserId,{owner=e.ownerUserId,engaged=e.engaged}end)
        check("Claim preserves physical "..kind.." body",actorId,c.world.actors[id]and c.world.actors[id].model:GetAttribute("ActorId"),
            c.world.actors[id]==body and e.actorId==actorId and body.model:GetAttribute("ActorId")==actorId)
        result.claimClient=waitFor("Enemy client observes original controlled actor",3,function()
            local v=ask(enemyPlayer,"Status");local role=v.snapshot and v.snapshot.enemyRole
            return role~=nil and role.actorId==actorId and v.body~=nil and v.body.actorId==actorId,v
        end)
        return id,e,body
    end
    local function invader()
        -- Claim immediately after stage preparation. Snapshot polling first would
        -- spend the ordinary NPC's finite pre-engagement offer window.
        local id,e,body=claim("Invader")
        result.initialClients=synced(members)
        local heroPlayer=heroes[1];local slot=c.ownerSlots[heroPlayer.UserId]
        local before=state();result.before=before
        waitFor("Original hero spawn shield expires naturally",4,function()local h=c.current.state.heroes[slot];return not h.shield or workspace:GetServerTimeNow()>=h.shield.deadline,h.shield and h.shield.deadline end)
        local origin=copyPoint(c.world:position(id));approach(enemyPlayer,id,slot,8,8)
        check("Human Invader movement changes same body position",">1 stud",distance(origin,c.world:position(id)),distance(origin,c.world:position(id))>1 and c.world.actors[id]==body)
        local victimId=c.current.state.heroes[slot].actorId
        local victimBody=c.world.actors[slot];local victimModel=victimBody.model
        actor(enemyPlayer,"Attack",{attack="Punch"})
        waitFor("Native Invader theft removes exactly raw8",4,function()return c.current.combat[slot].rawLife==39,{rawLife=c.current.combat[slot].rawLife,actorId=c.current.state.heroes[slot].actorId}end)
        result.stolen=state();local escapeAt=assert(e.lifeEscapeAt,"Theft did not establish finite escape")
        local theftEvent
        for _,event in ipairs(c.current.logs)do
            if event.kind=="LifeStolen"and event.userId==slot and event.actorId==victimId and event.data.before==47 and event.data.after==39 then theftEvent=event;break end
        end
        check("Actual theft journal belongs to original hero",victimId,theftEvent,theftEvent~=nil)
        if args.scenario=="InvaderDisconnect"then
            local attacks=0;for _,event in ipairs(c.current.logs)do
                if event.kind=="CampaignEnemyAttack"and(event.actorId or event.data and event.data.actorId)==e.actorId then attacks+=1 end
            end
            check("Human Invader attack is present before departure",">=1",attacks,attacks>=1)
            result.enemyDeparture=leaveActual(enemyPlayer)
            check("Disconnected Invader retains original owner, body and deadline",escapeAt,e.lifeEscapeAt,
                e.ownerUserId==enemyPlayer.UserId and e.connected==false and e.connectionEpoch==2
                    and e.actorId==body.model:GetAttribute("ActorId")and c.world.actors[id]==body and e.lifeEscapeAt==escapeAt)
            result.attacksBeforeDeparture=attacks
        end
        if result.invaderOutcome=="Return"then
            waitFor("Invader attack finishes on its original body",2,function()
                local mode=c.director.campaignEnemies.states[id]
                return mode~=nil and mode.mode=="Ready",mode and mode.mode
            end)
            approach(heroPlayer,slot,id,2.8,2)
            local p,q=c.world:position(slot),c.world:position(id);local d=distance(p,q)
            actor(heroPlayer,"Move",{x=d>.05 and(q.x-p.x)/d*.1 or .1,z=d>.05 and(q.z-p.z)/d*.1 or 0,run=false})
            actor(heroPlayer,"Attack",{attack="Punch"})
            waitFor("Native hero hit returns linked raw8 to original living actor",3,function()return c.current.combat[slot].rawLife==47,{rawLife=c.current.combat[slot].rawLife,enemyDead=e.dead}end)
            local victim=c.current.state.heroes[slot]
            check("Return retains victim identity, physical body and stock",victimId,state().heroes[slot],
                victim.actorId==victimId and victim.attempt==1 and victim.respawns==3 and c.current.combat[slot].rawLife==47
                    and c.world.actors[slot]==victimBody and c.world.actors[slot].model==victimModel)
            local recovery
            for _,event in ipairs(c.current.logs)do
                if event.kind=="StolenLifeRecovered"and event.userId==slot and event.actorId==victimId and event.attempt==1
                    and event.data.before==39 and event.data.after==47 then recovery=event;break end
            end
            result.recoveryEvent=recovery
            check("Original hero's linked return has an authoritative journal event",victimId,recovery,recovery~=nil)
            check("Invader spends its original life after hero hit",true,e.dead,e.dead==true)
        else
            waitFor("Invader escapes at original finite deadline",7,function()return e.dead==true,{dead=e.dead,escapeAt=escapeAt,now=workspace:GetServerTimeNow()}end)
            local victim=c.current.state.heroes[slot]
            check("Escape does not refund or replace the victim",39,state().heroes[slot],c.current.combat[slot].rawLife==39
                and victim.actorId==victimId and victim.attempt==1 and victim.respawns==3
                and c.world.actors[slot]==victimBody and c.world.actors[slot].model==victimModel)
            local recoveries=0;for _,event in ipairs(c.current.logs)do if event.kind=="StolenLifeRecovered"then recoveries+=1 end end
            check("Uninterrupted escape has no false recovery event",0,recoveries,recoveries==0)
            check("Escape deadline remains five seconds after theft",5,escapeAt-result.stolen.at,math.abs(escapeAt-result.stolen.at-5)<1.2)
        end
        local role=c.director:controlled(enemyPlayer.UserId)
        check("Spent enemy owner has no new playable life","Dead",role and role.status,role and role.status=="Dead")
        if args.scenario=="InvaderDisconnect"then
            local attacks=0;for _,event in ipairs(c.current.logs)do
                if event.kind=="CampaignEnemyAttack"and(event.actorId or event.data and event.data.actorId)==e.actorId then attacks+=1 end
            end
            check("Departure does not hand Invader back to NPC attacks",result.attacksBeforeDeparture,attacks,
                attacks==result.attacksBeforeDeparture and e.ownerUserId==enemyPlayer.UserId and role.connected==false)
            check("Offline Invader retains original finite escape deadline",5,escapeAt-theftEvent.now,
                math.abs(escapeAt-theftEvent.now-5)<.05 and e.lifeEscapeAt==escapeAt)
        end
        outcomeSynced()
    end
    local function heroCrash()
        local s,m=c.current,c.director.modes;result.before=state();local beforeBodies={};local lastRiding
        local offlineBody,offlineModel,offlineId
        local offline=args.scenario=="HeroDisconnectCrash"
        ridingObserver=function()
            if m.vehicleGroup.serial==0 and m.vehicleGroup.phase=="Riding"then
                -- Capture a fresh immutable value after entry combat and boarding.
                lastRiding=state()
                for _,slot in ipairs(s.order)do beforeBodies[slot]=c.world.actors[slot]end
            end
        end
        askAll(heroes,"Drive",function(_,i)return{course=c.director.definition.course,mode=not offline and i==1 and"Crash"or"Course",fighterSlot=1,timeout=60}end)
        if offline then
            local departingPlayer=heroes[#heroes];local slot=c.ownerSlots[departingPlayer.UserId]
            waitFor("Every actual hero boards before survivor departure",40,function()
                local all=m.vehicleGroup.phase=="Riding";for _,heroSlot in ipairs(s.order)do all=all and m.actors[heroSlot].mounted==true end
                return all,{phase=m.vehicleGroup.phase}
            end)
            offlineBody=c.world.actors[slot];offlineModel=offlineBody.model;offlineId=s.state.heroes[slot].actorId
            result.heroDeparture=leaveActual(departingPlayer);result.offlineSlot=slot
            local from=copyPoint(m.actors[slot].position)
            waitFor("Disconnected living rider continues native automatic travel",2,function()
                local h=s.state.heroes[slot];local a=m.actors[slot]
                return h.connected==false and h.status=="Alive"and a.position.x>=from.x+3,
                    {connected=h.connected,status=h.status,from=from,position=copyPoint(a.position)}
            end)
            result.offlineAdvance={from=from,to=copyPoint(m.actors[slot].position),actorId=s.state.heroes[slot].actorId}
            check("Offline automatic travel keeps original physical hero",offlineId,s.state.heroes[slot].actorId,
                c.world.actors[slot]==offlineBody and s.state.heroes[slot].actorId==offlineId
                    and s.state.heroes[slot].attempt==1 and s.state.heroes[slot].respawns==3)
            local input=m.actors[slot].input
            check("Departed rider receives no residual steering",{x=0,z=0},{x=input.x,z=input.z},input.x==0 and input.z==0)
            ask(heroes[1],"Drive",{course=c.director.definition.course,mode="Crash",fighterSlot=1,timeout=60})
        end
        waitFor("Real client causes native authored-hazard group crash",60,function()return m.vehicleGroup.serial>=1,{serial=m.vehicleGroup.serial,phase=m.vehicleGroup.phase}end)
        result.crashed=state();result.lastRiding=lastRiding;ridingObserver=nil
        check("Immutable Riding resource snapshot precedes first crash",true,lastRiding~=nil,lastRiding~=nil)
        askAll(remainingMembers(),"Stop")
        waitFor("Native group rewind resumes riding",8,function()return m.vehicleGroup.serial==1 and m.vehicleGroup.phase=="Riding",{serial=m.vehicleGroup.serial,phase=m.vehicleGroup.phase}end)
        waitFor("Only collided hero receives paid replacement",5,function()local h=s.state.heroes[1];return h.attempt==2,{attempt=h.attempt,status=h.status,respawns=h.respawns}end)
        result.rewound=state()
        local victim=s.state.heroes[1]
        check("Collided hero pays exactly one stock and replaces body",{attempt=2,respawns=2},result.rewound.heroes[1],victim.attempt==2 and victim.respawns==2 and c.world.actors[1]~=beforeBodies[1])
        for _,slot in ipairs(s.order)do if slot~=1 then
            local h=s.state.heroes[slot];local before=lastRiding.heroes[slot]
            check("Surviving real hero "..slot.." preserves body, health and stock",before,result.rewound.heroes[slot],
                c.world.actors[slot]==beforeBodies[slot]and h.actorId==before.actorId and h.attempt==before.attempt and h.respawns==before.respawns and s.combat[slot].rawLife==before.rawLife)
        end end
        check("Exactly one native group rewind",1,m.vehicleGroup.serial,m.vehicleGroup.serial==1)
        if offline then
            local slot=result.offlineSlot;local h=s.state.heroes[slot];local commits=0
            for _,event in ipairs(s.logs)do if event.kind=="CommitSpawn"and event.userId==slot
                and event.now>=result.heroDeparture.removingAt then commits+=1 end end
            check("Offline survivor remains disconnected through native rewind",false,h.connected,
                h.connected==false and h.connectionEpoch==2 and h.status=="Alive"and h.actorId==offlineId
                    and c.world.actors[slot]==offlineBody and c.world.actors[slot].model==offlineModel)
            check("Offline survivor receives no replacement spawn",0,commits,commits==0)
        end
        outcomeSynced()
    end
    local function rocketRat()
        local session,modes,family=c.current,c.director.modes,c.director.campaignEnemies
        assert(family and type(family.vehicleObstacleHit)=="function","Native obstacle collision callback missing")
        local originalHit=family.vehicleObstacleHit;local causalBodies
        family.vehicleObstacleHit=function(slot,owner,actorId)
            -- Observe provenance and call the exact native callback once, unchanged.
            local before=state();local hero=session.state.heroes[slot];local bodies={}
            for _,heroSlot in ipairs(session.order)do bodies[heroSlot]=c.world.actors[heroSlot]end
            local evidence={at=workspace:GetServerTimeNow(),slot=slot,sourceEnemyId=owner,sourceActorId=actorId,
                serialBefore=modes.vehicleGroup.serial,phaseBefore=modes.vehicleGroup.phase,
                victimActorId=hero and hero.actorId,before=before}
            if args.scenario=="RocketRatDisconnect"then
                local ownerRole=c.director:controlled(enemyPlayer.UserId)
                evidence.ownerCurrent=real(enemyPlayer);evidence.ownerRegistryCurrent=hub.connections:isCurrent(enemyPlayer)
                evidence.ownerConnected=ownerRole and ownerRole.connected
            end
            local handled=originalHit(slot,owner,actorId)
            evidence.handled=handled;evidence.serialAfter=modes.vehicleGroup.serial;evidence.phaseAfter=modes.vehicleGroup.phase
            if evidence.serialAfter>evidence.serialBefore then causalBodies=bodies end
            evidence.after=state();if #result.contacts<16 then result.contacts[#result.contacts+1]=evidence end
            return handled
        end
        askAll(heroes,"Drive",{course=c.director.definition.course,mode="Course",fighterSlot=1,timeout=60})
        local id,e,body=claim("RocketRat")
        local actorId=e.actorId;local ratState=assert(family.states[id]);local trajectory=e.trajectory
        result.ratClaim={id=id,actorId=actorId,ownerUserId=e.ownerUserId,at=workspace:GetServerTimeNow(),
            elapsed=family.now-ratState.startAt,samePhysicalBody=c.world.actors[id]==body,trajectory=trajectory}
        check("Human claims naturally spawned rat before native auto-drop",false,ratState.dropped,
            not ratState.dropped and family.now-ratState.startAt<(trajectory.dropAt or 1.5)-.2)
        local sequence=e.lastSeq or 0
        actor(enemyPlayer,"Move",{x=-1,z=0,run=false})
        waitFor("Human rat Move passes production role envelope",1,function()return(e.lastSeq or 0)>sequence,{lastSeq=e.lastSeq,notice=c.notices[enemyPlayer]}end)
        local elapsed=family.now-ratState.startAt;local fraction=math.clamp(elapsed/trajectory.duration,0,1)
        local expected={x=trajectory.from.x+(trajectory.to.x-trajectory.from.x)*fraction,
            y=trajectory.from.y+(trajectory.to.y-trajectory.from.y)*fraction,z=trajectory.from.z+(trajectory.to.z-trajectory.from.z)*fraction}
        local position=c.world:position(id)
        check("Human movement preserves authored rat trajectory",expected,position,distance(expected,position)<1 and math.abs(expected.y-position.y)<1)
        actor(enemyPlayer,"Jump")
        waitFor("Native rat Jump has NO_JUMP denial",1,function()return c.notices[enemyPlayer]=="NO_JUMP",c.notices[enemyPlayer]end)
        local targetPlayer=heroes[1];local targetSlot=c.ownerSlots[targetPlayer.UserId]
        if args.scenario=="RocketRatDisconnect"then
            -- Earn lateral alignment while there is still forward runway. Waiting
            -- until LeaveTest has completed can make a real early drop unreachable.
            ask(targetPlayer,"Stop")
            local own=modes.actors[targetSlot];local lane=c.world:position(id).z
            actor(targetPlayer,"Move",{x=0,z=math.clamp((lane-own.position.z)*.8,-1,1),run=false})
            result.preDropSteering={at=workspace:GetServerTimeNow(),slot=targetSlot,
                position=copyPoint(own.position),targetLane=lane}
        end
        local dropStarted=workspace:GetServerTimeNow();sequence=e.lastSeq or 0
        actor(enemyPlayer,"Attack",{attack="Punch"})
        local drop=waitFor("Human primary creates original rat's sole obstacle",1,function()
            for projectileId,p in pairs(family.projectiles)do
                if p.owner==id and p.actorId==actorId and p.mode=="Obstacle"then
                    return true,{id=projectileId,owner=p.owner,actorId=p.actorId,created=p.created,
                        expiresAt=p.expiresAt,position=copyPoint(p.position),acceptedElapsed=p.created-ratState.startAt,
                        observedElapsed=family.now-ratState.startAt}
                end
            end
            return false,{dropped=ratState.dropped,lastSeq=e.lastSeq,notice=c.notices[enemyPlayer]}
        end)
        result.manualDrop=drop
        check("Drop accepted before authored auto-drop time",trajectory.dropAt or 1.5,drop.acceptedElapsed,
            drop.acceptedElapsed<(trajectory.dropAt or 1.5)and(e.lastSeq or 0)>sequence and drop.created>=dropStarted-.15)
        actor(enemyPlayer,"Attack",{attack="Punch"})
        waitFor("Second human drop is denied NO_AMMO",1,function()return c.notices[enemyPlayer]=="NO_AMMO",c.notices[enemyPlayer]end)
        if args.scenario=="RocketRatDisconnect"then
            local originalProjectile=assert(family.projectiles[drop.id],"Accepted obstacle disappeared before departure")
            result.enemyDeparture=leaveActual(enemyPlayer)
            local retained=family.projectiles[drop.id]
            check("Accepted original obstacle survives actual owner departure",drop.id,retained and retained.owner,
                retained==originalProjectile and retained.owner==id and retained.actorId==actorId
                    and retained.created==drop.created and retained.expiresAt==drop.expiresAt)
            check("Offline rat keeps original owner and trajectory body",actorId,e.actorId,
                e.ownerUserId==enemyPlayer.UserId and e.connected==false and e.connectionEpoch==2
                    and e.actorId==actorId and c.world.actors[id]==body)
        end
        result.beforeDropContact=state()
        -- Stop only the selected pilot; normal mounted X continues in production.
        if args.scenario~="RocketRatDisconnect"then ask(targetPlayer,"Stop")end
        local deadline=os.clock()+5
        repeat
            if modes.vehicleGroup.serial>=1 then break end
            local own=modes.actors[targetSlot]
            local steer=math.clamp((drop.position.z-own.position.z)*.8,-1,1)
            actor(targetPlayer,"Move",{x=0,z=steer,run=false})
            task.wait(.08)
        until os.clock()>=deadline
        local contact
        for _,row in ipairs(result.contacts)do
            if row.sourceEnemyId==id and row.sourceActorId==actorId and row.serialAfter>row.serialBefore then contact=row;break end
        end
        check("Original human rat obstacle causally triggers native vehicle crash",actorId,result.contacts,contact~=nil)
        check("Contact is the intended actual hero",targetSlot,contact.slot,contact.slot==targetSlot)
        result.causalContact=contact;askAll(heroes,"Stop")
        if args.scenario=="RocketRatDisconnect"then
            local departure=result.enemyDeparture
            check("Original rat obstacle contacts only after actual owner departure",true,
                {removingAt=departure.removingAt,connectionAt=departure.nativeConnectionEvent.now,contactAt=contact.at,
                    current=contact.ownerCurrent,registryCurrent=contact.ownerRegistryCurrent,connected=contact.ownerConnected},
                departure.removingAt<contact.at and departure.nativeConnectionEvent.now<=contact.at
                    and contact.ownerCurrent==false and contact.ownerRegistryCurrent==false and contact.ownerConnected==false)
        end
        waitFor("Native rat collision rewinds group and resumes Riding",8,function()
            return modes.vehicleGroup.serial==1 and modes.vehicleGroup.phase=="Riding",{serial=modes.vehicleGroup.serial,phase=modes.vehicleGroup.phase}
        end)
        waitFor("Rat-collided hero commits exactly one paid replacement",5,function()
            local h=session.state.heroes[targetSlot];return h.attempt==2,{attempt=h.attempt,respawns=h.respawns}
        end)
        result.rewound=state()
        local victim=session.state.heroes[targetSlot]
        check("Obstacle victim alone pays one life",{attempt=2,respawns=2},result.rewound.heroes[targetSlot],
            victim.attempt==2 and victim.respawns==2 and causalBodies~=nil and c.world.actors[targetSlot]~=causalBodies[targetSlot])
        for _,slot in ipairs(session.order)do if slot~=targetSlot then
            local h=session.state.heroes[slot];local before=contact.before.heroes[slot]
            check("Rat collision survivor "..slot.." retains body, health and stock",before,result.rewound.heroes[slot],
                causalBodies~=nil and c.world.actors[slot]==causalBodies[slot]and h.actorId==before.actorId and h.attempt==before.attempt
                    and h.respawns==before.respawns and session.combat[slot].rawLife==before.rawLife)
        end end
        local effects=0;for _,p in pairs(family.projectiles)do if p.owner==id and p.actorId==actorId then effects+=1 end end
        check("Course rewind removes original rat effects",0,effects,effects==0)
        local role=c.director:controlled(enemyPlayer.UserId)
        check("Rewind does not grant spent human rat another life","Dead",role and role.status,role and role.status=="Dead"and role.actorId==actorId)
        outcomeSynced()
    end
    local function offlineDeathLateJoin()
        local session,modes=c.current,c.director.modes
        local departingPlayer=heroes[#heroes];local slot=c.ownerSlots[departingPlayer.UserId]
        local originalRun=session.state.runId;local ownerIds={};local originalIds={}
        for _,player in ipairs(members)do originalIds[player.UserId]=true end
        for _,heroSlot in ipairs(session.order)do ownerIds[heroSlot]=c.owners[heroSlot].userId end
        result.lateJoinScope="AddPlayers creates a new actual UserId. This is a fixed-roster late-arrival test, not a same-account reconnect."
        askAll(heroes,"Drive",{course=c.director.definition.course,mode="Course",fighterSlot=1,timeout=60})
        waitFor("All heroes board before offline death scenario",40,function()
            local all=modes.vehicleGroup.phase=="Riding"
            for _,heroSlot in ipairs(session.order)do all=all and modes.actors[heroSlot].mounted==true end
            return all,{phase=modes.vehicleGroup.phase}
        end)
        local originalActorId=session.state.heroes[slot].actorId
        result.heroDeparture=leaveActual(departingPlayer);result.offlineSlot=slot
        waitFor("Disconnected rider naturally dies without steering or jump",20,function()
            local h=session.state.heroes[slot]
            return h.connected==false and h.status=="AwaitingRespawn",{status=h.status,connected=h.connected,
                attempt=h.attempt,respawns=h.respawns,position=c.world:position(slot)}
        end)
        result.offlineDeath=state();local afterDeath=session.state.heroes[slot]
        local deathEvent
        for _,event in ipairs(session.logs)do
            if event.kind=="ConfirmedDeath"and event.userId==slot and event.data
                and event.data.actorId==originalActorId and event.now>=result.heroDeparture.removingAt then deathEvent=event end
        end
        check("Offline death belongs to the original actual rider",originalActorId,deathEvent,deathEvent~=nil)
        check("Offline death spends no respawn before reconnect",{attempt=1,respawns=3},result.offlineDeath.heroes[slot],
            afterDeath.attempt==1 and afterDeath.respawns==3 and afterDeath.connected==false and afterDeath.connectionEpoch==2)
        result.offlineDeathEvent=deathEvent
        local requestedAt=workspace:GetServerTimeNow()
        local addOK,addError=pcall(function()STS:AddPlayers(1)end)
        check("Studio adds one actual late test client",true,addOK and true or tostring(addError),addOK)
        local newcomer=waitFor("New actual UserId becomes ready after rendering",60,function()
            local proof={}
            for _,player in ipairs(Players:GetPlayers())do
                if not originalIds[player.UserId]then
                    proof[#proof+1]={name=player.Name,userId=player.UserId,current=real(player),ready=ready[player]==true}
                    if real(player)and ready[player]and hub.connections:isCurrent(player)then return true,player end
                end
            end
            return false,proof
        end)
        local selected=assert(hub:selected(newcomer),"Late actual client has no selected group")
        local newIds=0;for _,player in ipairs(Players:GetPlayers())do if not originalIds[player.UserId]then newIds+=1 end end
        check("Exactly one new actual client joins after one departure",{players=args.players,newIds=1},
            {players=#Players:GetPlayers(),newIds=newIds},#Players:GetPlayers()==args.players and newIds==1)
        result.lateArrival={name=newcomer.Name,userId=newcomer.UserId,oldUserId=departingPlayer.UserId,
            requestedAt=requestedAt,readyObservedAt=workspace:GetServerTimeNow(),selectedGroupId=selected.id,
            actualPlayer=real(newcomer),registryCurrent=hub.connections:isCurrent(newcomer),
            differentObject=newcomer~=departingPlayer,differentUserId=newcomer.UserId~=departingPlayer.UserId}
        check("Late arrival is a new Player and UserId, not a reconnect",true,result.lateArrival,
            real(newcomer)and newcomer~=departingPlayer and not originalIds[newcomer.UserId]
                and newcomer.UserId~=departingPlayer.UserId and Players:GetPlayerByUserId(departingPlayer.UserId)==nil)
        check("Original fixed run remains active during late arrival","Active",session.state.status,
            c.current==session and session.state.runId==originalRun and session.state.status=="Active"and not c.director.result)
        check("Late arrival selects the original active fixed group",group.id,selected.id,selected.id==group.id)
        ask(newcomer,"Menu",{kind="SelectRole",role="Hero"})
        waitFor("Late client's hero selection is refused in the active run",3,function()
            return c.notices[newcomer]=="RUN_ACTIVE",c.notices[newcomer]
        end)
        result.lateClient=waitFor("Late actual client sees its own non-owner state",8,function()
            local value=ask(newcomer,"Status");local snapshot=value.snapshot
            return real(newcomer)and hub.connections:isCurrent(newcomer)and value.userId==newcomer.UserId
                and value.sourceId==args.expectedSourceId and value.presentationDisabled==true and snapshot~=nil
                and snapshot.groupId==group.id and snapshot.worldName==c.world.folder.Name
                and snapshot.runId==originalRun and snapshot.levelEpoch==session.state.levelEpoch
                and snapshot.status==session.state.status and snapshot.campaign and snapshot.campaign.index==c.campaignIndex
                and snapshot.mine==nil and c.ownerSlots[newcomer.UserId]==nil,value
        end)
        local ownersUnchanged=#session.order==#ownerIds and c.current==session and session.state.runId==originalRun
        for _,heroSlot in ipairs(session.order)do
            ownersUnchanged=ownersUnchanged and c.owners[heroSlot].userId==ownerIds[heroSlot]
                and c.ownerSlots[ownerIds[heroSlot]]==heroSlot
        end
        check("New UserId cannot inherit or replace fixed run owners",ownerIds,c.owners,
            ownersUnchanged and c.ownerSlots[newcomer.UserId]==nil)
        local finalOffline=session.state.heroes[slot];local commits=0
        for _,event in ipairs(session.logs)do if event.kind=="CommitSpawn"and event.userId==slot
            and event.now>=deathEvent.now then commits+=1 end end
        check("Offline slot still awaits its own identity without spending stock",{attempt=1,respawns=3},state().heroes[slot],
            finalOffline.status=="AwaitingRespawn"and finalOffline.connected==false and finalOffline.connectionEpoch==2
                and finalOffline.attempt==1 and finalOffline.respawns==3 and session.combat[slot].rawLife==0)
        check("Late new identity does not commit the offline respawn",0,commits,commits==0)
        result.lateArrival.actualPlayersAtOutcome=#Players:GetPlayers()
        result.lateArrival.originalOwnerUserIds=ownerIds
        askAll(remainingMembers(),"Stop")
        outcomeSynced()
    end
    task.spawn(function()
        local ok,err=xpcall(function()
            check("Exact expected source identity",args.expectedSourceId,hub.deps.BuildId,type(args.expectedSourceId)=="string"and #args.expectedSourceId>0 and args.expectedSourceId==hub.deps.BuildId)
            local heroScenario=args.scenario=="HeroCrash"or args.scenario=="HeroDisconnectCrash"or args.scenario=="HeroOfflineDeathLateJoin"
            check("Supported role/crash scenario","Invader/RocketRat/HeroCrash with optional actual disconnect",args.scenario,
                args.scenario=="Invader"or args.scenario=="InvaderDisconnect"or heroScenario
                    or args.scenario=="RocketRat"or args.scenario=="RocketRatDisconnect")
            check("Actual client count","Integer2..4",args.players,type(args.players)=="number"and args.players%1==0 and args.players>=2 and args.players<=4)
            local hc=args.heroes or(heroScenario and args.players or args.players-1);result.heroes=hc
            check("Actual hero/enemy roster",args.players,hc,type(hc)=="number"and hc%1==0 and hc>=1 and hc<=3 and args.players==hc+(heroScenario and 0 or 1))
            members=waitFor("Actual clients ready after rendering",90,function()
                local list=Players:GetPlayers();local count=0;for _,p in ipairs(list)do if real(p)and ready[p]then count+=1 end end
                return #list==args.players and count==args.players,#list==args.players and count==args.players and list or{actual=#list,ready=count}
            end)
            group=assert(hub:selected(members[1]));members=hub:members(group.id,Players:GetPlayers());c=group.controller
            local proof={};for _,p in ipairs(members)do proof[#proof+1]={name=p.Name,userId=p.UserId,type=typeof(p),class=p.ClassName,current=real(p),registryCurrent=hub.connections:isCurrent(p),groupId=hub:selected(p).id}end
            check("Actual Player registry and one-group proof",args.players,proof,#members==args.players)
            check("Fresh production lobby",true,c.current==nil,c.current==nil)
            heroes={};for i,p in ipairs(members)do if i<=hc then heroes[#heroes+1]=p else enemyPlayer=p end end
            askAll(members,"Menu",function(_,i)return{kind="SelectRole",role=i<=hc and"Hero"or"Enemy"}end)
            waitFor("Production role preferences acknowledged",4,function()local pass=true;for i,p in ipairs(members)do pass=pass and c.preferences[p.UserId]==(i<=hc and"Hero"or"Enemy")end;return pass,pass end)
            local templates={"Mr. Green","Mr. Yellow","Mr. Brown"};askAll(heroes,"Menu",function(_,i)return{kind="SelectHero",template=templates[i]}end)
            waitFor("Production hero choices acknowledged",4,function()local pass=true;for i,p in ipairs(heroes)do pass=pass and c.choices[p.UserId]==templates[i]end;return pass,pass end)
            ask(heroes[1],"Menu",{kind="Start"})
            waitFor("Actual production Start observed",8,function()return c.current~=nil and #c.current.order==hc,c.current and #c.current.order end)
            c.campaignSeed=result.seed;c:_advanceCampaign(workspace:GetServerTimeNow());c:_advanceCampaign(workspace:GetServerTimeNow())
            check("Explicit stage3 preparation",3,c.campaignIndex,c.campaignIndex==3)
            local lastSample=0;observer=RS.Heartbeat:Connect(function()
                if not finished then
                    if ridingObserver then ridingObserver()end
                    if os.clock()-lastSample>=.1 and #result.trace<900 then lastSample=os.clock();result.trace[#result.trace+1]=state()end
                end
            end)
            if args.scenario=="Invader"or args.scenario=="InvaderDisconnect"then invader()
            else
                result.initialClients=synced(members)
                if args.scenario=="HeroOfflineDeathLateJoin"then offlineDeathLateJoin()
                elseif heroScenario then heroCrash()else rocketRat()end
            end
            check("Production controller remains fault free",false,c.faulted,c.faulted~=true)
            finish("PASS")
        end,debug.traceback)
        if not ok then finish("FAIL",tostring(err))end
    end)
    return true
end
return Acceptance
