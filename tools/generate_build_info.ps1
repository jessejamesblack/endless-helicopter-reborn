param(
    [string]$ExportPresetsPath = (Join-Path $PSScriptRoot "..\export_presets.cfg"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\systems\build_info.gd"),
    [string]$BuildSha = "",
    [string]$BuildDate = "",
    [string]$ReleaseChannel = "",
    [string]$SigningMode = ""
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
if ([string]::IsNullOrWhiteSpace($SigningMode)) {
    $SigningMode = if ($env:SIGNING_KEY_MODE) { $env:SIGNING_KEY_MODE } else { "local_unspecified" }
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
const SIGNING_MODE := "$SigningMode"

static func get_summary() -> Dictionary:
	return {
		"version_code": VERSION_CODE,
		"version_name": VERSION_NAME,
		"build_sha": BUILD_SHA,
		"build_date": BUILD_DATE,
		"release_channel": RELEASE_CHANNEL,
		"app_package_name": APP_PACKAGE_NAME,
		"signing_mode": SIGNING_MODE,
	}

static func get_version_label() -> String:
	return "%s (%d)" % [VERSION_NAME, VERSION_CODE]

static func get_signing_label() -> String:
	match SIGNING_MODE:
		"release_stable":
			return "Stable release key"
		"debug_stable":
			return "Stable debug key"
		"temporary_debug":
			return "Temporary debug key"
		"local_unspecified":
			return "Local/unspecified key"
	return SIGNING_MODE.replace("_", " ").capitalize()

static func is_identity_continuity_safe() -> bool:
	return SIGNING_MODE == "release_stable" or SIGNING_MODE == "debug_stable"

static func get_debug_label() -> String:
	return "%s | %s | %s | %s" % [get_version_label(), BUILD_SHA, RELEASE_CHANNEL, SIGNING_MODE]
"@

Set-Content -Path $OutputPath -Value $buildInfo -Encoding ASCII
Write-Host "Generated build info at $OutputPath"
