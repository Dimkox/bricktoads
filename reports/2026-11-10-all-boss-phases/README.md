# All six implemented boss encounters — 10 November 2026

## Corrected mechanics

**Reaction expiry:** production ordering is Session effects before Director/Boss stepping. The boss could therefore retain an expired Reaction during a new hit or source action selection. An expired light reaction skipped its OR7 recovery (Big Blag 253→251 instead of recovered 255→253); an expired heavy reaction selected a stale kick/boot or rejected a legitimate hit/command. One shared reaction-only reconciliation now runs before selection, hit, command, movement eligibility and normal step. It retains the existing deadlines, OR7 arithmetic and live combo/armor windows, without executing NPC decisions early.

**Voluntary movement expiry:** CampaignDirector accepted one human boss Move without recording a timeout, and boss actors did not pass through the hero World:hazard locomotion expiry. The body could continue indefinitely while Ready. Accepted moves now receive the existing MoveTimeout budget; expiry clears voluntary input. Attacks, disconnect, defeat and close clear the movement timestamp. Scripted charges/jumps and physical impulses retain their own behavior.

## Regression and build evidence

[Reaction RED](boss-reaction-expiry-red.txt) has 50 failing deadline variants and 10 passing preservation variants across five bosses × Human/NPC. [Reaction GREEN](boss-reaction-expiry-green.txt) passes all 60. The new movement spec checks all five bosses, fresh/stale connection input and uninterrupted Charge/Jump. [Movement RED](boss-move-timeout-red.txt) replays the 2e0047f baseline from isolated ignored module copies; [GREEN](boss-move-timeout-green.txt) uses the corrected source. Shared production files were never reverted for this replay.

Full frozen-source verification passes **56/56 commands and 186 Luau compilations**, with unchanged verification inputs, matching source/playable packaging and the protected starter unchanged. See [validation JSON](final-validation.json), [output](final-validation.txt) and [local file hashes](verified-files.json). Independent review found no remaining runtime issue. Its helper cleanup-status finding was corrected: a cleanup failure cannot be overwritten by the phase matrix's later PASS.

## Native Studio acceptance

Fresh local playable; Studio 0.746.0.7461269; production source SHA256 `d8bbd170ff44256aa64c8479e89421dcdb507ccfb4cea712941e1264fc0f7534`.

| Helper | Context | Checks | Result |
| --- | --- | ---: | --- |
| [Campaign phase matrix](campaign-native.json) | Edit; native Models, held-root poses, virtual time, real Session/SourceCombat | 550 | PASS |
| [Guardian chain](guardian-native.json) | Edit; native intro, target/ground queries, projectile Models and real Session | 88 | PASS |
| [Movement deadline](deadline-native.json) | Play Server; real Heartbeat and Humanoid physics | 90 | PASS |
| Total | 16 owned worlds; every cleanup/restoration row passes | 728 | PASS |

### Five campaign bosses

Each encounter starts with its ordinary full Life/progress. Only validated normal hero `Session.intent` Punch actions spend boss resources. No boss Life/progress writes prepare later phases or defeat. Every accepted punch lands, the same boss body/actor persists to defeat, and the hero retains actor, attempt 1, raw 47 and all three reserves. The resulting counts are fixture-specific combo/spacing observations, not a universal number of hits per boss.

| Boss | Native checkpoints for both Human and NPC | Ordinary boss moves checked at each checkpoint | Normal hero Punch inputs to defeat, per controller |
| --- | --- | --- | ---: |
| Big Blag | Phase 1 at 255; phase 2 at 191; phase 3 at 127; terminal 0 | Phase 1 Hop twice; phases 2/3 Hop + BellyDrop | 112 |
| Robo-Manus | Progress 0/108/120/228/240; terminal underflow after 240 | Burst + Jump | 67 |
| General Slaughter | Initial 255 spent before progress 0→108/120/228/240; terminal underflow after 240 | Charge + Headbutt | 172 |
| Buzzball | Protected Chase at 207, same-body handoff; phase 1 at 207; phase 2 at 127; terminal 0 | Roll + Bounce | 91 |
| Dark Queen | Progress 0/108/120/228/240; terminal underflow after 240 | Sweep + Spin | 67 |

The matrix has 40 checkpoint rows and 80 outgoing move executions, including Tell/Active armor, Recovery exposure, finite Ready, native lift/landing, three-bolt bursts and actual production collision damage to fresh synthetic ordinary target bodies. Total 1018 normal hero Punch inputs deplete all ten Human/NPC encounters. Both controller modes retain identical phase/resource transitions. Big Blag's first-phase ordinary Punch deliberately selects only Hop under the current documented tuning. The observed Life boundaries are reachable odd-byte values immediately below the source comparisons; this is not a claim of observing every possible byte value.

### First Causeway Guardian

The native assignment waits before spawning; finite introduction then activates one human-controlled Guardian. An ordinary primary hit is shielded. A previously accepted Bullet continues after its owner's disconnect and damages the hero 47→31; offline fire and an old connection epoch are rejected. Server Heavy deadlines produce native Heavy→Ground objects from actual ground rays. One disclosed physical fall and Session-paid respawn provides a legitimate Normal shield for pickup/throw checks, spending exactly one reserve. Three actual Session primary pickup/throw returns change the same Guardian's raw Life 47→31→15→0 and hearts 3→2→1→0, clear projectiles and open Exit. Authored exit boundary checks precede Won. Hero resources remain unchanged throughout the return chain after that paid spawn.

### Physical input deadline

For every campaign boss, exactly one accepted Move causes real native travel, then the existing 0.35-second timeout clears lastMove and Humanoid.MoveDirection. Later samples show zero drift for all five bodies. A new accepted Move resumes the same actor/Model at the existing cap 9 without changing Life/progress or hero resources. This helper uses real Heartbeat time, distinct from the virtual phase matrices.

## Boundaries and delivery

These are all **implemented** phases of the six current encounters, not proof of complete NES phase/timing/animation parity. The phase matrix discloses prepared cleared gates/stances, held roots, selected virtual steps and fresh synthetic collision targets; it is not free physics or a natural complete human boss fight. Guardian geometry/phase checks use virtual time; its paid fall is explicit. Movement expiry is separately verified with unanchored native Humanoids in Play. Synthetic owners and callback transitions are not actual remote clients, touch/keyboard acceptance or same-account live-body rejoin. The second genuine account remains unavailable. No automatic safe route, balance, art or public-access change was added.

CampaignBoss, CampaignDirector and BuildInfo were synced to existing private place 117412694427208 only after the old Sources matched Git HEAD; the final Sources exactly match the checked local playable. Private Save to Roblox with Notes used `Fix boss reaction deadlines and stale movement`. The owned helper was stopped and closed without saving test or migration changes. The original private Studio remains open with no QA folders; [synchronization receipt](private-studio-sync.json).

The protected starter remains SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`; concurrent concept art is preserved and excluded. Git push, CI and Jira outcomes are recorded in delivery comments/receipt to avoid self-referential commit metadata in this report.
