# QA threat priority after attempt17

Attempt17's third body died to three Guardian Bullets after returning two balls. The third successful return came from the fourth body after respawn. The original pilot chose Ground pickup/chasing before checking a damaging Bullet; its generic projectile helper also treated the harmless descending Guardian Heavy return ball as a threat. GuardianPattern applies damage only in its Bullet branch. The revised Guardian plan dodges advertised Bullets before pickup, chasing or returning a carried ball, and excludes Heavy from that threat collection. Safe pickup/return behavior is retained when no Bullet threatens.

The ordinary Dragon plan now checks its accepted pending windup before attempting a run-up or an observed-run Dash. It walks perpendicular to the actual enemy facing when available, using the existing safe-destination clamp. The fallback uses the enemy-to-hero direction. This leaves the previous Dragon run-up height correction and all game rules intact.

The report's native timeline establishes the actual hits, deaths and return order. It does not retain simultaneous per-plan projectile/enemy-facing states, so a particular selected Bullet or the precise original selection branch is not attributed to any one hit. The prepared read-only probes establish the priority holes independently. One calibrated close-Dragon volume experiment starts with0.6stud lateral offset and a0.16second remaining tell: ordinary walking clears the3stud side bound before the deadline, whereas a new0.18second Dash cannot interrupt in time. This experiment assumes immediate Move acceptance; it does not prove delayed-input or native survival.

From the repository root on the frozen source:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-guardian-threat-priority/probe-guardian-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-guardian-threat-priority/probe-dragon-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-qa-guardian-threat-priority/probe-current.luau
```

Expected exits:1,1,0. Baseline/candidate snapshots,14 passing assertions, logs and hashes are versioned. Previous146 Dragon-height assertions, public Session Run→Punch→Dash proof and26 step-off assertions still pass. No production source, native actor, health, reserve, phase or AI was changed.

Attempt17's first Cliffs Fall followed a real Headbutt during the bridge's Walk phase. Its second Cliffs Fall has no post-respawn Hit and remains separate navigation evidence. Nav Flight still controls its own crossing movement and can override combat evasion; this patch makes no claim to solve all mid-gap attacks. No new native full-campaign or deathless Guardian result is claimed.
