# Architecture

## Runtime Map

- `scenes/game/main/`: main gameplay scene and spawner
- `scenes/background/`: runtime-generated parallax background manager
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
- `scenes/ui/hangar/`: vehicle and finish selection screen
- `systems/game_settings.gd`: persistent audio, layout, and haptics settings
- `systems/haptics_manager.gd`: centralized event-based haptic playback
- `systems/music_player.gd`: shared music playback service for menu and gameplay loops
- `systems/account_manager.gd`: Supabase Auth email OTP session state and linked-account restore
- `systems/online_leaderboard.gd`: shared leaderboard service
- `systems/run_stats.gd`: live run stats, local best score persistence, and the last completed run summary
- `systems/player_profile.gd`: local-first vehicle, finish, lore, milestone, and reminder progression
- `systems/helicopter_skins.gd`: vehicle catalog, finish metadata, and vehicle/skin application
- `systems/background_catalog.gd`: biome metadata for the parallax background system
- `systems/mission_manager.gd`: deterministic daily missions, run-to-mission progress, and post-run mission summary handoff
- `systems/supabase_sync_queue.gd`: best-effort background sync for profile, missions, and v2 score submits
- `systems/push_notifications.gd`: Android push registration and deep-link routing

## Gameplay Flow

1. The app starts in `start_screen.tscn`.
2. Players can open `Settings` from the start screen to adjust audio, controls, and haptics.
3. Pressing `Play Game` opens `main.tscn`.
4. The player survives, scores over elapsed time, bounces off the top and bottom bounds to recover from mistakes, and interacts with enemies/pickups.
5. Near misses, direct missile hits, projectile intercepts, and hit streaks feed a combo-based skill-score loop with floating feedback and a compact combo HUD.
6. During gameplay, `Pause` can resume, open settings, or quit cleanly back to the menu.
7. On crash, `main.gd` finalizes the run in `RunStats` and transitions to `leaderboard_screen.tscn`.
8. The post-run flow finalizes `RunStats`, applies mission progress once, queues best-effort Supabase sync, and transitions to the results screen.
9. The post-run screen shows score, local best, Sprint 1 and Sprint 2 stats, a compact daily mission summary, unlock summaries, and keeps `Try Again` as the primary action.
10. The player can open the mission screen from the menu or the post-run screen, inspect today's progress, and open the Hangar to equip unlocked vehicles and finishes.
11. The same results screen can still switch into leaderboard mode, submit the run if manual name setup is needed, and show shared scores.
12. If a score-beaten push notification is opened, the push service routes the app back to the leaderboard screen in leaderboard mode. If a daily-mission push is opened from the menu or app launch, it routes to the mission screen.

## Enemy Roles

- `large_spiky_rock`: baseline obstacle and most common hostile
- `alien_drone`: mid-frequency flying enemy that fires straight projectiles
- `stationary_turret`: rarer bottom-lane enemy that fires gently homing missiles
- `glowing_rock`: rarest enemy; when destroyed by the player it triggers a screen-clear blast that removes hostiles and pickups currently on screen

## Encounter Director

- `spawner.gd` now defaults to a seeded encounter director instead of a flat timer-plus-weighted-random loop.
- The director advances through time-based phases: opening, warmup, combat intro, pressure, advanced, and endurance.
- Encounters are authored chunks from `encounter_catalog.gd` that can include obstacles, drones, turrets, glowing rocks, pickups, and breathers.
- Director timing is based on real elapsed run time. Gameplay still accelerates through `Main.speed_multiplier`, but encounter durations and breather cadence are not compressed by it.
- Fairness guards cap active hostiles/projectiles, prevent early turrets, keep glowing rocks spaced out, and allow only one active turret or glowing rock at a time.
- Ammo comes from authored encounters, breather pickups, and rare rescue ammo when the player is on a drought.
- In debug builds, the main HUD can show the current director phase, encounter id, seed, and active hostile count for reproducible tuning.

## Boundaries

- Scenes own gameplay behavior and local presentation.
- `systems/` owns non-scene shared runtime services.
- `run_stats.gd` owns run-level counters, combo/skill summary data, and local best persistence instead of scene tree metadata.
- `player_profile.gd` owns local vehicle/finish progression and merges remote profile data conservatively.
- `mission_manager.gd` owns today's mission state and the compact post-run mission summary instead of scene-tree metadata.
- `supabase_sync_queue.gd` owns retryable outbound sync jobs plus the startup pull/merge of profile and today's mission progress.
- `account_manager.gd` owns account session bootstrap, email-code sign-in, and server-side account-to-profile restore state.
- `backend/` owns external service bootstrap files.
- `docs/` owns human/agent-readable project knowledge.

## Vehicles And Finishes

- `helicopter_skins.gd` remains the compatibility entry point, but Sprint 5 treats it as the vehicle catalog.
- Vehicles own silhouette, texture, collision polygon, and any per-vehicle handling/profile differences.
- Standard finishes are color-only variants applied through tint/modulate data and do not affect collision, handling, speed, ammo, scoring, or controls.
- `original_icon` is the only texture-swap finish type and is unlocked globally at the higher score milestone when an original icon asset exists for that vehicle.
- Pottercar remains a prestige vehicle gated by current leaderboard #1 status and does not participate in the normal per-vehicle finish ladder.

## Backgrounds And Presentation

- `background_manager.tscn` builds a multi-layer parallax presentation at runtime using biome metadata from `background_catalog.gd`.
- Each run starts in one polished biome and long runs can transition into later biomes without affecting gameplay, scoring, missions, or encounter selection.
- The game currently keeps the mobile renderer on Compatibility until measured device testing justifies a renderer switch.

## Settings Runtime

- `game_settings.gd` persists settings to `user://game_settings.cfg`.
- The settings service applies `Master`, `Music`, and `SFX` audio levels at runtime.
- `Master` affects the full mix.
- `Music` affects the dedicated `Music` bus used by menu and gameplay loops.
- `SFX` affects gameplay/effects audio only.
- Fire-button side is configurable as `left` or `right`.
- Score and ammo panels stay tied together and mirror to the opposite side of the fire button.
- Haptics is controlled from the same shared settings service and used as the source of truth for vibration hooks.
- Render frame-rate capping is also configured from the same settings service; gameplay scoring remains time-based rather than frame-count-based.

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
