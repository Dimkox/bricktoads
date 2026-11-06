#!/usr/bin/env python3
"""Build the blank development place from src/ using only the Python standard library."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def build(root_path: Path) -> bytes:
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
    sources(item(server, "Folder", "BrickToads"), root_path / "src/server", server_only=True)
    replicated = item(root, "ReplicatedStorage", "ReplicatedStorage")
    sources(item(replicated, "Folder", "BrickToads"), root_path / "src/shared")
    starter = item(root, "StarterPlayer", "StarterPlayer")
    scripts = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    sources(item(scripts, "Folder", "BrickToads"), root_path / "src/client")
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "places/BrickToads.rbxlx")
    parser.add_argument("--check", action="store_true", help="Fail if the saved place differs from current sources")
    args = parser.parse_args()
    content = build(ROOT)
    if args.check:
        if not args.output.is_file() or args.output.read_bytes() != content:
            parser.exit(1, f"{args.output} is stale; run python tools/build_bricktoads_place.py\n")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(content)
    print(f"{args.output}: {len(content)} bytes; sha256={hashlib.sha256(content).hexdigest()}")


if __name__ == "__main__":
    main()
