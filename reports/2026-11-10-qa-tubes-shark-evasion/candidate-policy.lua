-- QA-only Tubes composition. Reads actual actors/telegraphs and returns normal
-- inputs; it never sends intents or changes controller/world/resource state.
local Combat
if script then Combat=require(script.Parent.campaign_combat_pilot)
else Combat=require('../../tools/qa/campaign_combat_pilot') end
local Pilot={}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function copy(input)
    local out={};for k,v in pairs(input or{})do out[k]=v end
    out.x,out.z=out.x or 0,out.z or 0
    return out
end
local function boundEntry(ctx,out,stageBeforeWater)
    local floor=ctx.definition.course.platforms[1];local p=ctx.position
    local water=ctx.definition.course.media[1]
    local maxX=math.min(floor.x+floor.w/2-2,water.minX-(stageBeforeWater==false and 0 or 3))
    local horizon=math.max(.1,math.min(.25,(ctx.dt or .1)+1/60))
    local speed=(ctx.definition.course.maxSpeed or 16)*horizon
    local x,z=out.x,out.z
    out.x=clamp(out.x,clamp((floor.x-floor.w/2+2-p.x)/speed,-1,1),clamp((maxX-p.x)/speed,-1,1))
    out.z=clamp(out.z,clamp((floor.z-floor.d/2+2-p.z)/speed,-1,1),clamp((floor.z+floor.d/2-2-p.z)/speed,-1,1))
    if out.primary and (out.x~=x or out.z~=z)then
        -- Contact was selected from the current facing. A boundary correction
        -- must not turn the real body away during its accepted windup.
        out.x,out.z,out.aimX,out.aimZ=0,0,nil,nil
    end
    return out
end
local function primaryOpportunity(ctx,route)
    local s=ctx.session;local c=s.combat[ctx.slot];local cfg=s.config.Attacks.Punch
    if c.attack or c.reactionEnd or c.deathAt or ctx.now<(c.nextAttack or 0) or not ctx.world.targets then return nil end
    for _,id in ipairs(ctx.world:targets(ctx.slot,cfg))do
        local enemy=ctx.director.enemies[id]
        if enemy and not enemy.dead and not enemy.boss then
            local family=ctx.director.campaignEnemies
            local state=family and family.states[id]
            local tell=state and state.mode=='Tell' and state.attack
            if not tell or tell.at-ctx.now>(cfg.windup or .1)+.05 then
                -- Existing world targeting proves current range, height,
                -- facing and visibility. No input contains an enemy ID.
                local look=ctx.world.actors[ctx.slot].root.CFrame.LookVector
                local out=copy(route);out.primary=true;out.run=false
                if ctx.actor.medium~='Water' then out.x,out.z=(look.X or 0)*.08,(look.Z or 0)*.08 end
                return out
            end
        end
    end
    return nil
end
function Pilot.plan(ctx,route)
    local out=copy(route)
    if not ctx.definition or ctx.definition.mode~='Tubes' or not ctx.actor or ctx.actor.finished then return out end
    local s,a=ctx.session,ctx.actor;local h=s.state.heroes[ctx.slot];local c=s.combat[ctx.slot]
    if not h or h.status~='Alive' or not h.connected or c.deathAt or c.reactionEnd then
        return{x=0,z=0,jump=false,primary=false,run=false}
    end
    if c.attack then
        -- Swimming controls oppose currents, choose altitude and maintain
        -- oxygen progress throughout a real attack's windup/recovery.
        if a.medium=='Water' then out.primary=false;return out end
        return{x=0,z=0,jump=false,primary=false,run=false,hold=true}
    end
    if a.medium=='Water' then
        local family=ctx.director.campaignEnemies
        for id,enemy in pairs(ctx.director.enemies) do
            local state=family and family.states[id]
            local attack=state and (state.mode=='Tell' or state.mode=='Active') and state.attack
            local move=attack and attack.move
            local target=attack and attack.destination
            if not enemy.dead and move and move.lift~=nil and target
                and not (attack.hits and attack.hits[ctx.slot])
                and ctx.now<attack.untilAt and math.abs(ctx.position.y-target.y)<(move.radius or 3)+1
                and math.abs(ctx.position.x-target.x)<(move.radius or 3)+4 then
                -- Normal repeated swim Jump clears the accepted fixed-target
                -- lunge. Retain current/hazard X steering instead of chasing.
                out.jump=true;out.primary=false;out.z=-1
                return out
            end
        end
    end
    local robot
    for id,enemy in pairs(ctx.director.enemies)do
        if enemy.kind=='Robot' and not enemy.dead then robot=id;break end
    end
    local opportunity=(a.medium~='Water' or (a.oxygen or 18)>5) and primaryOpportunity(ctx,out)
    if opportunity then
        -- Once the Robot is gone, the x32 staging line has no role in a
        -- nearby fish attack. Keep only the actual dry support boundary.
        if a.medium~='Water' and ctx.position.x<ctx.definition.course.media[1].minX then return boundEntry(ctx,opportunity,robot~=nil)end
        return opportunity
    end
    local p=ctx.position
    local waterX=ctx.definition.course.media[1].minX
    if a.medium~='Water' and p.x<waterX then
        if robot then
            local q=ctx.world:position(robot)
            local punch=s.config.Attacks.Punch
            if q and math.abs(q.y-p.y)<5 and q.x<=waterX-3+(punch.reach or 6)-.5 then
                -- Focus the entry Robot in a local observer view. The real
                -- Director, all NPC states/projectiles and their AI stay live.
                local observed=table.clone(ctx.director);observed.enemies={[robot]=ctx.director.enemies[robot]}
                local focused=table.clone(ctx);focused.director=observed
                local fight=Combat.plan(focused)
                return boundEntry(ctx,copy(fight))
            end
        end
        if math.abs(p.z)>.4 then
            -- Finish entry combat on the dry ledge, then center through normal
            -- movement before Z changes meaning to swimming altitude.
            out.x,out.z,out.primary,out.run=0,clamp(-p.z*.6,-1,1),false,false
            return boundEntry(ctx,out)
        end
    end
    -- Keep the existing current/oxygen/hazard route in water. Nearby primary
    -- opportunities above may interrupt an enemy without chasing/diving.
    return out
end
return Pilot
