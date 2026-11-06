#!/usr/bin/env python3
"""Run stand contracts in system Lua 5.4; not a Luau or Roblox-engine run."""
from __future__ import annotations
import ctypes
import ctypes.util
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(code: str) -> int:
    name = ctypes.util.find_library("lua5.4")
    if not name:
        raise RuntimeError("Lua 5.4 shared library is required for the fallback")
    lua = ctypes.CDLL(name)
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.luaL_loadstring.restype = ctypes.c_int
    lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
    lua.lua_pcallk.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    state = lua.luaL_newstate()
    if not state:
        raise MemoryError("Lua state allocation failed")
    try:
        os.chdir(ROOT)
        lua.luaL_openlibs(state)
        status = lua.luaL_loadstring(state, code.encode())
        if not status:
            status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if status:
            print(lua.lua_tolstring(state, -1, None).decode(errors="replace"), file=sys.stderr)
        return 1 if status else 0
    finally:
        lua.lua_close(state)


if __name__ == "__main__":
    raise SystemExit(run('''
print("RUNTIME: Lua 5.4 fallback; NOT Roblox / NOT native Luau")
local function module(path) return assert(loadfile(path))() end
local Combat = module("src/stand/server/Combat.lua")
assert(loadfile("tests/stand/Combat.spec.lua"))()(Combat)
local sessionTest = assert(loadfile("tests/stand/Session.spec.lua"))
sessionTest()(module("src/server/RunLifecycle.lua"), Combat,
        module("src/stand/server/Session.lua"), module("src/stand/server/Config.lua"),
        module("tests/stand/FakeWorld.lua"))
'''))
