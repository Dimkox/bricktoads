# Brick Toads

Playable Roblox prototype: choose Mr. Green, Mr. Yellow or Mr. Brown, clear the original 3D causeway, defeat its guardian by reflecting three projectiles, and reach the exit.

## Play

Open `places/BrickToadsPlayable.rbxlx` in Roblox Studio and press Play. The level is generated when the server starts. Choose **Герой**, **Противник** or **Наблюдать**. The first selected hero presses **Начать игру**. Solo, duo and trio start immediately; identical hero choices are allowed.

Use **Группы** / **Выбрать команду** to create an independent team or join another. Up to four local teams can play in separate arenas on one server. Joining an active team observes its existing run; it never adds a hero. A living or awaiting-respawn character keeps its role. After elimination you may create a new team or manually choose an eligible ordinary enemy in another group. Your old group's elimination/spent-life history stays intact when you return.

- **WASD** — move and face a direction.
- **F** — punch; **R** — heavy strike; **Space** — jump.
- Touch devices have a movement stick and attack/jump buttons.
- Heroes have five hearts and three successful respawns. A living hero with zero respawns can keep playing.
- Ordinary sentries have three hearts and one life. Clear both encounters to open the guardian arena.
- To play an enemy, choose **Противник**, wait for the hero to start, then select an available sentry. You take its existing body and current health. Move/jump normally and use **F** or the attack button for its ordinary strike; the hero's heavy strike is unavailable.
- A sentry becomes unavailable after its first accepted attack or an accepted hero attack directed at it, including a miss. A dead human enemy cannot take another sentry in this run/level. A separate new game resets that limit.
- To play the guardian, open **ОЧЕРЕДЬ БОССА** in the menu or observer HUD and press **Ждать стража**. This removes you from the next hero roster. Invitations follow FIFO; answer within10 seconds. After acceptance the current client acknowledges readiness automatically, with a separate15-second connection deadline.
- Declining or missing an invitation moves you to the queue tail for a future assignment. Cancel explicitly to leave. A successful ordinary-enemy claim cancels waiting; an accepted guardian reserve must be cancelled before claiming a sentry.
- The reserved guardian appears after the ordinary encounters. Without an accepted ready player it uses NPC control after pending invitations finish. A human guardian uses **WASD**/the touch stick to aim and **F**/**СНАРЯД** to fire the same projectile, with the same cooldown and three-reflection defeat condition. It has no hero heavy strike or jump. Disconnect preserves its body and health while accepted projectiles and physics continue.
- After final elimination, choose **Наблюдать** or **В основное меню**. The personal menu has **Вернуться к наблюдению** while the same group continues; it does not restore a body, health or respawns.
- Spectators can switch the followed hero or use the free camera inside the level bounds. Free camera: **WASD** to move, **Q/E** for height, right mouse drag for direction. Touch has a camera stick and height/turn buttons.
- Reflect the guardian's orange projectiles with an attack. Three returned projectiles open the exit.
- Victory/defeat returns to the selection screen. The host starts the next game manually.
- Each group's victory/defeat and restart are independent. Guardian waiting is shared across groups; an invitation names its target team, and accepting transfers only the invited observer to that team.

All three templates have the same capabilities. The server fixes the 1–3 hero roster at Start; later arrivals spectate this run. Health, collisions, enemy AI, projectiles and respawns are server-owned.

The spectator/menu flow was checked through Studio MCP with four real clients, including an eliminated hero, a dead human enemy and a continuing teammate. Camera bounds and iPhone 17 Pro landscape emulation were checked; this does not establish physical phone/tablet acceptance. Evidence: [spectator camera report](reports/2026-11-07-spectator-menu-camera/README.md).

This is an original playable prototype. Enemy damage, timing, geometry and the boss adaptation remain provisional. Ordinary human-enemy control, the guardian queue and up to four independent local groups are implemented for the current level. Multiple levels, cross-server boss routing and complete source-mechanics transfer remain outstanding. This does not implement cross-server discovery. Additional enemy combat abilities are deferred at the user's request. Actual same-server reconnect remains unconfirmed; its earlier transport report is separate from this game's playability.

Guardian acceptance used three real Studio clients for FIFO/decline/accept, then two clients for mobile invitation, human projectile control, three real reflected hits and the unlocked exit. Ordinary NPCs were held/killed and the hero relocated to isolate that encounter; this was not an unprepared full-level run. See [boss role evidence](reports/2026-11-07-boss-role-queue/README.md).

Independent-group acceptance used four Studio clients and three actual runs. It verified elimination/new game, isolated loss, another group's existing enemy, shared guardian assignment and a reflected projectile in the translated arena. The group selector was checked in phone emulation. See [group evidence](reports/2026-11-07-independent-groups/README.md).

## Source structure

```text
bricktoads/
  src/server/gameplay/     # game controller, encounters, original world and calibration
  src/server/             # main entry point and verified RunLifecycle
  src/client/             # selection, HUD, camera, keyboard/touch input
  src/shared/             # public project metadata
  src/stand/              # independent combat stand and shared private combat implementations
  places/BrickToadsPlayable.rbxlx
  tests/gameplay/         # encounter and main-game authority contracts
  tools/                  # deterministic builders
```

The main builder embeds the existing Combat, Session, Config, ConnectionRegistry and RobloxWorld sources in a private CombatRuntime folder. It excludes the stand entry point and all diagnostics/test drivers. Source implementations are shared, not copied.

`places/BrickToads.rbxlx` is the previous starter snapshot. Its existing local edits are preserved. The playable builder writes the separately named file above.

## Build and verify

Use Python3.10+ and native Luau0.745. Portable executables in this Windows workspace are under `.tools/python-3.13.9/` and `.tools/luau-0.745/`.

```sh
python tools/build_bricktoads_place.py
python tools/build_bricktoads_place.py --check
python tools/test_bricktoads_place.py
luau tests/run_gameplay.luau
luau tests/run.luau
luau tests/run_stand.luau
luau tests/run_connections.luau
luau tests/run_groups.luau
python tests/group_world/run.py
python tools/test_stand_gateway.py --luau <path-to-luau>
```

To open the separate combat stand: `python tools/build_combat_stand.py` → `build/CombatStand.rbxlx`. Its [runbook](docs/stand/RUNBOOK.md) and archived evidence remain available. No source ROM, extracted art/audio or external asset uploads are included.
