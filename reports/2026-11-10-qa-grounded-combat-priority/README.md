# Grounded tactical input before QA navigation

Attempt18's first Headbutt was accepted at1794327021.870, due7022.220 and hit7022.224. The retained planner first issued sideways Walk at7021.983, then changed to Stage gap run-up at7022.130. The other six Headbutt Hits have last-preHit phase Walk. No blanket Flight-evasion override or claim that navigation explains all four Falls follows from this evidence. See the full [native composition audit](../2026-11-10-full-campaign-playthrough/attempt-18-evasion-composition-audit.json).

The actual bridge previously replaced a prepared running primary with a navigation Jump and replaced an evasion request with route movement/run. The correction applies before Nav.plan only to the player's matching, alive, connected, unheld physical actor: actual standing/ground flags and authored support height/footprint must match, and no navigation jump may already exist.

- Evasion requests only ordinary Move toward a projected goal clipped three studs inside that same support; Run, primary and Jump are false.
- A ready running primary requires the existing native launch qualification and no active own attack. The original plan object, facing axes and Run are preserved. The existing client sends Move then public Punch; Session alone validates/selects Dash.
- A follow-up neutral Hold while that accepted attack remains active also precedes navigation. It sends ordinary zero Move without Run/primary/Jump, preserving the strike's existing facing. No pending-interaction exception is invented.
- Unsupported, high, stale, airborne, reacting or existing-flight contexts fall through to unchanged navigation. No jump state is cleared and no landing is invented.

The original baseline fails five of26 composition checks; the candidate passes26. A composed proof passes current production Pilot -> actual bridge foot -> public Session Move(run)/Punch -> Session Dash across a reachable authored gap, enemy47->31, same hero47/attempt1/stock3. The original baseline instead creates Jump and suppresses primary. Existing88 navigation checks and compilation pass.

The intermediate12DD bridge preserved the first primary but still overwrote Pilot's next Hold during the0.18second attack windup. A follow-up public Move at1.14 precedes the accepted attack deadline1.19. In the source-facing adapter,12DD orders backward Run, flips facing and misses (enemy47); the candidate orders zero Move, retains facing and hits (enemy31). Both retain hero47/attempt1/stock3. This is a prepared normal-control contract with World.stop/run and World.move/facing callbacks, not a new native-network claim. The intermediate baseline and both outcomes are preserved.

Reproduce from the repository root:

```text
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-grounded-combat-priority/verify.py
```

The generator extracts actual baseline/current foot and current pure Nav. The public Session scenario reuses the existing pinned canonical Dragon fixture, supplies numeric run/target observations and assumes no ray obstruction. Deep-frozen composition contexts establish no domain-state writes; they do not prove native physics, network timing, all four native Falls, or a complete campaign victory. Native19 remains required. Original production code, NPC AI, actor poses, health, resources and campaign phases are untouched.
