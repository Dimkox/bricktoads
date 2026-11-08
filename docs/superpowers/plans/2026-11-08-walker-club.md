# Walker club pickup and combat

**Goal:** Add one original leg-club pickup per combat-defeated Walker and let heroes use it through F/touch, preserving server authority, friendly fire and existing item/role lifecycle.

**Spec/authority:** Continue accepted BT-16/22/25/62/64 first-level weapons. Source is pinned in research/2026-11-08-walker-club-source.md. User requested autonomous gameplay implementation, push and Jira synchronization. Do not add deferred enemy-player abilities.

**Source facts:** Walker death produces one head effect0x1B plus one club0x1C, not two weapons. Grounded pickup8/E3 sets have_stick20 and removes the ground object. B checks flies then swings1A; NPC damage profile2/raw16, hero profile20/raw16. No confirmed use/break counter or manual B/A club throw. Light reaction retains equipment; heavy reaction/death drops it. Boss introduction forces a drop. Dropped ground weapons can be picked up again.

**Adaptation:** Keep the current provisional ordinary3HP arithmetic: club does2HP to NPCs, not a claim of original species Life. Hero Club uses source raw16/profile20 through trusted internal Combat.hit; remote Attack schema remains Punch/Dash. Reach9studs, width3.5,height4, windup0.16/window0.16,cooldown0.7/reaction0.75seconds, source2/20 impulses26horizontal/22vertical studs/s are calibrated. Pickup range4.5/height3, grounded/line of sight, auto-facing. No invented durability. Existing R-heavy action remains provisional.

## Interfaces

- New WalkerClubs.new(director) owns items keyed by defeated actorId, hero equipment and pending swings. Exports walkerDefeated(id,position,cause), hasClub(slot), interaction(slot), interact(slot,now,action), drop(slot,reason), bossIntro(), step(now), close(). Only cause='Combat' and kindWalker create one record, once. Unsupported drops are lost rather than relocated to a free safe platform.
- Existing held Pig/ball has priority. Ground guardian ball pickup has priority and successful pickup drops any equipped club; flies keep their confirmed priority over a club swing. Then equipped swing, ground-club pickup, Pig grab, ordinary attack. Pickup does not begin an attack or change shield/resources; a swing accepts BeginAttack before its effect and locks the first directed takeover target with the club hitbox.
- Pending swings capture actor/attempt/level/combat/reactionEpoch and a finite effect window; resolve once through real Session:_hit(...,'Club'). Heavy reaction history gets a separate internal heavyReactionEpoch so a light hit cancels the current swing but retains equipment. Accepted swings can finish on the same offline body. No item/target/damage values enter a client packet.
- Session preserves a longer trusted contextual cooldown by taking max(current,nextDefault). Combat.hit accepts internal Club with hero profile20/raw16 and heavy response; client schema still rejects Club. GameConfig clones Attacks/Impulses before adding Club/2/20, avoiding mutation of stand defaults.
- Persistent ownership tracks actor identity and last observed local position; heavy hit/death/new appearance drops from the old body, never the new spawn. World-ground support decides availability. Boss intro drops existing equipment without consuming it. New game/closed run clears items, equipment and pending swings.
- World clubItem(id,localPosition|nil), canPickupClub(heroId,localPosition,range,height), equipClub(id,heroId)->bool, unequipClub(id), clubSwing(id,heroId) render group-local ground objects and original welded massless noncolliding equipment outside combat targets. Preserve old-owner refs for cleanup and restore poses on drop/reset. Root art is new mechanical leg-club, with no original assets.

## Tasks

- [x] Domain23 real-Session contracts, source profiles and authoritative cooldown/schema/history behavior.
- [x] World17 contracts and original separate ground/welded art; auto-facing verified RED→GREEN.
- [x] Production integration, route10 regression, trusted combat, HUD and CI runner.
- [x] Review and complete native/compiler/build checks; actual Studio pickup/swing/friendly fire/drop/transfer/boss hands recorded in reports/2026-11-08-walker-club/.

Delivery follows this verified snapshot: push/check exact-head CI and update Draft PR/Jira with the resulting commit. Preserve the user-modified starter and leave main unmerged.
