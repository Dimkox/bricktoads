# Spectator camera and personal menu

**Goal:** Let an eliminated participant or observer watch the continuing group with a bounded free camera, switch followed heroes, enter a personal menu, and return to that same run without changing gameplay resources.

**Authority:** Accepted BT-15/BT-19 rules. Continue the existing main project; preserve the user's local starter place. Push verified changes and update Jira after implementation.

## Contracts

- Intent `{kind='ChooseView',runId,levelEpoch,view='Menu'|'Spectating'}` is current-Player-only and scoped to the active run/level. Wrong/closed context changes nothing.
- Living/awaiting-respawn heroes and living human enemies cannot use the eliminated-player menu to suspend their bodies. Eliminated heroes use the existing Core.ChooseView event; observers/dead enemies have server-owned per-run view choices.
- Snapshot adds `view` (Playing/Choice/Spectating/Menu), `canChooseView`, `cameraBounds={minX,maxX,minY,maxY,minZ,maxZ}`. Session hero snapshots include existing Core view. A role claim becomes Playing; a new game resets choices. Connection-object replacement retains current run choices.
- Personal menu never dissolves the group, reopens a hero slot, heals, spends/refills respawns or clears enemy spent life. Returning to watch creates no actor. Group end still shows the shared result menu.
- Camera controls are client presentation only: follow/next hero or free camera bounded to this level. Free camera starts at the current view, uses keyboard/touch movement, height and yaw controls, and resets on a new run/level. It never sends combat commands.
- Alive offline heroes can be followed while their bodies remain; the camera skips absent/dead models. Personal menu has a clear return-to-observation action, and no active-run new-game control.

## Work

- [x] Server view authorization and persistence with failing-then-passing controller tests.
- [x] Client personal-menu/return flow, hero switching and bounded keyboard/touch free camera in SpectatorCamera.
- [x] World-derived bounds and main server integration; build and regression verification.
- [x] Studio MCP multi-client checks: eliminated hero watches/menu/returns while teammate continues; dead enemy keeps one-life limit; camera bounds and phone controls.
- [x] Code review fixes and evidence recorded in reports/2026-11-07-spectator-menu-camera/.

Delivery: push the verified snapshot on the existing feature branch, verify its remote checks and synchronize BT-15/BT-19/BT-64 with its resulting commit. These broader tasks remain in progress; physical-device acceptance, source calibration, multiple levels/groups and real same-account reconnect are not claimed.
