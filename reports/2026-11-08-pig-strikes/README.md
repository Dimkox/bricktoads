# Pig standing strikes and running approach — 2026-11-08

Pig now has a short jab, a slower heavy strike and a later NPC running approach, rather than sharing the same unconditional Dash as the other prototype species. The server chooses an action at acceptance and preserves it until the actual geometrical hit test. Each action has an original windup/recovery pose; running has a distinct gait. A human Pig keeps the existing F primary and the same body/health/owner. No extra enemy-player sprint control is introduced.

## Source and chosen boundary

[Pinned primary-source trace](../../research/2026-11-08-pig-strikes-source.md): standing animation28 when the selected hero's raw Life low nibble>=4, otherwise2A. Effects are hero18/raw4/light recovery and20/raw16/heavy. Running40 uses hero22/raw16 even below raw16: the raw255/profile21 exception requires a different attacker animation and must not be inherited from the old generic Dash.

The four early Pigs do not rush. The five later Pigs can begin a running approach outside melee range while aligned, then stop running on attack, misalignment, target invalidation, carry, hit or takeover. Mapping the source palette enable onto zone>=3, chance1/32 at most each0.1s, depth/height2studs, walk9/run16studs/s and all spatial/time/impulse tuning are explicitly Roblox calibration. Source byte randomness is not a measured Bernoulli wall-clock process. NPC3HP remains provisional: attacks deal1/2/2HP with explicit source base profiles0/2/4, separate from original raw2/16/16.

Hero damage uses the actual Session lifecycle, shields, nibble arithmetic, delayed death and recovery. PigHeavy/PigRush increment heavy-reaction history; PigJab does not. Unknown prototype NPC raw Life defaults standing selection to jab; three prototypeHP are never treated as raw3. The public client Attack schema remains Punch/Dash, with no target/damage field. Other species and legacy stand targeting retain their previous profile.

Target selection excludes dying/heavy-reacting heroes but permits an actual unshielded light recovery. At effect time Session immunity can still reject an early hit. A completed jab47→43 recovers to47, so a single full-health jab is not claimed to permanently remove a heart. Full source combo timing, species health/AI, retreat and physical attack-hop motion remain open. These are original poses and calibrated attacks, not extracted animation frames.

## Studio MCP acceptance

[Complete checkpoints and fixed preparation hook](engine-checkpoints.json), Studio0.746.0.7461269, private place117412694427208/universe10775039796. Valid run `de1e21c8-407a-40eb-9f97-8741a1eeff8c`: two actual clients, one hero and one human-owned Pig.

| Scenario | Actual result |
|---|---|
| Human primary | Real offer selection claimed existing Pig-2; real F selected PigJab, hit hero47→43/profile18, then light recovery restored47. Hero kept actor/attempt1 and3 respawns |
| Prepare a reachable low-nibble state | One explicitly prepared existing Session PigRush hit made47→31; real hero F caught a real fly31→39. No HP/reserve assignments |
| NPC jab/heavy chain | NPC-7's normal AI jab made39→35. NPC-8 selected PigHeavy while raw35; light recovery restored39 during its windup. Its unchanged later profile20 hit made39→31 |
| Rush approach | Unanchored late NPC ran toward the hero, then selected PigRush, hit31→15/profile22 and returned to idle. Observed running velocity16.0027studs/s with WalkSpeed16 |
| Low-Life rush and death | A second actual NPC running approach hit15→0/profile22, confirmed dying, then one normal respawn: attempt1→2, reserves3→2, new actor and full47 |
| Presentation | Recorded Windup/Recovery for all three actions, Running for rush, and expiry back to idle. A client screen capture showed the original rig and readable HUD/buttons |

Preparation repositions bodies, anchors/pauses isolated attackers, selects Courtyard through QA cleanup and fixes the finite rush random roll to1. The hero remains unanchored with normal physics. The earlier human Pig is explicitly QA-killed for that district preparation; this does not prove natural role death or progression. The anchored two-NPC exchange proves action choice/hit/recovery, not their ordinary movement. The later rush actor is unanchored. No direct health or respawn writes occur.

An initial setup preflight accidentally retained the paused human attack cooldown; it produced no accepted F and is excluded. A fresh corrected run supplies all results above. An early rush read preceded its effect; the later Hit log supplies the31→15 result. Console contains one read-only AssistantCommand typo using the wrong world-folder spelling, separately identified; no game fault was observed. Test children ended, the temporary hook was removed, all23 production scripts matched the final repository pack, and main Studio returned to the normal start menu.

## Verification

[native-validation.txt](native-validation.txt): all22 fresh commands exit0. Core46; Combat766 assertions/Session42; registry18; Director30/Controller37/camera1; queue20; groups11; guardian13+3; route10; flies15; carry24; clubs23; PigStrikes15; gateway14; world18; Python17. Compiled62 source/test files plus2 tools. Main/stand/test places build; both deterministic checks pass. Independent review found two target-validity issues, both fixed RED→GREEN; final review has no actionable P1/P2.

Playable340597bytes, SHA256 `3ecd0002be2541d4971e8af2e6ef7e87b0aa6e398b2d0146c6243e3db5d1da99`. User-modified starter remains `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` outside this change.

Full unprepared combat progression, natural rush statistics, source-exact full AI/reactions, physical phone/tablet acceptance and same-account reconnect remain open. Native offline, schema, takeover, interruption and shield cases are not presented as additional engine scenarios. Earlier phone and multi-group reports remain separately bounded evidence.
