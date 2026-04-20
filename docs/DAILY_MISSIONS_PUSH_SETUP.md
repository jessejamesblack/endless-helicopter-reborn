# Daily Missions Push Setup

Sprint 3 adds a once-daily `daily_missions` push path on top of the existing score-beaten notification flow.

## Files

- SQL/RPC setup: [backend/supabase_player_progress_setup.sql](../backend/supabase_player_progress_setup.sql)
- Cron helper: [backend/supabase_daily_mission_push_setup.sql](../backend/supabase_daily_mission_push_setup.sql)
- Edge Function: [backend/supabase/functions/send-daily-mission-push/index.ts](../backend/supabase/functions/send-daily-mission-push/index.ts)
- Godot routing: [systems/push_notifications.gd](../systems/push_notifications.gd)

## Deploy The Function

```powershell
supabase functions deploy send-daily-mission-push --workdir backend --use-api --no-verify-jwt
```

Required secrets:

- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`
- `PUSH_WEBHOOK_SECRET`

The function uses the same Firebase and Supabase service-role setup as `send-score-beaten-push`.

## Apply The Player Progress SQL

Run:

`backend/supabase_player_progress_setup.sql`

That script adds:

- expanded leaderboard best-run stat columns
- `family_player_profiles`
- `family_daily_mission_progress`
- `family_run_history`
- daily mission push device preference support
- RPCs for profile sync, mission sync, and v2 score submit

## Schedule The Daily Push

Run:

`backend/supabase_daily_mission_push_setup.sql`

Before running it, replace:

- `YOUR_PROJECT_REF`

The recommended setup is an hourly cron job with an America/New_York gate inside the SQL helper.

That means:

- the cron worker wakes up every hour
- the SQL only calls the Edge Function during the `8:00 AM ET` hour
- the mission date is computed with the same `America/New_York` business-day rule the client uses
- you do not need to manually flip the schedule between EDT and EST

The payload shape is:

```json
{
  "type": "daily_missions",
  "family_id": "global"
}
```

## Behavior Notes

- The function only targets Android devices with:
  - `notifications_enabled = true`
  - `daily_missions_enabled = true`
- The function inserts into `family_daily_dispatch_log` so the same family/day combination does not get spammed repeatedly.
- It also skips players whose synced mission row for today is already `completed_count >= total_count`.
- Tapping the notification routes the game to the mission screen.
- The mission screen now shows `Resets daily at 8:00 AM ET`.
- The separate `score_beaten` push path now emits at most one notification per score submit: the highest family score the run actually beat.
