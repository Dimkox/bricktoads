# Retain available source Dragon interrupts

The unconditional Dragon-evasion priority added in03BE discarded an available normal run strike. A paired actual-domain contract now exercises Session, SourceCombat, LevelDirector and DragonFlight instead of checking only returned movement flags. The hero starts with47Life/attempt1/stock3, an accepted source Headbutt is due at3.35seconds, and a prepared ordinary run is observed before the next client response. The rejected03BE policy and candidate receive the same normal-response delays0.133/0.15/0.167seconds.

At0.167seconds, the rejected policy chooses only16stud/s sideways movement. It receives a real source Headbutt Hit at3.35, leaving hero31 and enemy47. The candidate sends ordinary Move(run=true) and public Attack(Punch); Session chooses Dash and stops the normal movement itself. Its accepted time is3.168333, captured attack deadline3.348333, and actual EnemyHit is recorded at3.35. Session.step runs before Director.step, so its47→31 heavy reaction cancels the pending Headbutt in that frame. The hero receives no Hit and retains47Life/attempt1/stock3. Both policies avoid the shorter-delay Hits, but the candidate also earns the normal heavy response there.

Only the forced Dragon priority is removed. The earlier reachable-height run-up correction and Guardian Bullet-before-pickup priority remain. The older03BE combined14-assertion report is historical to that frozen, rejected priority; its mandatory-Dragon-evasion assertions are intentionally not requirements for this candidate. The retained Guardian subset has10 passing assertions, plus146 run-up assertions,26 step-off assertions and the earlier public Session Dash contract.

Run from the repository root:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-dragon-interrupt/probe-before.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-dragon-interrupt/probe-pair.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-dragon-interrupt/guardian-retained.luau
```

Expected exits:1,0,0. The rejected03BE snapshot and all probes/logs are versioned. The contract uses a numeric ordinary-movement/source-cone adapter and1/600second domain slices. It omits native collisions, NPC-head support, gravity and network transport; it is not native60Hz acceptance or a universal latency claim. The hero start is a native18 position, while the enemy start4.5studs ahead is a source-calibrated prepared counterexample, not an unlogged simultaneous native pose. It proves the unconditional priority can regress a legal source response, not that it caused every native18 death or that a new campaign has won.

Native18 separately demonstrates grounded bridge interference: a perpendicular Walk request at7021.983 was replaced by Stage gap run-up at7022.130 before a Headbutt Hit at7022.224. That composition issue is reviewed separately. Native17/18 have different seeds and are not treated as a causal pair. No production source, live body, health, reserve, AI or phase was changed.
