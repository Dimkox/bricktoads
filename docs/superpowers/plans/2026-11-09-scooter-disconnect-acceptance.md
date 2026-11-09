# Actual scooter disconnect acceptance plan

**Goal:** Verify real client exits during enemy actions and scooter crashes; preserve identities/resources and publish exact results to GitHub/Jira.

**Spec:** `docs/SCOOTER_EPISODE.md`; continuation after actual-client enemy/crash checkpoint `5451f1d`.

**Approach:** Extend the existing tagged role harness and launcher. Keep the same production Intent/State driver and actual `LeaveTest` command. Prepare only seed41/stage3, then use real client inputs and actual PlayerRemoving events. Observe final outcomes on remaining actual clients while retaining departed owner/body evidence.

## Constraints

- Preserve `places/BrickToads.rbxlx` SHA-256 `1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353`; exclude external concept-art and boss-walker specification work.
- Current user Studio is `c7317dd0-90dc-42e5-853a-e791f6641191` / PID12452. Use a separate unsaved owned helper, never modify the user Studio.
- Base source `b6b12b3ad99311bf937fb556fe9445a40efd0c4cec71cdb9feae3c7475447cff`; actual current Players, matching BuildId and rendered readiness required.
- No test pose, health, stock, fake connection or forced death writes during live scenarios; no NPC substitution or safe auto-navigation for departed owners.
- Prove actual removal before the event under test; acknowledgement alone is insufficient. Compare immutable pre-contact resources and real physical body references.
- A newly added test Player has a different UserId. It can test late arrival, never same-owner reconnect.

## Steps

- [x] Audit expected offline contracts and supported transport; retain the prior true reconnect limitations rather than relabelling a new player.
- [x] Implement InvaderDisconnect: real claim/theft, real owner exit, no takeover, same finite escape and no false Life return.
- [x] Implement RocketRatDisconnect: accepted human drop, actual owner exit before contact, persistent original obstacle causes native crash/rewind and correct resources.
- [x] Implement HeroDisconnectCrash: boarded real rider exits, same offline body keeps moving and survives another hero's shared rewind without replacement/healing/stock charge.
- [x] Where supported, add a fresh actual late arrival and prove it cannot replace a fixed original owner; label it separately from reconnect.
- [x] Compile, run native scenarios, independently review raw evidence and preserve failures with exact source/test scope.
- [x] Close owned processes and verify protected files; native evidence and independent review are complete. GitHub/Jira delivery follows the scoped commit.
