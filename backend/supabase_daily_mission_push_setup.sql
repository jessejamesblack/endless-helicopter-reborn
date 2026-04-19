-- Runs every hour, but only dispatches during the 8:00 AM ET hour.
-- This avoids manual DST updates between EST and EDT.
select cron.schedule(
	'send-daily-mission-push-et',
	'5 * * * *',
	$job$
	with et_now as (
		select now() at time zone 'America/New_York' as value
	),
	gate as (
		select
			case
				when value::time < time '08:00' then (value::date - 1)
				else value::date
			end as mission_date,
			extract(hour from value)::int as et_hour
		from et_now
	)
	select net.http_post(
		url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-daily-mission-push',
		headers := jsonb_build_object(
			'Content-Type', 'application/json',
			'x-push-webhook-secret', (
				select webhook_secret
				from public.family_push_runtime_config
				where id = true
			)
		),
		body := jsonb_build_object(
			'type', 'daily_missions',
			'family_id', 'global',
			'mission_date', to_char(mission_date, 'YYYY-MM-DD')
		)
	)
	from gate
	where et_hour = 8;
	$job$
);
