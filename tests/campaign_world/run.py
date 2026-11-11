"""Exercise campaign adapters with the existing world API double; physics needs Studio."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default=str(ROOT / '.tools/luau-0.745/luau.exe'))
args = parser.parse_args()
sources = {
    'WorldSource': 'src/server/gameplay/GameWorld.lua',
    'CameraSource': 'src/client/SpectatorCamera.luau',
    'LevelSource': 'src/server/gameplay/LevelDefinition.lua',
    'BaseWorldSource': 'src/stand/server/RobloxWorld.lua',
    'DragonWorldSource': 'src/server/gameplay/DragonWorld.lua',
    'CampaignWorldSource': 'src/server/gameplay/CampaignWorld.lua',
    'CourseAppearanceSource': 'src/server/gameplay/CourseAppearance.lua',
    'CoursePropAppearanceSource': 'src/server/gameplay/CoursePropAppearance.lua',
    'SourceCombatSource': 'src/server/gameplay/SourceCombat.lua',
}
prefix = '\n'.join(f'local {name} = [====[{(ROOT / path).read_text(encoding="utf-8")}]====]'
                   for name, path in sources.items())
fixture = (ROOT / 'tests/group_world/contracts.luau').read_text(encoding='utf-8')
contracts = Path(__file__).with_name('contracts.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='bricktoads-campaign-world-') as directory:
    runner = Path(directory) / 'contracts.luau'
    runner.write_text(prefix + '\n' + fixture + '\n' + contracts, encoding='utf-8')
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
