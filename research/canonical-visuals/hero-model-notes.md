# Hero model study

Authoring asset: `assets/characters/canonical-hero/canonical-hero.glb`; rig/pivots/face landmarks: `canonical-hero-rig.json` in that directory. This study follows source anatomy/palette rather than the rejected explorer design. The body and face are smooth mesh surfaces with fifteen controllable segments.

`hero-model-turntable.png`: front / three-quarter / side. `hero-model-joint-bend-check.png`: a noncanonical hinge probe. The probe checks the actual authored hierarchy and overlapping joint-cap coverage; it does not establish source animation fidelity.

Source facts are separately preserved in `hero-idle-proportions.json` and the source frame sheets. Source frame01's24×33pixel bound and NES palette indices are measured; depth, rest joints, anatomical landmarks, six-stud scale and pose are adaptations. Head landmarks were retained for future separately authored source32/33 fear variants. A head-scale toggle cannot stand in for that mouth/eye deformation.

The neutral model is not yet production approved. Import/scale/vertex colours and source-pose comparisons are the next gates; no runtime files were changed by this asset task.
