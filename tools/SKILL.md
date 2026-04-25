---
name: endless-helicopter-tools
description: Use when adding or editing validation scripts, Android export scripts, build-info generation, Supabase restore checks, or other deterministic project tooling under tools/.
---

# Tools

## Tooling Principles

- Prefer deterministic scripts over one-off manual instructions.
- Keep validators narrow, readable, and tied to a user-facing risk.
- When adding a validator, wire it into `tools/validate_godot.ps1` if it protects normal project health.
- Use transaction-wrapped checks for live Supabase validation.
- Do not bake machine-specific paths into committed scripts.

## Godot Validators

- Use existing helper style from `tools/validate_sprint6_helpers.gd`.
- Validators should fail with actionable messages.
- Runtime validators should clean up instantiated scenes/nodes and reset `current_scene` when applicable.
- Prefer checking behavior directly over only checking text tokens.
- Text-token checks are acceptable for guardrails around fragile regressions.

## PowerShell Scripts

- Keep scripts Windows-friendly and explicit about parameters.
- Fail fast on unsafe Android signing/export combinations.
- Build the Android push plugin before APK export when exporting locally.
- Regenerate `systems/build_info.gd` through script flow, not ad hoc edits.

## Validation

- Run the changed script directly first.
- Then run `tools/validate_godot.ps1` when a validator, export path, or shared helper changes.
