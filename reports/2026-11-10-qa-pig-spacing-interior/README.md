# Rejected: Pig-spacing seven-stud inset

**Rejected for insufficient combat progress. The working QA sources are
restored to their exact original hashes:** CombatBFB17590… and Bridge97C32BCB….
No production, Early1D, clientB40, Studio or Git state was changed.

The rejected candidate is retained only in this report: CombatCB44211D… and
Bridge74C59DC7…. `validation.json` has the complete hashes and expected
positive/negative results. Do not deploy the report's candidate copies.

## Scope and conditional proof

The candidate added an internal hint only to the already validated ordinary
`pigSpacing` evasion branch. The Bridge consumed that hint inside its existing
grounded tactical-evasion gate, using a seven-stud inset on eligible floor
dimensions, capped at half the span minus one. Dimensions below eight kept
the existing three-stud inset. Other evasion branches, flights, ready running
primaries and accepted attack holds were unchanged. The ordinary TinyFace /
windup priority was not reordered.

At the first native23 grounded Pig point X47.378/Y3/Z11.007, a prepared Pig
2.8studs diagonally southwest makes the actual Combat plan emit spacing
evasion(+0.445,+0.895). Actual baseline Bridge composition yields outward
Move(+0.666,+0.746), goalX50.049/Z14. The rejected candidate instead emits
ordinary inward Move(-0.352,-0.936), goalX47/Z10. The baseline fails the
inward-composition assertion; the candidate passes it.

The dynamic conditional probe invokes actual Combat, extracts the actual
Bridge foot function, sends ordinary inputs through real Session and imposes
the original contact time using captured PigJab/profile18 tuning. Its prepared
Pig remains2.8studs diagonally relative to the hero to exercise spacing; this
is not the retained native NPC path. Ground/Humanoid response is mapped.
Baseline falls at0/33ms delivery but survives80ms; candidate survives all
three. This proves only conditional contact clearance, not native avoidance
or combat progress.

Retained checks passed:26 Bridge,146 Dragon,10 retained Guardian,26 step-off,
28 dimension/gate/normalization checks, and compilation. The hint is stripped
by actual Bridge/public normalization. Narrow7/8/14/20/22-stud dimension
cases retain ordered clamp intervals. These checks did not discharge liveness.

## Decisive zero-output and progress failure

At the reserved inner corner X47/Y3/Z10, with a grounded, ready, stationary
hero facing southwest and a rawLife15 Pig at
X45.753588/Y3/Z7.492719, the actual Combat plan emits the Pig spacing hint.
Actual Bridge composition clamps back to the hero's current point and emits
Move(0,0), primaryfalse, jumpfalse, runfalse. Run-up does not preempt this
case. `pigSpacing` returns before the legal-primary branch while the Pig
remains close. Independent review reproduced this actual composition.

The required follow-up prepared30-second source encounter uses real
Session, LevelDirector, SourceCombat and ordinary Pig NPC behavior. Unlike
the conditional envelope, it neither imposes a Hit nor moves the Pig relative
to the hero each plan. Its ground movement, facing and collision boundary are
still a non-native adapter, explicitly declared in the probe.

Result: Pig alive with rawLife15 unchanged; two ordinary primary requests
were accepted but dealt no enemy damage;19 hero Hits, heroLife47. Thus the
probe did not establish EnemyDeath or an effective ordinary primary after
leaving contact. A weak Jab can damage and recover the same raw Life while
spacing repeatedly prevents progress. The candidate is rejected rather than
expanding combat behavior or pickup/attack fallback without its own RED.

## Reproduction

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-pig-spacing-interior/verify.py
```

The default verifier uses pinned BFB/97 originals, the pinned rejected copies,
navigation snapshot and retained probes. It does not overwrite or require
the current working policies. Expected negative checks remain the baseline
inward assertion and the rejected candidate's30-second progress assertion.
Validation preserves the original BFB/97 restoration hashes and timestamp
under `atFreezeRestorationHashes` and `atFreeze`; current working hashes are
separate provenance. Optional `--check-working-baseline` checks restoration
only when the working policies are expected to be BFB/97. The pinned copies,
extracted actual functions, tests, diffs and complete logs remain negative
evidence, not an accepted fix.
