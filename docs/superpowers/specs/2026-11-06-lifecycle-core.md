# BT-56 / BT-18: first lifecycle implementation slice

Authority: Jira BT-10, BT-11, BT-18, BT-56 and BT-57, read on 2026-11-06. This implements a bounded part of the accepted design, not the complete first level.

## Scope
A server-only, engine-independent state machine for a fixed roster of 1–3 heroes; successful initial/respawn appearances; individual health and remaining respawns; ordinary/emergency protection; disconnect/rejoin; safe level transition; elimination and spectator/menu choice. No client remotes, actor creation, physics, combat profiles, enemy handoff, boss queue or playable level are included.

Initial state gives each registered hero 5 health and 3 respawns. The first successful appearance is free; later successful appearances consume one. Alive with zero remains alive. A confirmed death at zero eliminates. A normal next-level transition heals surviving heroes once and retains resources. Health zero by itself is not a death event: source damage arithmetic distinguishes zero from underflow.

## Engineering boundary
`RunLifecycle.new(runId, groupId, roster, levelId)` and `RunLifecycle.apply(state, event)` are pure operations. `apply` returns the authoritative next snapshot, a result code and an acknowledgement. The caller keeps snapshots private on the server and serializes events. Unique event IDs plus exact payload fingerprints support reply replay; expected revision, run, level, actor, attempt and connection epochs reject stale events. Invalid events preserve the input state.

A spawn has a reservation and a confirmation. The future Roblox adapter must prepare an unexposed actor, revalidate/commit with no yield, expose the actor only after acceptance and destroy the prepared actor on rejection. An abort before confirmation consumes no resource. The core itself does not create an actor, so its passing tests do not prove successful Roblox appearances. A failed emergency replacement leaves the existing actor alive without an expired shield. The adapter must continue physics and retry only while eligibility still holds.

No initial-spawn protection was specified by the owner. This slice therefore grants no initial shield and refuses an unsafe initial spawn rather than inventing its behavior. Initial geometry remains an adapter responsibility. An ordinary respawn gives a 2-second shield; an unsafe respawn gives a 10-second emergency shield/hold intent. Valid own attack cancels either. Safe emergency relocation removes protection without healing or spending. Expiry grants a replacement opportunity only to an online owner with resources. Rejoin alone never grants one.

A verified safe level transition clears emergency hold as a safe relocation, preserves a normal shield's existing absolute deadline, invalidates old-level reservations and preserves the attempt. This is a documented engineering ordering choice; it must be reviewed in BT-56 and exercised in Studio. The module does not claim any safe-point search or physical hold.

## Integration obligations / non-goals
The adapter authenticates Player.UserId, validates attacks and exit conditions, supplies monotonic server time, checks safety/occupancy and handles networking without trusting client IDs. `SetHealth` is a trusted normalized-health observation, not an attack-to-heart conversion. Confirmed death comes from the authoritative combat/physics system. Knockback is deliberately absent.

One module per run isolates groups. Cross-run role ownership, routing, current UI ownership, server loss and native Roblox lifecycle remain outside this slice. The in-memory acknowledgement journal lasts for a run and is not yet capacity-benchmarked; do not expose it to arbitrary client event creation.

## Verification boundary
Tests exercise exact state transitions, not mocked Roblox success. A portable Lua-compatible Luau subset permits a fallback run with system Lua 5.4; that is explicitly not native Luau/Studio validation. A generated `.rbxlx` contains the same module and test suite for later Studio execution, not a game level. No source ROM, NES code, sprite or sound is included in the game repository.
