# Campaign and complete resource catalog acceptance

Current production source: `a2440cee9f81d4f6eddbd4425a72f8f4fe74a25a4939f9124df7ab2708bed836`. Derived playable:1,938,467bytes, SHA256 `aa097da7ba0825911cbd3efce67f61f5141a397343746d6ea81a9d5d7365ab37`. All59 packaged source paths were compared to Studio by UTF8 length and Adler32 before disposable QA appends. The builder's source fingerprint is SHA256.

Only the existing Studio window was used, through Roblox Studio MCP. The account is Archaicus14, UserId11946162891, place117412694427208. The protected starter remains SHA256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`.

## Complete catalog

[Full native catalog](full-catalog-final.json) passed on9737089d. Its resource, hero, cast and course-appearance implementations are unchanged in a2440cee; the later automatic-Clinger integration and final campaign are checked separately:

- All29 imported cast families,166 mesh segments,368 sampled cast poses.
- Three hero palettes,12 attack/fear morph resources, all32 mapped hero action selectors and20 additional pose/context cases:156 hero cases total.
- Separate three-mesh Guardian, both cannon recoil paths and damage tint.
- Every vehicle with every hero:12 actual approved-resource mount cases. Both posed foot boxes meet the actual Deck/RiderDeck top within0.000001stud; physical R6 properties and poses remain unchanged by the production cosmetics.

The prepared Edit fixture explicitly disconnects only its own cosmetic joints before placing solved preview meshes. It checks production C0/C1 equations, resources and preserved physical bodies; this is not live solver, multiplayer or gameplay-selection evidence for all enumerated source branches. The real-client campaign below is separate.

[Course acceptance](course-elements-final.json) passed all11 detailed cases and the complete40-kind renderer inventory. It verifies resources, finite geometry, unchanged physical object identity/size/pose/queries/SurfaceId, same-size movement, resizing, removal, floor membership and unchanged shared templates. Four kinds use imported vehicles, seven use authored industrial structures and Serpent uses its existing imported articulated support. The other28 kinds retain their existing primitive representation. Thus the complete inventory is checked, but fully detailed art for every scene element is not claimed. `GameWorld` projectiles, pickups and clubs are separate paths from this40-kind inventory.

The remaining [native world-elements checks](world-elements-final.json) passed27 cases across projectiles, Guardian ball transitions, ground/equipped clubs and finite swing, Raven claw, HealingFly skin, catch effects, Dragon fire and Guardian intro foot/ripples, plus25 first-level scenery groups. It uses actual methods in a private world at X18000, with a synthetic held actor and fresh module clones. Its actor HP, scenery fingerprint, global Lighting, Baseplate and SpawnLocation were preserved; cleanup removed only owned QA objects. The initial finite-club fixture wrongly inspected a newly equipped unswung model; the corrected check starts a real swing and verifies expiry through presentation updates. This was a fixture correction, not a product bug.

The complete33 UHD model specifications in Jira BT-74 are broader than this runtime catalog. This verification does not close their LOD, PBR, DCC, socket, clip and human-control delivery criteria.

## Fixed defects

The screenshot's yellow transport plate and plain orange wall were real presentation gaps. Four original authored3D adaptations now provide source-informed Speeder, Surfboard, Jet and ClingerVehicle silhouettes, with36 uploaded textured segments. Approved asset89107256831014 and actual MeshId/TextureID/MeshSize/rest-frame receipts are packaged as mandatory resources. Walls, barriers, overheads, moving walls, crushers and electric gates have opaque recessed panels, piers, caps, seams and warning details. Their authoritative volumes and behavior are preserved.

Native checking caught the initial fit hiding5/10 Speeder parts and3/6 Clinger parts entirely below the road. All three heroes' original Ride soles were0.857369stud above the old deck. The corrected fit derives clearance from the actual scaled, oriented mesh bounds; Surf also reads the covering water surface. It separates the authored origin from the actual named deck top. The current hero's cosmetic root is aligned using this frame's joint equations and posed foot corners, without reading lagged cosmetic part transforms or moving the physical actor. Stale bodies, interrupted states, removed skins/proxies and nonfinite deck planes cannot keep the alignment.

Native API acceptance also caught a missing third argument in a two-number CFrame constructor, which permissive doubles had accepted. The constructor doubles now enforce actual overload arity; RED and corrected native results are retained in the `*-arity-diagnostic.json` and final files. Earlier gallery failures from the QA solver moving connected parts, and an invalid Idle fixture context, are retained as fixture diagnostics, not production defect claims.

Actual ordinary-NPC profile3 Dash effects now select the proven source `DashLowLifeTail` graphics31 branch once, bound to accepted tuning identity, actor, body, epoch and effect time. Misses, ordinary results, duplicate/stale receipts and interruptions cannot trigger it. This producer proof does not extend to untraced hero/boss target branches.

The separate client Course visibility gate requests typed resources, keeps a fallback through loading/failure, retries within bounds and restores owned local visibility across replacements/removal. Edit gallery screenshots intentionally retain server fallbacks; real-client readiness and hidden fallback observations are required below.

## Continuous campaign

The frozen pre-change8c8daa baseline26 completed all13 stages with Won and all six bosses/phases. It used explicitly enabled Studio God Mode, five respawns and final attempt6/stock3. [Verified God Mode summary](attempt26-god-mode-summary.json) retains the ordinary finite-policy failures separately; [original finite diagnostic](attempt26-summary.json) remains RED. This is not current-source finite-budget acceptance.

Attempt27 was deliberately stopped after224 observations while the mount clipping was investigated. Its partial archive has no terminal result and proves no complete campaign.

Attempt28, run `bricktoads-course2800-8f0fc5e1`, seed1158731273, completed all13 stages on9737089d with880 observations, all six bosses/phases and terminal Won. [Verified God Mode analysis](attempt28-god-mode-summary.json) records final attempt9/stock3/Life31, eight respawns and no planner errors. [Preflight](attempt28-preflight.json), unthinned samples, terminal journal, motion and audiovisual evidence are retained. This is gameplay completion with the presentation failure below, not overall presentation acceptance. The disposable QA planner sends only ordinary Start/Move/Jump/Punch through the existing production client sender. It does not write actor position, damage, Life, stock, enemy death, boss phase, stage index or completion. The one-shot pre-Start GUID dependency restores on its first call. No production trajectory assistance is added.

The live run exposed an integration gap that the manually prepared mount cases cannot establish: automatic Clinger control retains `mounted=false`, so the old movement selector chose Air instead of Ride and never passed the actual deck context. The unchanged Clinger velocity and missing rendered yaw also left hero/vehicle facing inconsistent with turns. [134 native observations](attempt28-clinger-presentation-defect.json) retain this negative result on9737089d. The prepared catalog does not waive this failure.

The corrected a2440cee code stores a separate presentation heading from the segment that actually earned movement, uses that heading for hero/vehicle facing and selects Ride during unfinished automatic Clinger control. It does not alter actual mode velocity or mount state. Four differential real-Session traces compare4,110 ticks against the frozen old traversal implementation, including wrong input, coarse cadence, damage/reaction and ordinary paid retries. Positions, inputs, progression, chase, collisions, resources, spawns, kills and impulses remain identical. Actual world/context tests cover cardinal directions, zero velocity, invalid headings, other modes, leaving Ride and unmounted Clinger forwarding its live deck.

Final attempt29, `bricktoads-course2900-752f7404`, seed1158731273, is running on a2440cee with the same ordinary input policy and explicit God Mode. [Preflight](attempt29-preflight.json) binds the final source. Its read-only heading observer must establish Ride, deck contact and correct hero/vehicle facing during actual traversal; terminal completion is pending.

[Attempt28 audiovisual analysis](attempt28-av-analysis.json) records all13 stages with loaded music and positive loudness, all9 voices loaded on every complete voice sample,631 Played SFX events and particle peak14/24. Stages4/6 had no sampled cues; stage12's two Played cues had no positive sampled SFX loudness, which does not establish inaudibility of short cues. All45 console warnings were asset-content representation warnings, with zero Lua/observer error records. All four vehicles reached client Ready with canonical meshes visible and fallbacks hidden; pending frames retain visible fallbacks. Actual source graphics31 was observed on the same actor as the ordinary-NPC profile3 receipt. Same-actor articulation evidence is separated from aggregates across different actors. Overall presentation acceptance remains false for28 because of Clinger.

## Automated verification and limits

[Final Clinger regression](validation-clinger-final.json):77/77 commands,227 Luau compilations and66 Python compilations pass on a2440cee. The earlier [9737089d receipt](validation-final.json) is retained. These include source combat, confirmed Dash, Ride alignment,16 visibility contracts,10 course groups, seven strict packaging tests,37 builder tests and13 recorded/adversarial analyzer tests. The observer additionally passed with its portable explicit Luau argument after CI wiring. Required new checks are included in the GitHub workflow.

Native prepared catalogs do not prove physical phone/tablet operation, genuine-account reconnect, public-server load, complete NES interpreter/timing parity or every possible gameplay branch. Real same-account reconnect remains unverified because no second genuine account is available to keep the target server alive. No public experience is published by this change.
