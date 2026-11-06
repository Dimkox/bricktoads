# Lifecycle Core Implementation Plan

> For agentic workers: execute inline with test-first gates and verification-before-completion.

**Goal:** Deliver a tested first server lifecycle module without claiming the full Roblox level is implemented.
**Architecture:** Pure server-only snapshots and serialized versioned events. Spawn reservation/confirmation separates intent from successful appearance; the engine adapter remains a distinct unfinished task.
**Tech Stack:** Lua-compatible Luau; native Luau CLI when available, explicitly labeled Lua 5.4 fallback; Python 3 for reproducible test-place packaging.
**Spec:** `docs/superpowers/specs/2026-11-06-lifecycle-core.md`

## Global Constraints
- BT-10: 1–3 fixed heroes, 5 health, 3 respawns per entire playthrough; initial appearance free.
- Ordinary shield 2 seconds, emergency shield 10 seconds; successful appearances, not deaths, consume resources.
- No invented combat coefficients or copied reference assets.
- CLI tests, serialized place and Studio/gameplay verification are separate evidence classes.

## Review Focus
- Retried commands with altered payloads must not double-spend or silently heal.
- Stale spawn confirmations after disconnect, death or level transition must not create a new attempt.
- Emergency timeout at zero/offline must release protection without killing or respawning a living hero.
- A dead offline hero with a remaining respawn must prevent false group defeat.
- Two/three identical templates must still have separate owner state and resources.

## Task 1 — Verified NES baseline
- [x] Verify the supplied manifest before changing any source tree.
- [x] Rebuild the exact ROM in a temporary directory; record exit code and hash.
- [x] Rerun the common damage procedure in an isolated output directory; retain its intervention limits.

## Task 2 — Lifecycle core (BT-56/18, partial BT-11/13/17/19/58)
Files: `src/server/RunLifecycle.lua`, `tests/Lifecycle.spec.lua`, `tests/run.luau`, `tools/test_lua54.py`.
- [x] Write executable behavior tests for the spec and review-focus cases.
- [x] Observe an expected failing test with the implementation absent.
- [x] Implement `new` and `apply`; run the complete suite until green.
- [x] Add sequence/invariant and mutation-sensitivity checks; record actual results.

## Task 3 — Reproducibility and handoff (BT-57, partial)
Files: `tools/build_test_place.py`, `tools/test_build.py`, `.github/workflows/lifecycle.yml`, `reports/2026-11-06.md`.
- [x] Verify generated place structure and embedded-source hashes.
- [x] Record native runtime availability, test commands, exact versions and not-run engine scenarios.
- [x] Review boundaries and all changed files; rerun the suite.
- [x] Publish only new/changed source, tests and evidence to an isolated branch/PR, not main.
- [x] Add Jira evidence without closing whole implementation tasks.
