# First-level route and guardian gameplay

**Goal:** Replace the short flat demonstration with a substantial original 3D first-level route: six sequential districts, real gaps/raised ledges, thirteen source-classified ordinary actors, a pickup/throw guardian battle and an earned exit.

**Sources:** BT-24/25/43 and accepted BT-10. Primary upstream `feos-tas/DisAssemble`: `Battletoads/data/levels_cfgs1.asm` has13 ordinary actor records in order (9 pigs,2 walkers,2 dragons), not40 enemies. The remaining records include players, ropes, helpers, flies/items/warp and composite boss parts/debris. This static inventory is not a verified natural-play population. Full species AI/weapon/grab parity remains unverified; existing ordinary combat tuning remains a disclosed 3D calibration.

**Guardian correction:** Primary ASM `object_level1_boss_turrets` creates ordinary shots and a final special shot. Ordinary shots expire; the special shot becomes a ground ball. B picks up an eligible ground object, B while carrying throws. Boss raw47 loses16 per successful thrown ball:47→31→15→underflow. Flying bullets are not punched back. Timing/distances below are Roblox tuning; no original frame count is invented.

## Architecture and interfaces

- New private `LevelDefinition.lua` supplies six original districts, support boxes, true gaps, per-district exit volumes, gate coordinates, unique enemy IDs/kinds, guardian location and final exit.
- Main server passes this definition to `GameConfig(base,definition)`; old engine-independent encounter fixtures without a definition retain their small legacy profile. Production always supplies the definition.
- World route rendering uses `config.Level`, replacing the continuous demonstration floor. `world:progress(zoneIndex,complete)` gates reachable geometry/respawn supports; `world:reached(heroId,volume)` checks physical local coordinates; `world:groundPosition(localPosition)` returns supported local ball position or nil. Existing group offsets remain applied exactly once.
- World `projectile(id,localPosition,reflected,mode?)` supports Bullet/Heavy/Ground/Carried/Thrown appearance; existing bool-only callers remain valid. Spawn kinds Pig/Walker/Dragon receive distinct original silhouettes while retaining current temporary ordinary combat calibration.
- Director enters route zones in sequence and spawns only that zone's unique actors with their real local Y. Progress needs both all current enemies defeated and a living, non-dying hero reaching the exit volume. Empty traversal districts still require reaching their far side. No respawn past a locked zone.
- Director's modern guardian pattern is injected via deps.GuardianPattern. `GuardianPattern.new(director)`; `step(now,dt)`, `fire(aim,target?) -> code`, `hit(attacker,target,action)->boolean`, `interaction(slot)->{available,label,carrying}`, `interact(slot,now)->code` with `NO_INTERACTION` fallback. Pattern owns the actual director.projectiles table; director supplies session/world/config/now/enemies/bossHits/_kill/_nearest.
- World legacy two-wave/boss behavior remains only for old no-definition fixtures. Modern guardian uses rawLife47/three thrown impacts. Direct punch never reflects a flying shot. A periodic finite attack cycle produces a special pickup opportunity even for an offline/idle human owner; accepted shots, phase deadlines and vulnerability continue without transferring control to NPC.
- Session adds an optional `contextualAttack(uid,now,action)` callback AFTER existing sender/actor/attempt/epoch/sequence/rate/reaction/cooldown validation and BEFORE ordinary attack acceptance. It returns `NO_INTERACTION` to attack normally, otherwise a code. Pickup keeps existing resources/shield. Throw accepts BeginAttack before its effect and releases emergency hold; no client-selected target/HP/position.
- Main Controller installs that callback and exposes private snapshot.interaction for the current hero. Client reuses F/touch primary action: УДАР / ВЗЯТЬ ШАР / БРОСИТЬ ШАР. New objective shows zone n/6 and actual guardian instruction; touch layout stays within existing action card.

## Work

- [x] Original route geometry, legible district landmarks, actual gap collisions, reachable jumps/ledges, zone-aware safe respawns and narrow-floor robustness.
- [x] Route progression and new production definition integration; source-backed actor inventory and uniqueness tests.
- [x] Source-correct guardian ground-ball pickup/throw, finite phases, authority/shield/offline/death/impact tests.
- [x] Objective/interaction HUD and feedback, including no reflection instructions in modern route.
- [x] Compile/build/native suites, independent review, and actual movement/jumps/battle/route completion in Studio. Preserve modified places/BrickToads.rbxlx and existing group isolation. The full traversal/guardian pass used cleared ordinary NPCs; see the report for its precise acceptance boundary.

## Acceptance boundary

Deliver a playable longer original level and source-correct guardian chain. Do not mark full NES parity or all BT-25 criteria complete: ordinary species AI/health, sticks, grabs/throws, flies/items, natural-run population and physical-device acceptance still need their own verified transfers. Keep those material limits in the final report without replacing requested gameplay work with more orchestration.
