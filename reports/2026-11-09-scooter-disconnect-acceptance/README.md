# Copper Rush: actual client disconnections — 9 November 2026

Continuation of the [real-client enemy/crash checkpoint](../2026-11-09-scooter-role-network-acceptance/README.md). This checkpoint uses actual `StudioTestService:LeaveTest()` exits rather than injected connection events, fake Players or owner replacement.

## Setup and scope

Base playable is unchanged: production source `b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff`, place SHA-256 `1102ac79b23efc210a1fdd4bad6907bde9d883cbcab0cbb468213b00a70d40df`,1,020,211 bytes. The [fresh helper receipt](helper-base-manifest.json) records50 packaged scripts, Studio0.746.0.7461269 and all six network delay/jitter/loss settings0. Owned helper: PID9000 / Studio `4336b7c4-279a-4348-85e8-51af0ce9d4bf`.

The client driver is unchanged from the previous checkpoint. Actual participants select roles/heroes and Start through production Intent/State; only seed41/stage3 are prepared server-side. Live actions use client commands. Departure requires all of: actual PlayerRemoving, absence of the old Player from Players, registry invalidation and the production controlled actor marked disconnected. A Leave acknowledgement alone is insufficient.

The server retains the departed owner's identity and physical actor evidence, but final readbacks query only still-present actual original participants. Their snapshots must include authoritative state for every fixed hero, including offline ones. No test health/stock/pose, fabricated connection or forced-death writes are used in live scenarios.

## Final native results

**Four final scenarios,195 checks PASS, zero failures.** [Compact summary](final-scenario-summary.json). Diagnostic runs are excluded from these totals.

| Scenario | Initial actual clients / heroes | Final remaining original clients | Checks | Test duration from server startup |
| --- | --- | --- | --- | --- |
| InvaderDisconnect | 2 / 1 | 1 | 50 | 26.262s |
| RocketRatDisconnect | 3 / 2 | 2 | 55 | 25.153s |
| HeroDisconnectCrash | 3 / 3 | 2 | 44 | 23.397s |
| HeroOfflineDeathLateJoin | 3 / 3, then one new actual client | 2, plus the new spectator | 46 | 37.300s |

[Invader](invader-disconnect2-final.json): a real Enemy client claims/moves/steals before leaving. Actual removal and EnemyConnection(false) retain original owner/body/deadline and advance its connection epoch1→2. The accepted attack count is1 before departure and remains1, so an NPC does not take over. `InvaderEscape` occurs5.000656s after the original theft. The living hero keeps raw39, attempt1, stock3 and its original physical body. Its final client snapshot contains the original Invader row with dead=true and a time after native death.

[RocketRat](rocket-rat-disconnect3-final.json): the human drop is accepted at path elapsed0.333343s. Its original projectile identity, creation time and expiry survive actual owner departure. Timeline: drop1794246579.020220 → PlayerRemoving1794246579.450052 → original native obstacle contact1794246579.654568. At that callback the old Player is absent, its registry entry is not current and the owned role is disconnected. The same obstacle/source ActorId causes serial0→1; native rewind returns to Riding. Only the collided hero pays a replacement (attempt2/stock2); the survivor keeps its physical body, attempt1/stock3/Life47. Old effects are removed and no new enemy life is issued.

[Offline living rider](hero-disconnect-crash3-final.json): slot3 really leaves after boarding. Its original physical actor continues automatic X by3.273 studs with no residual steering. Another real rider causes the authored-hazard crash. The shared rewind retains the offline slot's pre-Leave actor/Model/ActorId, attempt1, stock3 and Life47; connected=false/epoch2 remains. No CommitSpawn is recorded for that offline survivor. The collided connected hero pays one stock; both remaining clients see all three fixed hero states.

[Offline death and late arrival](hero-offline-death-late-join4-final.json): the disconnected slot3 naturally dies from course danger without jump/steering; it remains AwaitingRespawn, raw0, attempt1, stock3 and epoch2. `AddPlayers(1)` creates a different actual Player/UserId−4 rather than returning the departed−3. It enters the same original group/run (now stage4), with no hero slot, and a real SelectRole Hero intent is rejected RUN_ACTIVE. Original owners stay[−1,−2,−3], and no post-death CommitSpawn/stock charge is created for slot3. Two original participants plus the new spectator receive matching final hero resource/context rows. This is four distinct actual clients over the experiment, at most three present together; it is not same-account reconnect.

The same production source and unchanged client driver were used throughout. Final test fixture revisions added stricter readback/counter checks and pre-drop test steering; historical files retain their own observed outcomes. Durations are local native test times, not Internet latency or physical-device performance budgets.

## Investigation retained

[First InvaderDisconnect receipt](invader-disconnect2-initial.json) retains its original PASS45 result and earlier assertion scope. The physical departure/ownership/deadline checks are valid; its no-new-NPC-attack counter initially looked only at `event.actorId`, while enemy Session log rows carry it in `event.data.actorId`. The final guard reads either field and requires a positive pre-departure attack count, so0→0 cannot pass. This diagnostic receipt is not included in final totals.

[Intermediate Invader readback](invader-disconnect2-stale-readback-pass.json) retains PASS49 from the earlier fixture. The server had completed escape, but its sole remaining hero snapshot still held dead=false just before the death timestamp. The final replay explicitly waits for that enemy row/death timestamp as well as unchanged hero resources; the intermediate result is not relabelled as final.

[Missed-contact RocketRat run](rocket-rat-disconnect3-missed-contact-fail.json) remains FAIL. The accepted obstacle survived actual departure, but the test driver started steering too late and missed it; a later static crash was correctly rejected as proof of RocketRat contact. The final driver begins actual steering before drop/Leave, preserving strict removal-before-contact attribution. No game geometry, collision radius, timing or player navigation was changed.

[Local compilation/regression/build receipts and hashes](local-validation.json) pass. The existing CI compiles both extended helpers and runs the actual-source client-envelope/readiness regression. The driver source is unchanged at SHA-256 `ca62d8d70a6a42740d6a2f3f362434b05d9bfd3a339d30d668dedf059098affd`.

## Rejoin boundary and remaining acceptance

The public [StudioTestService AddPlayers interface](https://create.roblox.com/docs/reference/engine/classes/StudioTestService/AddPlayers) accepts a player count, without a selected UserId. A new test client can verify late-arrival rules; it cannot establish return of the departed account. A fresh [official full API capability receipt](reconnect-api-capability.json) verifies the same deployed Studio0.746: legacy NetworkClient PlayerConnect/Connect/Disconnect methods are absent, and CreateLocalPlayer has no UserId/network target. No connection or identity mutation is attempted by that read-only metadata check. Earlier [native transport experiments](../2026-11-07-reconnect-transport/README.md) retain their actual Studio multiplayer-teleport and empty-solo-server limitations. They are not repeated or relabelled here as a same-account success.

Physical phone/tablet multitouch and performance, gamepad, impaired public networks and actual same-account reconnect remain separate acceptance. This work does not publish the separate public BrickToads experience or complete the remaining canonical character/art/audio work.

The user's Studio `c7317dd0-90dc-42e5-853a-e791f6641191` / PID12452 reported no place open in the pre-test read and is outside these tests. The protected `places/BrickToads.rbxlx` keeps SHA-256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`. Concurrent model specification/concept-art work is preserved separately.

[Cleanup receipt](cleanup.json): all actual test children exited through EndTest, then the owned helper was closed after checking its exact file path/process lineage and absence of remaining test children. The user's Studio remains open. Production code/assets, client driver, network settings and the user starter were not changed by this checkpoint. Publishing was not performed.
