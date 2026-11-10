# Public Pig pickup/throw audit

Read-only source/control audit while the unchanged native24 run proceeds.
Working QA remains CombatBFB17590… / Bridge97C32BCB…; no source, Studio,
transport, geometry, HP, stock or Git change was made.

## Why spacing wins before a ready primary

The existing `pigSpacing` branch runs before normal primary selection. For
an ordinary, grounded, ready, same-height Pig, it aims for
`EnemyCarry.range+1.1=4.4` studs. At range<=4.0 it returns evasion immediately,
even if the hero already faces the Pig and a pickup is legal. At the next
range band it can return a tiny0.08 facing Move before primary/threat logic.
Being ready/facing therefore does not bypass spacing.

This preserves a real control distinction: a nonrunning public Punch invokes
`Session.contextualAttack` before ordinary melee. Director interaction routes
an eligible close Pig through EnemyCarry, at range<=3.3/height<=2.5/facing
dot>=0.5 with real ground/line-of-sight/actor checks. The same button therefore
means GRAB when close and ordinary melee outside the pickup margin. The
source's tiny-facing comment explicitly preserves that pickup margin.

## Actual public-control contract

The probe includes actual Session, LevelDirector, EnemyCarry, SourceCombat,
Combat arithmetic and lifecycle. It uses the prepared native-seed wide
Aqueduct corner: heroX47/Y3/Z10 facing southwest, Pig2.8studs southwest.
Only presentation, numerical eligibility, carry link and release are doubles.
No forced HP, stock, kill or actor replacement occurs.

- Normal Punch accepts GRAB; after0.12s the same living Pig is carried and
  its actual pending0.30s NPC Jab is cancelled.
- The next legal Punch, after the ordinary cooldown, throws that same body
  through the existing contextual action.
- For rawLife15, Throw subtracts4 to11. After the existing0.85s flight
  reaction, Director recovery rounds11 back to15. Three normal cycles all
  produce15→11→15, no enemy death, hero47/attempt1/stock3.
- For rawLife3, the same two public Punches cause the existing Throw underflow
  death, retaining hero47/attempt1/stock3. The normal source death path is used.

Thus repeated pickup/throw alone does not prove progress against the native
raw15 Pig when it lands safely. A physical throw off the route could kill,
but this audit neither simulates nor claims that outcome. The existing raw3
finisher is a proven ordinary-control opportunity.

## Concrete bounded policy RED and candidate

At rawLife3, ready/facing/grounded and real `carry:interaction.available=true`,
the pinned original BFB Pilot returns evasion andprimary=false. The
`probe-policy-red.luau` assertion fails on that specific masked finisher.

A narrow future QA candidate is to request the existing public Punch only
when a selected ordinary Pig has rawLife<4 and the authoritative ordinary
interaction currently advertises an available EnemyCarry GRAB. The existing
Carried branch already requests the later throw. This preserves the real
control path and must also preserve higher-priority contextual actions,
pending-capture holds, reaction, attack cooldown, facing, support and flight
guards. It is not a proposal to always grab raw15/31 Pigs, override private
target IDs, or change damage/recovery. No candidate source edit is made here.
The prepared contract has one Pig: a future multi-Pig implementation must
also establish that the existing carry selector will actually acquire the
low-Life Pig, rather than another eligible nearby body.

## Pig-head evidence is different

Native11's recorded head pose was heroY8.025629 versus PigY2.999987, almost
the same XZ. That exceeds pickup height2.5 and is a different case from the
grounded corner. The retained26 step-off checks and the original rejected
synthetic-boundary evidence describe that distinction. This probe explicitly
rejects the head-height and wrong-facing pickup cases; a future finisher
must not bypass those source gates.

The earlier rejected seven-stud-inset30-second progress probe did not pass
EnemyCarry into Director. Its negative result was not evidence that a public
pickup was unavailable. This contract includes that dependency explicitly.

## Reproduction and limits

```powershell
.tools/python-3.13.9/python.exe reports/2026-11-10-qa-pig-public-carry-audit/verify.py
```

Public contracts pass, the masked raw3 policy assertion is expected RED, all
existing24 EnemyCarry tests pass, and the new probes compile. Validation
records exact source hashes. The default RED probe imports the pinned
`baseline-combat-bfb.lua`, so later working QA changes do not rewrite this
historical counterexample. Original BFB/97 source hashes and timestamp remain
in `atFreezeSourceHashes` and `atFreeze`; current working QA hashes are
separate provenance. Optional `--check-working-baseline` checks working
restoration only when BFB/97 is expected. This is not a native rig/raycast/throw-flight,
latency, multiplayer or complete-fight acceptance; the NPC/body positions
and facing are explicitly prepared and held by the presentation adapter.
