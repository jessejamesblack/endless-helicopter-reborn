param(
    [ValidateSet('Debug', 'Release', 'Both')]
    [string]$Variant = 'Both'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pluginRoot = Join-Path $projectRoot 'android/plugins/fcm_push_bridge'
$outputRoot = Join-Path $projectRoot 'addons/fcm_push_bridge/libs'
$gradleWrapper = Join-Path $pluginRoot 'gradlew.bat'
$gradleCommand = if (Test-Path $gradleWrapper) { $gradleWrapper } else { 'gradle' }

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

Push-Location $pluginRoot
try {
    if ($gradleCommand -eq 'gradle' -and -not (Get-Command gradle -ErrorAction SilentlyContinue)) {
        throw "Gradle was not found. Install Gradle or add a Gradle wrapper under android/plugins/fcm_push_bridge."
    }

    switch ($Variant) {
        'Debug' {
            & $gradleCommand assembleDebug
        }
        'Release' {
            & $gradleCommand assembleRelease
        }
        'Both' {
            & $gradleCommand assembleDebug assembleRelease
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Android push bridge build failed."
    }
}
finally {
    Pop-Location
}

$debugAarSource = Join-Path $pluginRoot 'build/outputs/aar/fcm-push-bridge-debug.aar'
$releaseAarSource = Join-Path $pluginRoot 'build/outputs/aar/fcm-push-bridge-release.aar'

if (Test-Path $debugAarSource) {
    Copy-Item $debugAarSource (Join-Path $outputRoot 'FcmPushBridge-debug.aar') -Force
}

if (Test-Path $releaseAarSource) {
    Copy-Item $releaseAarSource (Join-Path $outputRoot 'FcmPushBridge-release.aar') -Force
}

Write-Host 'Android push bridge artifacts copied into addons/fcm_push_bridge/libs.'
