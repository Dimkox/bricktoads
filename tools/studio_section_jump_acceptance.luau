-- Studio-only prepared geometry fixture. Drives World movement, not player pathfinding.
-- No NPC combat, native input, full-route or touch acceptance is claimed.
assert(game:GetService('RunService'):IsStudio(),'Studio only')
local project=game:GetService('ServerScriptService').BrickToads
local gp=project.gameplay
local World=require(gp.GameWorld)
local Base=require(project.CombatRuntime.RobloxWorld)
local canonical=require(gp.LevelDefinition)
local Variation=require(gp.LevelVariation)
local config=require(gp.GameConfig)(require(project.CombatRuntime.Config),canonical)
local result={sourceSha256=require(project.BuildInfo).sourceSha256,cases={},
    fixture='Prepared takeoff on real seeded sections; World walk16 and jump50; no production navigation helper or normal-input route clear'}
local w=World.new(Base,config,{name='BrickToadsSectionJumpQA',offset={x=0,y=32,z=20480}})
local ok,err=xpcall(function()
    local coverage={}
    -- These three seeds select all three authored variants in every district.
    for _,seed in ipairs({1,48,842}) do
        w:clearActors()
        local route=Variation.build(canonical,seed)
        for zone,choice in ipairs(route.variation.sectionChoices) do coverage[zone..':'..choice]=true end
        assert(w:rebuildLevel(route))
        for zi,zone in ipairs(route.zones) do
            for gi,gap in ipairs(zone.gaps) do
                w:clearActors()
                assert(w:spawn(1,1,nil,false,'Mr. Green'))
                local body=w.actors[1]
                local takeoff,landing
                for _,p in ipairs(zone.platforms) do
                    if math.abs(p.x+p.w/2-gap.minX)<.01 then takeoff=p end
                    if math.abs(p.x-p.w/2-gap.maxX)<.01 then landing=p end
                end
                assert(takeoff and landing,'Gap needs both authored supports')
                local z=(gap.minZ+gap.maxZ)/2
                local start=Vector3.new(gap.minX-8,takeoff.y+takeoff.h/2+35,z+20480)
                body.root.CFrame=CFrame.lookAt(start,start+Vector3.new(1,0,0))
                body.root.AssemblyLinearVelocity=Vector3.zero
                body.root.AssemblyAngularVelocity=Vector3.zero
                task.wait(.2)
                local deadline=os.clock()+2
                while body.root.Position.X<gap.minX-2.5 and os.clock()<deadline do
                    w:move(1,1,0,false);w:hazard(1)
                    game:GetService('RunService').Heartbeat:Wait()
                end
                local launch=body.root.Position
                local velocity=body.root.AssemblyLinearVelocity
                local row={seed=seed,zone=zi,gap=gi,width=gap.maxX-gap.minX,
                    rise=landing.y+landing.h/2-takeoff.y-takeoff.h/2,
                    lead=gap.minX-launch.X,speed=velocity.X,walkSpeed=body.humanoid.WalkSpeed}
                w:jump(1)
                row.jumpAccepted=body.root.AssemblyLinearVelocity.Y>30
                row.peakY=body.root.Position.Y
                local crossed,landed=false,false
                deadline=os.clock()+1.8
                while os.clock()<deadline do
                    w:move(1,1,0,false);w:hazard(1)
                    game:GetService('RunService').Heartbeat:Wait()
                    local p=body.root.Position
                    row.peakY=math.max(row.peakY,p.Y)
                    if p.X>=gap.maxX+.5 then crossed=true end
                    if crossed and body.humanoid.FloorMaterial~=Enum.Material.Air and math.abs(body.root.AssemblyLinearVelocity.Y)<2 then
                        landed=true;break
                    end
                    if p.Y<landing.y+landing.h/2+28 then break end
                end
                w:move(1,0,0,false)
                row.final={x=body.root.Position.X,y=body.root.Position.Y,z=body.root.Position.Z-20480}
                row.pass=row.jumpAccepted and row.speed>14 and row.walkSpeed==16 and crossed and landed
                result.cases[#result.cases+1]=row
            end
        end
    end
    result.passed=0
    for _,row in ipairs(result.cases) do if row.pass then result.passed+=1 end end
    for zone=1,6 do for choice=1,3 do assert(coverage[zone..':'..choice],'Every authored section variant must be represented') end end
    result.sectionVariantsCovered=18
    result.status=result.passed==#result.cases and 'PASS' or 'FAIL'
end,debug.traceback)
w:clearActors();w.folder:Destroy()
if not ok then result.status='FAIL';result.error=tostring(err) end
_G.BrickToadsSectionJumpAcceptance=result
return game:GetService('HttpService'):JSONEncode(result)
