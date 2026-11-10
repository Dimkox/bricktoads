# All boss phases and reaction/input deadlines

**Goal:** Verify every implemented phase of the six encounters, including full Life/progress depletion and both attack families, and correct reproduced deadline bugs. Continue the shared codex/walker-strikes branch at2e0047f; no new balance, art, navigation, resource or public-release decisions.

**Confirmed defects:** Session resolves due attacks before the director step. An expired boss Reaction therefore used stale Life/heavy state for selection or hit validation, making identical timestamps depend on update order. Human campaign boss Move also had no server-side expiry in the actual director/boss loop; one accepted input could persist indefinitely.

**Architecture:** Reconcile only overdue reaction recovery before action selection, hit validation and human commands, sharing the same helper with step and without running NPC AI. Record accepted boss movement timestamps and clear voluntary input at the existing MoveTimeout; accepted scripted attacks and physical impulses retain their existing rules.

## Work

- [x] Capture RED reaction-expiry regressions across all five campaign bosses and both controllers, plus real Director movement timeout cases.
- [x] Implement bounded deadline corrections and verify live combos, heavy armor, legitimate move refreshes, stale/offline rejection and accepted attack continuation.
- [x] Native phase matrices: Guardian assignment/intro/Bullet/Heavy/Ground/Carried/Thrown/three returns/Exit; Big Blag C0/80 phases; Buzzball chase handoff and80 threshold; Robo/General/Queen progress120/240 and terminal underflow. Drive boss damage through actual Session actions and retain bodies/resources except legitimate paid respawns.
- [x] Independent review, full frozen-source tests/build/compile, source/playable match and protected starter hash.
- [x] Sync changed modules and BuildInfo after checking the private Studio baseline, save privately, close owned helper and prepare Git/Jira evidence. Push/CI/Jira receipts are recorded externally to the report.

**Acceptance boundary:** Prepared gates, starting stances and virtual time are disclosed; synthetic owners are not real network clients. Native phase checks are not natural full-route playthroughs or source-perfect timing/animation proof. Actual same-account return still requires the unavailable second account. Preserve dirty places/BrickToads.rbxlx SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and concurrent concept art.
