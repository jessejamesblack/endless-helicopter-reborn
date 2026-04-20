# Endless Helicopter Reborn

`Endless Helicopter Reborn` is a Godot 4.6 mobile arcade game. You pilot a vehicle through an endless obstacle field, bounce off the arena bounds to recover from mistakes, collect ammo, fire missiles, trigger rare glowing-rock screen clears, complete daily missions, unlock vehicles and per-vehicle finishes, compete on a shared online leaderboard, and tune controls, haptics, and frame rate from the settings menu.

## Features

- Endless survival-style arcade gameplay
- Mobile-friendly tap/click/space controls
- Missiles, ammo pickups, clearer explosions, and varied enemy roles
- Adjustable master/music/SFX volume, fire-button side, mirrored HUD layout, haptics intensity, and frame-rate cap
- Shared online leaderboard with player names
- Daily missions, vehicle unlocks, per-vehicle skin progression, and a hangar screen
- In-app beat-your-score notifications
- Android push notifications for score-beaten and daily-mission events
- Hybrid parallax background biomes for long runs
- Original retro sci-fi menu and gameplay music
- Automated Android APK builds with GitHub Actions

## Project Layout

```text
res://
  assets/
    art/
    audio/
    icons/
  backend/
  docs/
  scenes/
    effects/
    enemies/
    game/
    pickups/
    player/
    projectiles/
    ui/
  systems/
  tools/
```

## Opening The Project

1. Install Godot `4.6.x`.
2. Open the repository root in Godot.
3. The main scene is [scenes/ui/start_screen/start_screen.tscn](scenes/ui/start_screen/start_screen.tscn).

## Settings And Pause

- `Settings` is available from the start screen before a run.
- During a run, `Pause` opens a menu with resume, settings, and quit-to-menu actions.
- Settings persist in `user://` and apply immediately.
- `Master Volume` controls the full mix.
- `Music Volume` controls the menu and gameplay music layer.
- `SFX Volume` controls effects only, such as helicopter, missiles, reloads, and explosions.

## Collaboration Flow

This repository now uses branches and pull requests for changes to `main`.

1. Create a branch from `main`.
2. Push your branch.
3. Open a pull request back into `main`.
4. Let CI validate the branch before merging.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the working agreement.

This repo also includes a local `.githooks/pre-push` guard to help block accidental direct pushes to `main`.

## Local Validation

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_godot.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

## Shared Leaderboard

The game can use Supabase for a shared leaderboard.

- Setup guide: [docs/ONLINE_LEADERBOARD_SETUP.md](docs/ONLINE_LEADERBOARD_SETUP.md)
- Push setup: [docs/PUSH_NOTIFICATIONS_SETUP.md](docs/PUSH_NOTIFICATIONS_SETUP.md)
- Daily mission push setup: [docs/DAILY_MISSIONS_PUSH_SETUP.md](docs/DAILY_MISSIONS_PUSH_SETUP.md)
- SQL bootstrap: [backend/supabase_leaderboard_setup.sql](backend/supabase_leaderboard_setup.sql)
- Player progress bootstrap: [backend/supabase_player_progress_setup.sql](backend/supabase_player_progress_setup.sql)
- Runtime service: [systems/online_leaderboard.gd](systems/online_leaderboard.gd)
- Push runtime: [systems/push_notifications.gd](systems/push_notifications.gd)

Current leaderboard/profile behavior:

- Android installs derive a reinstall-stable `player_id` from the signed app package plus Android-backed device identity.
- Returning players on the same phone should restore automatically after reinstall once their profile has been migrated onto that stable id.
- Manual support restore by old `player_id` is still available in Settings, and current builds try to permanently migrate that old profile onto the phone's canonical stable id so future reinstalls on that device restore automatically.
- A public name is only required for leaderboard submission. Cloud profile restore and progression sync can exist before the player picks a public leaderboard name.

## Android Push Notifications

Android push notifications use:

- Firebase Cloud Messaging for delivery
- a custom Godot Android plugin under [android/plugins/fcm_push_bridge](android/plugins/fcm_push_bridge)
- a Supabase Edge Function under [backend/supabase/functions/send-score-beaten-push](backend/supabase/functions/send-score-beaten-push)

This works with sideloaded APKs. You do not need Play Store publishing to receive FCM notifications on supported Android devices.

Current Android builds also include a compatibility bridge so push registration can still work when the plugin singleton loads but Godot does not expose every bridge method reliably through the usual plugin path. If the in-game diagnostics say `Compat bridge available: yes`, you are on the current push-capable Android bridge.

## Android APK Installation

### From a local build

1. Export the Android preset with `tools/export_android.ps1`.
2. Use the freshly exported APK from `build/android/`.
3. Copy that APK to your Android device.
4. Open the APK on the device.
5. If prompted, allow installs from unknown apps for the app you used to open the file.
6. Finish installation.

Avoid installing older APKs that happen to be sitting elsewhere in the repo, such as stale root-level exports. Those can contain an outdated Android push bridge even when the current source and AARs are correct.

After installing, open the in-game push diagnostics and confirm at least:

- `Plugin loaded: yes`
- `Compat bridge available: yes`
- `Bridge diagnostics available: yes`
- `Firebase ready: yes`

### From GitHub Releases

Each successful release build from `main` creates or updates:

- a versioned GitHub release such as `v1.6.1-build.155`
- a rolling prerelease alias named `android-latest`

1. Open the repository on GitHub.
2. Go to `Releases`.
3. Open either the latest versioned release or `Endless-Helicopter-Reborn Latest APK`.
4. Download `Endless-Helicopter-Reborn-debug.apk` or `Endless-Helicopter-Reborn-release.apk`.
5. Copy the APK to your Android device and install it.

### From GitHub Actions artifacts

If you want the raw workflow output directly, every push also uploads an artifact.

1. Open the repository on GitHub.
2. Go to `Actions`.
3. Open the latest `Android APK` workflow run.
4. Download the `Endless-Helicopter-Reborn-*` artifact.
5. Copy the APK to your Android device and install it.

## GitHub Actions APK Builds

This repository includes `.github/workflows/android-apk.yml`.

- Every candidate release should increment `export_presets.cfg` `version/code` and `version/name` before building or publishing.
- On pull requests to `main`, it validates the project and exports an Android APK artifact.
- On pushes to `main`, it validates the project, exports an Android APK, publishes a versioned GitHub release, and refreshes the rolling `android-latest` prerelease alias.
- Manual workflow runs only publish a release when they are run from `main`; branch and PR builds stay artifact-only.
- The workflow also builds the Android FCM plugin AAR before the APK export.
- The APK is uploaded as a workflow artifact.
- The workflow also updates a rolling GitHub prerelease alias named `Endless-Helicopter-Reborn Latest APK`.
- Pull request APK filenames use `Endless-Helicopter-Reborn-debug.apk` unless signing secrets are present.
- Pushes to `main` publish `Endless-Helicopter-Reborn-release.apk` when signing secrets are configured, otherwise they fall back to `Endless-Helicopter-Reborn-debug.apk`.
- This is better than committing generated APKs into the repository on every change.

### Stable signed builds

If you want Android installs to upgrade cleanly between CI builds, add these GitHub repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`

If these secrets are not present, pull request and `main` builds fall back to a temporary debug keystore for artifact generation.

## AI Collaboration

This repo intentionally follows a lightweight harness-engineering approach:

- short `AGENTS.md` as a map
- docs as the source of truth
- deterministic validation/export scripts
- CI as a feedback loop

See [docs/AI_COLLABORATION.md](docs/AI_COLLABORATION.md) for the project-specific rules.
