# Native23 first death: ordinary PigJab before the gap

Run `bricktoads-qa-23-01-384fb79f`, seed1158731273. This audit only downloads
the root-frozen snapshot and reads local evidence. It changes no policy,
production source, transport, Studio state or Git state.

Frozen motion426511 bytes and detail85697 bytes were downloaded from15+3
StringValue parts. The saved JSON files have one additional final newline
from apply_patch and both parse correctly. Motion covers+24.833…140.596s;
the retained journal covers+58.884…137.635s, so the initiating contact and
first death are both preserved. The companion JSON records hashes, exact
events and the surrounding native frames.

Times below are seconds after stage entry at1794333404.410520.

1. At+81.251055, ordinary NPC Pig-5 lands PigJab/profile18 on actor2/attempt1
   at X50.642/Y3/Z13.947. Life39→35, blockedfalse, impulse true. The hit is
   not a projectile and is not lethal damage.
2. The last precontact plan at+81.16567 is `Evade on authored support`,
   requesting approximately X+0.778/Z-0.0055, withjump=false/run=false.
   The contact observation has VX+12.445, directed toward the platform's
   X54 edge, only3.358 studs away. At+81.29868, after the physical response,
   VX is+18.063 and VZ+7.362; the Humanoid isPlatformStanding.
3. The actual varied Aqueduct first floor is X4–54/Z-23…17 at standingY3;
   the second starts X59. By+81.53185, the body is X54.459/Y1.004/Z15.059,
   already past the first edge and below normal standing height.
4. Edge recovery requests Jump at+81.53185 and+81.66396 while the retained
   reaction deadline is+81.71772. Both frames still reportPlatformStanding
   andREACTION. Session's ordinary reaction guard denies Jump during that
   interval. No own QA Jump was requested immediately before the hit.
5. At+81.78253, after the reaction deadline, the body is already
   X55.838/Y-3.657. It is more than3.5 studs below its last standingY3,
   beyond the ordinary vertical jump-grace limit. Subsequent neutral/no
   support plans cannot restore a takeoff. Fall is confirmed+82.166931 at
   X58.426/Y-35.223/Z16.377, still before the second floor's X59 start.
   Paid respawn follows+82.182994, actor97/attempt2/stock2.

This is a concrete input-policy counterexample: a three-stud endpoint inset
for an evasive Move does not reserve enough room for an ordinary light
attack's impulse while reaction disables the later edge recovery. The new
changed-axis transport does not prevent this genuine NPC contact. The
evidence does not justify changing NPC damage, reaction, impulse or geometry.

The ordinary motion log records requested plans, not acceptedMove timestamps.
Jump rejection here follows the retained reaction notice/deadline together
with the Session guard; the snapshot has no separate per-packet Jump receipt.
No bounded reproduction, policy fix or additional Studio run is claimed by
this audit.
