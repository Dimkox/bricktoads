# Walker leg-club — 2026-11-08

A Walker killed through ordinary combat now leaves one original mechanical leg-club. A grounded hero can pick it up with F/ВЗЯТЬ ДУБИНУ and swing with F/УДАР ДУБИНОЙ. The weapon has greater reach, can damage teammates and has no invented wear counter. A light hit interrupts a pending swing while retaining equipment; a heavy reaction/death drops it for another pickup. Boss introduction drops equipment, and successful ground-ball pickup also releases an equipped club.

## Source and authority

[Pinned source trace](../../research/2026-11-08-walker-club-source.md) separates one weapon0x1C from the Walker-head0x1B record. Pickup8/E3 sets equipment state and removes the ground object. Club swing1A uses NPC profile2/raw16 and hero profile20/raw16. It is not the running finisher profile21. Source light/heavy reactions and boss introduction establish the confirmed drop paths. No verified limited-use counter or manual B/A club throw is added.

Hero damage uses raw16/profile20 through trusted internal Combat.hit. The unchanged client schema rejects Attack='Club', targets and damage values. Existing NPC3HP remains provisional: a club deals2 prototypeHP. Reach9,width3.5,height4studs; windup/window0.16s,cooldown0.7s,reaction0.75s and26/22studs/s impulses are Roblox calibration. Pickup uses grounded4.5-stud/3-height/geometry checks with automatic facing. Original flight/animation timing, species Life, item bounce/removal and full weapon interactions are not claimed.

Only a confirmed Combat Walker death creates one record keyed by its existing actorId. Repeated death does not duplicate it; unsupported/fall removal supplies no free safe pickup. Items and massless welded equipment stay outside enemy actors/role offers. Pickup preserves health, shield and respawns. Pending swings bind actor/attempt/level/combat/reaction history, use their own finite hitbox and lock the first directed takeover target when accepted. The first actual eligible hit consumes the effect, including a teammate or shielded target.

Historical heavyReactionEpoch triggers a drop even after recovery has cleared the current reaction. A new appearance cannot inherit old equipment or provide a new safe drop location. Accepted swings can finish on their same offline body. Hands cannot simultaneously own a Pig/guardian ball and club. Flies retain priority over a swing. Ground-ball priority and its forced club release are explicit Roblox integration to keep the guardian chain usable after re-pickup.

## Studio MCP evidence

[engine-checkpoints.json](engine-checkpoints.json) contains all checkpoints and the fixed preparation hook. Studio0.746.0.7461269, private place117412694427208. No HP/reserve values are directly set. Preparation repositions bodies, anchors/pauses other NPCs, invokes existing light/heavy Session hits, creates one shield-preparation lifecycle death in the first run and selects the boss/one ground ball to isolate hand priority. Actual keyboard/touch inputs defeat the Walker, equip, swing, transfer and defeat an ordinary enemy.

The valid three-client run was d2a0a9e4-aa63-40d0-a617-fba12ec901c1. Two heroes and a human Pig were present; the defeated Walker was an NPC. Two clients later disconnected. Their IDs were not reused. Remaining checks completed in fresh two-hero run2f3aaa8f-5305-45ce-90d1-ac47a28b8be7. This is prepared finite acceptance, not a full unprepared playthrough or reconnect proof.

| Check | Actual result |
|---|---|
| Walker combat death | Real R then F changed its3HP→1→0; exactly one ground club appeared, without another enemy actor |
| Phone pickup | iPhone17Pro LandscapeLeft,750×381; actual ВЗЯТЬ ДУБИНУ77×56 button equipped the item and removed its ground visual |
| Protection/resources | Pickup retained the existing Normal shield, raw47, attempt2 and2 respawns after one explicitly prepared lifecycle death |
| Automatic facing | The prepared hero faced away before pickup; the equipped hero turned toward the item |
| Phone friendly fire | Actual УДАР ДУБИНОЙ tap hit a teammate7studs away:47→31 raw, logged Club/profile20; both retained their actor and resources |
| Light retention | Existing Punch hit/recovery left the same club equipped |
| Heavy drop and transfer | In the second run, existing Dash hit dropped one club; the other hero's real F picked up that same item. Both stayed attempt1 with3 respawns |
| Ordinary enemy damage | Second hero's actual club swings changed Pig3HP→1→0, with one original club still equipped and no extra drop from Pig |
| Boss introduction | Prepared real boss start dropped current equipment once; F could re-pick it up |
| Ball hand priority | A prepared ground ball changed the equipped hero's primary action to ВЗЯТЬ ШАР; real F carried that ball and returned the same club to ground, with no dual equipment |

Phone Activated count2 confirms both pickup and swing button events. The screenshot showed the welded original leg-club, readable wrapped labels and clear controls. Explicit simulator coordinates were used; device simulation was restored to default.

One early inspector read ran before the friendly swing effect. The later real Hit event confirms profile20 and raw31; the early read is retained separately. The pickup shield expired before that later swing, so removal of shield at swing acceptance is native-contract proof rather than claimed engine proof. An earlier preflight with an incorrect offer click and unpaused NPC is excluded. Disconnected test clients are not presented as successful reconnects. Both accepted sessions ended and the temporary entry hook was removed;23 production sources were compared against the final repository pack.

## Verification and limits

[native-validation.txt](native-validation.txt): all21 fresh commands exit0. Core46; Combat334 assertions/Session42; Registry18; Director30/Controller37/camera1; queue20; Hub11; guardian13+3; route10; flies15; carry24; WalkerClubs23; gateway14; world17; Python17. Compiled60 source/test files and2 tools. Review found no actionable P1/P2; missing auto-facing was caught and verified RED→GREEN before the source freeze.

Playable:333593bytes, SHA256ebc65efd4c12990288ac8ae6795dff4c25b8bde0eb57eb7b2322419548b0ba32; deterministic check matches sources. User-modified places/BrickToads.rbxlx remains unchanged at SHA2561974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 outside this commit.

Full unprepared level combat, source-exact species health/AI/weapon physics, physical phone/tablet acceptance, multiple levels and actual same-account reconnect remain open. Competing pickup, offline completion, old-body cleanup and group isolation are native contracts, not claimed simultaneous multi-group engine acceptance for this weapon.
