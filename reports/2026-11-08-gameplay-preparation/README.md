# Gameplay preparation before Studio

The owner requested implementation first and Studio runs later. This batch adds real combat/feedback/diagnostic code; it does not declare the game or all13 reference modes complete. [Current coverage](../../docs/GAMEPLAY_COVERAGE.md) lists remaining work.

## Changed behaviour

- Modern hero primary chooses jab, uppercut, Dragon overhead, power punch, kick or boot from actual target Life/reaction after existing object/hand interactions. Current effect geometry decides the actual victim, with target-specific source profiles. No invented fixed combo counter or new hero air-kick.
- The13 existing source-classified ordinary bodies now carry explicit15/31/47 raw Life, source subtraction/reaction recovery and three-heart scaled display. Exact arithmetic zero remains alive until underflow. Human ownership, actor identity, one-life history and role limits persist.
- Dragon primary is a fixed profile22/raw16 headbutt for hero victims, without the hero Dash's low-Life finisher. Original finite neck/wing poses join the new hero action poses. Full Dragon flight/capture/mounting is not implemented by this change.
- A bounded private journal records run/source/rules, slot-to-owner mapping, lifecycle/health/shields/deaths, ordinary combat/ownership, contextual actions and result. A read-only Studio BindableFunction exports current/previous runs. The client receives only an allowlisted12-event tail, not the private journal.
- HUD text distinguishes actual hit, miss, shield, equipment, healing and guardian events, then returns to a short action hint. First sync/rejoin baselines history. Per-Player snapshot sequence prevents old groups/runs from rolling the client backward; a global server timestamp limits stale feedback. Alive-zero-health actors remain counted.

## Verification

[Structured validation](validation.json):30 commands exit0;78 Luau source/test/tool files compile.17 native runner suites, world/gateway probes,23 Python structural/packaging cases, portable lifecycle check and all deterministic builds pass.

Focused native counts: Dragon9; SourceCombat14; RunJournal7; CombatFeedback9; MatchHub12; Controller38; Director30; world23. The original stand still passes Combat1054 assertions and Session42 cases. These are code/adapter tests, not engine physics or device acceptance.

Playable370551bytes, SHA256 `f47327696381f21452017587aa53a6569209b645db8ce0efc1e6bf7a56541219`.

Embedded-source receipt `d47b4c1f530b636bbd220e6a93252d116056ab41a1e5dd3d13a6e6ca35258e9b` identifies script paths/text and excludes its own derived module. It is not a hash of the full place or runtime attestation after Studio edits.

The separate NPC-heavy QA place is385161bytes, SHA256 `a41d6c01875ccb7b6895b6ef54ff8d2342f97fc619b3d13e17bd68178118b3d4`. Building it does not produce an engine PASS.

## Independent review and fix pass

A fresh read-only reviewer requested four P2 fixes, with no P1. Each was reproduced before its correction:

| Finding | Regression and correction |
|---|---|
| Accepted response read live configuration | Hero/NPC tests mutate or remove live action/impulse/recovery settings. Capture and propagate reaction, impulse/profile binding, NPC recovery policy, death delay and heavy-protection duration. Captured force remains bound to its own profile. |
| Source rehit released protected carried/thrown targets | A target becomes carried between acceptance and effect, then is thrown. Effect rejects before recovery/damage/release; the same body and carry state persist. |
| Blocked light hit inferred heavy from recover=false | Actual heavy flag is stored separately; a Normal-shielded jab remains light, grants no post-heavy protection and does not select kick/boot. |
| Old snapshot rolled feedback scope backward | Monotonic per-current-Player snapshotSeq is checked before HUD/scope changes; group/run rollback, replay, legitimate return and replacement Player are covered. |

The coordinator verified the fixes RED→GREEN and reran the complete suite/compiler/build. No second independent approval is claimed. The review explicitly did not judge Studio physics, appearance, device layout, published services, emulator/frame parity or deferred systems.

## Decisions and limits

- Continue the authorised existing Luau project/current feature branch; do not merge main automatically.
- Three displayed NPC hearts scale source Life; they are not one common3HP damage budget. Current source tests establish arithmetic/identity, not natural difficulty or a complete dynamic spawn count.
- Preserve the existing close-grab reaction exclusion and explicit R/Dash mapping as documented adaptations. Exact hold/cancel/repeated-miss animation windows and full Dragon transport are still absent.
- The journal is bounded; dropped/late/error counters remain visible. This is not complete network/performance measurement or AnalyticsService retention instrumentation.
- Original hero/model work remains BT-14, animation catalogue/poses BT-62. New avatar/paid-cosmetic request is BT-73 with access/price decisions pending; no commerce is activated.
- All current Studio/phone/tablet/reconnect/published-service acceptance is NOT RUN. Earlier prepared Studio evidence retains its earlier commit and cannot validate this changed build.
- [Scooter source contract](../../research/2026-11-08-scooter-source.md) is documented for BT-27/28/29; no scooter scene is shipped in this batch. Audio, persistent goals/rewards and the other reference modes remain in their existing tasks.
