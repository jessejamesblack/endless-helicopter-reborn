# Weekly Discord Recap Setup

Sprint 6 adds a lightweight weekly family recap that posts to Discord without needing a full bot.

## Files

- Edge Function: [backend/supabase/functions/send-weekly-discord-recap/index.ts](../backend/supabase/functions/send-weekly-discord-recap/index.ts)
- SQL setup: [backend/supabase_app_release_setup.sql](../backend/supabase_app_release_setup.sql)

## Deploy

```powershell
supabase functions deploy send-weekly-discord-recap --workdir backend --use-api --no-verify-jwt
```

Recommended secrets:

- `DISCORD_GAME_EVENTS_WEBHOOK_URL`
- `RELEASE_WEBHOOK_SECRET`

## Schedule

Recommended schedule:

- Sunday 7:00 PM America/New_York

If you are using Supabase cron, trigger the function with a POST body like:

```json
{
  "family_id": "global"
}
```

and include:

- `x-release-webhook-secret: YOUR_RELEASE_WEBHOOK_SECRET`

For the most reliable setup, prefer an hourly cron job with an `America/New_York` gate in SQL instead of a single fixed UTC schedule. That avoids manual DST updates between EDT and EST.

## Behavior

- Posts the top score from the last 7 days.
- Includes the best near-miss and daily-mission activity when recent runs contain that data.
- Summarizes new unlocks when the run history contains them.
- Posts a gentle "no activity this week" recap instead of failing loudly when the family was quiet.
