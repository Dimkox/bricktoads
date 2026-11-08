# Ordinary enemy grab, carry and throw

**Goal:** Give heroes a source-supported close-range Pig grab and manual throw using the existing F/touch primary action. Keep the same NPC/human enemy body, health and owner throughout.

**Authority/spec:** Continue accepted first-level combat BT-16/22/25/62/64. Primary inspection: research/2026-11-08-grab-throw-source.md. Source Pig grabbing is close, facing, grounded and unlinked, not a low-health/stun-only action. The confirmed throw damages the linked enemy at release, then unlinks; it does not establish projectile damage to bystanders.

**Source boundary:** Pig type0x0B, pickup animation0x0A/E4, same-slot mutual links, B while holding→throw animation0x0C/E5. Throw profile17/rawDamage4 is provenance. Existing ordinary enemy health remains the disclosed3HP prototype; apply its current punchDamage1 for the throw. Do not claim original Pig rawLife/AI or exact damage parity. No additional enemy-player abilities are introduced.

**Roblox calibration:** range3.3studs, height2.5, facingdot0.5, grabwindup0.12s/window0.2s, throwreaction0.85s, launch26studs/s horizontal/16vertical. Grabbing is an accepted own attack and removes respawn protection before its effect. These are adaptation values, not NES frame conversions.

## Interfaces and ownership

- New EnemyCarry.new(director) owns pending grabs and existing-body Carried/Thrown states. Exports interaction(slot), interact(slot,now,action), step(now), stateFor(enemyId), blocksEnemy(enemyId), forgetEnemy(enemyId), close(). It uses director:applyThrowDamage(enemyId,heroSlot) once at successful release; this callback applies calibrated health damage and existing _kill.
- Pending grabs preserve enemy reference/actorId/reactionEpoch, hero actor/attempt/level/combat reference/reactionEpoch and accepted order. A miss/expired window/interruption creates no link. Accepted targeting closes that Pig's takeover even if it misses.
- Already-held hands have priority over new balls/flies/grabs. A hero cannot carry an enemy and guardian ball together. While carrying F throws; Dash returns HANDS_FULL. Grounded/facing checks select the target on the server; packets never include enemy IDs or health.
- GameWorld.canGrabEnemy(hero,enemy,range,height,dot), carryEnemy(enemy,hero), releaseEnemy(enemy,thrower?,tuning?) preserve actual models and restore per-Part collision/physics. Repeated carry follows the existing holder; drop never uses a replacement hero. A throw snapshots launch direction immediately, then gravity continues independently.
- Director excludes carried/thrown enemies from autonomous and human commands while retaining hazard/death checks and live counts. Same actor, owner, HP and one-life history persist. Grab cancels current windup/movement; new damage/kill releases links. Held owner/holder disconnect does not transfer control. Holder hit/death/new appearance drops; an accepted flight continues after thrower death/offline.
- No extra damage is invented for a thrown body touching another actor. Ordinary physics, walls and dangerous edges still apply. Closed runs/new games clear links, physics guards and presentation.

## Tasks

- [x] Domain24 real-Session contracts, source-grounded eligibility and same-body/resource guarantees.
- [x] World14 contracts and original carrying presentation; engine collision fix preserves/restores Humanoid.EvaluateStateMachine.
- [x] Production composition, route9 integration and contextual HUD/CI runner; legacy fixtures preserved.
- [x] Independent review and native/compiler/build checks; final two-client Studio prepared checks recorded in reports/2026-11-08-enemy-grab-throw/.

Delivery follows the verified snapshot: push/check exact-head CI, update Draft PR/Jira with the resulting commit. The user-modified starter stays outside the commit and main remains unmerged.
