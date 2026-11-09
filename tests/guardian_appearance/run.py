"""Run real GuardianAppearance behavior against native API doubles and rigid matrices.

This checks assembly/lifecycle and root-local transforms, not Roblox rendering,
uploaded asset permissions, mesh fit, or a physics simulation.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=str(ROOT / '.tools/luau-0.745/luau.exe'))
args = parser.parse_args()
module = ROOT / 'src/server/gameplay/GuardianAppearance.lua'
# Missing production behavior deliberately reaches the first behavioral assertion
# during RED, rather than hiding it behind a file-open or require error.
source = '[====[' + module.read_text(encoding='utf-8') + ']====]' if module.exists() else 'nil'
harness = Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='bricktoads-guardian-appearance-') as directory:
    runner = Path(directory) / 'contracts.luau'
    runner.write_text('local AppearanceSource=' + source + '\n' + harness, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
