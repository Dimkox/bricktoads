"""Native lifetime/retarget contracts; actual joint fit is a separate Studio check."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + json.dumps(k) + "]=" + lua(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    if value is None:
        return "nil"
    return json.dumps(value)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--luau", default=str(ROOT / ".tools/luau-0.745/luau.exe"))
args = parser.parse_args()
manifest = json.loads((ROOT / "assets/characters/green-toad.json").read_text(encoding="utf-8"))
source = (ROOT / "src/server/gameplay/CharacterAppearance.lua").read_text(encoding="utf-8")
prefix = "local AppearanceSource=[====[" + source + "]====]\nlocal Manifest=" + lua(manifest) + "\n"
with tempfile.TemporaryDirectory(prefix="bricktoads-appearance-") as directory:
    runner = Path(directory) / "appearance_contracts.luau"
    runner.write_text(prefix + Path(__file__).with_name("contracts.luau").read_text(encoding="utf-8"), encoding="utf-8")
    raise SystemExit(subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode)
