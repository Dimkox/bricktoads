# English source language and Roblox localization

The owner requires all game inscriptions to use English by default and the selected localization language when localization is enabled. This covers menu controls, combat feedback, HUD, dynamic health/respawn/enemy counts, objectives, interactions, role and queue panels, and text in the 3D world. Player display names and gameplay identifiers retain their identity.

Use standard Roblox localization: English source strings and a shared catalog backed by LocalizationTable, AutoLocalize/RootLocalizationTable for GUI inscriptions and Translator:FormatByKey for dynamic text. RobloxLocaleId determines the selected player locale; no extra game language menu or remote is added. Russian is the initial additional authored translation. Missing translations fall back to English. External experience translations remain subject to configured Roblox localization.

Keep text formatting separate from gameplay data. Do not translate numeric values, actor IDs, action enums, run/group IDs or intent payload keys. Retain historical internal metadata needed to recognize and safely migrate the old saved preview, including its original LevelName value.

Verify English default, Russian static/dynamic text, unsupported-locale fallback, missing-key behavior and actual Studio table/translator integration. Compile affected scripts, run their existing contracts, and inspect both narrow mobile and world labels. Language changes must not alter the map seed, collision, resources or network authority.
