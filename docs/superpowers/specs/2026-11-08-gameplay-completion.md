# Gameplay preparation before Studio

Authority: the owner's instruction to prepare the game/mechanics in code and run Studio later; accepted D-01…D-10 in BT-10, BT-16/25/33/37/43/60/63/64. Continue the existing private Luau runtime. Engine, device and published-service checks stay NOT RUN until performed.

## Current batch

1. Replace ordinary Dragon generic Dash with source-backed primary headbutt. Source animation32/E2base4 means hero profile22/raw16 even below raw16; the Dash animation16-only finisher does not apply. Ordinary enemy damage2HP/profile4 preserves the current disclosed3HP calibration. Same existing human F/NPC pipeline, current effect geometry, immutable tuning, first successful victim, owner/actor/life identity, interruption and offline completion. No unmounted fireball or invented extra control. Original head/wing presentation has finite reset and does not apply damage.
2. Prepare a bounded, versioned per-run diagnostic journal for later Studio sessions. Record lifecycle/accepted attacks/hits/misses, enemy ownership/deaths, result and contextual interactions through the existing Session record path. Include run/group/level/build/rules/actor/attempt/resource identity. Recording/export failures must not change combat. Keep detailed diagnostics private; client feedback receives a small allowlisted projection. A read-only Studio-only export supplies actual traces later.
3. Render server-confirmed, deduplicated feedback with bounded client state. Distinguish hit, miss, shield and interaction; reset on group/run changes and never replay old events on a first sync/rejoin. Feedback must not produce damage, input or rewards. Include text without sound; asset upload/audio acceptance is separate.

### Source-verified unarmed chain

The audit established the complete first-level ordinary target selector (ASM7150–7245), per-victim profiles and initial NPC Life. Add it as an additional binding task: ordinary source raw Life becomes authoritative for the13 source-classified actors, scaled to three displayed hearts. Ordered initial values:15,15,31,31,31,31,31,31,31,47,31,31,15. Actors keep their existing owner/body/one-life identity. Source subtraction/high-nibble rounding and NPC reaction-end OR7 recovery apply; exact zero is not underflow death.

After existing held-item/fly/grab/weapon interactions, freeze internal unarmed action from the first current eligible target: normal low-Life<4→power punch; heavy reaction Life<8→boot, otherwise kick; normal low nibble<4→uppercut, except Dragon→overhead; otherwise jab. Public Punch/Dash remain unchanged. Hero-victim profiles18/19/20/21/24/28 and ordinary profiles0/1/2/3/6/10 differ. Running Dash retains its actual-victim low-Life finisher. Only modern source policy permits reaction-target repeat hits; dying/protected/held actors remain excluded. Stand-alone legacy scenes retain their established policy. One accepted animation can land only once, with current effect geometry and fixed selection; public input cannot choose an internal profile.

NPC light reaction1.05s, heavy.85s, hero post-heavy protection28/60s and new impulses/poses are disclosed Roblox calibration, not measured original frame parity. The existing close-Pig grab exclusion during reaction is retained as an explicit adaptation; the source0x3F primary pass can reach grab earlier than the heavy selector. No separate hero air-kick is inferred.

## Constraints and outstanding mechanics

The roster,5hearts/3run-wide successful respawns, one-life enemy identity, friendly fire, shields, boss queue, no late heroes and existing contextual-hand priorities remain binding. Keep all three hero templates equivalent. No persistent economy or cosmetic reward model is chosen here.

Source flight/capture/mounting of Dragons still need their own complete transfer; do not label a normal headbutt as all Dragon mechanics. The shared animation table does not prove a new hero jump kick. Three displayed hearts are not source raw Life; use the explicit source records for nibble thresholds. Preserve and document source findings before expanding those state machines. The next accepted mode is an original2.5D scooter episode; no copied obstacle course or invented role is implied.

Implementation choices: reuse existing ModuleScript/build pipeline; one bounded journal shared by diagnostics and feedback instead of parallel combat logs; no new gameplay RemoteEvent. Extend the existing State snapshot with an allowlisted recent-event feed. Detailed journal stays server-side and is available only through a Studio BindableFunction. These are engineering choices under the existing implementation authorization.
