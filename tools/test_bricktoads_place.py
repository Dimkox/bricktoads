"""Test the development place build boundary; Studio import is checked separately."""
import importlib.util
import copy
import hashlib
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
    def morph_fixture(self, source):
        shutil.copytree(ROOT / 'src', source / 'src')
        shutil.copytree(ROOT / 'assets', source / 'assets')
        folder = source / 'assets/characters/canonical-hero'
        blob = b'explicit packaging fixture, never uploaded as an asset'
        (folder / 'hero-attack-morphs.glb').write_bytes(blob)
        row = copy.deepcopy(json.loads((folder / 'roblox-player1.json').read_text())['parts'][0])
        row.update(name='Morph', cframe=[0, -.5, -.2, 1,0,0, 0,1,0, 0,0,1],
                   attachments=[{'name':'MorphOriginRigAttachment',
                                 'cframe':[0,.5,.2, 1,0,0, 0,1,0, 0,0,1]}])
        manifest = {'schema':1, 'appearanceProfile':'CanonicalNESHeroMorph',
                    'sourceAssetId':'987654321', 'sourceGlbFile':'hero-attack-morphs.glb',
                    'sourceGlbSha256':hashlib.sha256(blob).hexdigest(), 'templates':[]}
        for prefix, hero in [('Green','Mr. Green'), ('PlayerTwo','Mr. Yellow')]:
            for kind in ('PowerFist','BigBoot'):
                manifest['templates'].append({'name':prefix+kind, 'heroTemplate':hero,
                    'morphKind':kind, 'appearanceScale':1, 'part':copy.deepcopy(row)})
        path = folder / 'roblox-attack-morphs.json'
        path.write_text(json.dumps(manifest), encoding='utf-8')
        return path, manifest

    def test_attack_morphs_preserve_private_identity_origin_extents_and_pbr(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory); path, manifest=self.morph_fixture(source)
            root=ET.fromstring(self.builder.build(source))
            folder=named(named(root,'ServerStorage'),'BrickToadsCharacterMorphs')
            self.assertEqual({p.findtext("Properties/string[@name='Name']") for p in folder.findall('Item')},
                             {p['name'] for p in manifest['templates']})
            for row in manifest['templates']:
                model=named(folder,row['name']); mesh=named(model,'Morph')
                for key,value in [('AppearanceProfile','CanonicalNESHeroMorph'),('HeroTemplate',row['heroTemplate']),
                                  ('MorphKind',row['morphKind']),('SourceAssetId',manifest['sourceAssetId']),
                                  ('SourceGlbSha256',manifest['sourceGlbSha256'])]:
                    self.assertEqual(named(model,key).findtext("Properties/string[@name='Value']"),value)
                self.assertEqual(named(model,'AppearanceScale').findtext("Properties/double[@name='Value']"),'1')
                self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"),row['part']['meshId'])
                for axis,value in zip('XYZ',row['part']['meshSize']):
                    self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='InitialSize']/{axis}")),value)
                self.assertEqual(named(mesh,'MorphOriginRigAttachment').attrib['class'],'Attachment')
                self.assertFalse({p.attrib['class'] for p in model.iter('Item')} & {'Script','LocalScript','Humanoid','Motor6D','Bone'})
                for flag,value in [('Anchored','true'),('Massless','true'),('CanCollide','false'),('CanTouch','false'),('CanQuery','false')]:
                    self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"),value)
                for surface in row['part']['surfaceAppearances']:
                    self.assertEqual(named(mesh,surface['name']).findtext("Properties/Content[@name='ColorMap']/url"),surface['colorMap'])

    def test_attack_morphs_reject_wrong_palette_origin_and_missing_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory); path, base=self.morph_fixture(source)
            cases=[('profile',lambda r:r.update(appearanceProfile='Unknown')),
                   ('duplicate',lambda r:r['templates'][-1].update(name=r['templates'][0]['name'])),
                   ('missing',lambda r:r['templates'].pop()),
                   ('palette',lambda r:r['templates'][0].update(heroTemplate='Mr. Yellow')),
                   ('scale',lambda r:r['templates'][0].update(appearanceScale=.5)),
                   ('origin',lambda r:r['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(0,2)),
                   ('runtime-origin-tolerance',lambda r:r['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(0,.0005)),
                   ('invisible-morph',lambda r:r['templates'][0]['part'].update(transparency=1)),
                   ('extent',lambda r:r['templates'][0]['part'].update(meshSize=[0,1,1])),
                   ('wrong-sha',lambda r:r.update(sourceGlbSha256='0'*64)),
                   ('source-path',lambda r:r.update(sourceGlbFile='../outside.glb'))]
            for name,change in cases:
                with self.subTest(case=name):
                    altered=copy.deepcopy(base);change(altered);path.write_text(json.dumps(altered),encoding='utf-8')
                    with self.assertRaises(ValueError):self.builder.build(source)
            path.unlink()
            with self.assertRaises(FileNotFoundError):self.builder.build(source)

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
            initial = mesh.find("Properties/Vector3[@name='InitialSize']")
            self.assertIsNotNone(initial, 'Saved MeshParts must preserve their source geometry extent')
            for axis, value in zip('XYZ', row.get('meshSize', row['size'])):
                self.assertEqual(float(initial.findtext(axis)), value)
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
        self.assertEqual([p.findtext("Properties/string[@name='Name']") for p in folder.findall("Item")],
                         ["CanonicalPlayer1", "CanonicalPlayer2", "GreenToad"])
        self.assertEqual(sum(p.attrib['class']=='ServerStorage' for p in root.findall('Item')),1)
        self.assertEqual(sum(p.findtext("Properties/string[@name='Name']")=='BrickToadsCharacterTemplates'
                             for p in named(root,'ServerStorage').findall('Item')),1)

    def test_missing_character_resource_fails_instead_of_silently_replacing_mesh_art(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / "src", source / "src")
            shutil.copytree(ROOT / "assets/characters/canonical-hero", source / "assets/characters/canonical-hero")
            with self.assertRaises(FileNotFoundError):
                self.builder.build(source, include_character_study=True)

    def test_rejected_explorer_is_excluded_from_the_playable_by_default(self):
        root = ET.fromstring(self.builder.build(ROOT))
        self.assertFalse([p for p in root.iter("Item") if p.findtext("Properties/string[@name='Name']") == "GreenToad"])
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / "src", source / "src")
            shutil.copytree(ROOT / "assets/characters/canonical-hero", source / "assets/characters/canonical-hero")
            self.builder.build(source)

    def test_canonical_player_templates_are_default_private_exact_uploaded_resources(self):
        root=ET.fromstring(self.builder.build(ROOT))
        storage=next((p for p in root.findall('Item') if p.attrib['class']=='ServerStorage'),None)
        self.assertIsNotNone(storage,'Default playable must package both canonical player resources')
        folder=named(storage,'BrickToadsCharacterTemplates')
        self.assertEqual([p.findtext("Properties/string[@name='Name']") for p in folder.findall('Item')],
                         ['CanonicalPlayer1','CanonicalPlayer2'])
        source_asset_ids=[]
        mesh_sets=[]
        for player in (1,2):
            path=ROOT/f'assets/characters/canonical-hero/roblox-player{player}.json'
            manifest=json.loads(path.read_text(encoding='utf-8'))
            template=named(folder,f'CanonicalPlayer{player}')
            self.assertEqual(template.attrib['class'],'Model')
            for name,value in [('AppearanceProfile','CanonicalNESHero'),('SourceAssetId',manifest['sourceAssetId']),
                               ('SourceGlbSha256',manifest['sourceGlbSha256']),
                               ('AssetManifestSha256',hashlib.sha256(path.read_bytes()).hexdigest())]:
                self.assertEqual(named(template,name).findtext("Properties/string[@name='Value']"),value)
            self.assertEqual(float(named(template,'AppearanceScale').findtext("Properties/double[@name='Value']")),1)
            meshes=[p for p in template.findall('Item') if p.attrib['class']=='MeshPart']
            self.assertEqual(len(meshes),15)
            self.assertEqual(sum(p.attrib['class']=='Attachment' for p in template.iter('Item')),28)
            for row in manifest['parts']:
                mesh=named(template,row['name'])
                self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"),row['meshId'])
                self.assertIsNotNone(mesh.find("Properties/Content[@name='TextureID']/null"))
                for axis,value in zip('XYZ',row['size']):
                    self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='size']/{axis}")),value)
                initial = mesh.find("Properties/Vector3[@name='InitialSize']")
                self.assertIsNotNone(initial, 'MeshId and resized size alone restore MeshSize as zero')
                for axis, value in zip('XYZ', row['meshSize']):
                    self.assertEqual(float(initial.findtext(axis)), value)
                self.assertIsNone(mesh.find("Properties/Vector3[@name='MeshSize']"),
                                  'Read-only MeshSize is saved under the InitialSize property')
                fields=('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22')
                for field,value in zip(fields,row['cframe']):
                    self.assertEqual(float(mesh.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{field}")),value)
                color=[round(v*255) for v in row['color']]
                self.assertEqual(int(mesh.findtext("Properties/Color3uint8[@name='Color3uint8']")),
                                 0xFF000000 | color[0]<<16 | color[1]<<8 | color[2])
                for flag,value in [('Anchored','true'),('Massless','true'),('CanCollide','false'),
                                   ('CanTouch','false'),('CanQuery','false')]:
                    self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"),value)
                for attachment in row['attachments']:
                    target=named(mesh,attachment['name'])
                    for field,value in zip(fields,attachment['cframe']):
                        self.assertEqual(float(target.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{field}")),value)
            self.assertFalse({p.attrib['class'] for p in template.iter('Item')} &
                             {'Script','LocalScript','Humanoid','Motor6D','Bone','AnimationConstraint'})
            source_asset_ids.append(manifest['sourceAssetId'])
            mesh_sets.append({p['meshId'] for p in manifest['parts']})
        self.assertNotEqual(source_asset_ids[0],source_asset_ids[1])
        self.assertNotEqual(mesh_sets[0],mesh_sets[1],'P2 uses the actual separate uploaded palette mesh assets')
        entry=named(named(named(root,'ServerScriptService'),'BrickToads'),'BrickToadsServer')
        self.assertIn('characterAppearance=require(gameplay.CharacterAppearance)',
                      entry.findtext("Properties/ProtectedString[@name='Source']"))

    def test_missing_either_canonical_manifest_fails_closed(self):
        for player in (1,2):
            with self.subTest(player=player),tempfile.TemporaryDirectory() as directory:
                source=Path(directory)
                shutil.copytree(ROOT/'src',source/'src')
                shutil.copytree(ROOT/'assets',source/'assets')
                (source/f'assets/characters/canonical-hero/roblox-player{player}.json').unlink()
                with self.assertRaises(FileNotFoundError):self.builder.build(source)

    def test_explicit_canonical_glb_basename_replaces_only_the_default_source_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(ROOT / 'assets/characters/canonical-hero', folder)
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            default = folder / manifest.get('sourceGlbFile', 'canonical-hero-player1.glb')
            selected = folder / 'review-versioned-hero.glb'
            default.rename(selected)
            manifest['sourceGlbFile'] = selected.name
            path.write_text(json.dumps(manifest), encoding='utf-8')
            root = ET.fromstring(self.builder.build(source))
            template = named(named(named(root, 'ServerStorage'), 'BrickToadsCharacterTemplates'), 'CanonicalPlayer1')
            self.assertEqual(named(template, 'SourceGlbSha256').findtext("Properties/string[@name='Value']"),
                             manifest['sourceGlbSha256'])
            self.assertEqual(len([p for p in template.findall('Item') if p.attrib['class'] == 'MeshPart']), 15)

    def test_canonical_glb_filename_rejects_paths_extensions_and_empty_values(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(ROOT / 'assets/characters/canonical-hero', folder)
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            for filename in ('../outside.glb', '..\\outside.glb', '/outside.glb', 'C:\\outside.glb',
                             'C:outside.glb', 'nested/hero.glb', 'hero.obj', '', None, 1,
                             'hero.glb:stream', 'hero.glb ', 'hero\x00.glb', 'CON.glb', 'com1.glb'):
                with self.subTest(filename=filename):
                    manifest['sourceGlbFile'] = filename
                    path.write_text(json.dumps(manifest), encoding='utf-8')
                    with self.assertRaises(ValueError):
                        self.builder.build(source)

    def test_explicit_canonical_glb_missing_or_wrong_hash_never_uses_the_default(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(ROOT / 'assets/characters/canonical-hero', folder)
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            manifest['sourceGlbFile'] = 'review-missing-hero.glb'
            path.write_text(json.dumps(manifest), encoding='utf-8')
            with self.assertRaises(FileNotFoundError):
                self.builder.build(source)
            # The ordinary source still exists, but only the selected bytes count.
            (folder / manifest['sourceGlbFile']).write_bytes(b'wrong source GLB bytes')
            with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                self.builder.build(source)

    def test_canonical_surface_appearance_maps_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(ROOT / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(ROOT / 'assets/characters/canonical-hero', folder)
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            surface = {'name': 'SurfaceAppearance', 'colorMap': 'rbxassetid://101',
                       'normalMap': 'rbxassetid://102', 'roughnessMap': 'rbxassetid://103',
                       'metalnessMap': 'rbxassetid://104', 'color': [.8, .9, 1], 'alphaMode': 'Overlay'}
            manifest['parts'][0]['surfaceAppearances'] = [surface]
            path.write_text(json.dumps(manifest), encoding='utf-8')
            root = ET.fromstring(self.builder.build(source))
            template = named(named(named(root, 'ServerStorage'), 'BrickToadsCharacterTemplates'), 'CanonicalPlayer1')
            appearance = named(named(template, manifest['parts'][0]['name']), 'SurfaceAppearance')
            for key, prop in (('colorMap', 'ColorMap'), ('normalMap', 'NormalMap'),
                              ('roughnessMap', 'RoughnessMap'), ('metalnessMap', 'MetalnessMap')):
                self.assertEqual(appearance.findtext(f"Properties/Content[@name='{prop}']/url"), surface[key])
            for axis, value in zip('RGB', surface['color']):
                self.assertEqual(float(appearance.findtext(f"Properties/Color3[@name='Color']/{axis}")), value)

    def test_invalid_canonical_geometry_content_profile_or_provenance_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)
            shutil.copytree(ROOT/'src',source/'src')
            shutil.copytree(ROOT/'assets',source/'assets')
            path=source/'assets/characters/canonical-hero/roblox-player1.json'
            original=path.read_bytes();base=json.loads(original)
            def altered(name,change):
                row=copy.deepcopy(base);change(row)
                with self.subTest(case=name):
                    path.write_text(json.dumps(row),encoding='utf-8')
                    with self.assertRaises(ValueError):self.builder.build(source)
            altered('unknown-profile',lambda r:r.update(appearanceProfile='UnverifiedAvatar'))
            altered('wrong-template-name',lambda r:r.update(templateName='CanonicalPlayer2'))
            altered('wrong-scale',lambda r:r.update(appearanceScale=.8))
            altered('invalid-asset-id',lambda r:r.update(sourceAssetId='not-an-uploaded-id'))
            altered('invalid-glb-sha',lambda r:r.update(sourceGlbSha256='bad'))
            altered('mismatched-glb-sha',lambda r:r.update(sourceGlbSha256='0'*64))
            altered('missing-part',lambda r:r['parts'].pop())
            altered('duplicate-part',lambda r:r['parts'][-1].update(name=r['parts'][0]['name']))
            altered('missing-mesh-id',lambda r:r['parts'][0].update(meshId=''))
            altered('foreign-content-url',lambda r:r['parts'][0].update(meshId='https://example.invalid/mesh'))
            altered('negative-size',lambda r:r['parts'][0]['size'].__setitem__(0,-1))
            altered('missing-mesh-size',lambda r:r['parts'][0].pop('meshSize', None))
            for name, value in [('short', [1, 2]), ('null', None), ('zero', [1, 0, 1]),
                                ('negative', [-1, 1, 1]), ('nan', [1, float('nan'), 1]),
                                ('infinite', [1, 1, float('inf')]), ('boolean', [True, 1, 1])]:
                altered('mesh-size-' + name, lambda r, v=value: r['parts'][0].update(meshSize=v))
            altered('nan-position',lambda r:r['parts'][0]['cframe'].__setitem__(0,float('nan')))
            altered('invalid-rotation',lambda r:r['parts'][0]['cframe'].__setitem__(3,8))
            altered('color-out-of-range',lambda r:r['parts'][0]['color'].__setitem__(1,1.5))
            altered('missing-source-joint',lambda r:r['parts'][0]['attachments'].pop())
            altered('duplicate-source-joint',lambda r:r['parts'][0]['attachments'].append(copy.deepcopy(r['parts'][0]['attachments'][0])))
            path.write_bytes(original)

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
