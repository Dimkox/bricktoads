-- Disposable QA diagnostics. The sole write is latestSample.modeFrameRing.
-- Optional ExpectedRunId; otherwise bind once to the first matching live run.
local RunService=game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsServer(),'Studio test server only')
local expected=script:GetAttribute('ExpectedRunId')
assert(expected==nil or type(expected)=='string' and #expected>0,'Invalid ExpectedRunId')
local watched={Surf=true,Jet=true,Ice=true,Serpents=true,Tubes=true}
local function number(v)return type(v)=='number' and v==v and math.abs(v)<math.huge and v or nil end
local function point(v)return v and {x=number(v.x),y=number(v.y),z=number(v.z)}or nil end
local function plan(v)return v and {x=number(v.x),z=number(v.z),jump=v.jump==true,primary=v.primary==true,run=v.run==true}or nil end
local lastAt=-math.huge
RunService.Heartbeat:Connect(function(heartbeatDt)
    local at=workspace:GetServerTimeNow();if at-lastAt<.05 then return end;lastAt=at
    local hub,qa=_G.BrickToadsFullCampaignHub,_G.BrickToadsFullCampaignQA
    if not hub or not qa or not qa.samples or not qa.current then return end
    local run=qa.current.runId
    if type(run)~='string' or #run==0 or expected and run~=expected then return end
    for _,group in pairs(hub.groups or{})do
        local c=group.controller;local s=c and c.current;local d=c and c.director;local m=d and d.modes
        if s and s.state.runId==run and not expected then expected=run end
        if s and s.state.runId==expected and m and watched[m.mode]then
            local epoch,index=s.state.levelEpoch,c.campaignIndex
            local row=qa.samples[#qa.samples];local stage=qa.stages and qa.stages[#qa.stages]
            if not row or row.index~=index or row.epoch~=epoch or qa.current.index~=index or qa.current.epoch~=epoch
                or not stage or stage.runId~=expected or stage.index~=index or stage.epoch~=epoch
                or not number(row.at) or row.at<stage.at or row.at>at then return end
            local frame={at=at,heartbeatDt=number(heartbeatDt),runId=expected,index=index,epoch=epoch,mode=m.mode,modeNow=number(m.now),
                modeElapsed=number(m.elapsed),actors={}}
            local vg=m.vehicleGroup
            if vg then frame.vehicleGroup={phase=vg.phase,serial=number(vg.serial),checkpoint=number(vg.checkpoint),
                elapsed=number(vg.elapsed),speed=number(vg.speed)}end
            for _,slot in ipairs(s.order)do
                local h=s.state.heroes[slot];local a=m.actors[slot];local combat=s.combat[slot]
                local body=group.world and group.world.actors[slot];local root=body and body.root
                local actor={slot=slot,actorId=h.actorId,status=h.status,connected=h.connected==true,
                    attempt=number(h.attempt),stock=number(h.respawns),rawLife=combat and number(combat.rawLife),
                    reactionEnd=combat and number(combat.reactionEnd),deathAt=combat and number(combat.deathAt),
                    sessionLastMoveAt=s.lastMove and number(s.lastMove[slot]),
                    decisionAt=qa.decisionAt and number(qa.decisionAt[expected..':'..tostring(epoch)..':'..slot..':'..tostring(h.actorId)])}
                if a then
                    actor.modeActorId=a.actorId;actor.position=point(a.position);actor.velocity=point(a.velocity)
                    actor.grounded=a.grounded==true;actor.mounted=a.mounted==true;actor.finished=a.finished==true
                    actor.support=a.support;actor.checkpoint=number(a.checkpoint);actor.progress=number(a.progress)
                    local accepted=a.input
                    if accepted then actor.modeInput={x=number(accepted.x),z=number(accepted.z),run=accepted.run==true,at=number(accepted.at)}end
                end
                if root and root.Parent then
                    local p,v,o=root.Position,root.AssemblyLinearVelocity,group.world.offset
                    actor.nativePosition={x=number(p.X-(o and o.X or 0)),y=number(p.Y-(o and o.Y or 0)),z=number(p.Z-(o and o.Z or 0))}
                    actor.nativeVelocity={x=number(v.X),y=number(v.Y),z=number(v.Z)};actor.anchored=root.Anchored==true
                    local look=root.CFrame.LookVector;actor.nativeLookVector={x=number(look.X),z=number(look.Z)}
                end
                for n=#(qa.motion or{}),1,-1 do
                    local motion=qa.motion[n]
                    if motion.at<stage.at then break end
                    if motion.slot==slot and motion.at<=at and motion.attempt==h.attempt and motion.at==actor.decisionAt then
                        actor.plannedAt=number(motion.at);actor.planned=plan(motion.plan);actor.decisionDt=number(motion.decisionDt);break
                    end
                end
                frame.actors[#frame.actors+1]=actor
            end
            local ring=row.modeFrameRing or{};ring[#ring+1]=frame
            while #ring>24 do table.remove(ring,1)end
            row.modeFrameRing=ring
            return
        end
    end
end)
