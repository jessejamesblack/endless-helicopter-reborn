# AGENTS.md

This repository is set up for AI-assisted development. Keep this file short and use it as a map, not an encyclopedia.

## Working Model

- Humans steer. Agents execute.
- Repository-local docs are the system of record.
- Prefer deterministic scripts and repeatable checks over one-off instructions.
- When behavior, structure, or taste matters repeatedly, encode it into docs or tooling.

## Start Here

- [README.md](README.md): project overview, Android install flow, CI build flow.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): scene layout, gameplay flow, service boundaries.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): day-to-day commands and validation workflow.
- [docs/ROADMAP.md](docs/ROADMAP.md): public milestone direction and near-term priorities.
- [docs/MCP_SETUP.md](docs/MCP_SETUP.md): project MCP servers for Codex and VS Code.
- [docs/AI_COLLABORATION.md](docs/AI_COLLABORATION.md): how this repo applies harness-engineering ideas.
- [docs/ANDROID_CONTINUITY_CUTOVER.md](docs/ANDROID_CONTINUITY_CUTOVER.md): canonical Android signing cutover and fresh-start restore runbook.
- [docs/ONLINE_LEADERBOARD_SETUP.md](docs/ONLINE_LEADERBOARD_SETUP.md): Supabase leaderboard setup.
- [docs/PUSH_NOTIFICATIONS_SETUP.md](docs/PUSH_NOTIFICATIONS_SETUP.md): Firebase + Supabase push setup.

## Repository Layout

- `scenes/`: game and UI scenes grouped by feature.
- `systems/`: shared services and non-scene runtime systems.
- `assets/`: art, audio, and icons grouped by asset type.
- `backend/`: SQL and backend-adjacent setup files.
- `docs/`: human and agent-facing project knowledge.
- `tools/`: deterministic local scripts for validation/export.
- `.github/workflows/`: CI automation.

## Practical Rules

- Keep scene/script pairs close together.
- Prefer editing docs when repeated guidance is needed.
- Update path references when moving Godot resources.
- Keep build outputs out of git.
- Use the scripts in `tools/` before inventing new ad-hoc commands.
- Do work on branches and land changes through pull requests into `main`.
- Bump the Android app version in `export_presets.cfg` for every release candidate before building or publishing.
- When a PR includes user-facing gameplay, Android, backend, release, or documentation changes, include a version bump and matching release-note updates unless the human explicitly says not to.
- Treat Android reinstall/restore testing as invalid unless the APK is continuity-safe:
  - use the canonical local export path in `tools/export_android.ps1` or CI
  - use `SigningMode` `release_stable` or `debug_stable`
  - never rely on temporary or unspecified signing for same-device identity validation
- Future PRs that touch restore, reinstall, identity, release workflow, or Supabase reset logic must consult `docs/ANDROID_CONTINUITY_CUTOVER.md` first.
- Regenerate `systems/build_info.gd` through `tools/generate_build_info.ps1` or `tools/export_android.ps1`; do not assume the checked-in file matches the last APK someone installed.

## Validation

- Use [tools/validate_godot.ps1](tools/validate_godot.ps1) for script-level validation.
- Build the Android push plugin with [tools/build_android_plugin.ps1](tools/build_android_plugin.ps1) before local Android exports.
- CI validates pull requests into `main`.
- Only `main` builds publish Android releases.
- Successful `main` releases publish a versioned GitHub release plus refresh the rolling `android-latest` GitHub prerelease alias.
- For Android continuity work, confirm the in-app Debug diagnostics show a stable signing mode and signing-certificate preview before trusting reinstall/restore results.

## When Making Larger Changes

- Update the relevant docs in `docs/`.
- Keep changes scoped by feature.
- If work spans multiple decisions, leave a short note in the PR/commit message explaining the new structure.
