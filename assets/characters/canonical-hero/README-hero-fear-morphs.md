# Boss-fear head morphs

`hero-fear-morphs.glb` supplies four independent, closed, connected 3D head meshes for the existing character templates. Each becomes one cosmetic MeshPart named `Morph`; body poses and motion belong to the shared character animation system.

This is a **head-only 3D adaptation**, informed by pinned NES graphics `32` and `33`, and adapted to the current detailed Green brawler and older orange Player Two. It does not claim an exact reconstruction of the original whole-body sprites. Those images do not establish a back view, eye depth, jaw cross-section, skeletal neck location, or 3D rotation. The stretched jaw/neck, cavity depth, popping eyeballs, pupils, teeth, tongue and asymmetric sculpt are authored interpretations. Green's familiar sunglasses have sprung onto the brow so the frightened eyes remain visible. Orange Player Two retains its existing absence of sunglasses.

The actual mesh has a deeply recessed open mouth and continuous jaw walls, rather than a black mark on a neutral face or an extruded sprite card. Eyes protrude from joined stalks; teeth and tongue join the mouth shell. Geometry remains a single connected, orientable closed surface per part. BeforeCut has a narrower, longer, asymmetric scream; AfterCut has a broader frontal scream. The software render shows front and three-quarter views of the actual mesh: Green on the top row, orange Player Two below; BeforeCut occupies the left two columns, AfterCut the right two.

## Frozen artifact and real import

- SHA-256: `ba7f9650dba2c0425db6ab0a3dc9f45041936c2eb798314864d0a8f93ac1e39a`
- Size: **6,193,776 bytes**; four meshes, four nodes, one primitive per mesh, one shared rough nonmetallic material.
- Real imported private Roblox Model: **94539676546833**; shared albedo atlas: **84359931596705**. [roblox-fear-morphs.json](roblox-fear-morphs.json) records the actual mesh/texture IDs, sizes, normalized CFrames and origin attachments.
- Color: one embedded 4096×4096 sRGB albedo, with padded 12×12 per-triangle cells and feature boundaries evaluated during baking. No `COLOR_0`, emissive image, emissive factor, emissive texture or external image is used.
- Khronos glTF Validator 2.0.0-dev.3.10: **0 errors, 0 warnings, 0 infos, 0 hints** in `hero-fear-morphs-khronos.json`.
- Existing canonical hero GLBs, palette GLBs, Green brawler GLB and attack morph GLB remained byte-identical. The already-dirty `places/BrickToads.rbxlx` was read only to verify its hash; this builder does not edit it.

| GLB node | MorphKind | Triangles | UV-split vertices | Height, studs | Import X, studs |
| --- | --- | ---: | ---: | ---: | ---: |
| GreenFearBeforeCut | FearBeforeCut | 12,334 | 37,002 | 3.081541 | -6 |
| GreenFearAfterCut | FearAfterCut | 11,168 | 33,504 | 2.808382 | -2 |
| PlayerTwoFearBeforeCut | FearBeforeCut | 11,824 | 35,472 | 3.298273 | +2 |
| PlayerTwoFearAfterCut | FearAfterCut | 10,596 | 31,788 | 2.961803 | +6 |

All meshes remain below 20,000 triangles and 65,536 exported vertices. Total triangles: 45,922. Player Two applies the neutral Head dimension ratios measured from `roblox-player1.json` and `roblox-player2.json` and omits Green's brow sunglasses. This preserves the distinction between the two existing styles; the meshes do not have identical centers.

## Neck-space attachment

Vertex coordinates use the existing cosmetic `Head.NeckRigAttachment` as `(0,0,0)`, with +Y up and -Z forward. Metadata is in Roblox studs; GLB coordinates are metres at **0.28 metres per stud**. Existing imported parts contain a 180-degree Y rotation; the builder composes the actual part and attachment CFrames to recover an identity rest-space neck, rather than mistaking the imported part center for the joint. The measured Green rest neck is approximately `(0,1.886075,-0.04)` and Player Two approximately `(0,1.88,-0.03)` in avatar rest space.

| Part | Neck-space bounding-box center, studs |
| --- | --- |
| GreenFearBeforeCut | `(0.022396, 1.340800, -0.178162)` |
| GreenFearAfterCut | `(0, 1.204221, -0.176106)` |
| PlayerTwoFearBeforeCut | `(0.020493, 1.435102, -0.166135)` |
| PlayerTwoFearAfterCut | `(0, 1.266867, -0.164218)` |

The X offsets in the first table are **import layout only**. Remove them before runtime binding. Derive import orientation using these measured centers and offsets; do not assume the Green/P2 centroid difference is pure X. Retain the origin-to-center displacement. After normalization, `Morph.CFrame * MorphOriginRigAttachment.CFrame` must equal neck-space identity. The negative center is the attachment position only when the imported MeshPart uses the authored identity orientation and its bounding-box center as its frame. Actual import rotation must be handled before constructing that attachment.

Runtime templates are one Model per morph under `ServerStorage.BrickToadsCharacterMorphs`, with `Morph`, `MorphOriginRigAttachment`, `MorphKind` of `FearBeforeCut` or `FearAfterCut`, `HeroTemplate` of `Mr. Green` or `Mr. Yellow`, `AppearanceProfile` of `CanonicalNESHeroMorph`, and `AppearanceScale` 1. Runtime replaces only the existing cosmetic Head during the corresponding fear state. No new Humanoid, collider, hitbox, damage, health, resource or ownership behavior is part of this package.

## Source and timing

The source pin is `feos-tas/DisAssemble@f1a43b69577246850d136473700a333b3cdfe93f`. Original images are `research/canonical-visuals/frames/hero-32.png`, `hero-33.png` and `hero-boss-appearance-reaction.png`. The authoring inspection enlargement `hero-fear-source-reference.png` preserves original pixels. Source/dependency hashes and the existing head fixture hashes appear in `hero-fear-morphs-rig.json`.

For the first-route Boss Walker appearance, source counter `01..DF` invokes animation `2C` / graphics `32`; `E0` performs the camera/arena setup and skips the fear helper; `E1..FE` invokes animation `2E` / graphics `33`; `FF` removes the intro object and skips the helper. These heads supply the two head-form changes only. The integrated finite intro now selects them at the verified milestones, preserves fear32 across the E0 skipped assignment, and releases the cosmetic context when FF activates the existing guardian pattern. Local 60 Hz timing, authored body poses and that FF release are adaptation; the complete source-body morph, recurring masked animation-pointer behavior and source Z motion are not reproduced. The underlying source research records other bosses' partial fear-helper traces separately; this artifact does not invent their full introductions.

## Rebuild and verification

Run `.tools/python-3.13.9/python.exe assets/characters/canonical-hero/build_hero_fear_morphs.py` from the repository root. It writes only this fear package's asset, rig metadata, validation report and previews. It reuses the existing reviewed geometry/export helpers without modifying them. Builder and dependency hashes are recorded for reproducibility.

The builder checks connected closed orientable geometry, unit normals, triangle/vertex limits, original-asset hashes and serialized float32 bounds. Run `node assets/characters/canonical-hero/validate_hero_fear_morphs.cjs build/hero_mesh_validator/package` for the independent Khronos validation. `hero-fear-morphs-validation.json` contains measured bounds, centers, dimensions and decoded export checks. The real import and normalized neck attachments are integrated. The strict place builder requires four fear resources alongside the four attack morphs in one private folder. Each appearance preassembles 19 MeshParts and 19 cosmetic motors (25 motors including the six physical-body motors); switching fear changes visibility through the existing neck binding.


## Prepared Studio checkpoint and limits

The checkpoint passed 45 validation commands and compilation of 123 Luau files. Fresh Studio opened the exact saved playable (744,382 bytes, SHA-256 `a20b157339a40161f387a3bdab95703a249df205b5a3cb36d340a3b81f031f03`), with source fingerprint `a9a7efd51486d814d2cf35ffefb9170b94456e49bb08d626008e9cd8c52459ca`. Native Session/Director/World preparation sampled `1/30/50/64/E0/E1/FE/FF` for three heroes, observed 32→33→idle and deferred active combat until FF. HP 37/100, raw Life 47, attempt 1, respawns 3 and server ownership remained stable. Separate fresh preparation checked reaction, native jump/Airborne, cancellation and actor replacement; another party remained unaffected. Native client camera checks covered the E0 cut and refusal of stale/other-party/free/ended contexts.

Loaded Green/P2 heads and the authored cosmetic intro (14 foot pieces and two impact markers) were captured through native Edit/runtime pose fixtures. The foot is a simple 3D proxy, not a finished boss mesh. This evidence does not establish an ordinary-input full-route playthrough, cold physical-device performance, complete source-body silhouettes/Z mapping, PAL timing parity, music/sounds, all 13 modes or production readiness. See [the integration report](../../../reports/2026-11-09-boss-appearance/README.md).
