# Ordinary Walker strikes — 2026-11-08

The ordinary Walker now has its own light strike and heavy launch instead of the generic Dash. NPCs begin attacks farther away and step back from a point-blank hero while checking support at the edge. Human Walkers retain manual movement and the same F primary. Both attacks have separate original leg/hip windup/recovery poses. Combat defeat still creates the same one leg-club, which the hero can pick up.

## Source and adaptation

[Pinned source note](../../research/2026-11-08-walker-strikes-source.md): object_tall_walker chooses3C when selected hero raw Life low nibble>=4 (E2param0x40→base0→hero18/raw4/light recovery), otherwise3A (E2param0x82→base2→hero20/raw16/heavy). Neither is Dash22 or low-Life finisher21/raw255. The source inner horizontal band turns away and continues gait; a harmless frozen close-range zone would miss that behaviour.

Roblox adaptation: NPC attack band2.5–6.5studs; point-blank retreat speed7studs/s shares the ordinary three-ray support guard. Effect reach7.5,width3.25,height4studs. Light windup/cooldown/recovery0.40/1.0/0.20s, reaction28/60s; heavy0.65/1.6/0.35s, reaction0.75s. Distances, times, impulses, three-dimensional range and simple backstep are calibration, not source frame/axis/gait parity. No invented grounded-target condition is added: actual hit geometry checks height later.

The server freezes action and a cloned tuning record at acceptance, then hits the actual first successful geometrical victim at effect time. A prior target's recovery/healing or another actual victim does not rewrite it. Dying/heavy-reacting targets are excluded from the standing choice; actual light recover==true is eligible. Client schema remains Punch/Dash without target/damage/position fields. NPC3HP stays provisional: WalkerLight/Heavy do1/2HP via explicit base profiles0/2, separate from source raw2/16. An unknown NPC raw Life uses Light rather than mistaking3HP for raw3. Existing Pig/other species and legacy profile paths are retained.

## Actual Studio acceptance

[Checkpoints and complete fixed preparation hook](engine-checkpoints.json). Studio0.746.0.7461269; private place117412694427208/universe10775039796. Valid run `d4782eb9-2b8b-4fe8-8d69-583fa0686a5b`: two actual clients, one hero and one human Walker.

| Scenario | Actual result |
|---|---|
| Human F at distance7 | The player scrolled to and claimed existing Walker-3. Real F selected WalkerLight and hit47→43/profile18 beyond bare Punch reach; normal recovery restored47 |
| Actual walk-away miss | Real Walker F began a light windup; actual hero A moved-65→-75.636 before the effect. No new Hit or health loss occurred; windup/recovery expired |
| Heavy selection after healing | One prepared existing Session PigRush made47→31; actual hero F caught a real fly31→39. Actual NPC Pig jab made39→35. The human Walker's real F selected Heavy at35, light recovery restored39 during its windup, and the fixed profile20 hit made39→31 |
| NPC start reach | Original NPC Walker-6 at6.4studs began its own Light, hit31→27/profile18, then light recovery restored31 |
| Point-blank NPC retreat | Unanchored Walker moved away from hero178:179.5→182.436, then stopped; a fresh Running-state repetition moved179.5→180.637 past the inner band |
| Unsafe side edge | Hero atz24.5, unanchored Walker atz26 near the Courtyard edge: MoveDirection and velocity stayed0, Walker stayedz26 and alive with3HP |
| Combat death and club | Real hero R/F changed anchored isolation target Walker3HP→1→0, defeated that same existing body and emitted exactly one ground club. Actual D/F approached and equipped that item; hero kept raw31, actor/attempt1 and3 respawns |
| Human body/role | Human Walker-3 remained alive with the same actorId, owner,3HP and attempt1 throughout the valid run; no role respawn or replacement |

Both attack phases and finite return to idle were recorded on the actual models. A client screen capture confirmed the equipped original club, readable HUD and contextual primary. Console contained only the normal playable-ready message. Test children ended, the temporary hook was removed,23 production sources matched the repository pack and normal Studio start menu was restored.

Preparation repositions original bodies, pauses/anchors other NPCs, selects zones2/3 to expose the source actors/flies, and uses one existing Session hit for the healing precondition. Old actors persist during that QA jump; it is not natural progression/population evidence. NPC range/death cases are anchored isolation; retreat/edge cases are unanchored. The hero stays unanchored with ordinary impulses. No direct HP or respawn writes occur.

The initial preflight clicked a clipped third offer without scrolling; its later unclaimed NPC hit is excluded from human-primary proof. The valid run first scrolled CanvasPosition30 and confirmed the human owner. Initial retreat samples retained FallingDown from long QA anchoring; only movement after normal recovery and the fresh Running repetition establish physical retreat. Inspection occurred after stopping, so no measured7studs/s claim is made.

## Verification and limits

[native-validation.txt](native-validation.txt): all23 fresh commands exit0. Core46; Combat1054 assertions/Session42; registry18; Director30/Controller37/camera1; queue20; groups11; guardian13+3; route10; flies15; carry24; clubs23; Pig15; Walker16; gateway14; world20; Python17. Compiled64 source/test files plus2 tools. Main/stand/test places build and both deterministic checks pass. Independent source/code review found no actionable P1/P2.

Playable342918bytes, SHA256 `275b4fab2758a107f0e1769f9c66f5859c78a99ffc56c6532ee4be70796a89bf`. User-modified starter remains `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` outside this change. Work continues from user-merged main d474ca0 in codex/walker-strikes.

Full unprepared combat progression, exact source gait/health/retreat/physical hop, a separate NPC-heavy engine case, physical phone/tablet acceptance and same-account reconnect remain open. Native shield/friendly-fire/takeover/offline/interruption/drop boundaries are not presented as additional engine scenarios. Earlier reports keep their own limits.

## Reproducible next engine check: NPC heavy

The follow-up adds `tests/gameplay/WalkerHeavyStudioAcceptance.server.luau` and a separate builder. No production source or normal playable place is changed. This is preparation, **Studio not run** in this continuation.

1. Run `python3 tools/build_walker_acceptance.py` from the repository root, or download the `WalkerHeavyAcceptance-<commit>` artifact from the PR's BrickToads checks. The output is `build/WalkerHeavyAcceptance.rbxlx`.
2. Open that separate place in Roblox Studio and use **Run** (F8). The main server and client entrypoints are disabled in this QA package; the fixture runs automatically on the Studio server. Publishing the fixture is unnecessary.
3. Find `ServerStorage/WalkerHeavyAcceptance_<guid>/Result` and copy its complete JSON value. The folder's `Status` becomes `pass` or `fail`; Output also contains `[BT-WALKER-ACCEPTANCE]`. Retain failures as well as passes. A fixture timeout is a failure, not a skipped check.
4. Record the tested git commit and downloaded place SHA256 alongside that JSON. Its embedded source hashes identify the built bytes, assuming no scripts were edited after import. A source edit in Studio requires rebuilding; the receipt is not a runtime attestation of edited scripts.

The fixture uses real `GameWorld`, `Session`, `LevelDirector`, combat/configuration and Heartbeat/physics. It isolates the existing first-zone Walker, anchors that attacker, places an unanchored hero six studs away and explicitly seeds raw Life35 in both lifecycle/combat state. No direct strike or hit call is made: AI selection, effect-time world geometry and engine response must produce the result. Expected evidence is profile20 and35→31, heavy reaction and upward physical response, one hit, finite return to idle, no light recovery/healing and unchanged actor/attempt/three respawns. Actual hip `Motor6D.C0` angles must change during windup and all four pose motors settle within0.02radians/0.01stud of their original frames. After recovery a later physics frame must observe the same living hero model/root grounded in Running/RunningNoPhysics/Landed, not merely a cleared PlatformStand property. These tolerances are QA measurements, not new game rules. The same NPC remains alive/unowned with3HP. Positioning and health seeding are fixture preparation, not natural-play proof.

The package disables all ordinary Script/LocalScript entrypoints and adds only its private acceptance script. Normal `tools/build_bricktoads_place.py` does not include it. Four native Python packaging tests verify the source boundary, deterministic identity, source-change sensitivity and failure on a missing runner. A fifth test (`python3 tools/test_walker_acceptance.py --luau <CLI>`) executes the actual script's early return for all three environments outside a Studio server and rejects any later service access. Luau compilation verifies syntax; these checks do not execute engine APIs. Full unprepared combat, real devices and reconnect still require their own runs.

[Preparation validation](acceptance-package-validation.json):26 project commands passed,67 Luau files compiled; final targeted packaging/guard, runner compilation, QA build and normal playable consistency checks passed after review. The independent reviewer reran all5 packaging/guard tests and compilation, found no remaining P1/P2 and approved this as acceptance preparation. Engine import/execution, impulse, motor tolerances and physical recovery timing were explicitly not judged. QA package357212bytes, SHA256 `b6304f45b6165dc2c3ced581b765e1a664b7092827c5790dca82319b26779104`; normal playable remains342918bytes/SHA256275b4fab2758a107f0e1769f9c66f5859c78a99ffc56c6532ee4be70796a89bf.
