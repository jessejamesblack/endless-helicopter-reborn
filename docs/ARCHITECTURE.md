# Architecture

## Runtime Map

- `scenes/game/main/`: main gameplay scene and spawner
- `scenes/game/background/`: scrolling/parallax background
- `scenes/player/`: helicopter player scene and logic
- `scenes/enemies/`: obstacles and enemy units
- `scenes/projectiles/`: player and enemy projectiles
- `scenes/pickups/`: ammo pickup scene
- `scenes/effects/`: explosion effect
- `scenes/ui/start_screen/`: start menu
- `scenes/ui/leaderboard/`: death screen and leaderboard UI
- `systems/online_leaderboard.gd`: shared leaderboard service

## Gameplay Flow

1. The app starts in `start_screen.tscn`.
2. Pressing `Play Game` opens `main.tscn`.
3. The player survives, scores over time, and interacts with enemies/pickups.
4. On crash, `main.gd` stores the run score in tree metadata.
5. The app transitions to `leaderboard_screen.tscn`.
6. The leaderboard screen submits the run if configured and shows shared scores.

## Boundaries

- Scenes own gameplay behavior and local presentation.
- `systems/` owns non-scene shared runtime services.
- `backend/` owns external service bootstrap files.
- `docs/` owns human/agent-readable project knowledge.

## Important External Integration

- Supabase powers the shared leaderboard.
- GitHub Actions builds Android APK artifacts.

## Architectural Preferences

- Keep each scene with its script when practical.
- Prefer feature folders over a flat root.
- Keep asset organization separate from gameplay organization.
- Keep docs and backend setup out of runtime scene folders.
