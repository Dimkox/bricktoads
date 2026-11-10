# Campaign enemy mechanics and source profiles

Primary source: [feos-tas/DisAssemble at f1a43b69577246850d136473700a333b3cdfe93f](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads), cached in `build/canonical-source`. This is static source inspection and executable native-Luau verification, not a measured NES natural-play population ledger or an emulator timing trace. Course positions, event triggers, populations, seconds, studs, physical impulses and visual presentation are authored Roblox content. No original executable or artwork is added to production assets.

`CampaignRoster.apply(def,index)` attaches provenance and source loader Life to authored actors and encounters. It converts Rope Ravens, Toadtraps and RetroBlasters from static damage boxes/emitters into real ordinary combat actors, adds a marked authored Large Raven encounter, and removes the duplicated mode damage sources. Electric traps remain course hazards. Tower configuration explicitly exercises Hordhead47/63 and Swellcheeks47/79/111 on authored placements. These placements do not claim original exact counts or coordinates.

## Loader Life and special handlers

The11-byte record loader reads final byte10, applies OR0F, and stores `Objects_Life` at main.asm28889–28895. Source profiles are centralized in `CampaignRoster.lua`; selected record lines are below.

| Family | Loader Life | Evidence |
| --- | --- | --- |
| Raven / LargeRaven |79 /79|levels_cfgs1.asm49,59|
| SaturnToadtrap |15,31,47,63|cfg1:53,92,106,108|
| RetroBlaster |31,47,79|cfg1:67,65,105|
| SentryDrone / Slug / GasTurret |15|cfg2:158,176,185|
| Robot / Electrofish / Duck |15|cfg2:230,253,278|
| Hammerfish |15,31|cfg2:257,282|
| Shark |15,47,63|cfg2:263,283,275|
| Hordhead |47,63|cfg1:336,361|
| Swellcheeks |47,79,111|cfg1:365,374,380|
| Snowman |15,31|cfg1:263,271|
| FlyingHead / RocketRat |15 /15|cfg1:425,196|
| Invader |FF sentinel, linked-health handler|cfg1:126–128; main5472–5723|

Ordinary arithmetic now accepts the full byte range0..255. Hero hit/recovery/display still require0..47 and retain five hearts. Ordinary recovery has its own byte guard, and its three displayed hearts scale to the actor's initial maximum. High capacities are not truncated to47 or flattened to31. Exact zero, underflow death and high-nibble OR0F rounding remain distinct. Claiming an NPC preserves its current raw Life and recovery state.

A loader value alone does not establish linear ordinary hit points for special handlers. Raven transitions to type14 DeadRaven when its reaction timer becomes nonzero (main4990–4998), so the adapter spends its ordinary one life on the first accepted hit and displays finite falling debris; it does not require a79-Life grind. LargeRaven's reaction path creates type2F (main4981–4983,4845–4859). The separate claw handler settles, checks contact, sets the hero's `have_stick` bit20, and removes the pickup (main10536–10575). Runtime supplies one finite claw per authored LargeRaven body, automatic contact pickup after a short settling delay, body/attempt/level-bound equipment and heavy-reaction drop. That one-pickup allocation cap and the seven-second pickup lifetime are explicit adaptation budgets. A pickup is never a playable enemy slot. The world adapter may draw the held claw through `campaignClaw(slot,held)`.

Invader's FF loader sentinel is not255HP. The runtime's three-heart ordinary body uses a display capacity15 and transforms on its first accepted hit; this display capacity is adaptation metadata, not a source linear-health claim.

## Invader linked Life

Main5472–5569 links the Invader to a hero, main5656–5659 subtracts8 directly, hit conversion at5520 changes its type to1D, and main5620 returns8 only when the sum is below30hex. `sub_0_9B72` at5712–5723 computes the linked health-bar target from Life AND38. The low-Life path at5635–5648 checks the masked Life against7 and removes the object rather than reaching SBC8 when raw Life is0..7. Exact8 can become living0; subtraction alone does not invent a death transition.

The adapter uses a told swept leap to make contact, then a trusted `Session:_stealLife` operation subtracts exactly8 without generic attack rounding or an invented PigRush impulse. A shield, post-hit protection, missing/dead body, or Life below8 prevents theft. Each ordinary actor steals once and owns a finite linked visual token. A valid incoming hit transforms/spends the ordinary actor and releases a returning token; the token can finish after that thief body dies. If the carried token expires first, the Invader escapes and spends that existing life without refunding health.

`Session:_recoverStolenLife` consumes the registered token exactly once. It validates run, level epoch, exact hero actor, attempt, combat state and survival. A return at Life+8>=48 is discarded rather than clamped or banked. An old-body/old-level token never heals a replacement body. Closure removes the component's tokens without healing. Theft and return can affect an offline living body; reconnect supplies no refill. The five-second escape budget, three-second return budget,24-stud return speed and physical contact primitive are Roblox tuning; the linked subtraction, conversion and capacity branch are source-backed.

## Rope attacks

Context selection at main7041–7098 chooses rope animation1C/46, LargeRaven52, or RetroBlaster50; animation22 is selected for low Life, and RetroBlaster4E for Life16..31. `anims_moves.asm`108–125 uses E2 parameter87/07/C7 for ordinary profile7/raw8; the13-mask foot/girya path uses8D for ordinary profile13/raw16. Actual hero victims add18 profiles through main15842–15850: profiles25/raw255 and31/raw16 respectively. Trusted runtime actions are `RopeStrike` and `RopeBoot`; public input still exposes ordinary primary only. Armed beak animation48 keeps the same7/25 damage profile and changes source collision index2 to3. Trusted RopeClaw retains that damage and adds an explicitly calibrated two-stud vertical contact allowance, so the pickup changes its contact shape without inventing a damage multiplier. `GameConfig` supplies explicit original geometry and physical-response calibration for these actions.

Rope Ravens, LargeRaven, RetroBlasters and SaturnToadtraps are selectable real actors governed by the ordinary ownership, engagement, reaction and one-life rules. Stationary wall families preserve their authored anchor for human and NPC, including reaction intervals. Course completion does not require killing every vertically passed foe.

## Rocket-rat encounter

Main10088–10124 defines a turbo-tunnel rocket-rat handler that copies its own position into a new type29 falling obstacle; the Inferno handler is separate at11501. The authored Speeder event is a later course encounter, not an entry flying patrol and not a free-flight control scheme. Its ordinary actor follows absolute `trajectory={from,to,duration,dropAt,dropGroundY}`, consumes one allowed obstacle drop and expires through ordinary one-life death. Human, NPC and disconnected ownership use the same route, speed, duration and drop allocation. Move cannot steer off the route and Jump cannot create flight. A dropped obstacle is a finite damage effect with no playable slot.

Checkpoint replay may create another authored natural appearance. An optional `spawnSerial` extends the actor identity, so reusing a reserved numeric encounter ID cannot restore a former owner's life or make an old packet control the new actor. The retired owner retains the spent body record; a new eligible player may claim the new NPC instance. Explicit course reset calls `expireEncounter(id)` to remove only that RocketRat actor's remaining drops/projectiles. Ordinary combat death, route expiry and disconnect preserve accepted effects. Event position, trajectory, duration and checkpoint replay timing are original authored tuning, not extracted camera/ROM coordinates.

## Other finite family actions

The component retains told ranged snowballs, opposite Sentry bolts, finite gas clouds, Robot shots/contextual self-destruct, temporary Slug latch, bounded swimming shock/lunge/bite families and Hordhead/Swellcheeks/FlyingHead movement. Handler identities are mapped at main5730–5858; relevant paths are Robot11883–12020, Sentry19012–19042, Slug19050 onward, GasTurret19173 onward, Swellcheeks14024–14204, Snowman20148–20288, Electrofish12123–12157, Hammerfish12243–12304, Shark12371–12413, Duck12063–12115, Hordhead11003 onward and last-level flying/head13821/13985 onward. These paths establish family identities and distinct mechanics; original 3D tells, swept collision, attack geometry and movement budgets remain calibrated adaptations, not assertions of frame-exact parity.

Accepted attacks permanently engage their ordinary instance, including misses. Incoming attacks release movable mode control before impulses. In-flight effects continue after shooter death or disconnect, use finite swept geometry and can damage ordinary actors or the separately directed boss through trusted collision callbacks. Boss effects use odd identities; ordinary projectiles, Life tokens and debris share a component serial with even identities. The component never creates hero stocks or adds a player-controlled slot for an effect.

## Verification

`tests/run_campaign_enemies.luau` has32 contracts against real LevelDirector, Session, Combat, RunLifecycle and CampaignBoss. They cover ranged and friendly-fire effects, claimed/NPC and disconnected actions, valid movement and malformed/stale packets, water and flight constraints, full byte Life/three-heart recovery, linked theft/return/capacity/body/epoch/expiry guards, wall anchoring, scripted rocket trajectories, Raven reaction death, finite LargeRaven pickup equipment and replay identity/one-life isolation. `tests/run_campaign_roster.luau` checks explicit source profiles, all authored high-Life variants, hero guards, rope damage profiles and removal of duplicated Rope hazard damage. The repository runner sweep is reported separately after integration; Studio physics and complete human multiplayer playthrough are separate evidence.
