# Endless Helicopter Reborn 1.6.5

Version 1.6.5 is the next stable Android release. It packages the Android reinstall-restore fixes, the dedicated title screen flow, clearer synced best-score behavior, live account cleanup for legacy split identities, and a fix for restore installs that were still submitting scores under a pasted support `player_id`.

## Highlights

- Android installs now treat the Android-backed source identity as the canonical reinstall key instead of silently minting a new progression identity.
- Restoring an older support `player_id` now attempts to migrate that profile onto the phone's canonical Android-backed app id so later reinstalls on the same phone restore automatically.
- Existing blocked test names such as `DebugSave` are now retired from cached/public-name use instead of surviving locally across updates.
- Restore installs that temporarily used a pasted support `player_id` now auto-handoff back onto the phone's canonical Android-backed player/device identity once Android finishes resolving it.
- Score-beaten notifications now send only one alert per run, using the highest family score that the new run actually beat.
- The post-death results screen now focuses on synced `Personal Best` wording when a cloud profile exists instead of talking about a local best.
- Run achievement screenshots now wait for the end-run results screen, so Discord shares capture the scoreboard state instead of an unrelated menu screen.
- Existing leaderboard rows can now accept a valid renamed public name instead of being locked forever to the first inserted name.
- The game now opens on a dedicated title screen with the `BadGames` and `EndlessHelicopter` marks, a credits path, and the temporary AI-art notice kept off the main menu.

## Player-Facing Fixes

- Returning players on the same phone should resume cloud-backed progress after reinstall once their profile has been migrated onto the phone's canonical Android-backed app id.
- Fresh Android installs no longer invent a replacement progression identity while the stable Android-backed path is still pending.
- Temporary support restores no longer stay stuck on the pasted `player_id` after the phone's real Android-backed identity is ready, so later score submits stop colliding with the restored leaderboard name.
- Support can now retire legacy test profiles and merge split player histories onto one canonical Android-backed account before a restore.
- Discord score-beaten posts are less noisy because one run no longer fans out into multiple alerts for every lower beaten score.
- The results screen now gives clearer synced leaderboard feedback after a run.
- New personal best and unlock screenshots should now reflect the end-run screen players actually care about.
- Daily streak milestone screenshots still use the share-card style flow.
- Public leaderboard names remain optional until the player actually wants to submit a score.

## Backend And Ops Notes

- `migrate_player_identity()` now also updates `app_update_push_history`, so update-push dedupe follows the migrated device id instead of treating the same phone as new hardware.
- The release path now reserves `DebugSave`, clears it from cached local names, and keeps restored public-name state aligned with the stricter filter.
- The Supabase leaderboard name guard now rejects duplicates without freezing every later update to the old name, so support merges can correct visible player names cleanly.
- Startup restore now waits for the full Android-backed player/device identity before permanently rebinding a pasted support `player_id`, and it auto-clears the temporary override once the canonical device identity is ready.
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
