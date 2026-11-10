# Native attempt 19: Ice input policy audit

The production game is unchanged. This change is confined to the explicitly
requested QA input pilot. It still returns ordinary Move/Jump inputs through
Session identity/epoch/sequence checks; it does not write position, velocity,
HP, stock, encounter state, geometry, mode phase or completion.

Frozen candidate: `e7c8152f21d45b281ca75150c39e1f78ff289c9bbce73f25945375f981b3037c`.
Baseline: `da9956a8db58d9d2d37852764e3764e470ef2830eccfa984a37976ddb314ac5f`.
Production build: `7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a`.
Playable: `9f9689b3da56384344209a2743f0eac4eb74e573b3100e0f2a06155e59598a4b`.

## Why the three bodies fell

Evidence is the existing full natural attempt 19 archive, detail journal and
logical mode frame rings in `../2026-11-10-full-campaign-playthrough/`.
Run `ca4ddeed-c377-4a43-9fa6-bae3527bd3e5`, seed `990047694`, real hero owner
`11946162891`. Times below are seconds after entry to Ice at
`1794329687.982793`; anchored native AssemblyLinearVelocity is not the logical
Ice velocity.

| Body / attempt | Accepted hit | Consequence observed in the ring |
| --- | --- | --- |
| 40 / 2 | +6.143677, Snowman -2, DragonFire profile22, X122.367/Y3/Z-9.999; Life47→31 | Reaction until +6.894 and actual Modes impulse. Plans request Jump at +6.596/X124.43 and +6.764/X126.60, but accepted mode axes are zero during reaction. At +6.897/X128.47 the body is already below floor4's takeoff top. Fall at +7.759724, X145.706. |
| 193 / 3 | +13.426083, authored Snowball -9001, Dash profile22, X195.308/Y5/Z-9.989; Life47→31 | Reaction until +14.176 suppresses requested Jump at +13.446/X196.15. Momentum carries it off floor6 past X198. Fall at +14.443226, X216.206. |
| 199 / 4 | +15.242455, same authored Snowball, X196.585/Y7.840/Z-1.526; spawn shield blocks HP damage | Reaction still applies. This body jumped normally after checkpoint3 spawn X194/Y5/Z-3; it lands at +15.328/X197.45, rolls off X198 during reaction through +15.992 and falls at +16.309218/X204.780. |

The synthetic Snowball's journal `impulse=true` is a request flag. It has no
native attacker actor or explicit direction, so GameWorld falls back to the
base implementation; it does not inject a new Modes velocity. The real NPC
Snowman does have an attacker actor and applies the Modes impulse.

Authored floor4 is X95–128, top3, Z-15…15; floor5 X132–165, top3; floor6
X169–198, top5, Z-18…12; floor7 X202–235, top3. Z-10 is inside those floors.
Checkpoint3's initial body was safely supported and clear of the Snowball.
These are longitudinal ledge exits following hit reaction, not an unsafe
lateral floor margin or a production respawn defect.

## Bounded QA change

- Use the existing full-contact Snowball lane forecast for every moving
  Snowball. If neither lane is safe while still at least25 studs before it,
  brake with ordinary backward input and retry the forecast. The old wait
  covered only a first-floor stationary start.
- Treat a static hazard whose whole width leaves center clear as a reason to
  retain center. In particular the positive-Z spike no longer forces an
  unnecessary Z-10 excursion immediately before the later negative-Z Icicle.
- Read already accepted live projectiles. A one-jump forecast tests four
  ordinary held longitudinal inputs over at most60 fixed frames, preserving
  an actual platform landing and enough inset for the next input packet.
  This avoids replacing a projectile hit with an unhit fall.
- Require an ordinary gap jump to reach a later authored support at current
  speed. After a braking dodge or a checkpoint spawn, low horizontal speed
  must not trigger the old fixed4.7-stud takeoff prematurely.

This is a small bounded single-jump calculation, not a search over a route or
a change to player pathfinding. All other course branches, including the DA
Rope patrol, are byte-identical. The only dispatch change passes the already
available read-only threat list to Ice.

## Reproduction and results

Use `.tools/luau-0.745/luau.exe` followed by the selected probe path in this
folder. Each probe imports its pinned baseline/candidate policy. Their files
and result logs are recorded in `validation.json`; compile output and the
precise QA policy diff are also included.

| Check | Baseline | Candidate |
| --- | --- | --- |
| Complete authored Ice, seed990047694, one hero, 36 cadence/start-delay/outer-step cases | 30 pass / 6 fail | 36 pass / 0 fail |
| Complete Ice with original Session, Modes, CampaignDirector, SourceCombat and CampaignEnemies, same seed, initial Z-6, 18 cases | 12 pass / 6 fail | 18 pass / 0 fail; all Life47, original actor/attempt1/stock3 |
| Prior seed614217761 first-section checks, three heroes, 36 cases | Existing baseline | 36 pass |
| Existing broad100 checks, modes2–6 across five seeds/four cadences | Existing baseline | 100 pass |
| Existing accepted-live-effect and rewind checks | Existing baseline | 8 pass |
| Luau compile and raw non-Ice byte comparison | — | Pass |

The full new matrices use cadence0.1/0.133/0.167 and startup delay
0/0.5/1/1.5/2/2.5. Static outer step is1/60 or0.1; NPC outer step is1/60.
These are startup offsets, not network transmission delays.

## Limits

The NPC probe uses the original NPC source and accepted projectile lifecycle,
but a presentation adapter replaces Roblox objects and ground Humanoid
movement. It mirrors the3-stud forward /0.85-stud side ground probes and
stops negative-id movement on zero Move. It is not native physics parity.
Static synthetic impulses correctly remain a no-op at the Modes boundary.

The older first-section36 checks stop after every original body crosses X87
above the raised floor. They establish no complete-level result. The new
full matrices are one seed and one hero. Other seeds, multiplayer, delayed
packets and a full natural13-stage native Won result remain outside this
acceptance. No Studio test was started or controlled by this audit agent;
the parent owns a later single-existing-window native run. No public release
or real-client reconnect result is claimed.
