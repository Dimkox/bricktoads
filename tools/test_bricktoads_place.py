"""Test the development place build boundary; Studio import is checked separately."""
import importlib.util
import json
import re
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "tools/build_bricktoads_place.py"


def named(parent, name):
    return next(item for item in parent.findall("Item")
                if item.findtext("Properties/string[@name='Name']") == name)


class BrickToadsPlaceTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(BUILDER.exists(), "development place builder is missing")
        spec = importlib.util.spec_from_file_location("build_bricktoads_place", BUILDER)
        self.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.builder)

    def test_playable_preserves_both_supported_screen_orientations(self):
        root = ET.fromstring(self.builder.build(ROOT))
        starter = named(root, "StarterGui")
        self.assertEqual(starter.findtext("Properties/token[@name='ScreenOrientation']"), "4")

    def test_sources_are_current_and_server_code_is_private(self):
        root = ET.fromstring(self.builder.build(ROOT))
        server = named(named(root, "ServerScriptService"), "BrickToads")
        shared = named(named(root, "ReplicatedStorage"), "BrickToads")
        client = named(named(named(root, "StarterPlayer"), "StarterPlayerScripts"), "BrickToads")
        for container, filename, name, class_name in [
            (server, "server/RunLifecycle.lua", "RunLifecycle", "ModuleScript"),
            (server, "server/BrickToadsServer.server.luau", "BrickToadsServer", "Script"),
            (shared, "shared/BrickToadsConfig.luau", "BrickToadsConfig", "ModuleScript"),
            (client, "client/BrickToadsClient.client.luau", "BrickToadsClient", "LocalScript"),
        ]:
            item = named(container, name)
            self.assertEqual(item.attrib["class"], class_name)
            self.assertEqual(item.findtext("Properties/ProtectedString[@name='Source']"),
                             (ROOT / "src" / filename).read_text(encoding="utf-8"))
        public_sources = "".join(shared.itertext()) + "".join(client.itertext())
        self.assertNotIn((ROOT / "src/server/RunLifecycle.lua").read_text(encoding="utf-8"), public_sources)
        self.assertNotIn("LifecycleSpec", [i.findtext("Properties/string[@name='Name']") for i in root.iter("Item")])

    def test_spawn_is_above_a_collidable_anchored_floor(self):
        workspace = named(ET.fromstring(self.builder.build(ROOT)), "Workspace")
        floor, spawn = named(workspace, "Baseplate"), named(workspace, "SpawnLocation")
        self.assertEqual(spawn.attrib["class"], "SpawnLocation")
        for part in (floor, spawn):
            self.assertEqual(part.findtext("Properties/bool[@name='Anchored']"), "true")
            self.assertEqual(part.findtext("Properties/bool[@name='CanCollide']"), "true")
        floor_top = float(floor.findtext("Properties/CoordinateFrame/Y")) + float(floor.findtext("Properties/Vector3/Y")) / 2
        spawn_bottom = float(spawn.findtext("Properties/CoordinateFrame/Y")) - float(spawn.findtext("Properties/Vector3/Y")) / 2
        self.assertGreaterEqual(spawn_bottom, floor_top)
        self.assertGreater(float(floor.findtext("Properties/Vector3/X")), float(spawn.findtext("Properties/Vector3/X")))

    def test_playable_runtime_reuses_private_combat_sources_without_stand_entrypoint(self):
        root = ET.fromstring(self.builder.build(ROOT))
        server = named(named(root, "ServerScriptService"), "BrickToads")
        runtime = named(server, "CombatRuntime")
        expected = {"Combat", "Session", "Config", "ConnectionRegistry", "RobloxWorld"}
        self.assertEqual({i.findtext("Properties/string[@name='Name']") for i in runtime.findall("Item")}, expected)
        for name in expected:
            source = (ROOT / "src/stand/server" / (name + ".lua")).read_text(encoding="utf-8")
            module = named(runtime, name)
            self.assertEqual(module.attrib["class"], "ModuleScript")
            self.assertEqual(module.findtext("Properties/ProtectedString[@name='Source']"), source)
        all_names = {i.findtext("Properties/string[@name='Name']") for i in root.iter("Item")}
        self.assertNotIn("Stand", all_names)
        self.assertNotIn("Diagnostics", all_names)
        self.assertNotIn("StudioReconnectTransportProbe", all_names)

    def test_rebuild_is_deterministic(self):
        self.assertEqual(self.builder.build(ROOT), self.builder.build(ROOT))

    def test_private_source_receipt_changes_when_an_embedded_source_changes(self):
        def stamp(content):
            server = named(named(ET.fromstring(content), "ServerScriptService"), "BrickToads")
            receipt = named(server, "BuildInfo").findtext("Properties/ProtectedString[@name='Source']")
            return re.search(r"sourceSha256='([0-9a-f]{64})'", receipt).group(1)
        original = stamp(self.builder.build(ROOT))
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / "src", source / "src")
            shutil.copytree(ROOT / "assets", source / "assets")
            file = source / "src/server/gameplay/GameConfig.lua"
            file.write_text(file.read_text() + "\n-- Controlled embedded source identity probe.\n")
            self.assertNotEqual(original, stamp(self.builder.build(source)))

    def test_green_mesh_template_is_serialized_privately_with_exact_pbr_and_attachments(self):
        manifest = json.loads((ROOT / "assets/characters/green-toad.json").read_text(encoding="utf-8"))
        root = ET.fromstring(self.builder.build(ROOT, include_character_study=True))
        folder = named(named(root, "ServerStorage"), "BrickToadsCharacterTemplates")
        template = named(folder, "GreenToad")
        meshes = [p for p in template.findall("Item") if p.attrib["class"] == "MeshPart"]
        self.assertEqual(len(meshes), 15)
        self.assertEqual({p.findtext("Properties/string[@name='Name']") for p in meshes}, {p["name"] for p in manifest["parts"]})
        for row in manifest["parts"]:
            mesh = named(template, row["name"])
            self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"), row["meshId"])
            for flag in ("CanCollide", "CanTouch", "CanQuery"):
                self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"), "false")
            self.assertEqual(mesh.findtext("Properties/bool[@name='Massless']"), "true")
            for surface in row["surfaceAppearances"]:
                appearance = named(mesh, surface["name"])
                for key, prop in (("colorMap", "ColorMap"), ("roughnessMap", "RoughnessMap"), ("metalnessMap", "MetalnessMap")):
                    self.assertEqual(appearance.findtext(f"Properties/Content[@name='{prop}']/url"), surface[key])
            for attachment in row["attachments"]:
                node = named(mesh, attachment["name"])
                self.assertEqual(node.attrib["class"], "Attachment")
                self.assertAlmostEqual(float(node.findtext("Properties/CoordinateFrame[@name='CFrame']/X")), attachment["cframe"][0])
        self.assertFalse({p.attrib["class"] for p in template.iter("Item")} & {"Humanoid", "AnimationConstraint", "BallSocketConstraint", "Script", "Motor6D"})
        self.assertEqual(named(template, "AppearanceScale").findtext("Properties/double[@name='Value']"), "0.8")
        self.assertEqual([p.findtext("Properties/string[@name='Name']") for p in folder.findall("Item")], ["GreenToad"])

    def test_missing_character_resource_fails_instead_of_silently_replacing_mesh_art(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / "src", source / "src")
            with self.assertRaises(FileNotFoundError):
                self.builder.build(source, include_character_study=True)

    def test_rejected_explorer_is_excluded_from_the_playable_by_default(self):
        root = ET.fromstring(self.builder.build(ROOT))
        self.assertFalse([p for p in root.iter("Item") if p.findtext("Properties/string[@name='Name']") == "GreenToad"])
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / "src", source / "src")
            self.builder.build(source)

    def test_missing_sources_fail_without_emitting_an_empty_place(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                self.builder.build(Path(directory))

    def test_conflicting_lua_and_luau_names_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            for scope in ("server", "client", "shared"):
                (source / "src" / scope).mkdir(parents=True)
            (source / "src/server/RunLifecycle.lua").write_text("return {}", encoding="utf-8")
            (source / "src/server/RunLifecycle.luau").write_text("return {}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                self.builder.build(source)

    def test_server_scripts_cannot_be_built_into_public_containers(self):
        for scope in ("shared", "client"):
            with self.subTest(scope=scope), tempfile.TemporaryDirectory() as directory:
                source = Path(directory)
                shutil.copytree(ROOT / "src", source / "src")
                (source / "src" / scope / "Private.server.luau").write_text("return 'private'", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Server script"):
                    self.builder.build(source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
