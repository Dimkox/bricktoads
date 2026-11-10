# Brick Toads

Current implementation: a server-owned thirteen-stage Roblox campaign, beginning with the six-district causeway and continuing through twelve distinct traversal/combat modes and five further bosses. Each run retains its fixed one-to-three-hero roster, respawn budget and seeded course composition across stage transitions. Green and Player Two use imported cosmetic meshes with source-frame locomotion/attacks, two oversized attack-limb forms and first-route boss-fear heads. The Guardian has imported red/black cannon meshes and a slender intro leg; Brown, ordinary enemies and later bosses still use procedural presentation. The complete canonical cast/animation transfer, polished art/audio/effects and production release remain unfinished; [current coverage](docs/GAMEPLAY_COVERAGE.md) separates implementation from acceptance. The player chooses directions and jump timing without automatic trajectory assistance.

## Play

Open `places/BrickToadsPlayable.rbxlx` in Roblox Studio and press Play. The level is generated when the server starts. Choose **Hero**, **Enemy** or **Watch**. The designated hero host presses **Start game**. Solo, duo and trio start immediately; identical hero choices are allowed. English is the default; enabled Roblox localization uses the selected locale, with English fallback for missing translations. See [localization](docs/LOCALIZATION.md).

**Studio God Mode** is enabled by default for testing the full campaign. Death still happens, but respawns are unlimited and the HUD shows `∞`. Change the server-side `ServerStorage.BrickToadsGodMode` boolean attribute to disable/enable it during Play or before the next Play. The ordinary three-respawn reserve is preserved while enabled. Published servers always use finite lives. [Tests and native evidence](reports/2026-11-10-studio-god-mode/README.md).

The [recorded native25 run](reports/2026-11-10-full-campaign-playthrough/attempt-25-summary.json) completed all13 stages and all six boss encounters/phases in one ordinary solo Studio game, with **God Mode off**, one paid respawn and two remaining. This establishes the recorded solo campaign; device, real reconnect and release acceptance remain separate.

Use **Groups** / **Choose team** to create an independent team or join another. Up to four local teams can play in separate arenas on one server. Joining an active team observes its existing run; it never adds a hero. A living or awaiting-respawn character keeps its role. After elimination you may create a new team or manually choose an eligible ordinary enemy in another group. Your old group's elimination/spent-life history stays intact when you return.

- On ordinary ground, hold **WASD** to walk and face a direction. Press, release, then press the same direction again within 0.25 seconds and hold it to run. Heroes walk/run at 16/24 studs/s; a first-route run jump travels farther at the same JumpPower50. Release, interruption and context changes clear running. Later modes supply their own movement and jump budgets; the HUD shows the current controls.
- **F** — primary attack or the nearby contextual action. During a physically qualified run it chooses the mega strike; **R** is a shortcut requiring the same run, not a standing heavy attack. **Space** jumps. Already-held Pig/guardian-ball and linked Dragon actions retain priority; the primary button displays the actual action.
- Standing hands-free primary strikes follow the target's actual source Life/reaction: jab, uppercut, overhead strike against a Dragon, power punch, kick or boot. This is a state-based chain, without a fixed hit counter. Eligible repeated hits can interrupt recovery; waiting lets ordinary enemies recover. All choices/effects are server-owned; an airborne primary is not a new jump-kick class.
- Touch gameplay uses four independent direction buttons plus separate Jump/Attack buttons through native Roblox IAS. Hold to walk; double-tap and hold a direction to run. No gameplay stick is used. Both orientations remain available, with compact health/objective cards and details on demand. Physical-phone/tablet multitouch acceptance is still outstanding. Gamepad/console controls are not implemented.
- A combat-defeated Walker drops one leg-club. Use **F** / **PICK UP CLUB** nearby to equip it, then **F** / **CLUB HIT** to swing with greater reach. It has no invented wear limit. Light hits retain it; heavy reactions/death drop it for another pickup. The guardian introduction frees weapon hands, and taking a ground ball also releases an equipped club. Club hits can hurt teammates.
- Face a nearby Pig while standing on the ground and press **F** / **GRAB** to lift it. Walk or jump with that same body, then press **F** / **THROW ENEMY** to throw. You cannot use the heavy strike while your hands are occupied. A hit or death of the carrier releases the enemy. Human enemies keep their body, health and owner; their commands resume after release/reaction. Walkers, dragons and heroes are outside this grab slice.
- In the stone courtyard, then on the long bridge, six healing flies appear in a two-then-four sequence. Face a nearby fly and use **F** / **CATCH FLY** to catch it with your tongue. A successful catch consumes it once and adds8 raw Life, capped at47 (about0.85 displayed heart); it does not restore respawns. A full-health catch still consumes the fly.
- Heroes have five hearts and three successful respawns. A living hero with zero respawns can keep playing.
- The first route's six districts contain a static roster of13 ordinary actors: nine pigs, two walkers and two dragons. Their explicit source Life values15/31/47 scale to three displayed hearts. Later courses add real bird, wall, rocket-rat, ice, machine, swimming and tower families with their own actions and source Life profiles. Damage/reaction use source target profiles; zero Life without subtraction underflow is not death. Human takeover preserves the same body, source Life and one-life history. These authored populations are not a verified dynamic natural-play census or complete source FSM transfer.
- Pigs choose a short jab or a slower heavy strike from the selected hero's raw Life at attack start. A jab uses source profile18/raw4 with its light recovery; a heavy strike uses20/raw16. Later NPC pigs can make a running approach and strike with22/raw16, including at low Life. Their windups and recovery poses are distinct. Roblox ranges, speeds, random decision cadence and the later-district rush enable are calibration, not measured original frames. A human Pig uses the standing primary choice when walking and the bounded ground running strike while actually running.
- Walkers now use their own light strike or heavy launch, selected from the same raw-Life low-nibble boundary. They attack from farther away and NPC Walkers step back when approached point blank, stopping at unsafe edges. Their windups/recovery use original leg poses. A human Walker keeps manual movement and the existing F primary. Profiles18/raw4 and20/raw16 are source-backed; range2.5–6.5studs, effect reach7.5 and movement/timing are explicit Roblox tuning. Combat defeat still produces just one leg-club.
- Dragons use a fixed hero22/raw16 headbutt plus same-body flight, heavy-hit disabling, mounting, mounted fire, dismount and vulnerable-hero capture/release. Heavy reaction opens the calibrated mounting window; use the contextual primary action to mount, directions to steer, primary to fire and Jump to dismount. These adapted mechanics are implemented; exact original trajectories, timing and full natural-play acceptance remain incomplete.
- On the first route, advance by defeating the current district's enemies and physically reaching its far side. Later courses require their actual traversal/objectives and any assigned boss outcome; elapsed time cannot clear them. Respawns use unlocked checkpoints. An earned stage transition moves surviving bodies and heals them once, retaining their attempts, remaining respawns and eliminated teammates.
- To play an enemy, choose **Enemy**, wait for the hero to start, then select an available enemy. You take its existing body and current resources. Use the displayed movement, Jump and **F** controls; stationary, flying, swimming and scripted riders retain their family restrictions. First-route ground enemies walk/run at 9/16 studs/s; their actual running primary has fixed damage and never uses the hero's low-Life finisher. The separate hero R shortcut is unavailable. The race rival has a course role and finite stun rather than an ordinary three-heart health bar.
- A sentry becomes unavailable after its first accepted attack or an accepted hero attack directed at it, including a miss. A dead human enemy cannot take another sentry in this run/level. A separate new game resets that limit.
- To play a boss, open **BOSS QUEUE** in the menu or observer HUD and select its queue. The campaign supports Guardian, Big Blag, Robo-Manus, General Slaughter, Buzzball and Dark Queen. Queueing removes you from the next hero roster. Invitations follow FIFO; answer within10 seconds. After acceptance the current client acknowledges readiness automatically, with a separate15-second connection deadline. Each assignment controls that encounter's existing boss body and resource model.
- Declining or missing an invitation moves you to the queue tail for a future assignment. Cancel explicitly to leave. A successful ordinary-enemy claim cancels waiting; an accepted guardian reserve must be cancelled before claiming a sentry.
- After all six districts, a finite mechanical-foot introduction and two fear forms lead into the guardian battle. The guardian becomes active when the introduction ends. Without an accepted ready player it uses NPC control after pending invitations finish. A human guardian uses **WASD**/the four touch directions to aim and **F**/**FIRE** to fire its ordinary shots. It has no hero heavy strike or jump. The server's finite pattern continues to provide heavy-ball opportunities while its human owner is idle or offline; disconnect preserves its body and health while accepted projectiles and timers continue.
- After final elimination, choose **Watch** or **Menu**. The personal menu has **Return to watching** while the same group continues; it does not restore a body, health or respawns.
- Spectators can switch the followed hero or use the free camera inside the level bounds. Free camera: **WASD** to move, **Q/E** for height, right mouse drag for direction. Touch has a camera stick and height/turn buttons.
- Dodge the guardian's flying shots; they cannot be punched back. Its special heavy shot becomes a ground ball. Approach it, press **F** to pick it up, then **F** again to throw it at the guardian. Three thrown-ball impacts defeat the guardian and open the exit.
- The Guardian exit advances the same run into the rope course. Stage completion continues through the campaign; only the final Dark Queen outcome produces campaign victory. Victory/defeat returns to the selection screen, and the host starts the next game manually.
- If a group stops because of a runtime error, it shows **Party stopped**. Its host can manually choose **Start again**; this creates a new party rather than silently resuming or resetting resources in the stopped one. Other healthy groups continue. Detailed errors stay server-side.
- Each group's victory/defeat and restart are independent. Boss waiting is shared across groups; an invitation names its target team, and accepting transfers only the invited observer to that team.

All three templates have the same capabilities. The server fixes the 1–3 hero roster at Start; later arrivals spectate this run. Health, collisions, enemy AI, projectiles and respawns are server-owned.

This is a playable campaign prototype. The source-backed modern combat policy and actor Life mapping are documented in [the combat transfer](research/2026-11-08-source-combat.md), [campaign enemies](research/2026-11-09-campaign-enemies.md), [race rival](research/2026-11-09-campaign-race.md) and [campaign bosses](research/2026-11-09-campaign-bosses.md). Timing, physical impulses, 3D geometry, authored populations and joint angles remain explicit Roblox adaptation. Ordinary human-enemy control, all six boss queues, seeded courses and up to four independent local groups are implemented. Complete source FSM/input/animation parity, finished canonical characters, final art/audio/effects and cross-server routing remain outstanding. Actual same-server reconnect remains unconfirmed. A normal human campaign playthrough, physical-device acceptance and public release readiness are not established by the automated or prepared checks. [The current coverage table](docs/GAMEPLAY_COVERAGE.md) also records the requested avatar feature BT-73.

## Campaign runtime

The [course mechanics notes](research/2026-11-09-campaign-courses.md) distinguish the implemented physical modes from their source and acceptance limits:

| Stage | Implemented objective and mechanics |
| --- | --- |
| 1. Flooded Causeway | Six districts of ground combat, carrying/throwing, clubs, flies, Dragon transport and Guardian pickup/throw battle. |
| 2. Echo Shaft | Rope descent/swing, contextual strikes, real Raven/Large Raven/Retro Blaster/Toadtrap actors, finite claw pickup and electrical phases. |
| 3. Copper Rush | Entry patrol and boarding, a continuous solid road across all steering lanes, automatic travel, jumps/ramps, swept crashes, shared checkpoint rewind and a later scripted Rocket Rat drop. |
| 4. Frostworks | Ice inertia/braking, gaps, pushable blocks, moving walls/platforms, falling ice and spikes. |
| 5. Tidal Foundry | Surfboard steering/jumps, current drift, water hazards/projectiles and Big Blag. |
| 6. Four Coil Vaults | Four ordered rooms with moving multi-segment serpent supports, timed jumps, spikes and checkpoints. |
| 7. Ember Airway | Jet boarding/automatic flight, relative throttle, altitude steering, lift and airborne hazards. |
| 8. Machine Ascent | Lifts, springs, fans, gas/electrical threats, a mechanical crusher and Robo-Manus. |
| 9. Pressure Pipes | Dry traversal, swimming/current forces, surface exits, breath, machinery and fish-family combat. |
| 10. Fuse Pursuit | Physical, stunnable Rat rival, three nearby bomb defuses, real rival/bomb contact failure and General Slaughter. |
| 11. Magnetic Circuit | Directional turns, shared Buzzball pursuit and a same-body battle handoff preserving its Life. |
| 12. Turning Spire | Cylindrical orientation, rotating/carrying platforms, springs, wind and rotating spikes. |
| 13. Last Eclipse | Physical arena entry, Dark Queen attack/recovery windows and the final campaign result. |

Course controls act in the mode's own axes. Vehicles require primary-action boarding after the entry patrol is cleared. A crash kills only the collided hero through Session; surviving riders stop and rewind without healing or spending another life. Emergency-held bodies wait for Session's safe release, and offline living bodies continue their physical course without new steering. Rope primary strikes hit actual actors; Invader theft/return tokens and claw equipment are bound to the current body and level. Race bombs are decided by real rival contact or a fresh nearby primary action, never an arrival timer. Boss raw Life and separate reaction progress retain their distinct models rather than becoming linear hearts.

The entry Invader now approaches from outside its initial attack range, leaving a visible role offer before engagement. Its existing escape deadline survives the stolen-Life victim's death or replacement, without healing an old body. A Rocket Rat drop hitting a mounted hero now enters the same shared crash lifecycle as a course obstacle; a protected contact consumes the drop without damage or extending protection. On Speeder/Surf/Jet, the hero HUD hides unavailable Attack/Mega/ground-run prompts and retains Jump/lift; Dragon and carried-item actions keep their own controls. A human Rocket Rat keeps **DROP OBSTACLE** and has no Jump control.

The campaign runners cover course inputs, swept hazards, resources/epochs, actor identity, one-life role claims, shared rewinds and real Session progression. Test pilots complete ten course modes for three seeds using ordinary inputs; prepared fixtures exercise other boundaries. These checks do not replace an unprepared human run through all thirteen stages and their ordinary combat/boss encounters.

The [current scooter acceptance report](reports/2026-11-09-scooter-acceptance/README.md) records **56/56 passing checks and 161 successful Luau compilations** for source `b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff`. A separate Python check also executes the client's real action-visibility block against desktop/touch snapshots. On this final source, **9/9 native engine courses** passed: one/two/three hero bodies × seeds 1/41/8125, through entry combat, boarding, riding and the next stage in 14.62–15.16 real seconds. These use one actual client, synthetic co-owners and scripted validated inputs after prepared stage-3 selection; the pilots do not directly write health, pose, geometry or lives. Every hero retained attempt 1 and three respawns.

Final-source mouse UI start and keyboard/IAS/remote riding also reached stage 4, 13.882 seconds after the keyboard phase began, preserving the hero's body, attempt 1 and three respawns. The native client showed Jump with Attack/Mega hidden, a steering/jump hint and the visible road. Separate prepared role fixtures confirmed a human Rocket Rat drop causes one shared rewind (stocks 2/3/3, survivor bodies retained, second drop rejected), and an Invader still escapes without stale healing after a victim death deliberately injected through Session and a paid replacement. These role fixtures do not represent multiple connected clients or an unprepared human campaign. The earlier [campaign checkpoint](reports/2026-11-09-campaign-mechanics/README.md) retains its historical receipts.

The next [actual-client checkpoint](reports/2026-11-09-scooter-network-acceptance/README.md) passes solo/duo/trio Copper Rush runs with **1/2/3 actual Studio clients**, seed41 and production Intent/State remotes: **47/85/114 checks**, 16.886/16.847/19.283 seconds from prepared stage3 to earned clear. Every rider boarded, steered, jumped and reached checkpoint3; all bodies, attempt1 and three respawns survived. Test-only automated client pilots disable presentation/UI, so this establishes baseline multiplayer hero/NPC traversal.

The following [enemy/crash checkpoint](reports/2026-11-09-scooter-role-network-acceptance/README.md) passes **164 checks in four final actual-client runs**: human Invader theft/return and finite escape (two clients), authored-hazard crash (three heroes), and a human RocketRat early drop/native collision (two heroes plus one Enemy client). Only the collided hero pays a respawn; survivors retain their bodies, stock and observed Life. Every actual client receives matching final actor/resource state and the spent enemy role. Physical-phone/tablet, gamepad, broader role/offline cases, impaired networks and same-account reconnect remain open.

The [disconnect checkpoint](reports/2026-11-09-scooter-disconnect-acceptance/README.md) passes **195 checks in four final native scenarios** using actual client exits: Invader keeps its finite escape without NPC takeover; an accepted RocketRat obstacle survives owner exit and causes one native crash; a living offline rider retains its physical body/resources through shared rewind; a naturally dead offline owner waits at attempt1/stock3 while a different new client enters as spectator. Remaining clients, including that late spectator, see matching fixed-roster resources. The late arrival has a different UserId and does not establish same-account return. Physical devices, gamepad, impaired public networks and actual same-account reconnect remain open.

Server-confirmed hit/miss/shield/item/boss text is shown in the existing objective feedback line and compact mobile goal. Short owner-only action refusals explain missing run-up, recovery or occupied control; they expire without replaying or extending on movement updates. Recent events are deduplicated and never replayed on first sync. A bounded private run journal and source receipt prepare later Studio diagnosis; only a small allowlisted feed reaches the client. This is not product retention analytics or completed sound work.

## Retained character and Guardian presentation checkpoint

Green and Player Two retain the existing server-owned R6 body, health and collisions beneath fifteen cosmetic mesh segments. Idle/walk/run and seven accepted hero attacks drive cosmetic joints from the pinned NES graphics-frame streams. Source graphics `0x1C` selects one oversized **PowerFist**, and `0x1E` one **BigBoot**. The separate folded-leg `0x1F` silhouette is still a joint-pose approximation. Player Two retains its older prototype body; Brown and the remaining cast are unfinished.

The first-route guardian has a finite **BossIntro** before its existing pickup/throw battle. Source counters select fear graphic `32` before the arena cut at `E0`, then `33` from `E1`; the guardian activates at `FF`. The two impacts, foot-motion marker and camera cut follow the source milestones. A valid imported resource supplies **one slender red `IntroLeg12` mesh and two reused impact markers**, replacing the earlier broad boot proxy; the 16-part proxy remains a fallback for an invalid or missing runtime resource. Local 60 Hz/4.25-second timing, camera coordinates, body poses, leg depth and motion are authored 3D adaptation. Fear morphs replace only the cosmetic head, so complete source body silhouettes and Z motion remain pending. Music and impact sounds are unfinished.

The active Guardian uses **three meshes, three cosmetic Motor6Ds, two preassembled muzzle-flash parts and two welds** over the existing physical body. Accepted bullets and heavy shots alternate barrel recoil/flash; blocked melee does not fire a barrel, and an actual health decrease briefly tints the saved mesh/PBR colors. The source establishes camera-relative cannons, not a complete external robot: the compact chassis, rear anatomy, depth and material response are authored. Source reticle `11` and cracked-glass `C7` effects remain unimplemented; the body has no reactor eye or magical coils.

Private Model **103948186317063** and atlas **90154814086213** supply `BossWalkerGuardian` and `BossWalkerIntroLeg` under `ServerStorage.BrickToadsBossTemplates`. [boss-walker.glb](assets/characters/canonical-hero/boss-walker.glb) is **3,821,508 bytes**, SHA-256 `4f1d852e369f83da380dd05b37a5d999886aea036eba220852678ed4a47adc08`. The strict [import manifest](assets/characters/canonical-hero/boss-walker-roblox.json) preserves actual mesh extents, imported rest rotations, mount/muzzle frames, texture and Metal material. [Asset notes](assets/characters/canonical-hero/boss-walker-README.md) record source boundaries and authored geometry.

Eight strict private resources cover Green/Player Two attack limbs and `FearBeforeCut`/`FearAfterCut` heads. Each appearance preassembles **19 MeshParts and 19 cosmetic Motor6Ds**; with the six physical-body motors, the actor has 25 motors. Runtime selection changes visibility through existing joints. Reactions, airborne state, cancellation and actor replacement release the fear appearance; exact saved head/limb transparency is restored. HP, raw Life, attempts, respawns and ownership remain under the existing server authority. Canonical clubs follow the visible hand.

The active fear heads use private Roblox Model **127590624870763** and atlas **96845591138258**, recorded in [roblox-fear-morphs.json](assets/characters/canonical-hero/roblox-fear-morphs.json). [hero-fear-wide-mouth.glb](assets/characters/canonical-hero/hero-fear-wide-mouth.glb) is **8,712,432 bytes**, SHA-256 `e5dd859b9be454198046580a147f7d202fd5374502f0f860384d1590efa325c1`. The jaw now drops about four studs farther down to neck Y−4.24 while the eyes/skull stay near ordinary head height. The nominal mouth opening is 4.73 studs high, about 3.02×/3.48× the earlier Green BeforeCut/AfterCut height, and 1.27/1.65 studs wide. [Current asset notes](assets/characters/canonical-hero/hero-fear-wide-mouth-README.md) distinguish the source-informed expression from authored depth and neck geometry. This changes the four cosmetic assets; source frames `32/33`, counters, poses and runtime code are unchanged. All seven earlier GLBs, including [the smaller fear package](assets/characters/canonical-hero/README-hero-fear-morphs.md) from Model94539676546833 and Boss Walker, remain unchanged. The earlier attack resources retain [their asset notes](assets/characters/canonical-hero/README-hero-attack-morphs.md) and [prepared Studio report](reports/2026-11-09-hero-attack-morphs/README.md).

At this earlier presentation checkpoint, all **47 validation commands** and compilation of **126 Luau files** passed, including 9 Guardian appearance, 16 intro asset, 14 Guardian pattern, 4 Guardian session and 31 builder contracts. Independent review found and resolved nested intro-child validation before cloning; the builder also preserves imported Metal as enum 1088. The exact saved place was reopened in fresh Studio. A prepared native Session/Director/World fixture confirmed the one-mesh/two-marker intro, three Guardian meshes/motors, two welds, the same two physical colliders, a single root assembly and manual server ownership. Actual accepted bullet/heavy shots drove left/right recoil and flash; blocked melee did not trigger firing or hurt tint. Three real pickup/throw interactions and finite projectile collision steps produced Life `47→31→15→0` and `Exit`, retaining prepared HP 37 for one hero, HP 100 for the other, attempt 1, respawns 3 and human Guardian owner 999. Another party's Guardian remained at zero shots.

Fresh validation after the mouth asset change again passed **47 commands and 126 Luau compilations**. The saved file's real Session/Director fixture repeated the Guardian encounter and confirmed Green/P2 graphics `32/33` use the new assets, restore the original cosmetic heads afterward and preserve prepared HP 37/100, attempt 1 and respawns 3 through Life `47→31→15→0` and Exit. Applying final GLB vertices to the actual native Neck CFrames placed the lowest points 0.2815–0.6074 studs above the prepared floor. These vertex measurements establish floor clearance. Loaded native Edit poses additionally confirmed that the forward-projecting cavity remains visible in front/three-quarter views without the torso filling it; the saved captures are separate from gameplay footage.

These checks used prepared positions, supports and time; they do not establish an ordinary-input full-route playthrough. [The retained mouth-proportion report](reports/2026-11-09-fear-mouth-proportions/README.md) records its **777,566-byte** saved place, SHA-256 `43657a454e90539db5e3e6d44aae701953fb3c35475d7416a89d9f838028cccf`. Its 42 embedded scripts retain source fingerprint `d6ada582f21045fc2035b5a81bc6ff97ae32be427f8af521df04aaa6c8e03923`; these are historical receipts, not the newer campaign build. [The preceding Guardian visual report](reports/2026-11-09-guardian-visuals/README.md) retains its 777,545-byte receipt and loaded red textured Metal geometry/leg captures after asset warmup. [The earlier fear/camera report](reports/2026-11-09-boss-appearance/README.md) retains its own receipts and prepared three-hero/interruption/camera checks. Cold loading, physical-device performance, PAL/lag timing parity, complete fear-body forms, the remaining canonical cast and full human campaign acceptance remain unfinished. See [animation contracts](docs/CANONICAL_ANIMATION.md).

## Campaign and historical route acceptance

See the [coverage table](docs/GAMEPLAY_COVERAGE.md) and campaign research notes for current implementation and evidence boundaries. The [Studio handoff](docs/STUDIO_HANDOFF.md) retains first-route source receipts, measured running/jump probes and compact-HUD checks. Those finite checks do not establish an unprepared full campaign, the complete canonical cast, real reconnect or physical-device acceptance. The prepared scenarios below belong to their recorded snapshots; they are not a blanket acceptance of newer code.

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
luau tests/run_boss_intro.luau
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
luau tests/run_campaign_modes.luau
luau tests/run_campaign_bosses.luau
luau tests/run_campaign_progression.luau
luau tests/run_campaign_enemies.luau
luau tests/run_campaign_roster.luau
luau tests/run_campaign_race.luau
luau tests/run_campaign_input.luau
luau tests/run_scooter_acceptance.luau
luau tests/run.luau
luau tests/run_stand.luau
luau tests/run_connections.luau
luau tests/run_groups.luau
python tests/group_world/run.py
python tests/canonical_hero_presentation/run.py --luau <path-to-luau>
python tests/guardian_appearance/run.py --luau <path-to-luau>
python tests/campaign_world/run.py --luau <path-to-luau>
python tests/campaign_input/run.py --luau <path-to-luau>
python tools/test_stand_gateway.py --luau <path-to-luau>
```

To open the separate combat stand: `python tools/build_combat_stand.py` → `build/CombatStand.rbxlx`. Its [runbook](docs/stand/RUNBOOK.md) and archived evidence remain available. The playable builder uses checked-in manifests of actual imported private Roblox assets and authored GLBs. No source ROM is included.
