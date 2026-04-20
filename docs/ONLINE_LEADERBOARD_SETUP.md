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

- Android devices derive a reinstall-stable player id from the signed app package plus the device's Android-backed stable id, first through the Android bridge and then through Godot's own Android unique-ID fallback if needed.
- Existing legacy Android installs migrate old cached player ids to the canonical stable id the first time the stable id resolves.
- If support restores an older pasted `player_id` on a device whose canonical stable id is ready, the app now attempts to migrate that old profile onto the phone's stable id so future reinstalls on the same phone restore automatically.
- Each device saves a public player name locally after the first submitted run.
- Cloud profile restore and progression sync do not require a public name; the player only needs to choose one before publishing a leaderboard score.
- Player names use a simple profanity filter.
- The database enforces unique public names within a leaderboard.
- The database stores one current best score per player.
- In-app score-beaten alerts are stored in `family_notifications`.
- The post-run results screen shows a synced `Personal Best` view when a cloud profile exists and falls back to on-device wording when it does not.

## Notes

- This is intentionally lightweight and uses a public client key.
- Anyone with the app and your `FAMILY_ID` can submit scores to that board.
- For a casual shared board, this is fine.
- For cheat-resistant competition, you would eventually want signed server-side score validation or a stronger account model.
