# Ordinary keyboard route — 2026-11-08

**Partial route result; full route NOT PASS.** This historical run predates the walk/run controls feature. A fresh solo game cleared zones 1–3 and crossed the Aqueduct gap three times, then lost its first life at the zone 4 cliffs. The run stopped when the user requested running and native touch controls; subsequent evidence belongs in [2026-11-09-running-controls](../2026-11-09-running-controls/).

## Recorded build and run

The identities below come from [fresh-route-before-running.json](fresh-route-before-running.json) and [validation.json](validation.json).

| Item | Recorded value |
| --- | --- |
| Run | `1140dbeb-8b8b-4d28-ae9b-8a7f38021395` |
| Production source SHA-256 | `ffb88bc24d0ea80d578a3dd5b4929dc1dbc4ee2124811bdcf7a239d8a64e0c13` |
| Playable SHA-256 | `4d84a7ae5bcd6c7cc30402c22ab26ab596cac2e16a685ae3468357cdc464d330` |
| Playable size | 404,113 bytes |
| Temporary route helper SHA-256 | `2290a2c3d18201faa9a2a17c324ffa5b1926c579ac6ef60a4c139e981cb0545b` |

The fresh game started through the ordinary UI and used ordinary keyboard input. Its preparation record states no health, life, position or kill writes, and no debug pauses during the attempt. Earlier diagnostic continuations are separate runs and must not be counted as this fresh attempt.

## Genuine jump support defect and correction

[forward-edge-failed-jump.json](forward-edge-failed-jump.json) preserves the earlier failure: the body was physically standing at approximately `X=48.385, Y=3` on a floor ending at `X=48`, with `FloorMaterial=Slate` and near-zero vertical velocity. The centre-only support ray missed the floor, and the coyote window had expired while the body still had physical support. Space produced no ascent, followed by a fall. This was a main-game jump eligibility defect.

GameWorld now checks the centre and eight footprint points derived from the actual root body's `Size` half-extents and horizontally projected `CFrame` axes. It adds no arbitrary support margin and does not derive support from cosmetic model bounds. Existing floor material, vertical velocity, surface, hazard, normal, consumed/rearm and grace checks remain in force. The geometry regression accepts the supported `X=48.385` case; facing along X, `X=48.5001` lies outside the relevant body half-extent and is rejected. The recorded world suite contains 32 passing checks.

## Temporary keyboard helper corrections

The helper is a QA driver, separate from product controls. Its recorded 53 navigation checks cover these regressions:

- An R attack starts its timing when the actual keypress is observed, rather than when the command is queued. Delayed polling retains the intended target and does not retreat before firing or before follow-through. Missing observed input has a bounded timeout.
- Actor, attempt and phase changes invalidate queued controls; missing Space also stops at a bounded deadline.
- A client sample at about 0.35 seconds no longer declares a jump failure prematurely. Observation is bounded to two seconds and can confirm the correct grounded destination even when ascent samples were missed.

[reverse-gap-authoritative-observation.json](reverse-gap-authoritative-observation.json) retains the original false failure: the client helper reported no ascent, but server samples show the reverse jump reaching approximately `Y=10.19` and landing across the `X=48..53` gap. This establishes a timing mismatch in observation; it does not establish network shaping as its cause. [segment-1.json](segment-1.json), [grounded-edge-observation.json](grounded-edge-observation.json) and [partial-run-critical-journal.json](partial-run-critical-journal.json) retain earlier diagnostic evidence, with their own preparation and completeness limits.

## Fresh partial route outcome

The fresh run recorded three successful crossings of the **same Aqueduct gap**: forward, reverse, then forward. Their observed rises were approximately 7.25, 7.16 and 7.22 studs. Zones 1–3 were cleared before the first death.

At the cliffs, the next Space request was already late: its recorded start was `X=273.089, Y=-1.404`, `FloorMaterial=Air`, vertical velocity approximately `-40.91`. No ascent followed. This rejection was consistent with the actor already falling, rather than a repeat of the supported-overhang defect. The first fall spent one reserve, from 3 to 2; the final snapshot shows an alive replacement actor on attempt 2, with 2 reserves remaining, in zone 4 and stage `Route`.

The user cancelled the proposed nearest-safe-Z / align-before-edge trajectory selection. That later helper delta was reverted from 56 checks to the recorded 53, never entered this run, and was not added as automatic trajectory selection to the product.

## Validation boundary

[validation.json](validation.json) records 32/32 validation steps passing; [validation.txt](validation.txt) contains their command output. The embedded source receipt matches the source identity above, the playable matches its recorded artifact, and validation preserved the production sources. The starter place hash was unchanged before and after: `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`.

These are historical checks and a partial engine run. They do not establish full-route completion, boss victory, physical mobile-device acceptance, reconnect acceptance or multiplayer acceptance. No tests were rerun while assembling this report.
