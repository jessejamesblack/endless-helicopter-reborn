# Account Linking Setup

Sprint account linking uses **Supabase Auth email OTP** plus a server-side `player_account_links` table.

## What It Does

- lets players sign in with an email code
- links one Supabase Auth user to one existing gameplay `player_id`
- restores the linked profile across reinstalls and devices after the player signs in again
- keeps the current gameplay/profile tables intact

## Apply SQL

Run:

- [backend/supabase_account_linking_setup.sql](../backend/supabase_account_linking_setup.sql)

This creates `public.player_account_links` and locks it down behind RLS.

## Deploy Edge Functions

Deploy:

- `link-account-profile`
- `get-account-profile`

The existing protected progression functions should also be redeployed so they can resolve linked accounts server-side:

- `save-score`
- `sync-player-profile`
- `sync-daily-mission-progress`
- `get-player-profile`
- `get-daily-mission-progress`
- `get-notifications`
- `mark-notifications-read`
- `register-push-device`

## Supabase Auth Settings

In the Supabase dashboard:

1. Enable email sign-in / OTP.
2. Use an email template that shows the one-time code rather than only a magic link.
3. Configure SMTP if you need higher send limits than the built-in provider.

## Runtime Behavior

- signed-out players can still keep playing offline
- signed-in linked players restore the linked profile automatically
- signed-in unlinked players keep using the current anonymous profile until that profile is linked
- manual `player_id` restore in Settings remains a support fallback only
