# Tall Walker source-profile3D study

`tall-walker.glb` is a bounded cosmetic prototype of source type`11`, not a humanoid with long thighs/calves. It has five independently controlled visual nodes: **UpperBody, LeftStrut, RightStrut, LeftFoot, RightFoot**. It contains no Humanoid, physical root, health, script or gameplay state.

The verified references are `research/canonical-visuals/tall-walker-procedural-leg-reference.png`, its catalog, the light/heavy attack sheets and `tall-walker-source-verification.json`, pinned to source revision`f1a43b69577246850d136473700a333b3cdfe93f`. The renderer was independently checked for35 prepared cases. This asset does not turn those static checks into an accepted Roblox gait or attack implementation.

## Preserved source facts

- Upper-body graphics`19` has a13×27pixel visible profile. Neutral full type`11` has a14×89pixel bound, versus the hero's24×33pixels. At the current hero study's6.0367stud height this produces a16.2809stud Walker envelope.
- Each source leg renders8sprites: **seven shaft sprites and one terminal-foot spriteD3**. This is not eight independent bones or a sequence of humanoid knees.
- The source changes the straight leg's slope and independent foot endpoint. The study therefore uses one continuous strut per leg, positioned and scaled between a body attachment and the foot. A24/−24pixel prepared spread is shown in `source-spread-preview.png`.
- The initial source palette slot is`0F 18 28 20`: olive/yellow/white. RGB comes from the same illustrative2C02 table as the reference extractor and is converted to linear`COLOR_0` with the exact IECsRGB transfer. Source palette codes remain authoritative; this is not a CRT measurement.

## Bounded3D interpretation

The upper body is a lightly bevelled, shallow extrusion of the actual source profile, including its transparent gaps. No closed cockpit, engine, unseen rear machinery, arms or knees were invented. Preserving an alpha opening through the extrusion is a bounded visual choice; it does not establish the original object's unseen3D construction. The side view is intentionally shallow and cannot claim a canonical backside.

Depth is inferred: upper body0.76stud, foot0.90stud, strut depth0.30stud. The struts have the measured source-facing width but an inferred shallow oval section. Their depth layers stay within the lower body; they remain straight when the feet spread. Both feet rest on one3D ground plane. The original renderer's2pixel back-leg layer offset remains in the source metadata, rather than becoming a floating physical foot.

The source-facing pixel contour is smoothed with a quarter-pixel bevel and a tenth-pixel diagonal bridge, constrained to the original outer profile box. These are3D reconstruction choices. Source white highlights are retained as vertex colours; metallic0.25/roughness0.62 are presentation calibration.

## Coordinates and integration

`rig.json` records all pivots and attachment endpoints in **studs**. The model origin matches the existing R6 Torso/root; its rest ground is localY−3. Authoring+Yis up, source-profile horizontal is+X and shallow depth isZ. The source renderer prepares facing-right; a gameplay adapter may rotate the complete cosmetic visual to its chosen forward axis.

GLB positions and node translations are in **metres**, multiplied by0.28. Expected height is about4.55865metres →16.2809studs. Measure the imported world-vertex bounds and scale every visual part/attachment uniformly if the importer applies a different conversion. Do not align this asymmetric model by its bounding-box centre.

For each leg, compute the current top attachment from UpperBody and an independent foot endpoint. Centre its strut at`(top+bottom)/2`, align local+Ywith`top−bottom`, and set its Ysize to the distance. A basis with right=`axis×depthReference`, up=`axis`, back=`right×axis` keeps the source-facing stripe stable. Translate the foot node to the endpoint. Do not insert a knee to imitate the source slope.

All five parts must remain cosmetic/massless/noCollide/noTouch/noQuery. Preserve the existing actor identity, health, physical body and ownership ledger. Reassert manual server ownership after assembly. No runtime integration was changed in this task.

## Files and evidence

`build_tall_walker.py` reproduces the GLB, metadata, numerical checks and local renders using Python's standard library and the frozen hero's geometry helper functions. It reads the verified source alpha and the original terminal tile from the pinned source cache; it does not download or upload anything.

- `turntable.png`: source-profile / three-quarter / shallow side views.
- `upperbody-closeup.png`: the same visible profile and its retained opening.
- `source-spread-preview.png`: straight-strut prepared spread, with no invented hinge motion.
- `validation.json`: finite geometry, valid indices/unit normals, closed manifold/component checks, independent binary metre bounds, an actual through-mesh ray probe at a source-enclosed transparent pixel, and zero straight-centreline error during spread.
- `khronos-validation.json`: independent official Khronos validation; `validate_glb.cjs` accepts a local validator package and does not use the network.

Each mesh remains below20,000triangles. Per-mesh counts and exact hashes are in the validation report. The rig manifest records all existing hero GLB hashes; the builder asserts those files remain unchanged. Actual Studio upload/import, vertex-colour retention, scale, gameplay alignment, animation timing, networking and mobile performance remain unverified. This does not complete the other NPCs, bosses or all-character redraw.
