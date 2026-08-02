begin;

alter table public.machine_planogram_slots
  add column if not exists pending_change_mode text not null default 'sell_through';

alter table public.machine_planogram_slots
  drop constraint if exists machine_planogram_slots_pending_change_mode_check;

alter table public.machine_planogram_slots
  add constraint machine_planogram_slots_pending_change_mode_check
  check (pending_change_mode in ('sell_through', 'full_swap'));

comment on column public.machine_planogram_slots.pending_change_mode is
  'sell_through keeps old units in front of the replacement; full_swap returns old units to the vehicle and activates the new product immediately.';

do $$
declare
  v_route_count integer;
  v_changed integer;
begin
  select count(*) into v_route_count
  from public.route_plans
  where planning_date = date '2026-08-03'
    and execution_status not in ('done', 'cancelled');

  if v_route_count = 0 then
    raise exception 'No active routes exist for 2026-08-03; full assortment swap was not scheduled.';
  end if;

  with tomorrow_machines as (
    select distinct m.id
    from public.route_plans rp
    join public.route_plan_stops rps on rps.route_plan_id = rp.id
    join public.machines m
      on m.id = rps.machine_id
      or (rps.machine_id is null and m.location_id = rps.location_id)
    where rp.planning_date = date '2026-08-03'
      and rp.execution_status not in ('done', 'cancelled')
  )
  update public.machine_planogram_slots slot
  set pending_change_mode = 'full_swap',
      pending_change_effective_date = coalesce(slot.pending_change_effective_date, date '2026-08-03'),
      pending_change_note = concat_ws(
        ' · ',
        nullif(trim(slot.pending_change_note), ''),
        'Kompletní výměna 3. 8. 2026: starý sortiment stáhnout do vozidla, nový aktivovat ihned'
      ),
      updated_at = now()
  from tomorrow_machines tm
  where slot.machine_id = tm.id
    and slot.active is true
    and (
      nullif(trim(slot.pending_product_sku), '') is not null
      or (
        nullif(trim(slot.planned_product_sku), '') is not null
        and nullif(trim(slot.planned_product_sku), '') is distinct from nullif(trim(slot.product_sku), '')
      )
    );

  get diagnostics v_changed = row_count;
  if v_changed = 0 then
    raise exception 'No pending assortment changes were found on routes for 2026-08-03.';
  end if;

  raise notice 'Scheduled % planogram slots for full assortment swap on 2026-08-03.', v_changed;
end
$$;

commit;

notify pgrst, 'reload schema';
