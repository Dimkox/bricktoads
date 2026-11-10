# Source-indexed player palette variants

`canonical-hero-player1.glb` and `canonical-hero-player2.glb` have the same geometry, node transforms, normals, face indices and joints as the frozen `canonical-hero.glb`. Only their `COLOR_0` float bytes differ. The base file remains unchanged; its SHA256 is recorded in `palette-variants.json`.

The verified source `palette_chars` row at main ASM line36743 contains initial player palettes:

| Slot | Source NES codes | The extractor's illustrative RGB |
| --- | --- | --- |
| P1 | `0F 0F 0A 1A` | black `(18,19,20)`, dark green `(0,102,0)`, light green `(88,184,44)` |
| P2 | `0F 0F 17 27` | black `(18,19,20)`, dark orange/brown `(155,83,0)`, light orange `(250,160,66)` |

The RGB function is read directly from `research/canonical-visuals/extract_source_frames.py::rgba`, using the same table as the reference sheets. It is an illustrative2C02 display approximation; source palette codes are authoritative. It is not an analog CRT match. These RGB values are converted to linear glTF vertex colours, preserving alpha1 for the actual opaque model surfaces.

P2 is **not** assigned an invented pure-yellow palette. If BrickToads retains the legacy name Mr. Yellow for this slot, that name is a modern naming adaptation. These two source palettes do not establish a third playable NES character. No Brown/Pimple variant is created or guessed here.

All GLB positions and node translations remain in metres at0.28metres per authored stud, exactly matching the base mesh. The shared rest/pivot file is `canonical-hero-rig.json`. The base mesh's inferred3D anatomy and neutral pose remain prototypes; a palette pass does not complete canonical animation or production art.

The previews `research/canonical-visuals/hero-model-player1-palette.png` and `hero-model-player2-palette.png` show front, three-quarter and side views under identical lighting. `build_palette_variants.py` reproduces the variants and asserts that every non-colour byte matches the base. `validate_palette_variants.cjs` runs an independently installed official Khronos validator; it does not access the network or upload assets. Studio import, colour retention, scale and animation remain separate acceptance gates.
