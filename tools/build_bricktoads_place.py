#!/usr/bin/env python3
"""Build the playable main project from src/ using the Python standard library."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
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
    # The explorer study is excluded from playable builds after the canonical-art decision.
    if include_character_study:
        # MeshId is read-only in gameplay. Persist the actual generated mesh/PBR
        # template in ServerStorage so runtime only clones existing MeshParts.
        manifest_bytes = (root_path / "assets/characters/green-toad.json").read_bytes()
        manifest = json.loads(manifest_bytes)
        expected = {"Head", "UpperTorso", "LowerTorso"} | {
            side + limb for side in ("Left", "Right")
            for limb in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")
        }
        rows = manifest["parts"]
        if manifest["schema"] != 1 or len(rows) != 15 or {r["name"] for r in rows} != expected:
            raise ValueError("GreenToad must contain the15 named source MeshParts")

        def compound(target, kind, name, values, fields):
            if len(values) != len(fields) or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in values):
                raise ValueError(f"Invalid character geometry: {name}")
            result = prop(target, kind, name, "")
            for field, value in zip(fields, values):
                ET.SubElement(result, field).text = str(value)

        def content(target, name, url):
            result = prop(target, "Content", name, "")
            if url:
                if not isinstance(url, str) or not url.startswith("rbxassetid://") or not url[13:].isdigit():
                    raise ValueError(f"Invalid generated character content: {name}")
                ET.SubElement(result, "url").text = url
            else:
                ET.SubElement(result, "null")

        def frame(target, values):
            compound(target, "CoordinateFrame", "CFrame", values,
                     ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"))

        storage = item(root, "ServerStorage", "ServerStorage")
        templates = item(storage, "Folder", "BrickToadsCharacterTemplates")
        template = item(templates, "Model", "GreenToad")
        scale = item(template, "NumberValue", "AppearanceScale")
        prop(scale, "double", "Value", manifest["fit"]["scale"])
        provenance = item(template, "StringValue", "AssetManifestSha256")
        prop(provenance, "string", "Value", hashlib.sha256(manifest_bytes).hexdigest())
        for row in sorted(rows, key=lambda r: r["name"]):
            mesh = item(template, "MeshPart", row["name"])
            content(mesh, "MeshId", row["meshId"])
            content(mesh, "TextureID", row["textureId"])
            compound(mesh, "Vector3", "size", row["size"], ("X", "Y", "Z"))
            frame(mesh, row["cframe"])
            color = [round(v * 255) for v in row["color"]]
            prop(mesh, "Color3uint8", "Color3uint8", 0xFF000000 | color[0] << 16 | color[1] << 8 | color[2])
            prop(mesh, "token", "Material", {"Plastic": 256}[row["material"]])
            prop(mesh, "token", "RenderFidelity", {"Automatic": 0, "Precise": 1, "Performance": 2}[row["renderFidelity"]])
            for flag, value in (("Anchored", True), ("CanCollide", False), ("CanTouch", False),
                                ("CanQuery", False), ("Massless", True), ("DoubleSided", row["doubleSided"])):
                prop(mesh, "bool", flag, str(value).lower())
            prop(mesh, "float", "Transparency", row["transparency"])
            prop(mesh, "float", "Reflectance", row["reflectance"])
            for attachment in row["attachments"]:
                frame(item(mesh, "Attachment", attachment["name"]), attachment["cframe"])
            for appearance in row["surfaceAppearances"]:
                surface = item(mesh, "SurfaceAppearance", appearance["name"])
                for key, name in (("colorMap", "ColorMap"), ("normalMap", "NormalMap"),
                                  ("roughnessMap", "RoughnessMap"), ("metalnessMap", "MetalnessMap")):
                    content(surface, name, appearance[key])
                compound(surface, "Color3", "Color", appearance["color"], ("R", "G", "B"))
                prop(surface, "token", "AlphaMode", {"Overlay": 0, "Transparency": 1}[appearance["alphaMode"]])
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
