# Seeded sections, isolated parties and English localization

Validated playable source: `77f80c0a2f23429e4ae8147701ee24e096c083a2de567b2257f845a7a73afe51`.
Packaged place: 525813 bytes, SHA256 `b0ad4fc05a02350d3dbeef4fd9086aa23c853f4de821b7cc9f150a5d3f71412c`.
All35 packaged scripts were synchronized to the original Studio Edit. The actual serialized playable file was independently opened in another Studio for final engine checks. User starter `places/BrickToads.rbxlx` remains unchanged at SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`.

## Implemented

- A new accepted run assembles one of three authored variants in each of the six districts. The server derives its seed from the run ID and records seed/version/section choices. The canonical level template stays immutable. Respawn and rejoin retain the current route.
- Each party owns its configuration and geometry. Rejected starts and actor-present rebuilds preserve the current run. Side stone cover is collidable district support. No player navigation, alignment or automatic jump assistance was added.
- Party faults are isolated, the boss queue avoids reentry during eligibility and action denial feedback is scoped to its owner and current body/connection. Faulted parties offer a deliberate new run.
- English source text covers the game UI and world signs. A364-entry standard Roblox table provides Russian translations; dynamic counts, team names and timers use Translator formatting. Missing languages fall back to English and player names retain their text.

## Evidence

`final-validation.json`: all38 native/Python/build commands and compilation passed; runtime/test/tool sources stayed unchanged during validation. Native checks include 1000 generation seeds, independent controllers, support identity, fallback, resource rules and localization coverage.

`geometry-final.json`: 45 engine checks passed on the packaged source, including accepted-run installation, denied Start, actor-present refusal, real death/respawn, rejoin, loss/restart with a fresh seed, peer body/map preservation, journal/snapshot metadata, physical floor offsets, cover rays and five genuinely empty gaps. The isolated server fixture deliberately prepares deaths and lifecycle state; it is not a normal-input full-route run or real cross-server reconnect.

`jump-final.json`: 15 real World walk16/jump50 crossings passed for seeds1,48,842, collectively selecting all18 authored district variants. Tested gaps4–5 studs and rises up to2 studs. Takeoff bodies are explicitly prepared in this fixture. These results establish sampled physical crossings, not automatic player navigation or a campaign clear.

`localization-native.json`: real Roblox table/translator methods produced English, Russian and unsupported-language English fallback. `localization-world-ui.json`: real world signs/gates resolve to Russian, UI is bound to its table, owner labels disable automatic translation. `english-default-lobby.png` and `english-default-gameplay.png` show the native UI in the selected English locale. A real desktop UI click started the run; no debug remote was added. `english-mobile-portrait.png` and `english-mobile-landscape.png` show the compact English HUD on iPhone17Pro emulation; the layout fixture also sent a standard production Start intent directly, so it is not physical-touch acceptance. English Attack/Jump and summaries fit both views. Physical touch and full Russian mobile layout remain untested.

## Canonical art direction and remaining work

The explorer model shown in `green-toad-art-preview.png` and `green-toad-r6-fit-zoom.jpg` is a **rejected study**, not a canonical character. Its15 meshes/15PBR/47attachments were confirmed after an actual XML import, and the generic cosmetic adapter was checked independently. Normal builds exclude its templates; the server does not inject the adapter. `--include-character-study` exists only for isolated pipeline research. Three source Studio preview clones were moved to ServerStorage studies and disabled for release.

The owner subsequently required all heroes, enemies and bosses to be recreated from the original NES proportions, poses and attack/morph animations, including boss introduction. This new art direction is recorded in the canonical-character spec; source frame and animation extraction is separate ongoing work. It is not completed by this report.

Full normal-input first-route completion, fresh duo/trio campaigns, real transport/reconnect, physical multitouch, performance acceptance, other twelve modes, all characters, audio/effects and public deployment remain open. See `docs/FULL_GAME_SCOPE.md`. No public experience was published or repurposed.

Initial `geometry-initial.json` / `jump-initial.json` concern earlier source `9ff38398…b76183`; final evidence above supersedes them. The initial jump sample used seeds1–3 and did not cover all section variants.

The artifact check caught an existing packaging omission: StarterGui orientation was not serialized. A RED→GREEN build contract now preserves Sensor (enum4); the final artifact supports both orientations. The original imported source fingerprint did not change. Studio used the matching Sensor setting for the mobile views and was reset to its default device viewport after testing.
