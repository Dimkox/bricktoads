# First Guardian Appearance Implementation Plan

> Agentic execution: subagent-driven-development; work continues in the existing codex/walker-strikes checkout and already-approved asset folder.

**Goal:** Play a finite source-derived foot/impact/fear/camera introduction before the first Guardian becomes active.

**Architecture:** A group-scoped server intro owns a nominal60Hz source counter and captured run/level/hero identities. Its plain context drives cosmetic World props, source32/33 hero poses and four preassembled fear-head resources; a local camera follows only the viewed group's introduction. The existing Guardian pattern activates once afterward.

**Tech Stack:** Luau, existing native contract fixtures, Python/GLB authoring, Studio MCP/Open Cloud.

**Spec:** `../specs/2026-11-09-canonical-character-direction.md`; verified chronology in `research/2026-11-09-canonical-character-animation-source.md`, section Boss Walker appearance.

## Constraints and rulings

- User authorization covers continued implementation, canonical fear, asset import, git push and Jira synchronization; repeated design/permission questions are unnecessary.
- Keep the dirty places/BrickToads.rbxlx byte-identical and exclude it from commits; retain all five existing GLBs.
- Counter1..DF requests fear32; impacts30/64; foot12 begins50; E0 changes perspective and retains prior fear; E1..FE requests33; FF ends.60Hz/3D anatomy/motion/camera/three heroes are explicit adaptations.
- No healing, life/shield reset, extra damage, player auto-path, total input lock or new combat rule. Release held objects through existing lifecycle functions.
- Independent groups, stale/replaced/dead actors, run replacement/quarantine, skipped timestamps, reused head parts and exact transparency restoration must remain safe.

## Tasks

- [x] Audit pinned source events, fear-write semantics, graphics32/33 and first-route mapping.
- [x] Add finite BossIntro/Director lifecycle and BossIntroWorld prop hooks, with RED/GREEN tests and public identity bounds.
- [x] Add real fear poses, four optional head morph bindings, shared-part transition safety and regression tests.
- [x] Author four sculpted fear heads, inspect/validate, upload through approved folder and normalize real imported resources.
- [x] Package eight total morphs using strict shared validation and add camera/localization/CI integration.
- [x] Reopen the generated playable, check intro chronology/visuals/interruption/resources/group isolation, independently review and run required checks.
Delivery: push this reviewed checkpoint, then verify remote CI and record actual results on PR3 and BT-14/BT-62. The external result is posted after the commit, without declaring full production acceptance.

## Ownership

- boss_intro_runtime: BossIntro/BossIntroWorld, LevelDirector, GameController, server dependency wiring, focused lifecycle tests.
- hero_fear_meshes: new fear asset authoring files only.
- boss_intro_source_audit: builder/packaging regression files after read-only source audit.
- root: presentation/appearance, client camera, source localization/CI, imports and native acceptance, final review/delivery.
