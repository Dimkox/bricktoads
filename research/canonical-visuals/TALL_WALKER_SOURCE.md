# Tall Walker: source legs and proportions

This extends the upper-body-only `19` image with the actual procedural leg renderer in the pinned [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm). It evaluates prepared safe-screen snapshots of source counters; it is not a natural gameplay trace or a Roblox animation acceptance.

- [Prepared gait / size references](tall-walker-procedural-leg-reference.png)
- [Heavy attack `3A` references](tall-walker-heavy-attack-reference.png)
- [Light attack `3C` references](tall-walker-light-attack-reference.png)
- [Every component and attachment coordinate](tall-walker-procedural-leg-catalog.json)
- [Independent literal ASM-path verification](tall-walker-source-verification.json)

The hexadecimal contact-sheet captions are **pose indices in this catalog**, not source graphics frame IDs. Each JSON row identifies the source object type, counter or attack-stream value and source advance. The body remains graphics frame `19` throughout these poses.

## The visible construction

The ordinary high Walker is source object type `11`; type `12` is the shorter form. They share the narrow upper body, source tiles `C9..CF`, whose visible size is 13×27 pixels. They do not use humanoid thighs, knees and shins.

Each leg is a straight segmented shaft:

| Property | Type `11` | Type `12` |
| --- | ---: | ---: |
| Sprite segments per leg | 8 | 4 |
| Vertical step per segment | 8 px | 8 px |
| Source initial vertical bias | `C8` (−56) | `E8` (−24) |
| Horizontal increment | signed endpoint delta / 8 | signed endpoint delta / 4 |
| Normal endpoint-counter excursion | ±24 px | ±16 px |

The two shafts start at `X_shadow−3`; the second starts two pixels above the first. Fractional X increments use an 8-bit accumulator and carry. Depending on slope magnitude, all shaft pieces select tile `D0`, `D1`, `D2` or `D4`; the final piece is replaced by foot tile `D3`. Negative slope changes the horizontal flip flag. Rendering order preserves the source's first-sprite priority where the legs overlap.

`objects_some_anim` and `Objects_cnt3` are absolute source X endpoints. During the ordinary counter-driven gait they become body-X plus/minus `Obj_various_cnt`. The object logic turns this counter at ±24 or ±16; the renderer interpolates the shafts between the body attachment and those endpoints. It also derives a temporary visual body height from the final shaft slope, so the upper body shifts slightly with the pose.

Relevant source paths: object logic 4608–4839; sprite drawing 33499–33639; slope-to-tile helper 34358–34370; shaft tile table 33284. These are coordinates of the pinned file, not the older research cache.

## Measured full silhouettes

The prepared anchor is `(X_shadow=128, Y_shadow=200, Z_floor=0)`, with no death flash, camera clipping or OAM exhaustion. Bounds include both legs and the body.

| Prepared pose | Visible width × height | Relative to hero idle height 33 px |
| --- | ---: | ---: |
| Type `11`, coincident endpoints | 14 × 89 | 2.697 |
| Type `11`, endpoints ±24 | 50 × 87 | 2.636 |
| Type `12`, coincident endpoints | 14 × 57 | 1.727 |
| Type `12`, endpoints ±16 | 32 × 54 | 1.636 |

The neutral source body anchor is Y−57 for type `11` and Y−25 for type `12`; their shaft starts are Y−56/−58 and Y−24/−26 respectively. JSON `headAnchor`, `legStarts`, component coordinates, integer/fractional steps and visible bounds allow a 3D author to preserve the silhouette without guessing a humanoid knee position. The coincident-endpoint pose is a prepared reference, not a claim that the natural AI stands there for a particular duration.

## Attack geometry

Attack streams `3A/3C` do **not** select successive full-body sprites. The object logic subtracts `18` from each stream's displayed value and transforms the resulting endpoint by direction. Its final renderer then resets body graphics to `19`.

- `3A` heavy: first endpoint moves by the signed transformed stream delta; the other moves by arithmetic floor of negative half that delta.
- `3C` light: first endpoint follows the stream delta; the other is held at body X.

The contact sheets cover 29 distinct prepared attack-stream poses plus six size/gait cases. They retain the source's body and shaft graphics. The stream's X/Z speed commands, hit events, target selection, reactions and whole-body world motion belong to the source action/physics logic and are not proved by these static pictures.

## Verification and reproduction

```text
python research/canonical-visuals/fetch_pinned_source.py
python research/canonical-visuals/extract_source_frames.py
python research/canonical-visuals/extract_walker_legs.py
python research/canonical-visuals/verify_walker_source.py
```

The verification helper interprets the actual arithmetic, branching, calls and sprite-write instructions from `tall_walker_sprites` through its leg helpers, stopping before the generic upper-body renderer. It compares every emitted leg sprite and the restored body anchor with the separately transcribed renderer: **35/35 PASS**, 387–653 interpreted instructions per pose. It separately runs `sub_0_95BA` and the actual post-call attack branch for **58 left/right endpoint mappings**. It is deliberately not a general 6502/NES emulator. Death flashing, clipping, sprite-budget exhaustion, natural gait timing and live Roblox playback remain outside this check.

## Pure runtime contract

[CanonicalWalker.lua](../../src/server/gameplay/CanonicalWalker.lua) provides source-pixel presentation data without changing a World, actor, health, AI, movement or damage rule:

```lua
local pose, reason = CanonicalWalker.pose(0x11, firstDelta, secondDelta)
local offsets, reason = CanonicalWalker.attackOffsets(0x3A, streamValue, facingLeft)
```

`pose` accepts source types `11/12` and signed-byte integer endpoint deltas. It returns a fresh table with `units='sourcePixels'`, `bodyGraphicsFrame=0x19`, `headAnchor`, `legStarts`, two `legs` (segment count, integer step, fractional byte, slope, and exact sprite components), `bodySprites`, and ordered combined `sprites`. Coordinates use the same normalized safe-screen/zero-ground-Z reference as the independent fixtures. The caller applies the chosen 3D scale, ground translation, source action clock and current actor identity; unsupported source clipping or slope cases do not acquire guessed geometry.

`attackOffsets` supports only verified source display values from `3A/3C` and an explicit boolean `facingLeft`. It returns fresh `{firstDelta,secondDelta}` values in source screen/body-X axes, already reflected by source direction. Source byte commands and their parameters are not display values. The caller must not reflect these deltas a second time while mapping axes into a 3D model.

Malformed arguments return `nil,'INVALID_INPUT'`. Unsupported source families, slopes, animations or display values return `nil,'UNKNOWN'`. Private source constants are frozen; returned tables are independent between calls. There is no global actor cache.

`tests/run_canonical_walker.luau` verifies 35 source-CPU pose fixtures, 58 attack mappings, upper-body placement, bounded refusal and cross-call mutation isolation: **6 behavioral groups PASS**. Its generated goldens are emitted directly by the source interpreter; they are not computed by the production module or copied from its renderer results. The module and three Luau test/fixture files compile. The model/World binding and live 3D joint inspection remain separate work.
