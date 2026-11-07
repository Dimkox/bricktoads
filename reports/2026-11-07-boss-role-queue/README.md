# Guardian role and queue — 2026-11-07

Implements the local causeway guardian selection described by BT-23 and BT-10 D-07. The server owns FIFO, invitation tokens, strict10-second response deadlines, separate15-second accepted connection deadlines, ordinary-role exclusion, actor identity and encounter ownership. Queue state survives a separate new run; accepted/active assignments do not auto-requeue. A cancelled/stale invitation cannot replace an active NPC.

## Tests and review

- Native BossQueue:20 passed, including signed Studio users, simultaneous slots, decline/exhaustion, cancellation/switch, strict deadline boundaries, stale clocks and close-at-expiry ordering.
- Native Director:30 passed; Controller:35 passed. Existing lifecycle46, Session38, ConnectionRegistry18, gateway14 and camera checks remain green. Builder structural/determinism suite:7 passed.
- Failing tests preceded implementation and subsequent fixes. Independent review identified an outbound projectile hitting after a reflected projectile killed the guardian within the same tick. The regression failed before the stage guard and passes afterward. Final targeted independent review found no P1/P2 issues.
- Live World identity assertion failed because enemyIdentity accepted only Drone. The final adapter accepts Boss, supplies its string ActorId and owner name, and the actual camera follows that actor. A native regression also proves that an accepted Ready owner disconnecting before spawn receives a disconnected guardian, with no heal on return.

## Studio evidence

Studio test place117412694427208; no public publication. Production scripts were injected into the unsaved Edit DataModel. Temporary hooks only observed State events and prepared the scene; they are not in the playable artifact.

The initial three-client run `684a630d-6d0a-4a85-99d8-14b032fdb2a4` verified real menu-button join by Player2, Player3 joining second, Player2 declining invitation1, Player3 receiving invitation2 and accepting through the actual button, followed by automatic ConnectBoss and Ready. While subsequent diagnostics ran, the unattended hero exhausted its reserves; that run does not prove the guardian fight. A prepared follow-up verified a human projectile but exposed the physical identity defect, prompting the final-source restart.

Final two-client run `de9e348b-04df-432b-9876-1c102ed7e0a0` used Player1 as the sole hero and Player2 as the selected guardian. Four ordinary NPCs were held in place and killed through their engine Humanoids to isolate the boss gate. The hero was relocated to x68 facing the guardian, then to the unlocked exit for result verification. Hero health, reserves, boss health, queue state and reflection results were not edited.

| Observation | Result |
|---|---|
| iPhone17Pro, LandscapeLeft | Actual viewport750×381; invitation card, two actions and spectator controls were visible without overlap |
| Acceptance | Automatic Ready acknowledgement; same run-bound offer became Active |
| Physical guardian | String ActorId `de9e348b-04df-432b-9876-1c102ed7e0a0:boss:1`, ControlledByPlayer=true, root unanchored |
| Client camera | Moved to guardian region (76.49,28.00,29.74); guardian HUD active, queue card hidden |
| Human attack | Actual F input created the configured projectile; NPC auto-fire stayed disabled |
| Hero reflection | Actual F input returned all three human-fired projectiles; guardian health3→2→1→0, same actor throughout |
| Defeat | Guardian status Dead, stage Exit, queue state None; no additional boss appeared |
| Result | Unlocked exit produced Won; hero retained rawLife47, five hearts, attempt1 and three reserves |

The final ready-owner presence change is covered by native regressions; the online Studio path above is unchanged. The Edit source is synchronized again before leaving the final playable menu.

## Limits

This is one local playable group with one prototype guardian identity and the existing three-reflection profile. It does not establish full NES mechanics, cross-server/global routing, multiple playable groups/levels, physical-device acceptance, actual same-user reconnect transport, or an unprepared full-level multiplayer walkthrough. No Jira issue is marked fully accepted by this slice.
