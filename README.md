# Endless Helicopter

`Endless Helicopter` is a Godot 4.6 mobile arcade game. You pilot a helicopter through an endless obstacle field, collect ammo, fire missiles, and now compete on a shared online leaderboard.

## Features

- Endless survival-style arcade gameplay
- Mobile-friendly tap/click/space controls
- Missiles, ammo pickups, explosions, and enemy variety
- Shared online leaderboard with player names
- In-app beat-your-score notifications
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

## Local Validation

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_godot.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

## Shared Leaderboard

The game can use Supabase for a shared leaderboard.

- Setup guide: [docs/ONLINE_LEADERBOARD_SETUP.md](docs/ONLINE_LEADERBOARD_SETUP.md)
- SQL bootstrap: [backend/supabase_leaderboard_setup.sql](backend/supabase_leaderboard_setup.sql)
- Runtime service: [systems/online_leaderboard.gd](systems/online_leaderboard.gd)

## Android APK Installation

### From a local build

1. Export the Android preset from Godot.
2. Copy the APK to your Android device.
3. Open the APK on the device.
4. If prompted, allow installs from unknown apps for the app you used to open the file.
5. Finish installation.

### From GitHub Actions

Every push can generate an APK artifact.

1. Open the repository on GitHub.
2. Go to `Actions`.
3. Open the latest `Android APK` workflow run.
4. Download the `android-apk-*` artifact.
5. Copy the APK to your Android device and install it.

## GitHub Actions APK Builds

This repository includes `.github/workflows/android-apk.yml`.

- On every push, it validates the project and exports an Android APK.
- The APK is uploaded as a workflow artifact.
- This is better than committing generated APKs into the repository on every change.

### Stable signed builds

If you want Android installs to upgrade cleanly between CI builds, add these GitHub repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`

If these secrets are not present, the workflow falls back to a temporary debug keystore for artifact generation.

## AI Collaboration

This repo intentionally follows a lightweight harness-engineering approach:

- short `AGENTS.md` as a map
- docs as the source of truth
- deterministic validation/export scripts
- CI as a feedback loop

See [docs/AI_COLLABORATION.md](docs/AI_COLLABORATION.md) for the project-specific rules.
