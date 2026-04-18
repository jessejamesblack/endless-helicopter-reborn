param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = @(
    'res://systems/game_settings.gd',
    'res://systems/online_leaderboard.gd',
    'res://scenes/ui/start_screen/start_screen.gd',
    'res://scenes/ui/settings/settings_menu.gd',
    'res://scenes/ui/pause/pause_menu.gd',
    'res://scenes/ui/leaderboard/leaderboard_screen.gd',
    'res://systems/push_notifications.gd',
    'res://scenes/game/main/main.gd',
    'res://scenes/player/player.gd',
    'res://scenes/enemies/enemy_unit.gd',
    'res://scenes/projectiles/enemy_projectile.gd'
)

foreach ($script in $scripts) {
    Write-Host "Validating $script"
    & $GodotBin --headless --path $projectRoot --check-only --script $script
    if ($LASTEXITCODE -ne 0) {
        throw "Godot validation failed for $script"
    }
}

Write-Host 'Godot validation completed successfully.'
