# Development

## Core Commands

### Validate key Godot scripts

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_godot.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe"
```

This full validator parses the main scripts and runs the focused gameplay checks added for the depth/feedback work, including depth retention, feedback fairness, enemy threat, spawn responsiveness, daily mission expansion, pause-menu missions, UI naming, score/combo feedback, release notes, and feature discovery.

It also runs release hygiene validation before Godot starts, checking that `export_presets.cfg`, `systems/build_info.gd`, and release notes all agree on the same version name/code.

For narrow iteration on recent run-depth changes, useful focused scripts include:

- `res://tools/validate_depth_retention.gd`
- `res://tools/validate_feedback_sprint.gd`
- `res://tools/validate_enemy_threat_pass.gd`
- `res://tools/validate_spawn_layout_responsiveness.gd`
- `res://tools/validate_daily_mission_expansion.gd`
- `res://tools/validate_pause_menu_missions.gd`
- `res://tools/validate_ui_naming_consistency.gd`
- `res://tools/validate_score_feedback_and_combo.gd`

### Validate live reinstall and restore migration

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_supabase_reinstall_restore.ps1
```

This live Supabase check requires `SUPABASE_ACCESS_TOKEN`. It uses the Supabase MCP endpoint in write-capable mode, inserts only synthetic rows inside a transaction, verifies reinstall/restore migration behavior, and rolls the transaction back before exit.

For the live signing cutover and final gameplay-data reset, use [ANDROID_CONTINUITY_CUTOVER.md](ANDROID_CONTINUITY_CUTOVER.md) as the operator runbook.

### Export Android locally

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_android.ps1 -GodotBin "C:\Path\To\Godot_v4.6.2-stable_win64_console.exe" -SigningMode release_stable
```

That script rebuilds the Android push bridge before export and writes the canonical local APK into `build/android/`. Install that fresh output, not any older APK that may still be sitting elsewhere in the repo.

The export script now refuses identity-unsafe Android builds unless you explicitly pass `-AllowIdentityUnsafeBuild`. Use that escape hatch only for disposable smoke tests that should never be used for reinstall or restore validation.

For push-notification debugging, the exported app now reports:

- whether the plugin singleton loaded
- whether the compat bridge is available
- whether Android runtime objects were exposed to GDScript
- whether player and device identity are using the Android-backed derived, legacy cached, or waiting-for-Android-backed path on Android
- which signing mode the build was exported with and a preview of the actual signing certificate hash
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

## What To Update When Changing Run Depth

- Update [README.md](../README.md) when player-facing run systems, mission behavior, or Android testing expectations change.
- Update [ARCHITECTURE.md](ARCHITECTURE.md) when autoload ownership, gameplay flow, mission progress timing, or sync assumptions change.
- Update folder `SKILL.md` files when an implementation rule should guide future agent work.
- Keep mission progress live when it is visible mid-run from the pause menu; use `MissionManager.record_live_mission_progress()` for immediate pickup/effect events and preserve the end-of-run summary path for final totals.
- Keep daily mission sync monotonic. Startup restore should preserve local progress when it is ahead of Supabase, queued local daily mission sync payloads should merge upward, and `sync-daily-mission-progress` should merge per-mission progress instead of overwriting rows with stale payloads.
- Do not call `refresh_daily_missions()` from a path that can interrupt live mission mutation unless the mutation guard is active; profile-change UI refreshes must not reload stale mission state before live progress is saved.
- Cover delayed cloud restore cases when changing missions: a live completion must remain complete even if remote mission/profile state is restored before the run reaches the results screen.
- When preparing a device-test or release candidate, keep `export_presets.cfg`, `systems/build_info.gd`, [docs/release_notes/latest.md](release_notes/latest.md), and [docs/release_notes/discord_summary.md](release_notes/discord_summary.md) in agreement.
- For release-only checks, run `powershell -ExecutionPolicy Bypass -File .\tools\validate_release_hygiene.ps1`. On `main`, CI also runs it after GitHub release publication with `-CheckGithubLatest` so the public latest release tag/title must match the checked-in version.

## CI

- Workflow: `.github/workflows/android-apk.yml`
- Before any release build, always bump `export_presets.cfg` `version/code` and `version/name`, then update `docs/release_notes/latest.md` and `docs/release_notes/discord_summary.md` to match.
- Pull requests to `main` run validation and produce an APK artifact.
- Pushes to `main` run validation, build an Android APK, publish a versioned GitHub release, and refresh the rolling `android-latest` prerelease alias.
- Manual workflow runs only publish a release when they target `main`; branch and PR runs stay artifact-only.
- CI also builds the Android FCM plugin AARs before exporting the APK.
- Outputs include a workflow artifact containing the generated APK.
- Outputs also include the rolling GitHub prerelease alias `Endless-Helicopter-Reborn Latest APK`.
- PR APK names can be `Endless-Helicopter-Reborn-debug.apk` or `Endless-Helicopter-Reborn-release.apk` depending on the configured canonical signing key.
- Pushes to `main` must produce `Endless-Helicopter-Reborn-release.apk` from the canonical stable release key for user-facing releases. A continuity-safe debug-signed APK is only for controlled testing when the stable debug key is intentionally used on non-public builds.

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
- CI now fails Android APK builds if neither the canonical release keystore nor the canonical debug keystore is configured, and `main` public release publishing requires the canonical release keystore specifically.
- Once users have installed a signing track, do not rotate from one stable keystore to another without planning a one-time manual restore/migration event.
- `export_presets.cfg` now enables Android user-data backup and retain-data-on-uninstall as a local safety net for settings/profile files.
- For official progression-safe installs, use the stable release keystore. The optional stable debug keystore is only for controlled testing and is not the canonical public signing track.
- The workflow writes artifacts to `build/android/`.
- The GitHub release is updated automatically on each successful build.

## Release Cutover Checklist

Use this order for the stable release-key continuity cutover and any future fresh-start gameplay-data wipe:

1. Confirm the permanent stable release key is configured through:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
2. Bump `export_presets.cfg` version metadata and update release notes.
3. Build and install the stable release-signed APK.
4. Verify the app's Debug diagnostics show:
   - `Signing: Stable release key`
   - a stable signing-certificate preview
5. Publish or update `app_release_channels` for the `stable` channel.
6. Raise `app_release_channels.minimum_supported_version_code` to the cutover build so older builds are force-upgraded.
7. Only after the version gate is live, run [backend/supabase_fresh_start_cutover_wipe.sql](../backend/supabase_fresh_start_cutover_wipe.sql) to wipe the gameplay-data tables listed in [ANDROID_CONTINUITY_CUTOVER.md](ANDROID_CONTINUITY_CUTOVER.md).
8. Preserve the operational/config tables listed in that runbook.
9. Re-test same-device uninstall/reinstall on the official build and confirm automatic restore without manual support restore.

This cutover is a fresh-start gameplay-data wipe. Pre-wipe cloud progression is intentionally retired.

## MCP Servers

- Repo-local Codex MCP config lives in [`.codex/config.toml`](../.codex/config.toml).
- Repo-local VS Code MCP config lives in [`.vscode/mcp.json`](../.vscode/mcp.json).
- See [docs/MCP_SETUP.md](MCP_SETUP.md) for login/auth steps and optional add-on servers.
