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
- [docs/AI_COLLABORATION.md](docs/AI_COLLABORATION.md): how this repo applies harness-engineering ideas.
- [docs/ONLINE_LEADERBOARD_SETUP.md](docs/ONLINE_LEADERBOARD_SETUP.md): Supabase leaderboard setup.

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

## Validation

- Use [tools/validate_godot.ps1](tools/validate_godot.ps1) for script-level validation.
- CI builds an Android APK artifact on every push via `.github/workflows/android-apk.yml`.

## When Making Larger Changes

- Update the relevant docs in `docs/`.
- Keep changes scoped by feature.
- If work spans multiple decisions, leave a short note in the PR/commit message explaining the new structure.
