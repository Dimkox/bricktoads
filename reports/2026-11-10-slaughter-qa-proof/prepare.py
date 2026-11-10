from pathlib import Path
P=Path(__file__).resolve().parents[2];R=Path(__file__).resolve().parent
for source,target in [('tools/qa/campaign_combat_pilot.lua','baseline-combat.lua'),('tools/qa/full_campaign_bridge.server.luau','baseline-bridge.lua')]:
 f=R/target
 if not f.exists():f.write_bytes((P/source).read_bytes())
nav=(P/'tools/studio_level_route_driver.luau').read_text().split('\nif not game then return Nav end',1)[0]+'\nreturn Nav\n';(R/'nav.lua').write_text(nav)
bridge=(R/'baseline-bridge.lua').read_text();foot=bridge[bridge.index('local function foot(ctx,desired,combatPlan)'):bridge.index('\nlocal function plan(player)')]
header="""local Nav=require('./nav')
local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function floorRows(w)return w.testFloors end
local Enum={Material={Air='Air'}}
"""
(R/'actual-foot.lua').write_text(header+foot+'\nreturn{foot=foot,qa=qa,states=qa.plans}\n')
