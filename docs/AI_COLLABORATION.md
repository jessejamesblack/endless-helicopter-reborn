# AI Collaboration

This project borrows practical ideas from OpenAI's harness-engineering approach and adapts them to a small Godot game.

## Principles Applied Here

### 1. Humans steer, agents execute

- Humans decide goals, priorities, and acceptance criteria.
- Agents implement, validate, and document changes.

### 2. Repository knowledge is the system of record

- Important context should live in the repo, not only in chat.
- `AGENTS.md` is the map.
- Root and folder-level `SKILL.md` files hold recurring agent workflows and local implementation taste.
- `docs/` holds the deeper sources of truth.

### 3. Agent legibility matters

- The repo is organized by feature so agents can navigate it quickly.
- Shared systems and setup files are separated from scene logic.
- Validation commands live in `tools/`.
- README media is generated from current Godot scenes through `tools/capture_readme_media.gd`, so public screenshots can stay tied to the actual app.

### 4. Encode repeatable behavior

- Repeated checks become scripts.
- Repeated build steps become CI.
- Repeated structural guidance becomes docs.

### 5. Keep feedback loops tight

- Validate changed scripts with Godot.
- Build Android artifacts in CI on push.
- Update docs when the system shape changes.
- Keep release hygiene checks green when changing versioned docs, public media, or user-facing release notes.

## Expectations For Future AI Work

- Read `AGENTS.md` first.
- Read the root `SKILL.md`, then the narrow folder `SKILL.md` for the files being changed.
- Prefer the smallest relevant doc instead of stuffing everything into one file.
- Keep structural changes deliberate and documented.
- If a new recurring rule appears, promote it into docs or tooling.
- When touching public-facing docs or README media, run the public-polish and release-hygiene validators in addition to any code-focused checks.
- When working on Android identity, reinstall, restore, push-device ownership, or leaderboard migration:
  - assume same-device continuity depends on a stable signing key track, not just code changes
  - treat reinstall/restore tests as invalid unless the build is exported with `SigningMode` `release_stable` or `debug_stable`
  - use `tools/export_android.ps1` for local installable APKs and let it regenerate `systems/build_info.gd`
  - do not trust stale checked-in `systems/build_info.gd` values as proof of what an installed APK contains
  - check the in-app Debug diagnostics for signing mode and signing-certificate preview before concluding that Android-backed identity changed because of application logic
- If a workflow or script can silently produce identity-unsafe Android artifacts, prefer failing loudly over generating a misleading APK.
- For Android continuity cutovers and wipe events, use [docs/ANDROID_CONTINUITY_CUTOVER.md](ANDROID_CONTINUITY_CUTOVER.md) as the runbook.
- Do not propose identity fixes without checking signing-track assumptions first.
- Do not recommend a DB wipe without naming the preserved tables and the version-gate plan.
- Do not treat pre-cutover restore failures as evidence that the current stable-signing design is broken.
- Prefer release-gated cutovers over partial rollouts when continuity rules change.
