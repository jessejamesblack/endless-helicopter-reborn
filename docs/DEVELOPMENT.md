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
- Output: workflow artifact containing the generated APK

## Android Export Notes

- CI can build unsigned-temporary-style debug artifacts without a permanent keystore.
- For upgradeable installs between CI builds, use repository secrets for a stable keystore.
- The workflow writes artifacts to `build/android/`.
