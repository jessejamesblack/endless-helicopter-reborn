---
name: endless-helicopter-android
description: Use when editing android/, Android plugin code, APK export behavior, signing continuity, Firebase push bridge integration, or device-install workflows.
---

# Android

## Read First

- `docs/DEVELOPMENT.md` for export and plugin build commands.
- `docs/ANDROID_CONTINUITY_CUTOVER.md` before signing, identity, reinstall, restore, or data-wipe work.
- `docs/PUSH_NOTIFICATIONS_SETUP.md` before Firebase or push bridge changes.

## Signing And Identity

- Continuity-safe testing requires stable signing.
- Use `tools/export_android.ps1` for local APK exports.
- Do not rely on old APKs in the repo root or ad hoc export locations.
- Do not rotate stable keys or signing mode without an explicit migration/cutover plan.
- Keep Firebase `google-services.json` and keystore material out of git.

## Plugin Work

- Build the Android push plugin with `tools/build_android_plugin.ps1`.
- Keep Godot bridge APIs backward compatible where possible.
- Preserve diagnostics that report plugin availability, compat bridge status, Firebase readiness, and signing mode.

## Validation

- For local plugin changes, run `tools/build_android_plugin.ps1 -Variant Both`.
- For export changes, run `tools/export_android.ps1` with a stable signing mode.
- Run `tools/validate_godot.ps1` after changing Godot-facing Android identity or push scripts.
