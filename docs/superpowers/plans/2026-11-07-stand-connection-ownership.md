# BT-13: current connection ownership and return contracts

Base: `6649ba1ff3fb99ba0840581b07010bffb4ba7eda`, existing feature branch / draft PR #2. The user's next-step instruction authorizes this slice and its GitHub/Jira sync.

## Contract and scope

Only the latest server-observed Player object for an account may receive its role or send Intent, including Sync/Start. Repeated join/remove callbacks are idempotent. Superseded/removed objects never become fallback owners. A fresh object returning to an existing hero preserves current actor, attempt, Life, reserves and protection deadline; already accepted attacks continue. Offline death waits for a connected owner before one allowed respawn.

Use a small pure ConnectionRegistry with weak object metadata and current-by-UserId binding. Apply it at the real gateway before rate limits, roster construction and snapshots. Keep Core/Session/game calibration unchanged.

## Tasks

1. Reproduce the current gateway using the **actual Stand source** and deterministic service/transport doubles. Test duplicate PlayerAdded, overlapping same-account objects, stale-object command with a current epoch, late removal, no fallback, unique host/roster and state preservation. This is a gateway contract fixture, explicitly not an authenticated Roblox reconnect.
2. Add failing registry tests, implement Registry.new/join/remove/isCurrent/online, integrate it into Stand, then run the same gateway regressions and native suites. Add meaningful return-state coverage using the real Session/Core and FakeWorld.
3. Through Studio MCP verify the generated runtime Source, run real-client security and disconnect/late-join regressions, save evidence and exact source/build hashes. Investigate genuine same-user return capability separately; never change UserId or relabel a new client as proof.
4. Independent review, compile/build checks, feature push, CI and Jira sync. BT-13 stays in progress until genuine transport return, level/role routing and other full-scope acceptance are verified.

## Current platform evidence

StudioTestService.AddPlayers accepts only a count; its args are test payload, not an identity selector. Reflection confirms that API. CombatStand is currently a local file with PlaceId=0 and GameId=0. Roblox added TeleportAsync testing in Test/Team Test on5 November2026; the old blanket 'teleports cannot run in Studio' is obsolete. Same-experience A→B→reserved A is a potential genuine return route, requiring valid place identities and proof of the same live server/actor. Empty JobId/PrivateServerId in local Test cannot prove sameness.

## Review focus

- No stale object can obtain current mine/connectionEpoch or issue a command by borrowing the current payload.
- Weak metadata does not retain every disconnected Player forever; current bindings remain strong until remove/replacement.
- Unique roster/host selection does not resurrect a displaced object when its replacement leaves.
- No fake-object/native fixture is described as a successful real-user reconnect.
- Existing real-client Start, Sync, snapshot fanout limits, input and late-join spectator still work.
