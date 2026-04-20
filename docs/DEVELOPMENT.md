# Development

## Core Commands

### Validate key Godot scripts

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_godot.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

### Validate live reinstall and restore migration

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_supabase_reinstall_restore.ps1
```

This live Supabase check requires `SUPABASE_ACCESS_TOKEN`. It uses the Supabase MCP endpoint in write-capable mode, inserts only synthetic rows inside a transaction, verifies reinstall/restore migration behavior, and rolls the transaction back before exit.

### Export Android locally

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_android.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

That script rebuilds the Android push bridge before export and writes the canonical local APK into `build/android/`. Install that fresh output, not any older APK that may still be sitting elsewhere in the repo.

For push-notification debugging, the exported app now reports:

- whether the plugin singleton loaded
- whether the compat bridge is available
- whether Android runtime objects were exposed to GDScript
- whether player and device IDs are using the Android-backed, legacy-cache, or local-fallback path
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
- Pull requests to `main` run validation and produce an APK artifact.
- Pushes to `main` run validation, build an Android APK, and update the rolling release.
- Manual workflow runs only publish a release when they target `main`; branch and PR runs stay artifact-only.
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
- The current push implementation also depends on the compat bridge classes under `android/plugins/fcm_push_bridge/src/main/java/com/endlesshelicopter/push/`.
- `tools/export_android.ps1` is the canonical local Android export path because it rebuilds the plugin AARs before packaging.
- The canonical local install artifact lives under `build/android/`.
- Avoid sideloading old APKs from the repo root or other ad-hoc locations; they can contain stale Android push bridge binaries.
- A successful install should show `Compat bridge available: yes` in the in-game push diagnostics.
- Local plugin builds require Gradle, Java 17, and the Android SDK.
- The Firebase config file belongs at `android/plugins/fcm_push_bridge/google-services.json` and is intentionally ignored by git.
- CI can build temporary debug artifacts for pull requests without a permanent keystore.
- Pushes to `main` can still publish a debug build if repository signing secrets are missing.
- `export_presets.cfg` now enables Android user-data backup and retain-data-on-uninstall as a local safety net for settings/profile files.
- For progression-safe installs between CI builds, use repository secrets for either the stable release keystore or the optional stable debug keystore.
- Temporary-key CI artifacts are test-only and can change the Android-backed player identity across builds.
- The workflow writes artifacts to `build/android/`.
- The GitHub release is updated automatically on each successful build.

## MCP Servers

- Repo-local Codex MCP config lives in [`.codex/config.toml`](../.codex/config.toml).
- Repo-local VS Code MCP config lives in [`.vscode/mcp.json`](../.vscode/mcp.json).
- See [docs/MCP_SETUP.md](MCP_SETUP.md) for login/auth steps and optional add-on servers.
