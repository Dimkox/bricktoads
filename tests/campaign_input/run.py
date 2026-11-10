"""Execute the client's real action-visibility block against role/course snapshots."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=str(ROOT / '.tools/luau-0.745/luau.exe'))
args = parser.parse_args()
client = (ROOT / 'src/client/BrickToadsClient.client.luau').read_text(encoding='utf-8')
render = client.split('render = function()', 1)[1]
begin = render.index('    local interaction = snapshot and snapshot.interaction')
end = render.index('    local isBoss =', begin)
feedback = (ROOT / 'src/client/CombatFeedback.luau').read_text(encoding='utf-8')
prefix = f'local CombatFeedback=assert(loadstring([====[{feedback}]====]))()\n'
prefix += 'local function actionState(snapshot, touch)\n'
prefix += '''local UserInputService={TouchEnabled=touch}
local enemy=snapshot.enemyRole
local controlledBoss=enemy and enemy.template=='Boss'
local controlled=enemy
for _,hero in ipairs(snapshot.heroes or {})do if hero.slot==snapshot.mine then controlled=hero;break end end
local punch,dash,jump,keyboardHint,runHint={},{},{},{},{Visible=true}
local function T(value)return value end
'''
prefix += render[begin:end]
prefix += 'return {primary=punch.Visible,mega=dash.Visible,jump=jump.Visible,hint=keyboardHint.Text,run=runHint.Visible}\nend\n'
contracts = Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='bricktoads-campaign-input-') as directory:
    runner = Path(directory) / 'contracts.luau'
    runner.write_text(prefix + contracts, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
