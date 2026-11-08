# BT-58: real-client command security

Authority: BT-58 and the existing CombatStand contract. This is the next technical slice authorized by the user's “далее”, not a redesign of game rules. Continue on the existing isolated feature branch `bt-18-combat-stand` / draft PR #2; main remains the integration base.

## Scope and approach

Extend the guarded Studio acceptance harness and send malformed, forged, repeated and stale payloads through real clients' Intent RemoteEvent. Observe server receipt, authoritative dump, physical actors and State delivery. Calling Session directly is supplementary coverage, not engine evidence. Keep all test bridges outside the generated game. No NPC/boss/level-routing implementation or claim of full BT-58 completion.

The existing runtime is tested first. Fix only reproduced defects; add a focused failing regression before changing production behavior. Preserve initial failed runs alongside final evidence. Same-user reconnect, physical devices and the previously unmet pending-disconnect precondition retain their previous status.

## Tasks

1. Add a `securityOnly` runner mode and client raw-packet/burst commands. Cover schema/numeric validation, server ownership, old actor/run identity, duplicate/reordered sequences, cooldown, rate limits, unauthorized Start and spectator commands. Confirm rejected commands preserve actor identity, Life, reserves and protection. Count State deliveries to detect amplification from Sync/rejected Start. Compile harness and run against unchanged runtime; save results, including FAIL.
2. Diagnose each real failure, write/retain the regression, make the smallest runtime fix and repeat affected engine cases. Extend native Session contracts for relevant omitted inputs. Verify valid commands still work after invalid packets, cooldown and bucket recovery.
3. Run native Luau, compilation, structural tests and deterministic builders; review the whole change independently. Record exact source/build hashes, Studio version, real-client evidence and limitations. Push the feature branch, verify CI and sync BT-58 / related work in Jira.

## Review focus

- Actual OnServerEvent sender determines ownership; attacker-supplied identifiers cannot acquire another actor.
- A client reply is not proof that its Intent was processed: wait for server receipt and a later authoritative snapshot.
- Rate-limit tests must record accepted/dropped traffic and recovery without assuming scheduler timing.
- Sequence advancement by valid rejected/cooldown/rate-limit packets follows the current contract; malformed/stale packets must not poison it.
- Test-only raw packet generation, observers and diagnostics must never enter the generated place.
- Preserve negative evidence and distinguish a harness precondition failure from a runtime defect.
