# QA follower edge recovery

From the repository root, run these commands with Python 3, Git and the Luau CLI. Substitute your installed executable paths if the ignored local tools are absent.

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-standby-edge/prepare_standby_probe.py
.tools/luau-0.745/luau.exe build/test_standby_edge_baseline.luau
.tools/luau-0.745/luau.exe build/test_standby_edge.luau
.tools/luau-0.745/luau-compile.exe --null tools/qa/full_campaign_bridge.server.luau build/standby_current.lua build/standby_baseline.lua build/test_standby_edge.luau build/test_standby_edge_baseline.luau
```

The baseline must exit **1** on the first near-edge movement assertion. The current probe must exit **0**, printing **29** checks. Compilation must exit **0**. Continue after the expected baseline failure.

The generator writes only four named files under `build/`. It extracts the actual current standby helper and level1/nonlead dispatch line, and compares the neutral baseline dispatch from Git commit `df98106`. That neutral dispatch is identical to the attempt14 bridge's nonlead behavior. Fetch the commit if using a shallow checkout. No pre-existing ignored test code is needed.

The probe uses the real `CampaignDefinition.build(1,1259618153)` support. Attempt14 retained four follower Fall positions but no exact paid-spawn poses or nonlead motion. The three grounded near-edge inputs are therefore explicitly **source-derived nearest-safe candidates**: recorded X, standing Y3, Z−24.8 from the standard1.2stud safe-search inset. They are not claimed as captured native respawn poses. The four recorded below-floor positions are tested as unsupported negatives.

Recovery requires the same native ActorId and SurfaceId, a grounded unlinked body near standing height, and no reaction/death. Only the existing level1/nonlead branch changes. Within five studs of an edge it requests ordinary Move toward a six-stud inset on that support; interior followers remain neutral. It sends no primary, run or jump. The tests deep-freeze observations and cover lead/cohort gating, all support edges/corners, and stale/unsupported/airborne/reacting/mounted/captured guards.

This is an input-policy contract, not a native AI/physics survival proof. Ordinary movement cannot guarantee survival against large knockback, collisions or attacks, and may not save a body already airborne. Missing or mismatched support observations remain neutral. No NPC targeting, geometry, health, stock, authority or pose changes are made. Attempt14 stayed frozen; the candidate is for a later run only.
