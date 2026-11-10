# Slaughter10: whole-boss input-queue counterexample

**QA-only helper integrated; native validation pending.** With the corrected
production retry contract, unchanged Combat loses all four appearances at
133ms input delay. The integrated General Slaughter helper wins all four
prepared whole-boss cases inside the normal global reserve budget. Fresh
133ms still consumes one reserve; the two calibrated one-reserve entries
retain their original bodies. See [current integration evidence](integrated-source.md).
Production, Bridge97, Early1D, clientB40 and Studio state were unchanged.

## Source composition and preparation

The fixture uses actual Session, Core lifecycle, Combat, SourceCombat,
CampaignBoss and the extracted actual Bridge foot function. It constructs
General Slaughter normally at raw255/progress0/Ready, on
`CampaignDefinition.build(10,1158731273)`'s authored72×64 platform. The
platform is finite and gravity applies after leaving it. The actual boss
arena bounds and source containment remain active.

Hero starts at the authored course-finish entry with a natural Session's
Life47/attempt1/three global reserves. Initial CommitSpawn grants no shield;
the initial2.1seconds only advance time before boss construction. The source AI chooses every attack;
ordinary input packets alone select and resolve every hero attack. No hit,
phase, raw Life, underflow progress, death, reserve or completion is injected.

The prepared Race-finished QA observation matches Native24's terminal detail.
Actual foot returns the Combat plan through its finished-body early branch;
the later grounded tactical branch that forces evasion.runfalse is bypassed.
The baseline Combat evasion itself requests walking. The fixture asserts this
actual composition identity on every plan.

Normal Move/Run/Punch/Jump intents pass Session identity, sequence and rate
checks. Queued plans retain their original actor/attempt/connection/level
identity. Running requires a fresh grounded request, no reaction, and actual
projected velocity>=18; setting a flag does not grant an instant run strike.
Targets use the actor's current facing and the source reach/side/height cone.
SourceCombat chooses the action, Session resolves windup and contact, and
CampaignBoss applies vulnerability, byte arithmetic, recovery and all21
required underflows. The normal three reserves supply at most four bodies.

## Earlier bounded results, retained as negative evidence

Plan cadence is133ms, physics1/120s; input queues are0 or133ms.

| Policy in probe | Queue | Result | Hero resources | Boss result |
| --- | --- | --- | --- | --- |
| Unchanged BFB Combat /97 Bridge | 0 | Won95.39s | Original47, attempt1, stock3; no Hit | raw0/progress240,21 underflows |
| Unchanged BFB Combat /97 Bridge | 133ms | Lost52.89s | attempt4, stock0,13 Hits including protected contacts | raw79/progress0, phase1 |
| Running on grounded evasion | 0 | Won107.93s | attempt2, stock2, Life31 | raw0/progress240,21 underflows |
| Running on grounded evasion | 133ms | Lost60.09s | attempt4, stock0 | raw47/progress0, phase1 |
| Running evasion plus retreat to10 during own post-attack cooldown | 0 | Won99.49s | attempt4, stock0, Life31 | raw0/progress240,21 underflows |
| Same cooldown-retreat variation | 133ms | Lost54.69s | attempt4, stock0 | raw63/progress0, phase1 |

The variations exist only in the probe. The cooldown variation preserves
pending attack holds, reaction locks and normal source attack selection; it
does not pause the NPC or alter any deadline. Both variations are rejected:
neither clears the queued whole encounter, and both consume reserves that
the immediate baseline retained. Partial boss damage is not a success.

## Native evidence and limits

Independent Native24 audit refutes the proposed pending-attack lock explanation:
the damaging Headbutts start after the previous hero strike has resolved;
there are no corresponding stage10 AttackMiss records. For the last
Headbutt, the first perpendicular plan arrives approximately115ms after Tell.
Only235ms remain before Active, while walking16stud/s needs219ms to cross
the3.5-stud half-width, leaving almost no transport/turning margin. Charge
evasion can also reverse near the finite arena boundary. Running alone is
therefore not assumed safe; its negative probe result is retained.

This is a prepared source simulation, not a native replay. Ground movement,
gravity, additive impulses and facing are numerical presentation mappings.
Native Humanoid acceleration, collision with rigs/decorations, floor friction
and exact transport/resend scheduling are omitted. Authored finite support
and source boss-arena clamping are included. The fresh three-reserve fixture
is more generous than Native24's one remaining reserve at entry, yet its
queued baseline still loses. No broader all-seed, multiplayer or all13-stage
acceptance follows from these results.

The earlier fixture's retry `findSafe` maps to the course-finish entry.
Current integration evidence corrects this after Boss construction by calling
actual CampaignModes.respawnPosition. Initial and pre-test resource calibration
remain at the separate authored course-finish entry.

## Single follow-up probe and current acceptance

The separately frozen [preemptive momentum probe](preemptive-probe.md) earns
all21 underflows in four prepared cases, including an ordinary-two-Fall
entry with one remaining reserve. The fresh133ms case still loses one body
to three Headbutts. Its original-body gate remains RED. The project's actual
acceptance permits three normal paid respawns. After correcting retry
placement and rerunning actual-source cases, only the bounded General
Slaughter helper was integrated in CombatQA. The six earlier negative cases
remain intact; no deathless claim follows.

## Reproduction

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-slaughter-qa-proof/verify_integrated.py
```

The current verifier regenerates the exact Bridge97 foot, calls actual
CampaignModes.respawnPosition for post-constructor retries, and runs baseline,
wrapper and integrated whole encounters plus the retained208 checks and33
state/gate checks. It checks exact earned progress, reserves, source scope
and compiler output. Current receipts are in `validation-integrated.json`.
Earlier `validation.json` and `validation-preemptive.json` preserve the
original fixture and probe stage; their old verifiers require that stage's
working source hash and are archival.
