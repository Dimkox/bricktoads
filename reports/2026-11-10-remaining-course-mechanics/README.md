# Remaining course mechanics: Ice, Ascent, Tubes, Race and Clinger

10 November 2026. Four confirmed gameplay defects are fixed. Focused native Studio crossings cover stages 4/8/9/10/11; they do not establish a natural whole-campaign playthrough.

## Corrected behavior

- **Ice co-op carry:** an earlier rider used to miss a block push performed by a later hero. Accepted X displacement now reaches every supported living rider once, with a matching native pose. The former per-rider carry/history reset is removed. Tests cover both two-hero orders, a three-hero cohort, exact accepted displacement at authored push limits and pose coherence.
- **Ice solid depth faces:** Z steering used to pass through the rendered IceBlock because only X faces were resolved. Both expanded Z boundaries now stop the body and depth velocity. Blocks retain authored X-only pushing and min/max limits; course geometry and navigation are unchanged.
- **Rat Race pending-death retry:** a bomb contact while every hero was already dying/pending could leave an empty failed-attempt baseline. The later legitimate paid spawn could never reset the round. Race now records each fixed-cohort attempt before selectively killing living bodies. Only an actually committed newer living attempt authorizes retry. Offline waiting and exhausted cohorts remain unable to manufacture spawns/resources.
- **Clinger endpoint:** the pursuer graphic stopped at the finite route end while its abstract progress grew indefinitely. A hero could pass through that visible orb after a shielded overtake. Chase progress is now capped at the authored route length, preserving the initial negative gap, input timeout, shields and chaseFinished guard. The endpoint catches an unprotected rider before course completion.

[Plan](../../docs/superpowers/plans/2026-11-10-remaining-course-mechanics.md). RED evidence: [Ice](ice-red.txt), [Race](race-red.txt), [corrected Clinger contract](clinger-corrected-red.json). The Clinger regression rereads lifecycle rows after stepping and expects normal actorId removal on death, rather than retaining a stale hero table or requiring a dead actor to remain controlled.

## Exact build and native acceptance

[Helper manifest](native-helper-manifest.json): source `62b8cf3b98b77ce9bc5dd15efea154021cf5a8e35ff3472efab75208a5f9dac2`, 50 production scripts, playable 1,022,141 bytes/SHA256 `aab353f4b373b63789040472f7b3371f782ba8163e5ef5eb5e783725305681c9`. The two changed modules matched the freshly loaded local helper. Studio 0.746.0.7461269, owned PID23196/Studio64f812f1-4b69-4df4-bc76-42d73ad2b33d.

[Final native receipt](native-third.json), [compact summary](native-summary.json), [exact helper fingerprint](native-tool-manifest.json), [fixture](../../tools/studio_remaining_course_acceptance.luau): **115 named checks PASS**, six verified cleanups, 4714 fixed simulation ticks across isolated worlds.

| Prepared native case | Observed outcome |
| --- | --- |
| Ice pusher/rider order 1,2 | Block and rider both move 0.419193 stud; same native rider/support/resources. |
| Ice order 2,1 | Identical block/rider displacement; both Z faces remain solid in both worlds. |
| Ascent lift and fan | Grounded rider carried through lift up/down/endpoints; peak root Y37.5. Fan raises root 10.166667 stud; spring power 68 retained. |
| Tubes current/swim/air | Current moves the body without changing input; validated swim input raises it; dry exit restores oxygen. Sustained submersion consumes the natural 18 seconds/1080 ticks and produces CampaignDrowned/AwaitingRespawn, attempt 1/stock 3/raw 0, no premature replacement. |
| Race same-frame death/contact | Native physical fall reaches AwaitingRespawn before actual rat/bomb contact. Attempt 1/stock 3 at loss; real Session commit becomes attempt 2/stock 2/raw 47 and resets the race. Same native rival body remains. |
| Clinger shield/overtake/endpoint | One legitimate retry/Normal shield permits overtake. Pursuer stops at route 546; unprotected hero is caught at 543.2, before finish, attempt 2/stock 2/raw 0 awaiting the next authorized spawn. Actual Buzzball body and raw Life 207 remain unchanged. |

The fixture uses actual Session intents, CampaignDirector, GameWorld, CampaignWorld and native Models. Stages, course phases, initial stances and rat contact are explicitly prepared; physical-fall preparation induces real Session death. The roster is synthetic, ordinary AI is deliberately unstepped and course bodies use their existing anchored pose adapter. No health, stock, attempt, actor ID or oxygen budget is written by the fixture. These are native server crossings, not real-Player network/keyboard/touch tests or complete route clears. The Race native case verifies reset/body/resources; successful retry defuse is separately covered by real-Session unit contracts.

## Retained diagnostic runs

[First native attempt](native-first.json) remains FAIL: 18 Ice push ticks produced less than the fixture's 0.1 stud assertion threshold. The final driver holds ordinary movement for 80 ticks; no game speed/force was changed.

[Second attempt](native-second.json) remains FAIL after both carry orders passed. Its second world was beyond Z65536, where native Vector3 quantization exceeded a 1 mm pose assertion. [Direct engine diagnostic](native-offset-precision.json) measured local 0.8 as 0.796875 there (error 0.003125), versus error 0.0001953125 at offset 4608. Moving only the isolated QA worlds to Z4096+512n resolved that test issue. Both failed receipts are excluded from final totals and not relabelled.

## Verification and synchronization

[Final frozen validation](final-validation.json), [text output](final-validation.txt): **56/56 commands and 170 Luau compilations PASS**, source/build receipts match and verification inputs remain unchanged. This includes 51 mode contracts plus the new real-Session Clinger boundary, 19 race contracts, three-hero Ice limits/carry, and all 30 existing normal-input course pilots across three seeds. Pilot worlds are API doubles, not native route acceptance. Lua5.4 remains unavailable and excluded.

[Original pre-sync](original-studio-pre-sync.json) verifies both target modules still matched ee97c93 before updating them. [Sync proof](original-studio-sync.json) matches CampaignModes, CampaignRace and derived BuildInfo to the tested helper in the existing private experience 10775039796/place 117412694427208. The private version was saved through Studio UI and left in Edit; no public release or access changes.

[Cleanup](cleanup.json): all six prepared worlds, actor registries and native bodies removed; local Play stopped; owned helper closed without saving incidental editor/migrated-lighting changes. Protected starter SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` and parallel concept-art/model work are preserved. Complete human campaign/role/device acceptance, source-perfect remaining detail, final art/audio and actual same-player rejoin remain separate; no second genuine account is currently available.
