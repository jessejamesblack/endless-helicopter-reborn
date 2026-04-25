---
name: endless-helicopter-github
description: Use when editing GitHub workflows, PR automation, APK artifact behavior, release publishing, or CI validation under .github/.
---

# GitHub

## Workflow Rules

- Pull requests to `main` should validate the project and upload an APK artifact.
- Pushes to `main` may publish releases only through the intended release workflow.
- Manual workflow runs should publish only when targeting `main`; branch runs stay artifact-only.
- Keep Android plugin build, Godot validation, and APK export order intact.

## Release Requirements

- Release candidates need a version bump in `export_presets.cfg`.
- Release notes should match the candidate.
- `main` public releases must use the canonical stable release key.
- CI should fail rather than producing identity-unsafe APKs when required signing secrets are missing.

## PR And CI Work

- Use GitHub tools or `gh` to inspect checks, logs, and PR state when configured.
- Keep workflow changes narrow and explain operational impact in the commit or PR body.
- Do not add secrets or machine-local paths to workflows.

## Validation

- Run `tools/validate_godot.ps1` for workflow changes that alter validation/export expectations.
- For Android workflow changes, cross-check `docs/DEVELOPMENT.md` and `docs/ANDROID_CONTINUITY_CUTOVER.md`.
