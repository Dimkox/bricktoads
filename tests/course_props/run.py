"""Lifecycle doubles; native Studio separately verifies resource rendering and axes."""
import argparse, json, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau',default=str(ROOT/'.tools/luau-0.745/luau.exe'))
args=parser.parse_args()
source=ROOT/'src/server/gameplay/CoursePropAppearance.lua'
if not source.is_file(): raise SystemExit('RED: CoursePropAppearance is missing')
helpers=(ROOT/'tests/character_appearance/contracts.luau').read_text().split("local storage=node('ServerStorage')",1)[0]
with tempfile.TemporaryDirectory(prefix='bricktoads-props-') as directory:
    runner=Path(directory)/'contracts.luau'
    runner.write_text('local AppearanceSource='+json.dumps(source.read_text())+'\n'+helpers+Path(__file__).with_name('contracts.luau').read_text())
    raise SystemExit(subprocess.run([args.luau,str(runner)],cwd=ROOT).returncode)
