# Dramatic downward fear mouth

This NEW package answers the user screenshot's almost-to-the-feet jaw drop.
It replaces neither the earlier fear GLB nor any other existing asset.

Frozen file: `hero-fear-wide-mouth.glb`, **8,712,432 bytes**.
SHA-256: `e5dd859b9be454198046580a147f7d202fd5374502f0f860384d1590efa325c1`.
Official Khronos validation: **zero errors, warnings, infos or hints**.

## Geometry change

The old BeforeCut Green chin ended at neck Y −0.200 while its top stretched
up to +2.882. The new chin reaches **−4.243** while the top is **+1.803**:
roughly four more studs downward, with the skull/eyes reduced to their normal
upper level. The lower jaw bends forward to about **Z −2.397** so the gape
projects ahead of the chest.

The nominal cavity is **4.73 studs high**, compared with the old 1.567 BeforeCut
and 1.36 AfterCut cavities before Player Two's former dimension scaling. That
is approximately **3.02× / 3.48×** the old Green opening height. BeforeCut is
narrower and asymmetric, **1.27 studs** nominal cavity width; AfterCut is a
broader frontal scream, **1.65 studs** wide. Both have a long thin colored lip,
a real concave closed interior, and a visible red tongue. This is a sculpted
head/jaw extension, not a freestanding flat black mask.

| Mesh | Triangles | Exported UV vertices | Neck-space minimum Y | Neck-space maximum Y |
| --- | ---: | ---: | ---: | ---: |
| GreenFearBeforeCut | 16,630 | 49,890 | −4.243142 | 1.803085 |
| GreenFearAfterCut | 18,066 | 54,198 | −4.240071 | 1.791375 |
| PlayerTwoFearBeforeCut | 16,208 | 48,624 | −4.243142 | 1.642397 |
| PlayerTwoFearAfterCut | 17,574 | 52,722 | −4.240071 | 1.610024 |

Every mesh is one closed, connected, consistently outward-oriented shell.
All remain below 20,000 triangles and 65,536 exported vertices. Green keeps
pop-out eyes and raised sunglasses. Player Two keeps the existing orange/ochre
palette and no sunglasses. Both use the same downward jaw height; Player Two's
jaw is not blindly vertically enlarged below the floor.

## Evidence and limits

Source graphics 32/33 and the user's screenshot inform the exaggerated fear
expression: eye/skull height stays near the ordinary head, while the rubber-like
jaw drops almost to the feet. Source32 is narrower/asymmetric; source33 is a
broader frontal expression. The screenshot remains at its original private
local path. Its path and SHA-256 are recorded in the new rig JSON; the image
was not copied into this repository.

The 3D mouth depth, cavity back, eye anatomy, lip thickness, tongue and neck
connection are authored. This is not an exact copy of the source's complete 2D
body or projection. Source references and all seven earlier GLBs, including
Boss Walker, remain unchanged.

## Binding and verification

Units: metadata in Roblox studs, GLB in metres at **0.28 metres/stud**; +Y up,
−Z front. All four meshes use actual existing Head.NeckRigAttachment space,
with the neck at identity. Layout-only X offsets are **−6 / −2 / +2 / +6**.
The rig JSON records exact bounds, centers and the attachment offset from each
bounding-box center. Preserve the native imported orientation and solve:

```text
Morph.CFrame * MorphOriginRigAttachment.CFrame == actual Head.NeckRigAttachment frame
```

Hide only the old cosmetic Head. The body and limbs remain present. Green's
actual rest neck is root Y+1.886075; Player Two's is root Y+1.880000. The new
neutral chin therefore reaches approximately root Y−2.36, above root-space
ground Y−3. Actual source32/33 body and neck rotations require the separate
native runtime check. No collision, damage, movement, camera or Humanoid logic
is supplied by this art package.

The preview is generated from serialized GLB positions, normals and baked-albedo
UV samples. Its four rows show the semantic meshes; columns are front,
three-quarter and full side. All views were inspected. Native attached-body
appearance and final lighting remain root integration work.

There are exactly four mesh nodes, one primitive each, one shared opaque
material and one embedded 4096×4096 baked albedo atlas. `COLOR_0`, emissive and
extra attachment nodes are absent. The atlas stores analytic surface pigments
in padded unique 8×8 triangle cells. Roughness is 0.63, metallic is zero.

Reproduce with the bundled workspace Python (NumPy/Pillow available):

```text
<bundled-python> assets/characters/canonical-hero/build_hero_fear_wide_mouth.py
node assets/characters/canonical-hero/validate_hero_fear_wide_mouth.cjs build/hero_mesh_validator/package
```

`hero-fear-wide-mouth-validation.json` contains structural, topology, float32
geometry and unchanged-earlier-asset checks. `hero-fear-wide-mouth-khronos.json`
contains the official validator report; `hero-fear-wide-mouth-freeze.json`
records hashes of the final reviewed package. The author performed no Studio
upload, Git mutation or existing manifest/builder/test/source edit.
