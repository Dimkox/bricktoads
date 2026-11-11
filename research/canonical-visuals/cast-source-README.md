# Decoded campaign cast source references

`extract_cast_frames.py` produces `cast-source-catalog.json`, `cast-source-contact-sheet.png`, native transparent PNGs in `cast-frames/`, and family sheets in `cast-contact-sheets/`. It reads the pinned Battletoads USA NES source at `feos-tas/DisAssemble@f1a43b69577246850d136473700a333b3cdfe93f`; missing public source files are cached under ignored `build/canonical-source`. It does not fetch or assemble a ROM, upload art, or mutate the runtime.

Run from the repository root:

```text
.tools/python-3.13.9/python.exe research/canonical-visuals/extract_cast_frames.py
.tools/python-3.13.9/python.exe tests/canonical_cast_source/run.py
.tools/luau-0.745/luau.exe tests/canonical_cast_source/profiles.luau
```

The current output has **32 entries / 164 frames**: the catalog's 29 character families, a separate Boss Walker intro-foot entry, the dynamic Racing Rat, and Healing Fly. `Pig`, `Walker`, and `Slug` are runtime names for source `PsykoPig`, `TallWalker`, and `Slime`. Hero references cover all three runtime templates; the Brown palette and third player are an approved adaptation of the source's two playable slots.

Every frame records its exact source namespace, metasprite address/components, visible pixel bounds, palette and reference PNG. Hero graphics use their frame-minus-one dynamic CHR lookup. Clinger-Winger and Armageddon deliberately use the hero sprite-configuration table with their **static special banks**, as the source renderer does. A numeric graphics ID is not interchangeable across these namespaces/banks. Full body depth and unseen rear geometry are not established by a 2D silhouette.

`cast-animation-profiles.json` is the companion handler trace, with 35 runtime keys including the three hero aliases. It separates real locomotion cycles from state-selected frames and child projectiles, and records clip IDs/caller masks/high-bit transforms. `src/server/gameplay/CanonicalCastProfiles.lua` exposes an immutable `get(kind)` row and a pure `sample(kind, context)` query. Normal multi-frame cycles require an explicit zero-based `phase`; untraced state/counter conditions return `nil, 'UNKNOWN_STATE'`. Its bank-specific namespace is returned alongside `spriteNamespace` and `bankRecipe`. Applying a physical-time calibration remains the caller's declared adaptation.

The extractor first cross-checks 16 known Hero/Pig/Dragon frames against the earlier catalog and PNGs, including both enlarged multi-list hero forms and both fear forms. The PNGs match byte for byte under the original reference palette. New family sheets use source actor palette flags and actual authored palette writes, rather than treating every enemy as the initial character palette.

`object_set_palette` copies cfg bytes 3/4/5 to palette RAM at offset cfg byte 7 plus 1/2/3 (main ASM 9298–9305). The loader takes actor palette flags from cfg byte 10's low two bits (28889–28895). The renderer XORs these bits into each metasprite's palette slot (34168–34170, 34264–34268). `selectedPaletteContext` and `paletteVariants` retain the exact cfg file/line, trigger and palette RAM writes. A snapshot includes zero-delay palette setters in the same authored trigger group, including Robo-Manus's palette setter immediately after its spawn record.

For example, Snowman's slot 3 becomes `0F 0F 23 20` from cfgs1 line 258; its body is white with a purple shadow, while the hat retains its separate brown palette slot. Dark Queen uses actor XOR 2 and slot 3 `0F 0F 15 27` from cfgs2 line 336, giving magenta and peach rather than a uniform gold character. Terra Tubes sets slot 3 to `0F 0F 00 10`; Electrofish, Hammerfish, Shark and Duck use their distinct loader XORs. `initialToEffectivePaletteMap` gives all twelve visible slot/code RGB and source-code mappings for mesh authoring. RGB is an illustrative NES display table; the recorded NES codes are authoritative.

Bank load metadata follows literal source tile counts and real adjacent source bytes, including compressed streams which continue into the next declared file. It includes the universal `EA..FF` raw tile tail and the additional bank 2/4/7 boss overrides. The declared Arctic Caverns final graphics load runs beyond the source bytes reconstructed here; its unresolved 126-byte tail remains in `bankLoads.unknownTailBytes`. None of the selected Snowman references uses that tail. Missing bytes are not painted or silently invented.

Explicit remaining unknowns:

- Snake PNGs contain source head/turn sprite components. Its complete body uses a procedural nametable path and is not represented as a finished full-body source sprite.
- Tall Walker graphics `19` is the upper body. Its verified straight procedural legs remain in `tall-walker-procedural-leg-catalog.json` and the dedicated source report.
- Static authored palette contexts do not prove exact natural-play interpreter scheduling, Surf City's rotating palette loop, or Clinger-Winger's cycling palette loop.
- Complete animation state timelines, every intro/interstitial, source emulator timing, and 3D joint/depth reconstruction remain separate from this extraction.
