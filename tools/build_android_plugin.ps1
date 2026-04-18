param(
    [ValidateSet('Debug', 'Release', 'Both')]
    [string]$Variant = 'Both'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pluginRoot = Join-Path $projectRoot 'android/plugins/fcm_push_bridge'
$outputRoot = Join-Path $projectRoot 'addons/fcm_push_bridge/libs'
$gradleWrapper = Join-Path $pluginRoot 'gradlew.bat'
$gradleCommand = if (Test-Path $gradleWrapper) { $gradleWrapper } else { $null }

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

function Find-GradleCommand {
    if (Get-Command gradle -ErrorAction SilentlyContinue) {
        return 'gradle'
    }

    $searchRoots = @(
        (Join-Path $env:USERPROFILE '.gradle\wrapper\dists'),
        (Join-Path $env:LOCALAPPDATA 'Temp')
    )

    foreach ($root in $searchRoots) {
        if (-not $root -or -not (Test-Path $root)) {
            continue
        }

        $candidate = Get-ChildItem -Path $root -Recurse -Filter gradle.bat -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName

        if ($candidate) {
            return $candidate
        }
    }

    return $null
}

function Find-AndroidSdkPath {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

Push-Location $pluginRoot
try {
    if (-not $gradleCommand) {
        $gradleCommand = Find-GradleCommand
    }

    if (-not $gradleCommand) {
        throw "Gradle was not found. Install Gradle or add a Gradle wrapper under android/plugins/fcm_push_bridge."
    }

    $androidSdkPath = Find-AndroidSdkPath
    if (-not $androidSdkPath) {
        throw "Android SDK was not found. Set ANDROID_HOME or install the SDK under %LOCALAPPDATA%\\Android\\Sdk."
    }

    $env:ANDROID_HOME = $androidSdkPath
    $env:ANDROID_SDK_ROOT = $androidSdkPath
    $sdkDirForGradle = $androidSdkPath -replace '\\', '/'
    Set-Content -Path (Join-Path $pluginRoot 'local.properties') -Value ("sdk.dir={0}" -f $sdkDirForGradle) -Encoding ASCII

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
