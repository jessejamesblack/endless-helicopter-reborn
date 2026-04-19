alter table public.family_leaderboard enable row level security;
alter table public.family_notifications enable row level security;
alter table public.family_push_devices enable row level security;
alter table public.family_player_profiles enable row level security;
alter table public.family_daily_mission_progress enable row level security;
alter table public.family_run_history enable row level security;
alter table public.client_error_events enable row level security;
alter table public.family_feedback_reports enable row level security;

alter table public.family_daily_mission_progress
alter column total_count set default 5;

drop policy if exists "family_leaderboard_insert" on public.family_leaderboard;
drop policy if exists "family_leaderboard_update" on public.family_leaderboard;

drop policy if exists "family_notifications_read" on public.family_notifications;
drop policy if exists "family_notifications_insert" on public.family_notifications;
drop policy if exists "family_notifications_update" on public.family_notifications;

drop policy if exists "family_push_devices_read" on public.family_push_devices;
drop policy if exists "family_push_devices_insert" on public.family_push_devices;
drop policy if exists "family_push_devices_update" on public.family_push_devices;

drop policy if exists "family_player_profiles_read" on public.family_player_profiles;
drop policy if exists "family_daily_mission_progress_read" on public.family_daily_mission_progress;
drop policy if exists "family_run_history_read" on public.family_run_history;

drop policy if exists "client_error_events_insert" on public.client_error_events;
drop policy if exists "client_error_events_read" on public.client_error_events;

drop policy if exists "family_feedback_reports_insert" on public.family_feedback_reports;
drop policy if exists "family_feedback_reports_read" on public.family_feedback_reports;

revoke execute on function public.submit_family_score_v2(text, text, text, integer, jsonb, text)
from public, anon, authenticated;

revoke execute on function public.sync_player_profile(text, text, text, text, jsonb, integer, integer, text, boolean, jsonb)
from public, anon, authenticated;

revoke execute on function public.sync_daily_mission_progress(text, text, text, jsonb, integer, integer)
from public, anon, authenticated;

revoke execute on function public.get_player_profile(text, text)
from public, anon, authenticated;

revoke execute on function public.get_daily_mission_progress(text, text, text)
from public, anon, authenticated;

revoke execute on function public.migrate_player_identity(text, text, text, text, text)
from public, anon, authenticated;
