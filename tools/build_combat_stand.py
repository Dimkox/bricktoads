#!/usr/bin/env python3
"""Serialize the standalone combat stand; serialization is not an engine test."""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def build(root_path: Path) -> bytes:
    root = ET.Element("roblox", {"version": "4"})
    for value in ("null", "nil"):
        ET.SubElement(root, "External").text = value
    serial = 0

    def item(parent, kind, name):
        nonlocal serial
        serial += 1
        node = ET.SubElement(parent, "Item", {"class": kind, "referent": f"STAND{serial}"})
        properties = ET.SubElement(node, "Properties")
        ET.SubElement(properties, "string", {"name": "Name"}).text = name
        return node

    def prop(node, kind, name, text):
        ET.SubElement(node.find("Properties"), kind, {"name": name}).text = str(text)

    def source(parent, kind, name, path):
        node = item(parent, kind, name)
        prop(node, "ProtectedString", "Source", path.read_text(encoding="utf-8"))

    item(root, "Workspace", "Workspace")
    players = item(root, "Players", "Players")
    prop(players, "bool", "CharacterAutoLoads", "false")
    light = item(root, "Lighting", "Lighting")
    prop(light, "float", "ClockTime", 14)
    prop(light, "float", "Brightness", 2)
    item(root, "ReplicatedStorage", "ReplicatedStorage")
    server = item(root, "ServerScriptService", "ServerScriptService")
    folder = item(server, "Folder", "CombatStand")
    source(folder, "ModuleScript", "RunLifecycle", root_path / "src/server/RunLifecycle.lua")
    for path in sorted((root_path / "src/stand/server").glob("*.lua")):
        name = path.name.removesuffix(".lua")
        kind = "Script" if name.endswith(".server") else "ModuleScript"
        source(folder, kind, name.removesuffix(".server"), path)
    starter = item(root, "StarterPlayer", "StarterPlayer")
    scripts = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
    source(scripts, "LocalScript", "CombatStandClient", root_path / "src/stand/client/Stand.client.lua")
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/CombatStand.rbxlx")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = build(ROOT)
    if args.check:
        if not args.output.is_file() or args.output.read_bytes() != content:
            parser.exit(1, "Combat stand is stale or missing\n")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(content)
    print(f"{args.output}: {len(content)} bytes; sha256={hashlib.sha256(content).hexdigest()}")


if __name__ == "__main__":
    main()
