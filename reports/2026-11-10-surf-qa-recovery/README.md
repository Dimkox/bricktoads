The QA Surf pilot now requests the existing ordinary Jump for a nearby Whirlpool. The production course, collision, jump budget, enemies, health and reserves are unchanged. The policy snapshot is fixed-policy.lua, SHA256 8c7d521749c78ec921f158633067a35b773c7b4a42933b28d6f9a93ca9a6fa16.

Attempt11 used seed388791054 and suffered one crash at the Log nearX349, followed by three crashes at the Whirlpool nearX295 after checkpoint3 rewinds. Exact authored geometry places checkpoint3 atX280; ride-9 Whirlpool is centered atX295/Z0, and ride-11 Log atX349/Z−12. Their expanded leading collision faces areX291.9 andX345.9, matching the recorded native positions (the native World snapshot can show the previous slice).

The existing serial reset and current-X lane-group refresh were already working. The remaining assumption was that every rider could reach the selected lane before the Whirlpool. A restart from rest reaches its leading face in about0.533seconds. A rider at the right offsetZ+4 needs more than11.2studs of left steering to pass below the Whirlpool exclusion intervalZ±7.2; Surf drift and delayed inputs make that marginal. The Whirlpool has the same authoredY3/height3 as a Log and is jumpable using the unchanged ordinary mechanics. The pilot previously jumped only LowBarrier/Log hazards.

The initial native Log349 missed-jump cause remains unproven because attempt11 did not retain its per-packet input trace. This repair addresses the demonstrated Whirlpool/paid-restart cascade. It does not claim to explain every initiating crash.

| Evidence | Baseline | Repaired |
| --- | ---: | ---: |
| Real Session/Modes cohort matrix |25 failures,29 passes|54 passes|
| Existing other-course cadence checks | |100 passes|
| Existing live-threat/rewind checks | |8 passes|
| Prepared native Surf + BigBlag | |Director Won in96.61seconds|

The54-case matrix uses the real production Session, Modes, lifecycle and authored course projectiles through validated ordinary Move/Jump/Punch packets. It covers input cadences0.08/0.133/0.167seconds, outer Heartbeat batches1/60/0.1/0.25seconds, three riders, staggered boarding and entry phases. All riders must finish. In27 ordinary cases, no death or reserve loss is allowed. In27 restart cases, the test deliberately withholds only the lead rider's Jump at the final Log until a real collision causes a paid death/rewind. Steering stays unchanged. Exactly that rider's single intended reserve may be spent; every additional death fails the case. No test directly kills, moves, heals, spends a stock, edits a checkpoint or changes geometry.

The numeric boundary doubles Roblox actor presentation and does not construct the ordinary NPC/boss controllers. Its source-less course-shot attacker−9001 correctly produces no physical impulse on an anchored Modes body, while the real Session reaction/reset still applies. An earlier draft incorrectly injected a lift and also neutralized steering during the deliberately missed jump. Both fixture issues were corrected before the final25RED/54GREEN results; the final exported probe was rerun successfully. This is course/lifecycle evidence, not native or registered-client acceptance.

The separate native trace native-surf-result.json uses the real production World, R6 physics, Session, Director, Invader AI, authored launchers and BigBlag AI on real Heartbeats. Its solo hero starts at the authored safe spawn with rawLife47/three reserves and reaches Director Won on attempt1, still rawLife47/three reserves, with zero Hit or Death events. Accepted ordinary inputs defeat the Invader, board, jump, complete Surf and defeat BigBlag. The isolated world usesZ49152/Y32, and constructor Lighting/Atmosphere values are restored synchronously before yielding. This prepared solo server fixture does not establish registered clients, latency/device behavior, a native cohort restart or a continuous full campaign. All owned native world/module/fixture objects were removed after export.

Reproduce from the repository root with the bundled Luau executable:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-surf-qa-recovery/probe-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-surf-qa-recovery/probe-fixed.luau
```

The baseline exits1 with25 failing cases; repaired exits0 with54 passing cases. Both import pinned QA policy snapshots from this directory and current production modules from the repository; regression-summary.json records the tested production build7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a and hashes. Native reproduction sources are native_campaign_scene_runner.server.luau and install_native_surf_campaign.py; the Python script generates an MCP payload and does not launch Studio. Execute the generated payload only in the authorized main Play Server. The prepared-inputs receipt pins the exact native policy and runner sources.
