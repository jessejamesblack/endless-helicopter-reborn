# Error Alert Email Setup

Sprint 6 uses Resend for developer-facing error alert emails from the `report-client-error` Edge Function.

## Secrets

Set these Supabase function secrets:

- `RESEND_API_KEY`
- `ERROR_ALERT_TO_EMAIL`
- `ERROR_ALERT_FROM_EMAIL`

## Where The Values Come From

### `RESEND_API_KEY`

Create this in the Resend dashboard after you sign in:

1. Open the API Keys dashboard.
2. Click `Create API Key`.
3. Give it a name like `endless-helicopter-errors`.
4. Choose `Sending access` if you want the tighter permission, or `Full access` if you prefer.
5. Copy the key immediately and store it as `RESEND_API_KEY`.

Resend only shows the API key value once.

Official docs:

- https://resend.com/docs/dashboard/api-keys/introduction

### `ERROR_ALERT_FROM_EMAIL`

This should be a sender address on a domain you control and verify in Resend, for example:

- `alerts@updates.yourdomain.com`
- `errors@updates.yourdomain.com`

Recommended flow:

1. Add a domain or subdomain you own in Resend.
2. Add the DNS records Resend gives you.
3. Wait for the domain to verify.
4. Use any address at that verified domain for the `from` address.

Resend recommends using a subdomain to isolate sending reputation. After the domain is verified, you can send from any address at that domain. The mailbox does not need to be pre-created in Resend, though using an address that can receive replies is still a good idea.

Official docs:

- https://resend.com/docs/dashboard/domains/introduction
- https://resend.com/docs/knowledge-base/how-do-I-create-an-email-address-or-sender-in-resend

### `ERROR_ALERT_TO_EMAIL`

This is simply the inbox where you want to receive the alerts.

Examples:

- your main Gmail or Outlook address
- a family/admin mailbox
- a monitored support inbox

This does not need to be hosted on Resend. It is just the recipient address for the alert emails.

## Recommended Setup

- Verify a subdomain such as `updates.yourdomain.com` or `alerts.yourdomain.com`.
- Use `alerts@updates.yourdomain.com` as `ERROR_ALERT_FROM_EMAIL`.
- Use your real inbox as `ERROR_ALERT_TO_EMAIL`.
- Use a domain-scoped `Sending access` API key if you want the narrowest permission set.

## Set The Secrets

Example:

```powershell
supabase secrets set `
  RESEND_API_KEY="re_xxxxxxxxx" `
  ERROR_ALERT_TO_EMAIL="you@example.com" `
  ERROR_ALERT_FROM_EMAIL="alerts@updates.example.com"
```

## Quick Test

After setting the secrets, trigger a test `error` or `fatal` report through the client error reporter flow and confirm:

- the event is written to `public.client_error_events`
- the email arrives at `ERROR_ALERT_TO_EMAIL`
- repeated identical errors do not spam you because the function dedupes and rate-limits alerts
