param(
    [string]$ExportPresetsPath = (Join-Path $PSScriptRoot "..\export_presets.cfg"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\systems\build_info.gd"),
    [string]$BuildSha = "",
    [string]$BuildDate = "",
    [string]$ReleaseChannel = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-PresetValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $pattern = "(?m)^" + [Regex]::Escape($Key) + "=(.+)$"
    $match = [Regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        throw "Could not find '$Key' in export presets."
    }
    return $match.Groups[1].Value.Trim()
}

function Unquote-Value {
    param([string]$Value)
    if ($Value.StartsWith('"') -and $Value.EndsWith('"')) {
        return $Value.Substring(1, $Value.Length - 2)
    }
    return $Value
}

$presetsText = Get-Content -Raw $ExportPresetsPath
$versionCode = [int](Get-PresetValue -Text $presetsText -Key "version/code")
$versionName = Unquote-Value (Get-PresetValue -Text $presetsText -Key "version/name")
$appPackageName = Unquote-Value (Get-PresetValue -Text $presetsText -Key "package/unique_name")
if ([string]::IsNullOrWhiteSpace($versionName)) {
    $versionName = "0.0.0"
}
if ([string]::IsNullOrWhiteSpace($appPackageName)) {
    $appPackageName = "com.jessejamesblack.endlesshelicopterreborn"
}

if ([string]::IsNullOrWhiteSpace($BuildSha)) {
    $BuildSha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA.Substring(0, [Math]::Min(7, $env:GITHUB_SHA.Length)) } else { "dev" }
}
if ([string]::IsNullOrWhiteSpace($BuildDate)) {
    $BuildDate = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}
if ([string]::IsNullOrWhiteSpace($ReleaseChannel)) {
    $ReleaseChannel = if ($env:RELEASE_CHANNEL) { $env:RELEASE_CHANNEL } else { "dev" }
}

$buildInfo = @"
extends RefCounted
class_name BuildInfo

const VERSION_CODE := $versionCode
const VERSION_NAME := "$versionName"
const BUILD_SHA := "$BuildSha"
const BUILD_DATE := "$BuildDate"
const RELEASE_CHANNEL := "$ReleaseChannel"
const APP_PACKAGE_NAME := "$appPackageName"

static func get_summary() -> Dictionary:
	return {
		"version_code": VERSION_CODE,
		"version_name": VERSION_NAME,
		"build_sha": BUILD_SHA,
		"build_date": BUILD_DATE,
		"release_channel": RELEASE_CHANNEL,
		"app_package_name": APP_PACKAGE_NAME,
	}

static func get_version_label() -> String:
	return "%s (%d)" % [VERSION_NAME, VERSION_CODE]

static func get_debug_label() -> String:
	return "%s | %s | %s" % [get_version_label(), BUILD_SHA, RELEASE_CHANNEL]
"@

Set-Content -Path $OutputPath -Value $buildInfo -Encoding ASCII
Write-Host "Generated build info at $OutputPath"
