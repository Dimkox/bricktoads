#!/usr/bin/env python3
"""Structural source/serialization checks, explicitly not Roblox playtests."""
from __future__ import annotations
import hashlib
import importlib.util
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SERVER = {"Combat", "Config", "Session", "RobloxWorld", "Stand", "RunLifecycle"}


class StandBuildTests(unittest.TestCase):
    def build(self) -> bytes:
        path = ROOT / "tools/build_combat_stand.py"
        self.assertTrue(path.is_file(), "Combat stand builder must be implemented")
        spec = importlib.util.spec_from_file_location("stand_builder", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.build(ROOT)

    def test_deterministic_serialization(self):
        self.assertEqual(self.build(), self.build())

    def test_server_layout_and_exact_sources(self):
        tree = ET.fromstring(self.build())
        server = tree.find("./Item[@class='ServerScriptService']/Item")
        scripts = {i.findtext("Properties/string[@name='Name']"): i for i in server.findall("Item")}
        self.assertEqual(set(scripts), SERVER)
        for name, item in scripts.items():
            path = ROOT / ("src/server/RunLifecycle.lua" if name == "RunLifecycle" else
                           f"src/stand/server/{name}{'.server' if name == 'Stand' else ''}.lua")
            self.assertEqual(item.findtext("Properties/ProtectedString[@name='Source']"), path.read_text())
            self.assertEqual(item.get("class"), "Script" if name == "Stand" else "ModuleScript")

    def test_client_is_local_and_core_is_not_replicated(self):
        tree = ET.fromstring(self.build())
        client = tree.find("./Item[@class='StarterPlayer']/Item/Item[@class='LocalScript']")
        self.assertIsNotNone(client)
        self.assertEqual(client.findtext("Properties/ProtectedString[@name='Source']"),
                         (ROOT / "src/stand/client/Stand.client.lua").read_text())
        replicated = tree.find("./Item[@class='ReplicatedStorage']")
        self.assertEqual(replicated.findall(".//ProtectedString"), [])

    def test_no_automatic_avatar_or_external_assets(self):
        tree = ET.fromstring(self.build())
        self.assertEqual(tree.findtext("./Item[@class='Players']/Properties/bool[@name='CharacterAutoLoads']"), "false")
        self.assertEqual(tree.findall(".//Content"), [])
        self.assertEqual(tree.findall(".//BinaryString"), [])
        for source in tree.findall(".//ProtectedString"):
            self.assertNotIn("rbxassetid://", source.text)

    def test_unique_referents_and_names(self):
        tree = ET.fromstring(self.build())
        refs = [i.attrib['referent'] for i in tree.iter("Item")]
        self.assertEqual(len(refs), len(set(refs)))
        for parent in tree.iter():
            names = [i.findtext("Properties/string[@name='Name']") for i in parent.findall("Item")]
            self.assertEqual(len(names), len(set(names)))

    def test_verified_core_unchanged(self):
        raw = (ROOT / "src/server/RunLifecycle.lua").read_bytes()
        self.assertEqual(hashlib.sha1(f"blob {len(raw)}\0".encode()+raw).hexdigest(),
                         "274e59f2bfe347e4496fdad7c9f617b2c32aa271")

    def test_runtime_sources_exist(self):
        for rel in ["src/stand/server/RobloxWorld.lua", "src/stand/server/Stand.server.lua",
                    "src/stand/client/Stand.client.lua"]:
            self.assertTrue((ROOT/rel).is_file(), rel + " must be implemented")


if __name__ == "__main__":
    unittest.main(verbosity=2)
