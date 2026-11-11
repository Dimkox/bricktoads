# BrickToads release completion — 2026-11-11

The reviewed [playable place](../../places/BrickToadsPlayable.rbxlx) contains 62 production scripts. Final source SHA-256: `d10b584ba65bb3a913af281921ab8e7d9a2db8123862cc69cd6f16ac3f1aac8a`. Place file: 2,228,161 bytes, SHA-256 `b5007ad29f58264437f06d279b5f4d81d36f6950c5cf5dc96c4735d87eb4f91f`.

## Product changes

- Hero meshes stay hidden locally until their declared mesh, texture and surface-map resources match and fetch successfully. The physical body remains visible while a skin is unavailable; a pending or failed optional morph retains the ordinary limb or head. No physical assembly, health, ownership or campaign resources are written by the client gate.
- The results and spectator menus name the actual stage and boss. Final victory identifies the full campaign and Dark Queen. A human boss owner sees reaction progress separately from raw Life. Compact menus retain 44-pixel touch targets and scroll when space is limited.
- All three selection portraits use the existing authored hero artwork. A native `IsLoaded` check keeps the local portrait visible until the renderer can draw the uploaded image.
- Dark Queen uses the actual imported Hair joint. The accepted Spin continues moving it after its source clip ends and resets after interruption. Static course props skip cosmetic writes while unchanged, with invalidation for movement, animation, alpha, size and replacement.

## Native checks

The first native pass found two issues that the portable doubles missed. Normal Script and LocalScript code cannot read the legacy `SurfaceAppearance.ColorMap` property. The [server](initial-content-api-server.json) and [client](initial-content-api-client.json) probes verified the five modern `*Content` getters and signals; the gate and factory now use those. The first client also showed a blank Brown card after a successful preload callback and before `IsLoaded` became true. Both regressions have focused local tests and were checked again in Studio.

The [corrected gallery](prepared-hero-normal-server.json) started in a normal server Script. All three private R6 actors preserved their physical state. The actual production coordinator on the client reached [Ready for all three](prepared-hero-ready-client.json), each with 15 visible base meshes, four referenced source images, and no visible physical duplicate. [All four morphs](prepared-hero-morph-loads.json) reached Ready for each palette; a bounded [transition log](prepared-hero-transitions.json) records pending and ready states. Deliberately invalid private base and morph textures preserved the [appropriate fallback](prepared-hero-failed-textures.json) through failed retries. Source-image readiness does not itself establish correct processed PBR pixels.

All three [portrait image labels](hero-portrait-native-images.json) became ready, and the [portrait phone capture](phone-portrait-hero-selection.jpg) shows the rendered images. iPhone 17 Pro simulation measured a 401×778 portrait and a 750×381 landscape viewport. Role targets were 44 px tall in [portrait](phone-portrait-hitboxes.json) and [landscape](phone-landscape-visible-hitboxes.json); the landscape Start target was also 44 px. The native localization table returned English and Russian start/restart strings. Physical touch hardware and simultaneous real touch input were not tested.

The [prepared Queen check](prepared-queen-hair.json) used the actual native imported Hair Motor6D. It measured source 0x81 and 0x82 angles, continuing Spin movement, interruption and rest reset without changing the physical torso. This does not prove a gameplay producer for the unresolved exact NES 0x83 selector.

## Finite campaign and restart

In one normal Studio window, the input-only client pilot finished [all 13 stages](campaign31-full-analysis.json) with **God Mode off**, run `bricktoads-release31-0-l6uuca`, seed `1158731273`. The server recorded 914 observations over 961.46 seconds, three falls on the first stage, and a living hero at attempt 4 with stock 0 and raw Life 47. No real player position, health, stock or progress was written by the test harness. The journal recorded the Guardian's three hits, Big Blag phases 1/2/3, and phases 1/2 for Robo-Manus, General Slaughter, Buzzball and Dark Queen. All finite acceptance checks passed.

The [victory screen](campaign31-victory.jpg) said `CAMPAIGN COMPLETE!` and named the 13 stages and Dark Queen. A [real click on New game](campaign31-new-game.json) created a distinct run and hero on attempt 1 with stock 3 and raw Life 47. The [full samples](campaign31-terminal-samples.json.gz), [sampled archive](campaign31-terminal-archive.json), and [export checksums](campaign31-exports.json) retain the evidence.

The full run used source `7e8e037b8f50826e3f483cc73f4b1b62cae3e1ff7d629229a9d81de56c21ae14`. While it ran, integration review caught that the ordinary spawner hid the six fallback body parts before the hero attachment could capture them; [native pre-fix data](spawn-fallback-native-before.json) confirmed six alpha values of 1. The final build only changes this appearance ordering and the source receipt relative to the full run. A [separate uninstrumented Play](spawn-fallback-native-after.json) on the final build verified the actual same spawned hero had six visible fallback parts while pending, then 15 visible canonical meshes and zero visible fallback parts when ready. The root remained invisible, ownership stayed server-side, and the old stand eyes were removed as before. The new `World:spawn` regression fails on the original ordering and passes on the final ordering. The full 13-stage run was not repeated after this cosmetic fix.

The final build also passed a live HUD check in [portrait](final-phone-gameplay-portrait.jpg) and [landscape](final-phone-gameplay-landscape.jpg); the [measured](final-phone-gameplay-hitboxes.json) status, objective, audio, direction, attack and jump targets were at least 44×44. Studio ended in [clean Edit mode](final-restored-edit.json), with all 62 final production sources matching, the original God Mode setting restored, 28 prop templates and no owned QA copies.

The native campaign [presentation observer](campaign31-presentation.json) had no errors or anomalies. [Clinger heading](campaign31-heading.json) retained 220 Ride observations with minimum hero/vehicle facing dots 0.99999994/1. [Client AV](campaign31-client-av.json) observed all 13 stages and retained 62 asset representation warnings, with no ScriptContext errors in the [console export](campaign31-console.json). The AV collector recovery is documented [here](campaign31-collector-notes.json).

## Verification and delivery

[82 local checks](validation.json) passed before native corrections, [12 affected checks](validation-after-native-fixes.json) passed after the resource and portrait corrections, and [8 affected checks](validation-final-spawn.json) passed after the spawn correction. The implementation commit `bc4590b25b5f12ca10efb306c4f7d14779361fda` passed [BrickToads](https://github.com/Dimkox/bricktoads/actions/runs/42978983515) and [Combat stand](https://github.com/Dimkox/bricktoads/actions/runs/42978983536). [PR #4](https://github.com/Dimkox/bricktoads/pull/4) contains the game changes and this evidence. The protected starter remains SHA-256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`.

[Jira receipts](jira-sync.json): comments 10514–10517 update BT-26, BT-61, BT-64 and BT-74. Issue statuses were preserved because the broader acceptance criteria still include live multiplayer, reconnect or physical devices.

## Release destination

The chosen production experience is a separate `BrickToads`. The connected Studio MCP rejected the [universe creation request](release-create-universe-probe.json) with 404; the test experience was not repurposed. Roblox's [place publishing documentation](https://create.roblox.com/docs/cloud/guides/usage-place-publishing) requires Studio publication to update `SurfaceAppearance`; the MCP upload transport also excludes `.rbxl` and `.rbxlx`. To create the private production destination, open the clean playable file in the existing Studio window and use **File → Publish to Roblox As… → Create new experience → BrickToads**. Public audience and real multiplayer/device acceptance are separate steps.
