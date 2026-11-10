from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SLAUGHTER = ROOT / 'reports/2026-11-10-slaughter-qa-proof'
FINAL = 'bebdb12c47f7cefa1b079d8bec236f0a178de5bf5929a86476c769554f8ae85c'
FOUR_F = '4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129'
LUAU = ROOT / '.tools/luau-0.745/luau.exe'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(script, log):
    result = subprocess.run([str(LUAU), str(script)], cwd=ROOT, capture_output=True, text=True)
    (HERE / log).write_text(result.stdout + result.stderr)
    assert result.returncode == 0, (log, result.stdout, result.stderr)
    return result.stdout


def rows(output, prefix, first_delay=True):
    result = []
    for line in output.splitlines():
        if not line.startswith(prefix):
            continue
        bits = [s.strip() for s in line.split('\t')]
        item = {'delay': float(bits[1])} if first_delay else {}
        start = 2 if first_delay else 1
        for index in range(start, len(bits) - 1, 2):
            value = bits[index + 1]
            if value in ('true', 'false'):
                value = value == 'true'
            else:
                try:
                    value = float(value) if '.' in value else int(value)
                except ValueError:
                    pass
            item[bits[index]] = value
        result.append(item)
    return result


source = ROOT / 'tools/qa/campaign_combat_pilot.lua'
before = source.read_bytes()
assert sha(source) == FINAL
assert sha(HERE / 'pre-queen-combat-4F.lua') == FOUR_F
start = before.index(b'local queenEvasions =')
end = before.index(b'local function guardianPlan(', start)
without = before[:start] + before[end:]
without, removed = re.subn(rb'    local queen = queenEvasion\(c,boss,q\)\r?\n    if queen then clearRunUp\(c\);return queen end\r?\n', b'', without)
assert removed == 1 and without == (HERE / 'pre-queen-combat-4F.lua').read_bytes(), 'Anything outside Queen helper/call changed'
old_sources = json.loads((SLAUGHTER / 'validation-integrated.json').read_text())['sourceHashes']
for name, expected in old_sources.items():
    if name != 'tools/qa/campaign_combat_pilot.lua':
        assert sha(ROOT / name) == expected, 'Unrelated implementation changed: ' + name

baseline = rows(run(HERE / 'queen-probe.luau', 'queen-baseline-retained.txt'), 'QUEEN13_BASELINE')
assert len(baseline) == 2 and [c['result'] for c in baseline] == ['Won', 'Lost']
assert (baseline[1]['attempt'], baseline[1]['stock'], baseline[1]['progress'], baseline[1]['underflows']) == (4, 0, 84, 7)
queen = rows(run(HERE / 'queen-probe-integrated.luau', 'queen-integrated-outcome.txt'), 'QUEEN13_INTEGRATED')
assert len(queen) == 2
for case in queen:
    assert case['result'] == 'Won' and case['progress'] == 240 and case['underflows'] == 21
    assert (case['heroLife'], case['attempt'], case['stock'], case['heroHits'], case['confirmedDeaths']) == (47, 1, 3, 0, 0)

general = rows(run(SLAUGHTER / 'probe-integrated-retry.luau', 'queen-retained-general-whole.txt'), 'WHOLE_INTEGRATED_RETRY')
assert len(general) == 4
assert [(c['result'], c['heroLife'], c['attempt'], c['stock'], c['heroHits']) for c in general] == [
    ('Won', 47, 1, 3, 0), ('Won', 31, 2, 2, 4), ('Won', 47, 3, 1, 0), ('Won', 47, 3, 1, 0)]
assert all(c['progress'] == 240 and c['underflows'] == 21 for c in general)
general_gates = run(SLAUGHTER / 'probe-integrated-gates.luau', 'queen-retained-general-gates.txt')
assert re.search(r'read-only\s+33\s*$', general_gates)
buzzball = rows(run(HERE / 'buzzball-probe.luau', 'queen-retained-buzzball.txt'), 'BUZZBALL_WHOLE', False)
assert len(buzzball) == 2
assert [(c['result'], c['heroLife'], c['attempt'], c['stock'], c['heroHits']) for c in buzzball] == [
    ('Won', 31, 1, 3, 1), ('Won', 47, 1, 3, 0)]
assert all(c['underflows'] == 1 and c['bossDefeated'] and c['sameInitialActor']
           and c['phase1Seen'] and c['phase2Seen'] and c['deaths'] == 0 for c in buzzball)

retained = []
for name, expected in [('dragon-146', 146), ('guardian-10', 10), ('stepoff-26', 26), ('bridge-26', 26)]:
    output = run(SLAUGHTER / f'integrated-regression-{name}.luau', f'queen-retained-{name}.txt')
    assert re.search(r'(?<!\d)' + str(expected) + r'(?!\d)', output) and ('PASS' in output or 'GREEN' in output), (name, output)
    retained.append({'name': name, 'passed': expected, 'exit': 0})
gates = run(HERE / 'queen-integrated-gates.luau', 'queen-integrated-gates.txt')
assert re.search(r'read-only\s+79\s*$', gates)
compiled = subprocess.run([str(ROOT / '.tools/luau-0.745/luau-compile.exe'), '--null', str(source),
                           str(HERE / 'queen-probe-integrated.luau'), str(HERE / 'queen-integrated-gates.luau')],
                          cwd=ROOT, capture_output=True, text=True)
(HERE / 'queen-integrated-compile.txt').write_text(compiled.stdout + compiled.stderr)
assert compiled.returncode == 0
assert source.read_bytes() == before, 'Implementation changed during verification'

data = {
    'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'bounded_Queen_QA_source_GREEN_pending_native25',
    'seed': 1158731273, 'candidateSha256': FINAL, 'baseline4FSha256': FOUR_F,
    'onlyQueenHelperAndTwoLineCallChanged': True,
    'otherSourceHashesRetained': {name: value for name, value in old_sources.items()
                                 if name != 'tools/qa/campaign_combat_pilot.lua'},
    'queenBaselineCases': baseline, 'queenIntegratedCases': queen,
    'generalRetainedCases': general, 'generalGatesPassed': 33,
    'buzzballRetainedCases': buzzball, 'oldRegressionPassed': retained,
    'queenGuardsPassed': 79, 'compileExit': compiled.returncode,
    'independentReviews': [
        'ice19_audit independently removed Queen scope to exact4F, reviewed geometry/state writes and reran Queen2',
        'client_delivery_review independently reviewed exact4F scope, reran Queen2/General4/Buzzball2/208 and compiler'
    ],
    'limits': [
        'Prepared boss-entry observations; no Finale/Clinger/Race traversal is earned by these subencounters.',
        'Mapped non-engine turning/movement/gravity/impulse response and fixed queues are not native Humanoid/transport parity.',
        'One seed and one hero; broader latency/FPS/rig/multiplayer/public-server behavior not established.',
        'Integrated fixed133ms budget is conservative in zero-queue case; its elapsed time differs from the initial probe.',
        'General fresh queued case spends one normal reserve; original-body RED label is retained under the allowed normal budget.',
        'No production source/health/resources/AI/phase/rate rules changed; no native25 or full13 Won claim.'
    ],
}
(HERE / 'queen-integrated-validation.json').write_text(json.dumps(data, indent=2) + '\n')
print('PASS final Queen source:2wholeWins/79guards; General4+33/Buzzball2/old208 retained; compile0; BEB frozen')
