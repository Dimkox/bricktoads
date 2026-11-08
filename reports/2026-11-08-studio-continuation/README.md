# Fresh-source Studio continuation — 2026-11-08

This continuation reads the new GitHub/Jira work after Walker and incorporates the prepared source-combat/Dragon work from `dadf96f`. Jira BT-65 puts the existing complete level and BT-25→BT-26→BT-61 acceptance before an unchosen persistent reward model. The new rewards/avatar backlog does not establish a selected catalogue, price, publication or commerce launch.

The confirmed results below distinguish native contracts, isolated engine fixtures and attempts at the complete production route. The prepared Walker fixture passed14 checks and the corrected Dragon fixture passed78 checks. There is **no unprepared full-route PASS**. The new keyboard relay, physical phone/tablet and actual same-account reconnect remain **NOT RUN** in this continuation.

## Confirmed corrections

### Stale movement after Dragon links

A hero's previous `Humanoid:Move` command could survive mounting/capture: linked movement ignores the Session timeout stop while the saved physical flags are later restored. The fix clears the saved body's voluntary movement on link and again on unlink **before** restoring locomotion. It does not replay movement, restore health, alter an attempt or touch a replacement body.

The world regression was RED on the previous code and is now GREEN for Mounted/Captured, timeout-style stop while linked, clearing before physical restoration and cleanup against the saved old actor. These are real adapter/API contracts against the test double, not additional Studio transport acceptance.

### Accepted fire direction

A fireball already kept its accepted trajectory, but its impact impulse read the rider's later facing/body. Shot acceptance now stores a cloned trusted `tuning.impulseDirection`. Session and Director forward it to the optional fifth `World:impulse` argument. The physical adapter normalizes its horizontal direction independently of a surviving attacker; ordinary melee retains current-facing behavior. Attribution and the public input schema are unchanged.

RED→GREEN cases include hero/NPC victims and rider turn/replacement/removal. The actual `ApplyImpulse` world contracts verify accepted +X against current −X, absent/replaced attackers, normalization, legacy/malformed fallback and no attacker `CFrame` mutation. Direction forwarding alone is not presented as physical engine proof.

### Main-route jump budget

Main-game `JumpPower` is now50; the independent stand retains42. At default gravity196.2studs/s² and speed16studs/s, the flat ballistic budget grows from about6.85 to8.15studs. The authored5-stud gap plus2.5-stud takeoff lead and0.5-stud landing inset needs8studs. The analytic regression covers all five authored gaps, including their height differences.

This is explicit Roblox calibration. The analytic envelope is a geometry check, not a network/landing simulation or proof that all jumps succeeded in an unprepared run.

### Reverse-gap planner and finite keyboard batches

The temporary acceptance planner now handles both directions across a gap, including the observed hero X≈53.28→Walker X≈45.63 pursuit. Gap crossing takes priority over attacks and cooldown retreat; support observations retain the same underlying part when scene tables are rebuilt. Camera-relative WASD batches release their keys after a finite interval, and unmatched manual input stops the helper. This path uses ordinary client keyboard controls, with no direct `FireServer`, generated input sequence or VirtualInputManager.

Independent review found a missing Space-confirmation deadline: an unobserved queued jump could retain its far-side target indefinitely. The RED→GREEN regression now requires a1.4-second deadline to clear the jump and return a fault at the current position. `applyPlan` then stops the driver, zeros desired movement and clears queued keys. [navigator-verification.txt](navigator-verification.txt) records **25 native checks passed**; the review repeated that command successfully. **The actual MCP keyboard relay has NOT RUN**: the user's active manual game was preserved and the revised helper was not injected. Native reverse-routing coverage is not a successful engine replay.

## Validation snapshot after the jump correction

[release-validation.txt](release-validation.txt) records **31/31 available commands, exit0**. The optional Lua5.4 shared-library fallback is unavailable and excluded; it is not counted as passed. [baseline-validation.txt](baseline-validation.txt) and [final-validation.txt](final-validation.txt) retain earlier snapshots rather than being overwritten.

Counts: lifecycle46; Combat1054 assertions/Session42; registry18; Director30/Controller38/camera1; MatchHub12; queue20; guardian13+3; route10; analytic traversal all5gaps; Pig15; Walker16; SourceCombat14; DragonStrikes9/DragonFlight19; flies15; carry24; clubs23; feedback10; journal8; world30; gateway14. Python checks: playable8, core build3, combat stand7, Walker packaging5. Compilation covered81 source/test scripts and2 tool scripts. Main/stand/lifecycle/Walker fixture serialize; deterministic main/stand source checks pass.

The final focused follow-up confirmed navigation25 and compilation of all85 current source/test/tool files. The31-command release snapshot remains the production baseline; fixture preparation changes do not constitute production changes or a new full-route result.

This is the recorded snapshot **before the reverse-navigation/public-input follow-up**, not a claim about a later artifact:

| Artifact | Value |
|---|---|
| Playable | `places/BrickToadsPlayable.rbxlx`,403209bytes |
| Playable SHA256 | `b6661521af567b1d50ff1b53ff484b9487c27e54d1a70f2f597a5ae3e6a47ef2` |
| Embedded source receipt | `111e5acea788db6c93dc5dc011c291ea974604ca4fe60c08b69f3bf733ea5eac` |
| Receipt coverage |28 embedded production sources, plus the separate BuildInfo receipt script |
| Isolated Walker place |418034bytes, SHA256 `4bec369a328f9ffa6bf8554662b21e47c4f70ac61b4682681e25658caf5efa34` |
| Preserved user starter |SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` |

The receipt was independently recomputed from serialized sources and matched BuildInfo. A place hash, embedded-source hash and fixture source-manifest hash describe different objects and must not be interchanged. The user's modified starter remains outside the generated delivery.

## Isolated NPC Walker Heavy: actual Studio PASS

[npc-walker-heavy-engine.json](npc-walker-heavy-engine.json) records `status=pass`, all **14 checks passed**, elapsed1.45085seconds, private place117412694427208. The fixture uses an existing first-zone NPC Walker, anchors that attacker for isolation and seeds the hero's raw Life to35. This is a prepared finite test, not natural combat or a complete route.

The ordinary NPC decision selected Heavy; actual geometry produced exactly one profile20 hit **35→31**. The hero was unanchored, received an observed upward response and returned to a grounded non-reaction state with the **same actor, attempt and three respawns**. Actual hip Motor6Ds moved during windup, the finite pose returned to idle and motors settled near their original frames. The NPC remained its existing living unowned body.

The JSON's `sourceManifest.engine_status=not_run` is its static packaging declaration; the top-level actual result and14 runtime checks record this later execution. Its `source_pack_sha256` is `5c480101dbbd0f42847293e25c9e03cb90a8f66da926032ef71d6178dc61af49`, a separate manifest digest from the playable's embedded-source receipt above.

## Isolated same-body Dragon transport: actual Studio PASS

[dragon-engine-pass.json](dragon-engine-pass.json) records `status=pass`, **78/78 checks passed**, elapsed4.187069seconds, on production receipt `111e5acea788db6c93dc5dc011c291ea974604ca4fe60c08b69f3bf733ea5eac`. The executed fixture source SHA256 is `f9a1be6c8b33ad81dd792a2c93a9edd601ce365c8b445bf5922365de6446e504`. It is a prepared isolated world at Z8192, using existing Dragon−10 and Pig−11, separate claimed actors and real unanchored bodies. These public Session calls are not a real-player/network or keyboard-relay run.

The same Dragon rose under an actual lift force, survived a prepared Heavy **raw47→31**, retained its claimed ownership and was mounted through public primary after a real walking command. Public steering moved that unanchored body and public stop halted horizontal flight. Mounted fire hit the existing Pig exactly once **raw31→15/profile4**. After the rider turned to−X, the actual response remained **+X at32studs/s**. Public Jump dismounted; every saved per-part collision flag was restored, the old walk remained zero and fresh walking was accepted. Hero/Dragon identities, attempt1 and three respawns remained unchanged; mounting/fire did not heal or spend appearances.

Capture preparation applied one real Heavy to the hero **raw47→31**, waited a physics frame to observe its impulse, then explicitly repositioned for the real delayed0.25-second capture geometry. The linked body was held and released finitely without a second hit or stale movement. Closing the isolated transport removed its temporary forces, links and shots. The operator confirmed removal of the temporary scene with no leftovers, preservation of the user's main run `0f201fcd…` and zero logger failures. This preparation does not establish a natural encounter, full route, physical device or reconnect result.

Three failed raw attempts remain: [attempt1](dragon-engine-attempt-1.json), a recovering-body/grounding race before mounting; [attempt2](dragon-engine-attempt-2.json), sampling the fire response before physics applied the queued impulse; [attempt3](dragon-engine-attempt-3.json), capture geometry missing after a queued impulse moved the prepared hero. Only the fixture preparation/timing was repaired between these attempts. They are not attributed to new production defects, and the final PASS does not erase them.

## Read-only production source comparison

[production-source-comparison.json](production-source-comparison.json) records exact `Source`/class/path comparison of **all29 production scripts, zero mismatches**, repeated after fixture cleanup against the current playable and its embedded source receipt `111e5acea788db6c93dc5dc011c291ea974604ca4fe60c08b69f3bf733ea5eac`. The user's live manual run was preserved, no fixture worlds remain and loggerFailures=0. No successful route is inferred from source comparison.

## Production route attempts and unresolved work

The production-route attempts did not establish an unprepared complete combat clear. Earlier failures are retained as failures. During the later attempt, the user observed the pilot repeatedly approaching the aqueduct from the wrong side: hero X≈53.28 had crossed the48–53 gap while the remaining Walker was behind at X≈45.63. A forward-only gap navigator could not correctly route that pursuit back over the gap.

This identifies a pilot/navigation defect; it does not independently prove the authored level is impossible for a player. [route-loop-observation.json](route-loop-observation.json) retains the observation. The reverse navigator and missing-input deadline are now covered by the25 native checks above. Actual replay through the new public keyboard relay remains NOT RUN, so no successful route repair is claimed in Studio.

Remaining acceptance includes actual keyboard relay replay, the full route and next manual game without clearing/position/health/reserve helpers, declared multiplayer/device cases and actual reconnect. The29-script comparison, native/CI/build success and the prepared14-check Walker/78-check Dragon fixtures cannot close those criteria. [delivery-validation.txt](delivery-validation.txt) records the final focused checks.
