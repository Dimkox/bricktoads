# Canonical animation query domain

`src/server/gameplay/CanonicalAnimation.lua` is a pure presentation profile. It reads no actor, game service or clock and applies no command effects. Runtime integration, reconstructed meshes and Studio visual acceptance remain separate. Its pinned source catalog and SHA-256 provenance are available through `provenance`; untraced family FSMs, remaining boss appearances and 3D velocity/proportion mapping remain explicitly unknown.

## Clip queries

- `ids()` returns a frozen array of the 69 even animation IDs `0x02..0x8A`.
- `describe(id, options?)` returns frozen metadata: source label/lines, `displayAdvances`, branch and deliberate label fall-through. Unknown IDs return `nil, 'UNKNOWN_ANIMATION'`.
- `sampleAdvance(id, advance, options?)` returns `{animationId, branch, advance, frameId?, ended, events}`. Advances start at zero. Command parameters never become frames. A command-only clip may end at advance zero with events and no frame. A sample after the end has no frame or repeated commands.
- `eventsBetween(id, previousExclusive, nextInclusive, options?)` returns frozen command markers in source order. Use `previousExclusive=-1` to include commands before the first display byte. Events include `kind`, `opcode`, frozen `params`, source byte offset, display advance and `appliesDamage=false`. An `E2 / HitOpportunity` marker does not confirm contact or apply a hit.

`options.branch` is `Normal` by default. The verified alternative `DashLowLifeTail` is available only for animation `0x16`. It enters source byte `0x37`, after the normal stream's zero terminator, because the successful low-Life effect overrides the pointer to `0x36` and the source continuation then increments it. The tail displays `0x31×11`, then `0x23×4`. The query does not select this branch by inspecting or changing health; the authoritative caller selects it.

## Explicit source clock

`sampleClock(id, clock)` accepts this structure:

```lua
{
    elapsedCalls = 0,             -- zero-based unpaused interpreter-call offset
    callerMask = 1,               -- exactly 0, 1 or 3
    firstFrameCounterPhase = 0,   -- required integer 0..callerMask
    firstRead = 'Advance',        -- 'Advance' or 'Read'
    branch = 'Normal',
}
```

`Advance` models entry through `start_read_anim`: increment the byte pointer when `(FrameCounter & mask)==0`, then read. `Read` models a first read through `read_obj_anim` without that initial increment; subsequent calls use the supplied mask. `DashLowLifeTail` forces first-read mode `Read`, matching the immediate successful-effect continuation. The first global counter phase is required rather than guessed. `callerMask('Hero')=1`, `callerMask('Pig')=3`, `callerMask('TallWalker')=0`, `callerMask('Dragon')=3`; remaining callers return `UNKNOWN_CALLER` until traced.

The result contains the current source `frameId`, source byte offset, end state and **only the command events consumed on that call**. To retain markers when rendering skips source calls, iterate the elapsed call interval; do not sample only its endpoint and assume intermediate commands replay. Later end samples carry no repeated termination events. Queries are bounded to `0..4096` calls and cache immutable schedules. Invalid clock data fails explicitly. Entering an unverified source context can return `UNKNOWN_OPCODE` or `SOURCE_BOUNDS`; it must not be treated as a newly invented pose.

This clock executes only byte-pointer/command-length logic. It never executes speed, link, hit, sound, weapon creation or cancellation effects. Actual B hold/cancel paths, contact-triggered pointer overrides, lag/PCM/PAL timing and complete caller FSMs need their own verified integration. Literal source frame values may also need caller postprocessing: Tall Walker drives articulated components, and some boss callers OR a high bit before rendering.

## Locomotion selectors

`heroFrame(state, input?)` returns one verified source frame or an explicit error. Supported states are `Idle` (`blink` optional), `Walk`, `Run`, `CarryWalk`, `DepthWalk` (`phase` is an explicit zero-based cycle position), `CarryIdle`, and `Air`.

For `Air`, `holding=true` chooses `0x2E`; otherwise an integer `zSpeedRaw` in signed-byte or byte form is required. Unsigned `(zSpeedRaw+2)%256 < 5` chooses the apex frame `0x2D`, otherwise `0x05`. Mapping Roblox vertical velocity into source raw speed is an integration decision, not performed here. Selecting `Run` is also the caller's responsibility; this helper does not claim the source's complete two-player speed/floor gait selector is reproduced in a three-player 3D scene.

`dragonFrame(state, input?)` supports `Locomotion`, `Disabled`, `LightReaction`, `Attack` and `Capture`. Normal cycle positions yield `09,09,0A,0A`; `approaching=true` with nonzero `zSpeedRaw` chooses `09`. Disabled selects `0A`; a light reaction `timerRaw>=0x26` selects `0C`, later reaction uses the normal cycle. Attack/capture selects `0B`. These are **final Dragon caller frames**, replacing the shared bird helper's intermediate `1C/1D/1E` values.

## Boss Walker intro

`bossWalkerIntro(counter)` requires the already incremented source counter `1..0xFF` and returns presentation facts: fear assignment/frame/pointer mask, foot frame/motion, stomp, camera cut and end state. `bossWalkerEventsBetween(previousExclusive, counterInclusive)` covers skipped updates and returns the two stomp markers (`0x30/0x64`), foot motion start (`0x50`), arena cut (`0xE0`) and end (`0xFF`).

`fearAnimation` is a **write request**, not a complete actor state: source animation `2C` is written through `DF`, nothing is assigned on the `E0` camera-cut branch, and `2E` is written from `E1` through `FE`. A nil assignment at `E0` or `FF` does not clear existing fear; the last clip can finish naturally. `clearExistingFear` remains false. The source masks its pointer with 7, drops a stick and unlinks carried objects; the profile reports those facts without performing them. The camera setup is a 2D perspective cut and must not be used as literal Roblox world coordinates. No health reset, new shield or damage effect is emitted. The source helper covers two hero slots; applying its presentation to a third hero is an explicit adaptation.

## Verification and regeneration

Run `.tools/luau-0.745/luau.exe tests/run_canonical_animation.luau` for the native contracts. The generated literal can be checked without writes using `.tools/python-3.13.9/python.exe research/generate_canonical_animation_data.py --check`, or regenerated by omitting `--check`. It comes from the checked-in [catalog](../research/2026-11-09-canonical-character-animation-catalog.json), whose read-only extractor verifies four pinned source hashes. No engine acceptance is implied by these commands.
