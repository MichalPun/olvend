-- Lock down one-off repair rollback evidence created after the global RLS
-- boundary was introduced. These tables are for direct DBA recovery only and
-- are not part of the browser or mobile application API.

begin;

alter table public.repair_ev104_visit1297_audit_20261015 enable row level security;
alter table public.repair_ev78_rohliq_planogram_audit_20261016 enable row level security;
alter table public.repair_ev78_rohliq_slot44_havlik_audit_20261016 enable row level security;

revoke all on table public.repair_ev104_visit1297_audit_20261015
  from public, anon, authenticated;
revoke all on table public.repair_ev78_rohliq_planogram_audit_20261016
  from public, anon, authenticated;
revoke all on table public.repair_ev78_rohliq_slot44_havlik_audit_20261016
  from public, anon, authenticated;

comment on table public.repair_ev104_visit1297_audit_20261015 is
  'Internal rollback evidence for the EV 104 visit 1297 repair; inaccessible to client roles.';
comment on table public.repair_ev78_rohliq_planogram_audit_20261016 is
  'Internal rollback evidence for the EV 78 Rohlík planogram repair; inaccessible to client roles.';
comment on table public.repair_ev78_rohliq_slot44_havlik_audit_20261016 is
  'Internal rollback evidence for the EV 78 Rohlík slot 44 repair; inaccessible to client roles.';

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'repair_ev104_visit1297_audit_20261015',
    'repair_ev78_rohliq_planogram_audit_20261016',
    'repair_ev78_rohliq_slot44_havlik_audit_20261016'
  ] loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = v_table
        and c.relrowsecurity
    ) then
      raise exception 'RLS was not enabled on public.%', v_table;
    end if;

    if has_table_privilege('anon', format('public.%I', v_table), 'SELECT')
       or has_table_privilege('anon', format('public.%I', v_table), 'INSERT')
       or has_table_privilege('anon', format('public.%I', v_table), 'UPDATE')
       or has_table_privilege('anon', format('public.%I', v_table), 'DELETE')
       or has_table_privilege('authenticated', format('public.%I', v_table), 'SELECT')
       or has_table_privilege('authenticated', format('public.%I', v_table), 'INSERT')
       or has_table_privilege('authenticated', format('public.%I', v_table), 'UPDATE')
       or has_table_privilege('authenticated', format('public.%I', v_table), 'DELETE') then
      raise exception 'Client privileges remain on public.%', v_table;
    end if;
  end loop;
end
$$;

notify pgrst, 'reload schema';

commit;
