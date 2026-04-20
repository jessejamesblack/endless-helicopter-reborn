# Endless Helicopter Reborn 1.6.3

Version 1.6.3 is the next stable Android release. It focuses on post-run polish, clearer synced leaderboard feedback, and more reliable achievement screenshot capture.

## Highlights

- Score-beaten notifications now send only one alert per run, using the highest family score that the new run actually beat.
- The post-death results screen now focuses on synced `Personal Best` wording when a cloud profile exists instead of talking about a local best.
- Run achievement screenshots now wait for the end-run results screen, so Discord shares capture the scoreboard state instead of an unrelated menu screen.

## Player-Facing Fixes

- Discord score-beaten posts are less noisy because one run no longer fans out into multiple alerts for every lower beaten score.
- The results screen now gives clearer synced leaderboard feedback after a run.
- New personal best and unlock screenshots should now reflect the end-run screen players actually care about.
- Daily streak milestone screenshots still use the share-card style flow.

## Backend And Ops Notes

- The leaderboard notification SQL now emits only the strongest `score_beaten` notification for each score submit.
- The results screen now fetches the current player's Supabase best row directly for synced personal-best messaging.
- Release publishing still happens only from `main`; PR and branch builds remain artifact-only.

## Safety Notes

- Cloud profile restore still uses `player_id`, not public display name.
- The results screen still falls back to on-device best-score wording when a synced profile is not available.
- Operational logs and release automation continue to avoid raw secrets, webhook URLs, and push tokens.
