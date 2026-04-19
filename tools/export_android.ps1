param(
    [Parameter(Mandatory = $true)]
    [string]$GodotBin,

    [string]$Preset = 'Android',

    [string]$Output = 'build/android/EndlessHelicopter-debug.apk',

    [switch]$Release,

    [string]$BuildSha = 'dev',

    [string]$BuildDate = '',

    [string]$ReleaseChannel = 'dev'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputPath = Join-Path $projectRoot $Output
$outputDir = Split-Path -Parent $outputPath
$buildPluginScript = Join-Path $PSScriptRoot 'build_android_plugin.ps1'
$generateBuildInfoScript = Join-Path $PSScriptRoot 'generate_build_info.ps1'
$canonicalBuildDir = Join-Path $projectRoot 'build\android'

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$exportFlag = if ($Release.IsPresent) { '--export-release' } else { '--export-debug' }

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedProjectRoot = (Resolve-Path $projectRoot).Path
    $resolvedPath = (Resolve-Path $Path).Path
    return [IO.Path]::GetRelativePath($resolvedProjectRoot, $resolvedPath)
}

function Get-StaleApkCandidates {
    if (-not (Test-Path $projectRoot)) {
        return @()
    }

    $searchRoot = Resolve-Path $projectRoot
    $canonicalBuildRoot = if (Test-Path $canonicalBuildDir) {
        (Resolve-Path $canonicalBuildDir).Path
    } else {
        $canonicalBuildDir
    }

    return Get-ChildItem -Path $searchRoot -Filter *.apk -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -ne $outputPath -and
            -not $_.FullName.StartsWith($canonicalBuildRoot, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        Sort-Object LastWriteTime -Descending
}

if (Test-Path $buildPluginScript) {
    Write-Host 'Building Android push bridge plugin before export...'
    & $buildPluginScript -Variant Both
    if ($LASTEXITCODE -ne 0) {
        throw 'Android push bridge build failed.'
    }
}

if (Test-Path $generateBuildInfoScript) {
    $resolvedBuildDate = if ([string]::IsNullOrWhiteSpace($BuildDate)) { [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $BuildDate }
    Write-Host "Generating build info for channel '$ReleaseChannel'..."
    & $generateBuildInfoScript -BuildSha $BuildSha -BuildDate $resolvedBuildDate -ReleaseChannel $ReleaseChannel
    if ($LASTEXITCODE -ne 0) {
        throw 'Build info generation failed.'
    }
}

Write-Host "Exporting Android preset '$Preset' to '$outputPath'"
& $GodotBin --headless --path $projectRoot $exportFlag $Preset $outputPath --install-android-build-template

if ($LASTEXITCODE -ne 0) {
    throw 'Android export failed.'
}

Write-Host 'Android export completed successfully.'
Write-Host "Install this fresh APK: $outputPath"

$staleApkCandidates = Get-StaleApkCandidates
if ($staleApkCandidates.Count -gt 0) {
    Write-Warning 'Other APK files exist outside build/android. Installing one of those can reuse a stale Android push bridge.'
    foreach ($candidate in $staleApkCandidates) {
        $relativePath = $candidate.FullName
        try {
            $relativePath = Get-ProjectRelativePath -Path $candidate.FullName
        }
        catch {
            # Keep the export successful even if relative-path display fails.
        }
        Write-Host (" - {0} ({1})" -f $relativePath, $candidate.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
}
