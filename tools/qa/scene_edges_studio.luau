-- Run in Studio Play on the server. Sample generated geometry in an isolated party.
assert(game:GetService("RunService"):IsStudio())
local project = game.ServerScriptService.BrickToads
local G, R = project.gameplay, project.CombatRuntime
local definition = require(G.CampaignDefinition)
local worldType = require(G.GameWorld)
local seed = 41
local first = definition.build(1, seed)
local config = require(G.GameConfig)(require(R.Config), first)
local world = worldType.new(require(R.RobloxWorld), config, {
    name="SceneEdgesStudioCheck", offset={x=0,y=32,z=8192}, campaignWorld=require(G.CampaignWorld),
})
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {world.geometry}
params.RespectCanCollide = true
local rows = {}
local function ray(x,y,z,dx,dy,dz)
    return workspace:Raycast(Vector3.new(x,y,z)+world.offset, Vector3.new(dx,dy,dz), params)
end
local function check(name, condition)
    assert(condition, name)
    table.insert(rows, name)
end
local ok, why = xpcall(function()
    local p=first.zones[1].platforms[1]
    local ridge=ray(p.x-.5,10,p.z-p.d*.26,0,-14,0)
    check("Causeway ridge supports a standing actor above the paving",
        ridge and ridge.Instance.Name=="WalkableCrest" and ridge.Position.Y>world.offset.Y+2 and ridge.Normal.Y>=.95)
    local boundary=ray(p.x,5,p.z+p.d/2-3,0,0,8)
    check("Floodgate side stops outward movement above the parapet",
        boundary and boundary.Instance.Name=="ArenaBoundary")
    local court=first.boss.platform
    local far=ray(court.x+court.w/2-3,5,court.z,6,0,0)
    check("Guardian court has a solid far end",far and far.Instance.Name=="ArenaBoundary")
    local near=ray(court.x-court.w/2-2,5,court.z,4,0,0)
    check("Long Bridge opens into the Guardian court",not near or near.Instance.Name~="ArenaBoundary")
    for _,zone in ipairs(first.zones) do
        for i,gap in ipairs(zone.gaps or {}) do
            local hit=ray((gap.minX+gap.maxX)/2,8,(gap.minZ+gap.maxZ)/2,0,-40,0)
            check(zone.name.." gap "..i.." remains open", not hit)
        end
    end
    for index=2,13 do
        local d=definition.build(index,seed)
        assert(world:advanceGeometry(d))
        if d.boss.kind then
            local a=d.boss.platform
            local wall=ray(a.x+a.w/2-2,a.y+a.h/2+6,a.z,7,0,0)
            check(d.boss.kind.." arena has a solid outer end",wall and wall.Instance.Name=="ArenaBoundary")
            local f=d.course.finishPoint
            local onZ=index==8 or index==10
            local x=onZ and f.x or a.x-a.w/2
            local z=onZ and a.z-a.d/2 or f.z
            local block=ray(x-(onZ and 0 or 2),f.y+1,z-(onZ and 2 or 0),onZ and 0 or 4,0,onZ and 4 or 0)
            check(d.boss.kind.." arena entrance is open",not block or block.Instance.Name~="ArenaBoundary")
        end
        if index==3 then
            for _,panel in ipairs(d.course.platforms) do
                if panel.roadRise then
                    for _,frac in ipairs({-.499,0,.499}) do
                        local x=panel.x+panel.w*frac
                        for _,lane in ipairs({-18,0,18}) do
                            local hit=ray(x,30,lane,0,-60,0)
                            local y=definition.roadHeight(d.course,x)
                            assert(hit and hit.Instance.Material==Enum.Material.Asphalt and hit.Instance:FindFirstChild("RoadAggregate"))
                            assert(math.abs(hit.Position.Y-world.offset.Y-y)<.025)
                        end
                    end
                end
            end
            check("Copper Rush textured physical road matches riding height across all lanes",true)
        elseif index==4 then
            local p,q=d.course.platforms[1],d.course.platforms[2]
            check("Frostworks gap has no new collision",not ray((p.x+p.w/2+q.x-q.w/2)/2,8,0,0,-60,0))
        elseif index==9 then
            local p=d.course.platforms[1]
            local hit=ray(p.x,5,p.z+p.d/2-2,0,0,5)
            check("Dry pressure pipe has a solid bank",hit and hit.Instance.Name=="ArenaBoundary")
        end
        task.wait()
    end
end,debug.traceback)
world.folder:Destroy()
assert(ok,why)
return game.HttpService:JSONEncode({seed=seed,checks=rows,source=require(project.BuildInfo).sourceSha256})
