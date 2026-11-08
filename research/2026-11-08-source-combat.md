# Source-state combat transfer

Primary source checkout: `feos-tas/DisAssemble` at `f1a43b69577246850d136473700a333b3cdfe93f`. [Main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [animation actions](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/anims_moves.asm), [first-level records](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm). Read-only static inspection; no emulator/Studio timing trace. No original executable, artwork or animation assets are included in the runtime.

## Hero primary

After the contextual selector returns ordinary target0, main7150–7245 chooses the following finite source action. Existing pickup/held/weapon/fly/grab interactions retain priority in this adaptation.

| Target state | Animation | Ordinary profile/raw | Hero profile/raw | Internal action |
|---|---|---|---|---|
| Normal Life≥4, low nibble≥4 |02/04|0/2|18/4|HeroJab|
| Normal Life≥4, low nibble<4 |06|2/16|20/16|HeroUppercut|
| Same condition, Dragon type17 |36|10/8|28/8|HeroElbow|
| Normal Life<4 |0E|3/255|21/255|HeroPowerPunch|
| Heavy reaction, Life≥8 |12|1/8|19/8|HeroKick|
| Heavy reaction, Life<8 |14|6/255|24/255|HeroBoot|
| Running, qualifying heavy target |14|6/255|24/255|HeroBoot|
| Other running result |16|4/16|22/16|Dash|

Effect decoding: animation data71–74,81,89–96,106–107; main15778–15795 masks E2 base profile,15842–15850 adds18 for an actual hero victim. Only attacker animation16 substitutes profile3/hero21 when the **actual effect-time victim** has Life<16 (15829–15840). PigRush and DragonHeadbutt retain fixed22 against heroes. Source profile bytes at16591–16625 establish arithmetic, not Roblox impulses or seconds.

One accepted animation has one successful effect (source making-damage latch15780–15781,15821–15823; new animation clears it15527–15536). The current runtime performs one effect-time geometrical check, with no target lock. The source's repeated E2 miss opportunities/hold-and-cancel windows are not fully transferred. Existing R/Dash remains the prototype's explicit running-strike control; exact double-tap/run-input parity is not claimed. There is no new3-hit counter.

The hero input path6859–7245 does not establish a standalone jump-kick action. Ground conditions specifically gate grabs/pickups (3408,3460); ordinary attacks remain usable airborne with current geometry. Shared jump-labelled animation entries28/2A/40 are explicitly chosen by Pigs at17077–17107 and do not prove a hero move.

## Ordinary Life and recovery

Loader28889–28895 applies record final byte OR0F. The13 source-classified actors in the existing new geography therefore start at:

| Brick Toads IDs | Family | Source Life |
|---|---|---|
|-1,-2|ambush Pig|15,15|
|-3|Walker|31|
|-4,-5|Pig|31,31|
|-6|Walker|31|
|-7,-8|entrance/direct Pig|31,31|
|-9,-10|Dragon|31,47|
|-11,-12,-13|direct/direct/ambush Pig|31,31,15|

Record evidence: levels_cfgs1.asm7,8,9,12,13,14,16,20,22,23,25,27,28. Entrance transformations preserve Life at16834–16855,8451–8475; ambush transformation9620–9657. Static actor classification is not a verified dynamic natural-play population.

`gen_damage_effects`16522–16547 applies the same subtraction/underflow/high-nibble OR0F rule to ordinary actors and heroes. In particular16−16 becomes15 without death because the high nibble crosses;2−2 stays0 without underflow. Only a subsequent underflow is lethal. Three displayed hearts scale actual source Life to its initial maximum; the display does not drive damage or source nibble tests. The three different initial Life capacities are not silently replaced by one3HP combat budget.

Generic hit selection3173–3187 rejects death/protected linkage, not every reaction timer. Repeated eligible hits can therefore interrupt reactions. For example, before reaction recovery a raw31 ordinary target follows31→29→27→25→23→21→19, then uppercut19→15, heavy kick15→7, boot→underflow. Waiting instead permits OR7 recovery. Source completion helper5955–5984 performs that recovery; Pig/Walker reaction paths reach it through16672–16723 and16754–16758/4633. Hero heavy reaction has separate protection at6594–6604 and skips light recovery. Throwing an ordinary object chooses offset55/profile17/raw4 at16183–16197; its original motion/collateral effects remain separate from the adapted finite throw.

Modern policy is installed by SourceCombat; standalone legacy scenes keep their existing reaction policy. Overdue recovery is applied before selection/effect, and post-heavy protection ends relative to the original reaction deadline instead of restarting on a late server step. Roblox NPC reactions1.05/.85s, hero protection28/60s, calibrated impulses and original motor poses are explicitly engineering tuning. Source frame parity, complete hero hold/cancel timing and exact thrown-body physics are not established.

Grab caveat: the source primary pass uses mask3F at7112, which removes bit40 in3185–3187/3222–3231; a close Pig grab can precede the later heavy selector3395–3413. The previous grab note's general heavy-exclusion wording is too broad for that caller. This batch retains the prototype's accepted close-grab exclusion during reaction as an adaptation rather than claiming exact parity.

## Dragon primary and remaining family mechanics

Normal Dragon dispatch2943 reaches the shared flying handler5050. Current contact selects animation32 at5214–5222; animation table26/135 has E2 parameter84, whose base profile4 becomes hero22/raw16. Animation32 is not animation16, so it cannot inherit Dash finisher21. Headbutt selection and effect both use current collision scans; no guaranteed target-locked damage is inferred.

The existing ordinary primary now uses DragonHeadbutt for NPC and human F: windup.35s, cooldown1.25s, reach6/width3/height4studs, recovery pose.25s and original neck/wing posture. These are prototype calibration. Unknown legacy actors retain the prior3HP path; actual current-level source actors use explicit raw Life/profile4 damage. No ordinary Dragon fireball is invented.

Full source flight has distinct launch/approach/turn states at5123–5174,5286–5355; current support-checked ground pursuit is not a complete transfer. Heavy-victim capture selects animation34 at5192–5208 and E4 linkage16055–16097. Hero mounting requires a disabled grounded Dragon and geometry/link checks3061–3094. Mounted-player fire is gated by the transport link in the hero input handler6892–6936 and frame8098–8101; it is not unmounted NPC ranged AI. These mechanics remain explicitly outstanding.

## Follow-up: prepared Dragon transport

`DragonFlight` now owns finite flight/turn/disabled/mounted/capture states over the same Director actor. `DragonWorld` is the Roblox boundary for gravity cancellation, root velocity, temporary same-body positioning and restoration; it does not claim a validated physics run. A surviving heavy hit stops flight, then a grounded contextual mount is available for six calibrated seconds. Rider Move steers; F fires; Jump or Dash dismounts. A mounted body is temporarily neutralized for this map's gates. It retains source Life, owner and one enemy life. Existing carried-Pig/guardian/fly priorities remain; mounting drops the equipped club.

Capture is a separate windup against a heavy-reaction hero, with a fresh effect-time scan, finite hold and release. Incoming impulse, changed actor/attempt, death or run end releases the old physical body first. It does not invent a second damage event. NPC/human unmounted Dragons have headbutt/capture, not ranged fire.

Mounted fire is source object1E: main9655–9712,20858–21057. The first-level collision path sets table byte offset14hex; `damage_from_table` adds5Ahex for actual hero victims: ordinary4/hero22, raw16. Source input6892–6936 caps live fire at two. Runtime keeps that cap per group, uses frozen accepted responses, swept sphere collision plus initial-overlap obstruction, and routes confirmed damage through existing shields and friendly fire.

Flight speed10studs/s, altitude1.5, turn.3s, lift4/.4s, disabled6s, mount reach5/height4, capture.25s+window.3s/hold1.25s, straight fire32studs/s/2s/radius1, dismount lift18 and original wing/link poses are explicit Roblox calibration. The source's complete vertical-velocity inheritance, exact target-type mask, random capture-release paths, flight-frame/input timing and motor/physics appearance remain unverified. Engine/device/reconnect acceptance is NOT RUN by owner instruction. Runtime preparation is not full source parity.
