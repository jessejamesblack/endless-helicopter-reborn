param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = @(
    'res://systems/game_settings.gd',
    'res://systems/online_leaderboard.gd',
    'res://systems/run_stats.gd',
    'res://scenes/ui/start_screen/start_screen.gd',
    'res://scenes/ui/settings/settings_menu.gd',
    'res://scenes/ui/pause/pause_menu.gd',
    'res://scenes/ui/leaderboard/leaderboard_screen.gd',
    'res://systems/push_notifications.gd',
    'res://scenes/game/main/main.gd',
    'res://scenes/player/player.gd',
    'res://scenes/player/near_miss_detector.gd',
    'res://scenes/enemies/enemy_unit.gd',
    'res://scenes/projectiles/missile.gd',
    'res://scenes/projectiles/enemy_projectile.gd',
    'res://scenes/effects/floating_score_text.gd'
)

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

Write-Host 'Godot validation completed successfully.'
