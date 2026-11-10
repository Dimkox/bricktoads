The QA Rope pilot parked at the positive swing limits and never moved again. Native attempt17 records three actual Swoops into that same descending body: Raven−3 at47→31, LargeRaven−10 at31→15 and Raven−5 at15→0. Their contact positions were approximately(16,182.335,16), (16,153.655,16) and(16,122.176,16). The ordinary attacks use the existing DragonHeadbutt/profile22 response; these are distinct from the remaining static ElectricTrap hazards. See native-17-extract.json and the complete attempt17 journal in the adjacent full-campaign-playthrough report.

Only the Rope branch in tools/qa/campaign_early_course_pilot.lua changes. It requests an ordinary damped swing toward X=12sin(1.5×elapsed), Z14. This keeps the body moving inside the authored swing limit16 and outside the static shaft hazards' Z band. The caller still normalizes movement and uses the existing client/Session input path. No primary, Jump, target ID or combat command is introduced; production navigation, AI, geometry, clocks, health, stock and completion rules stay unchanged. All other policy branches are byte-identical to the pinned2B9 baseline, including the existing Serpents, Ice, Surf and Jet corrections.

| Focused actual-domain check | Baseline | Candidate |
| --- | --- | --- |
| Three seeds × three input cadences × two accepted-Move delays |18 original-body failures|18 full-course passes|
| Typical first-body fatal state |Three Swoops, Life0, Y122.67 at11.733s|No fatal state|
| Final candidate state | |Mode complete23.417s, original actor, attempt1, stock3, Life31|
| Remaining damage | |One ordinary LargeRaven Swoop47→31|

The focused probe constructs the real Session, Modes, CampaignDirector, LevelDirector and CampaignEnemies modules with all10 authored NPCs active. It starts a fresh solo body at the source-derived slot1 spawn(0,240,−6). Only ordinary Move packets with current actor/run/connection identity and sequence are dispatched; source AI owns all accepted attacks, friendly hits, reactions and enemy deaths. Input cadence is0.1/0.133/0.167s, queued acceptance delay0/0.133s, seeds1006313601/1/41 and fixed domain slices1/60s. The normalized baseline reproduces the native attacker sequence−3/−10/−5 and final third-hit height/time closely. The fixture has fresh1/3 resources and stops at first-body fatal health; it does not claim the whole fixture run became Lost. Native17 entered Rope on its final4/0 appearance, which explains that recorded terminal Lost.

The actor/presentation boundary is numeric, not native Roblox R6 physics. Flying family trajectories, committed sweep collision, projectile progression, damage, reactions, movement and traversal are real production modules. Physical NPC knockback after friendly hits and every native projectile/geometry obstruction are not reproduced by this adapter. A new native attempt and complete13-stage acceptance remain separate. Candidate takes one real hit; neither damage-free traversal nor universal network/seed survival is claimed. The100-case other-course suite omits live NPC AI, while the8 live-threat/rewind checks are separate pure-plan contracts.

Reproduce from the repository root:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-rope-patrol/probe-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-rope-patrol/probe-current.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-rope-patrol/other100.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-rope-patrol/live8.luau
```

The baseline intentionally exits1; current, other100 and live8 exit0. Pinned baseline/candidate sources, complete fixture/probes, logs, source hashes, native evidence extract and limitations are versioned here. Independent review is recorded in validation.json when complete. No Studio/MCP control, new native window, production edit or Git mutation was performed by this focused audit.
