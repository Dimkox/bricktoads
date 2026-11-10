# Independent read-only Queen geometry counterexample

Working Combat snapshot during this audit:
`4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129`.
No Source or Studio changes were made by this audit.

Source Queen moves are Sweep and Spin. There is no Queen teleport or
projectile move in CampaignBoss. Sweep uses tell0.4, active0.25, reach8,
half-width4 and height4. Spin uses tell0.7, active1.8 and swept radius3.2.

Spin motion is world-axis aligned rather than rotated by its attack aim:
`x=origin.x+8*sin(theta)`, `z=origin.z+4*(1-cos(theta))`, where theta advances
through4*pi over the active interval. Its center-distance maximum is
sqrt(256/3), approximately9.2376, before arena clamping. Adding swept radius
3.2 gives an outer radial envelope of approximately12.4376. The source
subdivides curved sweeps into at most0.05-second segments. This is source
geometry, not a claim that coarse endpoint samples alone prove safety.

The existing attackThreat uses a conservative origin distance threshold of
orbit+radius+2=13.2 and selects a retreat radius14.2. Once the hero is outside
that threshold, attackThreat returns nil. The invulnerable-Boss fallback then
steers to radius8.5 around the current Boss position, which can move an
already-clear hero inward during Tell/Active.

This was confirmed by calling the actual working Pilot.plan in a prepared
grounded Finale observation: Boss/Spin origin(72,3,0), Hero(86.2,3,0), authored
arenaX39..105 andZ−29..29, healthy connected Hero47, no pending attack or
reaction. The read-only observation returned:

```text
SPIN_ALREADY_CLEAR 14.2 Move -1 0 run false evasion true primary false
```

The assertion required x<−0.99, z=0, evasion=true and primary=false. This is
a policy counterexample; it does not inject contact or demonstrate that this
particular snapshot must cause a hit. The independent whole-Queen queued
fixture and its actual earliest-Hit trace remain the encounter evidence.

No Core change, altered boss pose/aim/phase, damage, resource or deadline is
justified by this counterexample. A normal-control candidate can preserve
clearance during invulnerable Tell/Active, with whole-boss and finite-arena
checks required before any acceptance.

## Independent integrated-source review

The later integrated Combat snapshot
`bebdb12c47f7cefa1b079d8bec236f0a178de5bf5929a86476c769554f8ae85c`
was reviewed read-only. Removing only the Queen helper and its two-line call
reproduces the pinned pre-Queen4F1D source byte for byte. The helper reads
actual attack records and stores only local QA identity/side memory; no
Boss phase/pose/aim, hit, deadline, Life or resource write was found. Existing
carried-enemy/Dragon and pending own-attack/reaction gates remain earlier.

Independent actual-source whole-Queen reruns passed both queues:

| Queue | Whole victory | Hero | Earned source progress |
| --- | --- | --- | --- |
| 0 | 70.4583s | Original47/attempt1/stock3,0 Hits | 240,21 underflows,33 BossHits |
| 133ms | 75.9167s | Original47/attempt1/stock3,0 Hits | 240,21 underflows,21 BossHits |

Compilation passed. The integrated helper uses a fixed conservative133ms
movement budget even in the zero-queue test, so that immediate-input route
differs from the probe wrapper's62.8583-second route. The full-source
underflow and resource outcomes, rather than identical routes, are the
acceptance evidence. This remains a bounded source simulation, with native
validation pending.
