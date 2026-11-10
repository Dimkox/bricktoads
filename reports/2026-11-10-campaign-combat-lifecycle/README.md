# Campaign combat and lifecycle — 10 November 2026

## Corrected gameplay

1. **Human boss walking:** all five campaign bosses accepted Ready-state Move commands while their native World WalkSpeed remained 0. CampaignBoss now initializes the existing campaignWalkSpeed adapter with the existing Enemy.speed cap (9 studs/second in this build). NPC scripted attacks keep their existing motion; the stationary first guardian uses another constructor and is unchanged.
2. **Robo-Manus bolt response:** an old +X bolt could hit after a later Jump turned its owner toward -Z, applying native impulse (0,18,-32). Each emitted bolt now owns a tuning snapshot and its own spread direction, passed to both hero and ordinary-enemy damage paths. The native Play observation is now velocity X32/Z0 after the boss has turned toward -Z; config is not mutated.
3. **Swim/Fly input after reconnection:** connection callbacks cleared the ordinary enemy timestamp but retained CampaignEnemies' saved movement. A reconnected Electrofish or Swellcheeks moved indefinitely without another accepted input. A missing movement timestamp now also clears the component input. Fresh current-epoch input resumes the same body and Life; stale epoch input remains rejected.
4. **Victory with no eligible survivor:** a final due hero strike followed by an already accepted SentryDrone shot could defeat the boss and leave the sole hero in a lethal reaction. Controller then replaced geometry before Session rejected advanceLevel with NO_SURVIVOR. CampaignDirector now checks the same Alive/non-deathAt eligibility before declaring either boss or non-boss victory. While waiting, ordinary effects and Session deaths/retries continue, offline retry ownership remains reconnectable, and failed spawns spend nothing. Only a legitimate paid retry can satisfy the predicate; an exhausted cohort stays Lost, including stage 13. No Controller/UI rewrite was needed.

## Verification

- Full frozen-source run: **56/56 commands**, **181 Luau files compiled**, source/playable match, verification inputs unchanged. [JSON](final-validation.json), [command output](final-validation.txt).
- New regressions cover five boss movement adapters, three projectile-response cases, two authored enemy connection cases and 21 victory/resource cases across stages 5/8/10/11/13 with solo/duo/trio, offline ownership, failed spawns, lethal deadlines and terminal loss. Existing focused suites also pass. RED logs are retained beside this report; victory RED uses an isolated ignored copy of the c29a662 CampaignDirector with the current fixture/dependencies, reproducing NO_SURVIVOR without reverting shared files.
- Independent read-only review found no outstanding actionable runtime or helper issue. The departed-Player test fixture was corrected to use a fresh instance with the same identity, respecting the registry's existing tombstones. Prepared completed traversal in the Play fixture explicitly releases native hero bodies before testing physical impulses.

## Native Studio results

Fresh local playable, Studio 0.746.0.7461269, production source SHA256 `006fe6609a197b9e288ea9a982cd79ca5ca0095853b2489b2f03628b0ae0f2de`. All three tested module Sources match the local source files and the private Studio copy exactly.

| Helper | Native execution | Named checks | Result |
| --- | --- | ---: | --- |
| [Boss attacks](boss-attacks-native.json) | Play Server, real Heartbeat and Humanoid physics | 75 | PASS |
| [Enemy connection](enemy-connection-native.json) | Edit, isolated native Models and family callbacks | 44 | PASS |
| [Boss victory](boss-victory-native.json) | Edit, real Controller/Session/Director and native Models | 153 | PASS |
| Total | 14 owned worlds; all cleanup/restoration rows pass | 272 | PASS |

The five Play bosses walk approximately 6 studs in 0.65 seconds at the existing cap 9, on their own authored arena floors and with the same unanchored native bodies. Ordinary owner commands then trigger Hop/Burst/Charge/Roll/Sweep; actual hero Life changes 47→31 without changing the hero actor, stock or attempt. Robo-Manus's old +X center bolt lands during a later-Z Jump: captured direction X1/Z0, current facing X0/Z-1, observed native velocity X32/Y14.73/Z0. Its Play helper records 511 Heartbeat frames, not fixed simulation ticks, despite the legacy result field name `fixedTicks`.

The connection helper retains native X 78.900009 for Electrofish and X -19.200001 for Swellcheeks through disconnection and more than a MoveTimeout after reconnection. A new accepted Move then advances each same body; actor, Life, owner, hero resources and native Model remain unchanged. It performs 178 fixed family/mode steps.

The victory helper first resolves a real due hero finisher, followed by a claimed SentryDrone's accepted TwinBolt collision. The native hero remains alive at raw 0 until its accepted lethal deadline; the other twin shot remains in flight while the stage waits. Session then confirms death and commits attempt 2/stock 2 before the stage advances 8→9. Six additional prepared native EngineDeath cases cover stages 8/13 solo/duo offline retry and exhausted solo loss. Its 17 Controller calls use prepared time deltas, not fixed ticks. All old directors, body registries, QA worlds, defaults, atmosphere and touched Lighting properties are checked during cleanup.

## Fixture boundaries and delivery

These are synthetic server owners/rosters, explicit cleared gates/traversal, selected stances and phase/time setup. The victory helper deliberately prepares the boss's final Life/progress, one-hit hero vulnerability for the Sentry case, and native Humanoid.Health=0 for EngineDeath cases. Those setup writes are not presented as natural gameplay damage. Session alone performs the subsequent resource changes and paid spawns. The Play helper establishes physical Humanoid walking and knockback but does not establish real network owners, keyboard/touch, full natural boss fights, all phases/seeds, source-perfect parity, complete art/audio or production readiness. Actual same-account live-body return still needs the unavailable second real account. No automatic player navigation or safer crossing was added.

The three changed modules and BuildInfo were copied to the existing private place 117412694427208 only after its previous bytes matched Git HEAD. Save to Roblox with Notes used `Fix boss controls and victory retry ordering`. No public Publish action was used. The owned helper was stopped and closed without saving; the original private Studio remains open without QA folders. See [private synchronization](private-studio-sync.json) and [verified file hashes](verified-files.json).

The protected starter remains SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`; concurrent concept art is excluded. Push, CI and Jira receipts are recorded in the delivery response/comments without self-referential commit metadata here.
