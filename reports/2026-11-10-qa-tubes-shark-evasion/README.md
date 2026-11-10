# Native20 Tubes negative control

No production or active QA source changed. The current Tubes helper remains
`e365d2ecf700511a25230f92d9387771c6071ca27be911297306569945ca4013`;
Late remains `b786b7a9f9144331089180a28dc0a549c638038ee47c7b91a27e2d695bc800d8`.
The swim-Jump experiment in this directory was rejected and is not installed.

## Actual native chain

Native20 was one continuous registered solo campaign, run
`b280d913-e985-4f4d-a190-d80e85728ea0`, seed1158731273. It earned1–8 and entered
Tubes9 on actor141/attempt4/stock0/Life47. Stage9 began at1794331512.183408.

| Stage time | Actual event |
| --- | --- |
| 6.348031 | Electrofish−2 Shock/DragonFire at X32.204/Y3/Z0.056,47→31. |
| 21.213 | One normal HeroJab hit Shark−4 at X198,15→13. It later recovered15. |
| 25.728787 | Shark accepted Bite, effectAt26.028788. |
| 26.562823 | Shark Bite/PigHeavy hit X256.445/Y2.998/Z0.010,31→15. |
| 28.044480 | Gear268 hit X270.082/Y1.151/Z0.015,15→0. |
| 28.846371 | Ordinary CombatUnderflow Death, cohort eliminated, Lost9. |

The route waited near X256 for the Gear's vertical-motion phase. It kept normal
current/height steering but did not attack or evade the following Shark in this
interval. After the real Bite, the mode-frame ring observes a real vertical
impulse and movement toward the Gear. That distinguishes the Shark hit from
synthetic static-hazard impulse requests, which have no direction-producing
attacker in the native world. This is a QA input-policy limitation; no production
mechanic defect is established by this trace.

## Bounded source reproduction and rejected experiment

`fixture.luau` copies the existing full Session/Modes/Director/CampaignEnemies
fixture, adding queued ordinary input packets and first-body observation. Its
world adapter still replaces native Humanoid/contact physics. Static hits with
no attacker/accepted direction do not invent a Modes impulse. There is no manual
health, stock, phase, pose or enemy-state edit during these runs.

The unqueued0.167-second source run reproduces Shark26.333 then Gear28.033,
after a separate ordinary Robot entry death and paid retry. Its fresh starting
resources differ from native attempt4/stock0. The frozen queued counterexample
uses0.133-second decisions and0.133-second packet delay; it instead receives
Gear16.433 then a fatal Shark28.067. That ordered difference is explicit: queued
loss is not the same native cascade. These are prepared logical cases, not a
replay of actor141 or all earlier NPC interactions. The complete native stream
is retained in the adjacent attempt20 archive and detail files.

The broader9-case sweep has zero cases satisfying the deliberately stronger
first-body/no-Shark/no-Gear requirement. Some fail or stall earlier at entry;
these are not all attributed to Shark. The experimental normal Water Jump
response also has zero qualifying cases and remains rejected. It must not be
used as a passing full-Tubes or latency result. A later full campaign can retain
the existing helper and spend its normal reserves; deathless play is not the
campaign acceptance requirement.

From the repository root:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-tubes-shark-evasion/trace-queued-counterexample.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-tubes-shark-evasion/trace-source-cascade.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-tubes-shark-evasion/probe-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-tubes-shark-evasion/probe-experimental.luau
```

Expected exits are0,0,1,1. The0 exits only confirm the recorded negative
controls; their assertions require the stated damage ordering. The raw original
helper is pinned in `baseline-policy-original.lua`; `baseline-policy.lua` only
adjusts its sibling Combat import for this report directory. This audit used no
Studio control, extra windows, Git push or Jira edits.
