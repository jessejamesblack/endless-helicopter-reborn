# Endless Helicopter Reborn 1.6.6

Version 1.6.6 is the planned stable Android cutover release. It prepares the permanent stable release-signing epoch, the reviewed fresh-start gameplay-data wipe, and the stricter release-gating path that will force older builds forward before the live reset happens.

## Highlights

- Stable public Android releases now require the permanent release keystore on `main`; testing-only `debug_stable` builds stay available for controlled non-public validation.
- The repo now includes a reviewed fresh-start wipe script for the one-time Supabase gameplay-data reset.
- The cutover runbook now clearly separates the planned live cutover steps from repo preparation work, so docs no longer imply the wipe has already happened.
- Release notes and support guidance now frame automatic same-device restore as a promise that begins with the stable release-key cutover release and live wipe event.

## Player-Facing Fixes

- Once the live cutover is executed, official stable release-signed Android builds are intended to restore automatically on the same device after uninstall/reinstall.
- Notification preferences will restore from cloud/profile state after reinstall, while Android OS notification permission may still need to be granted again if the device prompts for it.
- Pre-cutover cloud progression will be intentionally retired by the fresh-start wipe and is not promised to be recoverable afterward.

## Backend And Ops Notes

- `main` public release publishing now requires `release_stable`; `debug_stable` is rejected for public release builds.
- The repo now includes `backend/supabase_fresh_start_cutover_wipe.sql` to wipe only user-bearing gameplay tables while preserving operational/config metadata.
- The cutover runbook calls out the required order explicitly: stable release build, live release gate update, then gameplay-data wipe.
- Release publishing still happens only from `main`; PR and branch builds remain artifact-only.

## Safety Notes

- Same-device reinstall stability still depends on reinstalling builds signed with the same stable release key.
- The live Supabase wipe must happen only after the cutover release is published and `minimum_supported_version_code` has been raised to this version.
- Cloud profile restore still uses `player_id`, not public display name.
- Release and reporting paths remain best-effort and do not block gameplay if an external service is unavailable.
