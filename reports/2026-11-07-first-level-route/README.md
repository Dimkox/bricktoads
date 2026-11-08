# First-level route and guardian acceptance

Date: 2026-11-07. Local Roblox Studio, final production sources. Build: `places/BrickToadsPlayable.rbxlx`, 282902 bytes, SHA-256 `cdd06a8cbcc98ddc6de122da6e4d89856ef2e129ac12de30d8d530ff9a059902`.

## Implemented

Six sequential original districts extend from the floodgate to the guardian court. Five real floor gaps include three raised cliff crossings. Each district requires its current enemies to die and a living hero to reach its physical far exit. Completed gates, district objectives, species silhouettes, safe respawn supports and independent group coordinates use the same definition.

The static source inventory supplies13 ordinary actors in order:9 pigs,2 walkers and2 dragons. This classification is documented in [the source note](../../research/2026-11-07-first-level-source.md); it is not a claim about a verified natural NES population. Ordinary combat remains the disclosed provisional shared profile.

The guardian uses ordinary bullets and a periodic special shot that becomes a ground ball. F picks up and then throws the ball. Three thrown impacts reduce raw guardian life47→31→15→0, open the final gate and allow the earned exit. The HUD changes its primary action label and blocks the heavy strike while carrying.

## Actual Studio pass

[Full traversal and guardian evidence](final-traversal-and-guardian.json) records run `c8196777-7536-43dd-91de-014d40d53517` on the final sources. The hero began at the normal initial spawn and used production Move/Jump/Attack packets throughout. No hero position, health or reserve edits were made.

A separate QA listener killed ordinary NPC Humanoids as they appeared, isolating traversal from ordinary combat. This is a prepared acceptance run, not an unprepared complete combat playthrough. The guardian, its bullets, heavy phases, pickup, throws, incoming damage and exit ran normally.

| Crossing | Result | Observed rise |
| --- | --- | --- |
| Aqueduct48→53 | LANDED | 5.10 studs |
| Cliff270→274 | LANDED | 5.02 studs |
| Cliff301→305 | LANDED | 4.97 studs |
| Cliff332→336 | LANDED | 5.09 studs |
| Long bridge530→535 | LANDED | 4.70 studs |

All five crossings used the initial actor, attempt1. The guardian received all three thrown hits. The server observed `Won` with that same hero at x670.036, y3.000, z1.440. Final raw hero life15; all3 respawns remained. [Guardian screenshot](guardian.png) shows2/3 hits during this run.

## Bugs reproduced and corrected

- Server-owned replication left the client showing x46.56 on the aqueduct while the accepted Jump reached the server at x50.57, already airborne beyond the x48 edge. Modern GameWorld now permits one server-verified jump within0.20 seconds of leaving a known support and at most3.5 studs of drop. Normal jumps consume the same allowance; an observed airborne phase and landing are required to rearm. It retains server ownership and rejects held, dead or reacting bodies. The separate combat stand retains its previous behavior.
- A thrown guardian ball initially entered the ordinary bullet collision branch, hit its thrower and disappeared on the first small simulation step. Only Bullet now tests hero collision. Regressions use real Session damage and0.1-second steps, keeping the thrower unharmed until the ball reaches the boss.

[Before-fix evidence](before-fixes.json) includes failed natural attempts and the accepted-but-airborne jump trace. Earlier isolated cliff probes used an incorrect enemy identifier and are explicitly excluded as acceptance evidence.

## Verification

[Native output](native-validation.txt): lifecycle46, Session40, connection ownership18, legacy Director30, Controller36, shared boss queue20, MatchHub11, modern route7, GuardianPattern13, real GuardianSession3 and world contracts10 pass. Existing combat assertions also pass. All53 Luau files compile. The builder's7 tests, deterministic rebuild/source check and gateway14 contracts pass.

Independent review found the thrown-ball regression and the direct boss impulse bypass; both have regression coverage and were fixed. A subsequent independent review of jump grace found no actionable P1/P2. Final Studio source synchronization removed all temporary production-script diagnostics. The QA driver is excluded from the generated place.

## Remaining acceptance

An [unprepared attempt on the final sources](unprepared-combat-attempt.json), run `0d2184ec-f424-4c5b-b785-b1c4a228201b`, cleared district1 and landed the aqueduct crossing, then exhausted its appearances during district2. It used the input-only QA pilot with no clearing listener or hero edits. An unprepared full combat clear remains unconfirmed; the prepared pass above must not be described as one. Full species AI/health, sticks, grabs, flies/items, dynamic source population and physical phone/tablet acceptance remain outside this transfer. Existing multi-client queue/group reports concern the earlier short battle and do not establish the new guardian's complete multi-client acceptance.

`places/BrickToads.rbxlx` retained its pre-existing local edits unchanged (SHA-256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`). The separate playable build contains the new level.
