# Full campaign mechanics

The owner explicitly asked to finish the entire game's mechanics. Continue implementation without another design-approval round. Existing BrickToads decisions and subsequent corrections remain binding: fixed 1–3 heroes, five hearts, three successful respawns across the run, no replacement of eliminated heroes, same-body human enemy control, FIFO boss reservations, standard Roblox multitouch direction buttons, English default text, and player responsibility for jumps and navigation.

The current first route is retained. Its completion must advance the same run into the remaining twelve distinct modes instead of returning a premature campaign victory. Actual movement, collision, objectives and boss outcomes drive progress. Merely naming thirteen maps or waiting for a timer does not implement those modes.

## Implementation choice

Extend the existing server-owned Session/World architecture with authored campaign definitions, a mode simulation, five additional boss state machines and a campaign director. Keep the tested causeway director and Guardian as the first encounter. This reuses roster, damage and role validation while giving rope, vehicles, ice, moving supports, water, racing and tower traversal their own behavior. A single reskinned walk-and-fight map would not meet the request; replacing the existing lifecycle would discard already tested rules.

New routes compose deterministic authored sections per run. Respawn/rejoin retain the composition and unlocked checkpoints. No automatic safe-route steering or automatic jump assistance is introduced. Scene movement relocates an existing body; only Session-authorized respawn consumes a life. A normal level transition heals survivors once without restoring the respawn budget or eliminated participants.

## Mode coverage

1. Existing causeway: ground combat, carry/throw, clubs, flies, mounted Dragon and Guardian.
2. Rope: descent, swing, reversal, airborne attack and wall threats.
3. Speeder: mount/automatic forward speed, depth steering, jumps, ramps, warnings and crashes.
4. Ice: inertia/braking, moving blocks, falling ice and spikes.
5. Surf: board movement, water hazards and transition into Big Blag.
6. Serpents: riding moving support through four rooms with spikes/checkpoints.
7. Jet: forward vehicle flight, vertical/depth steering and airborne hazards.
8. Ascent: lifts, fans, springs, gas/electric threats and Robo-Manus.
9. Tubes: transitions between dry movement and swimming, currents, moving machinery and breath.
10. Race: rat opponent, three bomb objectives, actual race outcomes and General Slaughter.
11. Clinger: directional turns, a pursuing Buzzball and a battle form retaining its Life.
12. Tower: cylindrical orientation, moving platforms, springs, wind and rotating threats.
13. Finale: Dark Queen phases, valid attack windows and final campaign result.

Source facts are constrained by the pinned reference and current research. Spatial scaling, original section composition and unmeasured timing remain explicit Roblox tuning. Raw source Life and separate reaction progress must not be silently replaced with linear hearts. Evidence of authored mechanics is separate from proof of exact NES parity.

## Verification and release boundary

Use meaningful tests for input validation, swept collision, checkpoints, phase changes, shared human/NPC profiles and campaign resources/epochs. Run existing regressions, build the playable, reopen it in Studio and exercise new real runtime modes. Record exactly what native checks establish. A successful prepared fixture is not a normal-input campaign playthrough or physical-phone performance acceptance.

The dirty user starter `places/BrickToads.rbxlx`, prior GLBs and frozen imported resources remain untouched. Work stays on the existing authorized feature branch. Push reviewed implementation and synchronize relevant Jira issues; do not close incomplete acceptance work or publish an unapproved public experience.
