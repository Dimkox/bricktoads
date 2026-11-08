# Gameplay completion implementation plan

> **For agentic workers:** Use superpowers:executing-plans task-by-task. Keep source and Studio evidence separate.

**Goal:** Prepare the next missing combat family and the observation/feedback needed to test a complete game in Studio later.

**Architecture:** Reuse Session/Director/GameWorld and current public intents. A private bounded RunJournal consumes existing server records; a small projection feeds deduplicated client feedback through State snapshots.

**Tech Stack:** Native Luau0.745, Roblox ModuleScripts, Python deterministic place builder.

**Spec:** docs/superpowers/specs/2026-11-08-gameplay-completion.md

## Global constraints

-5hearts,3successful respawns per run; fixed1–3hero roster; same capabilities for templates.
- Preserve existing ownership, one-life/claim closure, offline effects, shields and hand priorities.
- Studio/device acceptance is deferred explicitly, never inferred from native tests.
- Unknown source parameters stay unknown; Roblox timing/geometry is disclosed calibration.

## Review focus

- Low-Life Dragon must remain profile22, not Dash finisher21.
- An accepted attack must retain tuning/action while victim/health/configuration changes.
- Diagnostic errors/invalid rows cannot stop gameplay or grow memory without bound.
- Feedback must not replay historical events after first sync/group/run changes or stale snapshots.
- Private diagnostics and test controls must never become client mutation APIs.

### Task1: Dragon primary family

Files: Combat.lua, GameConfig.lua, LevelDirector.lua, GameWorld.lua; tests/gameplay/DragonStrikes.spec.lua, tests/run_dragon_strikes.luau; world-pose contracts and source note.

- [x] RED: fixed22/raw16 at raw15/16, NPC damage/profile, NPC/human acceptance/miss/changed victim/offline/interruption and no extra death-drop.
- [x] Implement DragonHeadbutt with reach6,width3,height4, windup.35,cooldown1.25,recoveryPose.25,reaction.75; these are prototype tuning, not source frames.
- [x] Add original head/wing cue with reset tests; run combat/Dragon/world suites.

### Task2: One bounded run journal

Files: gameplay/RunJournal.lua, Session.lua, GameController.lua, LevelDirector.lua, server entrypoint; tests/run_journal.luau and focused integration contracts.

Interfaces: `RunJournal.new(context,capacity?)`; `:record(row)`, `:snapshot()`, `:feedback()`; context includes build/rules/run/group. Journal owns monotonic seq and clones/sanitizes finite data with bounded depth/width. `feedback()` allowlists recent public fields only.

- [x] RED: bounded overwrite/dropped count; immutable snapshots; malformed/deep/unbounded payloads; no private fields in feed; separate run identities; failing logger does not interrupt a hit.
- [x] Wire journal through the single Session record callback; record missing ordinary-enemy/result events and a read-only Studio export with no gameplay controls.
- [x] Verify native integration and server/public build boundary.

### Task4: Source-state unarmed chain (execute after Task1)

Files: gameplay/SourceCombat.lua, LevelDefinition.lua, LevelDirector.lua, GameConfig.lua, GameController.lua, Session.lua, Combat.lua, world presentation; tests/run_source_combat.luau.

Interfaces: `SourceCombat.bind(session,director,config)` installs server-only attack selection and modern reaction policy. `Combat.hitEnemy(rawLife,action)` returns source profile/rawDamage/rawLife/dying/heavyReaction/recover. Actor records carry `rawLife/maxRawLife`; public hearts remain0..3. Stand fixtures without source records retain their legacy subtraction.

- [x] RED: exact initial records, nibble3/4 and heavy7/8, Dragon overhead, NPC2→0 alive/1→underflow, OR7 recovery, a real31→29→27→25→23→21→19→15→7→death chain, frozen selection/current victim, shields/protection/offline/identity, interaction priority and forged internal names.
- [x] Implement source profiles/arithmetic, authoritative NPC Life and recovery, modern reaction-hit policy, selector and acceptance input/effect separation; retain legacy scene behavior.
- [x] Add original source-action poses without visual damage; run full regressions and document adaptations.

### Task3: Confirmed client feedback and handoff

Files: client/CombatFeedback.luau, client entrypoint; tests/CombatFeedback.spec.luau; CI/build/report/README.

Interface: `CombatFeedback.new():sync(snapshot)->rows` consumes run/group plus numbered recent feed; baseline first sync and identity change; bounded dedup cursor, reject stale/out-of-order snapshots. Rows carry finite text/kind only; no gameplay mutation.

- [x] RED: first-sync/rejoin baseline, repeated and stale packets, missed packet with remaining events, group/run switch, bounded cursor and allowed-event text.
- [x] Add short text feedback to the existing HUD without adding controls or assets. Reset stale presentation on identity changes.
- [x] Full native/compile/build checks, independent review/fix pass, coverage inventory and publication preparation. PR/Jira publication is tracked by their actual commit/CI links. Preserve explicit Studio NOT RUN.

## Closeout

30 commands and78 compilation checks pass. Independent review found4P2; all reproduced then fixed in one coordinator pass with full-suite verification. [Report](../../../reports/2026-11-08-gameplay-preparation/README.md) records source limits and remaining work. Original rig work remains BT-14, animations BT-62; requested avatar/cosmetic access is BT-73, unimplemented pending decisions. Studio was intentionally deferred by the owner.
