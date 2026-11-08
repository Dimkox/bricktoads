# Pig grab, carry and throw — 2026-11-08

Heroes can stand close to a facing Pig, press F/СХВАТИТЬ, carry its existing body while walking/jumping, then press F/БРОСИТЬ ВРАГА. Holding occupies the primary action and blocks the heavy strike. This works on the ordinary human-owned body as well as NPC state; it never spawns a replacement, heals the target or changes its owner. Hit/death/new appearance of the carrier drops the old body; an accepted throw continues independently of the thrower's later death.

## Source and adaptation

[Pinned primary-source trace](../../research/2026-11-08-grab-throw-source.md): Pig type0x0B can enter close-grounded pickup0x0A/E4 without a mandatory low-health/stun threshold. Capture rechecks and links the same slots. B with a linked enemy selects throw0x0C/E5; A still jumps with the load. Throw profile17/raw damage4 applies to the linked enemy at release, before flight. This slice does not invent a second projectile hit against bystanders.

The existing ordinary three-heart enemy profile is still provisional. Throw uses its calibrated punchDamage1; profile17/raw4 is provenance, not a claim that original Pig raw15/31 or original damage arithmetic is implemented. Roblox reach3.3studs, height2.5, facing dot0.5, windup0.12s/window0.2s, reaction0.85s and launch26/16studs/s are explicit calibration. Full species/weapon/grab combinations and timing remain outside this transfer.

## Authority and physics

The existing Attack packet accepts no target, damage or position. Session checks current actor/attempt/connection/run/level/sequence/reaction/cooldown before contextual entry. BeginAttack removes protection before grab/throw. Accepted targeting closes that Pig's takeover even on a miss. Capture rechecks distance/facing/support and historical hero/enemy reactions; competing grabs link once. Only Pig qualifies; Walker/Dragon/Boss/hero grabs are excluded.

Held/thrown enemies remain living members of the encounter and keep their one-life/owner mapping. NPC AI and human commands are suppressed during that state; hazards/death are still checked. A held owner's disconnect does not hand its body to NPC. Hands cannot carry a guardian ball and Pig simultaneously. Flight does no extra scripted collateral damage, while normal geometry, gravity and kill-plane consequences remain active.

Review fixed expired reaction restoration before capture and a physically dead target between frames before throw. Studio then exposed an R6 Humanoid re-enabling torso collision during carry. The final World saves/disables EvaluateStateMachine while held and restores its original value on release, along with original part collision settings and server ownership. This prevents the Humanoid from changing held collisions; the resumed Humanoid can perform its normal post-release transitions. See [Roblox's Humanoid reference](https://create.roblox.com/docs/reference/engine/classes/Humanoid#EvaluateStateMachine). All these fixes have regression coverage.

## Actual Studio MCP checks

[engine-checkpoints.json](engine-checkpoints.json) contains state/events and the exact diagnostic hook. Studio0.746.0.7461269, private place117412694427208, final runea2049e2-715d-4aa0-a949-5435e6c3032a. Two real clients selected Hero and Enemy through the UI; the enemy claimed existing Pig-1. Its Model, root and actorId were compared against original references throughout.

This is prepared acceptance, not an unprepared complete combat walkthrough. A test-only fixed BindableFunction repositions existing bodies, anchors other enemies far away, moves a target during one pending grab, applies the existing Session Punch hit to the carrier and invokes one existing lifecycle death. No health/respawn values are directly set. The hook is absent from repository production scripts and the playable artifact.

| Check | Observed result |
|---|---|
| Delayed miss | Valid F accepted, prepared target moved away before capture; no link/damage, HP3 and original body remained |
| Capture | Same Model/root/actorId/owner-2; HP3, hero attempt1/raw47/respawns3; anchored carried body had zero collidable parts |
| Walk and jump | Real D/Space input moved hero to x−59.696/y7.855; same body followed at y11.255 with HP3 and no new actor |
| Held enemy D/F | Actual owner packets returned HELD; no damage or independent movement/attack |
| Carrier hit | Existing Punch hit produced43 raw then normal recovery; old Pig dropped with HP3 and no resource change, EvaluateStateMachine restored |
| Phone throw | iPhone17Pro landscape, viewport750×381; actual БРОСИТЬ ВРАГА button162×56, Activated count1. HP3→2 once at release; body unanchored, X velocity26, EvaluateStateMachine restored |
| Thrown owner F | Actual owner received THROWN during the finite reaction |
| Thrower death | Prepared lifecycle death produced hero attempt2/respawns2; same Pig remained Thrown/HP2 and did not follow the new hero |
| Recovery | Same Pig returned to normal physics/speed9; actual owner's D moved it4.800studs with HP2 |
| New appearance grab | Returned hero explicitly grabbed that same HP2 body; old link was not inherited automatically |
| Edge throw | Hero prepared at z23.5 on the real platform; F launched the still-living Pig at HP1 beyond z26. It fell below FallY−35 and died through the existing hazard path |
| One-life limit | Human role became Dead; requesting another existing Pig returned ENEMY_LIFE_SPENT. Hero stayed attempt2/respawns2/raw47 |

The phone's Dash control was hidden while carrying and Jump remained available. The screenshot showed clear controls and the carried original body. Explicit MCP simulator coordinates were verified by the actual Activated event/server transition. The simulator was restored to default. This does not establish physical phone/tablet acceptance.

The initial F+A attempt captured before movement and is retained as a pre-fix checkpoint, not counted as a miss. The successful final miss instead used the documented target movement during windup. The pre-fix collision experiment is also retained separately. Final source comparison verified22 production scripts after removing the diagnostic hook; both test sessions ended.

## Verification and remaining scope

[native-validation.txt](native-validation.txt): all20 initial commands passed, plus6 affected checks after the collision fix. Core46; Combat318 assertions/Session40; Registry18; Director30/Controller37/camera1; queue20; Hub11; guardian13+3; route9; flies15; EnemyCarry24; gateway14; world14; Python17. All57 source/test files and2 tools compiled. The final affected World/compiler/builder checks passed again; the superseded artifact hash is marked in the log.

Final playable:315900bytes, SHA256de6f4ab68bfab75450843bf15d48f5c9d633f3337b0e74213160442205d08830. The deterministic builder matches the sources. User-modified places/BrickToads.rbxlx remains at SHA2561974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 outside this commit.

Full source health/AI/reactions, other grabbed species/hero/club interactions, complete unprepared level acceptance, physical devices, multiple levels and actual same-account reconnect remain open. Offline carry/replacement and competing-grab guarantees are native contracts, not claimed real reconnect or a simultaneous multi-hero engine test.
