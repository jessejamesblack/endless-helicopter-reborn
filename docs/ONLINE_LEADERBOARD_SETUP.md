# Online Leaderboard Setup

This game now supports a shared leaderboard using Supabase's REST API.

## 1. Create a Supabase project

Create a project in Supabase, then open the SQL editor and run:

`backend/supabase_leaderboard_setup.sql`

## 2. Copy your project URL and anon key

From the Supabase dashboard, copy:

- Project URL
- anon public API key

## 3. Fill in the game config

Edit:

`systems/online_leaderboard.gd`

Set:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `FAMILY_ID`

Use the same `FAMILY_ID` on every device that should share a leaderboard. If you use `global`, everyone on that build shares the same board.

## 4. Re-export Android with internet enabled

`export_presets.cfg` has been updated to request internet access.

## What the game now does

- Each device keeps a saved player name.
- Player names use a simple built-in profanity filter.
- The database now enforces globally unique player names within each leaderboard.
- The leaderboard keeps scores tied to a per-device player id, so the board shows each person's best run cleanly.
- When someone posts a new personal best that beats your best score, the game creates a cross-device alert for you.

## Beat alerts

Beat alerts are shown in-game on the menu and leaderboard screens the next time that player opens the app.

This is true cross-device notification data, but it is not yet an operating-system push notification.

## True phone push notifications

Real Android push notifications need one extra layer beyond GDScript:

- a push provider such as Firebase Cloud Messaging or OneSignal
- a Godot Android plugin or native Android integration to register device tokens and receive pushes

The game-side leaderboard data is now structured so that step can be added next without redoing the scoreboard flow.

## Notes

- This is intentionally lightweight.
- Anyone with the app and your `FAMILY_ID` could post scores, so this is best for casual competition unless you later add auth.
- If you want tighter control later, this can be upgraded to authenticated accounts or invite codes.
