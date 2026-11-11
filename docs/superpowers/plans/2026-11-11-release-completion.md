# Release Completion Implementation Plan

> **For agentic workers:** Use subagent-driven development for disjoint hero loading, UI and animation/cost tasks. Root owns portrait uploads, Studio, release integration, Git/Jira and delivery.

**Goal:** Correct the confirmed remaining product defects and finish available release implementation with honest native acceptance.

**Architecture:** Existing authoritative gameplay remains intact. Pure presentation policy, local asset readiness, actual imported segment animation and cached cosmetic writes improve the current client/server boundaries.

**Tech Stack:** Luau0.745, Python3.13, existing deterministic assets, Roblox Studio MCP/Open Cloud.

**Spec:** ../specs/2026-11-11-release-completion-design.md

## Global Constraints

- One existing Studio, MCP only; no computer UI or extra client/server windows.
- No production automatic trajectory assistance; no QA pose/HP/progress/resource writes.
- English default with catalog localization; native Roblox touch controls and44px minimum targets.
- Preserve physical R6/collider identity, flags, joints, support/ownership and same-body resources.
- Preserve places/BrickToads.rbxlx SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and unrelated concept art.

## Review Focus

- Pending/failed base or first morph loads must retain the appropriate visible fallback.
- Delayed callbacks and removal cannot control a replacement body/skin or leak local modifiers.
- Later-level and enemy/boss menus must reflect actual campaign context and progress.
- Narrow RU/EN invitations must have separate reachable touch targets without clipping controls.
- Cached static appearance must update after every real transform/alpha/lifecycle change.

## Tasks

- [x] Add behavioral RED/GREEN coverage and hero readiness with lazy active-morph resources; integrate client initialization/cleanup.
- [x] Correct campaign/result/personal-menu policy, boss progress and touch target layout with production-code tests.
- [x] Correct Queen Hair animation and avoid static cosmetic writes; validate deterministic lifecycle/cost changes.
- [x] Upload/map all three existing hero portraits and verify actual native image loading.
- [ ] Review each task; build, synchronize and perform native loading/UI/animation checks in the single Studio.
- [ ] Run complete current-source campaign with finite lives and verify manual next-game flow; retain all actual evidence and restore exact sources/state.
- [ ] Implement remaining accepted release code, instrument/measure as appropriate, and prepare the requested separate BrickToads experience.
- [ ] Independent final review, relevant regression/CI, explicit owned commits/push and factual Jira synchronization.
