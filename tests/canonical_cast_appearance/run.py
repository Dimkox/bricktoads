"""Exercise actual cast skin code against lifecycle API doubles, not engine physics."""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import argparse

ROOT=Path(__file__).resolve().parents[2]
def lua(value):
    if isinstance(value,dict):
        return '{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in value.items())+'}'
    if isinstance(value,list): return '{'+','.join(lua(v) for v in value)+'}'
    return 'nil' if value is None else json.dumps(value)

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau',default=str(ROOT/'.tools/luau-0.745/luau.exe'))
args=parser.parse_args()
source=(ROOT/'src/server/gameplay/CanonicalCastAppearance.lua')
if not source.exists():
    raise SystemExit('RED: CanonicalCastAppearance module is missing')
helpers=(ROOT/'tests/character_appearance/contracts.luau').read_text(encoding='utf-8').split("local storage=node('ServerStorage')",1)[0]
prefix='local AppearanceSource='+json.dumps(source.read_text(encoding='utf-8'))+'\n'
queen=next(t for t in json.loads((ROOT/'assets/characters/canonical-cast/roblox-cast.json').read_text(encoding='utf-8'))['templates'] if t['name']=='DarkQueen')
prefix+='local QueenManifest='+lua(queen)+'\n'
(ROOT/'build').mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='cast-contracts-',dir=ROOT/'build') as directory:
    runner=Path(directory)/'cast.luau'
    relative=os.path.relpath(ROOT/'src/server/gameplay/CanonicalCastPresentation',directory).replace('\\','/')
    prefix+='local ActualPresentation=require('+json.dumps(relative)+')\n'
    contracts=Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8')
    queen_contracts=Path(__file__).with_name('queen_contracts.luau').read_text(encoding='utf-8')
    runner.write_text(prefix+helpers+contracts+'\n'+queen_contracts,encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau,str(runner)],cwd=ROOT).returncode)
