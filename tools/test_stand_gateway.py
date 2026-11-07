#!/usr/bin/env python3
"""Execute the actual Stand entry point in native Luau with service doubles.

The fixture tests connection-object authorization. It is NOT a live Roblox
transport test and does not authenticate or reconnect a real account.
"""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', required=True, type=Path)
    args = parser.parse_args()
    registry = ROOT/'src/stand/server/ConnectionRegistry.lua'
    prelude = '''local modules = {
Core=require("../src/server/RunLifecycle"), Combat=require("../src/stand/server/Combat"),
Config=require("../src/stand/server/Config"), Session=require("../src/stand/server/Session"),
FakeWorld=require("../tests/stand/FakeWorld"),
'''
    if registry.is_file():
        prelude += 'Registry=require("../src/stand/server/ConnectionRegistry"),\n'
    source = prelude + '}\nlocal function boot(game, Instance, require, workspace, script, print, warn)\n'
    source += (ROOT/'src/stand/server/Stand.server.lua').read_text(encoding='utf-8')
    source += '\nend\nlocal fixture=require("../tests/stand/StandGatewayFixture")\n'
    source += 'require("../tests/stand/StandGateway.spec")(function() return fixture(boot,modules) end)\n'
    target = ROOT/'build/stand-gateway-contracts.luau'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source, encoding='utf-8', newline='\n')
    return subprocess.run([str(args.luau.resolve()), str(target)], cwd=ROOT).returncode

if __name__ == '__main__':
    raise SystemExit(main())
