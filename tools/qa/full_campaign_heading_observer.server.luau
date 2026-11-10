-- Disposable Studio server observation only; no gameplay or presentation writes.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer(),'Studio QA server only')
local Http=game:GetService('HttpService')
local run=assert(script:GetAttribute('ExpectedRunId'))
local sha=assert(script:GetAttribute('ExpectedSourceSha256'))
local report={schema=1,runId=run,sourceSha256=sha,samples={},observations=0,dropped=0,
    scope='Actual Clinger movement delta, hero facing, source pose and cosmetic vehicle forward; read-only'}
local last=0
local heartbeat=RunService.Heartbeat:Connect(function()
    local now=workspace:GetServerTimeNow();if now-last<.1 then return end;last=now
    local hub=_G.BrickToadsFullCampaignHub;if not hub then return end
    for _,group in pairs(hub.groups)do
        local session=group.controller and group.controller.current
        local world=group.world
        local modes=world and world.campaignModes
        if session and session.state.runId==run and modes and modes.mode=='Clinger'then
            for slot,actorState in pairs(modes.actors)do
                local actor=world.actors[slot]
                local row=world.campaignWorld and world.campaignWorld.objects['clinger-'..slot]
                local skin=row and row.courseAppearance
                if actor and actor.root.Parent and actor.humanoid.Health>0 and actorState.previous
                    and not actorState.finished and skin and skin.fit
                    and actor.model:GetAttribute('ActorId')==actorState.actorId then
                    local dx=actorState.position.x-actorState.previous.x
                    local dz=actorState.position.z-actorState.previous.z
                    local length=math.sqrt(dx*dx+dz*dz)
                    if length>.0001 then
                        local direction=Vector3.new(dx/length,0,dz/length)
                        local forward=(row.part.CFrame*skin.fit):VectorToWorldSpace(Vector3.new(0,0,-1))
                        report.observations+=1
                        if #report.samples<512 then report.samples[#report.samples+1]={
                            at=now,slot=slot,actorId=actorState.actorId,segment=actorState.segment,
                            mounted=actorState.mounted,mode=world:movementMode(slot),
                            poseKind=actor.appearance and actor.appearance.sourcePose and actor.appearance.sourcePose.kind,
                            dx=direction.X,dz=direction.Z,heroDot=actor.root.CFrame.LookVector:Dot(direction),
                            vehicleDot=forward:Dot(direction),
                            velocity={actorState.velocity.x,actorState.velocity.y,actorState.velocity.z}}
                        else report.dropped+=1 end
                    end
                end
            end
        end
    end
end)
local read=Instance.new('BindableFunction');read.Name='BrickToadsCourseHeadingRead'
read.OnInvoke=function()return Http:JSONEncode(report)end
read.Parent=game.ServerStorage
script.Destroying:Connect(function()heartbeat:Disconnect();read:Destroy()end)
