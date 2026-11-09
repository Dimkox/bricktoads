# Actual-client enemy and crash acceptance

Use an unsaved, owned helper opened from `places/BrickToadsPlayable.rbxlx`. Keep the user's `places/BrickToads.rbxlx` and original Studio untouched.

Install the same client driver as the [hero course runbook](README.md): a LocalScript named `ScooterNetworkClient` in StarterPlayerScripts. Instead of the hero-course module, create `ServerScriptService.BrickToads.ScooterRoleNetworkAcceptance` from `tools/studio_scooter_role_network_acceptance.luau` and insert this test-only hook before the main server's first `if RunService:IsStudio() then`:

```luau
require(script.Parent.ScooterRoleNetworkAcceptance).install(controller)
```

Evaluate `tools/studio_launch_scooter_role_network.luau` in the helper's idle Edit DataModel, then call the returned function. Common options:

```luau
{
    name = "InvaderReturn2",
    scenario = "Invader",
    invaderOutcome = "Return",
    players = 2,
    heroes = 1,
    seed = 41,
    sourceId = "b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff",
    timeoutSeconds = 180,
    networkProfile = "Recorded local Studio settings",
}
```

Use a fresh name for every run and preserve failures.

| Scenario | Actual clients | Heroes | Other options |
| --- | --- | --- | --- |
| Invader return | 2 | 1 | `scenario="Invader", invaderOutcome="Return"` |
| Invader escape | 2 | 1 | `scenario="Invader", invaderOutcome="Escape"` |
| Authored-hazard crash | 3 | 3 | `scenario="HeroCrash"` |
| Human RocketRat drop/crash | 3 | 2 | `scenario="RocketRat"` |

Poll `ServerStorage.BrickToadsScooterRoleNetworkEvidence.<name>` in the same Edit instance. After Status becomes PASS/FAIL/ERROR, concatenate Chunk0001 through the Chunks count and JSON-decode. ERROR may instead contain a Failure StringValue. The active server owns EndTest cleanup and its bounded watchdog; the Edit evidence deadline alone does not prove teardown.

Actual clients choose roles and Start through production remotes. Only seed/stage3 are prepared on the server; live scenarios use actual client inputs. Invader claim is requested before diagnostic round trips consume its short unengaged window. A hero hit returns stolen Life only to the original actor; escape is a separate fresh run. HeroCrash steers one rider into authored danger while teammates follow the normal course. RocketRat follows its authored path; a human early drop must be distinguished from the automatic gate and a coincident static hazard. Its native obstacle callback is observed without changing its outcome.

Server snapshots, journal events, original/current body references and client readbacks provide separate evidence. A transmitted packet is not immediate server acceptance, and an updated server result alone is not proof that clients have received it. Final reports retain the exact source, client count, resource changes, test preparation and any incomplete conditions.

These automated clients disable presentation/UI to own their input sequence. They do not establish physical multitouch, human UI usability, Internet-network performance or registered-account reconnect.

Run local driver checks with the same commands as the hero runbook; CI also compiles both new helper files. Native receipts and limitations live in `reports/2026-11-09-scooter-role-network-acceptance/`.
