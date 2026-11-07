# Human ordinary enemies — Studio verification

7 November2026, Studio0.746.0.7461269, private place117412694427208. Sources were installed through Studio MCP; tests used two genuine Studio test clients.

## Observed engine behavior

- Client2 selected Enemy through the real menu; only client1 formed the hero roster. Claim through the visible role button transferred the existing NPC Model/root/actorId at3 hearts; no actor was added. Nameplate and camera switched to Player2. Movement used speed9; enemy HUD showed3 hearts/one life and no hero Dash.
- Actual keyboard movement/F by the human enemy changed the hero's rawLife47→31, leaving three respawns. The other NPC was temporarily anchored to isolate this damage source. The enemy's health was not changed by transfer.
- Valid hero Move/Punch inputs killed the human enemy through3→2→1→0. A request for the other NPC returned ENEMY_LIFE_SPENT, no offers and no extra body. A separate host-started new game subsequently granted a fresh enemy life with a new run/actorId.
- In a fresh final-code test, a sentry was placed7 studs in front of the hero, outside its own automatic attack range. A contextual Dash was submitted; the sentry was moved beyond reach during windup. It retained3 hearts, yet claim returned ENEMY_ENGAGED. The unrelated other sentry remained available and was claimed. These NPC anchors/placements were explicit test preparation, not gameplay commands.
- After removing anchors/restoring server ownership, the prepared scene continued through both encounters,3 reflected boss projectiles and Exit→Won in44.73s. Hero finished attempt4/reserves0/rawLife47. Inputs were contextual client commands; hero HP/resources were never set by the test.
- iPhone17Pro emulation: a real claim button worked; active enemy HUD, movement stick,162×56 attack button and hidden Dash were inspected. Physical phone/tablet acceptance remains open.

## Evidence and scope

`engine-role-lifecycle.json` contains before/claim/hit/death/spent-life/new-game states; `engine-attack-boundary.json` records the final miss-lock case; `final-continuation.json` contains the completed prepared-scene run; `phone.json` records active controls. The earlier continuation in `late-continuation-not-run.json` started after the group was already Lost during setup; it is not a completed playthrough. Two temporary MCP command syntax/name errors were corrected before the successful checks; they were not game-script failures.

Native Luau:25 Director +19 Controller contracts pass. Regressions:46 lifecycle,37 Session/318 Combat assertions,18 connection and14 gateway cases;17 structural builder tests and33 compiled source/test scripts pass. Review-found target-selection and reaction-expiry-clock mismatches have failing-then-passing regressions. The selected-role UI stroke now draws a border rather than obscuring text.

Connection-object replacement/offline behavior is verified by contracts, not actual same-account transport. Full multi-group/level routing, asynchronous reserve timeout T, boss FIFO, original NPC roster/complete mechanics transfer and real reconnect are not complete. These checks do not close the full Jira tasks.
