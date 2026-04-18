# Development

## Core Commands

### Validate key Godot scripts

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_godot.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

### Export Android locally

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_android.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

### Build the Android push plugin locally

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_android_plugin.ps1 -Variant Both
```

## What To Update When Moving Files

- `.tscn` `ext_resource` paths
- GDScript `preload()` and `change_scene_to_file()` paths
- `project.godot` main scene and icon paths
- docs that reference moved files
- `.import` files if the source asset path changed

## CI

- Workflow: `.github/workflows/android-apk.yml`
- Pull requests to `main` run validation and produce an APK artifact.
- Pushes to `main` run validation, build an Android APK, and update the rolling release.
- CI also builds the Android FCM plugin AARs before exporting the APK.
- Outputs include a workflow artifact containing the generated APK.
- Outputs also include a rolling GitHub prerelease: `Endless-Helicopter-Reborn Latest APK`.
- PR APK names can be `Endless-Helicopter-Reborn-debug.apk` or `Endless-Helicopter-Reborn-release.apk` depending on signing secrets.
- Pushes to `main` can produce `Endless-Helicopter-Reborn-release.apk` when signing secrets are configured, otherwise they fall back to `Endless-Helicopter-Reborn-debug.apk`.

## Branching

- Do not push feature work directly to `main`.
- Create a branch, push it, and open a pull request into `main`.
- Keep changes small enough that CI and review stay readable.
- See [CONTRIBUTING.md](../CONTRIBUTING.md) for the repo workflow.
- This repo includes `.githooks/pre-push`; set `git config core.hooksPath .githooks` in new clones if needed.

## Android Export Notes

- Android push notifications require the custom plugin under `android/plugins/fcm_push_bridge`.
- Local Android exports should build the plugin AARs first with `tools/build_android_plugin.ps1`.
- Local plugin builds require Gradle, Java 17, and the Android SDK.
- The Firebase config file belongs at `android/plugins/fcm_push_bridge/google-services.json` and is intentionally ignored by git.
- CI can build temporary debug artifacts for pull requests without a permanent keystore.
- Pushes to `main` can still publish a debug build if repository signing secrets are missing.
- For upgradeable installs between CI builds, use repository secrets for a stable keystore.
- The workflow writes artifacts to `build/android/`.
- The GitHub release is updated automatically on each successful build.
