# Rotating Tower spring pads

09 November 2026. Turning Spire's two spring pads now stay attached to their moving platforms. Both the native graphics and the launch footprint use the same current platform position/yaw. Jump timing and steering remain the player's choice.

## Defect and change

Stage 12 authored springs at the initial centers of platforms 8 and 15. Platform support, native geometry and grounded riders rotated, while the spring graphics and launch check kept initial world coordinates. At rotation pi/2, a hero correctly grounded on tower-8 received the ordinary 52 impulse instead of the spring's 65. [RED test receipt](red-test.txt) records that failure before production changes.

[CampaignDefinition](../../src/server/gameplay/CampaignDefinition.lua) now identifies each spring's tower platform. [CampaignModes](../../src/server/gameplay/CampaignModes.lua) resolves one position/yaw and shares it between rendering and inverse-yaw footprint checks. Existing width allowance, depth/height limits, jump powers and airborne-jump guard are preserved. Stage 8's fixed Ascent spring remains static.

The [four new regression cases](../../tests/campaign_modes/CampaignModes.spec.lua) cover both springs across multiple rotations, current support identity, rendered alignment, rotated corners/edges, supported off-pad positions, airborne repeat input and the static Ascent spring. [Implementation plan](../../docs/superpowers/plans/2026-11-09-tower-springs.md).

## Native Studio evidence

[Exact saved helper manifest](native-helper-manifest.json): source `d3724283b11cc446ef78787f91de120b90c14927e701c77a5c64aed7e4c6bd6b`, 50 packaged scripts, playable 1,020,779 bytes/SHA256 `48dbeeb4c7b69f33edd5ef7444ac07eacf64c53a04d8e5be5cb7d7babfb57499`. Both changed module sources matched the loaded helper exactly. Studio 0.746.0.7461269; local helper PID22644/Studio d9afc1f7-2e3a-4cb8-b82c-c57dc2bb7185.

The [server fixture](../../tools/studio_tower_spring_acceptance.luau) uses actual Session, CampaignDirector, GameWorld, CampaignWorld and native Models. Stage, time and takeoff positions are explicitly prepared in isolated worlds; the roster is synthetic and ordinary AI is deliberately unstepped. Inputs go through validated Session Jump envelopes. No health, attempts, respawn stock or actor IDs are written by the fixture.

**146 named checks PASS**, plus both explicit teardown records. [Compact summary](native-summary.json), [raw native receipt](native-studio-first.json).

| Prepared case | Launch velocity | Native rise after one 1/60 s course slice | Raw Life / attempt / respawns |
| --- | --- | --- | --- |
| Tower spring1 | 65 | 1.041672 studs | 47 / 1 / 3 |
| Same platform, outside spring1 | 52 | 0.824997 studs | 47 / 1 / 3 |
| Tower spring2 | 65 | 1.041664 studs | 47 / 1 / 3 |
| Same platform, outside spring2 | 52 | 0.824997 studs | 47 / 1 / 3 |
| Static Ascent spring | 68 | 1.091667 studs | 47 / 1 / 3 |

Native CFrames/raycasts verify both springs at 0 s and 5 s (.8rad), real support below each pad and noncollidable pad geometry. Rotated takeoffs use later phases. Every jump retains original native actor/Model, run/level, health and stock. A second valid airborne Jump packet returns the existing API's OK acknowledgment but produces **no additional impulse**; no new rejection code is invented. Native Models rise through the production course pose adapter, which owns anchored mode bodies; this is not a claim that a free Humanoid physics jump drove the course.

## Validation and synchronization

[Full frozen-source validation](final-validation.json), [text output](final-validation.txt): **56/56 commands and 168 Luau compilations pass**. Campaign definitions 8, mode contracts 48, vehicle lifecycle 2, campaign progression 15 and all 30 real-Session normal-input course pilots across seeds1/41/8125 pass. The pilots use an in-memory world boundary and are not native route clears. Builder and source receipt checks pass; inputs stayed unchanged during verification. Lua5.4 is unavailable and excluded, not counted as PASS.

[Original Studio pre-sync](original-studio-pre-sync.json) verified the two target modules still matched the previous Git baseline. [Synchronization receipt](original-studio-sync.json) verifies exact replacement of only those modules and derived BuildInfo in the existing private experience10775039796/place117412694427208; saved through Studio UI, left in Edit. No public publishing or access changes.

[Cleanup receipt](cleanup.json): both prepared worlds/actor registries/native bodies were verified removed, local play stopped and the owned helper closed without saving incidental editor changes. The original private Studio and existing blank Studio remain open. Protected starter SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` and concurrent character/concept-art work are preserved.

This checkpoint accepts the focused rotating-spring behavior. A natural whole-Tower/full-campaign human playthrough, physical devices, final art/audio and real same-player reconnect remain outside this evidence. The latter still needs a second genuine account, currently unavailable. Jira BT-33/BT-26 retain their broader acceptance scope.
