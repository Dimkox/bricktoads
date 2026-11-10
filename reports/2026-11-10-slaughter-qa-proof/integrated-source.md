# General Slaughter QA helper: bounded integration evidence

The integrated CombatQA helper wins all four prepared whole-boss cases
inside the normal global reserve budget. The source mechanics remain intact.
Native all-campaign validation is pending. Fresh133ms retains a documented
original-body failure: one normal reserve is consumed before victory.

The corrected fixture calls actual `CampaignModes.respawnPosition` on a
finished single-slot view after normal Boss construction. It asserts parity
with the authored arena's x−15, top+3, z. Initial entry remains course finish;
the two pre-test Falls calibrate resources separately before Boss construction.

| Input policy and entry | Queue | Result | Hero | Boss |
| --- | --- | --- | --- | --- |
| Original BFB, initial attempt1/stock3 | 0 | Won95.392s | 47, attempt1/stock3;0 Hits | progress240/21 underflows |
| Original BFB, initial attempt1/stock3 | 133ms | Lost47.342s | 0, attempt4/stock0;11 Hits | raw95/progress0/phase1 |
| Integrated, initial attempt1/stock3 | 0 | Won86.992s | 47, attempt1/stock3;0 Hits | progress240/21 underflows |
| Integrated, initial attempt1/stock3 | 133ms | Won142.942s | 31, attempt2/stock2;4 Hits | progress240/21 underflows |
| Integrated, two ordinary Falls → attempt3/stock1 | 0 | Won86.592s | 47, attempt3/stock1;0 Hits | progress240/21 underflows |
| Integrated, two ordinary Falls → attempt3/stock1 | 133ms | Won136.050s | 47, attempt3/stock1;0 Hits | progress240/21 underflows |

The wrapper and direct working-source cases match exactly on elapsed time,
earned Boss progress/hits, hero damage, resource use and ordinary input
counts. Every win earns36 source BossHits and all21 underflows; no phase,
hit, raw Life, completion or reserve is assigned. Valid public Move/Run/Punch
packets retain actor/attempt/connection/level identities through the queue.
Four per-case whole-victory/budget assertions run in the integrated probe.

The helper applies only to GeneralSlaughter. Its only stored values are local
QA session/slot/hero identity, Boss object, attack serial and chosen direction.
Before a read-only Ready deadline for an upcoming Headbutt, it establishes
perpendicular movement. Actual source Tell still chooses the Boss aim.
The selected side persists into Tell/Active, and Charge chooses available
finite-arena clearance. Positions already clear of the invulnerable attack
hold rather than approach. Boundary planning includes a bounded133ms packet
delay plus planning cadence. Existing carried-enemy and Dragon capture/mount
branches retain priority, along with pending hero attack and reaction guards.

The33 frozen-state/gate checks pass, including reset on hero/attempt/level/
Boss/serial changes. Retained regressions pass: Dragon146, Guardian10,
StepOff26 and actual Bridge97 composition26. Independent review reproduced
the retained208 checks. The source-scope assertion removes the new helper
and its two-line invocation and requires exact equality with original BFB;
Bridge97, Early1D and clientB40 hashes remain unchanged. Compilation passes.

Combat SHA256:
`4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129`.
Full source/artifact hashes and case receipts are in
`validation-integrated.json`; source delta is `integrated-combat-diff.patch`.

This prepared numerical ground/facing/gravity/impulse boundary is not a
native Humanoid replay. Native rig/decor collisions, acceleration, friction
and exact resend scheduling remain outside this proof. The one-seed,
fixed-cadence cases do not establish timing-invariant avoidance or all13-stage
completion. The fresh queued result is an improvement over the exact queued
baseline, while its original-body gate remains RED. The permitted acceptance
uses the original normal reserve budget. No Studio or Git operation was made
by this audit agent.

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-slaughter-qa-proof/verify_integrated.py
```
