# Online Leaderboard Setup

This game uses Supabase for the shared leaderboard and in-app score-beaten alerts.

For Android push notifications on top of the leaderboard, also follow [docs/PUSH_NOTIFICATIONS_SETUP.md](PUSH_NOTIFICATIONS_SETUP.md).

## 1. Create A Supabase Project

Create a project in Supabase, open the SQL editor, and run:

`backend/supabase_leaderboard_setup.sql`

That script creates:

- `family_leaderboard`
- `family_notifications`
- `family_push_devices`
- `family_push_delivery_log`
- `family_push_runtime_config`

If your project was already set up before the notification insert-policy fix, run this too:

`backend/supabase_fix_family_notifications_insert_policy.sql`

That fixes the `new row violates row-level security policy for the table "family_notifications"` error and allows score submissions to complete normally again.

If your project already used the older append-only leaderboard model, also run:

`backend/supabase_migrate_leaderboard_to_best_scores.sql`

That migrates the board to one stored best score per player, removes older duplicate runs, and installs the new RPC-based score submit path.

## 2. Copy Your Project URL And Anon Key

From the Supabase dashboard, copy:

- project URL
- anon public API key

## 3. Fill In The Game Config

Edit:

`systems/online_leaderboard.gd`

Set:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `FAMILY_ID`

Use the same `FAMILY_ID` on every device that should share a leaderboard.

If you want one world-wide board for everyone who installs the app, set:

`FAMILY_ID := "global"`

## 4. Export Android With Internet Enabled

`export_presets.cfg` already enables internet permission for Android.

## What The Leaderboard Does

- Android devices derive a reinstall-stable app `player_id` from the signed app package plus the device's Android-backed source id, first through the Android bridge and then through Godot's own Android unique-ID fallback if needed.
- The raw Android source id stays internal. The game hashes it into app-owned `player_id` and `device_id` values so reinstall continuity works without exposing the system identifier directly.
- Existing legacy Android installs migrate old cached player ids to the canonical Android-backed app id the first time that source id resolves.
- If support restores an older pasted `player_id` on a device whose canonical Android-backed app id is ready, the app now attempts to migrate that old profile onto the phone's canonical id so future reinstalls on the same phone restore automatically.
- Android exports also keep user-data backup enabled and request retain-data-on-uninstall, so local profile/config files have a backup safety net on supported devices.
- Same-device reinstall stability still depends on reinstalling builds signed with the same key. Official continuity now assumes the stable release key. The optional stable debug keystore is for controlled testing only, and temporary debug keys are test-only.
- The current restore model assumes a stable release signing epoch for official builds. The planned fresh-start gameplay-data wipe will retire pre-cutover cloud data when the cutover is executed; see [ANDROID_CONTINUITY_CUTOVER.md](ANDROID_CONTINUITY_CUTOVER.md) for the procedural cutover policy and support expectations.
- Configured online builds require a valid 1-12 character public player name before Play, Scores, Missions, Hangar, leaderboard publishing, cloud profile sync, or progression publishing. Unconfigured/offline dev builds can still play locally without a name.
- Each device saves that public player name locally after setup or the first valid leaderboard name entry.
- Player names use a simple profanity filter.
- The database enforces unique public names within both the leaderboard and synced player profiles.
- The database stores one current best score per player.
- In-app score-beaten alerts are stored in `family_notifications`.
- The post-run results screen shows a synced `Personal Best` view when a cloud profile exists and falls back to on-device wording when it does not.

## Notes

- This is intentionally lightweight and uses a public client key.
- Anyone with the app and your `FAMILY_ID` can submit scores to that board.
- For a casual shared board, this is fine.
- For cheat-resistant competition, you would eventually want signed server-side score validation or a stronger account model.
