"""Exercise actual course cosmetics against instance/transform doubles; Studio checks rendering."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=str(ROOT / '.tools/luau-0.745/luau.exe'))
args = parser.parse_args()
source = ROOT / 'src/server/gameplay/CourseAppearance.lua'
if not source.is_file():
    raise SystemExit('RED: CourseAppearance module is missing')
helpers = (ROOT / 'tests/character_appearance/contracts.luau').read_text(encoding='utf-8').split("local storage=node('ServerStorage')", 1)[0]
prefix = 'local AppearanceSource=' + json.dumps(source.read_text(encoding='utf-8')) + '\n'
with tempfile.TemporaryDirectory(prefix='bricktoads-course-') as directory:
    runner = Path(directory) / 'contracts.luau'
    runner.write_text(prefix + helpers + Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8'), encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
