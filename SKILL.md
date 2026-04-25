---
name: endless-helicopter-project
description: Use when working anywhere in Endless Helicopter Reborn. Covers repo workflow, Godot validation, MCP expectations, PR hygiene, and when to read the more focused folder skills.
---

# Endless Helicopter Project

## First Reads

- Read `AGENTS.md`, `README.md`, and this file before broad repo work.
- Read `docs/ARCHITECTURE.md` before gameplay, UI, service, or backend-adjacent changes.
- Read `docs/DEVELOPMENT.md` before validation, Android export, release, or CI work.
- Read `docs/MCP_SETUP.md` before changing MCP configuration or using Supabase/Godot MCP paths.

## Folder Skills

- `scenes/SKILL.md`: gameplay scenes, UI scenes, enemies, pickups, projectiles, and presentation.
- `systems/SKILL.md`: autoloads, shared runtime systems, profile/progression, missions, and stats.
- `tools/SKILL.md`: validators, local export scripts, deterministic checks, and CI-adjacent tooling.
- `backend/SKILL.md`: Supabase SQL, Edge Functions, profile sync assumptions, and data safety.
- `android/SKILL.md`: Android plugin, signing, export continuity, and device validation.
- `.github/SKILL.md`: workflows, PR checks, APK artifacts, and release automation.

## Working Rules

- Work on a branch and land through a PR into `main`.
- Keep generated build outputs out of git unless the user explicitly asks otherwise.
- Use `rg` for search and project scripts for repeatable checks.
- Prefer existing scene/service patterns over new abstractions.
- Do not rewrite unrelated local edits.
- Use `apply_patch` for hand edits.

## MCP Expectations

- Use project MCP servers when they materially help.
- Use Godot MCP for scene/script help when local code inspection is not enough.
- Use Context7 for current Godot, Android, Firebase, or Supabase docs.
- Treat Supabase MCP as read-only unless a checked-in script/runbook explicitly requires a write-capable local override.
- Use GitHub capabilities for PR, CI, and release work when configured.

## Validation

- For normal code changes, run `tools/validate_godot.ps1` with the Godot 4.6 console binary.
- For Android export or signing work, use `tools/export_android.ps1` and `docs/ANDROID_CONTINUITY_CUTOVER.md`.
- For live Supabase restore checks, use `tools/validate_supabase_reinstall_restore.ps1`; it is intentionally transaction-wrapped.

## Release Discipline

- Bump `export_presets.cfg` only for release candidates or when the user asks for a version bump.
- Regenerate `systems/build_info.gd` through the project scripts, not by hand.
- Update release notes when preparing a candidate intended for user testing or publishing.
