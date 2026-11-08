# Brick Toads

Playable Roblox prototype: choose Mr. Green, Mr. Yellow or Mr. Brown, cross six original 3D districts with real gaps and raised ledges, defeat the guardian by picking up and throwing heavy balls, and reach the exit.

## Play

Open `places/BrickToadsPlayable.rbxlx` in Roblox Studio and press Play. The level is generated when the server starts. Choose **Герой**, **Противник** or **Наблюдать**. The first selected hero presses **Начать игру**. Solo, duo and trio start immediately; identical hero choices are allowed.

Use **Группы** / **Выбрать команду** to create an independent team or join another. Up to four local teams can play in separate arenas on one server. Joining an active team observes its existing run; it never adds a hero. A living or awaiting-respawn character keeps its role. After elimination you may create a new team or manually choose an eligible ordinary enemy in another group. Your old group's elimination/spent-life history stays intact when you return.

- **WASD** — move and face a direction.
- **F** — punch, pick up a nearby ground ball, or throw the ball you are carrying. The primary button shows **ВЗЯТЬ ШАР** / **БРОСИТЬ ШАР** when that interaction is available. **R** — heavy strike; **Space** — jump. The heavy strike is unavailable while carrying a ball.
- Touch devices have a movement stick and attack/jump buttons.
- A combat-defeated Walker drops one leg-club. Use **F** / **ВЗЯТЬ ДУБИНУ** nearby to equip it, then **F** / **УДАР ДУБИНОЙ** to swing with greater reach. It has no invented wear limit. Light hits retain it; heavy reactions/death drop it for another pickup. The guardian introduction frees weapon hands, and taking a ground ball also releases an equipped club. Club hits can hurt teammates.
- Face a nearby Pig while standing on the ground and press **F** / **СХВАТИТЬ** to lift it. Walk or jump with that same body, then press **F** / **БРОСИТЬ ВРАГА** to throw. You cannot use the heavy strike while your hands are occupied. A hit or death of the carrier releases the enemy. Human enemies keep their body, health and owner; their commands resume after release/reaction. Walkers, dragons and heroes are outside this grab slice.
- In the stone courtyard, then on the long bridge, six healing flies appear in a two-then-four sequence. Face a nearby fly and use **F** / **ЛОВИТЬ МУХУ** to catch it with your tongue. A successful catch consumes it once and adds8 raw Life, capped at47 (about0.85 displayed heart); it does not restore respawns. A full-health catch still consumes the fly.
- Heroes have five hearts and three successful respawns. A living hero with zero respawns can keep playing.
- The six districts contain a static roster of 13 ordinary actors: nine pigs, two walkers and two dragons. They have distinct original silhouettes and currently share the provisional three-heart, one-life combat profile. This source-classified roster is not a verified natural-play population or a claim of complete species mechanics.
- Pigs now choose a short jab or a slower heavy strike from the selected hero's raw Life at attack start. A jab uses source profile18/raw4 with its light recovery; a heavy strike uses20/raw16. Later NPC pigs can make a running approach and strike with22/raw16, including at low Life. Their windups and recovery poses are distinct. Roblox ranges, speeds, random decision cadence and the later-district rush enable are calibration, not measured original frames. A human Pig's existing F uses the same standing primary choice; there are no extra attack controls.
- Advance by defeating the current district's enemies and physically reaching its far side. Empty traversal sections still require crossing their gaps and reaching the next gate. Respawns use unlocked route supports.
- To play an enemy, choose **Противник**, wait for the hero to start, then select an available sentry. You take its existing body and current health. Move/jump normally and use **F** or the attack button for its ordinary strike; the hero's heavy strike is unavailable.
- A sentry becomes unavailable after its first accepted attack or an accepted hero attack directed at it, including a miss. A dead human enemy cannot take another sentry in this run/level. A separate new game resets that limit.
- To play the guardian, open **ОЧЕРЕДЬ БОССА** in the menu or observer HUD and press **Ждать стража**. This removes you from the next hero roster. Invitations follow FIFO; answer within10 seconds. After acceptance the current client acknowledges readiness automatically, with a separate15-second connection deadline.
- Declining or missing an invitation moves you to the queue tail for a future assignment. Cancel explicitly to leave. A successful ordinary-enemy claim cancels waiting; an accepted guardian reserve must be cancelled before claiming a sentry.
- The reserved guardian appears after all six districts. Without an accepted ready player it uses NPC control after pending invitations finish. A human guardian uses **WASD**/the touch stick to aim and **F**/**ОГОНЬ** to fire its ordinary shots. It has no hero heavy strike or jump. The server's finite pattern continues to provide heavy-ball opportunities while its human owner is idle or offline; disconnect preserves its body and health while accepted projectiles and timers continue.
- After final elimination, choose **Наблюдать** or **В основное меню**. The personal menu has **Вернуться к наблюдению** while the same group continues; it does not restore a body, health or respawns.
- Spectators can switch the followed hero or use the free camera inside the level bounds. Free camera: **WASD** to move, **Q/E** for height, right mouse drag for direction. Touch has a camera stick and height/turn buttons.
- Dodge the guardian's flying shots; they cannot be punched back. Its special heavy shot becomes a ground ball. Approach it, press **F** to pick it up, then **F** again to throw it at the guardian. Three thrown-ball impacts defeat the guardian and open the exit.
- Victory/defeat returns to the selection screen. The host starts the next game manually.
- Each group's victory/defeat and restart are independent. Guardian waiting is shared across groups; an invitation names its target team, and accepting transfers only the invited observer to that team.

All three templates have the same capabilities. The server fixes the 1–3 hero roster at Start; later arrivals spectate this run. Health, collisions, enemy AI, projectiles and respawns are server-owned.

This is an original playable prototype. Enemy damage, timing and geometry remain provisional. The guardian pickup/throw chain and fly healing arithmetic are source-backed; their Roblox distances, timing and presentation are explicit calibration. Ordinary human-enemy control, the guardian queue and up to four independent local groups are implemented for the current level. Multiple levels, cross-server boss routing and complete source-mechanics transfer remain outstanding. This does not implement cross-server discovery. Additional enemy combat abilities are deferred at the user's request. Actual same-server reconnect remains unconfirmed; its earlier transport report is separate from this game's playability.

## Current route acceptance

Pig jab/heavy selection, immutable windup choice, the later running attack and one lethal rush/respawn were checked through Studio MCP with a real hero and human Pig. See [the Pig attack report](reports/2026-11-08-pig-strikes/README.md) for the actual fly-healed health chain, preparation and source limits.

Walker-club pickup/combat, friendly fire, heavy-hit drop, transfer to another hero and guardian hand priority were checked through Studio MCP, including phone pickup/swing emulation. See [the weapon report](reports/2026-11-08-walker-club/README.md) for the prepared scenarios and source/device limits.

Pig grab/carry/throw was checked through Studio MCP with two real clients, including a human enemy, carrier interruption, a phone throw, control recovery and a real fall. See [the grab/throw report](reports/2026-11-08-enemy-grab-throw/README.md) for preparation and source/damage limits.

The added fly capture/healing was checked with three actual Studio clients in two groups and with the phone primary button in emulation. These prepared checks and their limits are recorded in the [healing flies report](reports/2026-11-07-healing-flies/README.md).

The six-district route, all five physical gap landings, the three pickup/throw guardian hits and the earned exit were checked on the final sources in Studio. Ordinary NPCs were cleared by a separate QA listener to isolate traversal; hero movement, health and respawns were not edited. See [the current route report](reports/2026-11-07-first-level-route/README.md) for the exact evidence and remaining limits.

## Historical acceptance evidence

The archived reports below cover the earlier short prototype. They do not validate the current six-district route, its jumps, or the pickup/throw guardian battle. Native contracts and isolated encounter checks also do not establish an unprepared complete playthrough or physical phone/tablet acceptance.

The earlier spectator/menu flow was checked through Studio MCP with four real clients, including an eliminated hero, a dead human enemy and a continuing teammate. Camera bounds and iPhone 17 Pro landscape emulation were checked. See the historical [spectator camera report](reports/2026-11-07-spectator-menu-camera/README.md).

Earlier guardian acceptance used three real Studio clients for FIFO/decline/accept, then two clients for mobile invitation, human projectile control, three reflected hits in the legacy battle and the unlocked exit. Ordinary NPCs were held/killed and the hero relocated to isolate that encounter; this was not an unprepared full-level run. See the historical [boss role evidence](reports/2026-11-07-boss-role-queue/README.md).

Earlier independent-group acceptance used four Studio clients and three actual runs. It verified elimination/new game, isolated loss, another group's existing enemy, shared guardian assignment and a reflected projectile in the legacy translated arena. The group selector was checked in phone emulation. See the historical [group evidence](reports/2026-11-07-independent-groups/README.md).

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
luau tests/run_level_route.luau
luau tests/run_guardian.luau
luau tests/run_healing_flies.luau
luau tests/run_enemy_carry.luau
luau tests/run_walker_clubs.luau
luau tests/run_pig_strikes.luau
luau tests/run.luau
luau tests/run_stand.luau
luau tests/run_connections.luau
luau tests/run_groups.luau
python tests/group_world/run.py
python tools/test_stand_gateway.py --luau <path-to-luau>
```

To open the separate combat stand: `python tools/build_combat_stand.py` → `build/CombatStand.rbxlx`. Its [runbook](docs/stand/RUNBOOK.md) and archived evidence remain available. No source ROM, extracted art/audio or external asset uploads are included.
