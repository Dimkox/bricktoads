# Native23 PigJab: inward evasion feasibility

This is a bounded planning proof for the first PigJab fall, without changing
the QA pilot, Bridge, transport, production source or Studio. The native
source evidence remains in the first-death23 snapshots and causal audit in
`../2026-11-10-full-campaign-playthrough/`.

## Tell and available movement

The successful Pig-5 Tell is+80.936640, scheduled effect+81.236640, accepted
contact+81.251055. The preceding plan at+80.932066 observes
X49.765/Y3/Z14.001; the next plan+81.047461 observes X50.311/Y3/Z14.125.
The snapshot does not contain an exact body position at Tell itself.

The first post-Tell plan is not Evade: its axes are approximately
(-0.049214,-0.063071), exactly the tiny0.08 facing direction. The first
post-Tell Evade is+81.165668 at X50.222/Y3/Z14.006, only85.4ms before contact,
and points outward toward the clamped endpoint X51/Z14.

There were earlier grounded Evades at+80.514638, X47.378/Y3/Z11.007, and
+80.786564, X48.530/Y3/Z13.650. Those offer substantially more time than
the last Evade. The source `pigSpacing` branch can return its tiny facing
input before the later enemy-windup threat branch; the observed first
post-Tell plan matches that branch. This report does not reorder those
branches or change attack/hold/run behavior.

## Conditional RED and counterfactuals

Run the existing local Luau executable on `probe-contact-envelope.luau`.
The probe uses real Session, captured PigJab tuning, profile18 horizontal9 /
vertical0, reaction28/60, ordinary Move validation/input reset and the
ordinary Life/recovery/death FSM. It never writes Life, stock or production
actor state. The fixture starts at the first earlier Evade's native point
and follows the retained precontact command schedule.

Only native presentation/ground response is mapped: grounded Move targets
16stud/s, command delivery is0/33/80ms, an accepted PigJab contact is imposed
at the retained time, its9stud/s impulse uses an explicit outward diagonal,
reaction retains physical velocity, and gravity196.2 applies after leaving
the exact first Aqueduct support. This is not an NPC-AI replay.

| Conditional case | 0ms | 33ms | 80ms |
| --- | --- | --- | --- |
| Frozen outward command sequence | Fall | Fall | Supported |
| Replace only Evades from+80.514638 with ordinary inward Move | Supported | Supported | Supported |
| Ordinary inward Move from first post-Tell plan+81.047461 | Supported | Supported | Supported |
| Replace only last Evade+81.165668 with ordinary inward Move | Supported | Supported | Supported |

The two RED cases preserve the first-death mechanism under real Session
reaction: outward momentum plus the light impulse crosses X54 before
control returns. Inward movement keeps the counterfactual body supported
even when the same contact is imposed. The result establishes that an
ordinary inward response can be sufficient within this conditional model;
the earlier grounded Evade supplies a larger timing margin.

The probe checks these exact expected counts and compiles successfully.
`validation.json` records source hashes, timing facts and limits;
`contact-envelope.txt` retains every result.

## Limits and next decision

The real Pig's exact Tell position/facing and contact predicate were not
archived. A changed hero path could change NPC motion or cause the hit to
miss; this proof deliberately imposes the same accepted contact. Its mapped
ground response has no exact Humanoid acceleration, floor friction, rig/NPC
collision or recovery simulation. Contact positions differ from native by
up to approximately0.8stud. The80ms baseline is GREEN, so this is neither
an exact native replay nor a universal native safety guarantee.

The feasible candidate remains specific: on a grounded evasion near the
edge of this wide current floor, prefer a point farther inside that floor
before projecting the perpendicular escape. The result does not justify a
blanket10-stud inset, especially on the20/22-stud-deep Cliffs. Attack holds,
running strikes and flights require their existing separate gates. No source
change is made or claimed complete by this report.
