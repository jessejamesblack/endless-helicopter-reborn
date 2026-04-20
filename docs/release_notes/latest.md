# Endless Helicopter Reborn 1.6.2

Version 1.6.2 is the next bugfix candidate focused on same-device reinstall restore, stable Android identity migration, and safer progression continuity.

## Highlights

- Android installs now treat the Android-backed stable identity as the canonical reinstall key instead of silently minting a new progression identity.
- Restoring an older support `player_id` now attempts to migrate that profile onto the phone's stable Android identity so later reinstalls on the same phone restore automatically.
- Android exports keep user-data backup enabled and request retain-data-on-uninstall as a local safety net for profile/config files.

## Player-Facing Fixes

- Returning players on the same phone should resume cloud-backed progress after reinstall once their profile has been migrated onto the phone's stable Android identity.
- Fresh installs no longer need to invent a replacement Android progression identity while the stable bridge is still pending.
- Public leaderboard names remain optional until the player actually wants to submit a score.

## Backend And Ops Notes

- `migrate_player_identity()` now also updates `app_update_push_history`, so update-push dedupe follows the migrated device id instead of treating the same phone as new hardware.
- The repo now includes a live Supabase reinstall/restore validator that runs the migration path inside a transaction and rolls back synthetic test data.
- The Godot validation suite now includes a restore-resume flow check for the local startup/profile state logic.

## Safety Notes

- Same-device reinstall stability still depends on reinstalling builds signed with the same key.
- Cloud restore still uses player identity, not public display name.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
