# Immediate delivery of changed QA movement plans

The disposable client adapter could receive a new steering/run plan immediately after its RenderStepped keepalive had sent the previous one. Its existing 0.06-second gate then suppressed the changed Move. The next scheduled keepalive could be almost 0.1 seconds later. This avoidable client delay compounds RPC and RemoteEvent latency; it is separate from production combat, movement and networking authority.

Native20's accepted-input archive already demonstrates planning-to-accepted steering delays around0.15–0.2 seconds (see `../2026-11-10-full-campaign-playthrough/attempt-20-independent-review.md`). Native22's Lost1 is not attributed to this transport defect by this report. Native22 has no captured client response clock that independently isolates its response-to-send interval.

## Design and authorized scope

Use the existing ordinary sender immediately when a received plan changes x, z or run. Preserve the0.06-second gate for unchanged keepalives and preserve existing urgent Move-before-Jump/primary behavior. This adds no remote, server-side authority or new packet format. The production `send`, `sendIntent`, identity, sequence, normal server40/s limit and gameplay sources are unchanged.

Only `tools/qa/full_campaign_client_adapter.luau` changes. The previous plan is compared before `qa.move` is replaced, then the existing `force` argument includes `changed`. All source outside that response branch is preserved.

Baseline raw SHA256: `69829b89eb61699cdd1a3864faeeaf0e20dcbdee11a71c6b95b45e55ced5b3c5`.

Candidate raw SHA256: `b40c4b42d5a44d9f7561be8228204c5bae3f292292d9630eaf0fc21384544c65`.

## RED before the source change

`build_contract.py` concatenates the exact pinned adapter with the actual production `playable`, `send` and `sendIntent` functions. Only the scheduler/RPC clock and final RemoteEvent boundary are adapted. The harness supplies primitive packet context, not actors, world geometry, planner behavior, hits or resources.

The deterministic counterexample sends an old-plan keepalive at0.100, receives changed axes at0.105, and sees the baseline's first changed Move only at0.200: **95ms added client delay**. Changing only the run flag fails identically. Baseline result: **10PASS/2FAIL**, process exit1 for exactly those two missing immediate deliveries.

Unchanged keepalive gating, urgent Move→Jump→Attack order, production authentication envelope/sequence, terminal neutral Move and all six rate checks already pass on the baseline. This is not a timing test against a rewritten copy of the adapter's condition.

## GREEN and rate budget

Candidate result: **12PASS/0FAIL**, process exit0. The changed Move is sent at0.105 in the same coroutine turn as the response: zero added gate delay. Compilation passes.

The six30-second rate cases use30/60fps RenderStepped clocks and RPC RTT0/0.02/0.05 seconds. Every plan changes steering/run and requests Jump and primary; the existing0.13-second attack guard remains active. Exact Config.MaxIntentRate40 is required by the harness, and captured packets pass through a40-token/second bucket with ordinary refill/order. All six cases have zero rejected intents; the highest observed sliding one-second count is39 packets. The baseline has the same saturation results because urgent plans already forced a Move on every response; the changed-only case adds less action traffic than that tested envelope.

An independent subagent reran both contracts and all rate clocks and returned bounded CLEAR. The existing public sender, identity/sequence envelope and same-intent gate were independently reviewed.

Reproduce from the repository root:

```powershell
.\.tools\python-3.13.9\python.exe reports/2026-11-10-qa-client-plan-delivery/verify.py
```

The verifier checks exact baseline/candidate/working hashes, unchanged production client/config hashes, the extracted production sender hash, the exact reviewed adapter replacement, RED/GREEN outcomes and compiler output. Generated contracts, logs and `validation.json` are retained here.

## Limits

This proves a bounded adapter-clock defect and its correction. The RPC/render clock is modeled; it does not reproduce the exact Native20 or Native22 client timing. Fixed active packet context does not prove session-context changes or recovery when production `send` rejects an unplayable command. The tested rate clocks are not a universal guarantee for arbitrary FPS, RTT, phase alignments or simultaneous manual input.

No Studio actions or extra windows were used. No production source, rate limit, gameplay pilot, actor pose, health, reserve, enemy AI or phase/completion state was changed. The result is not a native Guardian pass, Ice acceptance or full13 completion.

The pinned adapter snapshots preserve exact source bytes, including their terminal blank line. The parent checks staged whitespace with `git -c core.whitespace=-blank-at-eof diff --cached --check` to preserve those frozen hashes while checking the remaining whitespace rules.
