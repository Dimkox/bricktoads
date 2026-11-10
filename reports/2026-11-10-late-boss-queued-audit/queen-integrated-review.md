# Dark Queen: bounded QA response integration

Final working Combat SHA256: `bebdb12c47f7cefa1b079d8bec236f0a178de5bf5929a86476c769554f8ae85c`. Removing only the new Queen helper/cache and its two invocation lines restores exact checkpoint4F1D. General Slaughter's helper and every prior branch are byte-identical. Production sources, Bridge97, Early1D and clientB40 remain unchanged.

The actual queued baseline's first hit is Sweep serial3. Tell starts6.175s, effect6.575s. At6.266667s the hero is still11.1studs in front, outside the generic reach+2 threat gate of10, so the invulnerable-boss fallback continues approaching. Perpendicular walking is first planned6.4s, delivered6.533333s, leaving41.667ms before the effect. Source Sweep hits6.583333s. Source Queen has only Sweep and Spin; no teleport or projectile action is involved.

The new Queen-only QA helper prepares perpendicular momentum before the next Sweep, preserves the chosen world side through Tell, and reserves a stable refuge from Spin's original center. Spin is the actual world-axis8-by-4 ellipse offset4 in Z: maximum origin distance9.237604 plus hit radius3.2 is12.437604. The14.2 safe envelope and16stud refuge are conservative for this authored encounter. Already-clear Tell/Active positions hold instead of returning toward the generic8.5stud target. Output remains ordinary Move/Run intent; Session and Boss retain hit detection, attack timing, damage, progress, AI and resources.

The helper requires DarkQueen, Boss stage, a normal unheld grounded hero and valid finite arena/attack data. Existing pending attack/reaction/action, carried enemy and Captured/Mounted Dragon precedence runs before it. A weak per-Session cache separates slot, run, epoch, actor, attempt, Boss identity, serial and move name. All other boss/NPC behavior is retained.

| Queen case | Baseline outcome | Integrated source outcome |
| --- | --- | --- |
| Queue0 |Won71.3917s, original47/1/3,0hits |Won70.4583s, original47/1/3,0hits |
| Queue0.133 |Lost50.8s,4deaths/stock0, progress84 |Won75.9167s, original47/1/3,0hits |

Both integrated cases earn exactly21 underflows, progress240 and natural BossDefeated. The integrated helper uses a fixed0.133-second delivery margin, so zero-queue elapsed time/BossHit count differs from the preliminary probe; the required complete outcome and untouched resources remain verified.

Final verification also retains:

- General Slaughter: all4 complete source encounters and33 state/priority guards unchanged, including its legitimate one-reserve queued victory.
- Buzzball: both prepared queue0/0.133 battles unchanged, both phases, one earned underflow, original actor and no deaths. The explicit normal `finishChase()` prepares battle entry; it does not prove the Clinger chase.
-208 earlier Dragon/Guardian/step-off/Bridge checks, plus79 Queen-specific frozen-state, identity/reset, hold, stage/ground/carry/Dragon/attack/reaction and read-only output checks.
- Compilation and independent scope/encounter/regression reviews.

Reproduce the final integrated receipt:

```powershell
.\.tools\python-3.13.9\python.exe reports/2026-11-10-late-boss-queued-audit/verify_queen_integrated.py
```

The verifier uses current BEB plus pinned pre-Queen source and baseline fixtures; historical4F audit verifiers remain scoped to their checkpoint. This is a bounded source/QA verification on one seed with mapped non-engine movement, facing, floor and impulse response and fixed delivery clocks. It does not establish actual native acceleration/rig collisions, public-server latency, Finale traversal or full13 completion. No Studio control, publishing or Git action was performed by this implementation/review agent. Native25 remains a separate ordinary acceptance test.
