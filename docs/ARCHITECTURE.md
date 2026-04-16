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
- `scenes/ui/settings/`: reusable settings dialog
- `scenes/ui/pause/`: in-game pause menu
- `scenes/ui/leaderboard/`: death screen and leaderboard UI
- `systems/game_settings.gd`: persistent audio, layout, and haptics settings
- `systems/online_leaderboard.gd`: shared leaderboard service
- `systems/push_notifications.gd`: Android push registration and deep-link routing

## Gameplay Flow

1. The app starts in `start_screen.tscn`.
2. Players can open `Settings` from the start screen to adjust audio, controls, and haptics.
3. Pressing `Play Game` opens `main.tscn`.
4. The player survives, scores over time, bounces off the top and bottom bounds to recover from mistakes, and interacts with enemies/pickups.
5. During gameplay, `Pause` can resume, open settings, or quit cleanly back to the menu.
6. On crash, `main.gd` stores the run score in tree metadata.
7. The app transitions to `leaderboard_screen.tscn`.
8. The leaderboard screen submits the run if configured and shows shared scores.
9. If a score-beaten push notification is opened, the push service routes the app back to the leaderboard screen.

## Enemy Roles

- `large_spiky_rock`: baseline obstacle and most common hostile
- `alien_drone`: mid-frequency flying enemy that fires straight projectiles
- `stationary_turret`: rarer bottom-lane enemy that fires gently homing missiles
- `glowing_rock`: rarest enemy; when destroyed by the player it triggers a screen-clear blast that removes hostiles and pickups currently on screen

## Spawn Tuning

- Spawn rarity order is: normal rock, alien drone, missile turret, glowing rock.
- Turrets spawn on a dedicated bottom lane instead of using the general random Y range.
- Alien drones continue to use randomized vertical placement.

## Boundaries

- Scenes own gameplay behavior and local presentation.
- `systems/` owns non-scene shared runtime services.
- `backend/` owns external service bootstrap files.
- `docs/` owns human/agent-readable project knowledge.

## Settings Runtime

- `game_settings.gd` persists settings to `user://game_settings.cfg`.
- The settings service applies `Master` and `SFX` audio levels at runtime through the `SFX` bus.
- Fire-button side is configurable as `left` or `right`.
- Score and ammo panels stay tied together and mirror to the opposite side of the fire button.
- Haptics is controlled from the same shared settings service and used as the source of truth for vibration hooks.

## Important External Integration

- Supabase powers the shared leaderboard.
- Supabase Edge Functions and Firebase Cloud Messaging power Android push notifications.
- GitHub Actions builds Android APK artifacts.

## Architectural Preferences

- Keep each scene with its script when practical.
- Prefer feature folders over a flat root.
- Keep asset organization separate from gameplay organization.
- Keep docs and backend setup out of runtime scene folders.
