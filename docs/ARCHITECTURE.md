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
- `scenes/ui/leaderboard/`: post-run results and leaderboard UI
- `scenes/ui/missions/`: daily mission screen
- `scenes/ui/hangar/`: cosmetic helicopter equip screen
- `systems/game_settings.gd`: persistent audio, layout, and haptics settings
- `systems/music_player.gd`: shared music playback service for menu and gameplay loops
- `systems/online_leaderboard.gd`: shared leaderboard service
- `systems/run_stats.gd`: live run stats, local best score persistence, and the last completed run summary
- `systems/player_profile.gd`: local-first cosmetic progression and reminder preference
- `systems/helicopter_skins.gd`: helicopter cosmetic metadata and sprite application
- `systems/mission_manager.gd`: deterministic daily missions, run-to-mission progress, and post-run mission summary handoff
- `systems/supabase_sync_queue.gd`: best-effort background sync for profile, missions, and v2 score submits
- `systems/push_notifications.gd`: Android push registration and deep-link routing

## Gameplay Flow

1. The app starts in `start_screen.tscn`.
2. Players can open `Settings` from the start screen to adjust audio, controls, and haptics.
3. Pressing `Play Game` opens `main.tscn`.
4. The player survives, scores over time, bounces off the top and bottom bounds to recover from mistakes, and interacts with enemies/pickups.
5. Near misses, direct missile hits, projectile intercepts, and hit streaks feed a combo-based skill-score loop with floating feedback and a compact combo HUD.
6. During gameplay, `Pause` can resume, open settings, or quit cleanly back to the menu.
7. On crash, `main.gd` finalizes the run in `RunStats` and transitions to `leaderboard_screen.tscn`.
8. The post-run flow finalizes `RunStats`, applies mission progress once, queues best-effort Supabase sync, and transitions to the results screen.
9. The post-run screen shows score, local best, Sprint 1 and Sprint 2 stats, a compact daily mission summary, and keeps `Try Again` as the primary action.
10. The player can open the mission screen from the menu or the post-run screen, inspect today's progress, toggle reminder preference, and open the hangar to equip unlocked helicopters.
11. The same results screen can still switch into leaderboard mode, submit the run if manual name setup is needed, and show shared scores.
12. If a score-beaten push notification is opened, the push service routes the app back to the leaderboard screen in leaderboard mode. If a daily-mission push is opened from the menu or app launch, it routes to the mission screen.

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
- `run_stats.gd` owns run-level counters, combo/skill summary data, and local best persistence instead of scene tree metadata.
- `player_profile.gd` owns local cosmetic progression and merges remote profile data conservatively.
- `mission_manager.gd` owns today's mission state and the compact post-run mission summary instead of scene-tree metadata.
- `supabase_sync_queue.gd` owns retryable outbound sync jobs plus the startup pull/merge of profile and today's mission progress.
- `backend/` owns external service bootstrap files.
- `docs/` owns human/agent-readable project knowledge.

## Settings Runtime

- `game_settings.gd` persists settings to `user://game_settings.cfg`.
- The settings service applies `Master`, `Music`, and `SFX` audio levels at runtime.
- `Master` affects the full mix.
- `Music` affects the dedicated `Music` bus used by menu and gameplay loops.
- `SFX` affects gameplay/effects audio only.
- Fire-button side is configurable as `left` or `right`.
- Score and ammo panels stay tied together and mirror to the opposite side of the fire button.
- Haptics is controlled from the same shared settings service and used as the source of truth for vibration hooks.

## Music Flow

- `start_screen.gd` and `leaderboard_screen.gd` ask `MusicPlayer` for the calmer menu loop.
- `main.gd` switches to a faster gameplay loop when a run starts.
- `music_player.gd` owns the track swap and keeps playback alive across scene changes.

## Important External Integration

- Supabase powers the shared leaderboard.
- Supabase also stores synced player profiles, daily mission progress, best-run expanded stats, and append-only run history.
- Supabase Edge Functions and Firebase Cloud Messaging power Android push notifications.
- GitHub Actions builds Android APK artifacts.

## Architectural Preferences

- Keep each scene with its script when practical.
- Prefer feature folders over a flat root.
- Keep asset organization separate from gameplay organization.
- Keep docs and backend setup out of runtime scene folders.
