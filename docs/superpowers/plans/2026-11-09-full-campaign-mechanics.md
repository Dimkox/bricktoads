# Full Campaign Mechanics Implementation Plan

**Goal:** Implement the missing game modes and bosses and connect them into one server-owned thirteen-level run.

**Architecture:** Preserve the causeway director and current lifecycle. Add campaign definitions, distinct mode simulation, additional boss FSMs, a campaign director and native world/client adapters.

**Tech Stack:** Luau, Roblox Studio MCP, existing Python place builder and native test runners.

**Spec:** [Full campaign mechanics](../specs/2026-11-09-full-campaign-mechanics.md).

## Global constraints

All existing fixed-roster/resource/role rules apply. No automatic player navigation. English default with localization. Preserve user starter SHA `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`, all seven previous GLBs and the active wide-mouth asset. No public publishing. Separate implemented Roblox behavior from unverified NES parity and device acceptance.

## Tasks

- [x] Read current repository/Jira and verify connected original Studio; no open GitHub issues were returned. Cached current Jira requirements live in ignored `build/full-mechanics-jira-2026-11-09.json`.
- [x] Implement campaign definitions and distinct traversal/objective mode mechanics with meaningful tests. Initial owner: campaign_modes; completeness fixes below are implemented.
- [x] Implement five additional boss FSMs with source-aware health/progress and common human/NPC actions. Owner: campaign_bosses; source arithmetic and finite native attacks checked separately.
- [x] Connect campaign directors, ordinary enemies, boss reservation and level transitions without resetting run resources. Owner: campaign_integration.
- [x] Implement native world geometry/physics/visual adapter and mode-aware camera/control hints. Owner: root.
- [x] Review task boundaries, repair integration and run current regressions/build/compile.
- [x] Open exact saved playable in Studio; inspect prepared new mode physics, deaths/checkpoints, boss outcomes and campaign transitions.
- [x] Prepare accurate coverage and reproducible evidence for the authorized commit/push/CI/Jira delivery. External delivery receipts belong to PR3 and the relevant Jira comments.

## Progress ledger

Baseline: `727098f8ca1393ae0e3059189838f7d063d810c6`. The sole dirty file before this task is the protected starter. All three implementers own disjoint paths. Root owns GameWorld/CampaignWorld, client, queue presentation and final integration verification. Existing builder discovers gameplay modules recursively.

Ruling: extend the existing feature branch and shared runtime instead of creating a separate worktree — active Studio/source synchronization and disjoint file ownership already isolate this implementation from the protected user starter.

Ruling: proceed using accepted scope and current repository specifications — the owner has repeatedly instructed implementation and explicitly expanded the target to all mechanics; no further product-choice round is needed.

## Completeness audit follow-up (implemented)

An initial implementation passed 53 commands/151 compilations and 30 real-Session course-only normal-input runs (ten modes, three seeds, no respawns). A separate audit found substantive omissions. These passing checks do **not** close the full request. Keep executing the following work before final delivery:

- [x] Actual Rope actors/roles for Raven, LargeRaven, wall RetroBlaster and SaturnToadtrap; source Life capacities and special bird reaction paths; Invader steal/return Life. Owner: enemy_roster_completion, owning CampaignRoster/Enemies, LevelDirector, Combat, Session, GameConfig and scoped tests.
- [x] Shared vehicle checkpoint stop/rewind, later scripted RocketRat encounter, missing Ice walls/platforms/spikes, Ascent electrical/mechanical hazards and Tubes currents. Owner: vehicle_and_obstacle_completion, owning Definition/Modes and scoped tests.
- [x] Actual physical Rat Race rival and bomb-contact outcome; source invulnerable/stunnable rival, same-body pre-engagement human option, no ordinary three-heart profile. Owner: race_completion, owning new CampaignRace and scoped tests.
- [x] Root integration: encounter spawn/reset callbacks; entry-only boarding gate; appropriate per-level exit gates; Rope kick hits real actors; rival roles/hits; shared-rewind camera/input; native shapes and readable role HUD.
- [x] Re-run full tests/build after these changes, repeat prepared native acceptance on the **new exact saved file** and update original Studio sources. Final external delivery is tracked by PR3 and Jira.

Prior native fixtures created all twelve new modes with three real bodies and checked thin-wall casts and resource-preserving same-body transitions, including offline and eliminated participants. Helpers were closed after their source snapshot changed. The last saved pre-follow-up checkpoint is 944488 bytes, place SHA `a68f376d108ab566d1d1f88753bb1749c2ba3729975193d13d08e8b70d068501`, source `674c3c6a9f11ff4f7bdf871e4cdd209b4b63663baa35a9afb7603ef29f8bdcf9`; it is already stale while follow-up agents edit. Prior native source `43a131...` evidence is debug-only and must not be labelled final. Original Studio `67cde5d7-c587-4240-9f6f-ef46082fa9bc`, process24008, remains Edit and has not received the campaign sources yet. Owned preview processes14140 and32512 were verified and closed; do not reuse their Studio IDs.

Root source fix: GameWorld:impulse must preserve all five arguments `(id,attacker,tuning,profile,impulseDirection)`; focused RED/GREEN now checks the actual Session call shape. Keep this fix while integrating new features. Original user starter and all frozen GLBs still match their protected hashes.

The reusable ignored verifier is `build/run_campaign_validation.py`; final verification discovers Race/Roster and passes55/55 commands plus157 compilations. `reports/2026-11-09-campaign-mechanics/studio-campaign-fixture.luau` is prepared acceptance code only, excluded from production. GUI art, sound assets, physical phones and exact whole-game NES parity remain separate evidence boundaries; do not claim them complete from code tests.

## Final implementation checkpoint

The [current report](../../../reports/2026-11-09-campaign-mechanics/README.md) records playable1,017,596bytes, place SHA `1769ecbaa4df2371da6dd42604235af655b2bd52c8d548737aa549b97a5c962e`, source `38bda09a769a7b405b8bc7705a00337956c9164fd55a60e04b26af7d9981d4a1` and50scripts. Native all12 new modes with3 actual bodies, wall casts, same-body role/recovery, offline/eliminated transition, five finite boss actions, short real-clock Rope/Ice/Race, prepared final victory through27 actual attacks and shared vehicle crash/rewind all passed on that exact saved file. Thirty normal-input course pilots remain explicitly API-double/course-only evidence.

Final bounded independent review found no remaining scoped defects after fixing emergency-held vehicle retry, the LargeRaven low-Life branch and unconditional old encounter cleanup. Original42 Studio sources matched the prior commit exactly before update; all50 final sources matched the new saved package exactly afterward. Original process24008 remains Edit; owned final helper8452 was cleaned and closed. The user starter and frozen character assets remain preserved. A complete natural human campaign, devices, actual reconnect, canonical cast/animations, source-exact unknowns, audio and release readiness remain open acceptance/product work.
