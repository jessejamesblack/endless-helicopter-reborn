-- Fresh-start gameplay-data wipe for the Android stable-release cutover.
--
-- Safe-use preconditions:
-- 1. The cutover release has been built from the permanent stable release key.
-- 2. app_release_channels.minimum_supported_version_code has already been
--    raised to the cutover build's version code so older clients are
--    force-gated off the backend.
-- 3. This wipe has been reviewed as an intentional fresh-start event.
--
-- This script deliberately preserves operational/config tables:
-- - app_release_channels
-- - family_push_runtime_config
-- - family_weekly_recap_log
-- - family_daily_dispatch_log
-- - client_error_events
-- - family_feedback_reports
--
-- This script deliberately wipes only user-bearing gameplay tables:
-- - family_player_profiles
-- - family_daily_mission_progress
-- - family_leaderboard
-- - family_run_history
-- - family_notifications
-- - family_push_devices
-- - family_push_delivery_log
-- - app_update_push_history

begin;

delete from public.app_update_push_history;
delete from public.family_push_delivery_log;
delete from public.family_notifications;
delete from public.family_push_devices;
delete from public.family_run_history;
delete from public.family_leaderboard;
delete from public.family_daily_mission_progress;
delete from public.family_player_profiles;

commit;

select 'family_player_profiles' as table_name, count(*) as remaining_rows from public.family_player_profiles
union all
select 'family_daily_mission_progress', count(*) from public.family_daily_mission_progress
union all
select 'family_leaderboard', count(*) from public.family_leaderboard
union all
select 'family_run_history', count(*) from public.family_run_history
union all
select 'family_notifications', count(*) from public.family_notifications
union all
select 'family_push_devices', count(*) from public.family_push_devices
union all
select 'family_push_delivery_log', count(*) from public.family_push_delivery_log
union all
select 'app_update_push_history', count(*) from public.app_update_push_history
order by table_name;
