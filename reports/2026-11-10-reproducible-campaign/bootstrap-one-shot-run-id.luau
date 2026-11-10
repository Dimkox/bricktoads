if RunService:IsStudio() then
    local first=assert(controller.groups[controller.order[1]]).controller
    assert(first.current==nil and first.director==nil,'QA identity must precede Start')
    local requested="bricktoads-qa-22-00-5530a024"
    assert(#requested<100 and first.deps.LevelVariation.seedFromId(requested)==1158731273)
    local original=first.deps.guid
    local identity={requestedRunId=requested,expectedSeed=1158731273,calls=0,installedBeforeStart=true}
    first.deps.guid=function()
        assert(first.current==nil and first.director==nil,'Unexpected identity request')
        first.deps.guid=original
        identity.calls+=1
        identity.restored=first.deps.guid==original
        identity.usedAt=workspace:GetServerTimeNow()
        return requested
    end
    local read=Instance.new('BindableFunction')
    read.Name='BrickToadsQAIdentityRead'
    read.OnInvoke=function()
        return game:GetService('HttpService'):JSONEncode({
            requestedRunId=identity.requestedRunId,expectedSeed=identity.expectedSeed,
            calls=identity.calls,installedBeforeStart=identity.installedBeforeStart,
            restored=first.deps.guid==original,usedAt=identity.usedAt,
            actualRunId=first.current and first.current.state.runId,
            actualCampaignSeed=first.campaignSeed,
            actualRouteSeed=first.deps.Config.Level.variation and first.deps.Config.Level.variation.seed,
            groupId=controller.order[1]})
    end
    read.Parent=game.ServerStorage
    _G.BrickToadsFullCampaignHub=controller
end
