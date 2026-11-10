# Studio infinite lives

The owner's requested God Mode gives heroes unlimited respawns during Studio testing. Damage, death, actor replacement, attempts, level transitions and shield deadlines remain normal. A boolean preserves the ordinary finite reserve rather than substituting an inflated number. Disable the mode to resume consuming that reserve. Enabling does not revive eliminated heroes or reopen a completed run.

`ServerStorage.BrickToadsGodMode` defaults to `true` in Studio. The bootstrap authorizes it with `RunService:IsStudio()`. Attribute changes reach active groups and future runs/groups; published servers deny the mode even if the attribute was saved as true. There is no client toggle intent. The compact reserve displays `∞`; English source strings include Russian localization.

## Native acceptance

One existing Studio window, controlled exclusively through Roblox MCP, private place117412694427208, real owner11946162891. Source receipt `ac63cddc20693176ff29a7a1e4e3c5e76b6769b10641f7bb47188fcfa500cceb`. Run `92bf00d4-ea83-42a1-8598-f2b4cdd9a150`.

The disposable [client append](native-pilot.client.luau) sent the production Start/Move intents using the existing sender and walked the hero off an edge. The [server observer](native-observer.server.luau) read actual appearances and changed only the authorized God Mode attribute after attempt7. Neither fixture wrote health, actor identity, position, stock, phase or death state.

- Six actual deaths produced seven unique ordinary appearances, all with preserved stock3 and infiniteLives=true. Each replacement received normal Life47 and the normal shield.
- Turning the attribute off at attempt7 preserved stock3. Three further replacements consumed stock2→1→0; the next actual death ended the run Lost, without an eleventh appearance.
- The [terminal result and journal](native-result.json) were exported before Stop. This intentional Lost is the disabled-mode control, not a campaign failure.
- A subsequent public Start with the attribute true exposed `Mr. Green · God Mode`, `↻ ∞` and `∞ resp.` in the actual client GUI; [HUD receipt](native-hud.json). This is a text/state check, not physical-device visual acceptance.
- After MCP Stop, exact updated production bootstrap/client sources were restored (7186/89719 UTF-8 bytes), disposable append backup removed, Edit attribute true retained. No extra Studio windows or public release.

The separately exported native25 all13-stage Won used the earlier finite production source7c03 and **no God Mode**. Its archive remains unchanged; this feature's native fixture does not claim another all13-stage run.

## Regression and review

The [domain RED/GREEN report](../2026-11-10-infinite-lives-domain/README.md) covers zero-stock operation, six deaths, emergency retry deadlines, failed/duplicate spawn handling, finite reserve restoration, disabling a zero-stock pending respawn, eliminated/closed-run refusal and level preservation. Existing finite lifecycle/Session/combat checks remain required. Controller, group and Studio-policy tests cover defaults, live/future groups and public-intent denial. The current full [validation receipt](../2026-11-10-full-campaign-acceptance/final-validation.json) records the final source/build checks. Independent source and native-evidence review is retained beside this report.

Final full run: **58/58 commands passed**, **200 Luau files compiled**, protected starter and source inventory preserved; finished2026-11-10T20:05:23UTC. The previous pre-God56-command receipt is retained separately. The obsolete finite-only Core revision pin was explicitly updated to the reviewed infinite-lives revision, with source equality packaging checks retained.
