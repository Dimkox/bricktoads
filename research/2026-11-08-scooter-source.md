# Next2.5D scooter mode: source contract

Read-only audit of `feos-tas/DisAssemble` commit `f1a43b69577246850d136473700a333b3cdfe93f`: [main ASM](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/Battletoads%20%28U%29%20%5B%21%5D.asm), [configuration](https://github.com/feos-tas/DisAssemble/blob/f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/data/levels_cfgs1.asm). This is preparation for BT-27/28/29, not a running scooter scene or measured frame trace.

| Mechanic | Verified source behaviour | Main ASM evidence |
|---|---|---|
| Automatic progression | Mounted original players and camera advance separately from directional steering |24035–24047,24156–24176,24483–24489|
| Speed | Fractional increment8/256 per update; cap8, later12 after camera high byteDD |24110–24119,24132–24180|
| Steering | Continuous four-direction movement; depth clampC0..E7 |6054,7398–7445,30691–30721|
| Jump | Fresh A, allowed mounted state, floor-relative height<12hex, flag08clear; source lift2+80/256 |7663–7679,7702–7715,7751–7754|
| Ramp | Object24, collision and per-player launch latch |9945–10009|
| Crash | Bespoke valid collision sets Life0/death animation, stops scrolling and clears bike speed |9846–9880,9924–9938,10014–10033|
| Camera edges | Rider X is clamped at screen16/ED, with speed/camera locking; no behind-camera death timer |7651–7657,5887–5924|
| Checkpoint | Mounted contact26 records config restart, slows integer auto speed to2 when≥4 |9878–9904|
| Restart | Group camera/config rewind; original riders reposition together and speed clears |28295–28352,28498–28508|
| Finish | Camera boundaryFC, restricted final movement/countdown, then level complete; no boss-defeat requirement |24500–24590|

Source restart puts both original riders at checkpoint X+30hex while camera returns to checkpoint X−30hex; depthCC/DC, height50hex. Extending to1–3 heroes requires an explicit third depth placement and preservation of survivor bodies/resources. Repositioning a survivor must not consume a respawn. Actual crashed heroes use the one existing lifecycle budget, successful respawn5/5 and accepted protection; original checkpoint code clearing protection must not override Brick Toads D-02.

The source's vehicle collision uses asymmetric byte-Z comparisons, not generic symmetric boxes. Obstacle23/25/29/2A/2B thresholds at9853–9877,10049–10053 are raw coordinates. Original new course geometry, swept crossings and calibrated units must be authored separately; do not copy obstacle order from the reference.

The available ordinary enemy role is rat-on-rocket object28, with dropped obstacle29 (dispatch5769–5773, behaviour10088–10140, falling-object9712–9726; example records196–201,222,248–249 establish role existence only). A human adaptation may control an allowed drop while the server retains the scripted encounter trajectory/expiry. Manual free flight, combat powers, a bike boss or a one-drop-per-pass latch are not established by this audit. Drop budget/cooldown and three-player placements are explicit future tuning decisions.

Suggested bounded integration: one group mode with Mounting/Riding/Crashing/CheckpointRestart/Finishing/Completed, existing fixed roster/actor epochs, continuous depth/relative X/jump state, bounded authored obstacle encounters and swept collisions. Offline bodies continue automatic movement/collision; only new input stops. Lifecycle alone owns resource spending/elimination. This contract is not yet implemented or engine-tested.
