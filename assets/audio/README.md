# Original authored chiptune audio

`generate_audio.py` generates the two production mono PCM16, 22,050 Hz WAV atlases
and `atlas.json` with exact sample-aligned regions, RMS, peaks and SHA-256 hashes.
It uses only the Python standard library. Run from the repository:

```
.tools/python-3.13.9/python.exe assets/audio/generate_audio.py
.tools/python-3.13.9/python.exe tests/audio_fx/test_audio_assets.py
```

The 16 SFX and four music compositions are original pulse, triangle and seeded
15-bit noise synthesis. Pitches, rhythm, timbre, envelope, volumes and durations
are authored here. The generator never reads source music, ROM bytes, original
samples, instrument data or note sequences. The waveform vocabulary is inspired
by the limited channels of an NES; this is not an emulation or recreation of the
original soundtrack. Both files are comfortably below seven minutes. Atlas
regions have 180 ms silent separators and zero endpoints. Use the region bounds
exactly; never play an entire atlas as one cue.

`Level` has a brisk bass-led action arrangement; `Boss` uses a faster chromatic
pulse pattern; `Result` uses a rising major-key figure; `Lobby` uses a slower,
lighter arpeggio. Whole-region 6 ms ramps produce a bounded, click-free loop seam.
The short zero transition is an authored arrangement choice. `Result` is a music
loop distinct from the one-shot `Victory` and `Defeat` SFX.

## Source-informed placement, not copied audio

The inspected public source is pinned to
[`f1a43b69577246850d136473700a333b3cdfe93f`](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads).
Line references below describe the checked-in decoded `build/canonical-source/main.asm`.
They are placement facts, not licenses to infer an original pitch or recording.

| Inspected source fact | Client adaptation |
| --- | --- |
| `set_level_music`, `set_music_by_level_id` and `set_music_track`, lines 1900–1923, select music by level/context. | Switch to the authored `Level` loop for an active owned group. |
| `music_for_noga`, lines 4193–4207, selects boss music during the Guardian setup. The intro also calls sound `62` at source counter `30` and `64`; see existing canonical animation research. | Switch to the authored `Boss` loop when authoritative boss state is active; `BossWarning` is a separate bounded authoritative-event cue. No ROM cue is extracted. |
| `anim_make_hit` / `anim_damage_by_table`, lines 15778–15945, check contact and the making-damage latch before damage effects and `some_sound_flag`; the effect path includes a special final-boss sound `46`. | `Hit`, `Club` and `BossHit` play from confirmed effect events, rather than every render frame or repeated attack opportunity. All three sound designs are original. |
| `anim_play_sound`, lines 16286–16297, reads channel and sound parameters and calls `jump_to_play_sound`. `jump_to_play_sound`, lines 2117–2121, dispatches sound through the bank path. | The runtime has an explicit event-to-authored-cue catalog. It does not execute or copy the original audio driver. |
| `timer_end_music`, lines 1977–2000, handles a level-end music flag and contextual music selection. | Run result selects authored `Result` music plus one `Victory` or `Defeat` one-shot. |

Other cue placements (`Shield`, `Miss`, `Throw`, `Fly`, `Spawn`, `Crash`, `Bomb`,
`Death`, `Equip`, `EnemyDeath`) are explicit Roblox presentation adaptations to
existing confirmed events and snapshot transitions. Their exact original sound
IDs and source timings are not claimed. They do not change damage, physics,
resource counts or inputs. The source-informed requirement is satisfied by the
confirmed-effect and contextual-music placement model; source-perfect audio
transfer is not claimed.

The reproducible PCM manifest keeps platform IDs `null`; `roblox-audio.json`
records the actual MCP uploads and their separately observed moderation/native
status. `AudioCatalog.luau` uses those real IDs. The runtime requires loaded
assets with sufficient `TimeLength` before playback can be ready.
Generated WAV quality checks establish authored PCM correctness; only Studio can
establish upload availability, `IsLoaded`, `TimeLength`, `PlaybackLoudness` and
actual device playback.

## Client playback API

`GameAudio.new(deps?, catalog?)` owns eight SFX voices, one music voice and a
`CombatEffects` controller. Call `sync(rawSnapshot)` only with the existing
authoritative snapshot. First sync and group/run/level/controlled-actor changes
establish a baseline; stale, duplicate, old-level and retired-actor feed rows do
not replay. A fresh matching owner `CommitSpawn` beyond the previous cursor may
cross the actor-replacement baseline within the same group/run/level, so actual
respawns remain audible. A cue missed while loading or muted is consumed permanently. The
campaign boss's authoritative `Tell`, life and progress transitions fill cue
gaps absent from the existing public journal; they never change gameplay.

`setMuted(bool)` mutes all audio, `setMusicMuted(bool)` mutes only music,
`setEffectsEnabled(bool)` controls cosmetics, and `setReducedFlash(bool)` dims
the local particles. Audio mute leaves effects enabled. `destroy()` stops and
destroys owned instances. `diagnostics()` reports configuration, actual load
readiness and pool limits. Native sounds use Roblox's documented
[`PlaybackRegionsEnabled`, `PlaybackRegion`, `LoopRegion`, and `IsLoaded`](https://create.roblox.com/docs/reference/engine/classes/Sound).
Both regions use identical atlas bounds, and only music has `Looped=true`.
Living players can open the existing Sound/Music toggles through a compact
44 px HUD Audio button, then dismiss the panel. The controls return to the menu
when the run/view changes; the popup does not pause or send gameplay intents.

Effects resolve actor roots only inside the current `GroupId` world, never use
queries/touches/collisions, and remain capped at 24 anchored cosmetic parts.
Tween/Debris lifetimes clean up between snapshots; scope resets destroy them
immediately. The injectable voice/particle factories exercise the real policy
in CLI Luau without pretending that a fake engine establishes native playback.

Run both policy and PCM checks cross-platform with
`python tests/audio_fx/run.py --luau /path/to/luau`, or the policy alone with
`.tools/luau-0.745/luau.exe tests/run_audio_fx.luau`.
