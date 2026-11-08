"""Verify the isolated Studio acceptance package without claiming an engine run."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LUAU = None


def named(parent, name):
    return next(item for item in parent.findall("Item")
                if item.findtext("Properties/string[@name='Name']") == name)


class WalkerAcceptanceBuildTests(unittest.TestCase):
    def setUp(self):
        path = ROOT / "tools/build_walker_acceptance.py"
        self.assertTrue(path.is_file(), "isolated Walker acceptance builder is missing")
        spec = importlib.util.spec_from_file_location("build_walker_acceptance", path)
        self.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.builder)

    def test_only_acceptance_entrypoint_runs_and_sources_are_preserved(self):
        package = ET.fromstring(self.builder.build(ROOT))
        server = named(package, "ServerScriptService")
        project = named(server, "BrickToads")
        for item in package.iter("Item"):
            if item.attrib["class"] not in ("Script", "LocalScript"):
                continue
            name = item.findtext("Properties/string[@name='Name']")
            disabled = item.findtext("Properties/bool[@name='Disabled']")
            self.assertEqual(disabled, "false" if name == "WalkerHeavyAcceptance" else "true")
        entrypoint = named(project, "BrickToadsServer")
        self.assertEqual(entrypoint.findtext("Properties/ProtectedString[@name='Source']"),
                         (ROOT / "src/server/BrickToadsServer.server.luau").read_text(encoding="utf-8"))
        gameplay = named(project, "gameplay")
        self.assertEqual(named(gameplay, "LevelDirector").findtext("Properties/ProtectedString[@name='Source']"),
                         (ROOT / "src/server/gameplay/LevelDirector.lua").read_text(encoding="utf-8"))
        acceptance = named(server, "WalkerAcceptance")
        self.assertEqual(named(acceptance, "WalkerHeavyAcceptance").findtext("Properties/ProtectedString[@name='Source']"),
                         (ROOT / "tests/gameplay/WalkerHeavyStudioAcceptance.server.luau").read_text(encoding="utf-8"))

    def test_manifest_identifies_exact_source_bytes_without_fabricated_results(self):
        package = ET.fromstring(self.builder.build(ROOT))
        acceptance = named(named(package, "ServerScriptService"), "WalkerAcceptance")
        manifest = json.loads(named(acceptance, "SourceManifest").findtext("Properties/string[@name='Value']"))
        self.assertEqual(manifest["engine_status"], "not_run")
        paths = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in (ROOT / "src").rglob("*") if path.is_file() and path.suffix in (".lua", ".luau")}
        paths["tests/gameplay/WalkerHeavyStudioAcceptance.server.luau"] = hashlib.sha256(
            (ROOT / "tests/gameplay/WalkerHeavyStudioAcceptance.server.luau").read_bytes()).hexdigest()
        self.assertEqual(manifest["source_sha256"], paths)
        expected = hashlib.sha256(json.dumps(paths, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        self.assertEqual(manifest["source_pack_sha256"], expected)
        self.assertNotIn("pass", manifest)

    def test_source_edit_changes_receipt_and_build_is_deterministic(self):
        content = self.builder.build(ROOT)
        self.assertEqual(content, self.builder.build(ROOT))
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory)
            shutil.copytree(ROOT / "src", copy / "src")
            shutil.copytree(ROOT / "tests/gameplay", copy / "tests/gameplay")
            path = copy / "src/server/gameplay/LevelDirector.lua"
            path.write_text(path.read_text(encoding="utf-8") + "\n-- Controlled source mutation for build identity.\n", encoding="utf-8")
            self.assertNotEqual(content, self.builder.build(copy))
            (copy / "tests/gameplay/WalkerHeavyStudioAcceptance.server.luau").unlink()
            with self.assertRaises(FileNotFoundError):
                self.builder.build(copy)

    def test_normal_playable_does_not_contain_acceptance_runner(self):
        package = ET.fromstring(self.builder.playable.build(ROOT))
        names = {item.findtext("Properties/string[@name='Name']") for item in package.iter("Item")}
        self.assertTrue({"WalkerAcceptance", "WalkerHeavyAcceptance", "SourceManifest"}.isdisjoint(names))

    def test_runner_returns_before_side_effects_outside_studio_server(self):
        if not LUAU:
            self.skipTest("pass --luau to execute the runner's environment guard")
        source = (ROOT / "tests/gameplay/WalkerHeavyStudioAcceptance.server.luau").read_text(encoding="utf-8")
        for studio, server in ((False, False), (False, True), (True, False)):
            with self.subTest(studio=studio, server=server), tempfile.TemporaryDirectory() as directory:
                script = Path(directory) / "guard.luau"
                script.write_text("local calls=0\nlocal game={}\nfunction game:GetService(name)\n"
                                  "calls+=1; assert(name=='RunService','acceptance escaped its guard')\n"
                                  "return {IsStudio=function() return " + str(studio).lower() + " end,\n"
                                  "IsServer=function() return " + str(server).lower() + " end}\nend\n"
                                  "local function run()\n" + source + "\nend\nrun()\nassert(calls==1)\n", encoding="utf-8")
                result = subprocess.run([LUAU, str(script)], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", help="Luau CLI for the environment-guard probe; never executes Studio APIs")
    args, remaining = parser.parse_known_args()
    LUAU = args.luau
    unittest.main(argv=[__file__, *remaining], verbosity=2)
