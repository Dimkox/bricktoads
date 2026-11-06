#!/usr/bin/env python3
"""Serialize a server-only Roblox contract-test place from the exact source files.

The output is a test harness, not a playable level. XML checks do not replace
opening the place and running the suite in Roblox Studio.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = '''local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    warn("Brick Toads contract tests are restricted to Studio; this is not a game level.")
    return
end
game:GetService("Players").CharacterAutoLoads = false
local Core = require(script.Parent.RunLifecycle)
local run = require(script.Parent.LifecycleSpec)
local passed = run(Core)
print("Brick Toads lifecycle contract tests passed: " .. passed)
'''

def add_item(parent: ET.Element, class_name: str, name: str, referent: str, source: str | None = None) -> ET.Element:
    item = ET.SubElement(parent, "Item", {"class": class_name, "referent": referent})
    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", {"name": "Name"}).text = name
    if source is not None:
        ET.SubElement(properties, "ProtectedString", {"name": "Source"}).text = source
    return item

def build(root_path: Path) -> bytes:
    core = (root_path / "src/server/RunLifecycle.lua").read_text(encoding="utf-8")
    spec = (root_path / "tests/Lifecycle.spec.lua").read_text(encoding="utf-8")
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    service = add_item(root, "ServerScriptService", "ServerScriptService", "RBX1")
    add_item(service, "ModuleScript", "RunLifecycle", "RBX2", core)
    add_item(service, "ModuleScript", "LifecycleSpec", "RBX3", spec)
    add_item(service, "Script", "RunContractTests", "RBX4", BOOTSTRAP)
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT/"build/LifecycleTests.rbxlx")
    args = parser.parse_args()
    content = build(ROOT)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(content)
    print(f"{args.output}: {len(content)} bytes; sha256={hashlib.sha256(content).hexdigest()}")

if __name__ == "__main__":
    main()
