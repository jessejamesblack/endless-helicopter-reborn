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

That script rebuilds the Android push bridge before export and writes the canonical local APK into `build/android/`. Install that fresh output, not any older APK that may still be sitting elsewhere in the repo.

For push-notification debugging, the exported app now reports:

- whether the plugin singleton loaded
- whether the compat bridge is available
- whether Android runtime objects were exposed to GDScript
- whether player and device identity are using `android_stable`, `legacy_cache`, or `android_pending` on Android
- whether Firebase initialized successfully
- whether an FCM token was obtained and registered with Supabase

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
- Before any release build, always bump `export_presets.cfg` `version/code` and `version/name`, then update `docs/release_notes/latest.md` and `docs/release_notes/discord_summary.md` to match.
- Pull requests to `main` run validation and produce an APK artifact.
- Pushes to `main` run validation, build an Android APK, publish a versioned GitHub release, and refresh the rolling `android-latest` prerelease alias.
- Manual workflow runs only publish a release when they target `main`; branch and PR runs stay artifact-only.
- CI also builds the Android FCM plugin AARs before exporting the APK.
- Outputs include a workflow artifact containing the generated APK.
- Outputs also include the rolling GitHub prerelease alias `Endless-Helicopter-Reborn Latest APK`.
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
- The current push implementation also depends on the compat bridge classes under `android/plugins/fcm_push_bridge/src/main/java/com/endlesshelicopter/push/`.
- `tools/export_android.ps1` is the canonical local Android export path because it rebuilds the plugin AARs before packaging.
- The canonical local install artifact lives under `build/android/`.
- Avoid sideloading old APKs from the repo root or other ad-hoc locations; they can contain stale Android push bridge binaries.
- A successful install should show `Compat bridge available: yes` in the in-game push diagnostics.
- Local plugin builds require Gradle, Java 17, and the Android SDK.
- The Firebase config file belongs at `android/plugins/fcm_push_bridge/google-services.json` and is intentionally ignored by git.
- CI can build temporary debug artifacts for pull requests without a permanent keystore.
- Pushes to `main` can still publish a debug build if repository signing secrets are missing.
- For upgradeable installs between CI builds, use repository secrets for a stable keystore.
- The workflow writes artifacts to `build/android/`.
- The GitHub release is updated automatically on each successful build.

## MCP Servers

- Repo-local Codex MCP config lives in [`.codex/config.toml`](../.codex/config.toml).
- Repo-local VS Code MCP config lives in [`.vscode/mcp.json`](../.vscode/mcp.json).
- See [docs/MCP_SETUP.md](MCP_SETUP.md) for login/auth steps and optional add-on servers.
