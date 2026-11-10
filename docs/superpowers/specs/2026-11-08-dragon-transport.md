# Dragon flight and transport preparation

Continue the approved first-level source mechanics in existing Luau/Roblox architecture. Studio and devices are explicitly deferred by the owner; native checks do not establish engine acceptance.

## Behaviour

- One existing Dragon body/actor/owner/health/life. NPCs fly toward current heroes, turn between passes and use existing headbutt. Human controllers use public Move/Jump/Punch with identity, sequence, rate and connection checks. Offline bodies remain vulnerable.
- A surviving heavy hit disables flight and opens a finite grounded mounting opportunity. Contextual F mounts; rider Move steers, F fires, Jump or Dash dismounts. Mounting neutralizes that enemy for gate counting while linked, without killing/healing it. Human enemy ownership remains assigned but control is suspended while mounted.
- Capture is a separate short windup against a current heavy-reaction hero, revalidated geometrically at effect. No target lock or invented unmounted ranged AI. Capture carries and releases the same hero, without creating damage/resources; shield/death/reaction/actor changes interrupt links.
- Mounted fire: fixed base4/hero22 raw16; global cap two live shots, finite lifetime and swept wall/actor collision. Friendly fire through existing damage/shield pipeline. Shots survive owner disconnect but cannot cross run/group scope. Current full source target-type exclusions and frame parity are not claimed.
- Existing carry/guardian/fly hand priorities remain; mounting drops an equipped club. No new remote attack names, paid functions, extra lives or scene reset.

## Engineering calls

Speeds, altitude, lift, turn/disable/capture durations, radius, lifetime and original motor poses are disclosed Roblox calibration. Grounded mount after a surviving heavy hit is an adaptation of object_dragon/set_on_transport. Current gate design treats a mounted Dragon as neutralized so it can actually transport heroes beyond its encounter. Dismount restores an unspent hostile body. Capture release adds no second hit. Fire damages the existing supported ordinary families through one pipeline; source mask parity remains research.

## Source

Pinned DisAssemble f1a43b69577246850d136473700a333b3cdfe93f; main2943–3095,5050–5355 (flight/disable/mount/capture),6892–6936 (input-only fire/cap2),9655–9712 and20858–21057 (fire movement/collision, table offset14hex plus5Ahex for hero -> profile4/22). No upstream executable/artwork is shipped.

## Verification boundary

Real Session/Director/Combat tests cover ownership, immutable accepted state, shields, miss/change/interruption, actor replacement, disconnect, cleanup and resource conservation. Real GameWorld API-double contracts cover group-local coordinates, forces, saved physical flags and geometry. Roblox physical flight, motor appearance, wall collisions under replication and touch UX remain NOT RUN.
