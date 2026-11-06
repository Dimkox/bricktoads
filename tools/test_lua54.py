#!/usr/bin/env python3
"""Execute the portable contract suite using the system Lua 5.4 shared library.

This is a fallback semantic check, NOT a Luau or Roblox Studio test.
"""
from __future__ import annotations
import ctypes
import ctypes.util
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def main() -> int:
    name = ctypes.util.find_library("lua5.4")
    if not name:
        print("Lua 5.4 shared library unavailable", file=sys.stderr)
        return 2
    lua = ctypes.CDLL(name)
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.luaL_loadstring.restype = ctypes.c_int
    lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
    lua.lua_pcallk.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    state = lua.luaL_newstate()
    if not state:
        raise MemoryError("Could not allocate Lua state")
    try:
        os.chdir(ROOT)
        lua.luaL_openlibs(state)
        code = b'print("RUNTIME: " .. _VERSION .. " (portable fallback; not Luau/Studio)"); local test = assert(loadfile("tests/Lifecycle.spec.lua"))(); local path = "src/server/RunLifecycle.lua"; local module = loadfile(path); test(module and module() or {})'
        status = lua.luaL_loadstring(state, code)
        if status == 0:
            status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if status:
            error = lua.lua_tolstring(state, -1, None)
            print(error.decode("utf-8", errors="replace") if error else "Lua execution failed", file=sys.stderr)
            return 1
        return 0
    finally:
        lua.lua_close(state)

if __name__ == "__main__":
    raise SystemExit(main())
