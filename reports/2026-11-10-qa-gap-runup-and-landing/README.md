# QA gap run-up and landing-side hold

Attempt16 was a genuine single-window Studio Play run, seed338231076, run73937d7b-557f-4b5f-b78c-52545a2e833b. It naturally ended Lost1. These changes affect the disposable QA navigator only; production remains source7c03. No native success after these changes is claimed here.

Two recorded input-selection errors are reproduced with the actual Nav function and the actual bridge `foot` caller:

1. Aqueduct supports are X4..48 and53..124. AtX55.302/Y3 the hero was walking backward at about16stud/s. The bridge had not yet observed qualified running, but Nav kept aiming towardX53.7, only.7stud from the edge. The held backward movement crossed into the gap before the running qualification/Jump could occur. The late recovery Jump was requested after the body was below the takeoff floor.
2. Both final bodies passed the Cliffs landing targetX266 onto/above a Dragon body. AtX267.798/Y5.897 andX267.951/Y9.328, strict authored-floor landing atY5 was not established. The old fixed targetX266 therefore reversed the hero across the landing edgeX262 while its flight observation window remained active. The retained trace and source contain no later accepted damaging hit needed to explain these two falls.

The navigator now stages an unqualified, standing-height near-edge body eight studs inward on the same support, retains that ordinary run-up until reached, and then resumes the existing approach. It never infers permission to Jump: the caller must still report actual running qualification. A changed support, crossing direction or destination cancels obsolete staging.

Once a flight has passed its original target and the body is inside the destination footprint's two-stud inset and above its landing band, its X target holds at the observed X. This prevents reversal toward the gap. It does not declare a high body landed, extend the two-second window, change actor position/velocity, pause AI or change resources. Captured/linked handling remains in the bridge.

Validation: all88 navigation checks pass, including the prior72 checks, real/mirrored run-up and high-landing cases, nonstanding/descending/goal-change guards, unsupported/below-floor guards and the unchanged timeout. The composed actual-foot probe changes three expected failures to three passes with deeply frozen context data. The baseline is immutable commit e53be90e04dc83eef7354e1b29825d71fd1080cd, NavSHA864b09976d0c926fb20132744c0ddff6dd6afcff572b34f470f46fdcd6a33d33. Candidate NavSHA is recorded in source-receipt.json and validation.json.

Reproduce from the repository root:

```text
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-gap-runup-and-landing/prepare_probe.py
.tools/luau-0.745/luau.exe build/gap_review_base.luau
.tools/luau-0.745/luau.exe build/gap_review_current.luau
.tools/luau-0.745/luau.exe tests/run_route_driver_navigation.luau
```

The baseline intentionally exits1; current and the88-check suite exit0. The Python extractor creates only named ignored build outputs and reads versioned sources. It does not launch or control Studio. These are planner/caller contracts with the observed native poses, not an engine physics replay or a claim of general network-delay tolerance. The next ordinary native campaign must establish the actual outcome.
