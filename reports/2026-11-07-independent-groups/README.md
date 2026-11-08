# Independent local groups — 2026-11-07

Implements the one-server portion of BT-59 using independent Controller/Session/world contexts. Capacity4 and arena spacing512 studs are technical configuration. Active groups preserve their roster, resources, actors and result while another group starts, loses or changes its observers. Shared BossQueue dispatches one selected guardian across eligible groups. Cross-server routing and additional levels remain outside this slice.

## Verification

Native suites: MatchHub11, world/camera coordinate groups3, Session39, Controller36, Director30, BossQueue20, lifecycle46, connection18 and gateway14 pass. Existing combat/camera tests remain green. Seven deterministic builder/privacy tests and native compilation pass. Tests cover returning the same current Player to A→B→A while rejecting an obsolete object; these are not real same-account transport acceptance.

Independent reviews of world coordinates, routing, client group envelopes, server replication focus and final legacy-preview migration found no actionable P1/P2 issues. MatchHub and explicit group/level Session tests were RED before implementation. World preservation tests reproduced the prior constructor destroying the first world before the fix.

## Actual four-client Studio run

Players1/2 started team A (`group-1`) together, Player3 created/started team B (`group-2`), Player4 waited for the guardian. A's run was `3a5b66bb-78cb-4558-93e5-eb3f44ba20b2`; B's was `96709902-9d01-4258-8982-b35e63f628e2`.

Ordinary NPC roots were temporarily held to isolate routing. Hero deaths were actual falls below the configured kill plane, with no direct health/reserve edits. Later NPC engine deaths and selected hero relocations prepared a focused guardian encounter; this was not an unprepared full-level walkthrough. Temporary observation/preparation hooks are not included in the playable artifact.

| Scenario | Observed result |
|---|---|
| Two independent starts | A froze two heroes, B one; separate run IDs, actors and world folders; corresponding geometry/actors differed by Z512 |
| Shared FIFO across groups | Player4 declined A's invitation1, remained queued, received B's invitation2 and accepted; only that observer moved to B and automatically acknowledged Ready |
| Final elimination in continuing A | Player1 fell four times, reached attempt4/zero reserves/Eliminated; Player2 retained its original actor, raw47 and reserve3; A stayed Active |
| New team after elimination | Actual desktop group/create buttons created team C; its separate run `b94fd326-c35e-40e0-88cd-e29d08535ede` started Player1 at five hearts/three reserves |
| Isolated loss | Four real C falls produced Lost; A and B stayed Active with their original surviving actors/resources |
| Manual other-group role | Actual selector/join buttons moved Player1 from C to observing B. No new hero was added. It claimed B's existing sentry with unchanged actorId/three hearts |
| Stale old-group action | Start bound to A after switching to B returned WRONG_GROUP and changed neither run |
| Scoped human-enemy damage | Real F input from the B sentry damaged B's original hero raw47→31; A's teammate stayed raw47/reserve3 |
| Translated guardian | B's accepted Player4 received its guardian at physical Z512. Real human F projectile and real hero F reflection reduced that boss3→2; B hero identity/resources remained current |
| Camera | Observer and actor camera followed B around Z535 instead of A; explicit worldName selects only the routed world's actors |
| Phone layout | iPhone17Pro LandscapeLeft, viewport750×381/safe750×323; selector, rows, close/create actions fit without overlap |

The emulator's instance-target mouse clicks initially missed the intended controls; UI creation/join were verified in the desktop viewport, while phone evidence establishes layout only. A probe sending an unbound Sync after the initial handshake received the intended MISSING_GROUP. Live ROLE_ACTIVE notice can be cleared by the next successful movement packet, so the denial check used unchanged route/body alongside the native return-code assertion.

Live startup also found an older saved generated `BrickToadsWorld` with zero actors and757 descendants overlapping group1. Migration removes only that exact former runtime-owned preview when OriginalArt=true, matching LevelName and absent GroupId. Named group worlds remain untouched. Final single-play startup verifies migration from the saved preview.

## Limits

Four groups share one Roblox server and its identical lighting style. No cross-server discovery/teleport/recovery, multi-level route, physical-device acceptance or full NES parity is claimed. NPC anchoring/relocation and prepared encounter evidence are kept separate from ordinary walkthrough acceptance. The user's pre-existing changes in `places/BrickToads.rbxlx` are preserved; the generated delivery is `places/BrickToadsPlayable.rbxlx`.
