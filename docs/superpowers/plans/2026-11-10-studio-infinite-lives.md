# Studio Infinite Lives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Add server-authorized infinite Studio respawns without changing damage or normal published rules.

**Architecture:** The lifecycle stores a per-hero flag through a trusted event. Session checks server development permission; the Studio bootstrap owns the toggle and the HUD displays the replicated flag.

**Tech Stack:** Luau, Roblox Studio MCP, existing lifecycle/controller/UI test runners.

**Spec:** docs/superpowers/specs/2026-11-10-studio-infinite-lives-design.md

## Global Constraints

- Studio control uses MCP and one existing window.
- Infinite lives do not imply invulnerability; no large stock sentinel.
- Published play denies the development feature, regardless of a saved attribute.
- Native25 finite Won evidence remains unchanged and separately recorded.

## Review Focus

- Disabling at zero stock cannot leave an unspawnable active ghost.
- Enabling never revives an eliminated hero or reopens a closed run.
- Failed/duplicate spawns do not create extra actors or bypass shields.
- Client payloads cannot grant development permissions or toggle lives.
- Locale and compact mobile reserve displays remain valid.

### Task 1: Lifecycle and Session

- [x] Add failing Core/Session tests for more than four appearances, zero stock and disable edges.
- [x] Implement trusted SetInfiniteLives and gated Session:setInfiniteLives.
- [x] Verify finite-lives, reconnect, death, emergency and new tests.

### Task 2: Studio adapter and HUD

- [x] Add failing controller/gateway tests for Studio mode and remote denial.
- [x] Wire ServerStorage.BrickToadsGodMode, new-run defaults and active-group changes.
- [x] Add localized God Mode/∞ reserve display; run localization/UI checks.

### Task 3: Acceptance and delivery

- [x] Build and run full appropriate verification: 58/58 commands, 200 compiled files.
- [x] Sync only changed sources to the existing Studio through MCP.
- [x] Verify at least six ordinary deaths/respawns with God Mode and a disabled-mode control.
- [x] Export evidence and restore clean Studio with the God Mode attribute enabled.
- Delivery: commit/push and Jira evidence links are recorded by the enclosing PR/update.
