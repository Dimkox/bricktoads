# Pig primary strikes

Goal: replace the shared heavy attack for ordinary Pig bodies with the first-level source standing jab/heavy choice and a distinct running approach. Continue the user's authorised game implementation, Studio MCP acceptance, push and Jira sync in the current development branch.

Source: pinned `feos-tas/DisAssemble` f1a43b69577246850d136473700a333b3cdfe93f. `sub_E3F2` / `loc_E426` select standing animation28 when the selected target raw Life low nibble is at least4, otherwise2A. Their effects request profile0→hero18/raw4/light recovery and profile2→hero20/raw16/heavy reaction. Running animation40 requests profile4. The exact running-entry trace is being recorded in the companion research note before its integration.

Ruling: existing user instructions request autonomous implementation and explicitly defer extra enemy-player abilities. This slice changes the existing primary attack on the same Pig body, with no new buttons, roles or life allowances. Roblox spatial/time tuning remains explicit calibration. Ordinary NPC3HP is unchanged here. Dragon behaviour is a separate future slice: mounted-player fire is not evidence of an unmounted NPC fire attack.

## Interfaces

- Trusted `Combat.hit` actions `PigJab` and `PigHeavy`: hero profiles18/raw4/recover and20/raw16/no recover respectively. Heavy never substitutes running finisher21. `GameConfig` extends cloned attack/impulse tables. Public intent remains only Punch/Dash.
- Director captures the chosen primary action at attack acceptance in `enemy.windup.action`; later damage/healing or a different geometrical target do not rewrite that attack. Effect-time hitbox/geometry still chooses the actual first eligible hit. Ordinary enemies receive explicit calibrated1/2HP, not an accidental fallback. Existing claims close at accepted start, held/reaction/death cancel, offline accepted attacks resolve once.
- The chosen target is the AI's nearest eligible hero or the human primary's first geometrically directed eligible combat actor. Missing target selects a normal jab. Eligibility excludes dead/dying/heavy-reacting targets. Source standing decision reads rawLife, never five-heart display/HP percentage. Running entry/exit parameters are documented as Roblox adaptation.
- World presentation reads `windup.action` and a finite recovery marker; jab, heavy and confirmed rush have distinct original poses. Incoming reactions, carried bodies and held weapons retain their existing priority. No extra client attack fields.

## Tasks and verification

- [x] Source note: pinned branches, E2 profiles, running-entry/exit and low-Life exception; classify unknowns.
- [x] RED→GREEN Combat arithmetic for PigJab/PigHeavy/PigRush, raw0/3/4/15/16/47 and both shields; retain all existing actions.
- [x] RED→GREEN Director choice/immutable pending action, real Session damage/recovery/shields/drop epoch, human/NPC consistency, takeover miss, interruption, cooldown and offline completion. Root owns Director/config/integration tests.
- [x] Distinct world telegraph/recovery poses and finite reset, covered by existing world harness. World agent owns GameWorld and world contracts.
- [x] Native regression/compiler/build check, independent review, actual Studio normal/heavy/running cases with preparation limits recorded; remove test-only hook and compare final production sources.
- [ ] Explicit stage excluding user-modified starter, commit/push, Draft PR and Jira sync. Verify exact-head CI, report any external failure honestly.

Review focus: chosen-target health changing during windup; different target entering actual hit geometry; default legacy fixture/other species unchanged; heavy reaction versus light club retention; accepted offline attack and stale body; source running finisher scope.

Running ruling after source trace: source40 always maps to hero22/raw16; the raw255/profile21 exception requires attacker animation16 and cannot apply to Pig40. Later Pig run enable follows palette trigger0100 in the original. Our new geography enables it from zone3 for the five later Pigs, leaving four earlier Pigs without rush. Eligible NPCs must be outside melee range and aligned within2studs in depth/height, with no current target reaction; they roll1of32 at most once each0.1seconds and move at16studs/s instead of9. These are calibration. Depth/target invalidation, carry, hit, takeover and accepted attack clear the running flag. Human primary does not acquire a new sprint ability. Unknown ordinary NPC raw Life defaults standing choice to jab; prototype3HP is never mistaken for raw Life.

Attack tuning: jab windup0.30/cooldown0.8/recovery pose0.20/reaction28/60 seconds; heavy0.55/1.3/0.30/0.75; rush0.22/1.4/0.35/0.75. Hitbox reach6,width3,height4studs. Ordinary enemy damage1/2/2HP uses explicit profiles0/2/4 and matching calibrated impulses. Source damage and prototype health are separate.

Review ruling: source excludes heavy reactions rather than all reactions. The existing actual Session `recover==true` identifies an unshielded light reaction and permits standing selection during it; the actual hit still respects Session reaction immunity. This matters after a raw+8 fly catch:39→35 light hit can select the heavy attack before recovery to39, whose later effect retains profile20. Starting a new rush remains conservatively blocked by any target reaction. Both target selection paths share this policy; other species/guardian targeting remain unchanged. Two review findings (rush validity at melee entry and nearest heavy-reacting target) have explicit RED→GREEN regressions.
