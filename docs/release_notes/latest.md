# Endless Helicopter Reborn 1.6.7

Version 1.6.7 follows the stable Android cutover with two reliability fixes: leaderboard best-score updates now survive same-player upserts correctly, and Discord achievement posts now include the player name so event notifications are easier to understand.

## Highlights

- Fixed a live leaderboard regression where higher scores from an existing player could be blocked by the leaderboard name-guard trigger during `upsert` writes.
- Achievement screenshot posts sent to Discord now include the player name in the heading and embed so unlocks and milestone posts are clearly attributable.
- The stable Android reinstall/restore cutover remains in place from `1.6.6`, so same-device continuity continues to depend on official stable release-signed builds.

## Player-Facing Fixes

- Higher best scores should now update the live leaderboard and run history correctly for existing players after reinstall/restore.
- Discord game-event posts for unlocks and milestone screenshots now show the player name when one is saved on-device.
- Notification preferences still restore from cloud/profile state after reinstall, while Android OS notification permission may still need to be granted again if the device prompts for it.

## Backend And Ops Notes

- The live leaderboard name-uniqueness trigger now ignores rows that already belong to the same `player_id`, which lets `submit_family_score_v2()` update an existing player row safely.
- The Discord screenshot webhook now accepts an optional `player_name` field and renders it in the message heading plus embed metadata.
- Public Android release publishing still requires `release_stable` on `main`; testing-only `debug_stable` builds stay non-public.

## Safety Notes

- Same-device reinstall stability still depends on reinstalling builds signed with the same stable release key.
- The post-cutover stable release epoch begins with the new permanent release key; older pre-cutover cloud progression remains intentionally retired.
- Cloud profile restore still uses `player_id`, not public display name.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
