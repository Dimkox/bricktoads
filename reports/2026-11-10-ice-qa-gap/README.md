This QA-only change addresses the repeated first Ice landing failure in full12, seed614217761. The shipped game mechanics and authored challenge remain unchanged. The final Early policy is SHA256461abaa9803a2e2211d0f3ed696d3100f01c587c6d7d811fafce781d7de8703e; baseline8c7d521749c78ec921f158633067a35b773c7b4a42933b28d6f9a93ca9a6fa16 preserves the accepted Surf repair.

The relevant floors areX−12..21/top0, X25..54/top0, andX58..87/top2. The reported falls atX71–76 happen after failing to land on the raised third floor across the second gapX54..58. They are not falls into a gap centered atX71.

An authored Snowball atX50/Y5/Z−9 moves laterally by±10 over a three-second period. The old pilot cached one arrival estimate while still accelerating. In the failing phase it steered into that Snowball immediately before the second gap. The collision starts the real0.75second reaction; ordinary Jump requests are then rejected while the existing Ice glide continues. The body reachesX58 below the elevated landing floor and falls nearX71/Z−10. The numeric trace records source−9001/Dash hits aroundX46–49, followed by rejected takeoff requests and the matching fall.

The native adverse-phase baseline independently confirms that chain with real physics and active AI: hit atlocalX46.325/Y3/Z−9.230, then fall atlocalX71.128/Y−58.988/Z−9.984. The first Snowman falls before attacking; separately logged later Snowman−2/DragonFire shots are distinct from this first static-hazard hit. Other native baseline phases passed, demonstrating that the authored crossing is possible and the failure depends on approach timing.

The QA pilot now evaluates the first lateral Snowball's whole contact interval using bounded local copies of the existing Ice acceleration, friction and held-input behavior. It chooses between the existing0/−10 lanes. From rest, more than25studs before the hazard, it withholds forward input until the forecast has clearance. Steering and the subsequent gap jump still use ordinary accepted inputs. This does not stop an already gliding hero, change a reaction, supply a jump during a reaction, move a body, heal anyone or restore a stock. Later Ice hazards retain the old policy; Surf, Jet and all production files are untouched.

| Evidence | Baseline | Final |
| --- | ---: | ---: |
| First-section36-case cohort regression |7 failures,29 passes|36 passes|
| Same native adverse phase, live AI |First fall nearX71; eventualLost|Won in13.334seconds|
| Native final resources |Four bodies exhausted in that baseline fixture|attempt1, reserves3, rawLife47|
| Existing other early-course checks | |100 passes|
| Existing live-threat/rewind checks | |8 passes|

The focused36 cases cover three initial bodies, six entry phases0..2.5seconds, input cadence0.08/0.133/0.167seconds and outer simulation batches1/60/0.1seconds. They stop only after all three original bodies cross the raised third floor pastX87 atY≥4.9; any death or reserve/attempt change fails the case. This is a first-section regression, not whole-stage victory. All inputs pass through the real Session and Modes APIs. The numeric actor/presentation boundary is doubled; source-less static-hazard impulses correctly remain ignored on anchored Modes actors while the real reaction/reset applies.

A separate full-stage54-case stress report is retained, including0.25second outer batches. It remains negative: final34 failing cases versus38 baseline cases. Later hazards and very coarse outer updates still cause deaths; final quarter-second stress can consume more reserves than baseline. This report does not accept deathless whole-Ice traversal or those coarse batches. The task intentionally targets the observed repeated first gap rather than claiming every reserve loss is eliminated.

The final native evidence is a prepared isolated solo stage with a fresh Session, slot3 at the authoredZ+6 spawn, rawLife47 and three reserves. Only the first ordinary input is delayed0.5seconds to expose the adverse phase, then inputs run at approximately0.1seconds. Production R6 physics, Snowman AI, projectiles, reactions, all authored hazards and completion remain active. No positions, resources, geometry, collisions or policies are rewritten in the game. Lighting/Atmosphere are restored synchronously after owned-world construction, before yielding. The final461ABA source reaches real Director Won with zero Hit/Death events and unchanged actor/attempt/resources. It does not establish registered-client latency, a native multiplayer cohort or a continuous campaign run.

native-slot1-baseline.json and native-slot3-baseline.json retain ordinary no-delay baseline successes. native-adverse-baseline.json is the frozen8C adverse-phase RED. native-fixed.json is the final461ABA native GREEN. native-candidate2.json records a rejected optional unconditional first-packet wait; it passed its native sample but introduced one later-gap regression in the100-case suite and was removed. Native candidate1 is the same source as the final accepted variant. All owned native worlds, cloned modules and fixture folders were exported and cleaned.

Reproduce the focused tests from the repository root:

```text
.tools/luau-0.745/luau.exe reports/2026-11-10-ice-qa-gap/probe-first-section-baseline.luau
.tools/luau-0.745/luau.exe reports/2026-11-10-ice-qa-gap/probe-first-section-fixed.luau
```

The baseline exits1 and final exits0. Pinned policy snapshots are included. The probe-full-stress variants deliberately retain the broader negative stress result. Native reproduction uses the included shared runner and install_native_ice_campaign.py, which generates a payload for the authorized Studio MCP Server context; it does not launch Studio. summary.json and stage4-prepared-inputs.json pin source/build/resource scopes. The protected starter place and the existing Surf evidence were preserved.
