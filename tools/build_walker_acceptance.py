#!/usr/bin/env python3
"""Build a Studio-only Walker-heavy fixture; never overwrite the playable place."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("bricktoads_playable", ROOT / "tools/build_bricktoads_place.py")
playable = importlib.util.module_from_spec(spec)
spec.loader.exec_module(playable)
RUNNER = "tests/gameplay/WalkerHeavyStudioAcceptance.server.luau"


def build(root_path: Path) -> bytes:
    runner = (root_path / RUNNER).read_text(encoding="utf-8")
    root = ET.fromstring(playable.build(root_path))
    for item in root.iter("Item"):
        if item.attrib["class"] in ("Script", "LocalScript"):
            ET.SubElement(item.find("Properties"), "bool", {"name": "Disabled"}).text = "true"
    server = next(item for item in root.findall("Item") if item.attrib["class"] == "ServerScriptService")

    def add(parent, class_name, name, properties=()):
        item = ET.SubElement(parent, "Item", {"class": class_name, "referent": "QA_" + name})
        props = ET.SubElement(item, "Properties")
        ET.SubElement(props, "string", {"name": "Name"}).text = name
        for kind, key, value in properties:
            ET.SubElement(props, kind, {"name": key}).text = value
        return item

    acceptance = add(server, "Folder", "WalkerAcceptance")
    sources = {path.relative_to(root_path).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in (root_path / "src").rglob("*") if path.is_file() and path.suffix in (".lua", ".luau")}
    sources[RUNNER] = hashlib.sha256((root_path / RUNNER).read_bytes()).hexdigest()
    manifest = {"schema": 1, "engine_status": "not_run", "source_sha256": sources,
                "source_pack_sha256": hashlib.sha256(
                    json.dumps(sources, sort_keys=True, separators=(",", ":")).encode()).hexdigest()}
    add(acceptance, "StringValue", "SourceManifest", [("string", "Value", json.dumps(manifest, sort_keys=True))])
    add(acceptance, "Script", "WalkerHeavyAcceptance", [
        ("bool", "Disabled", "false"), ("ProtectedString", "Source", runner)])
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def main() -> None:
    content = build(ROOT)
    output = ROOT / "build/WalkerHeavyAcceptance.rbxlx"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(content)
    print(f"{output}: {len(content)} bytes; sha256={hashlib.sha256(content).hexdigest()}; Studio NOT RUN")


if __name__ == "__main__":
    main()
