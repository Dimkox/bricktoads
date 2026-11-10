-- Disposable append: existing send() supplies real production identity/sequence.
if RunService:IsStudio() then
    local active=true
    local originalMovement=sendMovement
    sendMovement=function(force)
        if active then send('Move',{x=0,z=1,run=false}) else originalMovement(force) end
    end
    task.spawn(function()
        local nextStart=0
        while active do
            local now=workspace:GetServerTimeNow()
            if snapshot and snapshot.status=='Lobby' and now>=nextStart then
                nextStart=now+2;sendIntent({kind='Start'})
            elseif snapshot and snapshot.status=='Lost' then
                active=false;send('Move',{x=0,z=0,run=false});break
            elseif snapshot and snapshot.status=='Active' then sendMovement(true) end
            task.wait(.10)
        end
    end)
end
