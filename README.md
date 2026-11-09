# Brick Toads

Current implementation: one playable Roblox prototype mode with six authored 3D districts, server-selected section variants for each new run, three hero choices and a pickup/throw guardian battle. Green and Player Two use imported cosmetic meshes with source-frame locomotion/attacks and the two oversized attack-limb forms and first-route boss-fear heads described below; Brown and the remaining cast are unfinished. The 13-mode campaign, complete mechanics/animation catalogue, polished art/audio/effects and production release remain incomplete; [current coverage](docs/GAMEPLAY_COVERAGE.md) records the limits. The player chooses directions and jump timing without automatic trajectory assistance.

## Play

Open `places/BrickToadsPlayable.rbxlx` in Roblox Studio and press Play. The level is generated when the server starts. Choose **Hero**, **Enemy** or **Watch**. The designated hero host presses **Start game**. Solo, duo and trio start immediately; identical hero choices are allowed. English is the default; enabled Roblox localization uses the selected locale, with English fallback for missing translations. See [localization](docs/LOCALIZATION.md).

Use **Groups** / **Choose team** to create an independent team or join another. Up to four local teams can play in separate arenas on one server. Joining an active team observes its existing run; it never adds a hero. A living or awaiting-respawn character keeps its role. After elimination you may create a new team or manually choose an eligible ordinary enemy in another group. Your old group's elimination/spent-life history stays intact when you return.

- Hold **WASD** to walk and face a direction. Press, release, then press the same direction again within 0.25 seconds and hold it to run. Heroes walk/run at 16/24 studs/s; a run jump travels farther at the same JumpPower50. Release, interruption and context changes clear running.
- **F** — primary attack or the nearby contextual action. During a physically qualified run it chooses the mega strike; **R** is a shortcut requiring the same run, not a standing heavy attack. **Space** jumps. Already-held Pig/guardian-ball and linked Dragon actions retain priority; the primary button displays the actual action.
- Standing hands-free primary strikes follow the target's actual source Life/reaction: jab, uppercut, overhead strike against a Dragon, power punch, kick or boot. This is a state-based chain, without a fixed hit counter. Eligible repeated hits can interrupt recovery; waiting lets ordinary enemies recover. All choices/effects are server-owned; an airborne primary is not a new jump-kick class.
- Touch gameplay uses four independent direction buttons plus separate Jump/Attack buttons through native Roblox IAS. Hold to walk; double-tap and hold a direction to run. No gameplay stick is used. Both orientations remain available, with compact health/objective cards and details on demand. Physical-phone/tablet multitouch acceptance is still outstanding. Gamepad/console controls are not implemented.
- A combat-defeated Walker drops one leg-club. Use **F** / **PICK UP CLUB** nearby to equip it, then **F** / **CLUB HIT** to swing with greater reach. It has no invented wear limit. Light hits retain it; heavy reactions/death drop it for another pickup. The guardian introduction frees weapon hands, and taking a ground ball also releases an equipped club. Club hits can hurt teammates.
- Face a nearby Pig while standing on the ground and press **F** / **GRAB** to lift it. Walk or jump with that same body, then press **F** / **THROW ENEMY** to throw. You cannot use the heavy strike while your hands are occupied. A hit or death of the carrier releases the enemy. Human enemies keep their body, health and owner; their commands resume after release/reaction. Walkers, dragons and heroes are outside this grab slice.
- In the stone courtyard, then on the long bridge, six healing flies appear in a two-then-four sequence. Face a nearby fly and use **F** / **CATCH FLY** to catch it with your tongue. A successful catch consumes it once and adds8 raw Life, capped at47 (about0.85 displayed heart); it does not restore respawns. A full-health catch still consumes the fly.
- Heroes have five hearts and three successful respawns. A living hero with zero respawns can keep playing.
- The six districts contain a static roster of13 ordinary actors: nine pigs, two walkers and two dragons. Their explicit source Life values15/31/47 scale to three displayed hearts. Damage/reaction use source target profiles; zero Life without subtraction underflow is not death. Human takeover preserves the same body, source Life and one-life history. This source-classified roster is not a verified dynamic natural-play population or complete species transfer.
- Pigs choose a short jab or a slower heavy strike from the selected hero's raw Life at attack start. A jab uses source profile18/raw4 with its light recovery; a heavy strike uses20/raw16. Later NPC pigs can make a running approach and strike with22/raw16, including at low Life. Their windups and recovery poses are distinct. Roblox ranges, speeds, random decision cadence and the later-district rush enable are calibration, not measured original frames. A human Pig uses the standing primary choice when walking and the bounded ground running strike while actually running.
- Walkers now use their own light strike or heavy launch, selected from the same raw-Life low-nibble boundary. They attack from farther away and NPC Walkers step back when approached point blank, stopping at unsafe edges. Their windups/recovery use original leg poses. A human Walker keeps manual movement and the existing F primary. Profiles18/raw4 and20/raw16 are source-backed; range2.5–6.5studs, effect reach7.5 and movement/timing are explicit Roblox tuning. Combat defeat still produces just one leg-club.
- Dragons use a fixed hero22/raw16 headbutt plus same-body flight, heavy-hit disabling, mounting, mounted fire, dismount and vulnerable-hero capture/release. Heavy reaction opens the calibrated mounting window; use the contextual primary action to mount, directions to steer, primary to fire and Jump to dismount. These adapted mechanics are implemented; exact original trajectories, timing and full natural-play acceptance remain incomplete.
- Advance by defeating the current district's enemies and physically reaching its far side. Empty traversal sections still require crossing their gaps and reaching the next gate. Respawns use unlocked route supports.
- To play an enemy, choose **Enemy**, wait for the hero to start, then select an available sentry. You take its existing body and current health. Move/jump normally and use **F** or the attack button. Ground enemies can walk/run at 9/16 studs/s; their actual running primary has fixed damage and never uses the hero's low-Life finisher. The separate hero R shortcut is unavailable.
- A sentry becomes unavailable after its first accepted attack or an accepted hero attack directed at it, including a miss. A dead human enemy cannot take another sentry in this run/level. A separate new game resets that limit.
- To play the guardian, open **BOSS QUEUE** in the menu or observer HUD and press **Queue for Guardian**. This removes you from the next hero roster. Invitations follow FIFO; answer within10 seconds. After acceptance the current client acknowledges readiness automatically, with a separate15-second connection deadline.
- Declining or missing an invitation moves you to the queue tail for a future assignment. Cancel explicitly to leave. A successful ordinary-enemy claim cancels waiting; an accepted guardian reserve must be cancelled before claiming a sentry.
- After all six districts, a finite mechanical-foot introduction and two fear forms lead into the guardian battle. The guardian becomes active when the introduction ends. Without an accepted ready player it uses NPC control after pending invitations finish. A human guardian uses **WASD**/the four touch directions to aim and **F**/**FIRE** to fire its ordinary shots. It has no hero heavy strike or jump. The server's finite pattern continues to provide heavy-ball opportunities while its human owner is idle or offline; disconnect preserves its body and health while accepted projectiles and timers continue.
- After final elimination, choose **Watch** or **Menu**. The personal menu has **Return to watching** while the same group continues; it does not restore a body, health or respawns.
- Spectators can switch the followed hero or use the free camera inside the level bounds. Free camera: **WASD** to move, **Q/E** for height, right mouse drag for direction. Touch has a camera stick and height/turn buttons.
- Dodge the guardian's flying shots; they cannot be punched back. Its special heavy shot becomes a ground ball. Approach it, press **F** to pick it up, then **F** again to throw it at the guardian. Three thrown-ball impacts defeat the guardian and open the exit.
- Victory/defeat returns to the selection screen. The host starts the next game manually.
- If a group stops because of a runtime error, it shows **Party stopped**. Its host can manually choose **Start again**; this creates a new party rather than silently resuming or resetting resources in the stopped one. Other healthy groups continue. Detailed errors stay server-side.
- Each group's victory/defeat and restart are independent. Guardian waiting is shared across groups; an invitation names its target team, and accepting transfers only the invited observer to that team.

All three templates have the same capabilities. The server fixes the 1–3 hero roster at Start; later arrivals spectate this run. Health, collisions, enemy AI, projectiles and respawns are server-owned.

This is a playable prototype. The source-backed modern combat policy and actor Life mapping are documented in [the combat transfer](research/2026-11-08-source-combat.md); timing, physical impulses, 3D geometry and joint angles are explicit Roblox adaptation. Ordinary human-enemy control, the guardian queue, first-mode section variation and up to four independent local groups are implemented. Multiple completed modes, scooters, the remaining mechanics/characters, final art/audio/effects, exact source input/animation-window parity and cross-server routing remain outstanding. Actual same-server reconnect remains unconfirmed. [The current coverage table](docs/GAMEPLAY_COVERAGE.md) separates implementation, research and acceptance gaps, including the requested avatar feature BT-73. No public release readiness is claimed.

Server-confirmed hit/miss/shield/item/boss text is shown in the existing objective feedback line and compact mobile goal. Short owner-only action refusals explain missing run-up, recovery or occupied control; they expire without replaying or extending on movement updates. Recent events are deduplicated and never replayed on first sync. A bounded private run journal and source receipt prepare later Studio diagnosis; only a small allowlisted feed reaches the client. This is not product retention analytics or completed sound work.

## Current hero presentation checkpoint

Green and Player Two retain the existing server-owned R6 body, health and collisions beneath fifteen cosmetic mesh segments. Idle/walk/run and seven accepted hero attacks drive cosmetic joints from the pinned NES graphics-frame streams. Source graphics `0x1C` selects one oversized **PowerFist**, and `0x1E` one **BigBoot**. The separate folded-leg `0x1F` silhouette is still a joint-pose approximation. Player Two retains its older prototype body; Brown and the remaining cast are unfinished.

The first-route guardian now has a finite **BossIntro** before its existing pickup/throw battle. Source counters select fear graphic `32` before the arena cut at `E0`, then `33` from `E1`; the guardian activates at `FF`. The two impacts, foot-motion marker and camera cut follow the source milestones. Local 60 Hz/4.25-second timing, camera coordinates, body poses and the **16 cosmetic intro parts: a mechanical-foot proxy and two impact markers** are authored 3D adaptation. The foot is a proxy informed by source graphic `12`; the full boss mesh, music and impact sounds are unfinished. Fear morphs replace only the cosmetic head, so complete source body silhouettes and Z motion remain pending.

Eight strict private resources cover Green/Player Two attack limbs and `FearBeforeCut`/`FearAfterCut` heads. Each appearance preassembles **19 MeshParts and 19 cosmetic Motor6Ds**; with the six physical-body motors, the actor has 25 motors. Runtime selection changes visibility through existing joints. Reactions, airborne state, cancellation and actor replacement release the fear appearance; exact saved head/limb transparency is restored. HP, raw Life, attempts, respawns and ownership remain under the existing server authority. Canonical clubs follow the visible hand.

The fear heads are imported private Roblox Model **94539676546833**, with atlas **84359931596705**, recorded in [roblox-fear-morphs.json](assets/characters/canonical-hero/roblox-fear-morphs.json). [hero-fear-morphs.glb](assets/characters/canonical-hero/hero-fear-morphs.glb) is **6,193,776 bytes**, SHA-256 `ba7f9650dba2c0425db6ab0a3dc9f45041936c2eb798314864d0a8f93ac1e39a`. [Fear asset notes](assets/characters/canonical-hero/README-hero-fear-morphs.md) separate measured reference from authored depth and neck anchors. The earlier attack resources remain documented in [their asset notes](assets/characters/canonical-hero/README-hero-attack-morphs.md) and [prepared Studio report](reports/2026-11-09-hero-attack-morphs/README.md).

All **45 validation commands** and compilation of **123 Luau files** passed for this checkpoint. The exact saved place was reopened in fresh Studio. Prepared native Session/Director/World scenarios sampled counters `1/30/50/64/E0/E1/FE/FF` across three heroes, confirmed fear `32→33→idle`, deferred boss activation, human guardian activation, another party's isolation, and unchanged HP 37/100, raw Life 47, attempt 1, respawns 3 and server ownership. Separate fresh scenarios checked reaction, native jump/Airborne, cancellation and body replacement. Native client camera CFrames changed across `E0`; stale, other-party, free-camera and ended contexts declined the intro view. Loaded Green/P2 heads and authored foot props were also captured through native Edit/runtime pose fixtures.

These are prepared checks, not an ordinary-input full-route playthrough. [The boss-appearance report](reports/2026-11-09-boss-appearance/README.md) records source fingerprint `a9a7efd51486d814d2cf35ffefb9170b94456e49bb08d626008e9cd8c52459ca` and the **744,382-byte** saved place, SHA-256 `a20b157339a40161f387a3bdab95703a249df205b5a3cb36d340a3b81f031f03`. Cold loading, physical devices, PAL/lag timing parity, complete fear-body forms, full normal-input route acceptance, all 13 modes and production readiness remain incomplete. See [animation contracts](docs/CANONICAL_ANIMATION.md).

## Current route acceptance

See the [current Studio handoff](docs/STUDIO_HANDOFF.md) and [coverage table](docs/GAMEPLAY_COVERAGE.md) for the latest source receipt, measured running/jump probes and compact-HUD checks. Those finite checks do not establish an unprepared full route, all modes/characters, real reconnect or physical-device acceptance. The prepared scenarios below belong to their recorded snapshots; they are not a blanket acceptance of newer code.

Walker light/heavy primary, an actual walk-away miss, NPC attack reach, support-checked retreat and one combat-death club pickup were checked through Studio MCP with a real hero and human Walker. See [the Walker attack report](reports/2026-11-08-walker-strikes/README.md) for the fixed preparation, unchanged ownership/resources and source limits.

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
luau tests/run_walker_strikes.luau
luau tests/run_dragon_strikes.luau
luau tests/run_source_combat.luau
luau tests/run_journal.luau
luau tests/run_feedback.luau
luau tests/run_movement_input.luau
luau tests/run_running_combat.luau
luau tests/run_canonical_animation.luau
luau tests/run_canonical_hero_presentation.luau
luau tests/run.luau
luau tests/run_stand.luau
luau tests/run_connections.luau
luau tests/run_groups.luau
python tests/group_world/run.py
python tests/canonical_hero_presentation/run.py --luau <path-to-luau>
python tools/test_stand_gateway.py --luau <path-to-luau>
```

To open the separate combat stand: `python tools/build_combat_stand.py` → `build/CombatStand.rbxlx`. Its [runbook](docs/stand/RUNBOOK.md) and archived evidence remain available. The playable builder uses checked-in manifests of actual imported private Roblox assets and authored GLBs. No source ROM is included.
