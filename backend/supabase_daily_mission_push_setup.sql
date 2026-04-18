select cron.schedule(
	'send-daily-mission-push',
	'0 15 * * *',
	$$
	select net.http_post(
		url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-daily-mission-push',
		headers := jsonb_build_object(
			'Content-Type', 'application/json',
			'x-push-webhook-secret', 'YOUR_PUSH_WEBHOOK_SECRET'
		),
		body := jsonb_build_object(
			'type', 'daily_missions',
			'family_id', 'global'
		)
	);
	$$
);
