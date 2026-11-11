# Remaining course prop presentation

The authorized continuation replaces the 28 `ExistingPrimitive` course kinds with source-informed, original 3D meshes. The source remains the pinned Battletoads USA NES disassembly `f1a43b69577246850d136473700a333b3cdfe93f`. Decoded evidence and authored interpretation are recorded separately; background media and system indicators must not be assigned invented sprite identities.

## Scope

AirMine, BoardingPad, Bomb, Buzzball, ElectricTrap, Fan, Gas, Gear, IceBlock, Icicle, Lift, Log, Mine, MovingIcePlatform, Ramp, Rocket, RocketLauncher, Rope, RotatingSpike, Snowball, Spike, Spring, Telegraph, Tower, TowerPlatform, Warning, Water and Whirlpool.

## Design

A separate `CoursePropAppearance` owns cosmetic models fitted to the existing `CampaignWorld` parts. Flat imported templates live in `ServerStorage.BrickToadsCoursePropTemplates`; strict packaging requires every kind, the frozen GLB hash, actual uploaded mesh resources and typed fit/motion metadata. Existing vehicle and character contracts stay independent.

Every original part remains the authoritative physics/support object. Its identity, dimensions, transform, flags, SurfaceId and floor-array membership are preserved. Meshes are anchored, noncollidable and nonqueryable. The client hides a fallback only after its corresponding resources load successfully, and restores owned visibility during failure, replacement and removal.

Normal props use their authored envelope. Repeated hazards in long volumes use bounded tiling instead of an elongated orb. Tower maps the authored vertical axis to the existing cylinder axis; Rope follows the actual endpoint-derived local Z axis. Existing alpha and active/broken/defused state remain authoritative. Cosmetic rotation/pulse uses simulation time without changing gameplay timing or adding hitboxes, route assistance, damage or progress.

The mechanical Fan is an explicit presentation exception: `Updraft` alpha .8 described the former translucent airflow volume. Its housing/rotor use the template's visible alpha; a broken alpha1 still hides the entire model. The original airflow part, its alpha and gameplay behavior stay unchanged.

## Acceptance

Run meaningful lifecycle and resource-boundary tests before integration; inspect source and generated contact sheets. Import through Studio MCP and retain real resource receipts. In the single existing Studio window, run a private native fixture covering all 28 kinds and all 13 actual definitions, including transforms, axes, alpha states, movement, ownership and cleanup. Check real client loading and animation separately from the prepared fixture. Run the production campaign with normal inputs and the already-authorized Studio God Mode when needed for integration evidence. Do not describe that as finite-life or multiplayer acceptance.

Preserve the user's dirty starter place and unrelated concept art. Push explicit owned changes, verify CI on the resulting head and update Jira with exact evidence and remaining broader acceptance limits.
