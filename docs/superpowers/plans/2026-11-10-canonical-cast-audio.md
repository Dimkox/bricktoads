# Canonical Cast and Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Finish source-informed character presentation across the campaign, then add actual game audio and effects.

**Architecture:** Pinned source traces feed pure presentation sampling and deterministic articulated mesh assets. Existing world adapters attach/update cosmetics without changing gameplay. Client sound/effects consume authoritative confirmed events and mode/boss context.

**Tech Stack:** Luau, Python mesh/sound synthesis, Roblox Studio MCP/Open Cloud, existing builders/tests.

**Spec:** docs/superpowers/specs/2026-11-10-canonical-cast-audio-design.md

## Global Constraints

- One existing Studio window; all Studio control through Roblox MCP.
- Retain gameplay collider rigs, source combat and finite/God-mode rules.
- English source labels, native localization, compact touch HUD.
- Protect dirty starter and unrelated concept-art files.
- Keep decoded source facts separate from authored 3D/audio choices.

## Review Focus

- Graphics IDs from different families/banks or boss high-bit callers must not collide.
- Reaction/death/held/mounted priority must interrupt/reset stale attack forms.
- Every mesh is cosmetic, collisionless/massless and attached before server ownership.
- Missing/moderated resources cannot hide the only visible character or break gameplay.
- New snapshots, respawns, groups and level changes cannot replay old sounds or leak effects.

### Task 1: Source and cast matrix

- [x] Map every runtime family/template to pinned handlers, graphics banks and source states.
- [x] Decode available reference silhouettes/timelines; record measured, inferred and unresolved values explicitly.

### Task 2: Hero and creature animation

- [x] Add failing meaningful state/namespace/lifecycle tests.
- [x] Implement supported source hero states and family-specific articulated animation sampling, retaining untraced-state limits.
- [x] Integrate trusted world context without gameplay changes and review.

### Task 3: Character models

- [x] Generate complete named cast meshes and palette variants with geometry checks.
- [x] Import through MCP, export asset manifests and package resources.
- [x] Verify articulated source poses and appearances in native Studio; fix visual defects.

### Task 4: Sound and effects

- [x] Author/import actual original SFX/music after character work.
- [x] Add confirmed-event audio/effects with dedupe, settings and bounded cleanup tests.
- [x] Verify native loaded playback, nonzero output, mute and action effects in Studio.

### Task 5: Delivery

- [x] Run relevant full regression/build checks and independent review.

Delivery uses a separate branch because PR3 was already merged. Push the verified change, check its exact-head CI and add evidence to Jira; the external delivery results live in the PR and issue comments.

Current evidence: [native and automated acceptance](../../../reports/2026-11-11-canonical-cast-audio/README.md). Physical-device acceptance, real reconnect and the explicitly unresolved source traces remain open.
