# Source-informed articulated cast

This package supplies29 cosmetic model hierarchies:22 ordinary runtime families,
five campaign bosses, a reusable Snake segment/head and HealingFly. It does not
replace the existing Guardian, hero, collider rigs, health, physics or timings.

`canonical-cast.glb` is the import pack. Its166 mesh/node names are unique and use
`Family__Segment`. Every family stays at its authored origin; no display-layout
translation is baked into the geometry. `canonical-cast-pack.json` records every
name, individual GLB digest and rig path. Each family directory also contains an
independent GLB, embedded-palette PNG, rig JSON and software turntable. The GLBs
contain no script, Humanoid, collider or gameplay state.

The full contact sheet is `cast-model-contact-sheet.png`. These are software
orthographic previews with a depth buffer and smooth interpolated normals. They
are visual QA evidence of authored geometry, not native Studio render evidence.
Native import, material appearance and runtime articulation remain root-owned
verification tasks.

## Geometry and attachment contract

All rig JSON coordinates are Roblox studs. GLB positions and node translations
are scaled by 0.28 metres per stud. Y is up; the face points toward -Z. `Body` is the
root segment. Each part has a global `pivot`, global/local bounds and a parent.
Vertices are exported relative to that pivot; a node translation is its pivot
minus its parent's pivot. This supports reconstruction after importer scaling.
Every articulated joint has a stable, closed overlapping cap. Each mesh may
contain several intersecting but independently closed anatomical surfaces.

The rods of Walker remain straight and have no invented knee. Queen's long hair
is `Hair`, with no invented crown or superhero cape. Hammerfish uses the actual
round-mouthed source fish, rather than a hammerhead inferred from its name.
RocketRat separates its rider from the `Weapon` vehicle. Snake is a reusable
head/body/tail cosmetic; the source's full nametable body path is not claimed.

The importer discards COLOR_0 for textured meshes, so no GLB uses it. Every GLB
contains a small sRGB palette atlas and baseColorTexture. Each triangle has a
constant UV in a single 16x16 cell. The few mixed-colour Walker profile triangles
are split and assigned their majority colour, preserving positions and normals;
this prevents interpolation through unrelated atlas cells. Atlas texture colours
come from the selected source spawn's palette RAM after actor XOR. Per-family
rigs retain palette codes, caller context, selected spawn, variants count and
raw-slot→effective-slot mappings.

## Provenance and limits

The pinned public source is feos-tas/DisAssemble Battletoads commit
`f1a43b69577246850d136473700a333b3cdfe93f`. References are the decoded bank-correct
`research/canonical-visuals/cast-source-catalog.json` and its per-family sheets.
They supply sprite configurations, frame boxes, source namespaces, loader/CHR
recipes, palette codes, actor palette XOR and selected authored spawn context.
No ROM or sprite image is embedded in the GLBs.

Contours, landmark placement and source colours guide the models. Every depth,
unseen rear surface, rest joint, anatomical sculpt and neutral stance is an
authored 3D adaptation. These are not claimed exact canonical 3D models. Alternate
source palette variants remain catalogued; this package uses one evidenced
representative spawn palette for each family. The full source animation timeline
and shape-changing attack forms are handled separately by runtime presentation.

## Rebuild and verify

Run from the repository root with Python 3.11 or later. Geometry/export require the
standard library. Preview rendering additionally requires NumPy and Pillow.

```powershell
python assets/characters/canonical-cast/build_cast.py
python assets/characters/canonical-cast/pack_cast.py
python -m unittest discover -s tests/canonical_cast_geometry -v
```

Use `--no-preview` for a fast deterministic GLB/metadata rebuild. Use
`--families Pig Dragon` to rebuild a subset. Repack after any GLB change. The
independent tests check every requested family, finite geometry, valid indices,
unit normals, nonzero triangle area, manifold edge closure and winding, parent
cycles, named anatomy, embedded textures, safe UVs, hashes, exact 0.28 scale/pivot
reconstruction and combined-pack equality of arrays/transforms/material links.

The final import pack is 4,431,080 bytes, 175,584 triangles across 166 segments, with
SHA256 `2845f02929ac9a76cbad6f78c84c8b28d2b7c6abf0bca897a8a2859e365050a9`.
The 2 contract tests passed in 5.391 seconds before handoff. See `validation.json`
for the machine-readable verification record.
