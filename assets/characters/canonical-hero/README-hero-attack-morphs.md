# Source-derived oversized attack limbs

`hero-attack-morphs.glb` contains four independent cosmetic meshes: `GreenPowerFist`, `GreenBigBoot`, `PlayerTwoPowerFist` and `PlayerTwoBigBoot`. These are newly generated closed 3D volumes from the original enlarged limb silhouettes, not scaled neutral avatar hands or feet. No Humanoid, physics, damage or gameplay values are included.

## Verified source and authored interpretation

The source is the pinned Battletoads NES disassembly `feos-tas/DisAssemble@f1a43b69577246850d136473700a333b3cdfe93f`, decoded by the existing source-frame pipeline. Inputs and their source graphics labels/addresses are recorded in `hero-attack-morphs-rig.json`.

- **PowerFist:** graphics `1C`, semantic crop X22..35/Y−19..−4 inclusive, 144 opaque pixels, actual opaque bounds 14×14 (Y ends at −6). Inferred wrist is source pixel `(22,−9)`. The ordinary `19` jab fist is approximately 8×7 in the reviewer's semantic crop, so this enlarged contour is deliberately different in shape and size.
- **BigBoot:** graphics `1E`, crop X8..30/Y−36..−15; preserve all upper pixels through Y−24, and retain X≥12 below that to exclude an overlapping body fragment. This leaves 344 opaque pixels and a 22×22 opaque bound. Inferred ankle is `(13,−17)`. The small orange supporting foot in the full source frame is outside this crop and is not mistaken for the enlarged boot colour.
- Source mask corners receive one rounding pass; depth is a symmetric, smoothly inflated volume: fist thickness 1.36 studs, boot thickness 1.06 studs. A 0.0001-stud numerical weld removes marching-surface slivers. The final meshes retain **100% pixel-centre silhouette IoU** against both selected source masks when viewed in their source plane.
- Source **+X maps to local −Y**, source **+Y maps to local +Z**, and inferred depth spans local ±X. This rest orientation is meant to be rotated by the actual wrist/ankle animation. A side profile at the active boot pose is the appropriate source comparison; a standalone oblique boot may read like a broad amphibian paw because the original image does not specify its depth anatomy.
- Exact joint centres, depth, smooth surface interpolation, right-limb assignment and attachment orientation are authored 3D adaptations. NES metasprites contain no skeletal wrist or ankle transforms. Source-derived silhouette measurements do not certify the invented depth as original-game anatomy.

## Timing and appearance

`PowerFist` corresponds to animation `0E`, graphics `1C`, display advances 11..31. `BigBoot` corresponds to animation `14`, graphics `1E`, advances 12..36. Its preceding `1F` advances 0..11 are a **distinct windup**; the extended `1E` contour must not be displayed during that windup. The current narrow-fist uppercut (`06`/`22`) is not the separate oversized `1A` uppercut (`10`/`74`), which this package does not implement.

Green colours follow the owner's grass/forest-green brawler adaptation while retaining source tone regions. Player Two uses the verified source codes 0F/17/27 and the same illustrative RGB table: `(18,19,20)`, `(155,83,0)`, `(250,160,66)`. It is not an invented yellow skin. Geometry is identical between both colour variants for each morph type.

All colour is baked into **one embedded 2048×2048 sRGB albedo**, shared by all four meshes. Every node has one primitive and uses one shared rough, nonmetallic material. There is **no `COLOR_0`, emissive image, emissive factor or emissive texture**; this avoids the observed Studio SurfaceAppearance colour and emissive-import failures. No external texture file is required.

## Attachment and import layout

Local mesh coordinates use the wrist/ankle attachment as origin `(0,0,0)`, with +Y up and −Z forward. Metadata uses studs; GLB vertex positions and translations use metres at **0.28 metres per stud**. Each mesh's local bounds, centre and size are recorded explicitly.

The four independent GLB nodes have import-only X offsets: Green fist −6, Green boot −2, Player Two fist +2 and Player Two boot +6 studs. Corresponding offsets appear in each part record. They let the importer determine the model's right direction using the two identical fist centroids. **Remove these layout offsets before runtime wrist/ankle binding.** Do not align a mesh's bounding-box centre directly to the joint: retain the local origin-to-bounds offset.

The runtime template contract is one Model per morph under `ServerStorage.BrickToadsCharacterMorphs`, containing one MeshPart named `Morph` and `MorphOriginRigAttachment`, with `Morph.CFrame * attachment.CFrame` equal to wrist-space identity after normalization. AppearanceProfile is `CanonicalNESHeroMorph`, MorphKind is `PowerFist` or `BigBoot`, HeroTemplate is `Mr. Green` or `Mr. Yellow`, and AppearanceScale is 1. Root integration creates these runtime templates; this authoring task makes no Studio changes.

## Validation

Each fist has 11,390 triangles / 34,170 exported UV-split vertices; each boot has 15,028 triangles / 45,084 vertices. The package totals 52,836 triangles and is approximately 7.37 MB. Authoring shells are closed, orientable and connected. All four nodes remain below 20,000 triangles and 65,536 vertices each. The final official Khronos report records **0 errors and 0 warnings**; `hero-attack-morphs-validation.json` and the rig record contain the frozen hash and counts.

Rebuild with `build_hero_attack_morphs.py`. It writes only this new morph package, metadata and preview, and verifies that every previously existing GLB remains unchanged. `hero-attack-morphs-preview.png` shows Green/P2 fists on the top row and Green/P2 boots below. It is a render of the actual authored mesh, not an image-generation substitute.

Approved private Roblox Model `134209153804955` was imported through the approved folder. `roblox-attack-morphs.json` records the four actual MeshIds, shared baked `TextureID` and positive native MeshSize. This import uses the albedo through MeshPart.TextureID, without SurfaceAppearance. The playable builder preserves MeshSize as InitialSize and validates provenance and attachment origins before packaging.

The freshly reopened playable place passed prepared native World checks for source1C/1E visibility, source1F windup, palette independence, recovery, reaction, club, airborne and dead-state priority, exact nonzero transparency restoration, body replacement and unchanged server ownership/colliders. Static native runtime-pose/FK scenes separately confirmed loaded colours and silhouettes from front and side; these are visual fixtures, not normal-input gameplay. See `../../../reports/2026-11-09-hero-attack-morphs/README.md` for evidence and limits. Physical mobile devices, cold first-attack loading and performance remain unmeasured. Boss-appearance fear forms and the separate `1A` uppercut remain outside this package.
