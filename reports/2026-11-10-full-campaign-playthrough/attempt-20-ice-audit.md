# Attempt20 Ice: three paid falls despite E7

Read-only export and audit. No Studio state, input policy or production code
was modified by this audit. All three saved snapshots parse as JSON:

- `attempt-20-ice-motion.json`:367818 bytes, 13 frozen StringValue parts.
- `attempt-20-ice-detail.json`:79430 bytes, 3 parts.
- `attempt-20-ice-samples.json`:473979 bytes, 16 parts; all25 Ice observation
  rows, containing414 logical mode frames across four attempts.

The detail journal is actually `journal.events`; its other keys are
`dropped/latestSeq/groupId/duplicates/invalid/rules/schema/runId/build`.
Run `b280d913-e985-4f4d-a190-d80e85728ea0`, seed `1158731273`, frozen QA policy
`e7c8152f21d45b281ca75150c39e1f78ff289c9bbce73f25945375f981b3037c`.
Times below are seconds after Ice entry at `1794331261.403079`.

## First body: late lateral clearance before Icicle

Original actor2/attempt1/Life47/stock3 reaches the final Icicle without an Ice
NPC hit. At +13.050701 the journal records synthetic attacker-9001, Dash,
profile22, Life47→31, followed by `CampaignHazardHit(kind=Icicle)`. Position
is X288.009/Y3/Z-3.840. This is `ice-8`, authored X292/Z0, moving vertically.

The logical frame at +13.0505 has VX24.827/VZ-7.656, grounded on floor8.
Reaction lasts until +13.8007. Plans at +13.2503 and +13.3848 request Jump,
but accepted `modeInput.x/z` remain0/0. Floor8 ends at X296; by +13.4348 the
body is X296.807/Y2.760, unsupported and descending. The next floor begins
X300 at top5, already unreachable from below. `ConfirmedDeath` is
+14.285264 at X313.232/Y-58.749/Z-9.808. Paid CommitSpawn follows +14.302497.

The lateral miss is preceded by a measurable input delivery queue, absent
from the synchronous logical fixture:

| Observation | Time / state |
| --- | --- |
| Prior plan | +11.416586, X input0.957501/Z input+0.288429 |
| That plan first accepted | modeInput.at+11.583351, 166.8ms after planning |
| First negative steering plan | +11.549644, X+0.707107/Z-0.707107 |
| Old positive steering still accepted | frame+11.692993, X253.705/Z-4.674/VZ+9.580, no reaction |
| First negative accepted mode input | modeInput.at+11.734438, seen in frame+11.752695 |
| Session movement stamp | +11.750366, 200.7ms after the negative plan |

The body consequently continues toward center, reaches approximately
Z-1.046 near X271, then has insufficient lateral clearance at Icicle contact
X288. This evidence identifies a real held-input delay mismatch. It does not
establish that seed variation alone caused the miss, or identify a production
movement defect.

## Second body: checkpoint Snowball denies takeoff

Actor132/attempt2/stock2 respawns at checkpoint3 X218/Y5/Z0, on floor6.
At +14.834721 an authored Snowball records a shield-blocked Dash from-9001
at X219.039/Y5/Z0. Life remains47; reaction still lasts to +15.5847.

Plans +14.8335 through +15.3174 request Jump. Accepted axes are0/0 during
reaction; the journal has no accepted CampaignJump for this attempt.
Residual VX is about6 and decays. Floor6 ends X222; frame+15.3844 is
X222.062/Y4.957/VY-2.562, unsupported. At +15.6497, when movement resumes,
the body is already X223.292/Y-1.322. Floor7 begins X226, top3.
Fall is +16.284121 at X229.621/Y-59.373/Z0. Paid CommitSpawn: +16.299790.

## Third body: immediate checkpoint contact, then hit during jump

Actor136/attempt3/stock1 respawns at X218/Y5/Z0. The moving Snowball hits
again at +16.333441, only33.7ms after CommitSpawn and before this body's
first plan at +16.3511. Shield blocks HP damage. Reaction ends +17.0834;
accepted movement first resumes at modeInput.at+17.1516. The body remains
grounded at X218 during the initial reaction.

An ordinary CampaignJump is accepted at +17.649571. At +17.6680 the logical
body is X219.603/Y5/Z-1.603 with VX6.015/VY51/VZ-6.015. Another shield-blocked
Snowball hit follows +17.717091, just67.5ms after Jump, at
X219.926/Y7.336/Z-1.926. Reaction lasts until +18.4671 and accepted axes reset
to0/0. The airborne body's low horizontal velocity decays while its vertical
motion continues under ordinary gravity.

At +18.3504 it has passed floor6's end but is still only
X223.662/Y4.064/VY-51.383. It descends below the next platform before reaching
floor7's X226 start. Fall is +18.983824 at X228.145/Y-59.667/Z-8.074. The third
reserve is spent by CommitSpawn +19.000491. Attempt4 eventually completes Ice
and enters Surf with stock0.

## Impulse and acceptance limits

Every Ice Hit in this snapshot is an authored course hazard-9001. There are
no NPC Snowman Hits in epoch4. The journal's `impulse=true` is an impulse
request, not proof of an applied Modes velocity: attacker-9001 has no native
actor or explicit direction, so GameWorld falls back to the base path for
the anchored Modes body. Logical velocities corroborate this: the first two
contacts retain grounded VY0; the third airborne contact continues its
gravity descent rather than receiving a new upward impulse.

All three falls involve ordinary hit reaction suppressing the required
movement/jump after contact. Neither support geometry nor HP/stock was
changed. The synthetic course hit and shield reaction semantics are the
production behavior exercised here.

The corrected original-NPC fixture's same-seed18/18 GREEN result remains a
synchronous-input logical result. It applies planned Move/Jump immediately;
the native ring above contains a regular steering queue approaching200ms and
variable plan intervals around116–149ms. Its GREEN result therefore does not
prove native deathless traversal. A future bounded reproduction must model
the queued ordinary input boundary before considering another QA policy
change. This audit implements no such change and makes no full-campaign Won
claim.
