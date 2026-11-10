# Character presentation, audio and effects

The current playable build imports all three detailed hero palettes, four dedicated Brown attack/fear morphs, and29 articulated creature families. The29-family pack contains166 cosmetic segments and175,584 triangles. The existing Green body, Guardian, accepted attack rules, collider rigs, health, ownership and life rules are retained.

The pinned reference is Battletoads USA NES public source `f1a43b69577246850d136473700a333b3cdfe93f`. The [source catalog](../../research/canonical-visuals/cast-source-catalog.json) contains164 decoded frames,75 family/palette sheets and43 palette variants; the [animation profiles](../../research/canonical-visuals/cast-animation-profiles.json) distinguish35 runtime mappings and their graphics banks. Source silhouette/frame/caller facts are separate from authored depth, joint angles and timing adaptations.

Heroes now render source-informed jump/apex, carry, contextual item actions, reactions, folded1F windup and full-body32/33 fear shapes. Creature motion uses accepted actor/epoch-scoped actions, correct graphics namespaces and interrupted reaction/death/carry states. Pig light recovery is7→4; heavy recovery is5→8. Dragon light reaction uses0C→9/9/0A/0A with explicitly authored timing when no source timer byte exists. The Brown fear heads use their own uploaded Brown atlas rather than a green head with a multiplicative tint.

The new audio consists of16 original synthesized SFX and four original chiptune loops. Eight SFX voices and one music voice consume confirmed events and authoritative transitions. Old snapshots and repeated events cannot replay sounds. Local cosmetic particles are capped at24; mute leaves them enabled. A localized44px Audio button opens dismissible controls during play.

## Exact build

| Receipt | Value |
| --- | --- |
| Embedded source SHA-256 | `8c8daab80dc7c8ec2b825ee4af5ffd923bdbd9380ea47de5676b29e77c080650` |
| Playable file | `places/BrickToadsPlayable.rbxlx`,1,850,393 bytes |
| Playable SHA-256 | `9e9692845e5a278d7426f7a4bd657ac3abfda94fa7d00eb899495492868541bd` |
| Protected starter SHA-256 | `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353` |

The [final validation](final-validation.json) ran71 commands with zero failures and compiled216 Luau files. Focused results include23 cast presentation,15 server appearance,14 client visibility,18 audio,6 source-profile,6 packaging and35 playable-builder contracts. The historical58-command campaign checkpoint stays at its original path and source version.

## Native Studio evidence

All Studio operations used Roblox MCP and one existing Studio window, place117412694427208. No Team Test or additional client/window was opened.

- [Prepared cast fixture](native-cast-fixture.json):29 real imported creature rigs plus12 hero states;41 cases, zero errors. Cosmetic geometry and articulation preserve the physical body and HP. [Hero states](native-hero-states.png) and [cast overview](native-cast-overview.png) are native Edit captures of prepared poses.
- [Typed preload](native-typed-cast-preload.json):332 successful mesh/texture callbacks with no failures. Raw MeshId-string requests were rejected as an invalid diagnostic method and are not used as acceptance evidence.
- [Current-build client](native-client-acceptance.json): one genuine player11946162891 in ordinary Play. A prepared persistent gallery made all29 families/166 segments visible through the actual client gate during the bounded availability probe. Its sample timestamps are nominal intervals, not measured wall-clock loading latency. The normal game used MCP hero selection/Start and keyboard F, without player position, damage or resource writes. Actual music/SFX peaks were281.44/300.83; all nine voices loaded the correct9.470/42.017-second atlases. Muting produced zero playing voices while up to eight particles remained visible.
- [Serpent support](native-serpent-support.json): five prepared native-instance cases passed: movement/yaw, resize, removal, kind replacement and course close. Real support identity/physics/floor membership and shared templates remained unchanged. [Capture](native-serpent-support.png). The fixture explicitly disconnects cosmetic joints while placing its prepared Edit pose; it does not claim physics or a natural Serpents playthrough.

Native testing found that server-side mesh preloading can hang or report unavailable representations even when client rendering succeeds. The final implementation keeps the server fallback visible and lets the client gate change only `LocalTransparencyModifier` after typed-instance loading. Explicit unique backlinks protect replacement skins and external Serpent supports. Transient failures retry after1/3/10 seconds, then retain a visible fallback. Earlier native testing also exposed a permanent first-failure cache and a replacement-baseline handoff bug; both have regression contracts.

Studio was stopped after the checks. Owned galleries, QA modules and export chunks were removed. Current production sources and imported templates remain in Edit; no public experience was published.

## Remaining acceptance boundaries

The29-family roster and these presentation paths are implemented; exact universal NES timing, every conditional death/intro timeline, full Snake nametable-body reconstruction and dynamic alternate palettes are not established. Unknown source traces stay explicit in the profiles. The3D geometry and original audio are authored adaptations.

The ordinary current-build check used Studio God Mode and one real client. It does not replace the historical finite all13-stage win, a fresh full natural campaign on this art build, real same-account reconnect, multiplayer role matrices, physical phone/tablet readability or performance, or human listening on devices. Remaining emergency-state/low-health/queue and secondary item-event feedback in BT-63 is tracked separately from these16 core SFX. Broad Jira acceptance issues remain open where those criteria lack evidence.
