# Walker primary strikes

Continue the authorised game implementation after7d45afe. The ordinary Walker already drops its leg-club, but still attacks with generic Dash. Implement its source standing-light/heavy choice on the existing body/F, without introducing deferred player-enemy abilities.

Primary source is pinned feos-tas/DisAssemble f1a43b69577246850d136473700a333b3cdfe93f. Ordinary object_tall_walker chooses animation3C when selected target raw Life low nibble>=4 (E2base0→hero18/raw4/light recovery), otherwise3A (E2base2→hero20/raw16/heavy). Neither action uses running finisher21/raw255. Companion research note records the precise positional/target guards and source limits.

## Interfaces and decisions

- Internal Combat.hit actions `WalkerLight` and `WalkerHeavy` have fixed profiles18/20, raw4/16 and light-recover/heavy semantics respectively, matching actual Session shields/arithmetic/reactions. Public intent remains Punch/Dash. Existing stand defaults are not mutated.
- `GameConfig.Walker` owns calibrated AI range6.5studs and explicit ordinary NPC damage1/2HP and source profiles0/2; Attacks.WalkerLight/WalkerHeavy own effect hitbox reach7.5,width3.25,height4. Windup0.40/0.65,cooldown1.0/1.6,recovery pose0.20/0.35,reaction28/60 or0.75 seconds. These units/impulses are Roblox calibration. NPC3HP remains unchanged; unknown NPC raw Life selects Light rather than treating3HP as raw3.
- Director freezes action and cloned tuning at acceptance, then uses actual effect-time geometry, one hit and existing Session/damage dispatch. AI uses Walker range; human F uses the same standing choice. Exclude dying/heavy-reacting target; allow actual recover==true light reaction. Other species, Pig running and legacy scene stay unchanged.
- World reads existing windup.action,lastStrikeAction,strikeRecoveryUntil, and gives WalkerLight/WalkerHeavy separate original leg/hip poses for windup and recovery. Pose attributes are presentation only. Death, carry, incoming reaction and expiry clear them; held equipment and existing other species retain priority. No physical root teleport or extracted animation frames.
- Preserve takeover closure, exact actor/owner/HP/one-life history, accepted offline completion and interruption cancellation. Only a confirmed combat-death Walker creates its one existing ground club. No free fall drop or duplicate enemy/item.

## Tasks

- [x] Finish pinned source note and positional/target decision; record adaptation limits.
- [x] Combat fixed-profile RED→GREEN tests, all raw boundaries and shields, no regression to Punch/Dash/Club/Pig.
- [x] Director/config integration RED→GREEN: AI reach, accepted action immutability, actual Session damage/recovery/shields, NPC damage/impulse, human F, miss/claim/offline/interruption and one death-drop.
- [x] Original world pose/reset tests RED→GREEN.
- [x] Native/compiler/build verification and independent review. Actual Studio long reach/whiff/light/heavy and combat-death drop with fixed preparation disclosed; remove temporary hook, compare production sources.
- [x] Explicit stage excluding user-modified starter, commit/push, Draft PR and Jira sync; inspect exact-head CI and report external download failures honestly.

Review focus: AI start reach versus actual hitbox, low nibble3/4 versus raw16, target reaction ending during windup, multiple victims/changed target geometry, stale ownership/offline completion, interrupted swing and duplicate Walker club drop.

Source ruling: the inner horizontal window reverses direction and continues gait rather than freezing harmlessly at close range. Add a calibrated NPC-only backstep below2.5studs with speed7, sharing the same support/edge checks as ordinary pursuit; attacks start in2.5..6.5studs. Source axis/cadence, exact leg gait and attack animation root motion are not reproduced. Do not add an invented grounded-target rule: source target height is tested later by the actual collision. A human Walker retains manual movement/F and does not gain an automatic retreat ability.

Repository ruling: fetched origin/main has user merge d474ca0 of PR2, with an identical source tree to7d45afe. Continue from that merge in `codex/walker-strikes`; create a new Draft PR rather than modifying the merged PR. Preserve the existing user starter modification.

## Handoff verification — 8 November 2026

PR [#3](https://github.com/Dimkox/bricktoads/pull/3) is the continuation branch. Implementation head4f10421470bbb1b09f75a6d1007ebaa351810ceb has successful BrickToads checks, Combat stand checks and GitGuardian checks. A fresh isolated checkout reproduced all23 native/Python/build commands, compiled64 source/test files plus2 tools and rebuilt the same342918-byte playable (SHA256275b4fab2758a107f0e1769f9c66f5859c78a99ffc56c6532ee4be70796a89bf). Independent code review found no actionable P1/P2/P3.

[Structured follow-up evidence](../../../reports/2026-11-08-walker-strikes/handoff-validation.json) separates this run from the earlier Studio scenarios. BT-62 comment10375 already links the Walker animation/source evidence; BT-37 and BT-26 track source/acceptance limits. The completed checkbox records publication/handoff, not completion of those broader Jira tasks. No new gameplay implementation is required by the review.

This continuation does not rerun Studio, the separate NPC-heavy case, full unprepared combat, physical devices or real reconnect. Those remain open exactly as disclosed in the report.
