-- Generated from exact repo adapter + production sender. See build_contract.py.
local MAX_RATE=require('../../src/stand/server/Config').MaxIntentRate
assert(MAX_RATE==40,'Reassess the recorded production rate budget')
local function simulate(options)
    local clock,events,replies,requestIndex=0,{},{},0
    local snapshot={groupId='delivery-contract',status='Active',runId='delivery-contract-run',levelEpoch=1,view='Playing'}
    local controlled={status='Alive',connected=true,actorId='delivery-contract-run:actor:1',attempt=1,connectionEpoch=1}
    local sequence=0
    local spectatorCamera={isFree=function()return false end}
    local tokens,lastToken=MAX_RATE,0
    local rejected,originalCalls=0,0
    local intent={}
    function intent:FireServer(packet)
        tokens=math.min(MAX_RATE,tokens+(clock-lastToken)*MAX_RATE);lastToken=clock
        local allowed=tokens>=1
        if allowed then tokens-=1 else rejected+=1 end
        events[#events+1]={at=clock,packet=table.clone(packet),allowed=allowed}
    end
local function sendIntent(packet)
    local envelope = table.clone(packet)
    if snapshot then
        if type(snapshot.groupId) ~= "string" or snapshot.groupId == "" then return end
        envelope.groupId = snapshot.groupId
    elseif envelope.kind ~= "Sync" then return end
    intent:FireServer(envelope)
end

local function playable()
    return snapshot and snapshot.status == "Active" and controlled and controlled.status == "Alive"
        and controlled.connected == true and not controlled.dying and not snapshot.fault
        and (snapshot.view == nil or snapshot.view == "Playing") and not spectatorCamera:isFree()
end
local function send(kind, extra)
    if not playable() or not snapshot.runId or not controlled.actorId then return end
    if snapshot.enemyRole and kind == "Attack" and extra and extra.attack ~= "Punch" then return end
    if snapshot.enemyRole and snapshot.enemyRole.template == "Boss" and kind == "Jump" then return end
    if snapshot.interaction and snapshot.interaction.carrying and kind == "Attack" and extra and extra.attack == "Dash" then return end
    sequence += 1
    local packet = {kind = kind, runId = snapshot.runId, actorId = controlled.actorId,
        attempt = controlled.attempt, levelEpoch = snapshot.levelEpoch,
        connectionEpoch = controlled.connectionEpoch, seq = sequence}
    for key, value in pairs(extra or {}) do packet[key] = value end
    sendIntent(packet)
end

    local sendMovement=function()originalCalls+=1 end
    local RunService={IsStudio=function()return true end}
    local workspace={GetServerTimeNow=function()return clock end}
    local _G={}
    local thread
    local task={}
    function task.spawn(callback)thread=coroutine.create(callback)end
    function task.wait(duration)return coroutine.yield({due=clock+duration})end
    local planRemote={}
    function planRemote:InvokeServer()
        requestIndex+=1
        local rtt=options.rtt(requestIndex)
        local response=options.reply(requestIndex)
        replies[#replies+1]={at=clock+rtt,plannedAt=clock+rtt/2,value=response}
        return coroutine.yield({due=clock+rtt,response=response})
    end
    local ReplicatedStorage={WaitForChild=function()return {WaitForChild=function()return planRemote end}end}
-- Append only to the disposable Studio client. Existing send()/sendIntent()
-- retain their normal identity, sequence, group and production RemoteEvent.
if RunService:IsStudio() then
    local qa={running=true,move={x=0,z=0,run=false},requests=0,started=workspace:GetServerTimeNow()}
    local original=sendMovement
    local lastMove=-math.huge
    sendMovement=function(force)
        if qa.running then
            local at=workspace:GetServerTimeNow()
            if force or at-lastMove>=.06 then lastMove=at;send('Move',{x=qa.move.x or 0,z=qa.move.z or 0,run=qa.move.run==true}) end
        else original() end
    end
    _G.BrickToadsFullCampaignClient=qa
    task.spawn(function()
        local planRemote=ReplicatedStorage:WaitForChild('BrickToadsFullCampaignQA'):WaitForChild('Plan')
        local startAt,lastPrimary=0,-math.huge
        while qa.running do
            local ok,r=pcall(function() return planRemote:InvokeServer() end)
            local now=workspace:GetServerTimeNow();qa.requests+=1
            if not ok then qa.error=tostring(r);qa.running=false;break end
            if r.done then qa.result=r.result;qa.error=r.error;qa.running=false;qa.move={x=0,z=0,run=false};send('Move',qa.move);break end
            if r.sync then sendIntent({kind='Sync'})
            elseif r.start and now>=startAt and snapshot then startAt=now+2;sendIntent({kind='Start'})
            elseif r.plan then
                qa.move=r.plan;sendMovement(r.plan.jump or r.plan.primary)
                if r.plan.jump then send('Jump') end
                if r.plan.primary and now-lastPrimary>=.13 then lastPrimary=now;send('Attack',{attack='Punch'}) end
            end
            task.wait(.08)
        end
    end)
end


    assert(thread,'Adapter must start its ordinary planner coroutine')
    local function resume(value)
        local ok,result=coroutine.resume(thread,value)
        assert(ok,result)
        return coroutine.status(thread)~='dead' and result or nil
    end
    local pending=resume(nil)
    local nextFrame=options.frameDt
    local moveElapsed=0
    while math.min(nextFrame,pending and pending.due or math.huge)<=options.duration+1e-9 do
        clock=math.min(nextFrame,pending and pending.due or math.huge)
        -- Preserve the production RenderStepped .1s elapsed/reset gate.
        -- Keepalive is first when timestamps tie, the suppressing boundary.
        if nextFrame<=clock+1e-9 then
            moveElapsed+=options.frameDt
            if moveElapsed>=.1 then moveElapsed=0;if playable()then sendMovement()end end
            nextFrame+=options.frameDt
        end
        if pending and pending.due<=clock+1e-9 then pending=resume(pending.response)end
    end
    return {events=events,replies=replies,rejected=rejected,qa=_G.BrickToadsFullCampaignClient,originalCalls=originalCalls}
end

local failures,passed=0,0
local function check(name,callback)
    local ok,reason=pcall(callback)
    if ok then passed+=1;print('PASS '..name)else failures+=1;print('FAIL '..name..': '..tostring(reason))end
end
local function plan(x,z,run,jump,primary)return {plan={x=x,z=z,run=run==true,jump=jump==true,primary=primary==true}}end
local function suppression(second)
    return simulate({duration=.205,frameDt=.1,rtt=function(n)return n==1 and .01 or .015 end,
        reply=function(n)return n==1 and plan(1,0)or second end})
end
local function firstMove(row,predicate)
    for _,e in ipairs(row.events)do if e.packet.kind=='Move'and predicate(e.packet)then return e end end
end

check('Changed axes send in the same client turn as the reply',function()
    local row=suppression(plan(0,1));local e=assert(firstMove(row,function(p)return p.z==1 end))
    print(' CLOCK changed-axis reply='..row.replies[2].at..' firstMove='..e.at..' addedDelay='..(e.at-row.replies[2].at))
    assert(math.abs(e.at-row.replies[2].at)<1e-8,'Render keepalive suppressed changed axes after the reply')
end)
check('Changed run flag sends in the same client turn as the reply',function()
    local row=suppression(plan(1,0,true));local e=assert(firstMove(row,function(p)return p.run end))
    assert(math.abs(e.at-row.replies[2].at)<1e-8,'Render keepalive suppressed changed run after the reply')
end)
check('Unchanged replies retain the .06 same-intent keepalive gate',function()
    local row=suppression(plan(1,0))
    for _,e in ipairs(row.events)do assert(math.abs(e.at-.105)>1e-8,'Unchanged reply sent an extra Move')end
    assert(#row.events==3,'Expected initial Move plus .1/.2 keepalives')
end)
check('Urgent Move precedes public Jump and Attack',function()
    local row=suppression(plan(1,0,false,true,true));local order={}
    for _,e in ipairs(row.events)do if math.abs(e.at-.105)<1e-8 then order[#order+1]=e.packet.kind end end
    assert(table.concat(order,',')=='Move,Jump,Attack','Urgent public sender order changed')
end)
check('Production sender preserves authentication envelope and sequence',function()
    local row=suppression(plan(0,1,false,true,true));local seq=0
    for _,e in ipairs(row.events)do local p=e.packet
        assert(p.groupId=='delivery-contract'and p.runId=='delivery-contract-run'and p.actorId=='delivery-contract-run:actor:1')
        assert(p.attempt==1 and p.levelEpoch==1 and p.connectionEpoch==1 and p.seq==seq+1);seq=p.seq
    end
end)
check('Terminal reply sends neutral Move through production sender',function()
    local row=simulate({duration=.115,frameDt=.1,rtt=function(n)return n==1 and .01 or .015 end,
        reply=function(n)return n==1 and plan(1,0)or{done=true,result='ContractDone'}end})
    assert(not row.qa.running and row.qa.result=='ContractDone')
    local last=row.events[#row.events].packet;assert(last.kind=='Move'and last.x==0 and last.z==0 and last.run==false)
end)

-- Saturate supported QA actions: every plan changes axes/run and requests both
-- Jump and primary. Attack still uses the adapter's unchanged .13s guard.
-- Two render cadences and three RPC clocks cover the zero-RTT upper plan rate
-- and alignments where keepalives interleave with the responses.
for _,frameDt in ipairs({1/60,1/30})do for _,rtt in ipairs({0,.02,.05})do
    check('Production40/s budget frame='..frameDt..' RTT='..rtt,function()
        local row=simulate({duration=30,frameDt=frameDt,rtt=function()return rtt end,
            reply=function(n)return n%2==0 and plan(-1,0,true,true,true)or plan(1,0,false,true,true)end})
        local counts={Move=0,Jump=0,Attack=0};local worst=0
        for i,e in ipairs(row.events)do
            counts[e.packet.kind]=(counts[e.packet.kind]or 0)+1
            local n=0;for k=i,1,-1 do if e.at-row.events[k].at>=1 then break end;n+=1 end;worst=math.max(worst,n)
        end
        print(' RATE packets='..#row.events..' Move='..counts.Move..' Jump='..counts.Jump..' Attack='..counts.Attack..' worstOneSecond='..worst..' rejected='..row.rejected)
        assert(row.rejected==0,'Normal production40/s token bucket would reject an intent')
        assert(worst<=40,'Sustained QA action clock exceeds the documented40/s budget')
    end)
end end
print('TOTAL_PASS',passed,'TOTAL_FAILURES',failures)
assert(failures==0,tostring(failures)..' client plan delivery contract failures')
