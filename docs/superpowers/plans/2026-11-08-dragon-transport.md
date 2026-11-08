# Dragon transport implementation plan

Spec: docs/superpowers/specs/2026-11-08-dragon-transport.md
Execution: continue inline under the existing owner authorization; use current isolated feature checkout. No merge or Studio run.

## Global constraints
Fixed roster; five hearts, existing run resources, same body/owner/one life, existing public input schema. No avatar commerce. Static source evidence and Roblox calibration remain separate.

## Tasks

### Task1: Server flight and mounted/captured lifecycle
Files: DragonFlight.lua, DragonWorld.lua, LevelDirector.lua, Session.lua, GameController.lua, GameConfig.lua; focused real-runtime test runner.
RED: flight controller is absent; then cover heavy disable/grounded mount, hand priorities, human/offline behaviour, geometry recheck, shield/reaction/actor interruption and cleanup. GREEN: implement finite modes, scoped links and existing validated input hooks. Verify focused runner plus current combat/route suites.
Interfaces: DragonFlight.new(director), :heroIntent(slot,p,now), :step(now,dt), :enemyStep(id,e,dt), :beginCapture(id,e,target), :hitEnemy(id,heavy), :heroHit(slot), :forgetEnemy(id), :close(), :interaction(slot), :interact(slot,now,attack). World boundary: flight/grounded/link/unlink/fire sweep methods.

### Task2: Fire, physical adapter and original presentation
RED: mounted fire must use fixed4/22, max2, current sweep, walls, actor epochs and accepted tuning; real World contracts must restore flags/coordinates without touching new bodies. GREEN: implement anti-gravity server flight, same-body presentation links and bounded replicated projectiles; add entrypoint dependency, safe cleanup, original mount/capture/wing poses and confirmed feedback.

### Task3: Handoff
Run repository-native suite, all source/test compilation, structural tests and deterministic builders once after final edits. One fresh-context whole-change review, one regression fix pass, then full validation if code changed. Update coverage/source notes and Jira evidence; publish on existing PR branch with lease, verify current-head CI. Do not close tasks requiring Studio/device acceptance.

## Review focus
Stale/late hero and enemy identities; simultaneous mounting; life/owner preservation; shields under interrupted links; force/anchor restoration; fire wall tunnelling and deterministic first victim; reaction bypass; cross-group coordinates and run cleanup. No claim of exact source frames or Studio acceptance.
