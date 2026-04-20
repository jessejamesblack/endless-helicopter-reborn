# Endless Helicopter Reborn 1.6.3

Version 1.6.3 is the next stable Android release. It combines same-device reinstall restore hardening, synced post-run leaderboard polish, more reliable achievement screenshots, and the new dedicated title screen presentation.

## Highlights

- Android installs now treat the Android-backed source identity as the canonical reinstall key instead of silently minting a new progression identity.
- Restoring an older support `player_id` now attempts to migrate that profile onto the phone's canonical Android-backed app id so later reinstalls on the same phone restore automatically.
- Score-beaten notifications now send only one alert per run, using the highest family score that the new run actually beat.
- The post-death results screen now focuses on synced `Personal Best` wording when a cloud profile exists instead of talking about a local best.
- Run achievement screenshots now wait for the end-run results screen, so Discord shares capture the scoreboard state instead of an unrelated menu screen.
- The game now opens on a dedicated title screen with the `BadGames` and `EndlessHelicopter` marks, a credits path, and the temporary AI-art notice kept off the main menu.

## Player-Facing Fixes

- Returning players on the same phone should resume cloud-backed progress after reinstall once their profile has been migrated onto the phone's canonical Android-backed app id.
- Fresh Android installs no longer invent a replacement progression identity while the stable Android-backed path is still pending.
- Discord score-beaten posts are less noisy because one run no longer fans out into multiple alerts for every lower beaten score.
- The results screen now gives clearer synced leaderboard feedback after a run.
- New personal best and unlock screenshots should now reflect the end-run screen players actually care about.
- Daily streak milestone screenshots still use the share-card style flow.
- Public leaderboard names remain optional until the player actually wants to submit a score.

## Backend And Ops Notes

- `migrate_player_identity()` now also updates `app_update_push_history`, so update-push dedupe follows the migrated device id instead of treating the same phone as new hardware.
- The leaderboard notification SQL now emits only the strongest `score_beaten` notification for each score submit.
- The results screen now fetches the current player's Supabase best row directly for synced personal-best messaging.
- The repo now includes a live Supabase reinstall/restore validator that runs the migration path inside a transaction and rolls back synthetic test data.
- The Godot validation suite now includes a restore-resume flow check for the local startup/profile state logic.
- Release publishing still happens only from `main`; PR and branch builds remain artifact-only.

## Safety Notes

- Same-device reinstall stability still depends on reinstalling builds signed with the same key.
- Cloud profile restore still uses `player_id`, not public display name.
- The results screen still falls back to on-device best-score wording when a synced profile is not available.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
- Operational logs and release automation continue to avoid raw secrets, webhook URLs, and push tokens.
