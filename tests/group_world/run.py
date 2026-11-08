"""Run focused world-coordinate contracts against real sources in native Luau.

The Roblox API double checks coordinate routing and ownership only, not physics.
"""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default=shutil.which("luau") or str(ROOT / ".tools/luau-0.745/luau.exe"))
arguments = parser.parse_args()
SCRIPTS = (
    ("WorldSource", "src/server/gameplay/GameWorld.lua"),
    ("CameraSource", "src/client/SpectatorCamera.luau"),
    ("LevelSource", "src/server/gameplay/LevelDefinition.lua"),
    ("BaseWorldSource", "src/stand/server/RobloxWorld.lua"),
)
prefix = "\n".join(
    f"local {name} = [====[{(ROOT / path).read_text(encoding='utf-8')}]====]"
    for name, path in SCRIPTS
)
adapter = ROOT / 'src/server/gameplay/DragonWorld.lua'
prefix += '\nlocal DragonWorldSource = [====[' + adapter.read_text(encoding='utf-8') + ']====]'
with tempfile.TemporaryDirectory(prefix="bricktoads-world-") as directory:
    runner = Path(directory) / "world_contracts.luau"
    runner.write_text(prefix + "\n" + (Path(__file__).with_name("contracts.luau")).read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([arguments.luau, str(runner)], cwd=ROOT)
    raise SystemExit(result.returncode)
