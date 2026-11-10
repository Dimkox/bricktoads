"""Cross-platform audio policy and production PCM checks (Python stdlib only)."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", help="Path to the native Luau CLI")
    args = parser.parse_args()
    bundled = ROOT / ".tools/luau-0.745/luau.exe"
    cli = args.luau or shutil.which("luau") or (str(bundled) if bundled.exists() else None)
    if not cli:
        parser.error("Luau CLI required; pass --luau /path/to/luau")
    for command in ([cli, "tests/run_audio_fx.luau"],
                    [sys.executable, "tests/audio_fx/test_client_audio_controls.py", "--luau", cli],
                    [sys.executable, "tests/audio_fx/test_audio_assets.py"]):
        result = subprocess.run(command, cwd=ROOT)
        if result.returncode:
            return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
