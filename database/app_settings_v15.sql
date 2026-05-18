create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create or replace function public.set_app_settings_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_app_settings_updated_at on public.app_settings;
create trigger trg_app_settings_updated_at
before update on public.app_settings
for each row
execute function public.set_app_settings_updated_at();

alter table public.app_settings enable row level security;

drop policy if exists "Allow read app settings" on public.app_settings;
create policy "Allow read app settings"
on public.app_settings
for select
to authenticated, anon
using (true);

drop policy if exists "Allow insert app settings" on public.app_settings;
create policy "Allow insert app settings"
on public.app_settings
for insert
to authenticated, anon
with check (true);

drop policy if exists "Allow update app settings" on public.app_settings;
create policy "Allow update app settings"
on public.app_settings
for update
to authenticated, anon
using (true)
with check (true);
