# Campaign combat and lifecycle corrections

**Goal:** Continue the remaining-level mechanics checks with campaign boss controls, accepted projectile effects, enemy reconnection input and victory/respawn ordering; deliver the verified implementation through the existing private Studio, Git and Jira.

**Architecture:** Keep the existing Session resource authority and authored course/boss state machines. Use the existing campaignWalkSpeed adapter for the five mobile campaign bosses; preserve the stationary first guardian. Floating human enemies need a current accepted movement timestamp after every connection change. CampaignDirector declares victory only when Session has a legitimate surviving hero; pending deaths/retries keep the current scene and effects stepping and Session-owned total loss remains terminal. Robo bolts retain their accepted direction/tuning through later boss turns.

**Confirmed cases:** Zero native World WalkSpeed despite accepted Ready-state Move; stale Swim/Fly component input after reconnection; final due hero hit followed by an already accepted enemy projectile leaves the sole hero dying and Controller attempts advanceLevel with NO_SURVIVOR after replacing geometry; an old Robo bolt knocks toward the boss's later facing.

## Work

- [x] Record RED regressions using production Session/Controller/Director/components and authoritative World adapters where applicable.
- [x] Correct movement initialization, input freshness, projectile effects and victory survivor waiting without adding lives, replacing surviving bodies, cancelling accepted effects or changing player route choices.
- [x] Independently review the changes and run full frozen-source tests, compilation and source/playable verification.
- [x] Check prepared native Studio Models/controls/projectile effects/connection transitions and combat-result lifecycle with strict owned-world/global cleanup. Disclose synthetic rosters and prepared states; no actual-user reconnect claim.
- [x] Sync exact changed sources and BuildInfo after checking the private Studio baseline; save privately and prepare Git/Jira delivery. Push/CI/Jira receipts are maintained externally to the committed report.

## Constraints

Continue authorized shared branch codex/walker-strikes at c29a662. Preserve dirty places/BrickToads.rbxlx SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and concurrent concept art. No automatic safe route, public release, new balance/art decisions or fake same-account return proof. Existing real-account reconnect blocker remains unchanged.
