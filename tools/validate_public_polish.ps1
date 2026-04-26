Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
}

function Require-File {
    param([string]$RelativePath)
    $path = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Missing required public polish file: $RelativePath"
        return $null
    }
    return Get-Item -LiteralPath $path
}

function Require-Text {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Message
    )
    if (-not $Text.Contains($Needle)) {
        Add-Failure $Message
    }
}

$readmeItem = Require-File "README.md"
$roadmapItem = Require-File "docs/ROADMAP.md"
$aiCollaborationItem = Require-File "docs/AI_COLLABORATION.md"
$agentsItem = Require-File "AGENTS.md"

$readmeText = if ($readmeItem -ne $null) { Get-Content -Raw -LiteralPath $readmeItem.FullName } else { "" }
$roadmapText = if ($roadmapItem -ne $null) { Get-Content -Raw -LiteralPath $roadmapItem.FullName } else { "" }
$aiCollaborationText = if ($aiCollaborationItem -ne $null) { Get-Content -Raw -LiteralPath $aiCollaborationItem.FullName } else { "" }
$agentsText = if ($agentsItem -ne $null) { Get-Content -Raw -LiteralPath $agentsItem.FullName } else { "" }

Require-Text $readmeText "## Download Latest APK" "README should include a near-top latest APK download section."
Require-Text $readmeText "https://github.com/jessejamesblack/endless-helicopter-reborn/releases/latest" "README should link to the latest versioned GitHub release."
Require-Text $readmeText "https://github.com/jessejamesblack/endless-helicopter-reborn/releases/tag/android-latest" "README should link to the rolling android-latest release alias."
Require-Text $readmeText "## Gameplay Preview" "README should include a gameplay preview section."
Require-Text $readmeText "## Controls" "README should include a controls preview section."
Require-Text $readmeText "SKILL.md" "README AI collaboration section should mention repo-local skill files."
Require-Text $readmeText "tools/capture_readme_media.gd" "README AI collaboration section should mention the README media capture workflow."
Require-Text $readmeText "docs/ROADMAP.md" "README should link to the project roadmap."
Require-Text $agentsText "docs/ROADMAP.md" "AGENTS.md should include the roadmap in the docs map."
Require-Text $aiCollaborationText "SKILL.md" "AI collaboration docs should mention repo-local skill files."
Require-Text $aiCollaborationText "tools/capture_readme_media.gd" "AI collaboration docs should mention README media capture."
Require-Text $aiCollaborationText "release-hygiene" "AI collaboration docs should mention release hygiene checks."

$mediaFiles = @(
    "docs/media/readme-title.png",
    "docs/media/readme-run.png",
    "docs/media/readme-upgrades.png",
    "docs/media/readme-results.png",
    "docs/media/readme-hangar.png",
    "docs/media/readme-missions.png",
    "docs/media/readme-pause.png",
    "docs/media/readme-settings.png"
)

foreach ($relativePath in $mediaFiles) {
    if ($relativePath.ToLowerInvariant().Contains("screenshot")) {
        Add-Failure "README media filenames should not include the word screenshot: $relativePath"
    }
    $item = Require-File $relativePath
    if ($item -ne $null -and $item.Length -lt 10000) {
        Add-Failure "README media file looks too small to be a useful capture: $relativePath"
    }
    Require-Text $readmeText $relativePath "README should reference $relativePath."
}

foreach ($milestone in @("1.6.x cleanup", "1.7 gameplay content", "1.8 refactor", "1.9 validation", "2.0 public-ready")) {
    Require-Text $roadmapText $milestone "Roadmap should include milestone: $milestone"
}

$issueTemplates = @(
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/gameplay_tuning.yml",
    ".github/ISSUE_TEMPLATE/android_install.yml",
    ".github/ISSUE_TEMPLATE/backend_sync.yml",
    ".github/ISSUE_TEMPLATE/config.yml"
)

foreach ($templatePath in $issueTemplates) {
    $item = Require-File $templatePath
    if ($item -ne $null) {
        $text = Get-Content -Raw -LiteralPath $item.FullName
        if ($templatePath.EndsWith("config.yml")) {
            Require-Text $text "blank_issues_enabled: false" "$templatePath should disable blank issues."
            Require-Text $text "contact_links:" "$templatePath should define contact links."
        }
        else {
            Require-Text $text "name:" "$templatePath should define a template name."
            Require-Text $text "description:" "$templatePath should define a template description."
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

Write-Host "Public polish validation passed."
