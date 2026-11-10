# Guardian and Intro Leg Visuals Implementation Plan

**Goal:** Replace the first Guardian's generic cosmetic pod and broad intro boot with detailed source-informed red/black cannons and the slender intro leg12.

**Architecture:** A private four-mesh GLB supplies three battle meshes and one intro leg. Optional cosmetic GuardianAppearance binds the battle parts to the existing physical root; accepted-shot and health hooks drive preassembled recoil/flash/tint without changing combat. BossIntroWorld uses the imported leg when valid and retains its current proxy as a safe fallback.

**Tech Stack:** Luau, Python/trimesh/GLB authoring, strict playable serializer, Studio MCP/Open Cloud.

**Spec:** `../specs/2026-11-09-canonical-character-direction.md`; source boundaries in `research/canonical-visuals/BOSS_WALKER_SOURCE.md`.

## Constraints and rulings

- Continue the existing codex/walker-strikes checkout, explicit staging and approved canonical-hero authoring/export directory. User authorization already covers implementation, imports, push and Jira updates.
- Preserve the dirty places/BrickToads.rbxlx SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and all six earlier GLBs.
- Source facts: two red/black gfx10 cannons, HUD reticle11/glassC7, slender red gfx12 leg with small toe and upper joint/plate. Full external chassis/rear anatomy, exact RGB/PBR and3D projection are authored reconstruction, not measured source geometry.
- No new reactor eye, magical coils, invented HUD-as-body geometry, combat rules, projectile origins, collision, health, life, controls, timing or ownership changes. Generic cue(true) also signals blocked melee and must not trigger cannon fire.
- All cosmetic parts are preassembled before manual server ownership. Use actual imported rest rotations, native MeshSize/InitialSize and source mount/muzzle transforms. No new assembly parts during shot/damage playback.

## Tasks and ownership

- [x] Read-only source/shot/damage integration audit — guardian_visual_audit.
- [x] Author/freeze four detailed meshes, baked albedo and source/rig/validator evidence — boss_walker_mesh.
- [x] Implement GuardianAppearance with rigid-transform RED/GREEN lifetime, shot and health contracts — guardian_appearance_runtime.
- [x] Strictly package two boss templates/four parts from actual imported manifest, plus regression tests — guardian_visual_audit.
- [x] Integrate World spawn/shot/health/update and canonical intro leg fallback, preserving authority — root.
- [x] Upload through the existing approved directory, normalize actual resources and reopen serialized file — root.
- [x] Native visuals, recoil, damage, interruption/cleanup, ownership and party isolation; independent review and required checks — root/reviewer.

Delivery: commit and push the reviewed checkpoint; verify remote CI and update PR3 plus the relevant Jira tasks with explicit acceptance limits.

Follow-up owner feedback: mouth opening is too small versus the attached original-game frame. A new fear-mouth asset will be authored without changing the six frozen GLBs or this Guardian GLB; its acceptance is a separate recorded snapshot.
