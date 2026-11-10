# Copper Rush: real-client enemy control and crashes — 9 November 2026

This checkpoint checks the existing Invader and RocketRat roles and the scooter crash lifecycle using actual Studio client processes. Its predecessor is the [solo/duo/trio hero acceptance](../2026-11-09-scooter-network-acceptance/README.md). Historical receipts remain unchanged.

## Setup and evidence boundaries

The owned helper starts from `places/BrickToadsPlayable.rbxlx`: production source `b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff`, place SHA-256 `1102ac79b23efc210a1fdd4bad6907bde9d883cbcab0cbb468213b00a70d40df`,1,020,211 bytes. [Base manifest](helper-base-manifest.json) records50 packaged scripts and native Studio0.746.0.7461269. Test-only modules and one startup hook are installed only in an unsaved owned helper, PID24588 / Studio `eb10b2e6-a87b-4b72-a55a-bdb9723d8520`.

Tests require current actual Player instances, matching expected BuildId, an armed test Command listener, an ordered production snapshot and two rendered client frames. Small bounded heartbeats retain scheduling/replication evidence. Client sends and server-accepted actions are distinct observations. Enemy diagnostics preserve prior/current control identity and replicated body ActorId; changing role does not invent a new enemy body or Life budget.

Actual clients choose role/hero and Start through production Intent. Server preparation selects seed41 and stage3. Unprepared live scenarios then use only actual client Move/Attack/Jump/ClaimEnemy commands; no test health, stock, pose or forced-outcome writes occur during execution. The automatic test driver disables presentation/UI to own its input sequence. These are native automated network scenarios, not physical touch or human UI acceptance.

## Scenarios

- **Invader return:** one actual hero and one Enemy client claim the existing entry actor, move, steal raw8 and earn its return through a real hero hit on that life.
- **Invader escape:** a separate fresh run observes the successful steal's finite escape deadline and spent enemy life without inventing a second role for the same participant.
- **Hero crash:** actual hero clients board and deliberately encounter authored danger. Observe native death, paid replacement and Stopped/rewind/Riding; preserve untouched survivors' body identity, attempt, Life and stock.
- **RocketRat:** a real Enemy client claims the naturally spawned actor and performs its single drop. Reject the repeat with NO_AMMO and independently attribute any resulting crash to the falling obstacle. A coincident static hazard is insufficient evidence.

## Final native results

| Scenario | Actual clients / heroes | Result | Checks | Total time, including client startup |
| --- | --- | --- | --- | --- |
| Invader return | 2 / 1 | PASS | 41 | 59.650s |
| Invader escape | 2 / 1 | PASS | 38 | 79.466s |
| Authored-hazard crash | 3 / 3 | PASS | 36 | 58.654s |
| Human RocketRat drop/crash | 3 / 2 | PASS | 49 | 80.684s |

**Four final runs,164 checks, zero failures.** [Compact final summary](final-scenario-summary.json). These counts exclude all earlier diagnostic runs.

[Invader return](invader-return2-final.json) records accepted ownership of the original enemy body, actual movement and `LifeStolen`47→39. A real hero hit produces `InvaderTransformation` and `StolenLifeRecovered`39→47 on the original hero ActorId. Attempt1 and stock3 remain. The Enemy client receives Dead for that original actor before PASS.

[Invader escape](invader-escape2-final.json) records theft47→39 and `InvaderEscape` **5.000830s** later. There is no recovery event; the original hero remains at39 with attempt1/stock3. Both clients receive that result, including Dead for the spent original enemy actor.

[Three-hero crash](hero-crash3-final.json) records the last immutable Riding state, authored-hazard contact around X77, Stopped → rewind → Riding and serial1. Stocks become2/3/3: only hero1 receives a new ActorId and attempt2; heroes2/3 retain their physical bodies, attempt1 and Life47. All three client snapshots and each client's own replicated body agree with the authoritative result.

[RocketRat](rocket-rat3-final.json) naturally appears during the two-hero course and is claimed by the third actual client at path elapsed0.196637s, preserving its physical body and authored trajectory. Move is accepted without introducing free flight; Jump is refused with NO_JUMP. Human Punch creates the sole obstacle at accepted elapsed**0.415483s**, before the1.5s automatic gate, at X152.126/Z9.507. Repeat Punch is refused with NO_AMMO.

An observational wrapper calls the original native obstacle callback exactly once and records the source enemy/ActorId and victim. That exact obstacle changes serial0→1 and Riding→Stopped for hero1 around X149.47/Z10.33; a nearby static hazard is not substituted as evidence. Native rewind resumes Riding, pays only that hero's replacement (attempt2/stock2), preserves the other physical body (attempt1/stock3/Life47), removes the old rat effects and leaves its human owner on the spent original role. All three clients see the paid replacement and Dead rat role before PASS.

Raw before/after state, server journal, accepted/denied action observations, actual client identities, commands, traces, six network settings and full final client readbacks are retained. Full test duration includes cold startup; it is not a course time or performance budget.

## Retained investigation and verification

[Initial Invader claim failure](invader-return-late-claim-fail.json) is preserved as FAIL: diagnostic Status round trips consumed the unengaged window. Stage3 began at1794240761.292819; the NPC attack began at1794240762.782841, before ClaimEnemy was sent at1794240763.030375. The test now requests claim before those diagnostics; NPC timing and role locks are unchanged.

The earlier [Invader return](invader-return2.json), [escape](invader-escape2-initial.json) and [RocketRat](rocket-rat3-initial.json) runs retain their original PASS results and earlier test scope. They are not added to the final matrix totals. In the early return run the last Enemy-client snapshot still said Alive after the server had recorded death, so the final harness explicitly waits for matching client outcomes. It also re-reads fresh lifecycle state rather than retaining a pre-update hero table, compares crash resources with the last Riding/contact snapshot, and uses the drop's server acceptance timestamp rather than later observation time.

[Local verification and hashes](final-local-validation.json): all three test script compilations pass; the actual-source regression passes queued/later readiness, same-body enemy offer/claim, production Move/Punch/Jump envelopes, sequence reset and immutable previous identity. The packaged playable still matches sources. CI compiles both role helpers and runs the client regression. [Replay instructions](../../tests/scooter_network/ROLE_ACCEPTANCE.md).

## Remaining acceptance

Physical phone/tablet multitouch and performance, gamepad, impaired public networks and actual same-account reconnect are separate requirements. This checkpoint does not publish the separate public BrickToads experience or establish full canonical art/audio and natural thirteen-stage human completion.

The user's original Studio67/PID24008 and dirty `places/BrickToads.rbxlx` remain outside the test. Protected starter SHA-256: `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`. External `assets/concept-art/` work is excluded.

[Cleanup receipt](cleanup.json): all actual test children exited through EndTest. The helper was then closed after its exact playable path/process lineage and absence of remaining test children were verified. The original Studio remains open in Edit. No production code, character assets, game timing or network settings changed in this checkpoint.
