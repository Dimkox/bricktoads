# Boss Walker: arena camera and sprite components

The first-level boss uses a special camera-relative composition. The pinned source shows an intro mechanical leg, followed by a perspective/camera transition, foreground cannons, a reticle and damaged-glass effects. These references do not establish the unseen complete robot body or its rear view.

- [Intro foot before the cut](boss-intro-foot-source-reference.png): object graphics `12`, 35×128 visible pixels.
- [Arena turret, reticle and glass](boss-walker-arena-component-reference.png).
- [Source sprite configuration and bank metadata](boss-walker-arena-component-catalog.json).

## Bank and palette transition

At intro counter `E0`, `sub_6000_8E74` changes the camera to source X `06C0`, Y `0008`, repositions the two source player slots, loads graphics and palettes, and switches to the boss presentation. Chronology and fear graphics are traced in [the animation source report](../2026-11-09-canonical-character-animation-source.md).

The graphics calls are concrete, not inferred from a screenshot:

| Source call | Tile range | Resource |
| --- | --- | --- |
| Bank 4 archive `0C` | `2A..69` | `level1_boss.4`, 64 source-declared tiles |
| Bank 1 archive `36`, part 1 | `57..67` | First 17 decoded `level4_obj.4` tiles |
| Bank 1 archive `36`, part 2 | `68..72` | 11 raw `l1_boss2.chr` tiles |
| Bank 1 archive `38` | `B6..BD` | First 8 decoded `level4_obj2.4` tiles |

The `.4` decoder follows the real adjacent `zastavki_bkg.4` bytes when the source-declared boss transfer exceeds the short `level1_boss.4` block. No fabricated zero padding is inserted. The palette call has `flag_boss_1=1`, so its sprite palette offset is `06`, resolving to `byte_6000_A2FD`: `[0F,0F,06,16, 0F,0F,16,26, 0F,16,26,36, 0F,0F,00,20]`. Normal first-level `palette_chars` must not be used for this post-cut state.

## Visible components and source placement

| Object graphics | Meaning visible in decoded source | Measured size |
| --- | --- | ---: |
| `10` | Cannon / turret barrel | 31×24 px |
| `11` | White reticle | 24×24 px |
| `C7` | Cracked-glass overlay | 40×40 px |

Two source type-`0E` turret records carry initial endpoint bytes `26` and `E1`. Their handler selects graphics `10`, derives facing from bit `40`, moves Z toward `50`, and positions X/Y relative to the camera through `level1_boss_sub`. Recoil counter `Objects_cnt2` changes that camera-relative position. Type `0F` selects graphics `11`; its source endpoint byte is `84`, and its counter/animation state also controls camera shake and a five-sprite indicator strip. The cracked-glass object `63` uses its saved position and graphics `C7` for a finite timer.

The renderer therefore supplies a first-person-style cannon/reticle presentation. A generic stone humanoid boss appearing by a fade does not reproduce these source components or the intro sequence. For a 3D version, any unseen chassis, 3D rear anatomy and adaptation of this camera composition must be identified as authored reconstruction rather than measured source geometry.

Source paths: intro setup 34374–34445; turret logic 4281–4379; main boss logic 4401–4483; indicator drawing 33727–33782 and its data 33816–33823; graphics sets 22299–22310 and 29232–29235. [Pinned main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm).

## Reproduce and limits

```text
python research/canonical-visuals/fetch_pinned_source.py
python research/canonical-visuals/extract_source_frames.py
python research/canonical-visuals/extract_boss_arena.py
```

The components were decoded with the actual source bank swaps and visually inspected. This is not a complete emulated arena frame. The final nametable/background composition, precise full-state projection/layout, timing under lag and live Roblox camera/rendering remain unverified.

## Pimple intro boundary

The source's `pimple.4` is 21 decoded tiles. Archive `word_2000_CAF4` places it at PPU `1700` after the small spaceship graphics; archive `word_2000_CB0A` places it at `0700` after 18 tornado tiles. Those are cinematic contexts, not a third playable NES sprite slot. A specific final layout and palette have not been traced here, so this work does not assign Pimple a guessed body proportion or gameplay palette.
