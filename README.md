# Brick Toads — lifecycle core, first implementation slice

Authority: Jira BT-10 decisions, read 2026-11-06. This branch is **not a playable Roblox level**. It adds server-domain logic and reproducible evidence to the previously README-only repository. Do not publish the test place as the game.

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
