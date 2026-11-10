from pathlib import Path
import sys
R=Path(__file__).resolve().parent
P=R.parents[1]
for name in ['baseline-combat.lua','baseline-bridge.lua','candidate-combat.lua','candidate-bridge.lua','nav.lua']:
 assert(R/name).exists(),'Missing pinned report snapshot: '+name
nav=(R/'nav.lua').read_text()
header="""local Nav=require('./nav')
local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function floorRows(w)return w.testFloors end
local Enum={Material={Air='Air'}}
"""
candidate=(R/'candidate-bridge.lua').read_text()
for kind,source in [('baseline',(R/'baseline-bridge.lua').read_text()),('candidate',candidate)]:
 normalizer=source[source.index('local function normalize(p)'):source.index('\nlocal function floorRows(world)')]
 foot=source[source.index('local function foot(ctx,desired,combatPlan)'):source.index('\nlocal function plan(player)')]
 (R/(kind+'-foot.lua')).write_text(header+normalizer+'\n'+foot+'\nreturn{foot=foot,normalize=normalize,qa=qa,nav=Nav,states=qa.plans}\n')
if '--regression' in sys.argv:
 h=header.replace("require('./nav')","require('./ground_priority_nav')")
 (P/'build/ground_priority_nav.lua').write_text(nav)
 (P/'build/ground_priority_current_foot.lua').write_text(h+foot+'\nreturn{foot=foot,qa=qa,nav=Nav,states=qa.plans}\n')
 (P/'build/ground_priority_current_probe.luau').write_text((P/'reports/2026-11-10-qa-grounded-combat-priority/composition_probe_input.luau').read_text().replace('KIND','current'))
