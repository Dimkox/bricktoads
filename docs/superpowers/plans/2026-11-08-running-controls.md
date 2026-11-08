# Walking and Running Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Add standard Roblox keyboard/touch walking, double-tap running, longer run jumps and actual-running mega strikes for heroes and ground enemies.

**Architecture:** Native InputContext/InputAction/InputBinding owns keyboard and independent touchscreen buttons. A pure client direction/tap model emits bounded Move/run intent. Server physical movement validates actual run and freezes accepted attack profiles; terrain and trajectory selection stay player-controlled.

**Tech Stack:** Luau, Roblox0.746 native input/physics, native Luau0.745 tests, Python deterministic place builds.

**Spec:** docs/superpowers/specs/2026-11-08-running-controls.md

## Global constraints

- Preserve the user-edited places/BrickToads.rbxlx; generated delivery is BrickToadsPlayable.rbxlx.
- Standard Automatic InputBindings with UIButton, no virtual stick or custom touch protocol.
- No automatic safe trajectory or terrain changes. Main JumpPower50/grace/jump-consumption stay unchanged.
- Run speeds16/24 for heroes,9/16 for ordinary ground enemies; actual run threshold75%.
- Optional Move.run boolean only; client never supplies speed, attack profile or damage.
- Legacy stand without Movement config keeps its current behavior.

## Review focus

- Independent direction + attack + jump presses, release of one action, focus/context changes and no duplicate Activated actions.
- Actual run versus a request, wall push, knockback, timeout, reaction, offline/owner/body replacement and Dragon/carry restoration.
- Walking takeoff cannot acquire run speed in midair; run takeoff has longer range with the same Y/single-jump rules.
- Running primary ordering against opportunistic interactions; mandatory held actions and flight remain usable.
- Hero low-Life finisher must never leak into enemy running strike; accepted tuning remains immutable.

## Task1: Native client controls

**Owner/files:** client worker: src/client/BrickToadsClient.client.luau, new MovementInput.luau and RobloxInputBindings.luau, tests/gameplay/MovementInput.spec.lua, new tests/run_movement_input.luau.

**Interfaces:** MovementInput provides press/release/reset/vector returning camera-relative x,z,run. RobloxInputBindings builds disabled client context using direction/action GuiButtons, invokes direction press/release and action callbacks, and exposes setEnabled/reset/destroy. Main client sends Move.run plus immediate edges, preserves ordinary packet identity/sequence, and removes gameplay stick/legacy duplicate input handlers. Spectator camera controls stay separate.

- [x] Write meaningful double-tap/hold/release/diagonal/opposite/context reset tests; obtain RED.
- [x] Implement pure input model and Automatic native action bindings; no custom finger IDs.
- [x] Integrate responsive direction buttons and primary/Jump, with a desktop R shortcut and readable run/mega hints.
- [x] Verify native/compiler and hand off exact interfaces; root performs Studio input/layout checks.

## Task2: Physical locomotion and presentation

**Owner/files:** world worker: src/server/gameplay/GameWorld.lua, src/server/gameplay/DragonWorld.lua, tests/group_world/contracts.luau. Preserve the existing uncommitted footprint fix.

**Interfaces:** move fourth optional boolean; isRunning, movementMode, resetLocomotion per spec. Source config.Movement is supplied by task3. Old body references never target replacements.

- [x] RED actual world contracts for walk/run caps, qualifying velocity/support, zero/timeout/reaction, actor isolation, longer run takeoff and no midair promotion.
- [x] Implement bounded physical mode, takeoff cap, cleanup and distinct trusted walk/run gait; forward the new Move argument through DragonWorld.
- [x] Preserve carry/Dragon flags, saved old bodies, force/flight behavior and single-jump rules.
- [x] Run world contracts/compiler and hand off engine-visible mode attributes.

## Task3: Trusted combat/protocol integration

**Owner/files:** combat worker: src/stand/server/Session.lua, Combat.lua; src/server/gameplay/SourceCombat.lua, LevelDirector.lua, GameConfig.lua; tests/stand/FakeWorld.lua, tests/gameplay/SourceCombat.spec.lua and a new focused running-combat runner/spec. Coordinate any additional test file before editing.

**Interfaces:** strict optional Move.run boolean, max10 fields for Move only; world methods above are feature-detected for legacy doubles. GameConfig.Movement holds exact spec calibration. EnemyRunStrike fixed profiles4/22/raw16 and existing PigRush tuning. Session snapshots may add movementMode for client hints.

- [x] RED schema, stale requests, stationary/knockback fake-run, hero F/R acceptance, immutable running strike, enemy fixed-profile and interaction ordering cases.
- [x] Implement strict request propagation, main calibration, actual-running action choice and NOT_RUNNING feedback code.
- [x] Preserve mandatory held interactions and source NPC Pig behavior; add bounded NPC Walker run approach and lifecycle resets.
- [x] Run focused combat/director/legacy suites/compiler and hand off config/action names.

## Task4: Root integration and delivery

- [x] Review workers and update CombatFeedback/CI/build tests as required by actual behavior.
- [x] Run the complete relevant suite once after integration, build the deterministic place and compare every Studio source.
- [x] Exercise ordinary keyboard walk/double-tap run, run jump versus walk jump, running primary and standard UI action bindings; render mobile layouts and record native enemy contracts. New human-enemy engine checks remain NOT RUN. Physical devices remain NOT RUN unless available.
- [x] Update exact reports/handoff, git commit/push existing PR3 branch, CI and Jira. Preserve historical pre-running observations and explicitly cancelled Cliff trajectory work.

Verification: final movement suite34/34/compiler91 and final HUD focused5/5/compiler91. Four emulated layouts and native UIButton/keyboard combinations checked; new human enemy/multiplayer/physical touch/reconnect/full route remain NOT RUN and are not completion claims. Delivery evidence is the branch push, PR3 and linked Jira comments.
