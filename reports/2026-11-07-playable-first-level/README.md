# Playable main-project verification

Studio 0.746.0.7461269, private place117412694427208. Main project sources were installed and exercised through Roblox Studio MCP.

- Real menu buttons selected Mr. Brown and started a run. Actual keyboard movement, Punch/Dash, enemy deaths, respawns and defeat were observed.
- A subsequent actual client-input smoke completed Approach → Courtyard → Boss → Exit → Won in48.19seconds. Four enemy instances died, three actual projectiles were reflected, and the hero reached the exit on attempt4 with zero respawns and rawLife31. The raw final State and phase timings are in `solo-smoke.json`.
- That smoke automated valid contextual Move/Jump/Attack RemoteEvent inputs against the real physical scene. It did not change server health, positions, roles, actor IDs or outcomes. It is an engine smoke test, not a human usability playthrough or real reconnect test.
- iPhone17Pro Studio emulation: menu/result, new-game button and active HUD inspected; touch input enabled, movement stick104×104, attack buttons77×56. Hardware phone/tablet testing remains outstanding.
- Three real Studio test clients selected the same Yellow template. The authoritative host started through client Intent; all three clients received the same run with distinct own slots, actor IDs and owner nameplates. Actual respawns remained independent. `trio-start.json` records the client states and replicated bodies; a full trio level playthrough was not run. The earlier mistaken click on a non-host and premature EndTest label are explicitly corrected in `trio-ui-attempt.json`.
- StreamingEnabled=true initially exposed missing scene/actor replication without Player.Character. The game now assigns server ReplicationFocus and uses atomic actor models; camera/world visibility was rechecked in the actual client.
- NPC pursuit stops before unsafe support; external knockback/falls remain possible. The guardian now waits until a hero enters its arena. Late reflected-projectile expiry and lethal-before-exit victory were fixed with failing-then-passing regressions.

Native Luau:18 new gameplay contracts,46 lifecycle tests,37 Session cases/318 Combat assertions,18 connection cases and14 gateway cases pass. Structural builders:17 tests pass; all33 source/test scripts compile. The original local `places/BrickToads.rbxlx` was preserved; the playable artifact is `places/BrickToadsPlayable.rbxlx`.

Human enemy roles/options, boss queues, multiple groups/levels, full source-mechanics fidelity, physical mobile devices and actual same-server reconnect are not claimed complete.
