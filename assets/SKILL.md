---
name: endless-helicopter-assets
description: Use when editing assets/, including art, audio, icons, generated sprites, import-sensitive resources, or asset references used by Godot scenes.
---

# Assets

## Asset Rules

- Keep art, audio, and icons organized by existing asset folders.
- Avoid replacing established visual style unless the task explicitly asks for an art direction change.
- Do not commit throwaway exports, temporary renders, or large generated variants.
- Preserve source file paths referenced by `.tscn`, `.tres`, `.import`, and script `preload()` calls.

## Godot Imports

- When moving or replacing assets, check `.import` side effects and resource references.
- Prefer updating scenes/scripts to point at stable resource paths instead of duplicating assets.
- Keep icon and notification assets compatible with Android expectations.

## Audio

- Keep gameplay SFX on the `SFX` bus and music on the `Music` bus.
- Preserve loop/export assumptions for menu and gameplay tracks.
- Regenerate retro SFX through checked-in tooling when available instead of hand-editing binary output.

## Validation

- Run `tools/validate_art_quality.gd`, `tools/validate_background_quality.gd`, or push/icon validators when touching relevant assets.
- Run `tools/validate_godot.ps1` if asset path changes affect scenes or scripts.
