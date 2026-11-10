# Rope, riding and Serpents — 10 November 2026

## Fixed behavior

The last mounted hero could exhaust all three reserves while a living teammate remained on foot. Vehicle retry detection ignored that teammate, entered `Lost` with an `Active` Session, and permanently froze a later valid boarder at X24/speed0. Surf, Jet and Speeder share this path.

Retry detection now includes every unfinished living or pending-respawn actor in the fixed cohort. The existing waiting, stop, rewind and restart sequence handles later valid boarding. Session still owns deaths, stock spending and replacement identities; genuinely lost runs cannot restart and eliminated riders remain eliminated.

[RED evidence](late-boarder-red.txt) reproduces the deadlock for all three stages, while the three genuine run-loss cases already pass. [GREEN evidence](late-boarder-green.txt) passes all six real-Session regressions after the fix.

## Native Studio checks

Freshly opened `places/BrickToadsPlayable.rbxlx`, Studio `0.746.0.7461269`, local Edit DataModel, source SHA256 `88597bef8c796dcbfc233312f075571891a41f32dee9d1a8dbb7b5de4fad342b`. The loaded CampaignModes Source matches the local source exactly. Each standalone helper returns a JSON receipt with the same BuildInfo hash.

| Scope | Named checks | Fixed ticks | Result |
| --- | ---: | ---: | --- |
| Stage2 Rope | 112 | 447 | PASS |
| Stages5/7/3 Surf, Jet, Speeder | 201 | 252 | PASS |
| Stage6 Serpents | 64 | 962 | PASS |
| Total | 377 | 1661 | PASS; all eight world cleanups pass |

- [Rope receipt](rope-native.json): two synthetic heroes swing and descend to checkpoint2 with native ropes matching anchor/body endpoints. A native below-FallY pose becomes one Session-confirmed Fall, then attempt1/stock3 becomes attempt2/stock2. The other body and resources remain unchanged. A prepared Raven contact uses native target queries and Session's contextual primary attack: RopeStrike profile7 changes raw79→71, then the ordinary RavenReaction death path runs.
- [Riding receipt](riding-native.json): actual entry-patrol damage prepares the boarding gate; three native falls and ordinary paid retries exhaust the first rider's stock. An authored swept hazard then eliminates that rider. The living foot teammate can board through a Session Attack, complete the normal rewind, steer and jump/lift while keeping actor, Model, attempt1, stock3 and raw47. Separate solo cases stay genuinely Lost. All three shared modes pass.
- [Serpents receipt](serpents-native.json): two stationary heroes ride different segments for960 slices through outbound/return travel and across all four first-coil support identities. All16 native segments match logical poses and dimensions, all four spikes remain active, and resources/Models remain unchanged. An ordinary walk across the prepared first exit opens checkpoint2 for both heroes without moving the trailing body. A real native fall then spends exactly one paid retry onto the opened room ledge at X80/Y9/Z2.

The committed helpers are `tools/studio_rope_native_acceptance.luau`, `tools/studio_riding_native_acceptance.luau` and `tools/studio_serpents_native_acceptance.luau`; raw MCP receipts are retained beside the parsed results. Every helper closes its director, clears actor registries and removes the native bodies/worlds it owns. The owned local Studio helper is closed without saving its lighting migration or test-world changes.

## Verification and scope

The frozen-source suite passes56/56 commands and compilation of174 Luau files, with unchanged verification inputs and matching source/playable packaging. See [final validation](final-validation.json), [command output](final-validation.txt) and [verified file hashes](verified-files.json). The protected starter remains SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`; concurrent concept art is excluded from this change.

The changed CampaignModes Source and derived BuildInfo were synced into the existing private place117412694427208 only after its original bytes matched the Git baseline. Their final Sources match the checked local playable exactly. The private version was saved through Studio's Save to Roblox with Notes as `Fix late boarding after rider elimination`; no public Publish action was used. The owned local helper was then closed without saving. The original private Studio remains open and contains no QA folders.

Native fixtures use synthetic server rosters and explicitly selected poses, lanes, contacts and phases. Rope and riding ordinary AI are unstepped; Serpents steps the full director. Prepared gate damage does not establish natural entry combat. These results do not claim actual Players, network, keyboard/touch, unprepared full human routes, every seed, complete art/audio or production acceptance. No player navigation or automatic safe crossing was added. Actual same-account return to its original live body still needs the second genuine account that is currently unavailable.

Git commit/push, CI and Jira delivery receipts are recorded in the delivery message and Jira comments, without embedding a self-referential commit hash in this report.
