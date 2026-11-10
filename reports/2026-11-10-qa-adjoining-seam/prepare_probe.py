"""Generate the exact current bridge foot + Nav composition; no Studio access."""
import argparse
import hashlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--baseline', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
(root / 'build').mkdir(exist_ok=True)
nav = (root / 'tools/studio_level_route_driver.luau').read_text()
if args.baseline:
    correction = """            local inset = math.min(.25, (high-low)/2)
            if inset <= .15 then return {target = position, crossing = true, attackAllowed = false, phase = 'No shared crossing'} end
            -- Target beyond the bridge's .15-stud movement deadzone while
            -- retaining the full two-stud corridor on either support.
            z = clamp(z, low+inset, high-inset)
"""
    assert correction in nav
    nav = nav.replace(correction, '', 1)
source = (root / 'tools/qa/full_campaign_bridge.server.luau').read_text()
start = source.index('local function foot(ctx,desired,combatPlan)')
end = source.index('\nlocal function plan(player)', start)
foot = source[start:end]
assert 'out.x,out.z=n>.15' in foot, 'Reassess the caller deadzone if the bridge changes'
stem = 'adjoining_baseline' if args.baseline else 'adjoining_fixed'
header = f"local Nav=require('./{stem}_nav')\n" + """local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local Enum={Material={Air='Air'}}
local function floorRows(world)return world.testFloors end
"""
(root / f'build/{stem}_nav.lua').write_text(nav)
(root / f'build/{stem}_foot.lua').write_text(header+foot+'\nreturn foot\n')
probe = Path(__file__).with_name('bridge_probe_input.luau').read_text()
(root / f'build/{stem}_probe.luau').write_text(
    f"local Nav=require('./{stem}_nav')\nlocal foot=require('./{stem}_foot')\n"+probe)
print('Generated', stem, 'from bridge SHA256', hashlib.sha256(source.encode()).hexdigest())
