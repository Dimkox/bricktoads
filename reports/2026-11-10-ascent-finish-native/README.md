# Prepared native Ascent finish handoff

This isolated Studio server fixture compares the original live CampaignModes with the proposed grounded Ascent finish guard. It uses cloned modules, its own authored world at offset `(0,32,24576)`, one synthetic R6 hero, and ordinary Session Move/Jump inputs. NPC controllers are not constructed. No hero pose, health, reserve, campaign stage or completion value is assigned by the fixture.

The real safe-spawn search chose X=-6.8. An explicit prefix of ordinary Move inputs centers the hero at X0, then the unchanged `da2babf` QA pilot climbs the course. Modes advances at fixed60Hz faster than wall clock; the first30 Heartbeats after native release use real physics. This is a prepared server proof, not a client/network or full-playthrough result.

| Observation | Original live module | Owned module with grounded finish guard |
| --- | --- | --- |
| Native root Y at release | 96.7083 | 99 |
| Required final standing Y | 99 | 99 |
| Logical grounded/support | false / none | true / floor-17 |
| Initial physical overlaps | Torso and limbs intersect Support17/Arena | none |
| Minimum Y over30 Heartbeats | 95.3790 | 98.9966 |
| Actor/resources | Same appearance; Life47, stock3, attempt1 | Same appearance; Life47, stock3, attempt1 |

The baseline demonstrates unsupported release and solid-geometry intersection. It does not establish a full fall or death: observation ends after30 Heartbeats. The fixed case remains at its intended standing height during that interval. The fixed clone changes only CampaignModes; its main BuildInfo still identifies the original module tree, so the separate fixed-module hash in `manifest.json` identifies the after-case.

The two failed preparation diagnostics are retained. The first failed before world construction because ordinary Script threads cannot read protected Source; MCP then prepared module clones. The second used the uncentered actual safe spawn and could not climb with the old pilot, spending no reserves. Neither is counted as a pass.

Both successful cases, their raw MCP return receipts, source hashes and cleanup verification are retained here. All three owned receipt/script folders, module clones and worlds were removed after export. MCP confirmed the original main CampaignModes source stayed unchanged and Play remained running. No public release or main-player operation occurred.
