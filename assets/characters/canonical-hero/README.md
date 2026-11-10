# Canonical-reference hero mesh study

This is an authored 3D **prototype**, based on the pinned original NES hero references. It is not a completed canonical character, an accepted animation set, or a production release asset. It contains no explorer clothing, boots, added equipment, Humanoid, physical root, script, or gameplay state.

The source reference is [Battletoads source at f1a43b6](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads), rendered separately in `research/canonical-visuals/`. `hero-idle-proportions.json` measures frame01's visible24×33pixel bound and P1 palette indices0F/0F/0A/1A. Those are measured source facts. The model's depth, anatomical joints, symmetric rest stance and details are inferred 3D art decisions. The original sprites do not provide a3D skeleton.

Files:

- `canonical-hero.glb`: fifteen named mesh nodes with a parent hierarchy, smooth vertex normals and one matte vertex-colour material. Arms, forearms, hands, thighs, calves and feet are independently controlled. No external texture files are required.
- `canonical-hero.obj`: editable static geometry with vertex-colour extension; use GLB for hierarchy.
- `canonical-hero-rig.json`: exact pivots, fourteen joint attachment pairs, per-part bounds/counts, orientation, intended import scale, and inferred face-feature landmarks for later mouth/eye morphs.
- `build_canonical_hero.py`: deterministic authoring and software-rendering source, using only the Python standard library. Organic surfaces use variable-radius lofts, sculpted torso contours, facial features, hands and webbed feet. Joint-centred inner volumes cover segment caps during bends.
- `validation.json`: finite geometry, index/normal and hinge probe results.
- `khronos-validation.json`: independent official Khronos validator result, version2.0.0-dev.3.10: **zero errors and zero warnings**. Format details follow the [glTF2.0 specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html); `COLOR_0` is linear and the material multiplies its colour.

The actual local preview is `research/canonical-visuals/hero-model-turntable.png`, ordered **front, three-quarter, side**. `hero-model-joint-bend-check.png` uses an explicitly noncanonical articulation probe, to inspect cap coverage and joint continuity. It is not a walk, attack or fear animation copied from the game.

Build with `.tools/python-3.13.9/python.exe assets/characters/canonical-hero/build_canonical_hero.py`. Independent validation can be run with `node assets/characters/canonical-hero/validate_glb.cjs <local-Khronos-gltf-validator-package-directory>`; the validator is not a production dependency and the command does not download anything.

## Import boundary

Coordinates use +Yup and −Zforward, with the existing R6 Torso/root origin at0,0,0. Authoring geometry, OBJ, and rig JSON use Roblox **studs**. GLB `POSITION` values **and node translations are multiplied by0.28**, so the about6.04stud envelope is about1.69metres in the GLB. This follows [Roblox's standard units](https://create.roblox.com/docs/physics/units). The rig JSON records both dimensions and the exact conversion. Measure the inserted height, then apply any required uniform correction to every part and attachment. Do not align using the bounding-box centre.

If the importer recentres each MeshPart, compute the saved global joint point in the imported model frame and convert it through each actual part's CFrame. Child mesh nodes are located at their joint pivots in the GLB. The local rest shoulder correction is0; the old explorer adapter's hardcoded±45degree correction must not be applied to this asset.

All parts remain **cosmetic**: massless, no collision/touch/query, connected to the existing body without replacing or healing it. Reassert manual server ownership after assembly. Vertex colour retention, material/part splitting, scale and orientation still require an actual Studio import check.

## Limits and next work

The neutral mesh improves the source-inspired body silhouette and removes the rejected clothing direction. Its front projected width/height is about0.70 compared with the reference's0.727; the rest pose and projection differ, so this is **not** proof of exact canonical proportions. The three-quarter ratio differs further. Depth is inferred and anatomy/facial silhouette still needs visual acceptance against source poses.

The segments contain closed overlapping surfaces rather than a single welded skin. There are no empty hinge gaps in the supplied bend probe, but the segment/cap transitions can still show contour or lighting seams. A future skinning pass may be appropriate. Source attack morphs, exaggerated fist/boot geometry, open-mouth/extended-eye fear forms, and source-driven animation poses are not present in this neutral mesh. No Studio, network, performance, mobile, animation or all-character completion claim is made here.
