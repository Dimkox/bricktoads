"""Reproduce the bounded RED/GREEN matrix and retained regressions."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import subprocess

REPORT = Path(__file__).resolve().parent
ROOT = REPORT.parents[1]
LUAU = ROOT / '.tools/luau-0.745/luau.exe'
COMPILER = ROOT / '.tools/luau-0.745/luau-compile.exe'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


baseline = (REPORT / 'baseline-policy.lua').read_bytes().decode()
candidate = (REPORT / 'candidate-policy.lua').read_bytes().decode()


def outside_ice(text):
    start = text.index('local function iceLaneClearance(')
    end = text.index('local function hazardPosition(', start)
    return text[:start], text[end:]


assert outside_ice(baseline) == outside_ice(candidate), 'Bytes outside Ice changed'
assert sha(REPORT / 'baseline-policy.lua') == 'e7c8152f21d45b281ca75150c39e1f78ff289c9bbce73f25945375f981b3037c'
assert sha(REPORT / 'candidate-policy.lua') == '1d5693ed7ed9089a7c645c8bf4f3b8b2578fe169dd758f316c47f9b51a280695'
(REPORT / 'diff-from-E7.patch').write_text(''.join(difflib.unified_diff(
    baseline.splitlines(True), candidate.splitlines(True),
    fromfile='baseline-E7.lua', tofile='candidate-1D.lua', n=0)))

jobs = [
    ('probe-queued-baseline.luau', 'baseline-red.txt', 5, 4),
    ('probe-queued-candidate.luau', 'candidate-green.txt', 9, 0),
    ('probe-first-section-36.luau', 'first-section-36.txt', 36, 0),
    ('probe-static-candidate.luau', 'static-36.txt', 36, 0),
    ('probe-npc-candidate.luau', 'npc-oldseed-18.txt', 18, 0),
    ('newseed-1158731273-npc18.luau', 'npc-newseed-18.txt', 18, 0),
    ('probe-other-100.luau', 'other-100.txt', 100, 0),
    ('probe-live-8.luau', 'live-8.txt', 8, 0),
]
checks = []
for probe, log, expected_passed, expected_failed in jobs:
    proc = subprocess.run([str(LUAU), str(REPORT / probe)], cwd=ROOT,
                          capture_output=True, text=True)
    output = proc.stdout + proc.stderr
    (REPORT / log).write_text(output)
    passed = sum(row.startswith('PASS ') for row in output.splitlines())
    failed = sum(row.startswith('FAIL ') for row in output.splitlines())
    assert proc.returncode == 0, (probe, proc.returncode)
    assert (passed, failed) == (expected_passed, expected_failed), (probe, passed, failed)
    checks.append({'probe': probe, 'log': log, 'passed': passed, 'failed': failed,
                   'exit': proc.returncode})
    print(probe, passed, failed)

proc = subprocess.run([str(COMPILER), '--null', str(REPORT / 'candidate-policy.lua'),
                       str(REPORT / 'npc-fixture.lua'),
                       *[str(REPORT / job[0]) for job in jobs]], cwd=ROOT,
                      capture_output=True, text=True)
(REPORT / 'compile.txt').write_text(proc.stdout + proc.stderr)
assert proc.returncode == 0
validation = {
    'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'frozen_pending_independent_review_and_native_validation',
    'baselineSha256': sha(REPORT / 'baseline-policy.lua'),
    'candidateSha256': sha(REPORT / 'candidate-policy.lua'),
    'workingPolicySha256': sha(ROOT / 'tools/qa/campaign_early_course_pilot.lua'),
    'onlyIceBytesChanged': True,
    'sourcePhysicsChanged': False,
    'compileExit': proc.returncode,
    'checks': checks,
    'limits': [
        'Queued test is a conservative logical delivery envelope, not exact Roblox transport replay',
        'One actual seed1158731273, one hero, no multiplayer acceptance',
        'Ordinary regular Move held .133/.167/.2; urgent Move+Jump2/60; cadence .133/.167/.2',
        'Native20 checkpoint Snowball pre-input sweep remains a separate UX limitation',
        'No Studio control or native test by audit agent; no all13 native Won claim',
    ],
}
assert validation['candidateSha256'] == validation['workingPolicySha256']
(REPORT / 'validation.json').write_text(json.dumps(validation, indent=2) + '\n')
print('PASS hashes, non-Ice bytes and compilation')
