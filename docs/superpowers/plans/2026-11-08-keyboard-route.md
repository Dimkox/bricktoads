# Ordinary-keyboard route continuation

Baseline: pushed67f5731; existing user starter remains dirty and excluded. Continue BT-25/26/61 acceptance through normal MCP keyboard → production client, with no health/life/position/kill commands. Existing partially played run is a diagnostic continuation, not a fresh full-route PASS.

- [x] Reproduce the delayed R queue/retreat error, grounded edge overhang, stale phase/body input and missing-key wait. Fix only the temporary planner with native RED→GREEN regressions.
- [x] Confirm a real right→left48–53 gap crossing on the server. Correct the client's false0.35s failure classification using bounded2s observation; preserve raw trajectories and timestamp correlation.
- [x] Fix the genuine main-game jump support defect: a physically standing body atX48.385 on the48edge has FloorMaterial Slate but the centre-only support ray rejects Space. Derive inset support rays from the actual collider footprint; preserve geometry/Hazard/normal, vertical, consumed/rearm and grace rules. Meaningful geometry-based RED→GREEN and independent review precede delivery.
- [x] Build and verify exact production sources, synchronize Studio, then run a fresh ordinary solo attempt without debug pauses or resource/position helpers. Record actual outcome; prepared cases and partial runs do not substitute for a full-route result.
- [x] Complete focused/full checks, push the existing branch, update PR3 and Jira with exact evidence. Keep physical-device/reconnect/multiplayer criteria open until actually checked.

Network diagnostic at the observed false failure: all six shaping values and IncomingReplicationLag0, measured client ping1.868ms. Delayed tool/replication observations are possible; no network setting was changed and no cause beyond the recorded timing mismatch is asserted.

Outcome: footprint regressions and a fresh ordinary-keyboard attempt completed. That attempt cleared zones1–3, crossed the same Aqueduct gap three times and lost its first life in zone4; it is NOT a full-route PASS. The user cancelled the last trajectory helper delta and requested running/mobile input next. See the report README and 2026-11-09-running-controls for the delivered continuation and open acceptance boundaries.
