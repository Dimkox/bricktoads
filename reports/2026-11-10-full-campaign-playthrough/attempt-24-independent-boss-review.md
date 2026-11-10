# Native24 General Slaughter: independent read-only diagnosis

## Disposition

Native24 earned levels1–9 and reached the level10 boss with one carried reserve. Its two ordinary boss bodies each took47→31→15→0 from General Slaughter and died by CombatUnderflow. The Race traversal itself did not damage the hero. Replacement actor334 demonstrably moved on the ground before its later hits; this is not a replacement-control failure.

The proposed late-primary/own-attack-lock explanation is **refuted by the retained level10 journal and motion**. The final Headbutt instead supplies a concrete moving-but-still-in-cone counterexample: the pilot starts its perpendicular response too late to leave much delivery/turning margin at walk16. This does not establish that enabling run alone fixes the encounter. Charge contacts have additional unresolved geometry/direction observations.

The proposed extended native FallingDown penalty after the canonical reaction is **not supported by these boss observations**. No production GettingUp change is justified by this archive alone.

No Studio, source, gameplay state, health, resources, AI, phases or Git changes were made for this diagnosis. A child reviewer independently checked the journal/attack and recovery conclusions.

## Identity and clock

- Run: `bricktoads-qa-24-01-eb532d07`.
- Seed:1158731273; production source `7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a`.
- Stage10 observation origin: `1794335838.541860`. Every relative time below subtracts this origin; it is not an exact engine state-entry timestamp.
- Boss enters this slice with rawLife255. Terminal boss rawLife63, phase1, progress0. Hero actor125/attempt3/stock1 is followed by paid actor334/attempt4/stock0.

## Native contacts and preceding hero attacks

| Hero Hit | Boss Tell | Action | Latest hero AttackAccepted | Contact flat speed | Life |
| ---: | ---: | --- | ---: | ---: | --- |
| +23.082796 | +22.366333 | Charge / PigRush | +21.583246 | 0.0106 |47→31 |
| +25.798965 | +25.433148 | Headbutt / PigHeavy | +24.601496 |16.0000 |31→15 |
| +30.049908 | +29.687269 | Headbutt / PigHeavy | +28.848797 |13.2151 |15→0 |
| +53.034468 | +52.317046 | Charge / PigRush | +51.533557 |15.9425 |47→31 |
| +55.384424 | +55.019591 | Headbutt / PigHeavy | +54.167000 |16.0000 |31→15 |
| +64.331566 | +63.966010 | Headbutt / PigHeavy | +63.115395 |16.0000 |15→0 |

All31 retained hero AttackAccepted events in epoch10 have31 corresponding CampaignBossHit events. No AttackMiss or AttackExpired appears in that retained boss slice. In particular, the final primary was a legal and successful attack:

1. Plan +63.063613 observes Recovery/vulnerable and requests ordinary primary/run.
2. Dash is accepted +63.115395.
3. CampaignBossHit +63.301279 damages79→63. Session has already cleared the pending attack before resolving its contact.
4. Moving plans resume +63.313837. The sole nearby neutral/hold plan is +63.197764, while the Dash is pending.
5. Headbutt Tell begins +63.966010, **664.731ms after the successful hero contact**.
6. No new hero attack is accepted between that contact and the fatal Headbutt +64.331566.

`Session:intent` permits ordinary Move during a pending own attack; the `c.attack` COOLDOWN gate applies to another Attack. The QA combat pilot intentionally returns hold while `c.combat.attack` is pending, but that pending windup had ended well before these next Tells. Therefore neither a source input lock nor a late immunity miss explains the fatal Headbutt.

## Final Headbutt timing and geometry

Source Headbutt has tell0.35, active0.2, reach7, width3.5, height4. Source `_melee` checks the hero's forward and side offsets against those limits.

- Tell: +63.966009855; effect deadline: +64.316009855.
- Last pre-Tell plan: +63.948172, hero approximately `(19.194,3,28.444)`, moving toward the boss at walk16.
- First perpendicular plan: +64.080986977, **114.977ms after Tell**, hero `(19.980619431,3,26.460771561)`. It requests `(0.9295726263,0.3686390272)`, runfalse, primaryfalse.
- +64.213851929: hero `(21.430246353,3,26.012552261)`, flat speed16, still walking perpendicular.
- Hit: +64.331565857, observed hero `(23.413339615,3,26.798990250)` with flat speed16. The next motion row +64.347087 retains this contact point before the hit response moves the body.

The following geometry reconstruction is an inference, not a serialized attack-aim record. The constant perpendicular plan implies fixed boss aim `(-0.3686390272,+0.9295726263)`. The final boss position is `(21.322183609,3,23.077827454)`; the hero's recorded aim vectors before contact point consistently toward it. With that boss position and inferred aim:

| Observation | Forward | Absolute side |
| --- | ---: | ---: |
| First perpendicular plan +64.080987 |3.639245 |0.000004 |
| +64.213852 |2.688204 |1.182306 |
| Contact position |2.688209 |3.315647 |

Thus the contact point remains inside reach7 and width3.5. The hero is actively sidestepping, not stuck holding an old attack.

After the first perpendicular plan only235.023ms of Tell remains. Clearing3.5studs at a full perpendicular16stud/s requires more than218.75ms, leaving about16.27ms for response delivery and turning even under an optimistic constant-speed model. Native motion demonstrates less clearance than that optimistic model. A running or earlier response is a testable hypothesis, not an accepted fix.

For this stage's boss the completed mode actor makes `foot` return the combat plan before its standing-evasion branch. Therefore the Bridge's later explicit runfalse return is not the operative gate here. The generic combat threat plan itself starts from neutral/runfalse and chooses a perpendicular walking target.

## Charge observations remain distinct

Do not generalize the final Headbutt calculation to all six contacts:

- Charge3: the pilot requests approximately negativeX from +22.399825 onward, but motion becomes nearly stationary near `(10.74,2.95,5.63)` by +22.781984, before the +23.082796 hit. A physical obstruction/collision cause is not identified by these payloads. This is not evidence of an active own attack or a post-hit recovery delay, since it precedes that body's first boss Hit.
- Charge11: Tell +52.317046, effect +52.967046. Plans initially evade toward positiveZ, then switch toward negativeZ at +52.681985 near `(-15.575,3,54.911)`, before the charge becomes active. Motion follows negativeZ until the +53.034468 hit. A clamped-sideways fallback near an arena edge is a plausible source-based inference; the archive does not serialize the full authoritative attack origin/aim or blocking geometry needed to prove it.

A source-based encounter reproduction should retain authored arena bounds and native delivery/turning limits. An unbounded open plane would omit relevant negative cases.

## Native recovery after nonfatal hits

Canonical reactionEnd is Hit+0.75 in the four nonfatal contacts. The recorded brackets are:

| Hit | Last PlatformStanding sample | Canonical end | First reaction=nil Running/Metal sample |
| ---: | ---: | ---: | ---: |
|23.082796 |23.799977 |23.832796 |23.931754 |
|25.798965 |26.548415 |26.548965 |26.682116 |
|53.034468 |53.731998 |53.784468 |53.863889 |
|55.384424 |56.047443 |56.134424 |56.181320 |

There are **zero observed nonterminal rows with reaction=nil and FallingDown or PlatformStanding**. The first cleared sample is already Running on Metal in every case, and its plan requests run. The0.047–0.133-second gaps fit the approximately0.12–0.13-second observation interval; they do not establish an additional multi-second engine lock.

Low rootY and high vertical velocity do occur during the transition: +53.863889 hasY2.523/Vy17.701; +56.181320 hasY1.630/Vy44.477, both already Running. An exploratory settled measurement (`|Y-3|<0.15` and `|Vy|<2`) first appears at24.315071,26.682116,53.998762 and56.298218 respectively. That measurement is not a gameplay contract. All subsequent Headbutt contacts occur after those settled samples. The two lethal hits are excluded from recovery checks because their pending death must not be treated as a recoverable movement failure.

Source `RobloxWorld:setReaction` changes PlatformStand, AutoRotate and WalkSpeed without calling ChangeState; Session clears reactionEnd and calls it. Official Roblox documentation explains that FallingDown normally enters GettingUp after about3seconds and that PlatformStand prevents movement. These engine facts make the hypothesis worth checking, but the measured boss data above do not demonstrate that failure. See [Humanoid FallingDown and GettingUp](https://create.roblox.com/docs/reference/engine/classes/Humanoid#FallingDown) and [HumanoidStateType](https://create.roblox.com/docs/reference/engine/enums/HumanoidStateType).

## Follow-up: single probe-only preemptive strategy

Independently inspected and reran the frozen probe in `../2026-11-10-slaughter-qa-proof/`:

- `probe-preemptive.luau` SHA256 `94fe01cc91e20663a9eabfa912093970cb0b5919e71f7d3e63d13e623ae88fa1`.
- `fixture-preemptive.lua` SHA256 `58fc3f73b6fa06149824875530cbe8b85c3a8ec45396c5b90ca745708f43da7f`.

The strategy starts an ordinary perpendicular run near Ready before an upcoming Headbutt, preserves its selected side across Tell, and selects the Charge side with greater finite-arena clearance. It reads Boss state/attack data and changes only local tactical/latch state. Source Session/Boss/SourceCombat still determine action selection, contact, byte damage, reactions, phase transitions, deaths, reserves and defeat. Actual extracted `foot` is used and its completed-Race early return is asserted. No boss state, health, progress or outcome is assigned by the strategy.

The preemptive movement does not create a side offset against an attack that has not yet aimed: the boss retargets the hero when Tell begins. Its useful effect is already accepted perpendicular velocity, removing the later response-to-Tell delivery/turning delay.

All four cases earn source Boss defeat, exactly21 underflows and progress240:

| Preparation | Queue | Won at boss elapsed | Boss Hits on hero | Terminal hero attempt / stock | Body retained during boss |
| --- | ---: | ---: | ---: | --- | --- |
| Fresh47, attempt1/stock3 |0 |86.991667 |0 |1 /3 |Yes |
| Fresh47, attempt1/stock3 |0.133 |134.675000 |3 |2 /2 |**No: one paid death** |
| Two ordinary prep Falls, attempt3/stock1 |0 |86.591667 |0 |3 /1 |Yes |
| Two ordinary prep Falls, attempt3/stock1 |0.133 |136.050000 |0 |3 /1 |Yes |

The fresh queued case retains its negative result for an original-body gate: Headbutts at boss elapsed7.975,69.816667 and78.083333 take47→31→15→0; CombatUnderflow death is confirmed78.883333. A normal paid replacement later completes the encounter. This improves the exact queued baseline (Lost after four appearances), but **does not satisfy zero-death/original-body acceptance**. It is not a regression relative to that queued baseline.

The two prep losses are genuine ordinary inputs off the finite support, gravity, authoritative Session Fall and paid respawn. ConfirmedDeath(reasonFall)==2 and attempt3/stock1 are asserted. There are no resource assignments. The Boss is constructed normally after preparation, so this is a prepared subencounter, not completion of the Race traversal. Initial spawn has no shield; the initial2.1-second step only advances the clock. Paid prep-spawn protection is allowed to expire normally before the Boss is constructed.

Limits remain material: ground/run/facing/impulse response uses a mapped non-engine adapter; queue delay is fixed rather than a native transport trace; the fixture's retry search returns the course-finish entry rather than production finished-mode respawn position. The latter affects the fresh queued post-death result. The depleted cases use no in-boss replacement and therefore do not exercise that retry discrepancy. Four successful prepared cases do not establish native collision, arbitrary timing stability or full-campaign acceptance.

Disposition: **CLEAR for probe integrity; original-body fresh queued gate remains RED; no source candidate accepted.** Independent child review and rerun confirmed the same outcome. Production and working QA sources remain unchanged.

## Final QA integration review under the normal life budget

The parent clarified acceptance as the ordinary global budget of three paid respawns, not a deathless boss requirement. The fresh queued original-body negative remains recorded above; it is not by itself a rejection of an improvement that wins within the normal budget.

Reviewed final working Combat SHA256 `4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129`. Bridge remains `97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add`. The added helper is specific to GeneralSlaughter, uses private per-Session/slot state keyed by hero/run/epoch/attempt, boss identity and attack serial, and returns ordinary inputs only. Its invocation now follows existing accepted-attack, reaction, pending-action, carried-enemy and Captured/Mounted Dragon precedence. Other boss/NPC paths retain their prior behavior.

The final retry fixture directly calls production `Modes.respawnPosition` on a prepared finished-slot1 view and asserts the returned arena position. Initial/prep entry remains the course finish. Independent direct-working-source reruns produce:

| Preparation | Queue | Boss defeat elapsed | Hero Hits | Terminal Life / attempt / stock |
| --- | ---: | ---: | ---: | --- |
| Fresh |0 |86.991667 |0 |47 /1 /3 |
| Fresh |0.133 |142.941667 |4 |31 /2 /2 |
| Two ordinary prep Falls |0 |86.591667 |0 |47 /3 /1 |
| Two ordinary prep Falls |0.133 |136.050000 |0 |47 /3 /1 |

All four earn exactly21 source underflows and progress240 inside the original global resource budget. The fresh queued case genuinely spends one reserve and retains its original-body RED label. Its corrected retry position adds one further nonfatal hit compared with the earlier invalid retry mapping; that discrepancy is preserved rather than hidden. The depleted cases match Native24's boss-entry resource state47/attempt3/stock1 and win without another appearance in this bounded model.

Independently reran33 helper/state/priority checks and compilation. A separate reviewer reran all208 retained checks against the final working Combat:146 Dragon,10 Guardian,26 step-off and26 Bridge. Every process exits0. The Bridge test's initial missing-nav wrapper error was corrected in report-only scaffolding; the extracted foot body is exact text of unchanged Bridge97. No production source, movement/attack tuning, health, AI, phases or resource rules change.

Final disposition: **CLEAR for bounded QA source integration and the next ordinary native verification under the normal three-respawn budget.** Mapped Humanoid/facing/impulse response, fixed delivery timing, one seed and prepared boss entry remain limitations. This does not claim Native25, GeneralSlaughter native acceptance or full13 Won.

## Evidence and next proof boundary

Read `attempt-24-detail.json`, `attempt-24-motion.json` and `attempt-24-full-natural-archive.json`; source checks used CampaignBoss, Session, RobloxWorld, GameWorld, the combat pilot and the actual Bridge function. No replacement-body or production GetUp fix is established. A future QA response candidate needs a bounded real Session/CampaignBoss ordinary-input RED/GREEN encounter, retained authored bounds, credible input delivery and a fresh native boss observation before claiming General Slaughter or full13 acceptance.
