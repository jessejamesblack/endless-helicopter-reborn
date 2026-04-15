# Supabase Functions

This directory contains Supabase Edge Functions used by the game backend.

## send-score-beaten-push

Receives a beat-score payload from the database trigger flow and sends Android push notifications through Firebase Cloud Messaging.

Deploy it with:

```powershell
supabase functions deploy send-score-beaten-push --workdir backend --use-api --no-verify-jwt
```

Required function secrets:

- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`
- `PUSH_WEBHOOK_SECRET`

See [docs/PUSH_NOTIFICATIONS_SETUP.md](../../../docs/PUSH_NOTIFICATIONS_SETUP.md) for the full setup flow.
