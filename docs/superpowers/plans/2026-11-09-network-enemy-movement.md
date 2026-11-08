# Restore server simulation after enemy rig assembly

Continue BT-25/26 after the running/mobile slice da12b18. The owner asked to continue implementing the game; preserve flat terrain, player-controlled trajectories, one-life enemy roles and the dirty user starter.

Actual two-client reproduction on source ca590a35: Player1 starts as hero; Player2 claims Pig-1 through the normal UI, then holds A. The accepted client Move vectors reach the server, but 19 sampled enemy frames remain Idle/vx0 at x-34.9996. The fully assembled enemy root has automatic network ownership and belongs to Player2; hero roots remain explicitly server-owned. BaseWorld pins its simple rig before GameWorld adds enemy art. The rebuilt assembly can lose that explicit ownership assignment. Claim only updates identity/nameplate.

Single-variable diagnostic: manually call SetNetworkOwner(nil) on that same enemy root, then repeat ordinary A. Ownership becomes server/manual and the same body walks at vx-9. No HP, life, position or kill helper was used. This intervention is diagnostic, not a fresh final-code acceptance result.

- [x] Reproduce the assembly-reset ownership boundary in meaningful world contracts; get RED.
- [x] Pin complete enemy assemblies to the server after final rig/appearance and at any required same-body ownership boundary. Preserve strict failure behavior and actor identity.
- [x] Compile/run affected native and build checks; independent review.
- [x] Synchronize exact sources in Studio and start a fresh two-client game. Verify hero/NPC/human enemy ownership, real walk/run/jump/strike through native input without the diagnostic ownership setter.
- [x] Record honest results, push the existing branch and update PR3/Jira. A full route, real reconnect and physical devices remain unaccepted unless actually exercised.

Additional confirmed boundary: real two-client isolated World API pickup/removal of the club reset manual ownership to automatic Player1. Both operations now pin after completion, using the saved owner on removal; native RED→GREEN and physical Walk16/Run24/continuedRun24 pass on the final source.

Final source2a4d441f5989e5561b8a06f5bbe5a18799a605575671f45ddd02ef4898a01f08, full34/34/compiler91/world40, independent review with no actionable blockers. Final two-client run9265bbec-d31a-417a-8c9a-2347d30f851a confirms same-body enemy Walk9/Run16/run-jump and actual primary EnemyRunStrike47→31 with no diagnostic ownership setter. Hero counterattack interrupted by NPC/REACTION is explicitly not a hero-mega PASS. All31 sources matched after fixture/client cleanup; final delivery uses the existing branch/PR3 and Jira comments.
