# Boss Walker cosmetic reconstruction

`boss-walker.glb` contains exactly four independently attachable meshes:
`GuardianChassis`, `GuardianLeftCannon`, `GuardianRightCannon`, `IntroLeg12`.
This is a source-informed 3D adaptation, with an explicitly authored compact
chassis. The source does not establish a complete robot body or rear anatomy.

The final actual-geometry preview is `boss-walker-preview.png`: battle and intro
each have front, three-quarter and side views. All six panels were inspected.

## Frozen artifact

- SHA-256: `4f1d852e369f83da380dd05b37a5d999886aea036eba220852678ed4a47adc08`
- Bytes: **3,821,508**
- Khronos glTF validation: **0 errors, 0 warnings, 0 infos, 0 hints**.
- Four mesh nodes, one primitive per mesh, one shared opaque material and one
  embedded 4096×4096 baked albedo atlas. No `COLOR_0`, emissive or attachment nodes.
- PBR response is authored painted metal: roughness 0.48, metallic 0.32.
- Every shell is closed and outward oriented. Bolts, plates and housings are
  separately closed shell components that intentionally intersect in each mesh.

| Mesh | Triangles | Exported UV vertices | Bounding-box center, studs | Bounding-box size, studs |
| --- | ---: | ---: | --- | --- |
| GuardianChassis | 6,704 | 20,112 | 0, 1.2095, 0.8375 | 5.998, 8.419, 6.785 |
| GuardianLeftCannon | 7,324 | 21,972 | -3.167, 0.81, -1.2295 | 2.634, 2.72, 6.959 |
| GuardianRightCannon | 7,324 | 21,972 | 3.167, 0.81, -1.2295 | 2.634, 2.72, 6.959 |
| IntroLeg12 | 13,284 | 39,852 | 1.7278125, 11.64, -0.12 | 6.365625, 23.28, 3.12 |

Total: 34,636 triangles. Each mesh is below 20,000 triangles and 65,536 exported
vertices. Six earlier character GLBs remain byte-for-byte unchanged. The frozen
geometry package has now been imported and bound to the runtime as described below.

## Source evidence and reconstruction

Evidence is pinned at source commit
`f1a43b69577246850d136473700a333b3cdfe93f`. See
`research/canonical-visuals/BOSS_WALKER_SOURCE.md` and its linked PNGs/catalog.
The verified source palette indices and bank switch are recorded there. RGB
table values and 3D material response are approximate adaptations.

Graphics **12** is the intro leg, 35×128 visible pixels: long diagonal red
shaft, small toe, large round upper joint and diagonal upper plate. Its alpha
silhouette is retained in the XY plane, with depth and raised mechanical detail
authored. Exact image-boundary mapping is:

```text
studsPerPixel = 23.28 / 128 = 0.181875
x = (pixelBoundaryX - 8) * 0.181875
y = (128 - pixelBoundaryY) * 0.181875
```

The actual bottom is Y=0 and actual top is Y=23.28. The toe-ground origin maps
to image boundary (8,128); the original metasprite anchor maps to
`sourceAnchorStuds = [0,2.1825,0]`. That source anchor is metadata, not a ground
offset. The upper silhouette deliberately leans toward +X. Front is -Z, where
the raised circular joint and shaft runner are visible. The back and all
3.12-stud maximum depth are inferred. No wide boot sole or thick replacement
shin was introduced.

Graphics **10** is the 31×24 red/black camera-relative cannon. Its stepped red
and dark-metal contour informs the two battle guns. Their 3D length, circular
cross section, real open recessed muzzle, rear closure, recoil sleeve, rail,
breech, bolts and scale are authored. Graphics **11** (white reticle) and **C7**
(cracked glass) are camera/HUD effects and are absent from this physical asset.

The complete chassis is authored: segmented red hood, split bolted front
plates, side trunnions and brackets, cooling cassettes, rear engine grille and
short hydraulic supports. It is a compact pod, with no giant battle leg pair.
Full arena camera projection, precise final background composition and runtime
appearance are not established by the component references. The runtime body has
no reactor eye or magical coils; source reticle `11` and cracked-glass `C7` remain
unimplemented camera/HUD effects.

## Imported resources and runtime acceptance

Private Roblox Model **103948186317063** and shared atlas **90154814086213** are
recorded in [boss-walker-roblox.json](boss-walker-roblox.json). Native import
preserves a white MeshPart tint, the shared TextureID and Roblox Metal material
(enum 1088), without SurfaceAppearance children. The serializer writes positive
native MeshSize as InitialSize and retains the actual imported mesh IDs,
rotations and attachment frames. Two strict models are packaged privately under
`ServerStorage.BrickToadsBossTemplates`:

- `BossWalkerGuardian`: exactly the three battle meshes, profile `CanonicalBossWalker`.
- `BossWalkerIntroLeg`: exactly `IntroLeg12`, profile `CanonicalBossWalkerIntroLeg`.

Each model carries AppearanceScale 1 and source/manifest SHA-256 metadata. Battle
parts use GuardianMountRigAttachment; the two cannons also have
MuzzleRigAttachment. IntroLeg12 uses IntroOriginRigAttachment. The builder checks
the exact resource family, GLB hash/containment, visible geometry, root axes,
origins, cannon sides and forward muzzle clearance. Nested/unknown content is
rejected before a resource is cloned into the world.

The active Guardian preassembles three cosmetic motors, two muzzle-flash parts
and two welds over the existing physical rig. Accepted bullet/heavy shots
alternate barrel recoil/flash; blocked melee does not fire or start hurt tint.
Actual health decreases tint saved colors, which are restored afterward. A valid
intro uses one slender mesh and two ripple markers; the earlier 16-part boot
proxy remains a fallback for invalid or missing runtime content. No collision,
health, projectile-origin, control, intro-timing or ownership policy is added.

All 47 validation commands and compilation of 126 Luau files passed. The 9 Guardian
appearance, 16 intro asset, 14 Guardian pattern, 4 Guardian session and 31 builder contracts
passed; independent review's nested-intro-child issue was fixed before final
acceptance. Source fingerprint is
`d6ada582f21045fc2035b5a81bc6ff97ae32be427f8af521df04aaa6c8e03923`;
the 777545-byte playable has SHA-256
`668d4e363410366edaf0ad24265f6f8da7ca90067ffc1cc2925ec46b906114d8`.

[Fresh saved-file Studio evidence](../../../reports/2026-11-09-guardian-visuals/README.md)
confirms the imported intro/battle meshes, two unchanged physical colliders,
single root assembly and manual server ownership. Real GuardianPattern shots and
pickup/throw interactions through finite projectile collision steps produced
Life 47→31→15→0 and Exit; prepared hero HP 37/100, attempt 1, respawns 3, Human owner 999
and another party's unshot Guardian were preserved. Positions, support and time
were prepared, so this is not an ordinary-input full-route playthrough. Native
Edit poses show loaded red textured Metal geometry and leg after asset warmup;
fetches succeeded. Cold loading, physical-device performance, music/sounds,
remaining cast/modes and production readiness remain unverified.

## Root space and native import

Metadata uses Roblox studs; GLB uses metres at **0.28 metres/stud**. Axes are
+Y up and -Z forward. Battle geometry is already in R6 HumanoidRootPart space:
root identity at (0,0,0), bottom Y=-3, standing on the ground at root world Y=3.
Combined battle bounds are 8.968 wide × 8.419 high × 8.939 deep.

Only node translations provide the nonoverlapping import layout: chassis X0,
left cannon X-16, right cannon X+16, intro leg X+35 studs. Subtract those layout
offsets before binding. Do not move a mesh's bounding-box center onto its pivot.
The rig JSON records actual bounds, centers, dimensions, layout translations,
mount points and muzzle points individually.

| Part | Mount point in root space | Muzzle center in root space |
| --- | --- | --- |
| GuardianChassis | 0, 0, 0 | — |
| GuardianLeftCannon | -2.5, 0.7, 0.5 | -3.1, 0.7, -4.6 |
| GuardianRightCannon | 2.5, 0.7, 0.5 | 3.1, 0.7, -4.6 |
| IntroLeg12 | 0, 0, 0, in its separate ground-origin space | — |

The barrels sit 0.6 studs outboard of their mounting pivots. Muzzle marker
orientation uses root axes identity with forward -Z. The muzzle lip opening is
at Z=-4.6, radius 0.67; black rear closure is recessed to Z=-3.66. Front bolts
extend slightly beyond the marker plane. Native import can produce a Y180
mesh frame: preserve it and solve attachment frames against the imported
orientation. The required equations are:

```text
MeshPart.CFrame * GuardianMountRigAttachment.CFrame
    == root.CFrame * CFrame.new(mountPointStuds)
MeshPart.CFrame * MuzzleRigAttachment.CFrame
    == root.CFrame * CFrame.new(muzzlePointStuds)
IntroLeg12.CFrame * IntroOriginRigAttachment.CFrame
    == separate intro ground-origin frame
```

The intro leg is separate from the battle chassis. This package supplies
cosmetics and metadata only; it adds no Humanoid, collision, movement, damage
or camera logic.

## Reproduction and checks

`build_boss_walker.py` reuses the existing geometry and reviewed triangle-atlas
export helpers. Build uses Python plus NumPy/Pillow for software preview only;
the GLB itself has no runtime library dependency. On this machine the bundled
workspace Python provides those preview packages.

```text
<bundled-python> assets/characters/canonical-hero/build_boss_walker.py
node assets/characters/canonical-hero/validate_boss_walker.cjs build/hero_mesh_validator/package
```

`boss-walker-validation.json` checks topology, finite positions, unit normals,
nondegenerate float32 triangles, serialized bounds, exact unit conversion,
material/primitive/node counts and unchanged earlier GLBs. The official
validator report is `boss-walker-khronos.json`. `boss-walker-freeze.json` records
the reviewed file hashes. Rebuilding intentionally replaces only this new
Boss Walker package; earlier assets remain frozen.
