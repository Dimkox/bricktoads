# Brick Toads

Playable Roblox prototype: choose Mr. Green, Mr. Yellow or Mr. Brown, clear the original 3D causeway, defeat its guardian by reflecting three projectiles, and reach the exit.

## Play

Open `places/BrickToadsPlayable.rbxlx` in Roblox Studio and press Play. The level is generated when the server starts. Choose a hero and press **Начать игру**. Solo, duo and trio start immediately; identical hero choices are allowed.

- **WASD** — move and face a direction.
- **F** — punch; **R** — heavy strike; **Space** — jump.
- Touch devices have a movement stick and attack/jump buttons.
- Heroes have five hearts and three successful respawns. A living hero with zero respawns can keep playing.
- Ordinary sentries have three hearts and one life. Clear both encounters to open the guardian arena.
- Reflect the guardian's orange projectiles with an attack. Three returned projectiles open the exit.
- Victory/defeat returns to the selection screen. The host starts the next game manually.

All three templates have the same capabilities. The server fixes the 1–3 hero roster at Start; later arrivals spectate this run. Health, collisions, enemy AI, projectiles and respawns are server-owned.

This is an original playable prototype. Enemy damage, timing, geometry and the boss adaptation remain provisional. Human enemy roles, boss queues, multiple groups/levels and complete source-mechanics transfer are still outstanding. Additional enemy options are deferred at the user's request. Actual same-server reconnect remains unconfirmed; its earlier transport report is separate from this game's playability.

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
python tools/test_stand_gateway.py --luau <path-to-luau>
```

To open the separate combat stand: `python tools/build_combat_stand.py` → `build/CombatStand.rbxlx`. Its [runbook](docs/stand/RUNBOOK.md) and archived evidence remain available. No source ROM, extracted art/audio or external asset uploads are included.
