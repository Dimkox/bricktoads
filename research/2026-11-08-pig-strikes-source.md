# Pig strikes and late running approach

Primary static audit on 2026-11-08, pinned `feos-tas/DisAssemble` commit `f1a43b69577246850d136473700a333b3cdfe93f`: [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [animation data](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm), [level1 records](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm). No ROM or original assets/code are imported. Source bytes and branch conditions are separated from Roblox distances/timing.

## Standing attack selection

Pig update [16730–16792](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L16730) routes linked, reacting and dying bodies away from normal attack decisions. The target-decision branch16932–16962 excludes a target marked dead/out of lives, heavy-damaged or linked. It periodically evaluates relative position; it does not apply damage merely because a target is nearby.

For Pig type0x0B, `loc_0_E3F2`17066–17107 has a near-X attack window and a closer reorientation region, with source depth alignment. For a non-running Pig at the actual attack choice, `loc_0_E426`17096–17107 reads the **selected target's raw Life low nibble**:

- `(Life &0x0F)>=4` selects animation0x28, the short hop/jab.
- `(Life &0x0F)<4` selects animation0x2A, the heavier jump strike.

This is not a comparison against four normalized hearts or total Life16. For example raw47 has low nibble15 and selects0x28; raw19 has nibble3 and selects0x2A.

Animation0x28 (`move_jump_mini?`, [line129](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm#L129)) executes E2 with base profile0. Animation0x2A (`udar_jump_hit2?`, line128) executes E2 with base profile2. Animation choice happens before the effect. E2 later calls the real hit selector against current geometry (15778–15850); it does not guarantee hitting the originally selected actor or reselect an animation based on that actor's newly changed health. A miss does not become direct target-locked damage.

## Late running approach and its reset

The far/approach branch [17126–17143](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L17126) can set running flag0x10 only after the aligned-depth path reaches the outside-near-window case, when both conditions hold:

- `(PigFlags &3) | some_anim_tmp?` is nonzero.
- `(PigXlow XOR RandomValue1) &0x1F` equals0.

This is a conditional source byte predicate, not proof of a uniform one-in32 wall-clock process. With a running Pig entering the attack window,17077–17081 selects animation0x40 instead of the standing health-dependent choice. Its animation (`udar_i_prijok`, line130) adds jump motion and E2 base profile4.

`some_anim_tmp?` is written by the palette/event object at [9212–9230](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L9212), from that object's configuration parameter. In level1, palette records at progression0x0100 and0x0200 provide1. All nine Pig initial final bytes are0x00/0x10, hence their initial low-two flag bits are0. Running is therefore not licensed for those early Pig records by their own flags alone; the later source enable matters.

Running is removed by the speed-limit helper6002–6012 when the target becomes invalid16919–16929 or depth misalignment requires stopping17058–17063. More directly, writing an attack/idle animation [15527–15538](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L15527) masks flags with0xEB, clearing running0x10. The approach is not an endless damage aura or permanently latched run state. Source running movement sets X-speed byte0xA0, while ordinary approach uses other bytes; these are not studs/second.

## Effect profiles and reactions

E2 adds18 to the base profile when its actual victim is a hero (15842–15850). The decoded five-byte damage table gives:

| Pig action | Base profile vs ordinary object | Hero profile | Hero raw damage | Hero X/Z speed bytes | Hero reaction byte |
|---|---:|---:|---:|---|---|
| Standing jab0x28 |0, raw2|18|4|0x34 /0|0x1C|
| Standing heavy0x2A |2, raw16|20|16|0xF0 /6|0xD4|
| Running hop0x40 |4, raw16|22|16|0xF0 /4|0xD4|

The general low-Life finisher substitution [15829–15839](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L15829) requires attacker animation0x16 specifically. A Pig running hop uses0x40, so it **does not switch hero profile22 to21/raw255** at raw Life below16. It still uses raw16 and the ordinary underflow/death rule. The standing heavy similarly keeps profile20.

Hero profile18 is light and can recover raw Life's low three bits through the existing end-reaction OR7 path5955–5984. Thus raw47→43 can recover to47; claiming every jab permanently removes one heart would be false. Heavy20/22 has the larger reaction, matching the source heavy-state/drop branch. A successful hit uses the existing profile impulse; lethal subtraction and exact arithmetic raw0 remain distinct. Source hit order and repeated hits during light reactions are not fully transferred by this static trace; current Roblox Session reaction immunity remains a disclosed boundary.

## Finite Brick Toads adaptation

Implement standing jab/heavy for ordinary Pig primary attacks, selecting and freezing the action from server-observed target Life at acceptance, then testing the effect against current hit geometry. A human-owned Pig uses the same primary standing branch without another button or new deferred ability. Preserve existing body ownership, takeover closure, accepted-action/offline completion and one-life history.

Only the five later Pig actors in Courtyard/Watchforge (zone>=3) receive an NPC running-approach decision; the four early Pig actors do not. This preserves the static event order, while mapping palette enable0x0100 onto new geography is explicit calibration. Decision cadence0.1seconds, Bernoulli one-in32 chance, depth alignment2studs, outside attack range5studs, run speed16 versus walk9 and all windup/window/cooldown/impulse values are Roblox calibration. They are not measured source units or random traces. Running has a finite transition into the fixed profile22 hop and clears on interruption/ownership change; no player-enemy rush control is added.

Keep provisional ordinary3HP and existing species silhouettes; this slice does not claim full Pig AI, precise source health, full close-range retreat behavior or natural-run population. The previous universal NPC Dash chase is not an acceptable stand-in for all three verified profiles. Dragon projectile behavior is outside this slice: the fireball emission found in the inspected input branch is for a player already linked to a mount, not evidence that an unmounted NPC Dragon should emit it.
