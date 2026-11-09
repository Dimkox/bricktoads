# Canonical NES character visual reference

Reference: **Battletoads USA NES**, pinned [`feos-tas/DisAssemble@f1a43b6`](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads). This is a source-indexed research extraction for the owner's canonical redraw request, not a completed 3D character set or animation implementation. No ROM was downloaded, assembled, uploaded or added to the repository.

## Review artifacts

- [Hero movement, strikes, morphs and fear poses](hero-locomotion-and-morph-reference.png). Each hexadecimal caption is a source **graphics frame ID**, not an animation ID or a Roblox asset ID.
- [Boss appearance reaction](hero-boss-appearance-reaction.png): hero gfx `32/33`, used by source animations `2C/2E`. Their eyes/mouth/body forms are actual source shapes, not generic shoulder rotations.
- [First-route object poses](first-route-object-reference.png): Pig movement `02/03/04` and windup/contact `05/06`; final Dragon normal/reaction/strike `09/0A/0B/0C`; Tall Walker upper-body `19` only.
- [Boss Walker intro foot](boss-intro-foot-source-reference.png): object gfx `12`, the source intro-foot geometry before the arena graphics/camera cut. It is a distinct long mechanical limb, not the ordinary Tall Walker body or an invented humanoid boss entrance.
- [Machine-readable frame catalog](hero-frame-catalog.json) includes source labels, sprite-configuration addresses, every sprite component, measured visible bounds, input hashes and unrendered cases. Individual native-size transparent PNGs are in `frames/`.
- [Idle proportion data](hero-idle-proportions.json) contains the exact hero `01` silhouette bounds and row spans. Semantic head/torso joint positions are not inferred automatically from a 2D alpha mask.

## Exact source measurements

All numbers below are **visible source pixels**, not studs or collision dimensions. The ratio should inform the visual model without replacing the accepted physical body.

| Namespace / gfx | Meaning | Width × height |
| --- | --- | ---: |
| Hero `01` | Idle | 24 × 33 |
| Hero `05` | Locomotion / non-apex unheld jump branch | 32 × 28 |
| Hero `19` | Light punch form | 37 × 30 |
| Hero `1A` | Large uppercut form, including its second sprite list | 43 × 54 |
| Hero `1C` | Large punch form | 50 × 31 |
| Hero `1E` | Large boot form, including its second sprite list | 41 × 46 |
| Hero `32` / `33` | Boss appearance fear forms | 29 × 37 / 30 × 40 |
| Object `05` / `06` | Pig windup / strike | 34 × 31 / 40 × 28 |
| Object `09` / `0A` | Dragon normal forms | 26 × 32 / 29 × 23 |
| Object `0B` / `0C` | Dragon strike / light reaction | 26 × 31 / 24 × 20 |
| Object `12` | Boss Walker intro foot | 35 × 128 |
| Object `19` | Tall Walker upper body **without procedural legs** | 13 × 27 |

Hero idle visible bounds relative to its source anchor are X `−12..11`, Y `−21..11`, so its width/height ratio is `24/33 ≈ 0.72727`. The intro-foot height is approximately `128/33 = 3.88` idle-hero heights before its source camera/perspective transition. These are screen-space source measurements; they do not establish a universal 3D perspective scale.

The source `palette_chars` table has palette slots `[0F,0F,0A,1A]`, `[0F,0F,17,27]`, `[0F,18,28,20]`, `[0F,0F,16,26]` (main ASM line 36743). Player 1's initial palette is the first slot. Runtime palette-set objects can change non-player slots; the extracted object images use the initial character palette. Source palette codes are authoritative; displayed RGB approximates a 2C02 palette and is not a claim about an analog CRT. The original source has two playable sprite slots; a third playable hero remains an explicit adaptation, not a hidden third NES player palette.

## Extraction rules and checks

- Hero graphic bytes come from [`gfx/rash.asm`](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/gfx/rash.asm); sprite component positions come from [`spr_lists1.asm`](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/spr_lists1.asm), [`spr_lists2.asm`](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/spr_lists2.asm) and the pinned listing's literal inline object configurations.
- Source `gfx_ptrs` lookup is **frame − 1**, with frame 0 normalized to the first entry; the sprite-configuration tables are indexed directly by frame ID. Confusing them produces misassembled bodies even with correct tile bytes.
- Decode NES 8×8 2bpp tiles, source signed component coordinates, horizontal/vertical flags and first-sprite priority. Hero graphics load into tiles `01..10`; their remaining fixed components use the actual first-level graphics bank.
- Source special frames `1A/1E/4C/4D` continue into a second sprite list. Omitting that list loses the enlarged fist/boot.
- Packed `.4` inputs use their two leading repeat tags for zero and FF runs. Decode the source-declared tile count. The source reads past the short sprite0/common file boundaries into immediately adjacent source blocks; the extractor follows those real bytes instead of inserting invented padding.
- Dragon's shared handler temporarily writes `1C/1D/1E`, but its caller overrides them with **`09/0A`** for ordinary no-attack rendering. The visual extraction exposed this distinction; those shared intermediate frames are not presented as canonical Dragon flight.
- Latest run decoded 103 hero frame configurations and 11 selected object configurations. Native transparent PNGs and priority contact sheets were visually inspected. Thirty-two hero entries remain unrendered; the JSON records their reason. The exploratory full hero sheet can include level-specific fixed graphics whose bank context has not been verified; use the priority sheet and explicit bindings for the first route.

## Reproduce

From the repository root, using Python 3 with only its standard library:

```text
python research/canonical-visuals/fetch_pinned_source.py
python research/canonical-visuals/extract_source_frames.py
```

The first helper caches only the explicitly listed public source files under ignored `build/canonical-source`. The extractor writes this directory's generated PNG/JSON outputs, replacing only its own `hero-*.png` / `object-*.png` frame files. Source hashes are recorded in the catalog.

## Remaining work

Tall Walker's two procedural legs now have a separate [source renderer and measured pose catalog](TALL_WALKER_SOURCE.md). The boss arena's post-cut turret/reticle/glass components have a separate [source-bank catalog](BOSS_WALKER_SOURCE.md). Other family palettes/poses, complete final boss-arena background composition and later-level asset banks remain incomplete. The first-route boss intro's chronology is documented separately in [the animation source report](../2026-11-09-canonical-character-animation-source.md). These images do not establish live Roblox playback, collision compatibility, animation cancellation, multiplayer synchronization or production readiness.
