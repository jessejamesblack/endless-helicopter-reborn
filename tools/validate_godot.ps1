param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host 'Validating release version hygiene'
& (Join-Path $PSScriptRoot 'validate_release_hygiene.ps1')

$scripts = @(
    'res://systems/game_settings.gd',
    'res://systems/haptics_manager.gd',
    'res://systems/background_catalog.gd',
    'res://systems/helicopter_skins.gd',
    'res://systems/online_leaderboard.gd',
    'res://systems/player_profile.gd',
    'res://systems/run_stats.gd',
    'res://systems/mission_manager.gd',
    'res://systems/run_upgrade_manager.gd',
    'res://systems/powerup_manager.gd',
    'res://systems/run_objective_manager.gd',
    'res://systems/supabase_sync_queue.gd',
    'res://systems/build_info.gd',
    'res://systems/eastern_time.gd',
    'res://systems/app_update_manager.gd',
    'res://systems/error_reporter.gd',
    'res://systems/achievement_screenshot_manager.gd',
    'res://systems/android_identity.gd',
    'res://systems/feature_discovery_manager.gd',
    'res://systems/hangar_navigation_state.gd',
    'res://scenes/background/background_manager.gd',
    'res://scenes/game/main/encounter_catalog.gd',
    'res://scenes/game/main/spawner.gd',
    'res://scenes/ui/upgrades/run_upgrade_choice.gd',
    'res://scenes/ui/title_screen/title_screen.gd',
    'res://scenes/ui/start_screen/start_screen.gd',
    'res://scenes/ui/debug/debug_menu.gd',
    'res://scenes/ui/settings/settings_menu.gd',
    'res://scenes/ui/update/update_prompt.gd',
    'res://scenes/ui/feedback/feedback_screen.gd',
    'res://scenes/ui/share/achievement_share_card.gd',
    'res://scenes/ui/pause/pause_menu.gd',
    'res://scenes/ui/leaderboard/leaderboard_screen.gd',
    'res://scenes/ui/missions/mission_screen.gd',
    'res://scenes/ui/hangar/hangar_screen.gd',
    'res://systems/push_notifications.gd',
    'res://scenes/game/main/main.gd',
    'res://scenes/player/player.gd',
    'res://scenes/player/near_miss_detector.gd',
    'res://scenes/enemies/enemy_unit.gd',
    'res://scenes/enemies/obstacle.gd',
    'res://scenes/projectiles/missile.gd',
    'res://scenes/projectiles/enemy_projectile.gd',
    'res://scenes/pickups/missile_pickup.gd',
    'res://scenes/pickups/powerup_pickup.gd',
    'res://scenes/pickups/objective_pickup.gd',
    'res://scenes/effects/floating_score_text.gd'
)

Write-Host 'Importing project resources'
& $GodotBin --headless --path $projectRoot --import
if ($LASTEXITCODE -ne 0) {
    throw 'Godot resource import failed'
}

foreach ($script in $scripts) {
    Write-Host "Validating $script"
    & $GodotBin --headless --path $projectRoot --check-only --script $script
    if ($LASTEXITCODE -ne 0) {
        throw "Godot validation failed for $script"
    }
}

Write-Host 'Validating leaderboard layout'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_leaderboard_layout.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot leaderboard layout validation failed'
}

Write-Host 'Validating Sprint 2 runtime'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_sprint2_runtime.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot Sprint 2 runtime validation failed'
}

Write-Host 'Validating missions and cosmetics'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_missions_and_cosmetics.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot missions and cosmetics validation failed'
}

Write-Host 'Validating encounter director'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_encounter_director.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot encounter director validation failed'
}

Write-Host 'Validating depth retention'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_depth_retention.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot depth retention validation failed'
}

Write-Host 'Validating feedback sprint'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_feedback_sprint.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot feedback sprint validation failed'
}

Write-Host 'Validating enemy threat pass'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_enemy_threat_pass.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot enemy threat pass validation failed'
}

Write-Host 'Validating spawn layout responsiveness'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_spawn_layout_responsiveness.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot spawn layout responsiveness validation failed'
}

Write-Host 'Validating vehicle skins and restore'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_vehicle_skins_and_restore.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot vehicle skins and restore validation failed'
}

Write-Host 'Validating restore resume flow'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_restore_resume_flow.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot restore resume validation failed'
}

Write-Host 'Validating vehicle lore'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_vehicle_lore.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot vehicle lore validation failed'
}

Write-Host 'Validating art quality'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_art_quality.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot art quality validation failed'
}

Write-Host 'Validating background quality'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_background_quality.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot background quality validation failed'
}

Write-Host 'Validating frame-rate independence'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_frame_rate_independence.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot frame-rate independence validation failed'
}

Write-Host 'Validating haptics'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_haptics.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot haptics validation failed'
}

Write-Host 'Validating push notification icons'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_push_notification_icons.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot push notification icon validation failed'
}

Write-Host 'Validating Discord integration'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_discord_integration.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot Discord integration validation failed'
}

Write-Host 'Validating release notes'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_release_notes.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot release notes validation failed'
}

Write-Host 'Validating app update manager'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_app_update_manager.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot app update manager validation failed'
}

Write-Host 'Validating app update push'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_app_update_push.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot app update push validation failed'
}

Write-Host 'Validating error logging'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_error_logging.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot error logging validation failed'
}

Write-Host 'Validating achievement screenshots'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_achievement_screenshots.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot achievement screenshot validation failed'
}

Write-Host 'Validating version adoption'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_version_adoption.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot version adoption validation failed'
}

Write-Host 'Validating feedback reporting'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_feedback_reporting.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot feedback reporting validation failed'
}

Write-Host 'Validating release-ops secret leaks'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_release_ops_secret_leaks.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot release-ops secret leak validation failed'
}

Write-Host 'Validating daily reset timing'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_daily_reset_time.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot daily reset validation failed'
}

Write-Host 'Validating parallax motion'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_parallax_motion.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot parallax motion validation failed'
}

Write-Host 'Validating level music'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_level_music.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot level music validation failed'
}

Write-Host 'Validating difficulty tuning'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_difficulty_tuning.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot difficulty tuning validation failed'
}

Write-Host 'Validating Sprint 7 security'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_sprint7_security.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot Sprint 7 security validation failed'
}

Write-Host 'Validating daily mission expansion'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_daily_mission_expansion.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot daily mission expansion validation failed'
}

Write-Host 'Validating pause menu missions'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_pause_menu_missions.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot pause menu missions validation failed'
}

Write-Host 'Validating UI naming consistency'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_ui_naming_consistency.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot UI naming consistency validation failed'
}

Write-Host 'Validating score feedback and combo'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_score_feedback_and_combo.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot score feedback and combo validation failed'
}

Write-Host 'Validating hangar UI polish'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_hangar_ui_polish.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot hangar UI polish validation failed'
}

Write-Host 'Validating score display formatting'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_score_display_formatting.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot score display formatting validation failed'
}

Write-Host 'Validating feature discovery'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_feature_discovery.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot feature discovery validation failed'
}

Write-Host 'Godot validation completed successfully.'
