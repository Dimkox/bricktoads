-- Pure snapshot presentation. Role authority and starting a new game stay on the server.
local Presentation={}
local bossNames={CausewayGuardian='Causeway Guardian',BigBlag='Big Blag',RoboManus='Robo-Manus',
    GeneralSlaughter='General Slaughter',Buzzball='Buzzball',DarkQueen='Dark Queen'}

function Presentation.bossName(enemy)
    -- Controlled snapshot.name may be the human owner's display name.
    return enemy and (bossNames[enemy.bossType] or
        (enemy.template=='Boss' and not enemy.bossType and 'Causeway Guardian') or enemy.name) or 'Boss'
end

function Presentation.menu(snapshot)
    snapshot=snapshot or {}
    local level=snapshot.level or {}
    local campaign=snapshot.campaign or {}
    local index=tonumber(campaign.index or level.campaignIndex)
    local count=tonumber(campaign.count or level.campaignCount)
    local stage=level.levelName or 'Flooded Causeway'
    local won=snapshot.status=='Won'
    local enemy=snapshot.enemyRole
    local result={title=stage,intro='Guard weapons, grabs and a Guardian. Cross the causeway together.',
        chooseTitle='CHOOSE YOUR HERO'}
    if snapshot.status=='Faulted' then
        result.title='Party stopped';result.resultTitle='PARTY STOPPED'
        result.resultDetail='An error stopped this party. The host can start a new game manually.'
        result.intro='A new party starts only when you press “Start again”.';result.chooseTitle='NEW PARTY'
        result.stopped=true
    elseif won or snapshot.status=='Lost' then
        local complete=won and (campaign.complete==true or (index~=nil and count~=nil and index>=count))
        result.success=(enemy~=nil and not won) or (enemy==nil and won)
        result.intro='Press “New game” to start the next attempt.';result.chooseTitle='HERO FOR THE NEXT GAME'
        if complete then
            result.title='Campaign complete'
            result.resultTitle=enemy and 'HEROES COMPLETED THE CAMPAIGN' or 'CAMPAIGN COMPLETE!'
            result.resultDetail='All {count:int} stages cleared. The Dark Queen is defeated. Choose roles for a new game.'
            result.resultArgs={count=count or index or 13}
        elseif index then
            result.resultTitle=enemy and (won and 'HEROES CLEARED THE STAGE' or 'HEROES STOPPED')
                or (won and 'STAGE CLEARED!' or 'TEAM ELIMINATED')
            result.resultDetail=won and '{stage} cleared. Choose roles for the next game.'
                or 'The heroes were stopped at {stage}. A new game starts from the first stage.'
            result.resultArgs={stage=stage}
        else
            -- Older standalone Causeway snapshots have no campaign metadata.
            result.resultTitle=enemy and (won and 'HEROES CLEARED THE CAUSEWAY' or 'HEROES STOPPED')
                or (won and 'CAUSEWAY CLEARED!' or 'TEAM ELIMINATED')
            result.resultDetail=won and 'The Guardian is defeated. The gate is open — the team reached the exit.'
                or 'The heroes have no respawns left. Choose roles and try the causeway again.'
        end
    elseif snapshot.status=='Active' and snapshot.view=='Menu' then
        result.title='The team is still playing'
        if enemy and enemy.status=='Dead' then
            if enemy.template=='Boss' then
                result.intro='{boss} is defeated. You can keep watching this game.'
                result.introArgs={boss=Presentation.bossName(enemy)}
            else result.intro='Your only life is over. You can keep watching this game.' end
        else result.intro='You can return to watching this same game.' end
    elseif index and index>1 then
        result.intro='Choose a role for this campaign.'
    end
    return result
end

function Presentation.reactionProgress(enemy)
    local maximum=enemy and tonumber(enemy.maxProgress)
    if not enemy or not enemy.bossType or not maximum or maximum<=0 then return nil end
    return 'Reaction progress: {count:int}/{maximum:int}',{
        count=math.clamp(tonumber(enemy.progress) or 0,0,maximum),maximum=maximum}
end

return Presentation
