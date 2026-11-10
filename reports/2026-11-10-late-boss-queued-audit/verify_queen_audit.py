from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def run(command, log):
    result = subprocess.run([str(x) for x in command], cwd=ROOT, capture_output=True, text=True)
    (HERE / log).write_text(result.stdout + result.stderr)
    assert result.returncode == 0, (log, result.stdout, result.stderr)
    return result.stdout


run([sys.executable, HERE / 'build_queen_audit.py'], 'queen-build.txt')
probe = HERE / 'queen-probe.luau'
current = HERE / 'queen-probe-4F-capsule.luau'
current.write_text(probe.read_text().replace("require('./queen-baseline-combat')", "require('./pre-queen-combat-4F')"))
old_output = run([ROOT / '.tools/luau-0.745/luau.exe', probe], 'queen-outcome.txt')
new_output = run([ROOT / '.tools/luau-0.745/luau.exe', current], 'queen-current-outcome.txt')
assert old_output == new_output, 'GeneralSlaughter-only integration changed this DarkQueen audit outcome'
cases = []
for line in old_output.splitlines():
    if not line.startswith('QUEEN13_BASELINE'):
        continue
    bits = line.split('\t')
    row = {'delay': float(bits[1])}
    for index in range(2, len(bits) - 1, 2):
        value = bits[index + 1]
        try:
            value = float(value) if '.' in value else int(value)
        except ValueError:
            pass
        row[bits[index]] = value
    cases.append(row)
assert len(cases) == 2
assert cases[0]['result'] == 'Won' and cases[0]['progress'] == 240 and cases[0]['underflows'] == 21
assert (cases[0]['heroLife'], cases[0]['attempt'], cases[0]['stock'], cases[0]['confirmedDeaths']) == (47, 1, 3, 0)
assert cases[1]['result'] == 'Lost' and cases[1]['progress'] == 84 and cases[1]['underflows'] == 7
assert (cases[1]['heroLife'], cases[1]['attempt'], cases[1]['stock'], cases[1]['confirmedDeaths']) == (0, 4, 0, 4)
run([ROOT / '.tools/luau-0.745/luau-compile.exe', '--null', HERE / 'queen-fixture.lua', probe, current], 'queen-compile.txt')
hashes = {str(f.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(f.read_bytes()).hexdigest()
          for f in [HERE / 'queen-baseline-combat.lua', HERE / 'pre-queen-combat-4F.lua', HERE / 'queen-fixture.lua', HERE / 'queen-foot.lua',
                    probe, current, ROOT / 'tools/qa/campaign_combat_pilot.lua', ROOT / 'tools/qa/full_campaign_bridge.server.luau']}
assert hashes[str((HERE / 'pre-queen-combat-4F.lua').relative_to(ROOT)).replace('\\', '/')] == '4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129'
assert hashes['tools/qa/full_campaign_bridge.server.luau'] == '97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'
data = {
    'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'DarkQueen13_historical4F_prepared_source_baseline_zero_queue_Won_133ms_Lost',
    'seed': 1158731273, 'boss': 'DarkQueen', 'cases': cases, 'hashes': hashes,
    'pinned4FAndBfbBaselineOutcomesIdentical': True, 'compileExit': 0,
    'limits': [
        'Prepared completed-Finale observation; course traversal is not earned by this probe.',
        'Natural Boss.new creates15Life/progress0/Ready; no direct boss phase, health, progress or outcome write.',
        'Source Session/Boss/SourceCombat resolve all combat, deaths and paid appearances; normal three-respawn budget.',
        'Actual authored Definition13 arena and actual Modes finished-slot1 retry query are retained.',
        'Mapped non-engine ground/facing/impulse response and fixed delivery queues are not native Humanoid/transport replay.',
        'Initial budget assertion incorrectly counted final elimination as a replacement; original error log retained and assertion corrected to CommitSpawn counts.',
        'No source, Studio, Git or gameplay fix; no native or full13 acceptance.'
    ],
}
(HERE / 'queen-validation.json').write_text(json.dumps(data, indent=2) + '\n')
for case in cases:
    print(case)
print('Verified bounded DarkQueen risk; queued Lost is expected negative evidence, not a passing encounter')
