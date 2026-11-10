-- Disposable append to the real bootstrap; no HP, actor, stock or pose writes.
if RunService:IsStudio() then
    local storage=game:GetService('ServerStorage')
    local result={sourceSha256=buildId,placeId=game.PlaceId,started=workspace:GetServerTimeNow(),
        mode='public client Move off edge; six God deaths then finite control',appearances={},errors={}}
    local lastActor
    local read=Instance.new('BindableFunction');read.Name='BrickToadsGodModeAcceptance';read.Parent=storage
    read.OnInvoke=function() return result end
    RunService.Heartbeat:Connect(function()
        if result.done then return end
        local ok,err=pcall(function()
            local group=controller.groups['group-1'];local c=group and group.controller
            if not c or not c.current then return end
            local s=c.current;local h=s.state.heroes[1]
            result.runId=s.state.runId;result.status=s.state.status;result.current=s:snapshot()
            if h.actorId and h.actorId~=lastActor then
                lastActor=h.actorId
                result.appearances[#result.appearances+1]={at=s.now,actorId=h.actorId,attempt=h.attempt,
                    stock=h.respawns,infiniteLives=h.infiniteLives,rawLife=s.combat[1].rawLife,
                    shield=h.shield and h.shield.kind,ownerUserId=c.owners[1].userId}
            end
            if h.attempt>=7 and not result.disabledAt then
                result.disabledAt=s.now;storage:SetAttribute('BrickToadsGodMode',false)
                result.stockAtDisable=h.respawns
            end
            if s.state.status=='Lost' then
                result.done=true;result.finished=s.now;result.journal=c.journal and c.journal:snapshot()
            end
        end)
        if not ok then result.errors[#result.errors+1]=tostring(err);result.done=true end
    end)
end
