#!/usr/bin/env python3
"""Build the playable main project from src/ using the Python standard library."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def build(root_path: Path, *, include_character_study: bool = False) -> bytes:
    # Fail rather than silently dropping the existing private lifecycle module.
    (root_path / "src/server/RunLifecycle.lua").read_text(encoding="utf-8")
    root = ET.Element("roblox", {"version": "4"})
    for value in ("null", "nil"):
        ET.SubElement(root, "External").text = value
    next_id = 0

    def item(parent, class_name, name):
        nonlocal next_id
        next_id += 1
        result = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"BT{next_id}"})
        properties = ET.SubElement(result, "Properties")
        ET.SubElement(properties, "string", {"name": "Name"}).text = name
        return result

    def prop(target, kind, name, value):
        element = ET.SubElement(target.find("Properties"), kind, {"name": name})
        element.text = str(value)
        return element

    def part(parent, class_name, name, size, y):
        result = item(parent, class_name, name)
        prop(result, "bool", "Anchored", "true")
        prop(result, "bool", "CanCollide", "true")
        vector = prop(result, "Vector3", "size", "")
        for axis, value in zip("XYZ", size):
            ET.SubElement(vector, axis).text = str(value)
        frame = prop(result, "CoordinateFrame", "CFrame", "")
        for axis, value in zip("XYZ", (0, y, 0)):
            ET.SubElement(frame, axis).text = str(value)
        for row in range(3):
            for col in range(3):
                ET.SubElement(frame, f"R{row}{col}").text = "1" if row == col else "0"
        return result

    def sources(parent, directory, *, server_only=False):
        if not directory.is_dir():
            raise FileNotFoundError(directory)
        names = set()
        for path in sorted(directory.iterdir(), key=lambda p: p.name):
            if path.is_dir():
                name, class_name = path.name, "Folder"
            elif path.suffix in (".lua", ".luau"):
                name, class_name = path.stem, "ModuleScript"
                for suffix, script_class in ((".server", "Script"), (".client", "LocalScript")):
                    if name.endswith(suffix):
                        name, class_name = name[:-len(suffix)], script_class
                        break
            else:
                continue
            if class_name == "Script" and not server_only:
                raise ValueError(f"Server script {path} must be inside src/server")
            if name in names:
                raise ValueError(f"Duplicate Studio name {name!r} in {directory}")
            names.add(name)
            child = item(parent, class_name, name)
            if path.is_dir():
                sources(child, path, server_only=server_only)
            else:
                prop(child, "ProtectedString", "Source", path.read_text(encoding="utf-8"))

    workspace = item(root, "Workspace", "Workspace")
    part(workspace, "Part", "Baseplate", (256, 1, 256), -0.5)
    spawn = part(workspace, "SpawnLocation", "SpawnLocation", (6, 1, 6), 0.5)
    prop(spawn, "bool", "Neutral", "true")
    prop(spawn, "float", "Duration", 0)
    lighting = item(root, "Lighting", "Lighting")
    prop(lighting, "float", "ClockTime", 14)
    prop(lighting, "float", "Brightness", 2)
    server = item(root, "ServerScriptService", "ServerScriptService")
    project = item(server, "Folder", "BrickToads")
    sources(project, root_path / "src/server", server_only=True)
    # Share implementations with the independent stand; exclude its entrypoint,
    # diagnostics and all acceptance helpers from the actual game.
    runtime = item(project, "Folder", "CombatRuntime")
    for name in ("Combat", "Session", "Config", "ConnectionRegistry", "RobloxWorld"):
        child = item(runtime, "ModuleScript", name)
        prop(child, "ProtectedString", "Source",
             (root_path / "src/stand/server" / (name + ".lua")).read_text(encoding="utf-8"))
    replicated = item(root, "ReplicatedStorage", "ReplicatedStorage")
    sources(item(replicated, "Folder", "BrickToads"), root_path / "src/shared")
    starter_gui = item(root, "StarterGui", "StarterGui")
    prop(starter_gui, "token", "ScreenOrientation", 4)  # Enum.ScreenOrientation.Sensor
    starter = item(root, "StarterPlayer", "StarterPlayer")
    scripts = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    sources(item(scripts, "Folder", "BrickToads"), root_path / "src/client")
    # Fingerprint the embedded script paths and text, excluding this derived receipt.
    source_pack = []
    def collect(parent, prefix):
        for child in parent.findall("Item"):
            name = child.findtext("Properties/string[@name='Name']")
            path = prefix + "/" + name
            source = child.findtext("Properties/ProtectedString[@name='Source']")
            if source is not None:
                source_pack.append({"path": path, "class": child.attrib["class"], "source": source})
            collect(child, path)
    collect(root, "")
    fingerprint = hashlib.sha256(json.dumps(source_pack, sort_keys=True, separators=(",", ":"),
                                             ensure_ascii=False).encode("utf-8")).hexdigest()
    receipt = item(project, "ModuleScript", "BuildInfo")
    prop(receipt, "ProtectedString", "Source", f"return table.freeze({{format=1,sourceSha256='{fingerprint}'}})\n")
    # MeshId is read-only during gameplay. Package the actual uploaded resources;
    # both canonical players are mandatory in every default playable build.
    expected = {"Head", "UpperTorso", "LowerTorso"} | {
        side + limb for side in ("Left", "Right")
        for limb in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")
    }
    connections = [("Waist", "LowerTorso", "UpperTorso"), ("Neck", "UpperTorso", "Head")]
    for side in ("Left", "Right"):
        connections.extend([(side + "Shoulder", "UpperTorso", side + "UpperArm"),
                            (side + "Elbow", side + "UpperArm", side + "LowerArm"),
                            (side + "Wrist", side + "LowerArm", side + "Hand"),
                            (side + "Hip", "LowerTorso", side + "UpperLeg"),
                            (side + "Knee", side + "UpperLeg", side + "LowerLeg"),
                            (side + "Ankle", side + "LowerLeg", side + "Foot")])

    def number(value, name, minimum=None, maximum=None):
        if type(value) not in (int, float) or not math.isfinite(value) \
                or (minimum is not None and value < minimum) or (maximum is not None and value > maximum):
            raise ValueError(f"Invalid character value: {name}")
        return value

    def numbers(values, length, name, minimum=None, maximum=None):
        if not isinstance(values, list) or len(values) != length:
            raise ValueError(f"Invalid character geometry: {name}")
        for value in values:
            number(value, name, minimum, maximum)
        return values

    def compound(target, kind, name, values, fields):
        numbers(values, len(fields), name)
        result = prop(target, kind, name, "")
        for field, value in zip(fields, values):
            ET.SubElement(result, field).text = str(value)

    def content(target, name, url, *, allow_empty=True):
        if not isinstance(url, str) or (not url and not allow_empty) or (url and (
                not url.startswith("rbxassetid://") or not url[13:].isdigit() or int(url[13:]) <= 0)):
            raise ValueError(f"Invalid character content: {name}")
        result = prop(target, "Content", name, "")
        if url:
            ET.SubElement(result, "url").text = url
        else:
            ET.SubElement(result, "null")

    def frame(target, values):
        numbers(values, 12, "CFrame")
        rotation = [values[3:6], values[6:9], values[9:12]]
        for i in range(3):
            for j in range(3):
                dot = sum(a * b for a, b in zip(rotation[i], rotation[j]))
                if abs(dot - (1 if i == j else 0)) > .001:
                    raise ValueError("Invalid character CFrame rotation")
        a, b, c = rotation
        determinant = a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])
        if abs(determinant - 1) > .001:
            raise ValueError("Invalid character CFrame orientation")
        compound(target, "CoordinateFrame", "CFrame", values,
                 ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"))

    def enum_value(mapping, value, name):
        if value not in mapping:
            raise ValueError(f"Unsupported character enum: {name}")
        return mapping[value]

    storage = item(root, "ServerStorage", "ServerStorage")
    templates = item(storage, "Folder", "BrickToadsCharacterTemplates")

    def mesh_resource(parent, row, *, require_mesh_size=True):
        mesh = item(parent, "MeshPart", row["name"])
        content(mesh, "MeshId", row["meshId"], allow_empty=False)
        content(mesh, "TextureID", row["textureId"])
        if any(v <= 0 for v in numbers(row["size"], 3, "size")):
            raise ValueError("Character mesh size must be positive")
        compound(mesh, "Vector3", "size", row["size"], ("X", "Y", "Z"))
        # MeshSize is read-only in scripts. The place format persists its
        # source geometry extent as InitialSize, separately from scaled size.
        mesh_size = row.get("meshSize") if require_mesh_size else row.get("meshSize", row["size"])
        if any(v <= 0 for v in numbers(mesh_size, 3, "meshSize")):
            raise ValueError("Character source mesh size must be positive")
        compound(mesh, "Vector3", "InitialSize", mesh_size, ("X", "Y", "Z"))
        frame(mesh, row["cframe"])
        numbers(row["color"], 3, "Color", 0, 1)
        # Preserve actual exported mesh tint. Player palettes are in separate
        # uploaded mesh content, never fabricated through a P2 Color override.
        color = [round(v * 255) for v in row["color"]]
        prop(mesh, "Color3uint8", "Color3uint8", 0xFF000000 | color[0] << 16 | color[1] << 8 | color[2])
        prop(mesh, "token", "Material", enum_value({"Plastic": 256, "Metal": 1088}, row["material"], "Material"))
        prop(mesh, "token", "RenderFidelity", enum_value({"Automatic": 0, "Precise": 1, "Performance": 2}, row["renderFidelity"], "RenderFidelity"))
        if type(row["doubleSided"]) is not bool:
            raise ValueError("Invalid character DoubleSided flag")
        for flag, value in (("Anchored", True), ("CanCollide", False), ("CanTouch", False),
                            ("CanQuery", False), ("Massless", True), ("DoubleSided", row["doubleSided"])):
            prop(mesh, "bool", flag, str(value).lower())
        prop(mesh, "float", "Transparency", number(row["transparency"], "Transparency", 0, 1))
        prop(mesh, "float", "Reflectance", number(row["reflectance"], "Reflectance", 0, 1))
        for attachment in row["attachments"]:
            frame(item(mesh, "Attachment", attachment["name"]), attachment["cframe"])
        for appearance in row["surfaceAppearances"]:
            surface = item(mesh, "SurfaceAppearance", appearance["name"])
            for key, name in (("colorMap", "ColorMap"), ("normalMap", "NormalMap"),
                              ("roughnessMap", "RoughnessMap"), ("metalnessMap", "MetalnessMap")):
                content(surface, name, appearance[key])
            numbers(appearance["color"], 3, "SurfaceColor", 0, 1)
            compound(surface, "Color3", "Color", appearance["color"], ("R", "G", "B"))
            prop(surface, "token", "AlphaMode", enum_value({"Overlay": 0, "Transparency": 1}, appearance["alphaMode"], "AlphaMode"))
        return mesh


    def character(manifest_bytes, template_name, *, canonical=False):
        manifest = json.loads(manifest_bytes)
        rows = manifest.get("parts")
        if type(manifest.get("schema")) is not int or manifest["schema"] != 1 or not isinstance(rows, list) \
                or len(rows) != 15 or any(not isinstance(r, dict) for r in rows) or {r.get("name") for r in rows} != expected:
            raise ValueError(f"{template_name} must contain the15 named source MeshParts")
        metadata = {"AssetManifestSha256": hashlib.sha256(manifest_bytes).hexdigest()}
        if canonical:
            if manifest.get("appearanceProfile") != "CanonicalNESHero" or manifest.get("templateName") != template_name:
                raise ValueError("Invalid canonical appearance profile or template name")
            scale_value = number(manifest.get("appearanceScale"), "AppearanceScale", 1, 1)
            asset_id, source_sha = manifest.get("sourceAssetId"), manifest.get("sourceGlbSha256")
            if not isinstance(asset_id, str) or not asset_id.isdigit() or int(asset_id) <= 0:
                raise ValueError("Invalid canonical SourceAssetId")
            if not isinstance(source_sha, str) or len(source_sha) != 64 or any(c not in "0123456789abcdef" for c in source_sha):
                raise ValueError("Invalid canonical SourceGlbSha256")
            player = template_name[-1]
            source_file = manifest.get("sourceGlbFile", f"canonical-hero-player{player}.glb")
            if not isinstance(source_file, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*\.glb", source_file) \
                    or re.match(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\.", source_file):
                raise ValueError("Invalid canonical sourceGlbFile: expected a safe .glb basename")
            asset_folder = root_path / "assets/characters/canonical-hero"
            glb = asset_folder / source_file
            if glb.resolve().parent != asset_folder.resolve():
                raise ValueError("Canonical source GLB must remain inside its asset folder")
            if hashlib.sha256(glb.read_bytes()).hexdigest() != source_sha:
                raise ValueError("Canonical source GLB SHA256 mismatch")
            metadata.update(AppearanceProfile="CanonicalNESHero", SourceAssetId=asset_id, SourceGlbSha256=source_sha)
        else:
            scale_value = number(manifest["fit"]["scale"], "AppearanceScale", 0, 2)
            if scale_value == 0:
                raise ValueError("Invalid character fit scale")
            metadata["AppearanceProfile"] = "LegacyGeneratedGreen"
        parts = {r["name"]: r for r in rows}
        attachment_count = 0
        for row in rows:
            attachments = row.get("attachments")
            if not isinstance(attachments, list) or any(not isinstance(a, dict) or not isinstance(a.get("name"), str) for a in attachments) \
                    or len({a["name"] for a in attachments}) != len(attachments):
                raise ValueError("Invalid or duplicate character attachment")
            attachment_count += len(attachments)
        if canonical:
            for joint, first, second in connections:
                for name in (first, second):
                    if joint + "RigAttachment" not in {a["name"] for a in parts[name]["attachments"]}:
                        raise ValueError(f"Missing canonical source joint: {name}/{joint}")
            if attachment_count != 28:
                raise ValueError("Canonical resources require28 RigAttachments")
        template = item(templates, "Model", template_name)
        scale = item(template, "NumberValue", "AppearanceScale")
        prop(scale, "double", "Value", scale_value)
        for name, value in metadata.items():
            prop(item(template, "StringValue", name), "string", "Value", value)
        for row in sorted(rows, key=lambda r: r["name"]):
            mesh_resource(template, row, require_mesh_size=canonical)

    for player in (1, 2):
        manifest = (root_path / f"assets/characters/canonical-hero/roblox-player{player}.json").read_bytes()
        character(manifest, f"CanonicalPlayer{player}", canonical=True)
    character((root_path/'assets/characters/canonical-hero/roblox-brown.json').read_bytes(),
              'CanonicalPlayerBrown',canonical=True)

    morph_folder = item(storage, 'Folder', 'BrickToadsCharacterMorphs')

    def morph_family(family, kinds, *, palettes=(('Green', 'Mr. Green'), ('PlayerTwo', 'Mr. Yellow'))):
        morph_bytes = (root_path / f'assets/characters/canonical-hero/roblox-{family}-morphs.json').read_bytes()
        morphs = json.loads(morph_bytes)
        expected_morphs = {prefix + kind: (hero, kind)
                           for prefix, hero in palettes
                           for kind in kinds}
        records = morphs.get('templates')
        if type(morphs.get('schema')) is not int or morphs['schema'] != 1 \
                or morphs.get('appearanceProfile') != 'CanonicalNESHeroMorph' \
                or not isinstance(records, list) or len(records) != 4 \
                or any(not isinstance(row, dict) for row in records) \
                or {row.get('name') for row in records} != set(expected_morphs):
            raise ValueError(f'Expected four tagged canonical {family} morph resources')
        asset_id, source_sha = morphs.get('sourceAssetId'), morphs.get('sourceGlbSha256')
        if not isinstance(asset_id, str) or not asset_id.isdigit() or int(asset_id) <= 0 \
                or not isinstance(source_sha, str) or not re.fullmatch('[0-9a-f]{64}', source_sha):
            raise ValueError('Invalid morph source provenance')
        filename = morphs.get('sourceGlbFile')
        if not isinstance(filename, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*\.glb', filename) \
                or re.match(r'(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\.', filename):
            raise ValueError('Invalid morph source GLB basename')
        asset_folder = root_path / 'assets/characters/canonical-hero'
        source_file = asset_folder / filename
        if source_file.resolve().parent != asset_folder.resolve() \
                or hashlib.sha256(source_file.read_bytes()).hexdigest() != source_sha:
            raise ValueError('Morph source GLB SHA256 mismatch or path escape')
        for row in sorted(records, key=lambda r: r['name']):
            hero, kind = expected_morphs[row['name']]
            if row.get('heroTemplate') != hero or row.get('morphKind') != kind:
                raise ValueError('Morph palette or kind does not match its resource name')
            number(row.get('appearanceScale'), 'Morph AppearanceScale', 1, 1)
            mesh_row = row.get('part')
            if not isinstance(mesh_row, dict) or mesh_row.get('name') != 'Morph':
                raise ValueError('Morph requires exactly one named MeshPart')
            if number(mesh_row.get('transparency'), 'Morph Transparency', 0, 1) >= 1:
                raise ValueError('Morph source mesh must be visible')
            attachments = mesh_row.get('attachments')
            if not isinstance(attachments, list) or len(attachments) != 1 \
                    or not isinstance(attachments[0], dict) \
                    or attachments[0].get('name') != 'MorphOriginRigAttachment':
                raise ValueError('Morph requires exactly one origin attachment')
            a = numbers(mesh_row.get('cframe'), 12, 'Morph rest frame')
            b = numbers(attachments[0].get('cframe'), 12, 'Morph origin frame')
            for i in range(3):
                if abs(a[i] + sum(a[3 + i*3 + j] * b[j] for j in range(3))) > .0001:
                    raise ValueError('Morph origin must resolve to its joint origin')
                for j in range(3):
                    if abs(sum(a[3 + i*3 + k] * b[3 + k*3 + j] for k in range(3)) - (i == j)) > .0001:
                        raise ValueError('Morph origin must use authored joint axes')
            model = item(morph_folder, 'Model', row['name'])
            prop(item(model, 'NumberValue', 'AppearanceScale'), 'double', 'Value', 1)
            for name, value in dict(AppearanceProfile='CanonicalNESHeroMorph', HeroTemplate=hero,
                                    MorphKind=kind, SourceAssetId=asset_id, SourceGlbSha256=source_sha,
                                    AssetManifestSha256=hashlib.sha256(morph_bytes).hexdigest()).items():
                prop(item(model, 'StringValue', name), 'string', 'Value', value)
            mesh_resource(model, mesh_row)

    morph_family('attack', ('PowerFist', 'BigBoot'))
    morph_family('fear', ('FearBeforeCut', 'FearAfterCut'))
    morph_family('brown', ('PowerFist', 'BigBoot', 'FearBeforeCut', 'FearAfterCut'),
                 palettes=(('Brown', 'Mr. Brown'),))

    # Boss art is mandatory private content, including its separately mounted
    # intro leg. Never replace an absent import receipt with a generated proxy.
    boss_bytes = (root_path / 'assets/characters/canonical-hero/boss-walker-roblox.json').read_bytes()
    boss_assets = json.loads(boss_bytes)
    boss_models = {
        'BossWalkerGuardian': ('CanonicalBossWalker',
                               {'GuardianChassis', 'GuardianLeftCannon', 'GuardianRightCannon'}),
        'BossWalkerIntroLeg': ('CanonicalBossWalkerIntroLeg', {'IntroLeg12'}),
    }
    records = boss_assets.get('templates') if isinstance(boss_assets, dict) else None
    if not isinstance(boss_assets, dict) or type(boss_assets.get('schema')) is not int \
            or boss_assets['schema'] != 1 or boss_assets.get('appearanceProfile') != 'CanonicalBossWalkerAssets' \
            or not isinstance(records, list) or len(records) != 2 \
            or any(not isinstance(row, dict) or not isinstance(row.get('name'), str) for row in records) \
            or {row['name'] for row in records} != set(boss_models):
        raise ValueError('Expected exactly two tagged Boss Walker template resources')
    asset_id, source_sha = boss_assets.get('sourceAssetId'), boss_assets.get('sourceGlbSha256')
    if not isinstance(asset_id, str) or not asset_id.isdigit() or int(asset_id) <= 0 \
            or not isinstance(source_sha, str) or not re.fullmatch('[0-9a-f]{64}', source_sha):
        raise ValueError('Invalid Boss Walker source provenance')
    if boss_assets.get('sourceGlbFile') != 'boss-walker.glb':
        raise ValueError('Boss Walker source GLB must be the boss-walker.glb basename')
    asset_folder = root_path / 'assets/characters/canonical-hero'
    source_file = asset_folder / 'boss-walker.glb'
    if source_file.resolve().parent != asset_folder.resolve():
        raise ValueError('Boss Walker source GLB must remain inside its asset folder')
    if hashlib.sha256(source_file.read_bytes()).hexdigest() != source_sha:
        raise ValueError('Boss Walker source GLB SHA256 mismatch')

    def composed_frame(first, second):
        a = numbers(first, 12, 'Boss Walker rest frame')
        b = numbers(second, 12, 'Boss Walker attachment frame')
        position = [a[i] + sum(a[3+i*3+j] * b[j] for j in range(3)) for i in range(3)]
        rotation = [sum(a[3+i*3+k] * b[3+k*3+j] for k in range(3))
                    for i in range(3) for j in range(3)]
        return position, rotation

    boss_folder = item(storage, 'Folder', 'BrickToadsBossTemplates')
    mesh_fields = {'name', 'meshId', 'textureId', 'size', 'meshSize', 'cframe', 'color', 'material',
                   'renderFidelity', 'doubleSided', 'transparency', 'reflectance', 'attachments', 'surfaceAppearances'}
    surface_fields = {'name', 'colorMap', 'normalMap', 'roughnessMap', 'metalnessMap', 'color', 'alphaMode'}
    for record in sorted(records, key=lambda row: row['name']):
        profile, part_names = boss_models[record['name']]
        rows = record.get('parts')
        if set(record) != {'name', 'appearanceProfile', 'appearanceScale', 'parts'} \
                or record.get('appearanceProfile') != profile \
                or not isinstance(rows, list) or len(rows) != len(part_names) \
                or any(not isinstance(row, dict) or not isinstance(row.get('name'), str) for row in rows) \
                or {row['name'] for row in rows} != part_names:
            raise ValueError('Boss Walker template profile or exact named MeshParts do not match')
        number(record.get('appearanceScale'), 'Boss Walker AppearanceScale', 1, 1)
        model = item(boss_folder, 'Model', record['name'])
        prop(item(model, 'NumberValue', 'AppearanceScale'), 'double', 'Value', 1)
        for name, value in dict(AppearanceProfile=profile, SourceAssetId=asset_id, SourceGlbSha256=source_sha,
                                AssetManifestSha256=hashlib.sha256(boss_bytes).hexdigest()).items():
            prop(item(model, 'StringValue', name), 'string', 'Value', value)
        for row in sorted(rows, key=lambda part: part['name']):
            if set(row) != mesh_fields:
                raise ValueError('Boss Walker MeshParts may contain only mesh resource fields')
            if number(row['transparency'], 'Boss Walker Transparency', 0, 1) >= 1:
                raise ValueError('Boss Walker source mesh must be visible')
            intro = row['name'] == 'IntroLeg12'
            cannon = row['name'] in {'GuardianLeftCannon', 'GuardianRightCannon'}
            origin_name = 'IntroOriginRigAttachment' if intro else 'GuardianMountRigAttachment'
            attachment_names = {origin_name} | ({'MuzzleRigAttachment'} if cannon else set())
            attachments = row['attachments']
            if not isinstance(attachments, list) or len(attachments) != len(attachment_names) \
                    or any(not isinstance(a, dict) or set(a) != {'name', 'cframe'}
                           or not isinstance(a.get('name'), str) for a in attachments) \
                    or {a['name'] for a in attachments} != attachment_names:
                raise ValueError('Boss Walker requires exactly its named mount and muzzle attachments')
            origins = {a['name']: a['cframe'] for a in attachments}
            mount, rotation = composed_frame(row['cframe'], origins[origin_name])
            if any(abs(value - (i in (0, 4, 8))) >= .0001 for i, value in enumerate(rotation)):
                raise ValueError('Boss Walker mount must use authored root axes')
            if (intro or row['name'] == 'GuardianChassis') and any(abs(value) >= .0001 for value in mount):
                raise ValueError('Boss Walker chassis or intro origin must resolve to the root origin')
            if cannon:
                if (row['name'] == 'GuardianLeftCannon' and mount[0] >= -.0001) \
                        or (row['name'] == 'GuardianRightCannon' and mount[0] <= .0001):
                    raise ValueError('Boss Walker cannon mount must remain on its named side')
                muzzle, muzzle_rotation = composed_frame(row['cframe'], origins['MuzzleRigAttachment'])
                if any(abs(value - (i in (0, 4, 8))) >= .0001 for i, value in enumerate(muzzle_rotation)):
                    raise ValueError('Boss Walker muzzle must use authored root axes')
                if muzzle[2] >= mount[2] - .0001:
                    raise ValueError('Boss Walker cannon muzzle must be forward of its mount along -Z')
            appearances = row['surfaceAppearances']
            if not isinstance(appearances, list) or len(appearances) > 1 \
                    or any(not isinstance(a, dict) or set(a) != surface_fields
                           or a.get('name') != 'SurfaceAppearance' for a in appearances):
                raise ValueError('Boss Walker may contain only one named SurfaceAppearance')
            mesh_resource(model, row)

    # All gameplay cast imports are mandatory, private, validated resources.
    cast_spec = importlib.util.spec_from_file_location("package_canonical_cast", Path(__file__).with_name("package_canonical_cast.py"))
    cast_packager = importlib.util.module_from_spec(cast_spec)
    cast_spec.loader.exec_module(cast_packager)
    cast_packager.package_cast(root_path, storage, item=item, prop=prop, mesh_resource=mesh_resource)

    # Course vehicles are mandatory uploaded art, separate from physical colliders.
    course_spec = importlib.util.spec_from_file_location("package_course_assets", Path(__file__).with_name("package_course_assets.py"))
    course_packager = importlib.util.module_from_spec(course_spec)
    course_spec.loader.exec_module(course_packager)
    course_packager.package_course_assets(root_path, storage, item=item, prop=prop, mesh_resource=mesh_resource)

    # Explicit research switch; this rejected study is absent from default builds.
    if include_character_study:
        character((root_path / "assets/characters/green-toad.json").read_bytes(), "GreenToad")
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "places/BrickToadsPlayable.rbxlx")
    parser.add_argument("--check", action="store_true", help="Fail if the saved place differs from current sources")
    parser.add_argument("--include-character-study", action="store_true", help="Include the rejected explorer study for isolated art pipeline research only")
    args = parser.parse_args()
    content = build(ROOT, include_character_study=args.include_character_study)
    if args.check:
        if not args.output.is_file() or args.output.read_bytes() != content:
            parser.exit(1, f"{args.output} is stale; run python tools/build_bricktoads_place.py\n")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(content)
    print(f"{args.output}: {len(content)} bytes; sha256={hashlib.sha256(content).hexdigest()}")


if __name__ == "__main__":
    main()
