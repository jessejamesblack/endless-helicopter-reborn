# Android Push Notifications Setup

This project supports Android push notifications for the existing `score_beaten` event.

The delivery path is:

1. The game submits scores to Supabase.
2. Supabase inserts a row into `family_notifications`.
3. A database trigger calls the `send-score-beaten-push` Edge Function.
4. The Edge Function sends Firebase Cloud Messaging notifications to registered Android devices.
5. Tapping the notification opens the game and routes the player to the leaderboard screen.

This works with sideloaded APKs. You do not need Play Store publishing, but the device must have Google Play Services.

## Files Involved

- SQL bootstrap: [backend/supabase_leaderboard_setup.sql](../backend/supabase_leaderboard_setup.sql)
- Supabase Edge Function: [backend/supabase/functions/send-score-beaten-push/index.ts](../backend/supabase/functions/send-score-beaten-push/index.ts)
- Godot runtime service: [systems/push_notifications.gd](../systems/push_notifications.gd)
- Android plugin project: [android/plugins/fcm_push_bridge](../android/plugins/fcm_push_bridge)
- Godot export plugin: [addons/fcm_push_bridge](../addons/fcm_push_bridge)

## 1. Confirm The Leaderboard Backend Exists

Run the bootstrap SQL in Supabase:

`backend/supabase_leaderboard_setup.sql`

The script now creates:

- leaderboard tables
- in-app notification tables
- push device registration tables
- push delivery log tables
- push runtime config

It is safe to rerun this script on the same project.

If your project was already live before the notification insert-policy fix, also run:

`backend/supabase_fix_family_notifications_insert_policy.sql`

Without that policy, new score submissions can fail with:

`new row violates row-level security policy for the table "family_notifications"`

If your project already used the older append-only leaderboard rows, also run:

`backend/supabase_migrate_leaderboard_to_best_scores.sql`

That migrates the leaderboard to one stored best score per player and installs the new best-score submit function.

## 2. Create A Firebase Project

1. Open the Firebase console.
2. Create a Firebase project or reuse one.
3. Add an Android app.
4. Use this package name:

`com.jessejamesblack.endlesshelicopterreborn`

5. Download `google-services.json`.

Firebase docs:

- https://firebase.google.com/docs/android/setup
- https://firebase.google.com/docs/cloud-messaging/android/client

## 3. Put `google-services.json` In The Android Plugin

For local builds, place the file here:

`android/plugins/fcm_push_bridge/google-services.json`

That file is ignored by git on purpose.

For GitHub Actions, base64-encode the same file and store it as this repository secret:

`FIREBASE_GOOGLE_SERVICES_JSON_BASE64`

CI fails if this secret is missing. That is intentional: without `google-services.json`, the APK can install and run but Firebase cannot initialize, so the app will never register a token in `family_push_devices`.

PowerShell example:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\google-services.json"))
```

## 4. Deploy The Supabase Edge Function

From your Supabase project root or this repo:

```powershell
supabase functions deploy send-score-beaten-push --workdir backend --use-api --no-verify-jwt
```

Set these function secrets:

- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`
- `PUSH_WEBHOOK_SECRET`

Helpful commands:

```powershell
supabase secrets set FCM_PROJECT_ID="your-firebase-project-id"
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
supabase secrets set PUSH_WEBHOOK_SECRET="long-random-secret"
```

Notes:

- Hosted Supabase Edge Functions already provide `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- `--no-verify-jwt` is required here because the database trigger posts to the function without a Supabase JWT.

Supabase docs:

- https://supabase.com/docs/guides/functions
- https://supabase.com/docs/guides/functions/secrets

Firebase HTTP v1 docs:

- https://firebase.google.com/docs/cloud-messaging/send/v1-api

## 5. Enable Push Dispatch In Supabase

The SQL bootstrap creates one row in `public.family_push_runtime_config`. Update it after the Edge Function is deployed:

```sql
update public.family_push_runtime_config
set
    enabled = true,
    function_url = 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-score-beaten-push',
    webhook_secret = 'YOUR_PUSH_WEBHOOK_SECRET'
where id = true;
```

If you want to disable push notifications without removing the rest of the leaderboard stack:

```sql
update public.family_push_runtime_config
set enabled = false
where id = true;
```

## 6. Build The Android Plugin AAR

The Godot export packages a custom Android plugin AAR. Build it before local Android exports:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_android_plugin.ps1 -Variant Both
```

Requirements:

- Gradle installed and on `PATH`, or a Gradle wrapper in `android/plugins/fcm_push_bridge`
- Android SDK installed
- Java 17 available

CI already builds the plugin automatically.

## 7. Android Runtime Notes

The Android push bridge now uses two paths on purpose:

- the normal Godot plugin singleton: `FCMPushBridge`
- a static compatibility bridge: `com.endlesshelicopter.push.FcmPushBridgeCompat`

The compatibility bridge exists because some Android exports can load the plugin but still fail Godot-side method detection or Android runtime lookup early in app startup. The compat path lets `systems/push_notifications.gd` call plain Kotlin static methods through `JavaClassWrapper`, while the Kotlin side caches Android `Activity` and application `Context` as soon as they are available.

In practice, this means:

- seeing `Plugin loaded: yes` is no longer enough by itself
- `Compat bridge available: yes` is the stronger signal that the APK contains the current push bridge implementation
- `Android runtime available: yes` means Godot exposed Android runtime objects directly to GDScript for this session
- push can still work even if `Android runtime available` is `no`, because the compat bridge also keeps its own cached context fallback
- fresh Android installs now derive both `player_id` and `device_id` from a hashed Android-backed stable id, so reinstalls on the same signed app keep push and leaderboard identity aligned
- existing installs keep any cached local ids they already had; this stabilizes identity going forward, but it does not migrate old server-side player ids automatically

## 8. Export Or Download The APK

Local export:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_android.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

That export script now rebuilds the Android push bridge plugin automatically before packaging the APK, so local Android builds do not silently reuse stale AARs. Install the freshly exported APK from `build/android/` after each export.

CI export:

- PRs to `main` build an artifact
- pushes to `main` update the rolling GitHub prerelease
- CI requires `FIREBASE_GOOGLE_SERVICES_JSON_BASE64` so the published APK can register for push.

## 9. Test Checklist

1. Install the APK on device A and device B.
2. Launch both devices once, open `Settings`, and tap `Enable Notifications`.
3. Submit a score on device A.
4. Beat that score on device B.
5. Confirm device A receives `Score Beaten`.
6. Tap the notification and verify the game opens to the leaderboard screen.

For first-pass verification on a single device, open the in-game debug or settings diagnostics panel after tapping `Enable Notifications` and confirm:

- `Plugin loaded: yes`
- `Compat bridge available: yes`
- `Player identity source: android_stable` on a fresh Android install
- `Device identity source: android_stable` on a fresh Android install
- `Bridge diagnostics available: yes`
- `Firebase ready: yes`
- `Permission granted: yes`
- `Token present: yes`
- `Device ID:` is populated

## Troubleshooting

Open the in-game `Settings` screen to see the current push diagnostic message. It reports whether the Android plugin loaded, Firebase config is present, notification permission is granted, an FCM token exists, and the Supabase registration request succeeded.

The debug panel now also shows `Player identity source` and `Device identity source`:

- `android_stable`: a fresh Android install is using the hashed Android-backed identity path
- `legacy_cache`: this install is still using an older cached random id from before the stable-id rollout
- `local_fallback`: the app could not resolve an Android-stable id and fell back to a local random id

If `family_push_delivery_log.device_id` and `family_push_delivery_log.fcm_token` are `NULL`, the backend did run, but there were no registered devices for the target player. Check `family_push_devices` next:

```sql
select
    family_id,
    player_id,
    device_id,
    notifications_enabled,
    last_seen_at,
    created_at,
    updated_at
from public.family_push_devices
order by updated_at desc;
```

Common causes:

- `family_push_devices` is empty: install the latest APK, open `Settings`, tap `Enable Notifications`, and keep the app open briefly.
- Settings says Firebase config is missing: confirm the APK was built with the matching `google-services.json` or GitHub secret.
- Settings says the APK is using an outdated Android push bridge: rebuild the plugin AARs and export a fresh APK. `tools/export_android.ps1` now does this automatically for scripted local exports.
- Local export worked but the device still shows the outdated bridge message: confirm you installed the fresh APK from `build/android/` and not an older APK from the repo root or another manual export path.
- Settings says `Android context is unavailable`: install a build that includes the compat bridge fallback, then check `Compat bridge available` and `Android runtime available` in the debug report. Current builds resolve Android context from both Godot runtime objects and cached Kotlin-side fallbacks.
- Settings shows `Plugin loaded: yes` but `Bridge diagnostics available: no`: the APK still contains an older bridge binary even if the plugin singleton name is present. Re-export and reinstall the APK from `build/android/`.
- Settings shows `Compat bridge available: no`: the APK was exported before the compat bridge classes were added, or the new AAR was not packaged into the export.
- Settings says permission is not granted: enable notifications in Android app settings, then tap `Enable Notifications` again.
- Settings says the plugin is not loaded: rebuild the Android plugin AAR and export an Android APK, not a desktop Godot runner build.
- A delivery row has `status = 'no_registered_devices'`: the score-beaten trigger fired correctly, but the beaten player has no active FCM token stored.

## Notes

- The leaderboard now stores only each player's current best score, not every historical run.
- The game still keeps in-app notification history in `family_notifications`.
- Push delivery is additive. If permission is denied, the leaderboard still works.
- Device registrations are stored in `family_push_devices`.
- Delivery attempts are stored in `family_push_delivery_log`.
