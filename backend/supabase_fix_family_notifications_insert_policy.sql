alter table public.family_notifications enable row level security;

drop policy if exists "family_notifications_insert" on public.family_notifications;
create policy "family_notifications_insert"
on public.family_notifications
for insert
with check (true);
