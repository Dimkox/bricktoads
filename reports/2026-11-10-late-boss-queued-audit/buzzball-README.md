# Prepared Buzzball11 queued-input audit

No fix is proposed. The current Combat4F / Bridge97 composition defeats the
whole prepared Buzzball encounter with both immediate and133ms queued normal
inputs, within the original three-reserve budget.

| Queue | Source boss result | Hero result | Contacts |
| --- | --- | --- | --- |
| 0 | Defeated56.725s, raw0, one underflow; both phases observed | Original actor, attempt1, stock3, Life31 | One source hit, no death |
| 133ms | Defeated57.783333s, raw0, one underflow; both phases observed | Original actor, attempt1, stock3, Life47 | No source hit or death |

The fixture clones the corrected Slaughter presentation boundary using
`CampaignDefinition.build(11,1158731273)`. It creates Buzzball normally at
raw207, no progress counter, and `Chase`. It then invokes the normal source
`finishChase()` API exactly once as **explicit prepared battle-entry setup**.
It does not set a boss phase directly or claim that the Clinger chase or
course was completed. The natural constructor places the boss on its authored
arena. The fresh Session's clock advances to2.1 before boss construction;
initial appearances receive no shield.

The test uses actual Session/Core/Combat/SourceCombat/CampaignBoss logic for
input identities, rate limits, attack selection, windups, vulnerability,
byte damage, reactions and final defeat. All hero actions are ordinary
Move/Run/Punch/Jump packets. Actual CampaignModes supplies the prepared
finished-slot retry position; no health, reserve, hit or progress is written.
Actual Bridge's finished-body early return is asserted on every plan. The
finite72×64 arena and source boss containment remain active.

Movement, facing, gravity and additive impulses are numerical presentation
mappings. This is not a Roblox Humanoid or native encounter replay. The
bounded result covers one seed, one hero, fresh global reserves, fixed133ms
planning, and queues0/133ms. It does not establish Clinger traversal, chase
entry, multiplayer, public-server behavior or full13 completion.

Reproduce from the repository root:

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-late-boss-queued-audit/buzzball-verify.py
```

The verifier rebuilds isolated `buzzball-*` fixture files, reruns both whole
encounters, checks exact source arithmetic/resource outcomes, compiles the
fixture/probe, confirms the extracted foot matches current Bridge, and
verifies all recorded implementation hashes remain unchanged. Results and
limits are in `buzzball-validation.json`; full output is in
`buzzball-outcome.txt`. No Studio, Git or implementation change is performed.
