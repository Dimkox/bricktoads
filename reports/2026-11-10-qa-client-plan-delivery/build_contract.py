"""Run the exact disposable adapter and production packet sender on a bounded clock.

Only the Roblox scheduler, RPC reply clock and RemoteEvent boundary are adapted.
No actor, game world, planner, hit, health or lifecycle simulation is supplied.
"""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--adapter', required=True)
parser.add_argument('--out', required=True)
args = parser.parse_args()
client = (ROOT / 'src/client/BrickToadsClient.client.luau').read_text()
send_intent = client[client.index('local function sendIntent(packet)'):client.index('local function chooseView(view)')]
send = client[client.index('local function playable()'):client.index('local actions = frame(controls, "Actions")')]
adapter = Path(args.adapter).read_text()

prelude = r'''-- Generated from exact repo adapter + production sender. See build_contract.py.
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
'''

environment = r'''
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
'''

scheduler = r'''
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
'''

Path(args.out).write_text(prelude + send_intent + send + environment + adapter + scheduler)
