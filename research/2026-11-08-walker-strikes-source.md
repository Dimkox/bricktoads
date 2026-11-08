# Walker primary strikes

Static primary-source audit on 2026-11-08, pinned `feos-tas/DisAssemble` commit `f1a43b69577246850d136473700a333b3cdfe93f`: [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [animation data](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm), [level1 records](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm). No ROM, original implementation or assets are imported. Source coordinates, bytes and animation instructions are not Roblox studs, seconds or art.

## Actor and normal-decision guards

`object_tall_walker` handles types0x11/0x12 ([4608–4817](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L4608)), distinct from the level1 boss. Its nonzero reaction/animation timer takes the reaction branch; nonzero death timer takes the death branch. A current nonzero animation ID is advanced rather than replaced by another normal attack (4618–4682). Normal selection therefore occurs outside these own-body states. The separate animation-pointer/countdown field can also defer normal selection (4697–4705).

The normal branch calls `sub_0_E317` ([16932–17054](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L16932)). For its selected hero, the sign bit of death timer/out-of-lives, state bit0x40 (heavy damage), or a nonzero linker makes `tmp_var_1A` nonzero and requests another target. Light reaction alone is not this heavy-state exclusion. The periodic decision condition is `(objectSlot XOR FrameCounter)&7 ==0`; this is not a measured Roblox decision interval.

The Walker then requires `tmp_var_1A==0`, `tmp_var_19==0` and `tmp_var_17==0` (4708–4713). The helper derives the latter from the source Y-coordinate difference, i.e. depth alignment, and halves the nonzero steering value specifically for types0x11/0x12 (16966–17008). There is **no separate target Z-height or grounded test in this decision branch**. Actual height/facing/depth/range collision is checked later by E2; do not describe the decision as guaranteeing a grounded victim or guaranteed hit.

The two combat Walker records are the0x22 wrappers at [level-data lines9 and14](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm#L9). The wrapper changes the same slot to0x12 (8455–8475). Their last byte0x10 becomes raw Life31 through OR0x0F (28889–28895). The earlier0x22 record with parameter0x55 is handled by the separate warp-marker branch8407–8430; it is not an additional combat Walker. Existing Brick Toads ordinary3HP remains a provisional profile unless separately migrated.

## Near band and close-range movement

`loc_0_94FF` / `loc_0_952F` ([4708–4748](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L4708)) first forms a two-byte value from the helper's X difference using ADC0x60/ADC0. The high result must be zero and its low result `t` must satisfy `0x40<=t<0x80`. Within this near band, `0x50<=t<0x70` takes the close-range reorientation path rather than starting an attack. These literal predicates retain the source carry/arithmetic context; they are not an exact stud-distance formula.

The close branch writes direction from `(deltaXhigh XOR0x80)&0x80` and proceeds to the ordinary Walker gait at0x9558. Thus it is not simply a face-toward-target idle guard: the direction is opposite the target and still participates in movement. The gait updates speed, separate leg counters and body geometry (4759–4809); it is not transferred by merely setting a close-range dead zone. An idle inner safe zone without a way to move out would leave the Roblox Walker harmless at touching distance. Full source gait, exact inner/outer coordinate windows, random retreat countdown and its natural encounter timing are outside this finite strike slice.

## Frozen animation choice and effect

At `loc_0_952F` (4735–4747), a valid noncentral attack reads the **selected target's raw Life low nibble**:

| Condition | Animation | Animation data / E2 parameter | Ordinary-object profile | Hero profile / raw damage |
|---|---|---|---|---|
| `(Life&0x0F)>=4` |0x3C|`byte_3000_E5A0`, line140 /0x40|0 / raw2|18 / raw4|
| `(Life&0x0F)<4` |0x3A|`udar_i_podkid?`, lines137–139 /0x82|2 / raw16|20 / raw16|

The animation-pointer table maps0x3A and0x3C at [lines30–31](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm#L30); effects are at [137–140](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm#L137). Neutral names `WalkerLight` / `WalkerHeavy` avoid attributing an unverified anatomical animation to new art. Raw47 selects light; raw35 selects heavy. This is not a comparison to four hearts or total Life16.

E2 masks its parameter with0x3F for the damage-table row and uses the upper bits for the height-collision index: light0x40 has height index1, heavy0x82 index2 ([15778–15795](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L15778)). These high bits are not extra damage. The eventual `check_hitting` evaluates current actors/geometry; a hero victim adds18 to the base profile (15807–15850). The original selected actor can move away, another actor can be hit, or the effect can miss. Healing or target changes during the animation do not rewrite the already chosen animation.

The source table ([16591–16619](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L16591)) gives:

| Profile | X speed byte | Z speed byte | Hit/attacker byte | Raw damage | Reaction byte |
|---|---|---|---|---|---|
|0, ordinary light|0x30|0|0|2|0x3F|
|2, ordinary heavy|0xF0|6|1|16|0x78|
|18, hero light|0x34|0|0|4|0x1C|
|20, hero heavy|0xF0|6|1|16|0xD4|

Neither Walker animation is0x16, so neither satisfies the generic low-Life finisher substitution15829–15839. The heavy remains profile20/raw16 even when the actual hero has raw Life below16; do not route it through Dash22 or finisher21/raw255. Light18 uses the existing end-reaction OR7 recovery5955–5984; heavy20 uses heavy reaction/drop behavior. Actual zero without subtraction underflow and confirmed death remain distinct under the existing raw-Life arithmetic. Session's current reaction immunity is an acknowledged transfer boundary rather than a complete NES combo claim.

## Finite implementation boundary

Replace the existing primary action for the same two Walker bodies with `WalkerLight` / `WalkerHeavy`, freezing the chosen action/tuning at server acceptance and using effect-time geometry. AI chooses an eligible hero; an owned Walker uses its existing primary input with the same standing raw-Life branch. Keep one body, health/owner/life ledger, interrupt/carry/death/closure rules, accepted offline action and the existing single club drop on confirmed combat death. No additional enemy-player button or ability is introduced.

The chosen NPC adaptation attacks within2.5–6.5studs and backs away below2.5 at7studs/second through a supported-edge movement helper. This is a finite adaptation of the source inner-window movement, not the original gait/cadence/leg root motion or coordinate windows. A human-owned Walker retains manual movement and its existing F primary; no automatic retreat or new input is added. There is no new target-grounded restriction.

The NPC band/backstep, effect reach7.5/width3.25/height4, light/heavy windup0.4/0.65seconds, cooldown1.0/1.6 and recovery pose0.2/0.35 are **Roblox calibration**, not source measurements. Ordinary damage1/2HP is calibration against the retained3HP profile, while hero profiles18/20 may use the verified raw arithmetic. New original readable poses, collision dimensions, safe-edge movement and all network/ownership behavior require implementation/engine checks; source code/assets are not copied.
