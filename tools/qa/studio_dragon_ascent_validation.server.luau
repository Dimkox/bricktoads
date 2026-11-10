-- Apply only inside the already captured reproducer. This replaces one world
-- method with the tested production implementation; it never changes actor,
-- health, reserve, geometry, collision, phase or completion state.
-- A subsequent fresh campaign is required for frozen-source acceptance.
local hub=assert(_G.BrickToadsFullCampaignHub)
local p=game.Players:GetPlayers()[1]
local group=assert(hub:selected(p))
local controller,world=group.controller,group.world
local factory=require(script.Parent.PatchedDragonWorldForValidation)
local methods=factory({new=function()end,move=function()end,setReaction=function()end,clearActors=function()end})
local proof={scope='Live source-method replacement in captured reproducer; not frozen-release acceptance',
    runId=controller.current.state.runId,seed=controller.campaignSeed,oldBuild=controller.journal.context.build,samples={}}
local read=Instance.new('BindableFunction');read.Name='BrickToadsDragonAscentValidation';read.Parent=game.ServerStorage
local function sample()
    local row={at=workspace:GetServerTimeNow(),enemies={},cohort={}}
    for _,id in ipairs({-9,-10}) do
        local enemy=controller.director.enemies[id]
        local body=world.actors[id]
        row.enemies[tostring(id)]={dead=enemy and enemy.dead==true,rawLife=enemy and enemy.rawLife,
            position=world:position(id),lift=world.dragonFlights[id]~=nil,
            velocityY=body and body.root.Parent and body.root.AssemblyLinearVelocity.Y,
            platformStand=body and body.humanoid.PlatformStand}
    end
    for slot,hero in pairs(controller.current.state.heroes) do
        row.cohort[#row.cohort+1]={slot=slot,actorId=hero.actorId,attempt=hero.attempt,stock=hero.respawns,
            status=hero.status,rawLife=controller.current.combat[slot].rawLife}
    end
    proof.samples[#proof.samples+1]=row
end
sample()
world.dragonAscentBlocked=methods.dragonAscentBlocked
world.dragonMotion=methods.dragonMotion
proof.appliedAt=workspace:GetServerTimeNow()
read.OnInvoke=function() return game.HttpService:JSONEncode(proof) end
task.spawn(function()
    for _=1,20 do task.wait(.1);sample() end
    proof.events={}
    for _,event in ipairs(controller.journal:snapshot().events) do
        if event.kind=='EnemyDeath' and (event.userId==-9 or event.userId==-10) then proof.events[#proof.events+1]=event end
    end
    proof.complete=true
end)
