# Rope, riding and Serpents acceptance plan

**Goal:** Continue the existing course implementation with focused stages2/5/6/7 checks and correct confirmed lifecycle defects, then deliver Git and Jira evidence.

**Existing scope:** The authored original Roblox courses and Session resource rules in research/2026-11-09-campaign-courses.md. No automatic route selection, balance/art changes, public release or new reconnect claim. Continue the shared codex/walker-strikes checkout and preserve the protected starter and concurrent concept art.

## Confirmed defect

If the last mounted hero exhausts their stock while another fixed-cohort hero is still on foot, vehicle retry detection ignores the living foot hero. Surf/Jet/Speeder enter Lost despite an Active Session. Later valid boarding cannot leave Lost. Retry eligibility should include every unfinished living or pending-respawn cohort actor; only Session may commit another attempt or spend stock. Existing stop/rewind/restart handles the late boarder.

## Work

- [x] Capture a failing real-Session regression for late boarding in stages3/5/7, including exhausted actors and genuine run loss.
- [x] Correct retry eligibility and verify unchanged resource ownership, normal co-op rewinds and boarding gates.
- [x] Native prepared acceptance for Rope descent/swing/checkpoint/kick, Surf/Jet late boarding and restart, and Serpents support carry/room checkpoint/paid respawn. Keep exact fixture boundaries and strict cleanup in each helper.
- [x] Independent review, complete frozen-source tests/build/compile, exact playable/source checks and protected starter check.
- [x] Sync changed modules and BuildInfo into the existing private Studio after checking its baseline, save privately, close only owned helper and prepare Git/Jira delivery evidence. External push/CI/Jira outcomes are recorded in the delivery message and Jira comments.

## Acceptance boundary

Native fixture checks use synthetic server rosters and selected authored poses/phases. They establish native Model/control/lifecycle behavior for named cases, without claiming network, physical-device, unprepared full-route or complete production acceptance. Actual same-account live rejoin still needs the unavailable second real account.
