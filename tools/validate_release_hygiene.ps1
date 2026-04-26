param(
    [switch]$CheckGithubLatest,
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$AppName = "Endless-Helicopter-Reborn",
    [string]$AndroidLatestTag = "android-latest"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
}

function Read-RequiredText {
    param([string]$RelativePath)
    $path = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Add-Failure "Missing required release file: $RelativePath"
        return ""
    }
    return Get-Content -Raw -LiteralPath $path
}

function Match-Required {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Description
    )
    $match = [Regex]::Match($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        Add-Failure "Could not find $Description."
        return ""
    }
    return $match.Groups[1].Value.Trim()
}

function Get-ObjectProperty {
    param(
        [object]$Object,
        [string]$Name
    )
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Invoke-GhJson {
    param(
        [string[]]$Arguments,
        [string]$Description
    )
    $output = & gh @Arguments 2>&1
    $text = ($output -join "`n")
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "Could not read $Description for ${Repository}: $text"
        return $null
    }
    try {
        return $text | ConvertFrom-Json
    }
    catch {
        Add-Failure "Could not parse $Description JSON for ${Repository}: $($_.Exception.Message)"
        return $null
    }
}

function Get-ApkAssets {
    param([object]$Release)
    if ($null -eq $Release) {
        return @()
    }
    $assets = Get-ObjectProperty $Release "assets"
    if ($null -eq $assets) {
        return @()
    }
    return @($assets | Where-Object {
        $assetName = [string](Get-ObjectProperty $_ "name")
        $contentType = [string](Get-ObjectProperty $_ "contentType")
        $assetName.EndsWith(".apk", [StringComparison]::OrdinalIgnoreCase) -or $contentType -eq "application/vnd.android.package-archive"
    })
}

function Find-AssetByName {
    param(
        [object[]]$Assets,
        [string]$Name
    )
    return @($Assets | Where-Object { [string](Get-ObjectProperty $_ "name") -eq $Name } | Select-Object -First 1)
}

function Test-OnlyExpectedApkAsset {
    param(
        [object]$Release,
        [string]$ReleaseDescription,
        [string]$ExpectedAssetName
    )
    $apkAssets = @(Get-ApkAssets $Release)
    $matchingAssets = @(Find-AssetByName $apkAssets $ExpectedAssetName)
    if ($matchingAssets.Count -ne 1) {
        Add-Failure "$ReleaseDescription should contain exactly one APK asset named $ExpectedAssetName."
    }
    foreach ($asset in $apkAssets) {
        $assetName = [string](Get-ObjectProperty $asset "name")
        if ($assetName -ne $ExpectedAssetName) {
            Add-Failure "$ReleaseDescription contains stale APK asset $assetName; expected only $ExpectedAssetName."
        }
    }
    if ($matchingAssets.Count -gt 0) {
        return $matchingAssets[0]
    }
    return $null
}

$exportText = Read-RequiredText "export_presets.cfg"
$buildInfoText = Read-RequiredText "systems/build_info.gd"
$latestNotesText = Read-RequiredText "docs/release_notes/latest.md"
$discordSummaryText = Read-RequiredText "docs/release_notes/discord_summary.md"

$exportVersionCodeText = Match-Required $exportText '^version/code=(\d+)\s*$' "version/code in export_presets.cfg"
$exportVersionName = Match-Required $exportText '^version/name="?([^"\r\n]+?)"?\s*$' "version/name in export_presets.cfg"
$buildVersionCodeText = Match-Required $buildInfoText '^const VERSION_CODE := (\d+)\s*$' "VERSION_CODE in systems/build_info.gd"
$buildVersionName = Match-Required $buildInfoText '^const VERSION_NAME := "([^"\r\n]+)"\s*$' "VERSION_NAME in systems/build_info.gd"

$versionCode = 0
if (-not [int]::TryParse($exportVersionCodeText, [ref]$versionCode)) {
    Add-Failure "export_presets.cfg version/code is not an integer: $exportVersionCodeText"
}

$buildVersionCode = 0
if (-not [int]::TryParse($buildVersionCodeText, [ref]$buildVersionCode)) {
    Add-Failure "systems/build_info.gd VERSION_CODE is not an integer: $buildVersionCodeText"
}

if ($exportVersionName -ne $buildVersionName) {
    Add-Failure "version/name ($exportVersionName) does not match VERSION_NAME ($buildVersionName)."
}
if ($versionCode -ne $buildVersionCode) {
    Add-Failure "version/code ($versionCode) does not match VERSION_CODE ($buildVersionCode)."
}

$latestHeading = (($latestNotesText -split "\r?\n") | Select-Object -First 1).Trim()
if ($latestHeading -notmatch [Regex]::Escape($exportVersionName)) {
    Add-Failure "docs/release_notes/latest.md heading should include version $exportVersionName."
}
if ($latestNotesText -notmatch [Regex]::Escape("Version $exportVersionName")) {
    Add-Failure "docs/release_notes/latest.md should describe Version $exportVersionName."
}

$expectedDiscordVersion = "$exportVersionName ($versionCode)"
if ($discordSummaryText -notmatch [Regex]::Escape($expectedDiscordVersion)) {
    Add-Failure "docs/release_notes/discord_summary.md should include $expectedDiscordVersion."
}

$expectedTag = "v$exportVersionName-build.$versionCode"
$expectedTitle = "$AppName $exportVersionName ($versionCode)"
$expectedApkAssetName = "$AppName.apk"
$expectedAndroidLatestTitle = "$AppName Latest APK"
$expectedReleaseUrl = "https://github.com/$Repository/releases/tag/$expectedTag"

if ($CheckGithubLatest) {
    if ([string]::IsNullOrWhiteSpace($Repository)) {
        Add-Failure "Repository is required for GitHub latest release validation."
    }
    elseif ((Get-Command gh -ErrorAction SilentlyContinue) -eq $null) {
        Add-Failure "GitHub CLI gh is required for GitHub latest release validation."
    }
    else {
        $release = Invoke-GhJson @("release", "view", "--json", "tagName,name,isPrerelease,url,assets", "--repo", $Repository) "GitHub latest release"
        $latestApkAsset = $null
        if ($null -ne $release) {
            if ([bool](Get-ObjectProperty $release "isPrerelease")) {
                Add-Failure "GitHub latest release should not be a prerelease: $(Get-ObjectProperty $release "url")"
            }
            if ([string](Get-ObjectProperty $release "tagName") -ne $expectedTag) {
                Add-Failure "GitHub latest release tag ($(Get-ObjectProperty $release "tagName")) should be $expectedTag."
            }
            if ([string](Get-ObjectProperty $release "name") -ne $expectedTitle) {
                Add-Failure "GitHub latest release title ($(Get-ObjectProperty $release "name")) should be $expectedTitle."
            }
            $latestApkAsset = Test-OnlyExpectedApkAsset $release "GitHub latest release" $expectedApkAssetName
        }

        $androidLatest = Invoke-GhJson @("release", "view", $AndroidLatestTag, "--json", "tagName,name,isPrerelease,url,body,assets", "--repo", $Repository) "GitHub $AndroidLatestTag release alias"
        if ($null -ne $androidLatest) {
            if ([string](Get-ObjectProperty $androidLatest "tagName") -ne $AndroidLatestTag) {
                Add-Failure "GitHub Android latest alias tag ($(Get-ObjectProperty $androidLatest "tagName")) should be $AndroidLatestTag."
            }
            if ([string](Get-ObjectProperty $androidLatest "name") -ne $expectedAndroidLatestTitle) {
                Add-Failure "GitHub Android latest alias title ($(Get-ObjectProperty $androidLatest "name")) should be $expectedAndroidLatestTitle."
            }
            if (-not [bool](Get-ObjectProperty $androidLatest "isPrerelease")) {
                Add-Failure "GitHub $AndroidLatestTag release alias should be a prerelease: $(Get-ObjectProperty $androidLatest "url")"
            }
            $aliasBody = [string](Get-ObjectProperty $androidLatest "body")
            if (-not $aliasBody.Contains($expectedReleaseUrl)) {
                Add-Failure "GitHub $AndroidLatestTag release alias should point to $expectedReleaseUrl."
            }
            $aliasApkAsset = Test-OnlyExpectedApkAsset $androidLatest "GitHub $AndroidLatestTag release alias" $expectedApkAssetName
            if ($null -ne $latestApkAsset -and $null -ne $aliasApkAsset) {
                $latestDigest = [string](Get-ObjectProperty $latestApkAsset "digest")
                $aliasDigest = [string](Get-ObjectProperty $aliasApkAsset "digest")
                if (-not [string]::IsNullOrWhiteSpace($latestDigest) -and -not [string]::IsNullOrWhiteSpace($aliasDigest) -and $latestDigest -ne $aliasDigest) {
                    Add-Failure "GitHub $AndroidLatestTag APK digest ($aliasDigest) should match latest release APK digest ($latestDigest)."
                }

                $latestSize = Get-ObjectProperty $latestApkAsset "size"
                $aliasSize = Get-ObjectProperty $aliasApkAsset "size"
                if ($null -ne $latestSize -and $null -ne $aliasSize -and [int64]$latestSize -ne [int64]$aliasSize) {
                    Add-Failure "GitHub $AndroidLatestTag APK size ($aliasSize) should match latest release APK size ($latestSize)."
                }
            }
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

Write-Host "Release hygiene validation passed for $exportVersionName ($versionCode)."
if ($CheckGithubLatest) {
    Write-Host "GitHub latest release and $AndroidLatestTag alias match $expectedTag."
}
