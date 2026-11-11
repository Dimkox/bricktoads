# Course prop source references

This folder records the source evidence for all 28 remaining Roblox course renderer kinds. It separates proved NES source objects, procedural graphics, background components, and authored Roblox adaptations. It is research input for the 3D pack, not a claim that the game supplied 28 ready-made 3D assets.

The reference is **Battletoads USA NES (1991)**, [feos-tas/DisAssemble at f1a43b69577246850d136473700a333b3cdfe93f](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads). No ROM, emulator, video frame, screenshot repainting, or generated illustration was used. Internal source level IDs differ from playable course ordinals: Revolution is source ID05 and playable course12, Surf City is source ID0C and playable course5. `Level_ID_Table` at main.asm:14643 proves that order.

`source-catalog.json` has one `kinds[]` record per runtime kind, with `runtimeKind`, `sourceEvidence`, `status`, `sourceRefs`, `sourceTypes`, `graphicsFrameIds` where proved, `palette`, `rgbColors`, `appearanceCues`, `adaptationLimits`, and current `runtimeRefs`. Source refs link directly to the pinned upstream file and line ranges. RGB is an illustrative 2C02 display conversion; source palette indices and sprite attribute XOR are recorded separately.

## Coverage

| Runtime kind | Proved source evidence | Decoded reference |
| --- | --- | --- |
| AirMine | Exact source identity unproved; Mine78 is only a visual analogue | Authored full-depth flight-hazard adaptation |
| BoardingPad | Roblox boarding objective marker | Authored marker; no NES actor claim |
| Bomb | Type5A, gfxB3, `object_ratrace_bomb` | Green bundled three-lobed device; source cycles actor palette flags |
| Buzzball | Types7A/7B, **hero namespace** gfx7C–7F | Red/coral spiral orb, four frames |
| ElectricTrap | Type2E, gfx5A and5B, custom `electro_sprites` | Cyan paired endpoints and electrical component |
| Fan | Types54/55, gfxA3/A4 | Side-on pale/olive fan housing and blades |
| Gas | Type53, gfxA6–AA; zeroed child flags and authored turret context | Expanding pale plume and dispersing fragments |
| Gear | Type6B, gfxD0/D1; linked mirrored source halves | Gray toothed wheel halves |
| IceBlock | Type38, gfx6F/70/71 through shared physics table | White/lavender faceted rolling block |
| Icicle | Type39, gfx72/73 authored parameter | Two white/lavender hanging shards |
| Lift | Type4A, gfx90; FA/AC electrical variants recorded separately | Orange pillar/platform component |
| Log | Type77, gfxEC | Long orange/brown bark-grooved log |
| Mine | Type78, gfxEE; zeroed child flags and source creator context | Neutral gray/white naval mine |
| MovingIcePlatform | Type3E, gfx80 | Pale flat slab with irregular hanging teeth |
| Ramp | Type24 launch branch, gfx4B | White/pink angled wedge/diamond sprite |
| Rocket | Type6A, gfxCC/CD; zeroed child flags and source creator context | Neutral gray/white pointed up/down rocket |
| RocketLauncher | Type68 logical mine/fire/rocket creator; no visible source cannon established | Visible emitter housing is authored |
| Rope | Types06/07, procedural sprite placement, raw CHR tiles27/28/29 | Three gold/cream rope tile components |
| RotatingSpike | Type37, gfx6A | Pale radial pointed star |
| Snowball | Type3A, gfx75 via `electro_or_snow_gfx` | Small white/lavender orb |
| Spike | Types40/45, gfx81 | Clustered prongs on a low curved base |
| Spring | Type36, gfx67/68/69 | Orange base, pale upper pad, crossed/coil connector |
| Telegraph | Roblox `World:bossTell` radius footprint and DODGE marker | Authored boss cue; no NES actor claim |
| Tower | Revolution initial CHR load, background palette and block tables | 103 purple masonry/cyan sky background components |
| TowerPlatform | Type34, gfx65/66 | Orange projecting beam and separate sparkle/disappear component |
| Warning | Type49, gfx8A, camera-relative blinking source cue | White/pink exclamation mark |
| Water | Surf City initial background CHR, palette and block tables | 60 complete deep blue/cyan water and adjoining background components |
| Whirlpool | Type76, gfxED | Flat white/lavender elliptical spiral and dark center |

There are **21 kinds with 40 exact source metasprite frames**, one procedural rope family with three raw CHR tiles, two background adaptations, one logical source spawner adaptation, two Roblox system markers, and one kind with unproved source identity. `source-contact-sheet.png` contains the metasprites and rope components; each family has its own larger sheet. `tower-background-blocks.png` and `water-background-blocks.png` show static background components rather than reconstructed gameplay screens.

## Provenance and limits

The decoder reuses the established `research/canonical-visuals/extract_cast_frames.py` CHR/metasprite decoder. It reads literal source load recipes and checks all 46 existing source inputs against that pinned catalog. Seven added public source blocks are stored under `inputs/`; each download is checked against the pinned Git tree's blob SHA-1 and recorded with SHA-256. The script uses only Python's standard library.

Dynamic Mine/Rocket flags are explicitly zeroed at main.asm:11304–11307; Gas flags are zeroed at19188–19189. Their representative palettes use the first authored creator/turret trigger snapshot rather than an arbitrary red baseline. Bomb's source handler cycles flags0–3; its green render is phase0. Surf/Clinger live palette loops and exact interpreter scheduling remain separate. Rope uses procedural attribute2 and the initial source sprite palette, not a fabricated metasprite ID.

The Surf City background declaration requests224 tiles, while the available source stream plus proved adjacent RTI/padding yields207 complete tiles and a partial tile. **265 declared tail bytes remain unresolved.** The block sheet includes only blocks whose tiles are fully decoded; unknown pixels are never synthesized. The full source water screen and changing palettes are not reconstructed. Tower's 255 declared background tiles decode completely using its proved adjacent source block, but its live CHR animation and whole rotating screen projection are not reproduced.

AirMine's identity remains unproved. BoardingPad and Telegraph are authored communication. RocketLauncher uses source behavior as context while its visible body is authored. All depth, back faces, supports, extrusion and adaptation to Roblox collision/medium dimensions are authored. In particular, flight hazards may span depth44, Tower is28×105×28, and Water is a large medium volume; source sprite proportions do not override those runtime meanings.

## Reproduce and inspect

From the repository root, run:

```powershell
.tools/python-3.13.9/python.exe assets/props/canonical-course/source/extract_prop_references.py
```

The script writes only this folder, verifies53 source input hashes, checks exact28-kind coverage and nonempty evidence/cue fields, and writes `verification.json` with output hashes. It does not modify Studio, production Luau, Git state, Jira, the protected place, or other art. Static source verification is not a Studio or natural-play acceptance claim.
