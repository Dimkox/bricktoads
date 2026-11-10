# Mounted Dragon QA regression

Run these commands from the repository root with Python 3 and the Luau CLI available. The paths below use this workspace's ignored local executables; substitute your installed executables on a clean checkout.

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-mounted-dismount/prepare_mounted_bridge_probe.py
.tools/luau-0.745/luau.exe build/test_mounted_bridge_baseline.luau
.tools/luau-0.745/luau.exe build/test_mounted_bridge.luau
.tools/luau-0.745/luau.exe build/test_mounted_bridge_session.luau
.tools/luau-0.745/luau-compile.exe --null tools/qa/full_campaign_bridge.server.luau build/mounted_bridge_foot.lua build/mounted_bridge_baseline_foot.lua build/test_mounted_bridge.luau build/test_mounted_bridge_baseline.luau build/test_mounted_bridge_session.luau
```

The baseline command must exit **1**, failing the first assertion about moving the observed mounted actor inward. The current six-case probe and Session contract must each exit **0**. Compilation must exit **0**. A shell should continue after the expected baseline failure.

The generator writes only five named files under the ignored `build/` directory. It extracts the current bridge's actual `foot` function and the baseline from Git commit `df98106`, consumes the adjacent versioned probe input, and reuses the canonical fixture from `tests/gameplay/DragonFlight.spec.lua`. Git must contain `df98106`; fetch that commit if using a shallow checkout. No pre-existing build scripts or generated test files are required.

The six-case probe uses `CampaignDefinition.build(1,303307263)` and the recorded native pose. It checks inward movement, supported Jump, Captured neutrality, no repeated dismount, an unsupported gap, and an excessive height. The Session contract uses the existing prepared canonical heavy-hit mount fixture, then sends the bridge's ordinary Move and Jump through the real Session API, checking unchanged identity/resources and one normal dismount event.

These checks do not simulate native landing physics or prove later combat/course completion. Unsupported or high mounted actors remain neutral. The native read extract records attempt13 observations; its disconnected terminal session was never rescued or counted as Won/Lost. No timeout cause was established. Historical receipts are retained in `validation.json`; `reproduction-verification.json` records regeneration using these versioned files.
