# Healing flies implementation plan

**Goal:** Add source-backed tongue catches and limited health recovery to the first-level route, through the existing primary action on keyboard and touch.

**Authority/spec:** Continue implementing the accepted first-level mechanics in BT-17/25/43/64. User requested game implementation and autonomous continuation. Primary source facts are pinned in research/2026-11-07-healing-flies-source.md. No additional human-enemy combat abilities are introduced.

**Architecture:** New private HealingFlies owns six server-side collectible records and pending tongue catches. LevelDefinition places two flies in Courtyard and four in Longbridge, following the source's two-then-four order in original 3D geography. GameController/LevelDirector compose the existing contextual Punch with this module; existing GuardianPattern interaction keeps priority. GameWorld renders per-group flies/tongue feedback; the existing HUD receives the contextual label ЛОВИТЬ МУХУ.

**Source rules:** A successful tongue catch consumes one fly and adds8 raw Life, capped47, including consumption at full health. No target catch means no healing. The normalized display remains5*raw/47. Source timings/coordinates and natural-play fly population are not claimed; the source six-record inventory is distinguished from those claims.

**Roblox calibration:** Catch radius6 studs, vertical difference at most3, facing dot at least0.25. Hover bob0.25 at2 radians/second; pending effect after0.16 seconds. These values live in GameConfig. F/touch Punch selects the nearest eligible fly automatically; the client cannot choose an item, position or heal amount. Dash remains an ordinary attack. Tongue is an accepted own attack: BeginAttack clears respawn protection/hold before the effect.

## Constraints and review focus

- Only the current active living hero can begin a catch. Stale actor/connection/run/level/sequence, reaction, cooldown and sender checks remain in Session/Controller.
- A pending catch stays tied to its actor/attempt/level. A hit/death/new appearance cancels it; an already accepted action may finish offline on the same body. Resolve-time position/facing must still reach the same live fly.
- Each item can be consumed once per run. Two competing tongues cannot duplicate healing. Respawn/menu/rejoin do not replenish food. Another group owns separate food even at translated coordinates.
- Failed Core health events do not consume food or change raw Life. Healing never creates an actor, changes attempt/reserves or revives a dead hero. Closed runs clear visuals/pending actions.
- Preserve all existing local edits in places/BrickToads.rbxlx. Build only places/BrickToadsPlayable.rbxlx; keep the current branch and Draft PR.

## Tasks

### 1. Domain and real Session integration

- [x] Write and run failing tests, then pass15 actual Session/Core/Combat contracts for arithmetic, catches/misses, interruption, offline state, resources and invalid intents.
- [x] Implement HealingFlies and World interfaces.
- [x] Integrate production Director/Controller, six unique food records and configuration/snapshot counts; preserve legacy fixtures.
- [x] Pass route/guardian/gameplay suites and new route wiring regression.

### 2. Original presentation and touch instruction

- [x] Add per-world flies outside actors/hit targets and short catch feedback/cleanup.
- [x] Verify offset, removal, reset, facing/range and actor isolation in World contracts; compile.
- [x] Reuse contextual primary label and add instruction; phone77×56 catch button verified.

### 3. Engine and delivery

- [x] Verify prepared Studio checks with three clients/two groups, keyboard/touch, miss, shared food, full health and simultaneous valid client packets; record boundaries.
- [x] Run native/compiler/build checks, review fixes and final21-source Studio comparison. Evidence in reports/2026-11-07-healing-flies/.

Delivery follows this verified snapshot: commit/push, check exact-head CI and synchronize Draft PR/Jira. The three existing unpushed queue/group/route commits travel on the same feature branch; main remains unmerged.
