# Playable first level implementation plan

> **For agentic workers:** Use executing-plans for integration and independent parallel tasks for World/client. Track completed steps below.

**Goal:** Replace the blank main runtime with a playable original 3D prototype: choose a toad, start solo/duo/trio, fight NPCs, reflect the boss's projectiles, reach the exit, see a result.

**Architecture:** Reuse RunLifecycle and the existing server Combat/Session/ConnectionRegistry sources without copying their implementation. The main builder embeds these private dependencies as CombatRuntime; GameWorld provides original geometry/rigs and LevelDirector controls encounters. Server-owned intent validation and immutable run membership remain authoritative.

**Tech Stack:** Roblox Luau, native Luau CLI, Python standard-library place builder, Studio MCP.

**Spec:** Existing BT-10 accepted decisions, BT-11/12/14/16/17/18/20/21/23/24, and docs/superpowers/specs/2026-11-06-combat-stand.md. This is a playable prototype, not completion of the full NES transfer or all role/lifecycle requirements.

## Global constraints

- Work inside bricktoads; meaningful source/module names. Existing feature branch remains isolated from main.
- Preserve the user's modified places/BrickToads.rbxlx. Emit the new main place as places/BrickToadsPlayable.rbxlx.
- Fixed 1–3 hero roster, duplicate templates allowed, equal capabilities; late arrivals cannot occupy hero slots.
- Five hero hearts and three successful respawns; normal/emergency shield contracts remain unchanged.
- Ordinary enemies display three hearts and have one life; separate boss profile. Never heal or respawn an enemy on ownership transfer.
- Timing, geometry and provisional enemy arithmetic are explicit prototype calibration, not claimed NES parity.
- No Jira maintenance during implementation. Studio interaction through MCP.

## Interfaces

- GameWorld.new(BaseWorld, config) returns the BaseWorld-compatible instance, with original level geometry and actors keyed by positive hero slots and negative NPC/projectile IDs.
- World:spawnEnemy(id, kind, positionTable); position(id) -> {x,y,z}|nil; face(id,targetId); enemyMove(id,targetId,speed); enemyHealth(id,raw,max); stage(name); atExit(heroId); projectile(id,positionTable,reflected); removeProjectile(id).
- LevelDirector.new(session, world, Combat, config); step(now,dt); hit(attacker,target,action)->boolean; snapshot()->{stage,objective,enemies,bossHits,bossMax,result}; isTarget(id).
- Snapshot uses Session fields plus template/displayName/username/userId for heroes; lobby owner choices; canStart/canSelect/selectedTemplate; level director fields. Remotes live in ReplicatedStorage.BrickToadsGame (Intent/State).
- Client sends {kind='SelectHero',template=...}, {kind='Start'}, {kind='Sync'}, or Session's contextual Move/Jump/Attack packets. No client health, target or position authority.

## Review focus

Unknown template/spoofed owner; active-run reselection; late join; enemy transfer after first accepted attack; repeated victory/result restart; offline damage; GUI overlap on phone; unbound NPC damage bypassing shields.

## Tasks

- [x] World: original causeway, three toad appearances, enemy/boss silhouettes, safe collision geometry, projectile rendering, exit feedback. Compile and inspect in Studio.
- [x] Client: useful menu and character selection, owner labels, touch/keyboard controls, hearts/respawns/objective/result. Verify actual client GUI on desktop and phone emulator.
- [x] Domain: failing encounter tests, then LevelDirector and controlled game gateway using actual Session damage/shields. Verify NPC death/waves, boss reflection, one-time win, fixed roster/selection guards.
- [x] Builder: embed shared private sources, emit separate playable place, structural tests and compile/build checks. Keep user's old place untouched.
- [x] Integrate via MCP; play menu, movement, attacks, real enemy damage, respawn, boss and exit; fix runtime issues. Preserve actual limitations in a short run note.
- [x] Review changed code and deliver the playable implementation in the feature branch. No merge/public publication.

## Verification result

Actual solo client-input smoke reached Won in48.19seconds with three reflected projectiles, attempt4, zero remaining respawns and rawLife31. Three real clients started with identical Yellow templates and received separate owned actors/nameplates. Phone emulation verified touch controls. Eighteen new gameplay contracts and all existing suites pass. Reports distinguish the completed solo smoke, trio start, and unrun full trio/hardware/reconnect acceptance.
