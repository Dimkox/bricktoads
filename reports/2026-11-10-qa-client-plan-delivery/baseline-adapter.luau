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

