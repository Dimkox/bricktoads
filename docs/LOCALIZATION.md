# Game text and localization

English (`en-us`) is the source language for the playable game: menus, compact HUD, instructions, combat feedback, objectives, enemy role descriptions and world signs. The old Russian `LevelName` value in the server bootstrap is retained only to recognize and remove a historical saved preview; it is not player text.

`src/shared/TextCatalog.luau` contains standard Roblox `LocalizationTable` entries. Russian is currently curated; other missing languages fall back to English. Additional enabled translations belong in each entry's `Values`, using Roblox locale identifiers. This does not silently select Russian from the operating system language or add a custom language selector.

The client creates its own standard table under `LocalizationService`, sets `SourceLocaleId` to `en-us`, and uses the selected `LocalizationService.RobloxLocaleId`. Static UI and world BillboardGui labels use `AutoLocalize` and `RootLocalizationTable`. Dynamic counts, group names, invitation time and host messages use `GetTranslator(localeId):FormatByKey(key, arguments)`. Changing the selected locale refreshes these dynamic labels. Failure to load or format a translation retains readable English.

Player display names and usernames stay unchanged. They are passed as ordinary format arguments, never with the `translate` format specifier; their owner labels have automatic localization disabled. Project-owned group names use the structured `group-N` identifier, translated as `Team {index:int}`.

Checks:

- `luau tests/run_localization.luau`: catalog argument parity, English default, Russian formats, locale changes, English fallback and panel integration.
- `python tools/test_localization.py`: English gameplay source coverage, explicit dynamic format coverage and legacy metadata compatibility.
- Packaged source `77f80c0a…73afe51` was opened in a separate Studio: real table creation, `GetTranslator`/`FormatByKey` for English/Russian, unsupported-language English fallback, world-label binding and protected owner names passed. Native UI started an English run; lobby/HUD screenshots and actual Russian translator results are in `reports/2026-11-09-section-variation/`. Selected-language mobile/device rendering remains unverified.

The independent `CombatStand` is a developer acceptance fixture and is not bundled into the playable game UI.
