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

## What To Update When Moving Files

- `.tscn` `ext_resource` paths
- GDScript `preload()` and `change_scene_to_file()` paths
- `project.godot` main scene and icon paths
- docs that reference moved files
- `.import` files if the source asset path changed

## CI

- Workflow: `.github/workflows/android-apk.yml`
- Pull requests to `main` run validation and produce an APK artifact.
- Pushes to `main` run validation, build the APK, and update the rolling release.
- Outputs include a workflow artifact containing the generated APK.
- Outputs also include a rolling GitHub prerelease: `Endless-Helicopter-Reborn Latest APK`.
- APK names are `Endless-Helicopter-Reborn-debug.apk` or `Endless-Helicopter-Reborn-release.apk`.

## Branching

- Do not push feature work directly to `main`.
- Create a branch, push it, and open a pull request into `main`.
- Keep changes small enough that CI and review stay readable.
- See [CONTRIBUTING.md](../CONTRIBUTING.md) for the repo workflow.
- This repo includes `.githooks/pre-push`; set `git config core.hooksPath .githooks` in new clones if needed.

## Android Export Notes

- CI can build unsigned-temporary-style debug artifacts without a permanent keystore.
- For upgradeable installs between CI builds, use repository secrets for a stable keystore.
- The workflow writes artifacts to `build/android/`.
- The GitHub release is updated automatically on each successful build.
