# Boss role and queue implementation plan

> For agentic workers: implement independent queue/client tasks in parallel; coordinator owns gameplay integration. Test behavior before implementation, then review the integrated result.

**Goal:** Let an eligible observer queue for the causeway guardian, accept a timed invitation before its encounter, and control the existing guardian with the same combat profile as NPC.

**Architecture:** One server-owned BossQueue persists across runs; slots bind to run/level. LevelDirector waits at the boss gate while invitations are unresolved, then creates exactly one human- or NPC-controlled guardian. Current Player/actor/epoch/sequence authority remains in the existing gateway.

**Tech stack:** Roblox Luau, native Luau CLI, Python place builder, Studio MCP.

**Spec:** Jira BT-23 and BT-10 D-06/D-07, read 2026-11-07. Boss identity `CausewayGuardian` is this original prototype, whose existing three-reflection calibration is preserved; full NES parity and cross-server routing remain separate work.

## Constraints and decisions

- Use the existing task branch `bt-18-combat-stand`; other writer is idle. Preserve the user's modified `places/BrickToads.rbxlx`. No main-branch writes or public game publication.
- Server invitation deadline: 10 seconds, strictly before expiry. Separate accepted connection deadline: 15 seconds (technical configuration).
- FIFO per boss, one entry/offer/assignment per user, no duplicate priority changes. Decline/timeout rotates once and skips that candidate for the same slot.
- Cancel/switch invalidates old invitations. A failed ordinary claim retains waiting; successful ordinary claim cancels it. Active ordinary roles, including offline bodies, cannot queue. This run's heroes cannot become its boss.
- Boss encounter waits for pending invite/connection resolution; empty/exhausted eligible queue starts NPC once. No takeover after encounter starts.
- Human disconnect stops new commands; accepted projectiles and timers continue, health and ownership persist. Rejoin binds a fresh connection epoch to the same living body.
- Work on one local playable group; queue module supports several slot contexts and tests competition without claiming cross-server delivery.

## Queue interface

`BossQueue.new({inviteSeconds=10,connectSeconds=15}, eligible(userId,context))`;
`register(slotId,bossId,context,now)`, `select(userId,bossId,now)`, `cancel(userId,now)`,
`reply(userId,offerId,accepted,now)`, `connect(userId,offerId,now)`, `step(now)`,
`start(slotId,now) -> {state='Waiting'|'NPC'|'Human',userId?}`, `close(slotId,now)`.
`view(userId,now)` returns a private copy with state None/Queued/Invited/Accepted/Ready/Active, bossId, offerId, slotId, deadline and queue position where relevant. Accepted, Ready and Active reserve a role. All methods are synchronous and do not yield.

## Gateway/client interface

- `QueueBoss{bossId='CausewayGuardian'}`, `CancelBossQueue{kind}`, `ReplyBoss{offerId,accepted:boolean}`, `ConnectBoss{offerId}`; strict key/schema and current Player checks.
- Snapshot `bossQueue` uses the queue view; `bossQueue.available` is eligibility to join. `enemyRole` includes the controlled guardian with `template='Boss'`, same actor-context fields, and remaining boss health.
- Client presents a separate queue panel in both lobby and observer HUD, with join/cancel and invite accept/decline. After accepting, the current client acknowledges Ready with ConnectBoss. Countdown uses server time; server remains authoritative.
- Guardian controls: existing directional movement for aim, Punch to launch its existing projectile with unchanged cooldown. No hero Dash/jump/movement ability is invented. NPC auto-fires; human fires only accepted input. Reflections damage both controller types identically.

## Tasks

- [x] Queue: failing behavioral tests for FIFO, idempotency, deadline boundaries, decline rotation, cancellation/switch, connect timeout and two-slot atomic ownership; implement module and pass native runner.
- [x] Integration: failing Controller/Director tests; bind ordinary-claim/hero exclusions, queue gate and human boss attack/disconnect/rejoin/death to current run and identity.
- [x] Client: implement responsive queue/invitation panel and existing guardian role HUD/control, no overlap with personal menu or touch controls.
- [x] Verify: all existing suites, queue suite, compile, deterministic rebuild and structure tests; review changed source; exercise live queue and human guardian through Studio MCP.

## Verification and review

Queue20, Director30 and Controller35 behavioral tests pass, alongside the existing lifecycle/combat/connection/camera suites and seven builder checks. Independent review found a post-defeat projectile ordering defect; a failing test reproduced it and the repaired loop now stops impacts in the same tick. Live validation found the physical Boss identity excluded from enemyIdentity; extending identity/nameplate support fixes the camera. Native regressions cover a Ready owner leaving before boss creation, names surviving the new director, and no healing on return.

Studio verified FIFO decline-to-next, client readiness acknowledgement, human aim/fire, health3→2→1→0 from actual hero reflections, assignment release and Won at the unlocked exit. Two prepared-scene runs are documented in the report. Native actor replacement tests do not establish real same-account reconnect transport.

## Review focus

Late invite after NPC start; ordinary claim versus accepted reserve; offline invite expiry; replacement Player sending old actor commands; projectiles hitting after guardian death. All need explicit regression coverage.
