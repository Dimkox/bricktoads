# Canonical course vehicle studies

Four textured segmented 3D vehicles replace abstract transport rectangles. The frozen combined import is `canonical-course-vehicles.glb`; its SHA256 is in `canonical-course-vehicles-pack.json`. The pack has 36 uniquely named `Kind__Segment` meshes, embedded nearest-filter palette textures, and no source sprite textures.

These are source-informed authored 3D studies, not recovered original 3D models and not pixel-perfect reproductions. Depth, rear surfaces, handlebars' physical thickness, internal connectors and neutral pivots are authored. Runtime colliders, physics and campaign behavior remain external.

## Pinned evidence

The original reference is [feos-tas/DisAssemble, pinned Battletoads source](https://github.com/feos-tas/DisAssemble/tree/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads). No ROM is fetched or assembled.

`extract_vehicle_references.py` reuses the existing researched CHR decoder and exact source metasprite configurations. `vehicle-source-catalog.json` records table parts, loaded tile recipes, palette context, source file hashes and unresolved states. `vehicle-source-contact-sheet.png` is the decoded source reference; `references/` contains the individual transparent reference frames.

Source `main.asm:9148-9208`, `object_bike` / `bike_frame_id`, chooses object frame `2A` in Turbo Tunnel, `D2` in Surf City, `74` in Clinger Winger, and `8B` otherwise. The Clinger rotation table `frames_koleso` is at `main.asm:8955`. Representative authored type18 spawn palettes include source type19 writes from the same trigger group. RGB is an illustrative 2C02 conversion; recurring Surf/Clinger palette loops and exact interpreter scheduling are not reproduced.

| Kind | Source cues retained | Triangles | Meshes | Deck length / width |
| --- | --- | ---: | ---: | --- |
| Speeder | Cyan/teal low hover-scooter, forward cowling, black rider recess, swept raised rear shoulders, raised handles; no invented road wheels | 3,584 | 10 | 5.6 / 2.4 |
| Surfboard | Pale yellow/olive pointed board, broad white top, interrupted yellow centre seam, divided rear crest | 792 | 8 | 5.6 / 2.1 |
| Jet | Red/pink aircraft, pointed nose, swept wings, black cockpit recess, tall fin and side vents | 2,876 | 12 | 6.2 / 4.6 |
| ClingerVehicle | Red/pink single circular wheel and undulating handlebars from upright source frame74 | 4,648 | 6 | 2.6 / 2.0 |

`Surfboard` uses source objectD2 and the source Surf bank. `Jet` object8B decodes from the Turbo Tunnel object graphics: Volkmire's separately named graphics recipe writes background pattern data at `$1000`; it does not imply a new sprite-bank shape. Clinger frame74 is the upright rest choice; subsequent table entries include different orientation silhouettes and partial components, not an invented frame-perfect mechanical animation.

## Import and reconstruction contract

The combined GLB keeps all four hierarchies at their own authored origins, without layout offsets. Scene units are metres at `0.28 metres/stud`. Geometry is Y-up, forward **-Z**, deck origin **Y=0** with XZ centred. The main hull stays below the deck; raised cowling, tail fin and handlebars are intentional ornaments away from the rider centre. The runtime rotates Y=-90 degrees to face +X.

Import all 36 meshes and match names `Kind__Segment`. Preserve the actual imported MeshId and texture resources. Rebuild a **flat** Model per kind under `ServerStorage.BrickToadsCourseTemplates`. The pack JSON gives each part's authoring `globalPivotStuds`, `globalBoundsStuds`, `sizeStuds` and `centerStuds`. The observed Roblox native importer recentres individual MeshParts at their own bounding centres and converts facing by 180 degrees around Y; set `Size` to `sizeStuds` and `CFrame` to `CFrame.new(centerStuds) * CFrame.Angles(0, math.pi, 0)` when reconstructing the flat template. The native `MeshSize` / `InitialSize` remains the imported source extent (approximately 0.28 of the authored stud extent) and is preserved separately from resized `Size`.

Approved native model asset `89107256831014` produced actual uploaded MeshId and TextureID values, with empty `surfaceAppearances` arrays. `roblox-course-vehicles.json` records those resources and reconstructed rest frames. The package preserves TextureID; it does not invent SurfaceAppearance instances. If a future actual import provides SurfaceAppearance, the strict packager permits a single leaf appearance with uploaded ColorMap instead. An untextured mesh is rejected.

Each template has StringValues `AppearanceProfile=CanonicalCourseVehicle`, `CourseKind=<exact kind>`, `SourcePin=f1a43b69577246850d136473700a333b3cdfe93f`, and NumberValues `DeckTop=0`, `DeckLength`, `DeckWidth` from the table above. MeshParts are anchored, massless, with CanCollide, CanTouch and CanQuery false. No joints are required for whole-vehicle movement.

Runtime fit uses `min(collider.Size.X / DeckLength, collider.Size.Z / DeckWidth)` uniformly. It derives the vertical lift from all fitted mesh corners so the hull and wheel clear the original route foot plane by0.03stud; Surf also keeps its actual Deck surface0.1stud above the covering water volume. The actual named Deck/RiderDeck top is published separately from the authored origin. Only the mounted hero's cosmetic root is aligned to that surface using its posed foot bounds. Collider height never flattens the artwork, and physical actor/object transforms, hit volumes and behavior remain unchanged. This generator does not write runtime code, upload network assets, or operate Studio.

## Rebuild and validation

Run `extract_vehicle_references.py` then `build_course_vehicles.py` with Python 3 plus numpy and Pillow. The bundled app Python runtime discovered by `load_workspace_dependencies` contains both renderer dependencies; the embedded `.tools/python-3.13.9/python.exe` can run the reference decoder but does not include those packages.

The generator reuses the existing code-native mesh primitives, palette-atlas GLB writer and depth-buffer renderer from `assets/characters/canonical-cast/` without modifying any cast asset. Each closed component is checked for finite vertices, positive triangle area, valid indices, two faces per edge, paired directed edges and unit normals; parent hierarchies are acyclic. Every vehicle is below 12,000 triangles and uses only colours present in its decoded source reference. The main Body upper bound is checked at or below deck Y0. These geometry checks are in `validation.json`.

`vehicle-model-contact-sheet.png` and per-kind `turntable.png` are software previews, not Studio screenshots. The board's layered top surfaces have separated elevations to avoid coplanar flicker. Native import is approved and reconstructed in the uploaded-resource receipt; in-game visual review remains a separate check.

For independent glTF validation, run `validate_course_vehicles.cjs` with the cached Khronos package directory `build/hero_mesh_validator/package`. It writes `khronos-validation.json` for the combined file and all four individual GLBs. No new package download is needed.

`tools/package_course_assets.py` makes these assets mandatory in the default playable build. It verifies the frozen GLB hash and bytes, derives bounds from the GLB itself, requires the exact four kinds and 36 named segments, preserves native mesh extent/texture content, and rejects unknown node fields, attachments, invalid geometry and missing assets. Run `tools/test_course_asset_packaging.py` for the focused boundary tests and `tools/test_bricktoads_place.py` for full builder regressions.
