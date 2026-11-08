# Healing flies: verified first-level transfer

Read-only inspection on 2026-11-07 of public primary disassembly, pinned to `feos-tas/DisAssemble` commit `f1a43b69577246850d136473700a333b3cdfe93f`. No ROM was executed; original assets/code are not imported into Brick Toads.

## Static inventory

[Level configuration, lines17–18 and30–33](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm#L17) contains six type0x0A records: two at progression trigger0x0150, then four at0x0440. The object dispatch identifies0x0A as `object_muhi`. This is a static record count, not a measured natural-play population or simultaneous count. These are food objects, not ordinary enemy slots.

## Input, capture and healing

[Main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm):

- Lines6859–6895 process B input. The ordinary unlinked branch reaches `loc_0_A5BC` (7111–7118), which asks `check_hitting` for an eligible contextual action. Type0x0A has hit flag8 (dispatch5739, flags5873).
- `muhi` (3431–3451) checks source depth/height/forward reach and facing, stores the fly slot and returns eating animation0x18. Source thresholds0x20/0x40/0x70 are engine coordinates; they are not Roblox studs.
- Animation command `make_tongue` (15706–15729) creates tongue object9 linked to the hero. `obj_tongue` (13675–13760) checks actual type0x0A overlap during extension. A catch converts that fly into a transient effect through `loc_0_DD6D` (15986–16012) and marks successful retraction with speed0xF8. A miss lacks that marker.
- On retraction, `muha_add_life` (13643–13668) adds **8 raw Life**, capped at **0x2F=47**, only after that successful-catch marker. It resets the hero animation and removes the tongue. A successful full-health catch still consumes the fly and caps health; there is no prior full-health exclusion in this inspected chain.

The transferable arithmetic is `newRawLife = min(47, oldRawLife + 8)`. It does not add a respawn, create a character or refill all health. Current Brick Toads normalizes hearts as `5 * rawLife / 47`; +8 raw is approximately0.851 normalized heart, so the UI must not promise exactly one heart.

## Finite implementation proposal

Add two flies after the early ground encounter and four before the guardian approach, preserving the two/four order in original 3D geography. The existing F/touch primary action can show a contextual tongue action when a facing fly is in reach. Server validates active hero/actor/attempt/epoch/sequence, selects the target itself, and consumes each food instance once for its group/run. No enemy-role offer or client health value is introduced.

Roblox placement, hovering path, distances, capture duration, tongue mesh/effect and cooldown are explicit original calibration. Exact NES frame timing, flight AI, occlusion details, dynamic spawn/reappearance behavior and natural-run capture traces remain UNKNOWN here. Current-player/offline/reaction/death rules must use the existing game's authority; this note does not establish their original NES equivalents.
