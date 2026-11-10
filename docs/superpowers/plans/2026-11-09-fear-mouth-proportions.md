# Fear Mouth Proportions Correction

**Goal:** Match the owner's attached original-game reference with a dramatically dropped, elongated jaw instead of a mildly enlarged head.

**Reference:** C:/Temp/codex-clipboard-97d370f2-282e-4c65-9d04-fb2aa60447cd.png. The mouth reaches almost to the feet while the eyes/skull remain near ordinary head height.

**Approach:** Author a new four-mesh hero-fear-wide-mouth.glb, preserving all prior GLBs. Replace only the active Green/P2 fear resource manifest after validation/import. Existing fear32/33 pose/counter/visibility and physical rig stay unchanged. Use a real forward-projecting cavity and thin jaw frame, not a flat black mask over the torso.

- [x] Freeze new Before/After shapes, with about4.7studs of vertical gape; jaw nearneckY−4.25, eyes near+1.8. Record measured mouth/cavity bounds and inferred3D interpretation.
- [x] Validate all four meshes and prior hashes; upload through the already-approved asset folder and normalize actual neck origins/rotations.
- [x] Update the active fear manifest, rebuild and reopen. Inspect both heroes in real source32/33 poses, including floor clearance, visible opening, return and interruption.
- [x] Run required checks/review and update current docs/evidence.

Delivery: push the reviewed correction and verify remote CI/Jira after the commit; the Guardian checkpoint is already pushed as94d3502.

Constraints: do not change the dirty user starter file, any previous GLB, gameplay controls, collision, health/resources, source intro timing or camera. The source bodies/complete3D projection remain authored adaptation.
