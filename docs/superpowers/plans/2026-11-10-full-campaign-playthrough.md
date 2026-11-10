# Full thirteen-stage Studio playthrough

**Request:** A complete thirteen-level Studio campaign run, remaining mechanical fixes, Git push and Jira evidence.

**Acceptance:** One ordinary campaign from Start through final Won, preserving its run identity, fixed cohort, level epochs and each hero's carried respawn stock. Authored hazards, ordinary AI and NPC boss behavior remain active. Drive connected Studio clients' existing intent senders; no actor teleport, health/stock write, direct enemy kill, manual phase/completion flag, skipped gate or paused boss is a successful playthrough.

**QA instrumentation:** Local disposable Studio copy only. A read-only runtime reference export enables a test planner to inspect the current scene. A client-only test input adapter shares the production sender/sequence/RemoteEvent; this establishes automated client intent acceptance, not physical keyboard/touch input. Read-only traversal/combat policies live in tools/qa and never enter the production build. Ordinary foot crossings use the existing test navigation module. Production player route choices are unchanged.

## Steps

- [x] Prepare and verify disjoint QA policies for early courses, late courses and combat, including coarse native input cadence and independent review.
- [ ] Run the native Play client through the campaign; record stage exits, accepted inputs, deaths, stock, identity, NPC/boss state, fault and final result. Diagnose failed attempts as pilot behavior versus reproduced production defects.
- [ ] Reproduce mechanical defects before fixes; preserve normal resource and geometry authority; repeat affected acceptance and the complete route as needed.
- [ ] Independent review, full frozen-source tests/build/compile and protected-file checks.
- [ ] Save exact verified production changes to the existing private Studio; deliver Git push, CI and Jira with the actual achieved coverage and remaining limits.

Preserve protected dirty places/BrickToads.rbxlx SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and concurrent concept art. Continue codex/walker-strikes at37ac199. No public publishing or fake actual-user reconnect proof; the second real account remains unavailable.
