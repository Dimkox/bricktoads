# Human enemy roles implementation plan

**Goal:** Let a player choose Enemy before a run or claim an available live sentry during it, then control that same body with three hearts and one life.

**Authority:** Accepted BT-20/21 rules; additional enemy abilities remain deferred. Continue the existing main project, preserve the user's modified places/BrickToads.rbxlx, and deliver the rebuilt BrickToadsPlayable.rbxlx. Push and Jira synchronization are explicitly requested.

## Rules

- Prestart preference Hero/Enemy/Spectator; only eligible Hero preferences form the fixed1–3 roster. The first online Hero starts the game.
- A nonhero may atomically claim an existing ordinary enemy only before its first accepted attack or a hero attack directed at it. A miss never reopens it; unrelated attacks do not close it.
- Preserve body, actorId, health, position and combat state on transfer; stop AI control. No extra enemy spawn or healing.
- A hero from this run cannot become its enemy, including after elimination. A human enemy's actual death spends that player's one life for this run/level; no slot change or reconnect restores it.
- Disconnect stops new commands, retains owner/body, and lets accepted attacks, physics and damage continue. No NPC takeover. New current Player objects return to the same living body with a new connection epoch.
- Current-Player registry, run/level/actor/attempt/connection/sequence and schema validation apply to enemy controls. Enemy offers contain existing instances only. Boss claims and cross-server reservations/queues are outside this slice.

## Interfaces

- Existing Session exports validIntent(packet) for shared schema validation.
- LevelDirector:claim(userId, enemyId) -> code; connection(userId, connected); controlled(userId) -> role snapshot or nil; command(userId,payload,now,validator) -> code; available(userId) -> offers; closeTargetForAttack(targetIds) permanently closes only the first directed ordinary target. controlled role includes enemyId, actorId(string), attempt1, connectionEpoch, connected, status Alive/Dead, hearts/maxHearts3, template/name.
- Enemy IDs remain negative world table keys; actorId is run-specific string in the physical Model attribute. World:enemyIdentity(id,actorId,ownerName) updates identity/nameplate without recreating it.
- Controller handles SelectRole{role}, ClaimEnemy{runId,levelEpoch,enemyId}, and contextual controls. Snapshot adds preference, enemyRole, enemyOffers, enemyUnavailableReason. controlledSlot(userId) selects the camera/replication body.
- Enemy control permits Move/Jump and Punch (ordinary strike), with the same cooldown/windup/profile as NPC. Hero Dash remains unavailable to the enemy. Both controller types share the same health.
- Client uses enemyRole context for control/camera/three-heart HUD, lists available sentries and death/closed-role messages; preference controls are available before new games. Hero UI remains unchanged in behavior.

## Work and verification

- [x] Domain: test first, implement ownership/one-life/attack-boundary and enemy commands inside LevelDirector; use actual Session hit path for heroes and ordinary enemy friendly fire.
- [x] Gateway/world: test preferences, hero exclusion, claim authority and connection-object replacement contracts; integrate contextual enemy commands, owner nameplate and replication focus.
- [x] Client: role preference, claim list, camera and readable three-heart controls on desktop/phone.
- [x] Run existing and new suites; rebuild; exercise actual two-client hero/enemy play, claim boundary and death/no-new-life through Studio MCP.
- [x] Review the code and prepare verified build/evidence and per-ticket Jira updates for delivery through the feature branch.

## Result and limits

Actual two-client checks prove same-body takeover, human enemy damage,3→2→1→0 death, no second enemy life, and reset only on a separate new game. A fresh final-code scene proves an accepted Dash miss locks only the directed sentry; another sentry remains claimable. Its continuation reached Won in44.73s after three returned boss projectiles and all three hero respawns. The setup deliberately anchored/relocated NPCs for isolated assertions, then restored normal physics; it is not an unprepared full multiplayer acceptance run. Phone emulator checks pass. Native tests:25 Director +19 Controller, all existing suites green. Actual same-user reconnect and broader Jira acceptance remain open.
