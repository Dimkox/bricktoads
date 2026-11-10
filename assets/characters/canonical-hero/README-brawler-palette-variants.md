# Detailed brawler palette variants

`brawler-player2.glb` and `brawler-brown.glb` share the actual detailed `green-brawler.glb` anatomy and fifteen-node articulated rig. Every position, normal, index, tangent, UV, node transform, material and non-color texture byte remains unchanged. The same `green-brawler-rig.json` joint metadata applies. Earlier GLBs and Roblox import manifests are untouched by the builder.

Only green skin texels in the embedded 2048×2048 base-color PNG are remapped. Red cloth wraps, gray metal cuffs/rivets, sunglasses and highlights retain their original texels. The linear tonal ramp preserves the existing grain, creases, warts and shaded forms; this is an atlas remap rather than multiplying green artwork by a brown tint. All alpha bytes, ORM and normal maps are preserved exactly.

P2 follows the pinned NES `palette_chars` slot `0F/0F/17/27`, with the extractor's approximate display swatches `(155,83,0)` and `(250,160,66)`. The existing `Mr. Yellow` runtime name does not change that source palette to another slot. Interpolating these swatches across authored 3D shading is an adaptation. Brown uses the approved third-player `(160,112,86)` skin and `(224,186,129)` light tones; no original third playable NES slot is claimed.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| P1 source | 16,143,164 | `22c949f45a084f68dd61053cd9e62c2651cb8d351bf124c9eb2a23347a0fe543` |
| P2 variant | 15,661,152 | `dc20fceef651efd190d3116d77c2d0075e4790c95abd9071812818c247351cac` |
| Brown variant | 15,636,648 | `0be712c48d4796e52eda54d3cd86ce03ed374c5b3b1a7300fe9bad86f539ecf4` |

The variants share triangle-position/normal fingerprint `5929985f8336955a57428c699616cfab18574bf3df51c6cb3686cd104d843eca` and non-color binary fingerprint `0f954ccf52305460caf48b0d41ae16bdb896a34229c4325bb6b160efe4b57a7a`. Each changes 3,911,424 skin/unused-atlas texels and preserves 282,880 non-green texels. The official Khronos validator `2.0.0-dev.3.10` reports zero errors and zero warnings for both exact GLBs. Full measurements and input hashes are in `brawler-palette-variants.json`; independent validator receipts are `brawler-player2-khronos.json` and `brawler-brown-khronos.json`.

`brawler-palette-triptych.png` shows actual textured mesh bust projections in P1/P2/Brown order. It was visually inspected for equivalent detailed anatomy, skin colors, red bands and intact glasses. Software lighting is approximate; live Studio texture loading, imported scale, full-body poses and runtime animation still require native verification.

Reproduce with:

```text
.tools/python-3.13.9/python.exe assets/characters/canonical-hero/test_brawler_palette_variants.py
.tools/python-3.13.9/python.exe assets/characters/canonical-hero/build_brawler_palette_variants.py --preview
node assets/characters/canonical-hero/validate_brawler_palette_variants.cjs build/hero_mesh_validator/package
```

The four behavior tests were observed failing before the builder existed, then passed. They verify source swatches/accessory preservation, ordered Brown shading and alpha, exact geometry/UV/joint/PBR preservation on the real P1 GLB, and refusal to overwrite the source.
