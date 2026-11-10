# Scooter network acceptance

This test launches **actual Studio clients** and drives the production `Intent`/`State` RemoteEvents automatically. It does not exercise human keyboard, touch or menu UI. The server prepares campaign stage 3 after the real clients select heroes and start; traversal then uses client input only. It creates no synthetic players and writes no hero pose, HP or respawn stock during the course.

Expected production BuildId:

```text
b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff
```

## Run in an owned Studio helper

1. Open a fresh, owned copy of `places/BrickToadsPlayable.rbxlx` in idle **Edit**. Keep the user's `places/BrickToads.rbxlx` and original Studio untouched. The embedded BuildInfo must match the expected BuildId.
2. Create `ServerScriptService.BrickToads.ScooterNetworkAcceptance` as a **ModuleScript** containing the complete source of `tools/studio_scooter_network_acceptance.luau`.
3. In the helper's `ServerScriptService.BrickToads.BrickToadsServer`, insert this one hook immediately before the first `if RunService:IsStudio() then`, after the MatchHub `controller` is created:

   ```luau
   require(script.Parent:WaitForChild("ScooterNetworkAcceptance")).install(controller)
   ```

4. Create the **LocalScript** `StarterPlayer.StarterPlayerScripts.ScooterNetworkClient` containing `tests/scooter_network/Client.client.luau`. It disables only `PlayerScripts.BrickToads.BrickToadsClient` to own the input sequence. The server creates the test bridge only for the tagged StudioTestService session; clients do not call `GetTestArgs`.
5. Evaluate the complete source of `tools/studio_launch_scooter_network.luau` as a function in that helper's Edit DataModel, then invoke its returned launcher with the following options. Use a fresh `name` for every run; `players` supports integers **1–3**.

   ```luau
   {
       name = "Heroes1Rendered",
       players = 1,
       scenario = "Heroes",
       seed = 41,
       timeoutSeconds = 180,
       sourceId = "b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff",
       networkProfile = "Unmodified baseline; recorded Studio settings",
   }
   ```

The launcher calls `ExecuteMultiplayerTestAsync`; it returns before the test finishes. Poll `ServerStorage.BrickToadsScooterNetworkEvidence.<name>` in the same Edit DataModel. Its `Status` becomes `PASS`, `FAIL` or `ERROR`. On completion, concatenate `Chunk0001` through the declared `Chunks` count, in order, and JSON-decode the result. Preserve that complete JSON, including failures, startup diagnostics and the six recorded network settings. An `ERROR` may instead contain a `Failure` StringValue.

The server calls `EndTest(results)` on completion or failure and has an independent 180-second watchdog for these options. The Edit launcher has a further 45-second evidence deadline; an Edit deadline alone does not prove server teardown.

## What the result establishes

Readiness requires an ordered production snapshot, a connected command listener and at least two `RenderStepped` frames. Small one-second client Heartbeats record rendering, snapshot and command/reply progress, with bounded history. RemoteEvent sends are reported separately from server acceptance.

The pilot defeats the entry patrol, waits for teammates before boarding, then steers and jumps through the actual course. The server independently observes every hero mounted, receiving mode input and reaching **`course.finishPoint.x - 45`** before transition. Production advances the team when its **first finisher** clears; this test does not require every hero's individual `finished` flag. Final checks compare body ActorId, attempt and respawn stock across the earned stage-4 transition; raw Life is recorded separately, including the normal next-stage restoration.

The completed one/two/three-client runs in `reports/2026-11-09-scooter-network-acceptance/` passed **47/85/114 checks** in **50.418/65.352/80.473 seconds** total. Every hero reached checkpoint3, produced four accepted jumps, and reached stage4 with the same body identity, attempt1 and three respawns; final raw Life was47. See `course-summary.json` and each full `heroes<N>-rendered.json` receipt for measured times and individual progress.

Earlier `heroes3-startup-ready45-fail.json`, `heroes3-startup-ready90-fail.json` and `heroes3-ready-barrier-fail.json` remain in that report folder. They show cold-start readiness and missing-command failures, including Ready before rendering had settled. The later render barrier and diagnostic changes do not by themselves establish a general fix for multiplayer command loss.

## Local and CI checks

From the repository root:

```powershell
.tools/luau-0.745/luau-compile.exe tests/scooter_network/Client.client.luau
.tools/python-3.13.9/python.exe tests/scooter_network/test_client_ready_order.py
```

The readiness runner executes the **actual client source** with deterministic early/later State delivery and render-frame doubles. It checks the readiness barrier, the production menu envelope, exactly one Ready and the bounded Heartbeat interval. CI runs it with `--luau /tmp/bricktoads-luau/luau` in `.github/workflows/lifecycle.yml` and compiles the client and both Studio helpers. These checks verify the driver and its syntax; actual Studio multiplayer acceptance requires the JSON receipts above.
