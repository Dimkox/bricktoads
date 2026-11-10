# Ice co-op and race retry implementation plan

**Goal:** Correct confirmed stage4 block collisions/carry and stage10 retry deadlock and stage11 endpoint collision bypass; verify stages8/9 natively.

**Architecture:** Preserve server-owned Modes/Session/World. Resolve authored X block pushes and solid Z faces, deliver each accepted block displacement once to every supported living rider independently of cohort order. Snapshot fixed-cohort attempts before Race bomb failure applies deaths; Session alone commits and charges retries. Clamp shared Clinger chase progress to the finite authored path length so endpoint collision uses the same coordinate as its rendered body. Keep native acceptance in an isolated test helper.

**Spec:** Existing research/2026-11-09-campaign-courses.md and Jira BT-33/BT-26. These are corrections to implemented mechanics, with no new gameplay decisions.

## Constraints

- Continue authorized branch codex/walker-strikes in the shared bricktoads checkout; agents own disjoint files. Preserve protected starter SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and concurrent concept art.
- No automatic player navigation, safer route selection, balance/art/access/public-release changes or new enemy lives.
- No resource/health/identity writes in live probes. Prepared stage/pose/time setup is disclosed separately from ordinary subsequent input.
- No fake actual-user rejoin; second genuine account remains unavailable.

## Tasks

- [x] Ice RED regressions: rider before/after pusher, both Z faces; keep X pushing within authored min/max. Implement accepted-delta carry once per supported rider, solid Z collision and coherent native poses.
- [x] Race RED regression with real Session death already pending at rat bomb contact; next committed attempt must clear failed state, spend exactly one stock and permit defuse. Preserve zero-stock elimination/offline waiting/cohort retry behavior.
- [x] Clinger RED real-Session regression: idle/shield overtake then ordinary current-segment inputs must encounter the visible endpoint pursuer instead of earning a course clear; preserve initial negative chase gap, existing shield and chaseFinished rules.
- [x] Independently review the patches; run existing mode/race/progression and full frozen-source verification/build/compile.
- [x] Native Studio acceptance on exact saved build: Ice both cohort orderings and both Z faces with Models/support/carry; Race pending-death retry through real Session; Ascent lift/fan, Tubes oxygen/surface and Clinger corner/current-control scope as feasible. Verify cleanup and distinguish synthetic server roster from network/device acceptance.
- [x] Sync changed modules/derived BuildInfo into existing private Studio after verifying baseline sources. Save private version, close owned helper, prepare coverage/report and authorized Git/Jira delivery. External commit/push/CI/Jira receipts live in the delivery response.

## Review focus

No double carry for later riders; native/logical pose agreement for earlier riders; opposite depth directions/long steps and X limits; dying/offline/eliminated fixed-cohort members during race loss; no new spawn or stock charge from Race itself; accepted attacks/shields retain their existing rules.
