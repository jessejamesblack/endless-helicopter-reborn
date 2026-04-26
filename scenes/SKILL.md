---
name: endless-helicopter-scenes
description: Use when editing Godot scenes or scripts under scenes/, including main gameplay, spawner, enemies, player, pickups, projectiles, UI, background, and visual feedback.
---

# Scenes

## Read First

- `docs/ARCHITECTURE.md` for scene ownership and gameplay flow.
- `scenes/game/main/main.gd`, `spawner.gd`, and `encounter_catalog.gd` before changing run flow or spawning.
- The matching `.tscn` before changing a script that relies on node paths.

## Godot Patterns

- Keep scene/script pairs close together.
- Preserve node names used by `$Path` and `@onready` references.
- Update `.tscn` `ext_resource` paths when moving resources.
- Prefer programmatic UI additions only when the scene already uses that pattern or the UI is runtime-only.
- Match existing UI colors, borders, font sizes, panel radii, and HUD placement before inventing a new look.

## Gameplay Changes

- Run depth systems should flow through managers in `systems/` and shared modifier queries, not UI-specific hard-coding.
- Gameplay pickups/effects that map to visible daily missions should notify `MissionManager` live through the shared systems path instead of waiting only for the post-run summary.
- Spawner y positions must be viewport/playfield responsive. Avoid fixed lane literals such as `160`, `300`, or `440`.
- Keep early-game encounters readable. Add pressure through timing, roles, and composition before raw HP inflation.
- Fairness fixes should update run stats when they introduce a new death/crash reason.

## Validation

- Parse changed scene scripts with Godot `--check-only --script`.
- Run focused validators when touching these areas:
  - `tools/validate_enemy_threat_pass.gd`
  - `tools/validate_spawn_layout_responsiveness.gd`
  - `tools/validate_feedback_sprint.gd`
  - `tools/validate_score_feedback_and_combo.gd`
  - `tools/validate_pause_menu_missions.gd`
- Run `tools/validate_godot.ps1` before committing gameplay or UI behavior changes.
