# Actual same-player reconnect: native Team Test probes

09 November2026. This checkpoint uses native UI **Team Test** in the existing private BrickToads Reconnect Test experience, rather than Server & Clients. **Current-game same-body/resource reconnect is NOT accepted.** Both bounded transport probes failed the required retained-runtime condition or return transport.

## Environment and evidence

Universe10775039796/place117412694427208, actual authenticated owner UserId11946162891. [Initial private universe, saved version79 and50-script manifest](private-edit-baseline.json). UI Studio0.746.0.7461269; actual cloud server reports0.746.0.7461264. The saved test versions observed by the actual client were81 and82. The server Script was installed and saved in Edit before each run; client reads are of server-created replicated JSON. No code was injected into the read-only Team Test server mirror.

[Pre-test local backup receipt](backup-metadata.json):1,368,243bytes, SHA256 `27e63a2d401959716b0f76fdc2f43b7b38eb009d355e536d7a6af0c00ff22732`, outside Git at `C:/Temp/bricktoads-private-version79-before-team-test.rbxl`.

The [test fixture](../../tests/reconnect/TeamTestTransport.server.luau) allows only the exact private place/universe and actual owner. TeleportData contains routing/tag/nonce/stage only, never health, lives, character data, server marker or a replacement observer. PASS requires the original server-local arena table, original probe Instance pointer/GUID, an actual original Player removal, a new actual Player with the same UserId, current Players registry identity and heartbeats while that owner is absent. Recreated A cannot manufacture those references. This is a dummy-instance transport gate, not game-body acceptance even if PASS.

## Probe1: reserved A → B → same reserved A

[Original client receipt](origin-client.json), [request/loading/return tool trace](reserved-a-route-tool-trace.json), [returned actual client](after-route-client.json), [exact version81 fixture source](reserved-a-preflight-source.luau).

Origin job `eaf2e27f-9105-429a-bc01-4a9936fa5294`; the actual same positive UserId completed origin→A→B→ReturnArena. Returned job `aa6cb058-c010-4364-80b4-dc13eed4798b`, server marker `5999668c-3b81-4067-9577-6a79ec1135b4`. ReturnArena ran in a fresh context: no original arena RAM, original removal record or retained probe. **FAIL:1 check passed,9 failed.** The one passing check is the actual current Player; original-identity comparisons fail because original arena evidence is absent, not because a different UserId was substituted. Empty reserved-A retention is not established. No game state was restored from a snapshot.

MCP calls during teleport briefly reported unreachable Client/Server; those loading observations are retained in the trace, not counted as test failures or successes. A later actual-client read produced the terminal result.

## Probe2: return to the exact original Team Test JobId

[Origin version82](origin-return-before-client.json), [start request](origin-return-start.json), [actual transit and exact target](origin-return-transit-client.json), [terminal native failure](origin-return-final-failure.json), [exact fixture source](origin-return-preflight-source.luau).

Original Team Test job `85c32c4f-25d7-4388-811e-ce1289131e56` was armed before departure. The real owner reached transit job `7205ed75-3e36-4889-89aa-ba007badb275`. Transit used **only** `TeleportOptions.ServerInstanceId` with that original JobId. TeleportAsync returned successfully at1794248275.217027, but the player did not return. The actual server then emitted `TeleportInitFailed`, `Enum.TeleportResult.Failure`, at1794248315.798476:

> Unable to join the destination place: Timeout when fetching TeamTest launch config

The fixture terminated FAIL after42.586394seconds from transit activation. Studio also visibly displayed Teleport Failed/Error Code769. This establishes failure of this exact route in this environment; it does not establish the lifetime of the inaccessible original Team Test server. No blind retry or alternative identity was used.

## Remaining acceptance

A second genuine authorized account must remain in the original joinable server while the owner leaves and returns. That participant is not available to these tools; the user was asked to arrange one. AddPlayers/new negative test UserIds, duplicate/spoofed Player.UserId, bots or a re-created server do not replace the same-player requirement.

After transport is possible, the current-game observer must still prove original MatchHub/group/run/controller/Session/world/actor/Model/root identity, current health and respawn stock/attempt, no new spawn/shield, epoch+2, stale-epoch rejection and fresh-input movement. Keep levelEpoch unchanged when checking reconnect did not heal: ordinary level progression intentionally heals surviving heroes. Offline death/paid respawn and other role-specific cases remain separate. Read-only production path review found no concrete reconnect reset defect, so production behavior was not changed to satisfy this probe.

## Verification and cleanup

[Local validation](local-validation.json): fixture compiles; Lifecycle46, GameController43 and MatchHub22 checks pass; the production place builder check passes. These111 local checks are separate from the two failed native probes.

[Cleanup summary](cleanup-summary.json) and [Edit manifest](cleanup-edit-manifest.json): both Team Tests stopped; the temporary Script was removed and cleanup saved through Studio UI. Original Edit JobId restored, same50 production script paths/classes/byte lengths. This is a manifest comparison, not a full cloud-place binary equality claim. Production playable remains1,020,211bytes/SHA256 `1102ac79b23efc210a1fdd4bad6907bde9d883cbcab0cbb468213b00a70d40df`; protected user starter remains SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`. Concurrent model/art work is excluded. No public publish, access/security changes or collaborator invitations were performed.

Primary platform references: [Studio teleport support](https://devforum.roblox.com/t/test-teleports-in-studio/4977640), [destination must be saved](https://devforum.roblox.com/t/test-teleports-in-studio/4977640?page=2), [testing modes](https://create.roblox.com/docs/studio/testing-modes), [read-only Team Test server inspection](https://devforum.roblox.com/t/studio-beta-inspect-your-live-server-during-team-test/4966700), [TeleportOptions routing](https://create.roblox.com/docs/reference/engine/classes/TeleportOptions.md).
