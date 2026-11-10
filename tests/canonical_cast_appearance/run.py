"""Exercise actual cast skin code against lifecycle API doubles, not engine physics."""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import argparse

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau',default=str(ROOT/'.tools/luau-0.745/luau.exe'))
args=parser.parse_args()
source=(ROOT/'src/server/gameplay/CanonicalCastAppearance.lua')
if not source.exists():
    raise SystemExit('RED: CanonicalCastAppearance module is missing')
helpers=(ROOT/'tests/character_appearance/contracts.luau').read_text(encoding='utf-8').split("local storage=node('ServerStorage')",1)[0]
prefix='local AppearanceSource='+json.dumps(source.read_text(encoding='utf-8'))+'\n'
(ROOT/'build').mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='cast-contracts-',dir=ROOT/'build') as directory:
    runner=Path(directory)/'cast.luau'
    relative=os.path.relpath(ROOT/'src/server/gameplay/CanonicalCastPresentation',directory).replace('\\','/')
    prefix+='local ActualPresentation=require('+json.dumps(relative)+')\n'
    runner.write_text(prefix+helpers+(Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8')),encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau,str(runner)],cwd=ROOT).returncode)
