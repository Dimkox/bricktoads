# Hero grab, carry and throw: finite primary-source slice

Read-only audit on 2026-11-08. Primary source is `feos-tas/DisAssemble`, pinned commit `f1a43b69577246850d136473700a333b3cdfe93f`. The inspected files are [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [animation actions](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm), and [first-level records](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm). No ROM, assets or original code is imported into the game. This is a static code trace, not measured natural-play or frame timing.

## Chosen slice and correction to the initial hypothesis

Choose **a hero lifting the existing ordinary Pig body, carrying it and manually throwing it**. A universal “first stun it” or low-health threshold is not established by this path. The close-grab selector has no Life comparison. The normal/light-reaction target can qualify; the heavy-damaged state is explicitly routed away from this grab choice. Requiring an invented HP threshold or claiming that heavy stun is mandatory would misstate this source.

The alternative Walker leg→club chain is real but adds independent spawning/pickup/weapon damage and break/drop details. The Pig chain establishes body identity and state transitions more directly, so the club is not part of the recommended finite implementation.

## Entry and action selection

- Main [6859–6895](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L6859): B hold/tap drives the action branch. With ordinary hands free, not using the running/weapon branch, `loc_0_A5BC`7111–7118 calls the contextual target selector. No separate grab button is needed in this source path.
- `obj_hit_flags_cfg`5873–5875 gives Pig type0x0B flags0x53, including grabbable bit2. Generic selection3163–3190 skips missing types, protected linked targets and nonzero death timers. This includes lethal underflow states, even if raw Life is0.
- `loc_0_8B82`3246–3291 and `loc_0_8C16`3336–3414 perform source depth/height/front reach checks. The close branch tests grabbable bit2, target linkage and grounded hero (`Objects_Z_floor,X==0`) before returning animation0x0A. Target `Objects_Linker_ID` must be0; the target's linked-object bit0x40 must be clear. `loc_0_8BB8` routes state0x40 (`damaged_heavy`) away from that grab choice. Hero animation0x5E is separately excluded.
- Reach is based on source object widths, hit-Z profile, signed X deltas and 6502 carry state. Source values such as0x12/0x24 are not a measured Roblox distance or a symmetric world-space radius.

## Capture retains the same body

[Animation table lines5–7,75–78](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm#L75) maps0x0A to the enemy pickup sequence, which eventually executes command E4;0x0C is the throw sequence and executes E5. Main action dispatch15596–15601 maps these to `sub_0_DDFB` and `anim_damage_linked`.

`sub_0_DDFB`16085–16119 rechecks a current grabbable target at the actual animation action, clears its animation, gives it lift motion and enters `loc_0_DDD5`16055–16074. That writes reciprocal holder/held slot references (`slot+0x81`) to **the existing actor slots**. No enemy creation, life reset or replacement body occurs in this operation. A target that moved away before this action is not automatically acquired.

Pig update `object_Psyko_Pig`16730–16747 sends linked pigs to the existing held-body movement helper instead of normal AI. The helper6137–6142 uses the reciprocal link and `loc_0_B06B`8778 onward;8834–8869 derive carried height from the holder's current animation. The standing/walking/jumping presentation includes held-object variants (8202–8204,8353–8367). These confirm actual carry, not just an interaction icon. No independent carry timeout or Pig self-escape command appears in these inspected held-body branches. That does not establish every game's linked-object race or justify inventing a mandatory release timer.

## Manual throw and damage

B while an ordinary object is held takes the negative linked-object branch at6995–6997 to `loc_0_A5AC`7096–7105. Outside the boss-specific branch this selects animation0x0C. A input remains jump:7659–7755 permits a grounded, idle carrier to jump using a different source lift value; it is not the throw button.

At E5, `damage_linked_object`16136–16208 resolves the exact linked target. An ordinary Pig takes the ordinary-enemy branch `loc_0_DE91`: **damage profile17, byte offset0x55**. Its table row16614 is target horizontal speed0xF1, vertical speed6, raw damage**4**, reaction timer0x80. The handler sets heavy-damaged state0x40 and clears both links. Damage occurs when this throw action executes, before subsequent body flight; this trace does not establish a second collision-damage projectile.

General damage16460–16588 subtracts the profile damage, applies the existing nibble-boundary rule, and sets death timer0xC0 on subtraction underflow. Raw0 alone is not that death flag. Examples for damage4:31→27;19→15;4→0 without underflow;0→underflow/death. Profile17 must not be confused with club profile2, whose raw damage is16. This audit initially hypothesized16 for throw, then decoded all five-byte table rows and corrected it to4 before implementation.

The first-level loader28889–28895 initializes Life as the record's final byte OR0x0F. Thus the three ambush Pig records start raw15; five direct Pig records and the entrance Pig start raw31. Their conversion into ordinary Pig type0x0B at9620–9657 and16834–16860 preserves the same slot and Life. These are source initializations, not confirmation that the current provisional three-heart Brick Toads profile already implements species health.

## Interruption, limits and Roblox decisions

The source has release-on-holder-reaction handling:5940–5954 invokes the linked-target damage/release path for the qualifying reaction before applying extra release motion. Ordinary heavy hits to a linked victim can also unlink it (15845–15867). These are not evidence for unlimited safe carry or immunity. Exact timing and all death/fall/link races are not measured here.

Roblox should validate owner/actor/attempt/epoch/sequence, select a same-group living Pig itself, recheck at capture, and maintain exclusive reciprocal references to the same Model/actorId. Human enemy control, offline behavior and reconnect identity have no NES equivalent; preserving the current ownership and one-life history is a Brick Toads requirement. It must not hand that body to AI or create a new enemy. Geometry, carry offset, windup, duration, recovery and input labels are explicit Roblox calibration.

The chosen implementation retains the existing provisional three-heart ordinary enemy profile and maps this source raw4 throw to the existing `punchDamage=1`. That conversion is **Roblox calibration**, not a species-Life parity claim. Grounded facing grab range3.3studs, grab windup0.12seconds, recovery0.85seconds and throw velocities26/16studs per second are also explicit calibration. Damage is charged once at throw release and the physical arc has no additional collateral hit. No new enemy attack, buff or automatic self-escape is inferred from the hero grab action.

A practical finite slice is hands-free grounded hero→close qualifying Pig→capture recheck→same-body carry→manual throw/reaction→ordinary damage/death lifecycle. Leave club pickups, throwing other heroes/species, collateral flying-body damage and extra enemy attacks outside this slice. The user's deferred enemy abilities are unaffected: this is a hero action against the existing role.
