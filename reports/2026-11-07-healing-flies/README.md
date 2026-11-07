# Healing flies — 2026-11-07

Six food objects now appear on the first route: two in the stone courtyard, then four on the long bridge. Face a nearby fly and press F/the contextual ЛОВИТЬ МУХУ button. A short pending tongue must actually reach the same fly before it is consumed. A successful catch adds8 raw Life, capped47; it does not restore respawns or create a body. Eating at full health still consumes the fly.

[Primary-source note](../../research/2026-11-07-healing-flies-source.md) pins the six-record two/four inventory, B/tongue capture chain and exact healing arithmetic to public disassembly commitf1a43b6. This is a static inventory, not a measured natural-play population. The original geometry/art, hover path,6-stud radius,3-stud height, facing dot0.25,0.16-second windup and0.22-second catch effect are Roblox calibration. The five-heart display remains5*raw/47; +8 is approximately0.85 displayed heart.

## Authority

The existing primary Attack packet carries no item ID, position or heal amount. Current Player, group/run/level, actor/attempt/connection, sequence, reaction and cooldown checks run before the contextual action. BeginAttack clears respawn protection/hold before the tongue effect. A pending catch is tied to the same combat/body/attempt/level and historical reaction epoch. A hit/death/replacement appearance cannot later complete it, even after a long frame has cleared reactionEnd. An accepted tongue may finish on its same offline body.

Item records belong to one run/group and stay consumed through respawn/menu/rejoin. Competing tongues resolve in accepted order and consume a fly once. A failed authoritative health event changes neither food nor raw Life. The other group has separate models/state at its own translated coordinates. Food is outside combat actors, enemy offers and hit targets. New run/closed run cleanup removes only that world's visuals.

Review also fixed a pre-existing integration edge: contextual food/ball success no longer marks an unrelated NPC as engaged. Only an actually accepted ordinary combat attack closes its directed takeover target.

## Actual Studio MCP verification

Studio0.746.0.7461269, private place117412694427208, three actual clients and two independent groups. [engine-checkpoints.json](engine-checkpoints.json) contains state, events and the exact fixed diagnostic preparation hook. Group1 run82b3528c-ac0a-4b76-a72a-285856d91129 had two heroes; group2 runcdb864e3-9428-4822-bc2c-3d5c58a092ae had one.

This was a prepared scene, not a natural full-level clear: a test-only BindableFunction cleared ordinary NPCs, selected zones3/6, repositioned existing bodies and invoked the existing Session Dash hit for injury. No health/reserve values were directly edited. These diagnostic actions were removed before the final exact-source verification and are excluded from the build.

| Check | Actual result |
|---|---|
| Injured hero, keyboard F | raw31→39, same actor/attempt1 and all3 respawns; first courtyard fly consumed once |
| Phone full-health catch | Second hero pressed the actual contextual button; Activated count1, raw47→47, same actor/resources, second shared fly consumed |
| Group isolation | Group1 consumed2 while group2 retained its own2 courtyard flies, at offsetZ512 |
| Actual missed catch | Group2 hero pressed F then moved/turned away with A; accepted tongue healed nothing, raw31 and both food objects remained |
| Same fly after miss | Corrected facing and keyboard F gave group2 raw31→39; group1's consumed food stayed consumed |
| Late food activation | Zone6 created four actual HealingFly models; consumed courtyard food did not reappear |
| Return to full health | A later keyboard catch recorded raw39→47. Another full-health catch remained47 |
| Simultaneous client intents | Two actual clients scheduled valid production packets at one deadline. Both InteractionAccepted events were0.0168s apart. Only one FlyCaught occurred for bridge-fly-3; raw31/31→39/31; both retained actor/attempt1 and3 respawns |

The earlier sequential two-key attempt was not simultaneous: the second input became an ordinary Punch after the fly was already gone, and friendly damage/recovery followed. Its checkpoints are retained separately, not presented as the accepted race. Likewise, a preliminary diagnostic source hook did not expose shared state across the tool boundary; that preflight session supplies no acceptance claims. The successful final session used the fixed diagnostic actions described above.

Phone: iPhone17Pro LandscapeLeft emulator, viewport750×381. The actual primary button measured77×56 and wrapped ЛОВИТЬ МУХУ legibly; the screenshot showed it clear of the movement stick and HUD. MCP used explicit emulator coordinates; an actual button event and server catch prove activation. The device was restored to default. This does not establish physical phone/tablet acceptance.

## Verification and remaining work

[native-validation.txt](native-validation.txt) records all19 fresh commands, all exit0: lifecycle46; Combat318 assertions/Session40; connections18; Director30/Controller37/camera1; boss queue20; MatchHub11; guardian13+3; route8; healing flies15; gateway14; world11; Python17. Compilation covered54 source/test files and2 tool launchers. Regression failures were observed before the route wiring, unrelated-NPC engagement and historical interruption fixes; review afterward found no further actionable P1/P2.

Playable build:295858bytes, SHA2561839d72817755ec0273081005c22cd2997a91230c59668aac28238f66621af7a. Final Studio Edit comparison verified all21 production sources after removing the diagnostic entry hook; the generated place matches the repository. The prior user-modified places/BrickToads.rbxlx remains unchanged at SHA2561974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and is outside this commit.

An unprepared complete combat playthrough, full Pig/Walker/Dragon mechanics, sticks/grabs, exact NES fly AI/timing, physical devices, multiple levels and real same-account reconnect remain unconfirmed or unimplemented. This slice supplies food capture/healing, not full BT-17/25/43 acceptance.
