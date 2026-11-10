from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
LUAU = ROOT / '.tools/luau-0.745/luau.exe'
COMPILER = ROOT / '.tools/luau-0.745/luau-compile.exe'
BASELINE = '69829b89eb61699cdd1a3864faeeaf0e20dcbdee11a71c6b95b45e55ced5b3c5'
CANDIDATE = 'b40c4b42d5a44d9f7561be8228204c5bae3f292292d9630eaf0fc21384544c65'
CLIENT = 'cc3dc908559407962a305bcd3b73dff682a6d250567ac95e1567dad6a77a3351'
SENDER = 'bffba8611d31fb776d09409d10ac0a23633ba39429a10adac978fa7a293eb9a7'
CONFIG = 'c423b8b8685940bd03f487f3bd2773d2302773ff48ba98a3a1414254b31b1624'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, log):
    result = subprocess.run([str(x) for x in command], cwd=ROOT, capture_output=True, text=True)
    output = result.stdout + result.stderr
    (HERE / log).write_text(output)
    return result.returncode, output


baseline = HERE / 'baseline-adapter.luau'
candidate = HERE / 'candidate-adapter.luau'
working = ROOT / 'tools/qa/full_campaign_client_adapter.luau'
client_path = ROOT / 'src/client/BrickToadsClient.client.luau'
assert sha(baseline) == BASELINE
assert sha(candidate) == CANDIDATE == sha(working)
assert sha(client_path) == CLIENT, 'Production client changed; reassess extraction and preservation claim'
assert sha(ROOT / 'src/stand/server/Config.lua') == CONFIG
source = client_path.read_text()
chunks = source[source.index('local function sendIntent(packet)'):source.index('local function chooseView(view)')]
chunks += source[source.index('local function playable()'):source.index('local actions = frame(controls, "Actions")')]
assert hashlib.sha256(chunks.encode()).hexdigest() == SENDER
old = "                qa.move=r.plan;sendMovement(r.plan.jump or r.plan.primary)"
new = """                local previous=qa.move
                local changed=(r.plan.x or 0)~=(previous.x or 0) or (r.plan.z or 0)~=(previous.z or 0)
                    or (r.plan.run==true)~=(previous.run==true)
                -- Changed steering is immediate; unchanged keepalives retain their gate.
                qa.move=r.plan;sendMovement(changed or r.plan.jump or r.plan.primary)"""
assert baseline.read_text().count(old) == 1
assert baseline.read_text().replace(old, new) == candidate.read_text(), 'Adapter delta exceeds the reviewed plan-delivery change'

checks = []
for label, adapter, expected_exit, expected_pass, expected_fail in [
    ('baseline', baseline, 1, 10, 2), ('candidate', candidate, 0, 12, 0)
]:
    contract = HERE / f'{label}-contract.luau'
    code, output = run([sys.executable, HERE / 'build_contract.py', '--adapter', adapter, '--out', contract], f'{label}-generation.txt')
    assert code == 0, output
    code, output = run([LUAU, contract], 'baseline-red.txt' if label == 'baseline' else 'candidate-green.txt')
    passed = len(re.findall(r'^PASS ', output, re.M))
    failed = len(re.findall(r'^FAIL ', output, re.M))
    assert (code, passed, failed) == (expected_exit, expected_pass, expected_fail), output
    rates = [dict(zip(['packets', 'move', 'jump', 'attack', 'worstOneSecond', 'rejected'], map(int, row)))
             for row in re.findall(r' RATE packets=(\d+) Move=(\d+) Jump=(\d+) Attack=(\d+) worstOneSecond=(\d+) rejected=(\d+)', output)]
    assert len(rates) == 6 and all(r['rejected'] == 0 and r['worstOneSecond'] <= 40 for r in rates)
    checks.append({'scope': label, 'exit': code, 'passed': passed, 'failed': failed, 'rates': rates})

code, output = run([COMPILER, '--null', working], 'compile.txt')
assert code == 0, output
result = {
    'status': 'bounded_transport_green_pending_native_verification',
    'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'baselineSha256': BASELINE, 'candidateSha256': CANDIDATE,
    'workingSha256': sha(working), 'productionClientSha256': CLIENT,
    'productionSenderExtractSha256': SENDER, 'productionConfigSha256': CONFIG,
    'onlyReviewedAdapterDelta': True, 'compileExit': code, 'checks': checks,
    'independentReview': 'client_delivery_review independently reran RED/GREEN and all six rate clocks; bounded CLEAR',
    'limits': [
        'RPC/render clocks and RemoteEvent capture are adapted; no Roblox engine, actors or gameplay simulation is supplied.',
        'The 95ms counterexample is an extracted-code clock case, not a captured Native22 client reply timestamp.',
        'Fixed active sender context does not establish context-transition or unplayable-send recovery behavior.',
        'Six30s rate clocks bound the tested30/60fps and RTT0/.02/.05 alignments, not arbitrary RTT/FPS/manual-input patterns.',
        'Rate saturation uses the existing urgent-force path to bound every-plan Move plus Jump and guarded primary.',
        'No production source, server rate limit, gameplay pilot or resources are modified.',
        'No native Studio, Guardian, zero-death Ice or full13 acceptance claim.'
    ],
}
(HERE / 'validation.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'status': result['status'], 'candidateSha256': CANDIDATE,
                  'baseline': '10PASS/2FAIL', 'candidate': '12PASS/0FAIL', 'compileExit': code}))
