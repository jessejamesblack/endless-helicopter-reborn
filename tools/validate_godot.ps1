param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = @(
    'res://systems/game_settings.gd',
    'res://systems/haptics_manager.gd',
    'res://systems/background_catalog.gd',
    'res://systems/helicopter_skins.gd',
    'res://systems/online_leaderboard.gd',
    'res://systems/player_profile.gd',
    'res://systems/run_stats.gd',
    'res://systems/mission_manager.gd',
    'res://systems/supabase_sync_queue.gd',
    'res://scenes/background/background_manager.gd',
    'res://scenes/game/main/encounter_catalog.gd',
    'res://scenes/game/main/spawner.gd',
    'res://scenes/ui/start_screen/start_screen.gd',
    'res://scenes/ui/settings/settings_menu.gd',
    'res://scenes/ui/pause/pause_menu.gd',
    'res://scenes/ui/leaderboard/leaderboard_screen.gd',
    'res://scenes/ui/missions/mission_screen.gd',
    'res://scenes/ui/hangar/hangar_screen.gd',
    'res://systems/push_notifications.gd',
    'res://scenes/game/main/main.gd',
    'res://scenes/player/player.gd',
    'res://scenes/player/near_miss_detector.gd',
    'res://scenes/enemies/enemy_unit.gd',
    'res://scenes/projectiles/missile.gd',
    'res://scenes/projectiles/enemy_projectile.gd',
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

Write-Host 'Validating vehicle skins and restore'
& $GodotBin --headless --path $projectRoot --script res://tools/validate_vehicle_skins_and_restore.gd
if ($LASTEXITCODE -ne 0) {
    throw 'Godot vehicle skins and restore validation failed'
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

Write-Host 'Godot validation completed successfully.'
