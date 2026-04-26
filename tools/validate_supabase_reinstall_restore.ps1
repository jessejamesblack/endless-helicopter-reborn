param(
    [string]$ProjectRef = "lxvniafwjlwatbiblwyi",
    [string]$AccessToken = $env:SUPABASE_ACCESS_TOKEN
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw 'SUPABASE_ACCESS_TOKEN is required to validate live Supabase reinstall restore flow.'
}

Add-Type -AssemblyName System.Net.Http

function New-SupabaseMcpClient {
    param(
        [string]$ResolvedProjectRef,
        [string]$ResolvedAccessToken
    )

    $client = [System.Net.Http.HttpClient]::new()
    $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $ResolvedAccessToken)
    $client.DefaultRequestHeaders.Accept.ParseAdd('application/json')
    $client.DefaultRequestHeaders.Accept.ParseAdd('text/event-stream')

    $baseUrl = "https://mcp.supabase.com/mcp?project_ref=$ResolvedProjectRef"
    $initializePayload = @{
        jsonrpc = '2.0'
        id = 1
        method = 'initialize'
        params = @{
            protocolVersion = '2025-03-26'
            capabilities = @{}
            clientInfo = @{
                name = 'restore-resume-validator'
                version = '1.0'
            }
        }
    } | ConvertTo-Json -Compress -Depth 8

    $initializeContent = [System.Net.Http.StringContent]::new($initializePayload, [System.Text.Encoding]::UTF8, 'application/json')
    $initializeResponse = $client.PostAsync($baseUrl, $initializeContent).GetAwaiter().GetResult()
    $initializeBody = $initializeResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $initializeResponse.IsSuccessStatusCode) {
        throw "Supabase MCP initialize failed: $([int]$initializeResponse.StatusCode) $initializeBody"
    }

    $sessionId = ($initializeResponse.Headers.GetValues('mcp-session-id') | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        throw 'Supabase MCP initialize did not return an MCP session id.'
    }

    $client.DefaultRequestHeaders.Add('MCP-Session-Id', $sessionId)

    $initializedContent = [System.Net.Http.StringContent]::new('{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}', [System.Text.Encoding]::UTF8, 'application/json')
    [void]$client.PostAsync($baseUrl, $initializedContent).GetAwaiter().GetResult()

    return @{
        Client = $client
        BaseUrl = $baseUrl
    }
}

function Invoke-SupabaseMcpTool {
    param(
        [hashtable]$Session,
        [string]$ToolName,
        [hashtable]$Arguments
    )

    $payload = @{
        jsonrpc = '2.0'
        id = 2
        method = 'tools/call'
        params = @{
            name = $ToolName
            arguments = $Arguments
        }
    } | ConvertTo-Json -Compress -Depth 20

    $content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
    $response = $Session.Client.PostAsync($Session.BaseUrl, $content).GetAwaiter().GetResult()
    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
        throw "Supabase MCP tool call failed: $([int]$response.StatusCode) $body"
    }

    $parsed = $body | ConvertFrom-Json
    if ($parsed.result.content.Count -lt 1) {
        throw "Supabase MCP tool call returned no content: $body"
    }

    return $parsed.result.content[0].text
}

function Get-SqlRowsFromToolText {
    param([string]$Text)

    $parsedText = $Text | ConvertFrom-Json
    $resultText = ''
    if ($parsedText -and $parsedText.PSObject.Properties.Name -contains 'result') {
        $resultText = [string]$parsedText.result
    }
    if ([string]::IsNullOrWhiteSpace($resultText)) {
        throw "Could not extract SQL result text from MCP response: $Text"
    }

    $match = [regex]::Match($resultText, '(?s)<untrusted-data-[^>]+>\r?\n(.*?)\r?\n</untrusted-data-[^>]+>')
    if (-not $match.Success) {
        throw "Could not extract SQL rows from MCP response: $resultText"
    }

    return ($match.Groups[1].Value | ConvertFrom-Json)
}

$session = New-SupabaseMcpClient -ResolvedProjectRef $ProjectRef -ResolvedAccessToken $AccessToken

$verifyRows = Get-SqlRowsFromToolText (Invoke-SupabaseMcpTool -Session $session -ToolName 'execute_sql' -Arguments @{
    query = "select position('app_update_push_history' in pg_get_functiondef('public.migrate_player_identity(text,text,text,text,text)'::regprocedure)) > 0 as migrates_app_update_push_history;"
})

if (-not $verifyRows[0].migrates_app_update_push_history) {
    throw 'Live migrate_player_identity() does not reference app_update_push_history.'
}

$familyId = 'restore_resume_validation_' + ([guid]::NewGuid().ToString('N').Substring(0, 10))
$oldPlayerId = 'legacy-player'
$newPlayerId = 'stable-player'
$oldDeviceId = $familyId + '-legacy-device'
$newDeviceId = $familyId + '-stable-device'
$oldPlayerName = ('O' + ([guid]::NewGuid().ToString('N').Substring(0, 11))).Substring(0, 12)
$newPlayerName = ('N' + ([guid]::NewGuid().ToString('N').Substring(0, 11))).Substring(0, 12)

$validationSql = @"
begin;

insert into public.family_player_profiles (
    family_id,
    player_id,
    name,
    equipped_skin_id,
    unlocked_skins,
    equipped_vehicle_id,
    unlocked_vehicles,
    unlocked_vehicle_skins,
    equipped_vehicle_skins,
    vehicle_skin_progress,
    global_skin_unlocks,
    best_score_milestones,
    seen_vehicle_lore,
    seen_skin_lore,
    vehicle_catalog_version,
    total_daily_missions_completed,
    daily_streak,
    last_completed_daily_date,
    daily_reminders_enabled,
    profile_summary
)
values (
    '$familyId',
    '$oldPlayerId',
    '$oldPlayerName',
    'bubble_chopper',
    '["default_scout","bubble_chopper"]'::jsonb,
    'bubble_chopper',
    '["default_scout","bubble_chopper"]'::jsonb,
    '{"default_scout":["factory"],"bubble_chopper":["factory","desert"]}'::jsonb,
    '{"default_scout":"factory","bubble_chopper":"desert"}'::jsonb,
    '{"bubble_chopper":{"runs_completed":6,"daily_missions_completed":2,"near_misses":14,"projectile_intercepts":3,"best_score":4200}}'::jsonb,
    '[]'::jsonb,
    '{"score_10000":false}'::jsonb,
    '["bubble_chopper"]'::jsonb,
    '["bubble_chopper:desert"]'::jsonb,
    2,
    4,
    2,
    '2026-04-19',
    true,
    '{"equipped_vehicle_id":"bubble_chopper","unlocked_vehicles":["default_scout","bubble_chopper"],"missions_intro_seen":true}'::jsonb
);

insert into public.family_player_profiles (
    family_id,
    player_id,
    name,
    equipped_skin_id,
    unlocked_skins,
    equipped_vehicle_id,
    unlocked_vehicles,
    unlocked_vehicle_skins,
    equipped_vehicle_skins,
    vehicle_skin_progress,
    global_skin_unlocks,
    best_score_milestones,
    seen_vehicle_lore,
    seen_skin_lore,
    vehicle_catalog_version,
    total_daily_missions_completed,
    daily_streak,
    last_completed_daily_date,
    daily_reminders_enabled,
    profile_summary
)
values (
    '$familyId',
    '$newPlayerId',
    '$newPlayerName',
    'default_scout',
    '["default_scout"]'::jsonb,
    'default_scout',
    '["default_scout"]'::jsonb,
    '{"default_scout":["factory"]}'::jsonb,
    '{"default_scout":"factory"}'::jsonb,
    '{"default_scout":{"runs_completed":0,"daily_missions_completed":0,"near_misses":0,"projectile_intercepts":0,"best_score":0}}'::jsonb,
    '[]'::jsonb,
    '{"score_10000":false}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    1,
    0,
    0,
    null,
    false,
    '{"equipped_vehicle_id":"default_scout","missions_intro_seen":false}'::jsonb
);

insert into public.family_daily_mission_progress (
    family_id,
    player_id,
    mission_date,
    missions,
    completed_count,
    total_count
)
values (
    '$familyId',
    '$oldPlayerId',
    '2026-04-20',
    '[{"mission_id":"close_calls","target":3,"progress":1,"complete":false}]'::jsonb,
    1,
    3
);

insert into public.family_leaderboard (
    family_id,
    player_id,
    name,
    score,
    run_summary,
    equipped_skin_id,
    equipped_vehicle_id,
    equipped_vehicle_skin_id
)
values (
    '$familyId',
    '$oldPlayerId',
    '$oldPlayerName',
    4200,
    '{"score":4200,"equipped_vehicle_id":"bubble_chopper"}'::jsonb,
    'bubble_chopper',
    'bubble_chopper',
    'desert'
);

insert into public.family_leaderboard (
    family_id,
    player_id,
    name,
    score,
    run_summary,
    equipped_skin_id,
    equipped_vehicle_id,
    equipped_vehicle_skin_id
)
values (
    '$familyId',
    '$newPlayerId',
    '$newPlayerName',
    60,
    '{"score":60,"equipped_vehicle_id":"default_scout"}'::jsonb,
    'default_scout',
    'default_scout',
    'factory'
);

insert into public.family_run_history (
    family_id,
    player_id,
    name,
    score,
    run_summary,
    equipped_skin_id
)
values (
    '$familyId',
    '$oldPlayerId',
    '$oldPlayerName',
    4200,
    '{"score":4200}'::jsonb,
    'bubble_chopper'
);

insert into public.family_run_history (
    family_id,
    player_id,
    name,
    score,
    run_summary,
    equipped_skin_id
)
values (
    '$familyId',
    '$newPlayerId',
    '$newPlayerName',
    60,
    '{"score":60}'::jsonb,
    'default_scout'
);

insert into public.family_notifications (
    family_id,
    target_player_id,
    challenger_name,
    challenger_score,
    beaten_score
)
values (
    '$familyId',
    '$oldPlayerId',
    'Rival',
    4500,
    4200
);

insert into public.family_push_delivery_log (
    family_id,
    target_player_id,
    device_id,
    fcm_token,
    notification_type,
    status
)
values (
    '$familyId',
    '$oldPlayerId',
    '$oldDeviceId',
    'mcp-fcm-old',
    'daily_missions',
    'sent'
);

insert into public.family_push_devices (
    family_id,
    player_id,
    device_id,
    fcm_token,
    platform,
    device_label,
    notifications_enabled,
    daily_missions_enabled,
    app_version_code,
    app_version_name,
    build_sha,
    release_channel
)
values (
    '$familyId',
    '$oldPlayerId',
    '$oldDeviceId',
    'mcp-fcm-old',
    'android',
    'Legacy Phone',
    true,
    true,
    101,
    '1.0.1',
    'restore-test-old',
    'stable'
);

insert into public.family_push_devices (
    family_id,
    player_id,
    device_id,
    fcm_token,
    platform,
    device_label,
    notifications_enabled,
    daily_missions_enabled,
    app_version_code,
    app_version_name,
    build_sha,
    release_channel
)
values (
    '$familyId',
    '$newPlayerId',
    '$newDeviceId',
    'mcp-fcm-new',
    'android',
    'Fresh Install Phone',
    false,
    false,
    202,
    '2.0.2',
    'restore-test-new',
    'stable'
);

insert into public.app_update_push_history (
    channel,
    version_code,
    family_id,
    player_id,
    device_id,
    status
)
values
    ('stable', 999901, '$familyId', '$oldPlayerId', '$oldDeviceId', 'sent'),
    ('stable', 999901, '$familyId', '$newPlayerId', '$newDeviceId', 'sent'),
    ('stable', 999902, '$familyId', '$oldPlayerId', '$oldDeviceId', 'sent');

select public.migrate_player_identity('$familyId', '$oldPlayerId', '$newPlayerId', '$oldDeviceId', '$newDeviceId') as migration_outcome;

select
    not exists(
        select 1 from public.family_player_profiles
        where family_id = '$familyId' and player_id = '$oldPlayerId'
    ) as old_profile_removed,
    exists(
        select 1 from public.family_player_profiles
        where family_id = '$familyId'
          and player_id = '$newPlayerId'
          and total_daily_missions_completed = 4
          and daily_streak = 2
          and daily_reminders_enabled = true
          and coalesce(profile_summary ->> 'equipped_vehicle_id', '') = 'bubble_chopper'
    ) as new_profile_restored,
    exists(
        select 1 from public.family_daily_mission_progress
        where family_id = '$familyId'
          and player_id = '$newPlayerId'
          and mission_date = '2026-04-20'
          and completed_count = 1
    ) as mission_progress_restored,
    exists(
        select 1 from public.family_leaderboard
        where family_id = '$familyId'
          and player_id = '$newPlayerId'
          and score = 4200
    ) as leaderboard_restored,
    (
        select count(*) = 2
        from public.family_run_history
        where family_id = '$familyId'
          and player_id = '$newPlayerId'
    ) as run_history_rebound,
    exists(
        select 1 from public.family_notifications
        where family_id = '$familyId'
          and target_player_id = '$newPlayerId'
    ) as notifications_rebound,
    exists(
        select 1 from public.family_push_delivery_log
        where family_id = '$familyId'
          and target_player_id = '$newPlayerId'
          and device_id = '$newDeviceId'
    ) as push_delivery_rebound,
    exists(
        select 1 from public.family_push_devices
        where family_id = '$familyId'
          and player_id = '$newPlayerId'
          and device_id = '$newDeviceId'
          and fcm_token = 'mcp-fcm-new'
          and notifications_enabled = true
          and daily_missions_enabled = true
    ) as push_device_rebound,
    not exists(
        select 1 from public.family_push_devices
        where family_id = '$familyId'
          and device_id = '$oldDeviceId'
    ) as old_push_device_removed,
    not exists(
        select 1 from public.app_update_push_history
        where family_id = '$familyId'
          and device_id = '$oldDeviceId'
    ) as old_update_history_removed,
    (
        select count(*) = 2
        from public.app_update_push_history
        where family_id = '$familyId'
          and device_id = '$newDeviceId'
          and player_id = '$newPlayerId'
    ) as update_history_rebound,
    (
        select count(*) = 1
        from public.app_update_push_history
        where family_id = '$familyId'
          and version_code = 999901
          and device_id = '$newDeviceId'
    ) as update_history_conflict_deduped;

rollback;
"@

$validationRows = Get-SqlRowsFromToolText (Invoke-SupabaseMcpTool -Session $session -ToolName 'execute_sql' -Arguments @{
    query = $validationSql
})

$summary = $validationRows[0]
$failedChecks = @()
foreach ($property in $summary.PSObject.Properties) {
    if ($property.Value -is [bool] -and -not $property.Value) {
        $failedChecks += $property.Name
    }
}

if ($failedChecks.Count -gt 0) {
    throw "Supabase reinstall/restore validation failed: $($failedChecks -join ', ')"
}

Write-Host 'Supabase reinstall/restore validation completed successfully.'
$summary | ConvertTo-Json -Depth 10
