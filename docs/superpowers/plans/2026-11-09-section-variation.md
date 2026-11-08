# Section Variation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Track each independently verified deliverable below.

**Goal:** Assemble the current first-level run from reproducible, varied, traversable sections.

**Architecture:** A pure LevelVariation module derives a fresh route from the canonical definition and a server run seed. GameWorld rebuilds only an empty arena; GameController installs one route per accepted run. Group-local configuration prevents changes leaking to peers.

**Tech Stack:** Roblox Luau, native Luau contracts, Python place builder, Studio MCP.

**Spec:** [section variation design](../specs/2026-11-09-section-variation-design.md).

## Global Constraints

- Preserve the dirty user starter `places/BrickToads.rbxlx`; never stage or overwrite it.
- Preserve the canonical definition, actor identities, raw Life, fly ordering and Guardian mechanics.
- No player path selection, safe-jump alignment or auto jump.
- Use server runId-derived seed; retain the route for respawn/reconnect.
- Keep configuration and geometry independent between groups; apply offsets once.

## Review Focus

1. Rejected Start must not clear actors, replace a route or spend an attempt.
2. A group rebuilding must not mutate the base template or another active group.
3. Cover must behave as part of its support for grounding and respawn.
4. Seed reproduction must describe the actual World geometry, not only metadata.
5. A fault during queue eligibility must not reenter or mutate the queue callback.

## Tasks

- [x] Pure `LevelVariation.lua` plus native tests: 14 checks across 1000 seeds; independent review found no actionable issue. Runtime integration remains separate.
- [x] `GameWorld:rebuildLevel(route)` with active-actor refusal, local route replacement, collider/support reset, variation attributes and StoneCover geometry. Test two group offsets and cover support.
- [x] Accepted-run integration in GameController and server dependencies. Test invalid Start, repeat Start after end, stable respawn route and independent groups. Add seed metadata to the run journal.
- [x] Close the queue eligibility reentry review finding; preserve fault isolation and visible owner action feedback already in the pending hardening slice.
- [x] Build the reproducible playable artifact and verify all relevant contracts, compilation and packaging. Sync exact source paths to Studio.
- [x] Exercise real generated geometry, cover ray support, run rebuild and group isolation in Studio. Save bounded evidence with explicit fixture limitations.
- [ ] Review final changes, commit and push; update Jira with implementation and remaining acceptance gaps. Do not mark the full game or production release complete.

## Review ledger

- Base: `0f095cd50f88eedc8da2780eeeea824e857983df`.
- Pure generator review: clean. World/integration excluded from that verdict.
- Hardening review: prior cross-group read isolation finding fixed; eligibility/quarantine reentry requires a focused correction and recheck.
