"""Exercise imported intro-leg validation, fallback and party cleanup.

This uses the rigid transforms and API doubles from the Guardian contracts;
it does not prove uploaded mesh permissions, rendering or native physics.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=str(ROOT / '.tools/luau-0.745/luau.exe'))
args = parser.parse_args()
shared = (ROOT / 'tests/guardian_appearance/contracts.luau').read_text(encoding='utf-8')
anchor = "local names={'GuardianChassis','GuardianLeftCannon','GuardianRightCannon'}"
assert shared.count(anchor) == 1, 'Guardian doubles moved; review intro asset harness'
prefix = shared.split(anchor, 1)[0]
source = (ROOT / 'src/server/gameplay/BossIntroWorld.lua').read_text(encoding='utf-8')
contracts = Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='bricktoads-boss-intro-asset-') as directory:
    runner = Path(directory) / 'contracts.luau'
    runner.write_text('local IntroSource=[====[' + source + ']====]\n' + prefix + contracts,
                      encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
