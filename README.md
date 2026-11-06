# Brick Toads — Studio starter and lifecycle core

Authority for the lifecycle core: Jira BT-10 decisions, read 2026-11-06. The development place is an empty baseplate with a spawn and source entry points. Gameplay, original levels, characters and combat integration are still outstanding. The separate contract-test place must not be published as the game.

## Open the project

Open `places/BrickToads.rbxlx` in Roblox Studio. Press Play to check the empty scene: Output should show `[BrickToads] server ready; lifecycle core loaded` and `[BrickToads] client ready`. Stop returns to Edit mode. The lifecycle module is loaded on the server but has no actor adapter or exposed remotes.

For the separate combat/respawn stand, run `python tools/build_combat_stand.py` and open `build/CombatStand.rbxlx`. Its source is under `src/stand/`; it keeps the blank starter place separate. Controls, experimental tuning and the acceptance matrix are documented in [the stand runbook](docs/stand/RUNBOOK.md). This stand is a technical test scene, not the completed first game level.

All project files live under the `bricktoads` repository folder:

```text
bricktoads/
  src/
    server/        # BrickToadsServer.server.luau and private RunLifecycle.lua
    client/        # BrickToadsClient.client.luau
    shared/        # BrickToadsConfig.luau, replicated project metadata
  places/          # BrickToads.rbxlx, the generated development place snapshot
  tests/           # Lifecycle behavior suite and CLI entry point
  tools/           # Python place builders and structural build tests
  docs/            # Design, implementation and Studio setup documentation
  reports/         # Recorded verification results
  research/        # Existing research and provenance evidence
  .github/         # CI workflow
  .tools/          # Local Python/Luau runtimes, ignored by Git
  build/           # Generated contract-test place and temporary results, ignored
```

## Rebuild the development place

Use Python 3.10+ and native Luau CLI 0.745. No Rojo, Wally or third-party Python packages are required. The configured Windows workspace keeps portable Python 3.13.9 and Luau 0.745 inside `.tools/`; these executables are local and are not committed.

```powershell
# Run from the bricktoads folder on this Windows workspace.
& .\.tools\python-3.13.9\python.exe tools/build_bricktoads_place.py
& .\.tools\python-3.13.9\python.exe tools/test_bricktoads_place.py
& .\.tools\python-3.13.9\python.exe tools/test_build.py
& .\.tools\luau-0.745\luau.exe tests/run.luau
```

On another machine with Python and Luau on PATH:

```sh
python3 tools/build_bricktoads_place.py
python3 tools/test_bricktoads_place.py
python3 tools/build_bricktoads_place.py --check
```

The builder maps `src/server` to `ServerScriptService.BrickToads`, `src/shared` to `ReplicatedStorage.BrickToads`, and `src/client` to `StarterPlayer.StarterPlayerScripts.BrickToads`. Subfolders remain folders; `.server.lua`/`.server.luau` become Scripts, `.client.lua`/`.client.luau` become LocalScripts, and other `.lua`/`.luau` files become ModuleScripts. Duplicate instance names fail the build. Server scripts outside `src/server` also fail the build, so a misplaced server entry point cannot be replicated to clients.

Edit code under `src/`, rebuild, then reopen the place in Studio to pick up changes. This is an explicit build workflow, not a live two-way sync. Rebuilding replaces the scene snapshot with the blank baseplate/spawn definition in `tools/build_bricktoads_place.py`; save future hand-authored levels separately before rebuilding. Commit the regenerated place with its source changes; CI uses `--check` to detect a stale snapshot. Contract tests are never included in the development place.

Official portable tool downloads: [Python 3.13.9 embeddable Windows x64](https://www.python.org/ftp/python/3.13.9/python-3.13.9-embed-amd64.zip) (SHA-256 `91d828c2da3a029b41699e918674a0cb379c02cf20dab9c501306885f837402a`) and [Luau 0.745 Windows](https://github.com/luau-lang/luau/releases/download/0.745/luau-windows.zip) (SHA-256 `5afe2fd5db34a045a2e4261ec0ea3144da6346ff38808726d5ac6e06115081c6`). Verify archives before extracting them into `.tools/python-3.13.9` and `.tools/luau-0.745` respectively.

## Included
- Fixed roster of 1–3 independently owned heroes, including identical templates.
- Five health units and three respawns per playthrough; first appearance free.
- Reservation/confirmation of successful appearances; aborts do not spend.
- Two-second normal protection and ten-second emergency protection/hold intent.
- Attack cancellation, safe relocation, expiry, offline/rejoin, current-level routing state, elimination and group defeat.
- Idempotent acknowledgement replay; run/revision/level/actor/attempt/connection guards.
- 46 behavioral tests including 120 deterministic lifecycle sequences. Local mutation testing detected all 8 deliberate faults.

`src/server/RunLifecycle.lua` uses a Lua-compatible Luau subset. It is server-only and must not be exposed directly as a RemoteEvent API. `SetHealth` is a trusted observation, not a rule that one attack removes one heart. Confirmed death is a separate event. Knockback and original combat profiles are not implemented here.

## Run tests
With native Luau CLI 0.745 on PATH:

```sh
luau tests/run.luau
python3 tools/test_build.py
python3 tools/build_test_place.py
```

Pinned Linux Luau archive SHA-256: `186e5ddaa2b048ebc7390c11ed1b00c04e7d3beaffed429250329e3575d2ece2`. The workflow `.github/workflows/lifecycle.yml` verifies this digest before execution. A configured workflow is not evidence of a successful run; inspect the actual check result.

Portable fallback on a system with the Lua 5.4 shared library:

```sh
python3 tools/test_lua54.py
```

The fallback executes the same production module and behavior suite, but **is not native Luau or Roblox Studio verification**.

## Studio handoff
The build command writes `build/LifecycleTests.rbxlx`. Open it in Roblox Studio and run the server. Its server script disables automatic character loading and invokes the embedded contract suite only in Studio. Record the Studio version, place hash, output and result. XML construction and structural tests alone do not prove Roblox can import or run it.

The place contains no original level, characters, enemies, cameras or mobile UI. A real server actor adapter, geometry/physics tests, 1/2/3-client sessions and phone/tablet playtests remain outstanding. Reservation/confirmation must be bound to actual successful actor appearance without yielding or exposing an actor before commit; rejected preparations must be destroyed.

## Evidence and next boundary
Read `docs/superpowers/specs/2026-11-06-lifecycle-core.md` for exact contracts and unresolved integration work. `reports/2026-11-06.md` distinguishes completed checks from not-run scenarios. Fresh NES verification is recorded separately from game implementation. Source ROMs, disassembly, graphics and sounds are not distributed here.
