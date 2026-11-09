"""Fetch only the explicitly used public source inputs; never downloads a ROM."""
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

ROOT=Path(__file__).resolve().parents[2]
PIN='f1a43b69577246850d136473700a333b3cdfe93f'
FILES={'main.asm':'Battletoads (U) [!].asm','symbols.map':'Battletoads (U) [!].map',
       'source.lst':'Battletoads (U) [!].lst'}
for relative in ['data/spr_lists1.asm','data/spr_lists2.asm',
    *['gfx/'+n for n in ('rash.asm','sprite0.chr','game_std.chr','level1_obj.4','levels1_5_obj.4',
                         'tall_walker.4','stick.4','common.4','byte_BC65.chr','level1_lift.chr')]]:
    FILES[relative]=relative
for name in ('level1_boss.4','level4_obj.4','l1_boss2.chr','level4_obj2.4','zastavki_bkg.4'):
    FILES['gfx/'+name]='gfx/'+name
for local,upstream in FILES.items():
    target=ROOT/'build/canonical-source'/local
    if target.exists():continue
    target.parent.mkdir(parents=True,exist_ok=True)
    url=f'https://raw.githubusercontent.com/feos-tas/DisAssemble/{PIN}/Battletoads/'+quote(upstream,safe='/')
    with urlopen(url,timeout=45) as response:target.write_bytes(response.read())
    print(local,target.stat().st_size)
