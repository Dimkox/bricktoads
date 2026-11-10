# Trusted infinite lives: domain and Session evidence

This change implements infinite **respawns** for development testing. It does not add invulnerability. It was made after the separate finite Native25 campaign had reached Won; these local tests do not establish any native Studio result.

`RunLifecycle` starts each hero with `infiniteLives=false`. The trusted server event `SetInfiniteLives` accepts only `{userId, enabled}` in addition to the standard event envelope. It cannot revive an eliminated hero or reopen a closed run. The ordinary client intent whitelist is unchanged.

`Session:setInfiniteLives(enabled)` requires a boolean and `config.Development.allowInfiniteLives == true`. It returns `INVALID_OPTION`, `DEVELOPMENT_ONLY`, or `RUN_CLOSED` on rejection, and `OK` after converging all eligible heroes to the requested mode. Calling it again with the same value changes neither revision nor actors. It can be called before the first ordinary Session step. It does not spawn, heal, kill, move or advance a level.

While enabled, normal death and emergency fallback can reserve and commit an appearance even when the finite reserve is zero, without decrementing that reserve. Actor uniqueness, attempts, deaths, health damage, reaction, delayed combat death, normal two-second shields, emergency ten-second deadlines and offline restrictions remain in effect. Disabling retains the unspent finite reserve. Disabling a zero-reserve dead hero settles it to elimination, including pending-spawn cancellation, so there is no unspawnable awaiting-respawn ghost. A living hero retains its current body and HP.

The Session snapshot exposes an explicit boolean on every `heroes[i].infiniteLives`, plus top-level `infiniteLives` which is true when any eligible hero is enabled. Core acknowledgements and Session journal rows also expose the flag alongside the unchanged finite `respawns` count.

Verification:

- [Initial RED](red-before-core.log): the first 21 contracts all failed against the unchanged Core/Session, because the field, trusted event and setter did not exist.
- [Malformed-gate RED](red-malformed-development.log): a non-table development config exposed an indexing failure; the setter now rejects it through the same explicit development-only gate.
- [Focused GREEN](green.log): 24 contracts pass using the real Core and Session with a synchronous World effect double. The suite includes seven ordinary Session deaths/respawns, more than four zero-reserve emergency retries, reserve preservation on disable, real raw-life underflow/delayed death, two/three-player elimination edges, disconnected eligibility, pending reservations, strict payloads, late closed-run toggles and the first ordinary appearance.
- [Finite lifecycle regression](lifecycle-regression.log): all 46 existing lifecycle cases pass, including the 120-sequence invariant exercise.
- [Stand regression](stand-regression.log): existing Combat arithmetic and 42 Session cases pass. `tests/run_stand.luau` also invokes the new focused suite.
- [Stand package checks](stand-package-approved-core.log): all seven source/serialization checks pass. The former unchanged-Core pin deliberately failed for this approved feature ([old pin RED](red-old-core-pin.log)); its named replacement pins Git blob `b22773c676dc13f114f6cfb7e1fad0aa23c5dacc` and cites the 24 new contracts plus 46 finite lifecycle cases. The separate exact packaged-source comparison remains unchanged.

Reproduce from the repository root:

```powershell
& .tools/luau-0.745/luau.exe tests/run_infinite_lives.luau
& .tools/luau-0.745/luau.exe tests/run.luau
& .tools/luau-0.745/luau.exe tests/run_stand.luau
& .tools/luau-0.745/luau-compile.exe --null src/server/RunLifecycle.lua src/stand/server/Session.lua tests/InfiniteLives.spec.lua tests/run_infinite_lives.luau tests/run_stand.luau
```

This report covers domain and server-coordinator behavior only. The World double checks effect ordering and resource accounting; it does not represent Roblox physics, actual multiplayer reconnects, HUD behavior, bootstrap gating or published experience permissions. Those integration surfaces are owned by the parent task.
