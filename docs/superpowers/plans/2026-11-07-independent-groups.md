# Independent local groups implementation plan

**Goal:** Let an eliminated hero or observer create/join a separate group and choose an eligible enemy role while the previous group continues; share guardian FIFO across groups.

**Spec:** BT-59, BT-24/25 and BT-10 D-03.1/D-04/D-07. Existing prototype mechanics remain unchanged. Topology is one server with separate world folders and arenas spaced512 studs apart on Z. Technical capacity:4 groups, disclosed in config; no Teleport or cross-server recovery claim.

**Architecture:** MatchHub owns current Player authority, selected group and global role exclusion. Each group retains its own GameController, Session, actors and run. One BossQueue dispatches selected guardians among eligible group/run slots. Group selection changes the snapshot and camera world; a living role cannot be abandoned for a second role. Eliminated membership remains in the previous run to reject same-group enemy reentry.

## Interfaces

- `MatchHub.new(deps, worldFactory(index,groupId))`, where deps includes existing Core/Combat/Session/Registry/Config/Director/BossQueue/Controller/clock/guid. It creates group1, and exposes `groups[id]={id,name,controller,world}`, `order`, `routes[userId]`, `queue`.
- Methods: `join(player)`, `leave(player)`, `handle(player,payload,players)->code`, `snapshot(player,players)`, `step(now,dt)`, `selected(player)->group`, `controlledSlot(userId)->slot,world`.
- Hub joins a Player only to its selected controller; `members(groupId,players)` filters current connections by route. A replacement Player returns to the stored route/owned body. Views do not alter old-run ownerSlots or spent enemy lives.
- `Config.Groups={maxGroups=4,spacing=512}`. World factory calls `GameWorld.new(BaseWorld,config,{name='BrickToadsWorld_'..groupId,offset={x=0,y=0,z=(index-1)*512}})`. Default world remains `BrickToadsWorld` at zero offset. World folder attribute GroupId is set by factory.
- GameController receives `deps.SharedBossQueue` and `deps.GroupId`. Session constructor optional context `{groupId,levelId}` removes the stand-only group identity from game sessions. Boss slot context includes groupId. Existing stand/test constructors remain compatible.
- Gameplay snapshots add `groupId`, `groupName`, `worldName`, `groups={id,name,status,heroes,players,canJoin,reason}`, `canCreateGroup`. BossQueue view adds groupId/groupName for an offered target; MatchHub may derive these from slot identity.
- Every client packet except initial Sync includes current `groupId`. Hub checks it and strips only that envelope key before strict Controller validation. `JoinGroup{kind,groupId,targetGroupId}` and `CreateGroup{kind,groupId,requestId}` are strict, current-sender, rate-limited and idempotent. Group IDs/request IDs are bounded strings. Missing/stale group cannot start or modify another group.
- ReplyBoss/ConnectBoss route through the global offer token. Accepted invitation moves the observer to the target group; old-view groupId is checked before that move. Duplicate accepted replies from the now-current group remain idempotent. Ordinary claims remove waiting only after success. Eligibility rejects any living role and same-run hero history in the proposed target group.
- Client `GroupPanel` is menu scroll order8 or a compact collapsed observer HUD control; expanded group picker must fit touch landscape. It shows current group and other groups, create/join actions, progress and denial reason. Living heroes/enemies cannot switch. Selecting an active group observes it; it does not add a hero. A queue invitation identifies its target group.
- SpectatorCamera resolves only snapshot.worldName, so groups cannot show/control each other's actors. All world geometry/spawns/projectiles and exit/safe-point checks use the group's coordinate offset.

## Work

- [x] MatchHub: write failing native tests for independent starts/results, duplicate requests, stale envelopes, live-role exclusion, eliminated cross-group selection and shared FIFO; implement.
- [x] World: namespace/offset geometry, actor origins, local Director coordinates, projectiles, exits and camera lookup; retain default-world compatibility.
- [x] Gateway: optional Session context, shared queue injection, authoritative group snapshots, server replication focus and per-group presentation.
- [x] Client: bound send wrapper plus responsive group picker and target group on guardian invitation.
- [x] Verify native suites/build/compile, independent review, and actual multi-client isolation and role transfer in Studio. Keep user-modified places/BrickToads.rbxlx untouched.

## Verification

Native groups11, world/camera coordinate groups3, Session39, Controller36, Director30, queue20, lifecycle46, connection18 and gateway14 pass; builder7 and compile pass. Independent review found no P1/P2 issues. Four-client Studio evidence confirms actual elimination, new independent run, isolated loss, cross-group ordinary takeover, scoped human-enemy damage, shared guardian invitation/transfer and a reflected human-fired projectile in the Z512 arena. Phone emulation checks layout; desktop buttons were used for creation/join.

Ruling: remove the former runtime's saved unscoped preview only when its exact name, OriginalArt flag and LevelName match and GroupId is absent. Live inspection found that old generated floor overlapping group1; independent named worlds are still preserved. See the report for preparation and limits.

## Review focus

Late old-group Start after switching; reconnect to owned active role; two simultaneous roles across groups; global guardian invite versus ordinary claim; cross-world hitboxes/camera/respawn origins. No public publication or main-branch merge.
