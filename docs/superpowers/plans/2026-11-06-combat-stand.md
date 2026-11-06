# Combat stand implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a separate reproducible Roblox combat/lifecycle stand without claiming engine acceptance from pure tests.

**Architecture:** Preserve RunLifecycle. Add a pure raw-Life combat model, a pure session coordinator and a synchronous Roblox-world port. Strict server-owned intents and independent physical models retain offline bodies.

**Tech Stack:** Lua/Luau, Roblox engine APIs, Python standard-library XML builder, pinned Luau CI.

**Spec:** docs/superpowers/specs/2026-11-06-combat-stand.md

## Global constraints

1–3 fixed heroes; five displayed hearts; three respawns per game; 2/10-second shields. No ROM/ASM/assets. No edits to existing lifecycle or development place. Experimental 3D tuning is not source-game evidence. No fake Studio PASS.

## Review focus

Malformed/NaN/forged intent must not mutate state. A spawn failure must not consume a reserve. Old actor or connection commands must not affect replacement bodies. Emergency timeout and safe relocation must choose one outcome. A disconnected body and already-started attack must persist without permitting new owner commands.

### Task 1: Combat state

Files: src/stand/server/Combat.lua, Config.lua; tests/stand/Combat.spec.lua.
Interface: damage(raw, damage)->raw,dying; hit(raw,action,shield)->result; recover(raw)->raw; hearts(raw)->number.
- [x] Write assertions for 47→43→47, 47→31, 16→15, 15→0, exact zero without death, shielding, bad inputs and all 48 inputs per profile.
- [x] Run tests against absent module; observe assertion failure.
- [x] Implement the numeric model and explicitly provisional timing configuration.
- [x] Run Lua fallback, record result, commit.

### Task 2: Session coordinator

Files: src/stand/server/Session.lua; tests/stand/Session.spec.lua, FakeWorld.lua.
Interface: new(Core,Combat,Config,roster,runId,world,logger); step(now); intent(uid,payload,now); connection(uid,bool,now); snapshot().
- [x] Write failing integration contracts for fixed composition, attacks in all directed pairs, delayed/repeated/forged intents, physical effects once, failed spawns, both shields, timeout/relocation priority, offline and reconnect.
- [x] Implement synchronous world contract and core event sequencing.
- [x] Run full pure suite; record red/green and commit.

### Task 3: Roblox adapter and controls

Files: src/stand/server/RobloxWorld.lua, Stand.server.lua; src/stand/client/Stand.client.lua.
- [x] Write packaging/syntax assertions before runtime files exist.
- [x] Implement original geometry, server-owned physical actors, full-volume safe point checks, impulses, hazards and explicit death cleanup.
- [x] Implement lobby/start, strict remote gate, snapshots and bounded logs. Diagnostics only in Studio via server-only BindableFunction.
- [x] Implement camera, keyboard/touch movement, jump, two attacks, five fractional hearts and status. No client health/target/position authority.
- [x] Run syntax/build checks; mark engine execution NOT RUN unless actually available.

### Task 4: Build, evidence and publish

Files: tools/build_combat_stand.py, test_combat_stand.py, run_stand_lua54.py; tests/run_stand.luau; .github/workflows/combat-stand.yml; reports/2026-11-06-combat-stand.md.
- [x] Build deterministic standalone XML place, check embedded sources exactly and absence of remote asset dependencies/ROM.
- [x] Preserve source evidence and derive compact test fixtures without changing archived observations.
- [x] Review complete branch; fresh full test execution; package only changed/new files.
- [ ] Publish new branch/PR through GitHub API; verify remote hashes, actual CI result and unchanged main. Report remaining engine gate accurately.
