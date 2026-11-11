# Source-informed solid course props

This pack supplies all28 remaining `CourseKind` appearances: AirMine,
BoardingPad, Bomb, Buzzball, ElectricTrap, Fan, Gas, Gear, IceBlock, Icicle,
Lift, Log, Mine, MovingIcePlatform, Ramp, Rocket, RocketLauncher, Rope,
RotatingSpike, Snowball, Spike, Spring, Telegraph, Tower, TowerPlatform,
Warning, Water and Whirlpool.

These are original closed3D adaptations of the pinned **Battletoads USA NES
(1991)** source at `f1a43b69577246850d136473700a333b3cdfe93f`. They are not
claims that the game possessed these exact3D surfaces. The source supplies
identities, visible contour cues and representative palettes; thickness,
unseen rear surfaces, cylindrical masonry wrap, mechanical connections,
runtime support proportions and rest pivots are authored.

`source/source-catalog.json` distinguishes 21 exact object/metasprite kinds,
Rope's procedural tile components, Tower/Water background adaptations,
the invisible source launcher adaptation and the three unproved/system
marker kinds. The catalog includes source lines, URLs, decoded reference
frames, palette context and limits. No ROM is needed. No source sprite
image appears in a GLB: its only embedded image is an original constant-cell
palette atlas. Nearest-source RGB mapping expresses the authored material
roles using the proved representative palette; source cycling and alternate
palette states remain research records, rather than reproduced animations.

The source catalog SHA256 is
`171df6ec3eb594b43e7c9fd6879f2c0488fe28afa86c0c3f65f9325854f4aab7`.

## Frozen import

`canonical-course-props.glb` is **991060bytes**, SHA256
`a5fc292cb0a58f82aee5b6d9bb16e3cfd3636ef3779ba99b424a661db8590157`.
It contains28 kinds,98 flat named meshes and39210 triangles. Each kind uses
2–5 MeshParts; the largest individual part has3104 triangles. Tower has7200
triangles across4 parts. Every component has finite positions, unit normals,
valid indices, nonzero triangles, paired edge winding, a closed two-manifold
surface and positive signed volume. Components may intentionally overlap
within a part; the geometry is not a Boolean union.

`canonical-course-props-pack.json` is the reconstruction contract. It contains
the exact imported `Kind__Part` names, roles, global bounds, centres, sizes,
authored rotation pivots, base transparency and optional cosmetic motion.
All model envelopes are centred on local0; `referenceCenterStuds` is0 and
`referenceSize` is the complete envelope. Every GLB node is a scene root.
There are no skeletons, joints, attachments or gameplay actions.

The fitting enum is `Stretch`, `TileZ`, `Tower` or `Rope`. Long mine/bomb/spike
and log volumes use bounded repeated templates. Each tile retains a compact
solid silhouette. Tower's authored Y axis maps to collider local X; Rope's
length is local Z. Other assets are Y-up and face -Z. All rest pivots translate
with the centred envelope. Gear/Buzzball spin around Z, the radial spike star
spins around Y and only the fan's rotor spins. Whirlpool's Spiral alone has
authored cosmetic SpinY at speed1.2 around its unchanged global rest pivot
`[0,0.11683073718728623,0]`; this is the central Y axis, not the asymmetric
spiral mesh's bounding-box centre. This rotation rate is authored rather than
an assertion of NES frame duration. Water's wave ribbons remain static.
Gas lobes have baseTransparency
0.30; other parts start opaque. Live inactive/broken alpha stays external.

When reconstructing native imports, preserve actual MeshId, TextureID,
SurfaceAppearance and the raw imported MeshSize independently of the desired
Size. The established native importer Y180 conversion must be applied as in
the vehicle protocol. This source pack does not fabricate Roblox IDs or
claim native import completion; native receipts and Studio review belong to
the integrating workflow.

The existing physical volumes, damage, triggers, timing, movement and level
layout remain external. MeshParts are cosmetic and must be anchored,
noncollidable, nontouchable, nonqueryable and massless.

## Inspection and rebuilding

`course-props-contact-sheet.png` and per-kind `turntable.png` / `oblique.png`
are elevated software previews of the generated geometry, not Studio captures.
They were inspected to verify the green bundled Bomb, red spiral Buzzball,
cyan semicircular ElectricTrap, actual gear teeth/hub, distinct rocket and
launcher, twisted Rope, pointed ice/prongs, log end rings, spring coil,
purple staggered tower masonry and bounded fluid/marker ribbons.

`manifest.json` records every per-kind hash, bytes, bounds and geometry count.
`validation.json` records geometry checks. `khronos-validation.json` records
the independent official Khronos validator result: all29 GLBs have zero
errors and zero warnings. Its remaining information messages concern two
48x48 non-power-of-two palette atlases; the sampler uses clamp-to-edge and no
mipmaps, so these textures remain valid. Two consecutive
release builds produced the identical frozen combined hash.

`build_course_props.py` builds the code-native volumes and UV atlas, while
`render_course_props.py` renders them with a software depth buffer. It imports
the existing closed-volume helpers from `assets/characters/canonical-cast`;
it does not modify those assets. Use a Python environment with NumPy/Pillow.
Rebuilding after import requires coordinating a new freeze and native receipt.

For independent validation, use the cached official package:

```text
node assets/props/canonical-course/validate_course_props.cjs build/hero_mesh_validator/package
```

The standalone per-kind GLBs, rig metadata and atlas are retained for audit
and reuse. Imported native templates must remain flat, even though the
authoring helper calls its descriptive per-kind metadata a `rig`.
