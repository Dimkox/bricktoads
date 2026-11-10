# Dedicated Brown attack and fear morphs

`brown-hero-morphs.glb` supplies four Brown resources using the exact serialized Green mesh arrays, normals, triangle indices, UVs, accessor metadata and node translations from the existing approved packages. No dimensions, source pivot or attachment origin changes are introduced. Earlier GLBs, Roblox manifests and runtime source remain unchanged.

| New node | Exact geometry source | Base-color atlas |
| --- | --- | --- |
| BrownPowerFist | hero-attack-morphs.glb / GreenPowerFist | 0, 2048×2048 |
| BrownBigBoot | hero-attack-morphs.glb / GreenBigBoot | 0, 2048×2048 |
| BrownFearBeforeCut | hero-fear-wide-mouth.glb / GreenFearBeforeCut | 1, 4096×4096 |
| BrownFearAfterCut | hero-fear-wide-mouth.glb / GreenFearAfterCut | 1, 4096×4096 |

The two embedded atlases selectively remap green skin to the approved Brown `(160,112,86)` / light `(224,186,129)` tonal ramp. Red tongue, dark mouth cavity, teeth, eyes, glasses and other non-green texels retain their original bytes. Both complete atlases contain zero remaining bright green skin texels under the documented check. Alpha remains exact. This fixes the native green fear-head problem without relying on MeshPart/SurfaceAppearance tint multiplication.

The package has four nodes, four meshes, two materials, two embedded atlases and no `COLOR_0`. Its size is **9,618,088 bytes**, SHA-256 **`4e3907a96bba1f3c4646da862922f0132548d1eb240c044733f6589a74a8eab2`**. The official Khronos validator `2.0.0-dev.3.10` reports zero errors and zero warnings. Independent geometry hashes, exact source rig metadata, source file hashes and atlas pixel counts are recorded in `brown-hero-morphs-rig.json` and `brown-hero-morphs-validation.json`.

Root packaging can clone the validated matching Green resource, preserve its existing native size/origin attachment and joint mapping, replace its material/texture with the corresponding dedicated Brown imported atlas, then retag `HeroTemplate` to `Mr. Brown`. Source node translations are retained for import/layout parity; the existing rig metadata still identifies the layout offset to remove when binding at the wrist/ankle/neck. Brown remains an approved third-player adaptation, not an original NES playable slot. Native import/appearance acceptance is recorded separately by the root worker.

Reproduce:

```text
.tools/python-3.13.9/python.exe assets/characters/canonical-hero/test_brown_hero_morphs.py
.tools/python-3.13.9/python.exe assets/characters/canonical-hero/build_brown_hero_morphs.py
node assets/characters/canonical-hero/validate_brown_hero_morphs.cjs build/hero_mesh_validator/package
```

The three tests were observed red before the builder existed, then passed. They cover Brown skin versus preserved mouth/eye details, exact real-GLB geometry/UV/pivot inheritance for all four resources, and refusal to overwrite a previous Green asset.
