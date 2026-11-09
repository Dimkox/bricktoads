# Private Team Test transport preflight

`TeamTestTransport.server.luau` is a standalone capability probe for the private experience10775039796/place117412694427208 and actual owner UserId11946162891. Its exact place/universe guard runs before creating any objects. It deliberately does not require IsStudio, so the private Team Test destination server may execute it. It is not part of the production place builder and establishes no game character/resource acceptance.

Install it as a ServerScriptService Script in the owned private fixture before starting the intended native UI Team Test. The destination place must contain the same script. From the actual owner's Client context, trigger:

```luau
game.ReplicatedStorage.BrickToadsTeamTestTransport.Command:FireServer({kind = "Start"})
```

Read `ReplicatedStorage.BrickToadsTeamTestTransport.Result.Value` in each reached context. The JSON records only routing IDs, server-generated marker, actual UserIds, event times, heartbeat and transport observations. TeleportData carries only tag/nonce/A/B routing and stage. A returned TeleportAsync result alone does not count as transition success.

Route: origin → fresh reserved A → fresh reserved B → the original reserved A. Arena and transit wait2seconds before their next leg. Every activated server has a120-second watchdog; origin/transit record their completed departure leg without issuing overall PASS. Errors and TeleportInitFailed are terminal, without retry loops.

To test whether the native Team Test **origin** remains alive under its manager, use the optional route:

```luau
game.ReplicatedStorage.BrickToadsTeamTestTransport.Command:FireServer({kind = "Start", route = "TeamTestOrigin"})
```

This arms the dummy probe in the original Team Test server before leaving. Its current36-character JobId is routing-only `originJobId`; the owner travels to fresh reserved B, then returns with `TeleportOptions.ServerInstanceId` targeting that exact original JobId. No marker, resources or probe state are copied. The same original-RAM/removal/instance/heartbeat checks decide the result. The default reserved-A route is retained unchanged.

Only the original A runtime can PASS: it must retain the original server GUID, same dummy server Instance, original actual Player removal, a new actual Player of the same UserId, matching nonce and heartbeats advanced while away. A newly booted A explicitly FAILs rather than recreating the probe. This is transport-only; even PASS requires a separate current-game observer to prove character, health, respawn stock and control preservation.
