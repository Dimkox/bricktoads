"""Extract the actual QA foot function and pure Nav; no Studio control."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)
BASELINE = 'e53be90e04dc83eef7354e1b29825d71fd1080cd'

def digest(value):
    return hashlib.sha256(value).hexdigest()

base = subprocess.run(['git', 'show', BASELINE + ':tools/studio_level_route_driver.luau'],
    cwd=ROOT, check=True, stdout=subprocess.PIPE).stdout
current = (ROOT / 'tools/studio_level_route_driver.luau').read_bytes()
bridge = (ROOT / 'tools/qa/full_campaign_bridge.server.luau').read_bytes()
(HERE / 'baseline-nav.lua').write_bytes(base)
(HERE / 'candidate-nav.lua').write_bytes(current)
source = bridge.decode().replace('\r\n', '\n')
foot = source[source.index('local function foot(ctx,desired,combatPlan)'):source.index('\nlocal function plan(player)')]
header = """local Nav=require('./gap_review_KIND_nav')
local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local Enum={Material={Air='Air'}}
local function floorRows(world)return world.testFloors end
"""
for kind, raw in [('base', base), ('current', current)]:
    nav = raw.decode().replace('\r\n', '\n').split('\nif not game then return Nav end', 1)[0] + '\nreturn Nav\n'
    (BUILD / f'gap_review_{kind}_nav.lua').write_text(nav, encoding='utf-8')
    (BUILD / f'gap_review_{kind}_foot.lua').write_text(header.replace('KIND', kind) + foot +
        '\nreturn {foot=foot,nav=Nav,states=qa.plans}\n', encoding='utf-8')
    probe = (HERE / 'composition_probe_input.luau').read_text().replace('KIND', kind)
    (BUILD / f'gap_review_{kind}.luau').write_text(probe, encoding='utf-8')
receipt = {'baselineCommit': BASELINE, 'baselineArtifactSha256': digest(base),
    'candidateArtifactSha256': digest(current), 'actualBridgeSha256': digest(bridge),
    'scope': 'Extracted actual QA Nav plus actual bridge foot; numeric read-only context, no native outcome claim'}
(HERE / 'source-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt))
