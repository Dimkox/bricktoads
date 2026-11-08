# BT-13: actual Studio transport return

Continue after the user's request to test “как в игре” and explicit direction to use Roblox Studio MCP. Current code base: ce518f5. The private Roblox experience now exists: universe10775039796, root place117412694427208, confirmed visibilityPRIVATE through Open Cloud GET. It was created with Save to Roblox, without a public release.

## Execution

1. Probe actual TeleportAsync support before constructing the full fixture. A Studio-only tagged script teleports both real test clients to a distinct ReservedServerId of the same place, checks preserved UserIds/different server marker and records whether destination EndTest reaches the launcher. Do not assume test args propagation or saved source availability.
2. If transport is confirmed, use one place and two reserved-server GUIDs. Origin bootstraps both clients into arena A. Arena starts via real State.host, maps UserIds through State.mine, preserves actor/run/server marker and sends returning owner to transit B. Anchor remains A, damages offline owner with real Dash, then owner returns to the original reserved A.
3. Assert same UserId/new Player object, same live anchor/arena marker/actor instance/run/attempt/reserves, current Life31 and epoch+2. Never Start/reset on return; missing original state is FAIL. Preserve actual failures and unknowns.
4. Compile, independently review evidence, archive exact source/build hashes, push test artifacts and sync Jira. No genuine same-user PASS is claimed until observed through the engine. Production gateway/Core/calibration need no speculative changes.

All further control is through Roblox Studio MCP. The local change in places/BrickToads.rbxlx predates this work and is outside the transport probe; preserve it.
