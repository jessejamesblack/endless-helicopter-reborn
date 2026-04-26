# Endless Helicopter Reborn 1.6.13

Version 1.6.13 is a release-trust, public polish, and gameplay-content update. It keeps the 1.6.12 depth sprint intact while adding clearer install/repo surfaces, stricter release metadata validation, more run objective variety, and a new mid/late-run enemy pressure role.

## Highlights

- Added Black Box Recovery and Signal Gates as new short objective events.
- Added Mine Layer enemies that drop slow ion mines, creating extra navigation pressure and missile-intercept opportunities.
- Added storm-pocket and minefield encounter chunks for more mid/late-run variety.
- Added release hygiene validation so Android export metadata, checked-in build info, release notes, Discord summary, and public GitHub release metadata stay aligned.
- Improved the public README with latest APK links, current gameplay media, controls, roadmap links, and clearer Android install guidance.
- Added a public roadmap and GitHub issue templates for bugs, gameplay tuning, Android installs, and backend/sync issues.
- Added periodic 1-of-3 run upgrades at milestone moments so each run can build in a different direction.
- Added temporary powerup pickups: Shield Bubble, Score Rush, Missile Overdrive, Ammo Magnet, EMP Burst, and Afterburner Burst.
- Added short objective events, including rescue pickups, reactor chains, black box recovery, and signal gates, with score and reward hooks.
- Strengthened vehicle identities with handling differences and run passives for near misses, ammo economy, shields, missiles, combo stability, and scoring.
- Expanded enemy pressure with armored, shielded, and elite variants, Mine Layers, faster turret/drone firing, immediate entry shots, and more responsive early pacing.

## Player-Facing Fixes And Polish

- Fixed boundary recovery abuse with stall and chain protections.
- Fixed pause spam so rapid pause/resume cannot create a slow-motion advantage.
- Restored long-run background continuity so existing biome visuals stay coherent until the next biome transition.
- Improved responsive spawn lanes for tall and tablet layouts.
- Made kill-score popups more visible, extended the combo window slightly, and let combo scoring climb a bit higher.
- Added daily mission access from the pause menu and new mission types for upgrades, powerups, objectives, elites, and special enemies.
- Daily mission progress now updates live during runs for immediate pickup/effect events such as ammo pickups, powerup collection/use, EMP activations, and shield absorbs.
- Daily mission cloud sync now preserves the highest per-mission progress and completion state, so a stale cloud row cannot roll a completed mission back to `4/5`.
- Live mission completions now survive a stale cloud restore that finishes mid-run, keeping the end-screen completion text, local mission list, profile credit, and sync payload aligned.
- Mission state now blocks disk reloads while live progress is being applied, preventing profile-change UI refreshes from rolling the mission list back before it is saved.
- Pending daily mission sync jobs now merge upward locally, so a stale queued payload cannot replace a newer completed mission payload before the queue flushes.
- Added broader daily mission validation so progress is checked across in-run views, end-of-run results, and the main-screen mission summary.
- Fixed app-update push notifications so they cannot appear as incorrect score-beaten `0/0` notifications.
- Updated the new upgrade, powerup, objective, and run-summary UI to better match the existing game HUD style.
- Added fresh README media capture tooling and validation for public polish docs/templates/media.

## Progression And Data Notes

- Added unlock-pool meta progression for upgrades, powerups, and objective possibilities without adding a shop, paid upgrades, or a currency economy.
- Expanded objective unlock pools to include the new Black Box Recovery and Signal Gates possibilities.
- Expanded run stats for upgrades, powerups, objectives, elite/special kills, shield absorbs, effect seconds, ammo refunds, and boundary crash reasons.
- Kept profile sync within the existing JSON summary path; no Supabase schema migration is required for this release.
- Live mission progress is reconciled against the final run summary so the same pickup or effect cannot count twice.
- Startup cloud restore keeps local daily mission progress when the local device is ahead, then queues a repair sync back to Supabase.
- Added repo-local `SKILL.md` guidance for future agent-assisted work.

## Safety Notes

- Same-device reinstall stability still depends on reinstalling builds signed with the same stable release key.
- Public Android release publishing still requires `release_stable` on `main`; testing-only `debug_stable` builds stay non-public.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
