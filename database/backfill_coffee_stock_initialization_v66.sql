-- Backfill the new machine.stock_initialized_at marker from complete historical
-- first-calibration records. The v65 completion guard relies on this marker,
-- but older fully calibrated machines predate the column.

begin;

create table if not exists public.coffee_stock_initialization_backfill_v66_audit (
  machine_id bigint primary key references public.machines(id),
  evidence_number integer,
  previous_stock_initialized_at timestamptz,
  derived_stock_initialized_at timestamptz not null,
  active_container_count integer not null,
  calibrated_container_count integer not null,
  applied_at timestamptz not null default now()
);

with active_container_counts as (
  select machine_id, count(*)::integer as active_count
  from public.machine_coffee_containers
  where active = true
  group by machine_id
), calibrated_container_counts as (
  select
    container.machine_id,
    count(distinct container.id)::integer as calibrated_count,
    max(item.accepted_at) as initialized_at
  from public.machine_coffee_containers container
  join public.route_machine_visit_items item
    on item.coffee_container_id = container.id
   and item.machine_id = container.machine_id
   and item.item_kind = 'coffee_container'
   and item.accepted_at is not null
   and item.actual_before_quantity is not null
   and item.final_quantity is not null
   and item.operator_note ilike '%První kalibrace zásobníku%'
  where container.active = true
  group by container.machine_id
), eligible as (
  select
    machine.id as machine_id,
    machine.evidence_number,
    machine.stock_initialized_at,
    calibrated.initialized_at,
    active.active_count,
    calibrated.calibrated_count
  from public.machines machine
  join active_container_counts active on active.machine_id = machine.id
  join calibrated_container_counts calibrated
    on calibrated.machine_id = machine.id
   and calibrated.calibrated_count = active.active_count
  where machine.stock_initialized_at is null
)
insert into public.coffee_stock_initialization_backfill_v66_audit (
  machine_id,
  evidence_number,
  previous_stock_initialized_at,
  derived_stock_initialized_at,
  active_container_count,
  calibrated_container_count
)
select
  machine_id,
  evidence_number,
  stock_initialized_at,
  initialized_at,
  active_count,
  calibrated_count
from eligible
on conflict (machine_id) do nothing;

update public.machines machine
set stock_initialized_at = audit.derived_stock_initialized_at,
    updated_at = now()
from public.coffee_stock_initialization_backfill_v66_audit audit
where audit.machine_id = machine.id
  and machine.stock_initialized_at is null;

do $$
begin
  if exists (
    select 1
    from public.coffee_stock_initialization_backfill_v66_audit audit
    join public.machines machine on machine.id = audit.machine_id
    where machine.stock_initialized_at is null
       or machine.stock_initialized_at is distinct from audit.derived_stock_initialized_at
  ) then
    raise exception 'Coffee stock initialization v66 backfill did not persist all audited machines.';
  end if;
end $$;

commit;
notify pgrst, 'reload schema';
