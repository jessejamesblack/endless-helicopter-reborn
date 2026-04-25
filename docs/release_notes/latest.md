# Endless Helicopter Reborn 1.6.8

Version 1.6.8 is the depth and feedback sprint. It adds run-to-run choices, temporary powerups, stronger vehicle identities, short objective events, tougher enemy pressure, and several fairness fixes that make longer runs feel cleaner.

## Highlights

- Added periodic 1-of-3 run upgrades at milestone moments so each run can build in a different direction.
- Added temporary powerup pickups: Shield Bubble, Score Rush, Missile Overdrive, Ammo Magnet, EMP Burst, and Afterburner Burst.
- Added short objective events, including rescue pickups and reactor chains, with score and reward hooks.
- Strengthened vehicle identities with handling differences and run passives for near misses, ammo economy, shields, missiles, combo stability, and scoring.
- Expanded enemy pressure with armored, shielded, and elite variants, faster turret/drone firing, immediate entry shots, and more responsive early pacing.

## Player-Facing Fixes And Polish

- Fixed boundary recovery abuse with stall and chain protections.
- Fixed pause spam so rapid pause/resume cannot create a slow-motion advantage.
- Restored long-run background continuity so existing biome visuals stay coherent until the next biome transition.
- Improved responsive spawn lanes for tall and tablet layouts.
- Made kill-score popups more visible and extended the combo window slightly.
- Added daily mission access from the pause menu and new mission types for upgrades, powerups, objectives, elites, and special enemies.
- Daily mission progress now updates live during runs for immediate pickup/effect events such as ammo pickups, powerup collection/use, EMP activations, and shield absorbs.
- Updated the new upgrade, powerup, objective, and run-summary UI to better match the existing game HUD style.

## Progression And Data Notes

- Added unlock-pool meta progression for upgrades, powerups, and objective possibilities without adding a shop, paid upgrades, or a currency economy.
- Expanded run stats for upgrades, powerups, objectives, elite/special kills, shield absorbs, effect seconds, ammo refunds, and boundary crash reasons.
- Kept profile sync within the existing JSON summary path; no Supabase schema migration is required for this release.
- Live mission progress is reconciled against the final run summary so the same pickup or effect cannot count twice.
- Added repo-local `SKILL.md` guidance for future agent-assisted work.

## Safety Notes

- Same-device reinstall stability still depends on reinstalling builds signed with the same stable release key.
- Public Android release publishing still requires `release_stable` on `main`; testing-only `debug_stable` builds stay non-public.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
