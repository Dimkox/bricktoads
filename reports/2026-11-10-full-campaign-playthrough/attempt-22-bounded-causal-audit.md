# Native22 Causeway: bounded causal audit

Run `bricktoads-qa-22-00-5530a024`, seed1158731273. Times are seconds after
Causeway entry at1794332595.979177. This is a read-only audit of the existing
motion, detail and natural archive; no Studio, policy, production or Git
changes were made. The companion JSON records exact source file hashes.

## Four deaths

| Attempt | Established cause | Evidence |
| --- | --- | --- |
| 1, actor2 | Fall confirmed; initiating cause unknown because the detailed evidence expired | Death+35.826404 at X8.152/Y-36.097/Z-51.129, velocity3.824/-135.033/-29.524, Life47 immediately before death. Motion starts only+108.606491; the last256 journal events start+117.927416. The preceding retained sparse observation at+31.825932 is X12.554/Y3/Z-10.859, target Pig-4. This cannot establish a subsequent NPC hit, own jump or accepted steering. Life47 alone does not establish absence of earlier damage. |
| 2, actor43 | Ordinary NPC Dragon-10 Headbutt applies impulse/reaction, then the body leaves a cliff support | Hit+136.492243, DragonHeadbutt/profile22, X268.805/Y2.999/Z3.566, Life47→31. At+136.623 body velocity is approximately-10.416/-5.659/+14.055 and statePlatformStanding. It crosses the second cliff's lateral and longitudinal support bounds. Recovery Jump is only planned at+136.873, already X265.330/Y0.541/Z8.531 during reaction. Fall+137.413198 at X262.520/Y-36.289/Z12.431. |
| 3, actor150 | Shield blocks Headbutt HP damage but not its ordinary impulse/reaction; later recovery is too late | Hit+139.019438 from Dragon-10, profile22, X256.337/Y3/Z6.758, blockedtrue, Life47→47. At+139.047 body velocity is approximately-45.767/+14.744/+10.189. It is driven backward over the first cliff. Late Jump plans+140.5834 and+140.7218 occur near X232/Y0.735→-1.030/Z15.141→16.568, alreadyFallingDown beyond the cliff's lateral boundary. Fall+141.192409 at X230.906/Y-35.133/Z22.019. |
| 4, actor155 | Guardian Bullet is already lethal before the final knockback fall; no own QA Jump is requested in this sequence | Bullet/Dash hit+222.638781 inside the arena at X611.491/Y3/Z-5.919, profile22, Life31→15. The body later remainsFallingDown and nearly stationary near X601.965/Y1.997/Z-11.220 despite movement plans. A second Bullet/Dash hit+225.220892, profile21, reduces Life15→0 withdying=true. Its impulse has VX-32.002/VZ-11.483 and carries the already dying body past the arena's left edge. Fall+225.990889 at X577.427/Y-35.277/Z-20.024; Lost with two Guardian returns. |

The two Dragon hits are direct ordinary NPC Headbutts, not DragonFire
projectiles. GuardianPattern's Heavy ball does not damage a hero in flight;
its Bullet branch is the branch that invokes hero Dash damage. Both final
Guardian hits are therefore Bullet contacts. The last Hit's lethal damage
precedes the journal's Fall reason; it should not be described as a healthy
body lost solely to a navigation jump.

All QA plans after+200s havejump=false. The upward velocity near+223.519
therefore is not evidence of an own QA Jump. Its precise native Humanoid
recovery cause is not recorded and remains unassigned.

## Actual seed geometry

Bounds were read from `CampaignDefinition.build(1,1158731273)`, rather than
the unvaried LevelDefinition:

- Aqueduct first support: X4–54, Z-23…17.
- Courtyard: X128–228, Z-30…22.
- First cliff: X228–260, Z-6…14; second cliff: X265–297, Z-15…7.
- Guardian court: X594–696, Z-35…35.

Attempt2's Hit is on the second cliff; its subsequent X<265/Z>7 trajectory
leaves support. Attempt3's Hit is on the first cliff; the later X232/Z>14
position is outside that cliff and still beyond the Courtyard's X228 end.
The lethal Guardian Hit is inside the court; the following impulse crosses
X594. These bounds supersede any comparison against the unvaried map.

## Concrete input-policy counterexamples before another full run

Guardian evasion is not established by the newest requested direction. At
+222.453 and+222.587 the plan requests Z-0.973892, while the last native frame
still has VZ+14.444. The Bullet hits+222.6388, approximately52ms after that
last plan. The preceding plans alternate signs around the bullet corridor.
The ordinary motion log contains requested plans, not accepted native Move
timestamps, so this does not isolate transport from the evasion controller.
The transport investigation is separate.

Recovery is another bounded counterexample: from+224.719 through+225.102,
plans keep requesting Move(-0.387604,+0.921826), yet theFallingDown body stays
at X601.965/Y1.997/Z-11.220 with nearly zero velocity. The next Bullet is
lethal. A fresh full campaign would not determine why that state fails to
recover; a focused observation needs the native Humanoid recovery state and
accepted input, together with live Bullet position/destination/speed.

Native21 provides an additional own-input example, without proving Native22
death1. On seed844260480 the first Aqueduct support has Z-14…22. At+41.8418
the body is X36.815/Y3/Z-14.580 and requests an inward Jump. It then rises but
halts near Z-16.448 under neutral plans+42.1089…42.3584 and falls+42.8473.
The last preceding damage was Walker-6 EnemyRunStrike at+36.4778, over five
seconds earlier. This is a late edge recovery / absent airborne correction
counterexample, not a newly received hit at the takeoff.

## Narrow observation requirement

Native22's first cause cannot be reconstructed from the surviving files.
On the next first stock drop, freeze and export the current motion and
detail immediately, before the900 motion /256 journal retention trims that
death. This requires no Bridge source change. For a focused Guardian check,
retain Bullet id/position/destination/speed plus acceptedMove time and
Humanoid state around the first contact and recovery. No additional blind
all-seed search or source physics change follows from this audit.
