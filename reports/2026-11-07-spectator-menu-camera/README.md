# Spectator camera and personal menu — 2026-11-07

An eliminated hero or observer can follow the surviving heroes, switch targets, use a bounded free camera, enter a personal menu and return to the same ongoing game. A dead human enemy gets the same view choice without regaining its spent life. Living or awaiting-respawn heroes and living human enemies cannot use this menu to suspend their bodies.

## Implementation and authority

`ChooseView` accepts only the current connection and the active run/level context. An eliminated hero uses the existing lifecycle event; other observers have server-owned choices keyed by user. Replacing the connection object preserves a choice. A separate accepted new game resets it; claiming an available enemy becomes Playing. Personal menu/return does not recreate a hero, reopen roster slots, heal, refill respawns, clear enemy life use or finish the group. The active-run menu hides the new-game action.

`SpectatorCamera.luau` contains presentation only and has no remotes. Follow targets include living offline bodies and living zero-heart bodies while they are not in a death reaction. Absent, eliminated and dying targets are skipped. Free camera clamps its actual position to bounds derived from the main level's floor geometry: X[-94,136], Y[7,52], Z[-49,49]. A new run/level resets the camera context.

## Studio MCP evidence

Roblox Studio 0.746.0.7461269, private test place117412694427208, universe10775039796. Tests used Studio's real four-client/server sessions. Sources were injected into the main Edit DataModel, including the new camera ModuleScript. No test driver is embedded in the playable artifact.

The detailed checkpoints are in [four-client-evidence.json](four-client-evidence.json). Run `ce43a715-39b2-46c0-9644-d4c1ccf45a9d` had three heroes and a fourth player who selected Spectator before Start. Both NPC roots were temporarily anchored to isolate view testing. Hero1 was moved below the kill plane four times; normal death/respawn handling exhausted its three reserves, then eliminated it on attempt4. Health and reserves were not edited directly. These are prepared-scene checks, not a full four-player level walkthrough.

| Check | Observed result |
|---|---|
| Eliminated hero chooses Watch | Choice→Spectating, same run, no actor, raw0/reserves0 |
| Next hero twice | Camera followed slots3 and2; measured distance0 to each expected root offset |
| Personal menu | Server view Menu; return action visible; Start hidden |
| Teammate keeps playing | Hero2 moved and struck through real keyboard input; NPC1 hearts3→1 while hero1 stayed Menu. Hero2 retained actor/health/reserves; run stayed Active |
| Return from menu | Same run and elimination history; view Spectating |
| Six free-camera limits | Real keyboard input reached actual camera positions (136,52,49) and(-94,7,-49) |
| Menu entered from enemy offers | Return clears the chooser and restores Follow controls |
| Dead human enemy | Observer claimed existing NPC2, hero2 killed it with actual attacks; Choice→Menu→Spectating preserved Dead. Claiming NPC1 afterward returned ENEMY_LIFE_SPENT |

### Phone emulation

iPhone17Pro LandscapeLeft, viewport750×381, safe frame750×323. Actual height/yaw button events and stick movement were checked. Up raised camera Y from28.000 to48.392; Right changed look X from−0.791 to−0.246; dragging the camera stick moved X/Z from(−64.999,37.000) to(−45.947,30.797), still within the bounds. The eliminated hero remained raw0/reserves0.

MCP automatic instance targeting initially missed the simulated safe-area coordinates: that initial Up attempt produced no movement and is retained as `upBefore/upAfter` in the evidence. After observing actual InputBegan coordinates, explicit MCP input coordinates hit Up/Right and the stick. The successful Up result is the subsequent `before` checkpoint at Y48.392, with the recorded Up event. This was a tool targeting correction, not a gameplay-state mutation.

A fresh four-client run verified the final compact layout after the visual correction. [final-phone-layout.json](final-phone-layout.json) records panel(134,189,482,122), roster(18,18,292,150), objective(328,18,404,92), stick(18,207,104,104), axes(624,203,108,108). Runtime rectangle assertions and the screenshot confirmed no panel overlap with those elements. Next/Free are223×44; height/yaw buttons50×50. Text labels ЛЕВО/ПРАВО replace unsupported arrow glyphs. The simulator was restored to default and both test sessions ended.

## Verification and limits

[verification.json](verification.json) records the fresh native suites, compiler and deterministic builds. Review found and fixed the chooser-return bug and the zero-heart follow-target filter; a regression test calls the actual camera module. Native controller tests cover malformed/stale run/level payloads, current Player ownership, living-role denials, duplicate views, replacement connection persistence, new-run reset and resource preservation. These contract checks are not presented as an actual same-account reconnect or an engine multi-level transition.

Physical phone/tablet testing, complete source movement/camera calibration, multiple groups/levels, boss role queues and real same-account reconnect remain outside this slice. BT-15/BT-19/BT-64 remain in progress because their full acceptance criteria extend beyond this implementation. The previous user-modified `places/BrickToads.rbxlx` is preserved outside the commit; the build writes `places/BrickToadsPlayable.rbxlx`.
