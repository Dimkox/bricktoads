# Canonical character implementation plan

**Goal:** Recreate all characters from verified original proportions, forms and animation, including attacks and boss appearance.

**Spec:** [owner direction](../specs/2026-11-09-canonical-character-direction.md).

Preserve gameplay resource limits, actor identity, physical collision and server authority. The NES source has two playable slots; the third playable character and 3D depth are explicit adaptations. Source animation event markers do not apply damage. English remains the source UI language.

- [x] Extract pinned source frames, metasprite measurements and animation streams. Initial current-route references and69 stream queries are available; unknown families/bank contexts remain labelled.
- [x] Implement/review pure source-clock sampling, opcode boundaries, Dash continuation, hero/Dragon selectors and Boss Walker intro milestones. Native16 checks and independent source review pass.
- [x] Author a 15-segment organic hero mesh, metre-correct GLB, source palette variants and joint metadata; independently validate glTF structure and preserve existing gameplay rig.
- [x] Import both actual P1/P2 GLBs through the owner-approved MCP folder; verify mesh count, colour, scale, orientation and joints. Prepared native movement/ownership checks and the ordinary menu start pass. These neutral prototypes are superseded visually by the owner's newer muscular green-brawler direction, which remains in progress.
- [ ] Complete source poses and morph forms across every state. Idle/walk/run and seven hero attacks now drive real cosmetic joints, with native engine movement/reaction/replacement/club checks. Morphs, fear, airborne/death/carry/weapon source parity remain incomplete. Owner-directed Green Brawler is imported and bound; reports/2026-11-09-green-brawler records exact acceptance.
- [ ] Recreate Tall Walker articulated rods/feet, Pig, Dragon and first boss components using verified source geometry and renderer behavior.
- [ ] Integrate first boss foot/impacts/fear/camera-cut/post-cut sequence without HP, shield, attempt or respawn resets. Do not turn source state flags into health changes.
- [ ] Extend verified models, state sequences and engine acceptance to every remaining family and boss; do not mark all characters complete after the first hero.
- [ ] Push meaningful verified slices and synchronize Jira with exact acceptance limits. Public full-game release remains pending.
