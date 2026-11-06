# BrickToads Studio environment verification — 2026-11-06

## Scope

Created an empty local development place with a 256 × 256 anchored floor, one neutral spawn, and named server/client entry points. The private lifecycle module is loaded by the server; gameplay integration and cloud publication are outside this setup. Source, places, tests, documentation, build tools and local CLI runtimes are contained under the `bricktoads` repository directory.

## Local command checks

- Native Luau 0.745: `tests/run.luau` — 46 passed, 0 failed.
- Python 3.13.9: `tools/test_build.py` — 3 passed.
- Python 3.13.9: `tools/test_bricktoads_place.py` — 6 passed, including both public source scopes.
- `tools/build_bricktoads_place.py --check` — saved development place matches current sources.
- `tools/build_test_place.py` — separate contract harness generated under ignored `build/`.
- `git diff --check` — clean.

The new builder tests were run before its implementation and failed because the builder was absent. They passed after implementation. The existing contract-build test initially failed under Windows' default text encoding; explicitly reading both source files as UTF-8 corrected it, and the tests now pass without `-X utf8`.

An independent read-only review found that a misplaced `.server.luau` file in `src/shared` or `src/client` would expose its source. The regression test failed for both scopes before the fix; the builder now rejects server scripts outside `src/server`. This validation does not change the generated place snapshot.

## Actual Roblox Studio checks through MCP

Studio version: `0.746.0.7461269`. Opened the generated `places/BrickToads.rbxlx` as a local file, place ID `0`.

- Edit hierarchy: `ServerScriptService.BrickToads` contains `RunLifecycle` and `BrickToadsServer`; `ReplicatedStorage.BrickToads` contains `BrickToadsConfig`; `StarterPlayer.StarterPlayerScripts.BrickToads` contains `BrickToadsClient`.
- Verified exact floor size `256, 1, 256`, spawn position `0, 0.5, 0`, anchoring and collision in the imported DataModel.
- Verified the lifecycle module is absent from replicated/shared containers.
- Play output contained only the expected startup messages:

```text
[BrickToads] server ready; lifecycle core loaded
[BrickToads] client ready
```

- Client smoke check: local player spawned, Humanoid health `100`, root position approximately `0, 4.0963, 0`; client entry point present in PlayerScripts.
- Server smoke check: lifecycle exports `new` and `apply` loaded, one connected player, server core remains private.
- Stopped the play session and returned the development place to Edit mode.

These are import/startup/spawn checks. The 46-case behavior suite ran in native Luau CLI; it was not run inside Studio during this setup. Multiplayer sessions, mobile layouts, a real actor adapter and playable game logic remain future work.
