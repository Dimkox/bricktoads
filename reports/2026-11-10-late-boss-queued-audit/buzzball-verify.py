from pathlib import Path
import datetime
import hashlib
import json
import subprocess

R = Path(__file__).resolve().parent
P = R.parents[1]
SOURCES = [
    'src/server/gameplay/CampaignBoss.lua', 'src/server/gameplay/CampaignModes.lua',
    'src/server/gameplay/CampaignDefinition.lua', 'src/server/gameplay/GameConfig.lua',
    'src/server/gameplay/SourceCombat.lua', 'src/stand/server/Session.lua',
    'src/stand/server/Combat.lua', 'src/server/RunLifecycle.lua',
    'tools/qa/campaign_combat_pilot.lua', 'tools/qa/full_campaign_bridge.server.luau',
    'tools/qa/campaign_early_course_pilot.lua', 'tools/qa/full_campaign_client_adapter.luau',
]
def hashes():
    return {name: hashlib.sha256((P / name).read_bytes()).hexdigest() for name in SOURCES}
before = hashes()
assert before['tools/qa/campaign_combat_pilot.lua'] == '4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129'
assert before['tools/qa/full_campaign_bridge.server.luau'] == '97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'

def run(command, log):
    result = subprocess.run([str(x) for x in command], cwd=P, capture_output=True, text=True)
    (R / log).write_text(result.stdout + result.stderr)
    assert result.returncode == 0, (log, result.stdout, result.stderr)
    return result.stdout

run([P / '.tools/python-3.13.9/python.exe', R / 'buzzball-build.py'], 'buzzball-build.txt')
output = run([P / '.tools/luau-0.745/luau.exe', R / 'buzzball-probe.luau'], 'buzzball-outcome.txt')
rows = []
for line in output.splitlines():
    if not line.startswith('BUZZBALL_WHOLE\t'):
        continue
    bits = [x.strip() for x in line.split('\t')]
    row = {}
    for i in range(1, len(bits), 2):
        value = bits[i+1]
        if value in ('true', 'false'):
            value = value == 'true'
        else:
            try:
                value = float(value) if '.' in value else int(value)
            except ValueError:
                pass
        row[bits[i]] = value
    rows.append(row)
assert [row['delay'] for row in rows] == [0, .133]
for row in rows:
    assert row['result'] == 'Won' and row['bossDefeated'] is True
    assert row['bossLife'] == 0 and row['underflows'] == 1
    assert row['phase1Seen'] is True and row['phase2Seen'] is True
    assert row['sameInitialActor'] is True and row['attempt'] == 1 and row['stock'] == 3
    assert row['deaths'] == 0 and row['preparedChaseTransitions'] == 1
    assert row['elapsed'] < 300
assert [row['heroLife'] for row in rows] == [31, 47]
assert [row['heroHits'] for row in rows] == [1, 0]
foot = (R / 'buzzball-foot.lua').read_text()
bridge = (P / 'tools/qa/full_campaign_bridge.server.luau').read_text()
body = foot[foot.index('local function foot(ctx,desired,combatPlan)'):foot.index('return{foot=foot,qa=qa,states=qa.plans,nav=Nav}')].strip()
actual = bridge[bridge.index('local function foot(ctx,desired,combatPlan)'):bridge.index('\nlocal function plan(player)')].strip()
assert body == actual, 'Extracted finished-body foot is the actual working Bridge'
run([P / '.tools/luau-0.745/luau-compile.exe', '--null', R / 'buzzball-fixture.lua',
     R / 'buzzball-foot.lua', R / 'buzzball-probe.luau'], 'buzzball-compile.txt')
assert hashes() == before, 'No source or QA implementation changes during the audit'
data = {
    'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'bounded_prepared_whole_buzzball_GREEN_no_fix',
    'definitionIndex': 11, 'seed': 1158731273, 'maxSeconds': 300,
    'sourceHashes': before, 'actualFootExact': True, 'cases': rows,
    'preparation': [
        'Fresh normal Session Life47/attempt1/three paid reserves; clock advances to2.1 before boss construction, no initial spawn shield is granted',
        'Natural Buzzball constructor raw207/progressnil/Chase on authored finite72x64 arena',
        'Exactly one explicit normal source finishChase() API transition prepares battle entry; Clinger chase/course is not earned by this fixture',
        'Finished single-slot respawn position is read from actual CampaignModes.respawnPosition; no reserve or health assignment',
        'Actual Combat4F plan -> exact actual Bridge97 finished-body branch -> ordinary Session Move/Run/Punch/Jump packets',
    ],
    'sourceOrQAImplementationChanged': False,
    'directBossPhaseOrHitOrResourceWrite': False,
    'limits': [
        'Prepared battle subencounter only; no claim of actual Clinger chase, campaign stage entry, or full13 acceptance',
        'Numerical ground movement, instantaneous facing, gravity and additive impulse presentation boundary; no native Humanoid/rig/decorative collision parity',
        'One seed, one hero, fresh global three-reserve budget; fixed plan cadence.133 and queues0/.133, not exact native transport/resend replay',
        'No Studio, computer control, publishing or Git actions by this audit',
    ],
}
(R / 'buzzball-validation.json').write_text(json.dumps(data, indent=2) + '\n')
print('PASS prepared Buzzball whole encounter2/2; both source phases, canonical arithmetic and unchanged sources')
