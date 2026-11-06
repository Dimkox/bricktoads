#!/usr/bin/env python3
"""Structural tests for the generated test place; not Roblox import validation."""
from pathlib import Path
import importlib.util
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/build_test_place.py"

class BuildTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE_PATH.exists(), "build_test_place.py must be implemented")
        spec = importlib.util.spec_from_file_location("build_test_place", MODULE_PATH)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        self.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.builder)

    def test_sources_are_exact_and_server_only(self):
        xml = self.builder.build(ROOT)
        root = ET.fromstring(xml)
        self.assertEqual(root.tag, "roblox")
        self.assertEqual(root.attrib["version"], "4")
        services = {item.findtext("Properties/string[@name='Name']"): item for item in root.findall("Item")}
        self.assertEqual(set(services), {"ServerScriptService"})
        service = services["ServerScriptService"]
        modules = {i.findtext("Properties/string[@name='Name']"): i for i in service.findall("Item")}
        self.assertEqual(set(modules), {"RunLifecycle", "LifecycleSpec", "RunContractTests"})
        self.assertEqual(modules["RunLifecycle"].findtext("Properties/ProtectedString[@name='Source']"), (ROOT/"src/server/RunLifecycle.lua").read_text())
        self.assertEqual(modules["LifecycleSpec"].findtext("Properties/ProtectedString[@name='Source']"), (ROOT/"tests/Lifecycle.spec.lua").read_text())
        bootstrap = modules["RunContractTests"].findtext("Properties/ProtectedString[@name='Source']")
        self.assertIn('IsStudio()', bootstrap)
        self.assertIn('CharacterAutoLoads = false', bootstrap)

    def test_build_is_deterministic(self):
        self.assertEqual(self.builder.build(ROOT), self.builder.build(ROOT))

    def test_missing_source_fails_instead_of_empty_module(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                self.builder.build(Path(directory))

if __name__ == "__main__":
    unittest.main(verbosity=2)
