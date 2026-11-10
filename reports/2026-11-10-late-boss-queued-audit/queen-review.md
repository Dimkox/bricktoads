# Prepared Dark Queen13 queued-input baseline

This is the historical pre-Queen baseline audit at checkpoint4F, using seed1158731273 and the authored level13 arena. Its verifier now uses the pinned4F capsule so the negative evidence remains reproducible after the later Queen-only integration. For current working-source acceptance use `verify_queen_integrated.py` and `queen-integrated-review.md`. This baseline audit does not change a gameplay source, QA policy, Studio session or Git state.

The fixture is cloned from the corrected Slaughter source encounter: actual Session/Core/Combat/SourceCombat/CampaignBoss, ordinary identity/sequence Move/Jump/Punch packets, finite authored floor, actual cone/orbit collision, byte damage, phase/progress and normal three paid respawns. Initial entry uses the Finale course finish; subsequent appearances use an actual `Modes.respawnPosition` query with the finished-slot1 contract. DarkQueen is created normally with15Life/progress0/Ready. The completed-Finale actor is a prepared QA observation selecting actual Bridge foot behavior; it does not earn the Finale traversal or set production completion.

The old pinned CombatBFB17590 and pinned GeneralSlaughter-specific Combat4F1D67 both produce **identical output** in these cases; unchanged Bridge97's actual foot is used. Thus the queued failure is not attributed to the General Slaughter helper.

| Fixed input queue | Source outcome | Boss elapsed | Boss progress / underflows | Hero Life / attempt / stock | Confirmed deaths |
| ---: | --- | ---: | --- | --- | ---: |
|0 |Won |71.391667s |240 /21 |47 /1 /3 |0 |
|0.133s |**Lost** |50.800000s |84 /7 |0 /4 /0 |4 |

The queued case naturally exhausts its four appearances after12 boss hits on the hero. Terminal bossLife7/phase1 remains.52 ordinary REACTION rejections are recorded; no rate or identity error is reported. The no-delay case earns36 BossHits,21 underflows and BossDefeated, with no hero hit. The verifier treats the queued Lost as expected **negative evidence**, not a successful encounter.

An initial audit assertion incorrectly equated all deaths with paid replacements and therefore failed on the final elimination. That harness error is retained in `queen-initial-budget-assert-error.txt`. The corrected assertion counts source CommitSpawn events: each committed appearance after the initial appearance spends one reserve; the fourth death at zero stock grants no fifth appearance. Both cases rerun successfully as an audit with the corrected resource invariant.

Run:

```powershell
.\.tools\python-3.13.9\python.exe reports/2026-11-10-late-boss-queued-audit/verify_queen_audit.py
```

This remains a prepared source encounter with mapped non-engine movement, turning, floor response and impulses. It does not reproduce native acceleration, rig collisions, RPC timing, the preceding Tower/Finale traversal or a real public server. No Queen fix is proposed or implemented here, and no native/full13 Won is claimed. The negative case identifies a delayed-input boss risk for further bounded diagnosis if the native campaign reaches it.
