# Endless Helicopter Reborn 1.6.1

Version 1.6.1 is a stable bugfix release focused on cloud restore reliability, score saving, cleaner progression UI, and a few rough edges that showed up in hands-on Android testing after Sprint 7.

## Highlights

- Score saves now route through the live backend path again, so fresh scores and profile syncs can reach Supabase correctly.
- Launch-time cloud checks no longer loop forever on brand-new devices with no remote profile.
- The score HUD once again shows clear `SCORE` and `MISSILES` labels while keeping the cleaner non-padded numbers.
- `NEW` markers have been removed from menu and Hangar flows so selecting content no longer takes an extra tap.
- This release is intended as the stable Android follow-up to the larger Sprint 6 and Sprint 7 systems work.

## Player-Facing Fixes

- The post-run leaderboard/setup flow can now fall through to the normal name prompt instead of getting stuck while checking cloud progress.
- Restored score/ammo HUD labels make the in-run UI easier to read without bringing back padded zeros.
- Hangar and menu flows are less fussy now that `NEW` badges no longer interrupt first-tap selection.
- Save and restore behavior is more consistent after the recent backend reset and stable profile refresh work.

## Backend And Ops Notes

- Score submission now uses the active live save route that is deployed on Supabase.
- Profile sync remains on the protected synced profile path so release/update protections stay in place.
- This release keeps the Sprint 6/7 release stack: GitHub Releases, Discord build notes, release metadata, and update-aware cloud access.

## Safety Notes

- Cloud restore still uses player identity, not public display name.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
- Operational logs continue to avoid raw secrets, webhook URLs, and push tokens.
