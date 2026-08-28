begin;

create table if not exists public.operator_territory_settings (
  id boolean primary key default true check (id),
  territory_strength text not null default 'strong' check (territory_strength in ('strong','balanced','soft')),
  history_fallback_days integer not null default 90 check (history_fallback_days between 14 and 365),
  balance_employee_km boolean not null default true,
  keep_locations_together boolean not null default true,
  manager_default_reserve boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

insert into public.operator_territory_settings (id) values (true) on conflict (id) do nothing;
alter table public.operator_territory_settings enable row level security;
drop policy if exists operator_territory_settings_read on public.operator_territory_settings;
create policy operator_territory_settings_read on public.operator_territory_settings for select to authenticated using (true);
drop policy if exists operator_territory_settings_manage on public.operator_territory_settings;
create policy operator_territory_settings_manage on public.operator_territory_settings for all to authenticated
using (public.has_manager_access()) with check (public.has_manager_access());
grant select on public.operator_territory_settings to authenticated;

create or replace function public.save_operator_territory_settings(
  p_territory_strength text,
  p_history_fallback_days integer,
  p_balance_employee_km boolean,
  p_keep_locations_together boolean,
  p_manager_default_reserve boolean
) returns public.operator_territory_settings
language plpgsql security definer set search_path=public
as $$
declare v_row public.operator_territory_settings;
begin
  if not public.has_manager_access() then raise exception 'Pravidla může měnit pouze manažer.' using errcode='42501'; end if;
  insert into public.operator_territory_settings(id,territory_strength,history_fallback_days,balance_employee_km,keep_locations_together,manager_default_reserve,updated_at,updated_by)
  values(true,p_territory_strength,p_history_fallback_days,p_balance_employee_km,p_keep_locations_together,p_manager_default_reserve,now(),auth.uid())
  on conflict(id) do update set territory_strength=excluded.territory_strength,history_fallback_days=excluded.history_fallback_days,balance_employee_km=excluded.balance_employee_km,keep_locations_together=excluded.keep_locations_together,manager_default_reserve=excluded.manager_default_reserve,updated_at=now(),updated_by=auth.uid()
  returning * into v_row;
  return v_row;
end $$;
grant execute on function public.save_operator_territory_settings(text,integer,boolean,boolean,boolean) to authenticated;

commit;
