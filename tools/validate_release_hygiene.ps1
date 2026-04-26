param(
    [switch]$CheckGithubLatest,
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$AppName = "Endless-Helicopter-Reborn"
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

if ($CheckGithubLatest) {
    if ([string]::IsNullOrWhiteSpace($Repository)) {
        Add-Failure "Repository is required for GitHub latest release validation."
    }
    elseif ((Get-Command gh -ErrorAction SilentlyContinue) -eq $null) {
        Add-Failure "GitHub CLI gh is required for GitHub latest release validation."
    }
    else {
        $ghArgs = @("release", "view", "--json", "tagName,name,isPrerelease,url", "--repo", $Repository)
        $releaseJson = & gh @ghArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "Could not read GitHub latest release for ${Repository}: $releaseJson"
        }
        else {
            $release = $releaseJson | ConvertFrom-Json
            if ([bool]$release.isPrerelease) {
                Add-Failure "GitHub latest release should not be a prerelease: $($release.url)"
            }
            if ([string]$release.tagName -ne $expectedTag) {
                Add-Failure "GitHub latest release tag ($($release.tagName)) should be $expectedTag."
            }
            if ([string]$release.name -ne $expectedTitle) {
                Add-Failure "GitHub latest release title ($($release.name)) should be $expectedTitle."
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
    Write-Host "GitHub latest release matches $expectedTag."
}
