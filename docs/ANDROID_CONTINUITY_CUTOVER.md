# Android Continuity Cutover

This runbook is the source of truth for the planned Android signing cutover that is intended to make same-device uninstall/reinstall restore work automatically going forward.

## Why This Exists

Past Android restore failures were not caused only by app logic. The bigger problem was signing-key churn.

- Android-backed same-device identity is derived from the app package plus Android device identity in a way that depends on the app signing key.
- When installable builds were signed with different keys, the same phone could produce different canonical app `player_id` values across reinstalls.
- That split cloud progression across multiple identities and made automatic restore unreliable.

This document is procedural. It describes the required cutover event and should not be read as proof that the live release and wipe have already happened.

## Canonical Policy

- All user-facing Android builds use the permanent `stable release key`.
- Same-device automatic restore is only promised for official builds from this post-cutover signing epoch onward.
- The optional stable debug key is for controlled testing only and is not the canonical public track.
- Temporary or unspecified signing must never be used for reinstall or restore validation.

## Required GitHub Secrets

Configure these repository secrets for the canonical release-signing path:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`

The Android workflow is expected to fail loudly if these are missing for a user-facing build path.

## Cutover Event

The fresh-start cutover should happen in this order:

1. Bump `export_presets.cfg` `version/code` and `version/name`.
2. Build the Android APK with the permanent stable release key.
3. Verify in the installed app's Debug diagnostics that the build reports:
   - `Signing: Stable release key`
   - a stable signing-certificate preview
4. Publish or update `app_release_channels` for the `stable` channel.
5. Set `app_release_channels.minimum_supported_version_code` to the cutover build's version code so older builds are forced forward.
6. Wipe only the agreed gameplay/user-data tables.
7. Leave operational/config tables intact.
8. Validate that a fresh install, then uninstall/reinstall on the same device, restores automatically without manual support restore.

The version gate is part of the cutover. Older builds must stop writing to Supabase before or during the wipe, or they can repopulate stale identities immediately.

## Fresh-Start Gameplay-Data Wipe

This cutover is a fresh start. Pre-wipe cloud progression is intentionally retired.

### Wipe These Tables

- `family_player_profiles`
- `family_daily_mission_progress`
- `family_leaderboard`
- `family_run_history`
- `family_notifications`
- `family_push_devices`
- `family_push_delivery_log`
- `app_update_push_history`

### Preserve These Tables

- `app_release_channels`
- `family_push_runtime_config`
- `family_weekly_recap_log`
- `family_daily_dispatch_log`
- `client_error_events`
- `family_feedback_reports`

The wipe is gameplay-data only. It is not a full operational database reset.

## Support Policy After Cutover

- This is a fresh-start signing epoch.
- Pre-wipe cloud progression is not promised to be recoverable after the reset.
- After the cutover has been executed, same-device automatic restore is guaranteed only for official builds signed with the permanent stable release key from that point forward.
- Cross-device recovery is still a separate problem and is not solved by this cutover.
- Android OS notification permission may still need to be granted again after reinstall even when cloud notification preferences restore correctly.

## Operator Checklist

Use this checklist for future release/cutover work that touches reinstall, restore, signing, or Supabase reset behavior.

### Before Release

- Confirm the canonical signing track is the stable release key.
- Confirm `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_ALIAS` are configured in GitHub.
- Bump `export_presets.cfg` version metadata.
- Update release notes and support notes.

### Before Any Live Wipe Or Migration

- Confirm the new build is release-signed and continuity-safe in Debug diagnostics.
- Confirm the release artifact and URLs are ready for the `stable` channel.
- Raise `app_release_channels.minimum_supported_version_code` to the cutover build.
- Use the reviewed wipe script at `backend/supabase_fresh_start_cutover_wipe.sql`, not ad-hoc SQL in chat.
- If using Supabase MCP with write access, use a deliberate local override and keep the wipe plan explicit.

### After Cutover

- Install the cutover build on a clean device or emulator and create cloud data.
- Uninstall and reinstall the same signed build on the same device.
- Confirm the same canonical `player_id` is reported.
- Confirm profile, mission progress, leaderboard best, and notification preferences restore automatically.
- Confirm older builds receive the upgrade-required path and no longer sync.

## Expectations For Future Agents

- Do not diagnose Android identity churn without checking signing mode first.
- Do not propose a database wipe without naming both the wiped tables and the preserved tables.
- Do not recommend a partial rollout when a signing or continuity rule change requires a release-gated cutover.
- Do not treat pre-cutover restore failures as proof that the current stable-signing design is broken.
- For future PRs touching restore, reinstall, identity, release workflow, or Supabase reset behavior, consult this runbook first.
