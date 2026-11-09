# Rotating Tower Springs Implementation Plan

**Goal:** Keep both Turning Spire spring pads attached to their rotating supports, with launch checks matching their visible footprint.

**Architecture:** Author an explicit tower-platform index on each Tower spring. Resolve one current position/yaw from that support and the existing rotation; use it for rendering and inverse-yaw launch checks. Preserve fixed Ascent springs, authored jump powers and all lifecycle rules.

**Tech Stack:** Existing Luau campaign runtime, native Luau contracts, Python place builder, Studio MCP.

**Spec:** research/2026-11-09-campaign-courses.md (Turning Spire), existing CampaignDefinition stage12 and Jira BT-33.

## Constraints

- Continue the existing authorized feature branch and shared checkout; disjoint agent ownership keeps current Studio integration and protected user/art files intact.
- No automatic navigation, jump timing, enemy routing, balance, resource, public-release or access changes.
- Preserve protected places/BrickToads.rbxlx SHA1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353 and concurrent concept art.
- Same-player reconnect stays pending: no second genuine account is available.

## Tasks

- [x] Reproduce RED: stage12 seed41, actual logical support tower-8 at rotation pi/2 launches52 instead of authored65; rendered spring is still at its initial coordinates.
- [x] Add regression cases for both mounted springs at multiple nonzero rotations, correct support and render alignment, rotated footprint edges, ordinary off-pad jump and rejected airborne repeat. Keep Ascent static launch covered.
- [x] Update CampaignDefinition.lua, CampaignModes.lua and tests/campaign_modes/CampaignModes.spec.lua only. Share spring transform; explicit support index avoids coordinate inference.
- [x] Compile and run campaign definitions/modes/progression and existing real-Session course drivers; independently review diff.
- [x] Rebuild exact playable. Use an owned Studio helper to check native rendered CFrames, real Session input jump impulse, unchanged actor/attempt/Life/stock, ordinary/double-jump boundaries and cleanup. Prepared pose/time/level setup must be identified as such.
- [x] Prepare coverage/report and the scoped Git/Jira delivery; external push/CI/Jira receipts are recorded in the delivery response.

## Evidence boundary

The focused engine fixture proves spring attachment and accepted jump behavior on prepared stage12 supports. It does not establish a natural whole-tower or full-campaign human playthrough, physical-device input or reconnect.
