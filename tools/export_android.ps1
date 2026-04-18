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
$buildPluginScript = Join-Path $PSScriptRoot 'build_android_plugin.ps1'

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$exportFlag = if ($Release.IsPresent) { '--export-release' } else { '--export-debug' }

if (Test-Path $buildPluginScript) {
    Write-Host 'Building Android push bridge plugin before export...'
    & $buildPluginScript -Variant Both
    if ($LASTEXITCODE -ne 0) {
        throw 'Android push bridge build failed.'
    }
}

Write-Host "Exporting Android preset '$Preset' to '$outputPath'"
& $GodotBin --headless --path $projectRoot $exportFlag $Preset $outputPath --install-android-build-template

if ($LASTEXITCODE -ne 0) {
    throw 'Android export failed.'
}

Write-Host 'Android export completed successfully.'
