param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin,

    [string]$Preset = 'Android',

    [string]$Output = 'build/android/EndlessHelicopter-debug.apk',

    [switch]$Release
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputPath = Join-Path $projectRoot $Output
$outputDir = Split-Path -Parent $outputPath

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$exportFlag = if ($Release.IsPresent) { '--export-release' } else { '--export-debug' }

Write-Host "Exporting Android preset '$Preset' to '$outputPath'"
& $GodotBin --headless --path $projectRoot $exportFlag $Preset $outputPath

if ($LASTEXITCODE -ne 0) {
    throw 'Android export failed.'
}

Write-Host 'Android export completed successfully.'
