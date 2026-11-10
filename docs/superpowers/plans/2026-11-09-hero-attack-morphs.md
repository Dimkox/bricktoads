# Hero Attack Morphs Implementation Plan

**Goal:** Display source-derived enlarged fists and boots on the green hero and P2 only during verified attack frames.

**Architecture:** Pre-attach two invisible cosmetic morph meshes per supported hero before server network ownership is pinned. Source presentation switches transparency and restores the original hand/foot; it never changes attacks, damage, movement, collision or resources.

**Tech stack:** Existing Luau presentation, Python GLB authoring/build, Roblox Studio MCP/Open Cloud asset import.

**Spec:** `../specs/2026-11-09-canonical-character-direction.md`; green style from `../specs/2026-11-09-green-brawler-art-direction.md`.

## Constraints and review focus

- Preserve the user's dirty `places/BrickToads.rbxlx` and all existing GLB binaries.
- Verify source frame bindings; distinguish windup, active morphology and return frames. A source marker never creates new damage.
- Four private model resources: GreenPowerFist, GreenBigBoot, PlayerTwoPowerFist, PlayerTwoBigBoot, each one MeshPart Morph and one MorphOriginRigAttachment.
- Wrist/ankle-origin coordinates use +Y up, -Z forward and0.28 metres per stud. Retain imported rest rotations, actual MeshSize/InitialSize and PBR maps.
- Missing/invalid resources leave the normal body visible. Interruptions, club/carry/air/death, replacement and destruction must not leave an enlarged or invisible limb.
- Different actors and palettes remain independent. No new parts/constraints are created during an attack.

## Tasks

- [x] Trace exact source morph frames and relative silhouette measurements; record verified facts versus inferred3D depth/anchors.
- [x] Author four source-derived morph meshes, baked material/UVs and rig metadata; inspect previews and validate glTF before upload.
- [x] Add native regression tests for frame selection, transition/lifetime, missing assets, transparency restoration, actor independence and rotated-rest attachment; implement the cosmetic binding.
- [x] Add strict manifest serialization in `tools/build_bricktoads_place.py` and regression coverage in `tools/test_bricktoads_place.py`, including InitialSize and PBR.
- [x] Import through the already-approved hero folder; verify actual colours, scale, orientation, origin and source mesh extents. Reopen the serialized place.
- [x] Exercise actual Studio morph appearance, interruptions, club priority, ownership and cleanup; independently review and run relevant checks. Evidence: reports/2026-11-09-hero-attack-morphs/.

Delivery: push this reviewed checkpoint to codex/walker-strikes/PR3 and update BT-14/BT-62 with the recorded acceptance limits. Those external results are verified after the commit.

Ruling: continue in the existing `codex/walker-strikes` workspace and approved asset directory. The owner has repeatedly authorized implementation, MCP imports, git push and Jira synchronization; no new design/permission question is needed for this slice.
