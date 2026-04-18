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
$canonicalBuildDir = Join-Path $projectRoot 'build\android'

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$exportFlag = if ($Release.IsPresent) { '--export-release' } else { '--export-debug' }

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $projectUri = [Uri]((Resolve-Path $projectRoot).Path + [IO.Path]::DirectorySeparatorChar)
    $fileUri = [Uri](Resolve-Path $Path).Path
    return [Uri]::UnescapeDataString($projectUri.MakeRelativeUri($fileUri).ToString()).Replace('/', '\')
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
        $relativePath = Get-ProjectRelativePath -Path $candidate.FullName
        Write-Host (" - {0} ({1})" -f $relativePath, $candidate.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
}
