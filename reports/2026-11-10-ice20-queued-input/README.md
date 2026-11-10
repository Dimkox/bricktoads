# Ice QA held-input correction after native20

Native20 completed Ice after three paid falls. Its original-NPC logical18
matrix had passed before that run. The native logical rings demonstrate
regular steering accepted about167–201ms after planning, while that fixture
applied each plan synchronously. The full native audit is
`../2026-11-10-full-campaign-playthrough/attempt-20-ice-audit.md`.

This report freezes a bounded QA input correction. Production mechanics,
geometry, HP, stock and all other course policies remain unchanged. No Studio
test was started or controlled by this audit agent.

Baseline E7: `e7c8152f21d45b281ca75150c39e1f78ff289c9bbce73f25945375f981b3037c`.
Candidate 1D: `1d5693ed7ed9089a7c645c8bf4f3b8b2578fe169dd758f316c47f9b51a280695`.

## RED and the input boundary

The probe uses the existing corrected original-NPC fixture: original Session,
Modes, CampaignDirector, SourceCombat and CampaignEnemies; only native actor
presentation and ground Humanoid movement are represented by an adapter.
Seed is the actual native20 seed1158731273, one hero, initial Z-6. There are
nine cases: plan cadence0.133/0.167/0.2 crossed with regular Move hold
0.133/0.167/0.2.

At each fixed1/60 frame, due ordinary inputs are delivered first, then a new
plan may be generated, then Session/Modes/NPC physics step. An urgent Move
and Jump share a2/60 delivery time. A newer urgent plan supersedes older
delayed regular plans; stale steering must not overwrite that newer action.
No source gameplay state or logical actor position/velocity is written.

E7 passes five cases and fails four. At cadence0.2/hold0.2, it contacts the
final Icicle at +13.45, X288.681/Y3/Z-3.482, followed by reaction, missed gap
jump and a fall near X313. This is the same authored hazard and failure
mechanism as native20's +13.050701 Icicle contact at X288.009/Y3/Z-3.840.
The other failed cases include delayed takeoffs and a low-speed takeoff
after a dodge; their negative traces are retained in `baseline-red.txt`.

**This is not an exact replay of native20.** In this fixed queue model all
three E7 cases at cadence0.133 already pass. The final Icicle failure occurs
at cadence0.2/hold0.2. The queue and superseded-plan serial are a conservative
boundary abstraction; they do not reproduce the real RenderStepped resend
clock or0.06-second Move gate. The native evidence establishes that those
held-input effects exist, not that this probe duplicates every packet.

## Five-line QA correction

The Ice position/velocity steering gains change from0.6/0.5 to0.35/0.28,
consistently in actual steering and its three read-only forecasts. The lower
feedback gains avoid the large alternating saturated steering observed when
old commands remain accepted into the next plan interval.

The takeoff lead retains a4.7-stud minimum and also allows current forward
speed times plan cadence plus the urgent2/60 delivery interval, with a0.5
stud inset. This requests ordinary Jump before a packet can arrive beyond
the edge. The existing later-support landing check still rejects a jump
that cannot cover the gap at current horizontal speed.

These parameters have bounded empirical evidence below; no mathematical
all-latency stability guarantee is claimed. Raw bytes outside the Ice helper
and Ice function region are identical to E7, including Rope and dispatch.
See `diff-from-E7.patch` and `validation.json`.

## Verification

Run from the repository:

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-ice20-queued-input/verify.py
```

The verifier reruns pinned policies and probes, checks exact expected counts,
compiles Luau and compares raw non-Ice bytes. It fails on a mismatched count,
compile result or policy hash.

| Check | Result |
| --- | --- |
| Queued original-NPC9, E7 | 5 pass / 4 fail |
| Queued original-NPC9, 1D | 9 pass / 0 fail, all Life47/original actor/attempt1/stock3 |
| Prior first-section36, three heroes | 36 pass |
| Prior complete static36, seed990047694 | 36 pass |
| Synchronous original-NPC18, seed990047694 | 18 pass |
| Synchronous original-NPC18, actual seed1158731273 | 18 pass |
| Existing broad100, modes2–6/five seeds/four cadences | 100 pass |
| Existing accepted-live-effect/rewind8 | 8 pass |
| Compile / exact hash / non-Ice byte comparison | Pass |

Independent reviewer reran queued baseline/candidate and compile, confirmed
the five-line Ice-only delta, and cleared this candidate for another bounded
native run. This is not native deathless or all13-stage Won acceptance.

Native20's checkpoint3 Snowball can sweep the newly spawned body before its
first plan, with shield blocking HP but retaining ordinary reaction. That
pre-input UX limitation remains separately documented; no production shield
or respawn rule is changed here. Multiplayer, other seeds beyond the retained
regressions and exact Roblox transport replay remain outside this evidence.
