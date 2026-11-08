# Walker club: finite first-level source transfer

Read-only audit, 2026-11-08. Primary disassembly is pinned to `feos-tas/DisAssemble` commit `f1a43b69577246850d136473700a333b3cdfe93f`: [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [animation actions](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm), [level1 records](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm). No ROM, original implementation or assets are imported. This is static source tracing, not a natural-play or frame measurement.

## Death drop: one club, two object records

`object_tall_walker` handles types0x11/0x12. Its death-reaction branch [4608–4631](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L4608) requires a nonzero animation/reaction timer, animation ID0 and nonzero death timer. It sets animation ID to that death value before creating drops, preventing the same branch from emitting them every tick.

The branch calls the object creator twice: first creates type0x1B; the second passes through the drop helper and increments that type to0x1C. Dispatch5756–5757 names0x1B as the Walker-head handler and0x1C as its stick/leg handler. Thus the source establishes **one collectible club0x1C plus one separate0x1B object**, not two club pickups. Counts assume available object slots; no dynamic-population claim is made. Combat-death emission is confirmed; identical emission for every possible fall/removal path is not established.

The two first-level Walker appearances use the0x22 entrance wrapper and become0x12 in the same slot (8460–8475). Their final configuration byte0x10 becomes raw Life31 via the loader's OR0x0F (28889–28895). This does not imply the existing Brick Toads shared3HP profile already has species-Life parity.

## Ground item and pickup

The helper [4556–4602](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L4556) copies source position/direction into the dropped item and gives it motion. The0x1C update8676–8727 applies world physics, slowing/bouncing and rotating its presentation. It removes an object marked by its deletion flag. Exact flight, offscreen removal and all item-hit outcomes require a runtime trace before claiming parity.

Type0x1C has hit flags0x64: pickup bit4 and weapon bit0x20, with the generic collision flag0x40. B uses the contextual action selector7111–7118. The grounded-item branch3461–3483 checks depth, height/reach and no linker, then turns the hero toward the item and selects pickup animation8. It does **not** show the separate initial-facing test used for the fly or Pig grab.

Animation8 executes command E3 ([animation line75](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm#L75)). Its action16030–16046 rechecks the item, sets hero state bit0x20 and removes the ground object's type. This is **equipped weapon state**, not a carried enemy link; there is no additional enemy/body spawn or health/respawn write. A newly dropped0x1C can use this same pickup path again.

## Input and actual strike profiles

With weapon state0x20, the ordinary B branch [6970–6987](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm#L6970) first checks for an eligible fly; otherwise it selects club animation0x1A. A remains the jump input. The running branch can select a running strike separately. No manual B/A club toss/drop action was found in this inspected first-level input path; B should not be described as throwing an equipped club.

The club animation ([lines104–106](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm#L104)) requests hit parameter0x82. The action handler15778–15867 masks the hit profile to2, selects its height profile, and adds18 to the damage-profile index when the actual target is a hero. The decoded five-byte table rows are:

| Target | Profile / byte offset | Raw damage | Target X speed | Target Z speed | Attacker/hit byte | Reaction timer |
|---|---|---:|---|---:|---|---|
| Ordinary enemy | 2 /0x0A |16|0xF0|6|0x01|0x78|
| Hero |20 /0x64|16|0xF0|6|0x01|0xD4|

These are source bytes, not Roblox velocities or durations. Hero profile20 differs from existing Dash profile22, whose Z speed is4 and attacker/hit byte0x12. The club uses ordinary raw16 subtraction/nibble handling; the running-strike low-Life special branch is not evidence for changing club profile20 to21. A raw0 result without underflow remains distinct from confirmed death.

The accepted-hit state0x80 prevents replaying the successful animation effect repeatedly. The attack sequence does not decrement a club-use counter or clear weapon state. ED in its animation creates a brief effect object; it is not a verified weapon-break command. **No three/five-use durability limit is established.**

## Losing the club and boss introduction

The hero reaction dispatcher6458 onward distinguishes reaction timer below0x40 from at least0x40. The latter reaches6594–6595 and calls the drop helper. Consequently a light Punch reaction (profile18, timer0x1C) does not by itself require dropping the club; Dash22 or Club20 reaction0xD4 does. The helper clears state0x20 and emits another ground0x1C, allowing later pickup. Death reactions also enter the qualifying release path; direct actor removal/new appearance must not grant a replacement weapon in Roblox.

First-level boss introduction explicitly releases weapons: `object_level1_boss_noga`4123 calls the fear sequence, which4162 calls the drop helper. This provides a source-supported way to free hands for the boss's heavy ball. Source pickup writes no Life/respawn/protection counter. Shield authority and actor/owner/disconnection rules remain the accepted Brick Toads lifecycle, not facts established by NES networking.

The generic weapon attack target mask includes flag0x40, so source item interactions are not universally excluded. Exact knocked-item damage/deletion, object-pool exhaustion and all out-of-bounds persistence are **UNKNOWN** without a runtime trace; this finite transfer should not invent durability or projectile damage to fill those gaps.

## Chosen Roblox boundary

Implement one unique ground club per confirmed Walker death at a supported drop position. Keep it separate from enemy-role offers and actor counts. Validate a living current hero and same-group item at acceptance/effect; one item equips one hero once. F swings while equipped; a light hit cancels pending action but keeps equipment, a qualifying heavy reaction/death/actor change releases it, and boss introduction frees hands. No fabricated use limit or extra enemy ability is introduced.

Current ordinary NPCs retain3HP; mapping the club to calibrated2HP damage is an explicit Roblox adaptation. Hero club damage may use the verified raw16/profile20 arithmetic with separately declared physical/timing calibration. R remains the existing provisional heavy strike. Giving a reachable guardian ground ball priority and dropping the club on successful ball pickup is a disclosed Roblox integration decision to prevent a stuck interaction; it is not the original equipped-B branch. Item shape, placement/support search, ranges, animation times, impulses, source-gone cleanup and run/level isolation require implementation tests and engine evidence.
