# Scooter enemy and crash network acceptance plan

> **For agentic workers:** Execute with subagent-driven development. Track completed steps below.

**Goal:** Verify real-client Invader/RocketRat control and native scooter crashes, then push verified results and update BT-27/BT-29.

**Architecture:** Reuse the actual StudioTestService client bridge, render-readiness barrier and production Intent/State driver. Add a separate tagged role/crash harness and launcher; retain the prior solo/duo/trio receipts unchanged. Prepare only the run/seed/stage, then earn movement, actions, contacts and lifecycle results through real clients and the native controller.

**Tech stack:** Roblox Studio MCP, Luau0.745 compiler/regression CLI, Studio0.746, Git/GitHub and Jira.

**Spec:** `docs/SCOOTER_EPISODE.md`; user request to check enemy control and crashes with actual clients.

## Constraints and review focus

- Keep the user's `places/BrickToads.rbxlx` SHA-256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` unchanged and unstaged; original Studio67/PID24008 untouched.
- Production base source `b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff`; assert exact expected BuildId and actual current Player instances.
- Do not write health, lives, poses or forced outcomes during unprepared live scenarios. Label any separately prepared boundary explicitly.
- Distinguish client transmission from accepted server action; prove claim preserves the actual enemy body and finite one-life/one-drop budget.
- Observe native Stopped/rewind/Riding and charge only collided heroes; preserve survivor bodies/health/stock. No global stock reset or new enemy life from rewind.
- Bound tests and preserve failures; restore/close owned helpers only. No physical mobile, impaired-network or public-ready claims from local clients.

## Task1 — Role/crash driver and harness

Files: new `tools/studio_scooter_role_network_acceptance.luau`, `tools/studio_launch_scooter_role_network.luau`; extend `tests/scooter_network/Client.client.luau` only where actual role diagnostics require it.

- [x] Define exact Invader, HeroCrash and RocketRat scenarios against current runtime policies.
- [x] Verify actual enemy envelopes and identity reset using the actual client source; compile client/helpers and retain existing readiness regression.
- [x] Review readiness, same-body claim, collision causality, stock accounting and bounded EndTest cleanup before claiming acceptance.

## Task2 — Native actual-client runs

- [x] Launch a fresh owned copy of `places/BrickToadsPlayable.rbxlx`; inject test-only modules and hook without saving production files.
- [x] Invader: real Enemy client claims the existing body, moves and uses primary; observe raw8 theft and return/finite escape as separate outcomes where needed.
- [x] HeroCrash: a real hero deliberately steers into authored danger while actual teammates continue; observe crash, shared rewind, paid replacement and survivor preservation.
- [x] RocketRat: real Enemy client claims the naturally spawned rat, uses its one drop and receives NO_AMMO on repeat; verify obstacle contact/cleanup and lifecycle effects or retain an explicit failure.
- [x] Save original full JSON receipts, version/source/network settings and concise causal summaries under a new dated report.

## Task3 — Fix demonstrated defects, if any

- [x] Trace a reproducible failure to driver or production code before editing; add a meaningful RED/GREEN check for production fixes.
- [x] Rebuild and repeat only affected native scenarios when the packaged source changes. Preserve earlier results with their original source.

## Task4 — Delivery

- [x] Independently review final claims against raw receipts, check protected-file hash, close owned test processes and preserve original Studio.
- [x] Push the scoped commit, verify current-head CI and update PR/Jira with exact achieved coverage and remaining criteria. Delivered in `5451f1d`; both workflows passed, Jira comments10446/10447 recorded the results.
