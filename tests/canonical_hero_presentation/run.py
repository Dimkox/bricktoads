"""Real source-frame selection and cosmetic Motor6D wiring, using native API doubles.

This proves source/actor routing and C0 writes, not rendered mesh fit or physics.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + json.dumps(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return 'nil' if value is None else json.dumps(value)


def source(name, path):
    return f'local {name}=[====[{(ROOT / path).read_text(encoding="utf-8")}]====]\n'


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=str(ROOT / '.tools/luau-0.745/luau.exe'))
args = parser.parse_args()
prefix = source('AnimationSource', 'src/server/gameplay/CanonicalAnimation.lua')
prefix += source('PresentationSource', 'src/server/gameplay/CanonicalHeroPresentation.lua')
prefix += source('AppearanceSource', 'src/server/gameplay/CharacterAppearance.lua')
prefix += '''local CanonicalAnimation=assert(loadstring(AnimationSource))()
local presentationLoader=assert(loadstring(PresentationSource))
setfenv(presentationLoader,setmetatable({script={Parent={CanonicalAnimation='source-animation'}},
    require=function(name)assert(name=='source-animation');return CanonicalAnimation end},{__index=getfenv()}))
local CanonicalPresentation=presentationLoader()
'''
manifest = json.loads((ROOT / 'assets/characters/green-toad.json').read_text(encoding='utf-8'))
prefix += 'local Manifest=' + lua(manifest) + '\n'
rotated_manifest = json.loads((ROOT / 'assets/characters/canonical-hero/roblox-player1.json').read_text(encoding='utf-8'))
prefix += 'local RotatedRestManifest=' + lua(rotated_manifest) + '\n'
ride_manifests = {
    hero: json.loads((ROOT / f'assets/characters/canonical-hero/{name}').read_text(encoding='utf-8'))
    for hero, name in [('Mr. Green', 'roblox-player1.json'), ('Mr. Yellow', 'roblox-player2.json'), ('Mr. Brown', 'roblox-brown.json')]
}
prefix += 'local RideRestManifests=' + lua(ride_manifests) + '\n'
harness = (ROOT / 'tests/character_appearance/contracts.luau').read_text(encoding='utf-8')
anchor = 'local env=setmetatable({game='
assert harness.count(anchor) == 1, 'Appearance harness loader moved; review injection'
harness = harness.replace(anchor, "local env=setmetatable({script={Parent={CanonicalHeroPresentation='hero-presentation'}},require=function(name)assert(name=='hero-presentation');return CanonicalPresentation end,Vector3={new=vector},game=", 1)
contracts = Path(__file__).with_name('appearance_contracts.luau').read_text(encoding='utf-8')
rotated_contracts = Path(__file__).with_name('rotated_rest_contracts.luau').read_text(encoding='utf-8')
morph_contracts = Path(__file__).with_name('morph_contracts.luau').read_text(encoding='utf-8')
fear_contracts = Path(__file__).with_name('fear_contracts.luau').read_text(encoding='utf-8')
brown_contracts = Path(__file__).with_name('brown_contracts.luau').read_text(encoding='utf-8')
geometry_contracts = Path(__file__).with_name('geometry_contracts.luau').read_text(encoding='utf-8')
ride_contracts = Path(__file__).with_name('ride_contracts.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='bricktoads-source-presentation-') as directory:
    runner = Path(directory) / 'presentation_contracts.luau'
    runner.write_text(prefix + harness + '\n' + contracts + '\n' + rotated_contracts + '\n' + morph_contracts + '\n' + fear_contracts + '\n' + brown_contracts + '\n' + geometry_contracts + '\n' + ride_contracts, encoding='utf-8')
    result = subprocess.run([args.luau, str(runner)], cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.returncode)
    world_prefix = ''.join(source(name, path) for name, path in (
        ('WorldSource', 'src/server/gameplay/GameWorld.lua'),
        ('CameraSource', 'src/client/SpectatorCamera.luau'),
        ('LevelSource', 'src/server/gameplay/LevelDefinition.lua'),
        ('BaseWorldSource', 'src/stand/server/RobloxWorld.lua'),
        ('DragonWorldSource', 'src/server/gameplay/DragonWorld.lua'),
    ))
    world_harness = (ROOT / 'tests/group_world/contracts.luau').read_text(encoding='utf-8')
    world_contracts = Path(__file__).with_name('world_contracts.luau').read_text(encoding='utf-8')
    runner.write_text(world_prefix + world_harness + '\n' + world_contracts, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
