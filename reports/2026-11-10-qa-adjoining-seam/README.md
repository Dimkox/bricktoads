# QA adjoining-floor alignment

This changes only the disposable route-input planner. No production navigation, geometry, actor pose, health or reserves change. It was not installed into attempt 14.

Attempt 13's first two recorded falls ended near X0/Z−16.64 and X0/Z−17.37. Exact seed 303307263 has adjoining floors at X−2: the first spans Z−24..32 and the next Z−14..22. The source regression derives these authored floors and patrol, then approaches from a safe current-floor inset using the recorded Z lanes. It reproduces an unsafe planner segment; the sparse native archive does not prove either fall's exact cause. Already-fallen observations remain unsupported.

The planner now aligns within the shared two-stud Z margin before walking across an adjoining seam. Its alignment target sits up to 0.25 studs inside that corridor, beyond the actual bridge's 0.15-stud movement deadzone. An unaligned corridor too narrow for that target holds conservatively. No Jump is added. Mirrored, reverse, nonoverlapping and disabled-crossing cases are covered.

The existing navigation suite had 53 passing checks. The first change reproduced the unsafe adjoining approach and passed 66 checks, but independent review found four composed bridge deadlocks at 0.01 studs outside the shared margin. The final correction passes 72 checks: all original checks, 13 seam checks, four deadzone cases and two narrow-corridor cases. The actual extracted bridge composition independently changes four zero-movement failures to four inward-movement passes. Compilation and diff checks pass; final independent review is clear.

Frozen Nav SHA256: `864b09976d0c926fb20132744c0ddff6dd6afcff572b34f470f46fdcd6a33d33`. Existing test SHA256: `0b8ba46b4bd3e4093bfee0310f1da1a0d66d355a3689941af4e4e5efe8a805e5`. Composed bridge SHA256: `3888c4f37264707855d1a9475224fa989d642e4858eaa01f096e503ae287bdc3`.

From the repository root:

```powershell
.tools/luau-0.745/luau.exe tests/run_route_driver_navigation.luau
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-adjoining-seam/prepare_probe.py --baseline
.tools/luau-0.745/luau.exe build/adjoining_baseline_probe.luau
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-adjoining-seam/prepare_probe.py
.tools/luau-0.745/luau.exe build/adjoining_fixed_probe.luau
```

The baseline composition is expected to exit 1 with four failures. The generator reconstructs the reviewed pre-correction Nav by removing the five deadzone-correction lines, and extracts the actual current bridge foot function without editing it. Both imports and generated artifacts are confined to ignored build outputs. Fixed checks exit 0. These are planner/input composition contracts, not native physics or full-campaign acceptance.
