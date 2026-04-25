---
name: endless-helicopter-systems
description: Use when editing shared runtime systems under systems/, including autoloads, profiles, missions, stats, upgrades, powerups, objectives, settings, leaderboard, sync, and notifications.
---

# Systems

## Boundaries

- `systems/` owns shared runtime services and non-scene state.
- Scenes may query systems, but systems should not depend on fragile scene node paths.
- Keep local-first behavior: profile, missions, and stats should work without network access.
- Prefer additive profile summary fields over schema changes unless a backend migration is explicitly required.

## Autoloads And Data

- Add or rename autoloads in `project.godot` deliberately.
- Run-start systems should expose a clear `start_run()` or equivalent reset path.
- Summary dictionaries should be backward compatible with missing old fields and unknown future fields.
- Mission generation must keep the current 3 core plus 2 bonus structure unless a product change says otherwise.
- Mission progress that is visible from the pause menu should update live when the event happens. Use `MissionManager.record_live_mission_progress()` for immediate pickup/effect counters and keep the final `apply_run_summary()` path from double-counting live-applied progress.
- Guard live mission mutation from reentrant disk reloads. Profile or UI refresh callbacks must not call through to stale saved mission state while live mission progress is being applied.

## Supabase And Sync

- Keep Supabase sync best-effort and retryable.
- Keep queued daily mission sync monotonic. When replacing a pending mission sync job for the same date, merge per-mission progress upward instead of using last-write-wins.
- Do not expose raw Android identity values; keep app-owned hashed identifiers.
- Use existing profile JSON summary shapes when possible.
- No live data writes from systems work unless covered by a runbook or deterministic script.

## Validation

- Parse changed system scripts with Godot `--check-only --script`.
- Run focused validators for touched systems:
  - `tools/validate_depth_retention.gd`
  - `tools/validate_daily_mission_expansion.gd`
  - `tools/validate_vehicle_skins_and_restore.gd`
  - `tools/validate_restore_resume_flow.gd`
  - `tools/validate_sprint7_security.gd`
- Run the full `tools/validate_godot.ps1` after profile, mission, stats, sync, or autoload changes.
