# Native20 Ice: independent read-only review

## Scope and disposition

Reviewed the frozen Ice motion, detail and 25 unthinned samples (414 unique logical mode frames) independently of the pilot owner. No Studio actions, production source changes, pilot changes, state/resource writes or extra windows were used for this review.

Native20 run: `b280d913-e985-4f4d-a190-d80e85728ea0`; campaign seed: `1158731273`; one real hero owner: `11946162891`. Production source remains `7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a`. Ice pilot E7 SHA256: `e7c8152f21d45b281ca75150c39e1f78ff289c9bbce73f25945375f981b3037c`.

Ice was earned by ordinary inputs on attempt 4 after three confirmed Falls spent the three carried reserves. This is not a zero-death Ice pass or full-campaign acceptance. E7's preceding bounded numeric GREEN did not model the observed steering delivery delay. The actual accepted-input evidence supports improving the QA transport/forecast fidelity before making another pilot claim. It does not justify changing production jumping, reactions, shields, trajectory selection or resource rules.

All relative clocks below use the first Ice decision/stage observation `1794331261.403079` as +0. This is a QA observation origin, not the exact initial Modes elapsed clock.

## Exact native chronology

| Event | Stage-relative time | Position / outcome |
| --- | ---: | --- |
| Attempt 1 Icicle Hit | +13.050700903 | `(288.008545, 3, -3.840055)`, synthetic attacker -9001, Dash/profile 22, Life47→31 |
| Attempt 1 ConfirmedDeath | +14.285264015 | CampaignFall at `(313.232300, -58.749043, -9.808480)` |
| Attempt 2 CommitSpawn | +14.302496910 | Checkpoint 3, actor132, stock2, normal shield |
| Attempt 2 Snowball Hit | +14.834720850 | `(219.039352, 5, 0)`, shield blocks HP damage47→47, reaction still occurs |
| Attempt 2 ConfirmedDeath | +16.284121037 | CampaignFall at `(229.621490, -59.373310, 0)` |
| Attempt 3 CommitSpawn | +16.299789906 | Checkpoint 3, actor136, stock1, normal shield |
| Attempt 3 first Snowball Hit | +16.333441019 | `(218, 5, 0)`, shield blocks HP damage; before first QA decision for the body |
| Attempt 3 first QA decision | +16.351086855 | Ordinary move plan; the preceding Hit already suppressed control |
| Attempt 3 accepted Jump | +17.649570942 | Ordinary CampaignJump, no pose/state override |
| Attempt 3 second Snowball Hit | +17.717091084 | `(219.925735, 7.335979, -1.925732)`, shield blocks HP damage; airborne reaction |
| Attempt 3 ConfirmedDeath | +18.983824015 | CampaignFall at `(228.145187, -59.667034, -8.073796)` |
| Attempt 4 CommitSpawn | +19.000490904 | Checkpoint 3, actor141, stock0 |
| Attempt 4 Snowball Hit | +19.333886862 | Shield blocks HP damage; body ultimately survives |
| CampaignCourseCleared | +25.016167879 | Ordinary Ice completion, actor141/attempt4/stock0 |

The -9001 Hit rows record `impulse=true` as the requested combat response. They do not prove that a logical Modes knockback was applied. GameWorld has no corresponding attacker body/direction for -9001 and falls back to the base implementation for the anchored course body. The logical frames instead directly demonstrate reaction/input reset and retained Ice momentum. This distinction must be preserved in summaries.

## Accepted input establishes a missing queue in the numeric proof

The numeric NPC probe calls `Pilot.plan`, then sends ordinary Session Move/Jump synchronously at the same numeric `now`, then advances Session and CampaignDirector. The Studio adapter invokes the server planner, waits for the reply, updates its current plan and sends via the production RemoteEvent. Non-action Move is gated by 0.06 seconds, while the existing RenderStepped sender also resends the current move. Move/Jump on a jump plan are forced. Consequently the numeric zero-delay boundary is materially different from the native accepted boundary.

Concrete native evidence before the first Icicle Hit, with no active reaction:

- Decision +11.416586 returned `(x=0.9575013853, z=+0.2884286691)`. Its observed accepted Modes input timestamp was +11.583351: **166.765 ms after planning**; Session's accepted lastMove timestamp was +11.599813.
- Decision +11.549644 changed steering to `(0.7071067812, -0.7071067812)`. At frame +11.692993, the accepted axes still had the preceding **positive** `z=+0.2884286691`. The body was `(253.704897,3,-4.673667)` with logical `vz=+9.579692`.
- At frame +11.752695 the negative steering had finally been accepted, with Modes input timestamp +11.734438 and Session lastMove +11.750366. Relative to the first negative plan these are **184.794 ms** and **200.722 ms**, respectively. The frame's repeated jump plan has the same axes, so matching only the latest identical plan would incorrectly report a 35 ms lag and hide the earlier queued change.
- That held positive lateral momentum carries the body to approximately `z=-1.046` at `x=271.439`, despite the negative steering plans. At +13.0505, before the Hit, the body is `(288.009,3,-3.840)` with `vx=24.827`, `vz=-7.656`; it has not reached the required clearance from the final Icicle centered at `z=0`.

The first actual Hit at +13.050700903 resets accepted axes to zero and starts reaction through +13.800701. Plans request Jump at +13.2503 and +13.3848, but the logical input remains zero. At +13.4348 the body is already past floor8's `X=296` edge and below its top, so it cannot jump the next gap. This is an observed input/forecast failure, not evidence of a lateral floor-support defect.

Independent bounded crosscheck: the unchanged E7 numeric NPC fixture on the **new Native20 seed1158731273**, initialZ=-6, startup delay0, cadences0.1/0.133/0.167, passes all three cases with Life47, original actor/attempt1 and all reserves. Therefore seed mismatch alone does not explain Native20; the synchronous fixture still misses the native failure on that seed. This three-case check is not a delayed-input or native reproduction.

## Native20 authored geometry

Definition.build(4,1158731273) produces:

- Floor6: X189–222, top5, Z-15–15; CP3 `(218,5,0)`.
- Floor7: X226–259, top3, Z-15–15; Spike at `(246.5,2.5,9)`.
- Floor8: X263–296, top3, Z-15–15; final Icicle at `(292,5,0)`, dimensions4×6×7, Y-motion amplitude4/period3/phase8.
- Floor9: X300–333, top5, Z-15–15.
- CP3 Snowball: `(218,5,0)`, dimensions4×6×7, Z-motion amplitude10/period3/phase6.

All three deaths leave longitudinal platform ends/gaps. The observed lateral coordinates remain inside the authored platform depth while the relevant support exists.

## CP3 third spawn: quick sweep, not demonstrated instant overlap

CommitSpawn occurs at +16.299789906. The first Hit is only **33.651113 ms later**, before the first decision at +16.351086855. This is actual pre-input exposure, not a planner error in an already-issued command.

However the frozen frames do **not** establish that the spawn was instantaneously embedded in the Snowball:

- At observer +16.333337069, Modes `now` is +16.316788912 and Modes elapsed is `16.395848988089714`. The new body remains `(218,5,0)`, grounded on floor6, accepted axes zero, no reaction and no prior plan.
- Source motion formula gives Snowball Z `10*sin(elapsed/3*2*pi+6) = +4.8058236887` at that mode frame. Source swept collision expands its half-depth3.5 by BODY.z1.2: contact threshold4.7. The body is still **0.1058236887 studs outside** contact.
- Snowball Z is monotonically decreasing over this short interval. The earlier placement/commit phase has greater separation; interpolating adjacent clocks suggests approximately5.115 studs after the commit heartbeat, but that estimate is not an independently captured placement sample. The following heartbeat sweeps the Snowball into the stationary body.

The exact safe-point code checks geometry at placement, not a guaranteed future hazard-free interval: RobloxWorld:isSafe validates five floor rays and collidable AABB occupancy; GameWorld:findSafe changes its search origin to the checkpoint and delegates/revalidates. CampaignModes renders course hazards as noncollidable, nonquery objects and checks their active analytic collision separately in `_hazards`. Thus the placement query does not consult active analytic course hazards. The repository lifecycle specification requires adapter safety/occupancy checks, while the stand specification explicitly makes the normal two-second shield damage-only; no stationary future-clearance horizon was found in those contracts.

Disposition: preserve the 33 ms pre-input sweep as a real respawn usability observation. Native20 alone does not prove instant unsafe embedding, an expired/incorrect shield, or a contract requiring two seconds free of environmental reaction. Do not change shield/impulse/combat rules on this evidence.

## Follow-up: independent queued-input candidate review

Reviewed frozen QA-only candidate `1d5693ed7ed9089a7c645c8bf4f3b8b2578fe169dd758f316c47f9b51a280695` against exact E7 baseline. Its five changed lines are confined to Ice: matching lateral steering/forecast coefficients and a cadence/speed-based ordinary jump lead. Rope and all other branches are byte-identical outside the Ice region. No production source, actor pose, health, reserve, completion, AI or phase writes are introduced.

Independently reran `reports/2026-11-10-ice20-queued-input/probe-queued-{baseline,candidate}.luau` and compiled the working pilot:

| Check | Exact E7 baseline | Candidate1D5693 |
| --- | ---: | ---: |
| New-seed queued matrix: cadences0.133/0.167/0.2 × regular holds0.133/0.167/0.2 | 5 PASS, 4 FAIL | 9 PASS, 0 FAIL |
| Successful candidate resource outcome | — | All9 Life47, original actor/attempt1, reserves3 |
| Luau compilation | — | Exit0 |

The fixture delivers due ordinary packets before planning, then steps the real Session/CampaignDirector/Modes/NPC modules. Urgent Move/Jump uses a two-frame delay; a newer accepted urgent plan supersedes older delayed regular plans outside the production source. The fixture does not change game state to produce success.

Important reproduction limit: this fixed-hold queue is an abstraction, not an exact trace replay of native RenderStepped resend/gating and RPC timing. All three E7 cases at cadence0.133 already pass; the matching final-Icicle failure appears at the conservative cadence0.2/hold0.2 case, with Hit at13.45 seconds, `(288.681135,3,-3.482303)`, followed by a Fall nearX313. This reproduces the hazard/reaction/gap mechanism under delayed input but does not establish an exact replay of Native20's varying0.116–0.149-second decision cadence.

Disposition: **CLEAR for the next bounded ordinary Studio verification**, with no claim that Native20 is exactly replayed or that all13/full native playthrough is fixed. The CP3 quick-sweep observation and production mechanics remain unchanged.

## Evidence and limits

Primary files: `attempt-20-ice-detail.json`, `attempt-20-ice-motion.json`, `attempt-20-ice-samples.json`. Relevant source: `tools/qa/full_campaign_client_adapter.luau`; `src/stand/server/Session.lua`; `src/stand/server/RobloxWorld.lua`; `src/server/gameplay/CampaignModes.lua`; `src/server/gameplay/GameWorld.lua`; `src/server/gameplay/CampaignWorld.lua`.

This review establishes the actual accepted-input lag and native causal sequence. It does not claim a fully faithful network simulation, all-seed safety, zero-death Ice, multiplayer acceptance, full13 Won, or a production fix. The next queued-input QA candidate requires its own red/green proof, scope review and a fresh ordinary Studio run.
