# Native campaign acceptance

This is automated Studio gameplay acceptance through Roblox MCP. Production NPC AI and authored hazards remain active. Connected clients share the existing production sender, sequence, actor/run/connection identity and RemoteEvent. The pilot sends only ordinary Start/Sync/Move/Jump/Punch inputs, including normal running. It never assigns an actor pose, health, reserve, enemy death, boss phase, campaign index or completion flag. Player navigation in production is unchanged.

Production fix50552e8 permits one explicit jump out of a physically supported native Climbing edge hang. See [edge-jump.md](edge-jump.md). The protected starter place remains SHA2561974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353. The playable source receipt is19d30b64738cf3858e2a33ffea07a381fda8b093a4e850b44751c646e1e19bf9.

## Actual progress

| Attempt | Clients | Result |
| --- | --- | --- |
| 01 | Registered Archaicus14 Studio Play | Native Climbing/Air edge hang observed; stopped for investigation. |
| 02 | Registered Archaicus14 Studio Play | All13 first-level ordinary enemies defeated and one Guardian return; natural Lost. |
| 03–04 | Registered Archaicus14 Studio Play | Natural fall losses while improving test input policy. |
| 05 | Three standard Studio clients | Uncoordinated friendly fire,12 confirmed deaths and ordinary reserve accounting; Lost. |
| 06 | Three standard Studio clients | Same run completed levels1–5, including Guardian and all three Big Blag phases; Lost on Serpents6. Full trace retained. |
| 07 | Three standard Studio clients | Normal controller reached Jet7, then Lost. Last observed metadata retained; complete trace unavailable after test disconnection. |
| 08 | Three standard Studio clients | First-level Cliffs blocked by two live Dragons pinned below DistrictSupport. Native positions, upward rays and lift state retained in native-dragon-obstruction-before.json. Test disconnected without a terminal archive; no full completion claimed. |
| 09 | Three standard Studio clients | Normal run completed levels1–7, including three Guardian returns and all three Big Blag phases. Natural Lost on Ascent8 after all12 cohort appearances were spent. Complete terminal archive retained; QA ascent steering did not recover lateral knockback/checkpoint offset. |
| 10 | Three standard Studio clients | Fresh run requested with the grounded Ascent exit guard and repaired QA ascent steering; result pending. |

The registered Play client was Archaicus14, user11946162891. Standard multiplayer tests use simulated Player1/2/3 identities(-1/-2/-3), not additional genuine accounts. They are started with StudioTestService:ExecuteMultiplayerTestAsync through MCP. Each hero keeps its own three paid respawns across levels; eliminated cohort members remain eliminated. Automated intents establish neither physical keyboard/touch UX acceptance nor genuine-account reconnect or public-server soak coverage.

## Test-policy corrections

Native failures were separated from production defects. QA-only changes address native facing, ordinary Pig spacing and combos, stepping off NPC heads, safe run-up positioning, real running before gap jumps, teammate attack cones, first-finisher combat leadership and single shared Race-bomb defusing. Early-course policies now observe accepted projectile stores, cohort rewind serials and actual held-input intervals. Serpents uses proportional ledge alignment, future support landing and each body's physical vault. Race turns inward on observed descent. These policies stay under tools/qa and are excluded from the playable build.

Cadence regression checks cover125 early-course cases,4 three-rider Jet cases,4 delayed/jitter cases,30 Serpents solo cases and12 Serpents trio cases; late policies cover80 coarse-cadence cases,16 Finale approaches and20 fixed-step regressions. These are real Modes/Session API-contract tests with held ordinary inputs, not independent native playthrough claims. Independent reviews and compilation passed.

The complete production verification has56 passing commands and192 compiled source/test/tool files, with frozen sources, unchanged protected starter and matching playable packaging. See final-validation.json and final-validation.txt. The separate native edge fixture could not reproduce sustained Climbing in three preparations; no post-fix native dismount success is claimed from it.

## Studio persistence

Exact original Edit server/client sources are restored after cloning test instrumentation. The production GameWorld fix and derived build receipt are retained. One MCP-only private save attempt was rejected with “Game:SavePlace can only be called from a server script”; explicit cloud save is unconfirmed. No public release was performed. The separate evidence is in reports/2026-11-10-private-save-mcp-095357/private-save-mcp.json.

All13-level completion remains pending until one recorded ordinary run ends Won. BT-26 and BT-33 remain In Progress.
