# Canonical character appearance and animation source contract

Source inspection: 9 November 2026. This responds to the owner's new requirement to rebuild **all** characters from the original game's proportions and animation, including attacks and boss appearances. It supersedes the earlier free reinterpretation/explorer direction for character presentation. It does not change accepted resource limits, server authority or the third-player adaptation.

The existing project reference is **Battletoads USA NES**, pinned to `feos-tas/DisAssemble@f1a43b69577246850d136473700a333b3cdfe93f`; it is the original 1991 game. No separate 1989 build was found or substituted. This is static source analysis, not an emulator trace or completed runtime implementation.

Primary references: [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [animation streams](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm), [configurations 1](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm), [configurations 2](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs2.asm).

The machine-readable [catalog](2026-11-09-canonical-character-animation-catalog.json) contains all **69 animation pointers**, **128 object-dispatch entries**, direct authored type membership across all stream/checkpoint segments of the **13 modes**, and explicit partial/unknown boss intro records. These are indexes, not 128 enemies or a verified natural-play population. For example, Tall Walker is created from an appearance object rather than directly listed as type `11/12` in level one's initial stream; absent direct membership does not establish absence from play. Stop markers and checkpoint labels must not truncate later authored segments such as Terra Tubes' water enemies.

The read-only [extractor](extract_canonical_animation_catalog.py) reads pinned source caches under ignored `build/canonical-source`. Reproduce with `.tools/python-3.13.9/python.exe research/extract_canonical_animation_catalog.py` after downloading the four primary files listed in the catalog's reference section to those cache names. Their SHA-256 values are recorded there. It was run successfully with 69 terminated streams, 128 dispatch entries and 13 indexed modes. The report/catalog have no runtime remotes, ROM upload, character meshes or hidden game mutation.

## How the source animation language works

Main 15527–15620 is the interpreter. `write_obj_Anim_ID` sets the animation, resets its byte pointer and clears the making-damage latch. `start_read_anim` increments that pointer only when `(FrameCounter & callerMask)==0`; commands and their parameter bytes are processed in the same call until a graphics frame or terminator is reached. A byte below `E0` is a graphics-frame selection; `E0..F6` are commands. **Command parameters are not frames.**

Consequently `displayAdvances` in the catalog counts literal graphics-frame bytes; it is not a ready-made duration in seconds. Hero attacks use mask `1` (normally two unpaused source updates per pointer advance, main 7268–7269); Pig uses `3` (four, 16787–16788), ordinary Dragon uses `3` (four, 5358–5359), Tall Walker uses `0` (one, 4676–4677). First-read global phase can skip/shorten the first display byte; B hold/cancel windows, contact, side effects, lag and PCM paths can alter elapsed timing. Multiplying advance count by 1/2/4 gives a useful nominal budget, not proof of exact wall-clock timing.

`E2` is a hit opportunity. Its first parameter contains collision flags plus the base damage profile, the second contains effect/sound/score information. Contact and the making-damage latch govern whether an effect succeeds (15778–15945). Repeated `E2` entries in a running strike are not a license to apply repeated damage after one confirmed effect. Low-Life Dash has a special pointer override to byte `36` hex (15829–15840); that alternate tail follows the first zero terminator in the normal stream and cannot be dropped from a faithful playback implementation. Some other animations intentionally fall through into the following named data block; the extractor follows actual contiguous bytes and marks these cases.

This keeps appearance playback separate from server combat authority. A reconstructed morph is visible cosmetic geometry; it does not silently create a second hit, resize the physics capsule or invent new target lock.

## First-route hero frames and hits

Frame IDs, counts and animation IDs in this section are hexadecimal except the decimal repeat/advance counts. A frame's actual outline and size must come from the sprite/metasprite source, not the identifier's name. The separate visual extraction supplies this reference; none of the following numbers authorizes a guessed R6 pose.

| State / source animation | Ordered graphics frames with decimal repeats | Display advances | First E2 after this many display advances | Evidence |
| --- | --- | ---: | ---: | --- |
| Jab A `02` | `19×4, 1D×8` | 12 | 1 | anims 71 |
| Jab B `04` | `1B×4, 1D×8` | 12 | 1 | anims 72 |
| Uppercut `06` | `18×9, 1D×2, 22×16, 1D×2` | 29 | 12 | anims 73–74 |
| Power punch `0E` | `1D×3, 18×8, 1C×21, 1D×4` | 36 | 12 | anims 81–82 |
| Heavy follow-up kick `12` | `21×8, 20×11` | 19 | 8 | anims 90–91 |
| Large boot `14` | `1F×12, 1E×25` | 37 | 13 | anims 92–94 |
| Running strike `16`, miss path | `23×18` | 18 | 1; eleven potential E2 entries | anims 95–97 |
| Dragon-target elbow `36` | catalog's `26→57` stream | 26 | catalog event index | anims 106–107 |
| Boss-ball forward throw `70` | catalog's `0E→61` stream | 22 | separate linked-object throw | anims 79–80 |

These streams establish distinct windup/contact/recovery silhouettes, including enlarged hand/foot forms. They are not the prototype's former arbitrary motor curves. For example, `23` inside the uppercut's E2 parameter is **not** another uppercut graphics frame.

Locomotion and other presentation are not all stored in the attack-pointer table:

- Walk: `04,05,04,08,06,07,06,03`; run: `05,05,08,08,07,07,03,03`. Carry walk: `11,12,11,10`; movement into/out of depth: `01,09,01,0A`. Tables: main 13635–13638. Selection is speed/counter/direction driven (8298–8346); run rendering also considers both source players' speed/floor conditions.
- Idle `01`, blinking `02`: 8369–8385. Airborne without a held object: unsigned `(Zspeed+2)&255 < 5` selects `2D` near the apex, otherwise `05`; carrying jump uses `2E` (8190–8204). This is not an invented linear two-frame jump cycle. Holding a linked object while standing is `11` (8362–8365).
- Light reaction: stunned/eyes-closed `02`, front damage `29`, rear damage `16` (6581–6592). Heavy airborne reaction uses `13/14`; grounded states use `15` or `30` depending on source context (6694–6724).
- Special conditions have separate graphics: rope, electric shock, gas, fan capture, flattening and vehicle crash. Their verified source locations are indexed by the main handler; their full visual timelines remain separate work, not replaced by a generic stagger/death animation.
- Confirmed death/respawn selects mode-specific paths in 6735–6857. Importing a source respawn animation does not import source life/continue rules into BrickToads or reset its shared limits.

The source runtime has two playable slots; extending the source-derived poses to BrickToads' third hero remains an explicit modern adaptation. A separate Pimple intro graphic does not prove a complete third playable combat animation set in this ROM.

## Pig, Tall Walker and Dragon

| Family / animation | Graphics or articulated sequence | Display advances / caller stride | Effect |
| --- | --- | --- | --- |
| Pig `28` | `05×3→06×2` | 5 / 4 updates | E2 after 3 advances, profile parameter `00` |
| Pig `2A` | `05×12→06×6` | 18 / 4 | E2 after 12; sound + impact creation are commands |
| Pig running `40` | `06×6` | 6 / 4 | E2 after 1; profile parameter `04` |
| Walker heavy `3A` | Full numeric trajectory in catalog: `18` hold, descends through `16..08`, then launches through `0C..2A` and recovers | 62 / 1 | E2 after 48, parameter `82` |
| Walker light `3C` | Catalog's `14,10,0C,08…28…18` trajectory | 18 / 1 | E2 after 11, parameter `40` |
| Dragon headbutt `32` | `0B×11` | 11 / 4 | E2 after 3, parameter `84` |
| Dragon capture/link `34` | `0B×8` | 8 / 4 | E4 link after 3 advances; not an extra headbutt hit |

Pig source: main 16638–17143, anims 128–130. The attacking graphics differ from its speed-counter walk table `[03,04,03,02]` at 17143. Entrance/ambush creation is a separate state, not an instantaneous alias of ordinary Pig.

**Tall Walker is articulated.** Main 4608–4818 keeps full-body graphics frame `19` while counters and `sub_0_95BA` drive component coordinates; attack stream values are transformed by subtracting `18` before that procedure. They must not be interpreted as a succession of complete hero-shaped frames. Its head/leg/club transformation is part of the silhouette and animation contract. A humanoid wearing a Walker label is not sufficient.

Dragon's **final** normal cycle is `09,09,0A,0A`; a moving approach can force `09`, heavy/grounded disabled state uses `0A`, and light reaction includes `0C` (main 2943–3056, `object_dragon` / `byte_0_8A53`). Its shared flight helper temporarily writes `1C,1D,1E,1D` at main 5393, **but the Dragon caller overwrites that value when no attack animation is active**. Those shared intermediate IDs must not be rendered as canonical Dragon frames. This was cross-checked against the decoded source graphics, which exposed the wrong shared-frame interpretation. Flight approach/turn, mount, rider and captured-hero graphics/linking are separate source states; a complete flight-body transform still needs the visual source/model and physical mode integration.

## Boss Walker appearance: concrete source sequence

This sequence is a real authored intro involving the boss foot, frightened heroes, impacts, camera/perspective setup and music. It is not a generic fade-in.

Level-one config line 34 creates intro-foot object type `0D` at trigger `04D8`. The actual boss/turret composite records `0E/0F` have later trigger `06C0` (35–37). The source loader gives the object's fields and uses a clean slot; normal intro `Objects_cnt2` starts at zero. Main 4103–4137 increments it **before** testing milestones on each active unpaused object update. Object dispatch runs slots 0/1 before ordinary objects (2670–2844), so a helper write to hero animation can take effect after that update's player processing.

| Counter after increment | Source event | Nominal time at 60 unpaused updates/s |
| --- | --- | ---: |
| `01..DF` | `write_anim_fear` assigns hero animation `2C`, fear graphics `32` | initial phase |
| `30` | sound `62`; screen-shake byte `F8`; sound flag `08` | 0.8 s |
| `50` and later normal updates | intro foot graphics `12`, Z/level physics, X decreases by 1 only when `Z_floor != 0` | 1.333 s onward |
| `64` | second sound `62`, shake `F8`, sound flag `08` | 1.667 s |
| `E0` | **Camera/perspective cut and arena graphics setup**, boss music; fear helper is skipped on this branch | 3.733 s |
| `E1..FE` | fear helper selects animation `2E`, fear graphics `33` | post-cut phase |
| `FF` | delete intro-foot object; helper is not called on this branch | 4.25 s |

The `E0` branch calls `music_for_noga` (4193–4207) and bank-six function offset `5D`, which resolves to `sub_6000_8E74` (34374–34445). That setup cuts source camera to X `06C0`, Y `08`, changes palettes/graphics, recomputes each hero's X from its preceding Y, sets Y `0108`, adds `40` to Z, and clears source **state flags**. These are 2D perspective/setup operations, not ready Roblox coordinates and not a health reset.

`write_anim_fear` (4143–4187) runs for source slots 1 and 0, sets the fear animation, **masks the animation byte pointer with 7** rather than restarting it at zero, drops a held stick and unlinks a carried object. The released object gets X speed `40`, Z speed `02`. The fear streams themselves are anims 131–132: `2C` displays `32` and applies a small Z motion / X-from-shadow action; `2E` displays `33` and applies Z speed 2. Merely replacing these with two static R6 shoulder poses omits their body/face/form changes.

A nonzero hero animation takes the source animation branch before ordinary movement. The B selection path still executes; this does not establish a total input lock. No new invulnerability, HP restoration or resource reset was found in this helper. Existing interruption/contact rules remain authoritative. Seconds above are nominal counter conversion; exact wall-clock PCM/lag/PAL behavior has not been traced. Three-hero coverage and 3D camera/foot motion require stated adaptation and engine checks.

## Remaining families and boss intros

The catalog indexes each ordinary handler and every source mode. Raven/Large Raven, Invader, Rocket Rat, Saturn Toadtrap, Retro Blaster, Snowman, Snake components, Sentry Drone, Slime, Gas Turret, Hordhead, flying/head objects, Swellcheeks, Robot, Electrofish, Hammerfish, Shark and Duck have identified source handlers. **Their complete animation/proportion/state traces are UNKNOWN here**; dispatch labels and static records do not prove every runtime frame or dynamic actor.

Other boss intros are partially traced, so no shared invented choreography should be assigned to them:

- **Big Blag:** main 13055–13071 sets intro counter `80` on initial graphics frame 0, decrements it, faces direction `80` and calls the fear helper while nonzero. Full camera/spawn/body sequence remains unknown.
- **General Slaughter:** 13345–13458 starts boss music on frame 0; before counter `B5` calls a direction/fear helper that increments the counter. The early `<20` phase sets camera-Y auxiliary value `0C`; grounded later phase launches with Z speed 6. Full frame-table/camera interpretation remains unknown.
- **Robo-Manus:** 13462–13518 has a camera-gated setup, source player positioning/protection branch, graphics loading and music transition; while counter 2 is nonnegative it calls direction/fear. Full source setup chronology remains unknown.
- **Buzzball:** 14809–14878 traces the **same object's** chase-to-combat transition. At zero X speed it increments counter 3, pulses graphics/sound under `FrameCounter & 4`, calls fear, then changes type `7A→7B` when the counter sign becomes negative and starts boss music. Initial chase appearance is not established by this transition.
- **Dark Queen:** combat handler and animation `8A` are verified; both appearance/interstitial paths and final scene have not yet been followed to completion. They remain UNKNOWN.

## Next runtime contract

1. Store source clip identity and authoritative start/cancel identity on the existing actor; playback must not survive actor/run replacement. Build reconstructed visuals against measured source outlines/proportions.
2. Use a pure source-clock clip decoder with the exact per-caller stride and explicit first-read phase. Test opcode parameter arity, deliberate fall-through, repeated E2 opportunities and the Dash low-Life tail. Source clip clocks drive appearance; server combat accepts one authoritative hit under its existing contact/latch rules.
3. For the first-route boss add a finite **intro-foot → impacts/fear → arena perspective/camera cut → post-cut fear → active** sequence with cancellation on run end/replacement. Preserve HP, raw Life, attempts, respawns and ownership; three heroes is an explicit extension of the two-slot source helper.
4. Replace each first-route family and its attacks only after matching source visual poses and measuring them in Studio. Keep every remaining family/intro explicitly incomplete until its source path, rebuilt model and engine behavior have been reviewed.
