# Campaign boss mechanics: measured source and original 3D tuning

Scope: the five remaining encounters implemented by `CampaignBoss.lua`. The existing first guardian and `GuardianPattern.lua` are unchanged. This note is a static source audit and native Luau verification, not an emulated NES victory or Roblox engine acceptance.

Primary source is the locally cached `build/canonical-source/main.asm`, `levels_cfgs2.asm`, `source.lst` and `symbols.map` from [feos-tas/DisAssemble at f1a43b69577246850d136473700a333b3cdfe93f](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads). The read-only Jira receipt `build/full-mechanics-jira-2026-11-09.json`, BT-38, independently records the starting bytes and remaining unknowns.

## Measured facts

| Boss | Initial Life | Source behavior used |
| --- | --- | --- |
| Big Blag | FF / 255 | `object_big_blag` and `big_blag_and_electroball_sub`, main.asm:13055–13204. Life comparisons against C0 and80 affect jump/drop selection. |
| Robo-Manus | 0F / 15 | Configuration `level7_cfg` type7D. `object_robu_manus`, main.asm:13457 onward, calls `sub_0_CD7D`; landing, shooting animation88 and jumping are separate branches. |
| General Slaughter | FF / 255 | Configuration `level9_cfg` type7C. `object_general_slaughter`, main.asm:13345 onward, calls `sub_0_CD7D`; speed, turn delay and jumping are distinct state variables. |
| Buzzball | CF / 207 | `level10_cfg` type7A. `electroball_change_to_phase2`, main.asm:14857 onward, writes type7B without writing Life. `object_electroball_phase2`, main.asm:12981 onward, branches on Life's high bit. |
| Dark Queen | 0F / 15 | `level13_cfg` type7E. `object_dark_queen` and `sub_0_D40F`, main.asm:14307 onward, separate an ordinary attack/movement branch from accelerating rotating movement. |

`objects_some_anim` resolves to RAM0583 in symbols.map:323. The spawn loader writes configuration byte9 to this field and derives Life from byte10 OR0F (main.asm:28888–28895). These three reaction-progress bosses start with byte9=00 in the referenced configurations.

The common `sub_0_CD7D` (main.asm:13299–13340) checks the damage underflow/death flag. If RAM0583 is already at least F0, it takes the defeat transformation branch. Otherwise it clears that flag, adds0C to RAM0583 and calls `some_state_upd` (main.asm:5977), which ORs Life with07. Consequently the implemented progression reaches F0 after20 nonterminal underflows; the following underflow is terminal. This is a static derivation from these branches, not an observed complete source fight. General Slaughter's initial FF Life must first be spent; it does not start with the same damage state as Robo-Manus or Queen.

The common damage arithmetic in `gen_damage_effects`, main.asm:16538–16569, subtracts the selected damage byte. Borrow marks an underflow. Without borrow, crossing a high-nibble boundary rounds the new low nibble up to0F. In particular FF minus FF becomes0F after this rounding and does not by itself select the underflow branch. Recovery OR07 cannot restore an already crossed high-nibble boundary. This is not linear HP and is not one hit per heart.

## Roblox tuning and evidence limits

The module implements finite tell → attack → recovery state machines with a separate hit-reaction state. Big Blag has hop and belly drop, Robo-Manus a three-bolt burst and jumping slam, General Slaughter a swept horn charge and frontal headbutt, Buzzball a rolling sweep and bounce, Queen a frontal sweep and a subdivided curved spin. An active attack is armored; Ready and Recovery expose the actor, and a light reaction accepts a follow-up combo before its recovery deadline. All seconds, studs, hitbox sizes, shot spread, projectile speed, curve, attack ordering, input bindings, vulnerability windows and the mapping to existing trusted damage actions are original Roblox calibration. Their exact NES equivalents have not been measured.

Incoming named moves reuse the existing ordinary-target action profiles (2/4/8/16/255 byte damage); outgoing attacks use the existing Session action profiles, including source hero damage, impulses, shields and lifecycle. Those mappings establish playable consistent arithmetic, not proof that every named move reaches exactly that source boss collision branch. The generic arithmetic and source progress are implemented separately so further measured per-boss mappings can replace tuning without treating Life as ordinary HP.

The existing `Punch` input calls the same phase/attack-serial decision helper as NPCs and reaches both attacks. Big Blag's first phase selects Hop until its measured Life threshold is crossed. A trusted internal `Dash` call can directly select the second action for isolated tests; no extra ordinary-enemy button is required or introduced. An assigned human receives the same actor, raw Life, progress, recovery and collision profiles. Offline ownership blocks new commands; already accepted attacks and bolts continue. There is no midfight takeover. Boss hit selection rechecks authoritative world range, frontal hit geometry and visibility; invalid actions, dead attackers and invalid positions cannot change resources. Bolts and charges use swept contact. Bolts stop on solid geometry while retaining a valid hit on a body before the wall. Spin subdivides its curved path. Boss motion is bounded to its authored arena. Effects and IDs are owned by the encounter/world, and close/defeat removes only that encounter's projectiles.

Buzzball's direct Chase → Ready handoff changes neither actor nor Life. In the integrated campaign the traversal component supplies the chase; the battle constructor receives its same preserved207 Life state. The route does not earn victory from elapsed boss time.

## Verification

`tests/run_campaign_bosses.luau` contains24 native Luau contracts, using real `Session`, `Combat` and `RunLifecycle` for damage/resource checks. They cover valid and invalid attacks, byte arithmetic and recovery, both Big Blag thresholds, all reaction-progress terminal boundaries, Buzzball identity/Life handoff, every first attack and finite recovery, light combos, frontal/blocked geometry, large-frame swept collision, landing area and height misses, curved-spin misses, ordinary-enemy friendly fire, all five human/NPC profile parity, offline in-flight continuation, encounter isolation, the raised campaign platform's bounds/landing height, physical knockback containment in both controller modes, projectile wall blocking and both attacks through repeated Punch. The boss-only containment is original 3D arena tuning: it constrains X/Z and the standing plane without healing, changing progress or winning the fight. Chase retains its own route. Engine presentation and physics remain adapter doubles in these tests. Natural emulator victories, full source phase/1P/2P parity and physical Roblox multiplayer acceptance remain unproven.
