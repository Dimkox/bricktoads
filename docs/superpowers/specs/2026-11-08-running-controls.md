# Walking, running and running strikes

The user requests visible walking/running, double-press movement to run, a longer running jump and mega strikes while a hero or enemy runs. Mobile is touchscreen/multitouch only; use standard Roblox input. The user explicitly cancelled automatic safe trajectory selection: directions and jump timing belong to the player. Terrain complexity is deferred; this change adds no terrain or jump assistance.

## Controls

Use the current Roblox Input Action System: client-local InputContext (priority2000, Sink), Bool InputActions and Automatic InputBindings for keyboard and GuiButton.UIButton. Classes are available in Studio0.746. Do not use a custom touch protocol, synthetic production input, Scriptable bindings or a virtual stick. Four on-screen direction buttons support independent simultaneous presses; Jump and primary Attack remain separate buttons. Native actions provide the press/release lifecycle and multitouch aggregation.

Hold a direction to walk. Press, release, then press the same direction within0.25s and hold to run. Repeated held updates do not count as presses. Direction actions are camera-relative; diagonals normalize. Releasing the running direction, context/view/body change, focus loss and interruption clear the latch. Send Move immediately on edges and every0.1s while playable. Move gains only optional boolean `run`; no client speed/damage/profile fields. Normal client sequencing remains authoritative for ordering.

## Server movement

Main-game Movement calibration: hero walk16/run24studs/s, ordinary ground enemy walk9/run16; qualifying run velocity is at least75% of that actor's run speed in its requested direction. Run is a bounded request; the server owns speed and checks actual movement/support before treating it as running. Wall-pushing, a flag while stationary, knockback alone, stale/offline/held/reacting/dead actors do not qualify. Legacy stand without Movement config stays unchanged.

GameWorld interfaces: `move(id,x,z,runRequested?)`; `isRunning(id)` (actual grounded qualified run); `movementMode(id)` (Idle/Walk/Run/Air); `resetLocomotion(id,actorReference?)` (saved old body only when supplied). Model locomotion attributes and gait derive from server movement intent plus actual motion. Walking and running have visibly different stride/cadence; reaction, carry, Dragon and attack poses retain priority.

JumpPower remains50 in the main level. Run jumps get their increased range from real horizontal takeoff speed. Freeze the walk/run air-control speed cap at accepted takeoff until actual landing, prevent midair promotion to run, retain player steering/release, and preserve single-jump consumption/grace and physical impulses. Stop, timeout, reaction, death, ownership/connection/body changes and carry/Dragon links clear ground run; no stale run resumes after release. Dragon flight and Boss movement are separate.

## Running strikes

While physically running, primary Attack chooses the existing hero Dash/Boot selector at acceptance; R is an explicit shortcut requiring that same run qualification in the main game. Standing R returns NOT_RUNNING with a readable hint. Existing mandatory held-object/Dragon actions remain usable. Running primary precedes opportunistic grab/heal/club pickup or club swing; carried Pig/guardian ball/linked Dragon prevent ground run.

Ground enemies use trusted `EnemyRunStrike`, fixed base4/hero22 and raw16, never the hero Dash low-Life finisher. Copy PigRush timing/geometry as explicit prototype calibration. Existing NPC Pig rush keeps its source family. Human-controlled ordinary ground enemies can run and attack through the same bounded Move/primary commands. A calibrated NPC Walker run approach starts beyond12studs and stays latched until attack/interruption; it uses the same actual-running eligibility. Flying/disabled Dragon and Boss never inherit ground run.

Freeze selected action/tuning at acceptance. Release/turn during windup does not rewrite an accepted strike. All current damage, shields, same-body ownership, one-life and group isolation rules remain.

Official references: https://create.roblox.com/docs/input/input-action-system, https://create.roblox.com/docs/reference/engine/classes/InputBinding, https://create.roblox.com/docs/reference/engine/classes/InputAction.
