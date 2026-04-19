# Endless Helicopter Reborn 1.6.2

Version 1.6.2 is the next bugfix candidate focused on Android identity fallback and a cleaner first-time score-save flow after the 1.6.1 stable release.

## Highlights

- Android installs can now fall back to a persisted phone-local player/device identity when the stable Android ID bridge is unavailable.
- Fresh installs should no longer get stuck on “player ID isn’t ready yet” when restoring progress or entering a leaderboard name.
- The `Back To Menu` and `Submit Score` actions on the save-score screen now present as a matched button pair.
- This release keeps the 1.6.1 score-save and progression fixes while tightening the first-run Android experience.

## Player-Facing Fixes

- Score setup should now work even if the stable Android identity path is temporarily unavailable on first launch.
- Settings restore should no longer sit on “this phone’s player ID is not ready yet” for fresh installs.
- The leaderboard setup screen is easier to use on phone thanks to the balanced `Back To Menu` / `Submit Score` row.
- The earlier 1.6.1 score-save, HUD, and menu-friction fixes remain included.

## Backend And Ops Notes

- Score submission still uses the active live save route deployed on Supabase.
- Profile sync remains on the protected synced profile path so release/update protections stay in place.
- Android identity fallback still leaves room for the later canonical migration path when a stable device identity becomes available.

## Safety Notes

- Cloud restore still uses player identity, not public display name.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
- Operational logs continue to avoid raw secrets, webhook URLs, and push tokens.
