# QA Dragon run-up height

Attempt16's ordinary Dragon hovered above the grounded hero. The combat pilot's generic0.8stud run-up height guard excluded it even though the real Dash vertical bound was4stud. The pilot repeatedly used ordinary Jabs; source EnemyRecovery correctly restored45→47. Three subsequent Headbutts exhausted that body's Life. This is a test-strategy limitation, not a demonstrated production combat defect.

The only policy change uses `Dash.height-.15` for an ordinary Dragon's run-up eligibility. Other enemy kinds retain0.8. The standing-body, matching authored floor, strict3stud retreat endpoint, current identity, reaction and observed-native-run guards remain. The policy returns normal movement and the public primary hint; it never writes a pose, resource, attack profile, or game state.

The recorded hero and enemy poses used by the focused fixture are137ms apart. Their prepared pairing is not claimed as a simultaneous native snapshot. Exact seed338231076 geometry is used. Five eligible height cases plus nine unchanged/unsafe contexts produce146 assertions. Baseline fails the first supported-Dragon case; the candidate passes. Existing26 step-off assertions also pass.

Run from the repository root on the recorded source version:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-dragon-runup/probe-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-dragon-runup/probe-current.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-dragon-runup/public-session-dash.luau
```

Expected exits are1,0,0. Immutable baseline/candidate snapshots and verification logs are included. The public Session contract uses the canonical prepared DragonFlight fixture plus a numeric run/collision adapter: accepted Move(run=true), then public Attack(Punch), Session-selected Dash at dy1.658, original enemy47→31 heavy reaction and unchanged hero47/attempt1/stock3. Its vertical comparison matches `RobloxWorld:targets`, where `abs(localP.Y)<=cfg.height`; height is not halved. This proves public Session routing/geometry at the relevant height, not new native AI survival or full-campaign completion.

The remaining two attempt16 falls had no further Hit event after the last Dash. Their recorded NPC-head landing and Flight reversal are being reviewed separately in QA navigation. No live retry, production patch, or policy hotload was performed for this report.
