-- End-to-end stock integrity for route visits, control routes and service work.
-- The enforcement timestamp deliberately separates legacy partial visits from
-- visits completed after this protection was installed.

begin;

create table if not exists public.route_stock_integrity_runtime_v64 (
  singleton boolean primary key default true check (singleton),
  enforced_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.route_stock_integrity_runtime_v64 (singleton)
values (true)
on conflict (singleton) do nothing;

alter table public.route_stock_integrity_runtime_v64 enable row level security;

drop policy if exists route_stock_integrity_runtime_read_v64
  on public.route_stock_integrity_runtime_v64;
create policy route_stock_integrity_runtime_read_v64
  on public.route_stock_integrity_runtime_v64
  for select to authenticated
  using (true);

grant select on public.route_stock_integrity_runtime_v64 to authenticated;

create or replace function public.guard_route_visit_stock_item_v64()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_capacity numeric;
  v_tolerance numeric := 0;
begin
  if new.accepted_at is null
     or new.item_kind not in ('coffee_container', 'food_slot') then
    return new;
  end if;

  if new.item_kind = 'coffee_container' then
    select container.capacity_quantity,
           case
             when coalesce(new.actual_before_quantity, 0) <= container.capacity_quantity * 0.1 + 0.0001
               then coalesce(container.refill_package_quantity, 0)
             else 0
           end
      into v_capacity, v_tolerance
    from public.machine_coffee_containers container
    where container.id = new.coffee_container_id
      and container.machine_id = new.machine_id
      and container.active = true;

    if not found then
      raise exception 'Uložený zásobník nepatří k tomuto automatu nebo už není aktivní.'
        using errcode = '23514';
    end if;

    -- Missing vehicle stock is a valid operational exception. It must not
    -- invent a physical count; it must be explicit, empty and explained.
    if new.final_quantity is null then
      if new.issue_type = 'missing_stock'
         and coalesce(new.actual_add_quantity, 0) = 0
         and length(trim(coalesce(new.operator_note, ''))) >= 10 then
        return new;
      end if;
      raise exception 'Potvrzený zásobník musí mít konečný stav, nebo zdokumentovanou výjimku chybějící zásoby.'
        using errcode = '23514';
    end if;

    if new.actual_before_quantity is null
       or new.capacity_quantity is null
       or new.capacity_quantity <= 0
       or new.final_quantity < 0
       or new.final_quantity > v_capacity + v_tolerance + 0.011
       or abs(
         new.final_quantity
         - (new.actual_before_quantity + coalesce(new.actual_add_quantity, 0) - coalesce(new.removed_quantity, 0))
       ) > 0.011 then
      raise exception 'Uložený stav zásobníku je neúplný nebo nesouhlasí s fyzickou kontrolou a doplněním.'
        using errcode = '23514';
    end if;
  else
    select slot.capacity_units
      into v_capacity
    from public.machine_planogram_slots slot
    where slot.id = new.planogram_slot_id
      and slot.machine_id = new.machine_id
      and slot.active = true;

    if not found then
      raise exception 'Uložená pozice nepatří k tomuto automatu nebo už není aktivní.'
        using errcode = '23514';
    end if;

    if new.actual_before_quantity is null
       or new.final_quantity is null
       or new.capacity_quantity is null
       or new.capacity_quantity <= 0
       or new.final_quantity < 0
       or new.final_quantity > v_capacity + 0.011
       or abs(
         new.final_quantity
         - (new.actual_before_quantity + coalesce(new.actual_add_quantity, 0) - coalesce(new.removed_quantity, 0))
       ) > 0.011 then
      raise exception 'Uložený stav pozice je neúplný nebo nesouhlasí s fyzickou kontrolou, doplněním a odpisem.'
        using errcode = '23514';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists route_visit_stock_item_integrity_v64
  on public.route_machine_visit_items;
create trigger route_visit_stock_item_integrity_v64
before insert or update of accepted_at, final_quantity, actual_before_quantity,
  actual_add_quantity, removed_quantity, capacity_quantity, issue_type,
  operator_note, coffee_container_id, planogram_slot_id, machine_id, item_kind
on public.route_machine_visit_items
for each row
execute function public.guard_route_visit_stock_item_v64();

create or replace function public.guard_route_visit_completion_integrity_v64()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_expected_count integer := 0;
  v_missing_label text;
begin
  if new.status <> 'completed'
     or (tg_op = 'UPDATE' and old.status = 'completed') then
    return new;
  end if;

  if lower(coalesce(new.machine_kind, '')) = 'coffee' then
    select count(*)
      into v_expected_count
    from public.machine_coffee_containers container
    where container.machine_id = new.machine_id
      and container.active = true;

    if v_expected_count = 0 then
      raise exception 'Návštěvu nelze dokončit: kávový automat nemá nastavený aktivní plánogram zásobníků.'
        using errcode = '23514';
    end if;

    select container.container_code
      into v_missing_label
    from public.machine_coffee_containers container
    where container.machine_id = new.machine_id
      and container.active = true
      and not exists (
        select 1
        from public.route_machine_visit_items item
        where item.visit_id = new.id
          and item.machine_id = new.machine_id
          and item.item_kind = 'coffee_container'
          and item.coffee_container_id = container.id
          and item.accepted_at is not null
          and (
            (
              item.final_quantity is not null
              and item.actual_before_quantity is not null
              and item.capacity_quantity is not null
              and item.capacity_quantity > 0
              and item.final_quantity >= 0
              and item.final_quantity <= container.capacity_quantity
                + case
                    when item.actual_before_quantity <= container.capacity_quantity * 0.1 + 0.0001
                      then coalesce(container.refill_package_quantity, 0)
                    else 0
                  end
                + 0.011
              and abs(
                item.final_quantity
                - (item.actual_before_quantity + coalesce(item.actual_add_quantity, 0) - coalesce(item.removed_quantity, 0))
              ) <= 0.011
            )
            or (
              item.final_quantity is null
              and item.issue_type = 'missing_stock'
              and coalesce(item.actual_add_quantity, 0) = 0
              and length(trim(coalesce(item.operator_note, ''))) >= 10
            )
          )
      )
    order by container.sort_order, container.id
    limit 1;

    if v_missing_label is not null then
      raise exception 'Návštěvu nelze dokončit: zásobník % nemá platný potvrzený stav ani popsanou provozní výjimku.', v_missing_label
        using errcode = '23514';
    end if;
  elsif lower(coalesce(new.machine_kind, '')) = 'food' then
    select count(*)
      into v_expected_count
    from public.machine_planogram_slots slot
    where slot.machine_id = new.machine_id
      and slot.active = true;

    if v_expected_count = 0 then
      raise exception 'Návštěvu nelze dokončit: potravinový automat nemá nastavený aktivní plánogram.'
        using errcode = '23514';
    end if;

    select slot.slot_code
      into v_missing_label
    from public.machine_planogram_slots slot
    where slot.machine_id = new.machine_id
      and slot.active = true
      and not exists (
        select 1
        from public.route_machine_visit_items item
        where item.visit_id = new.id
          and item.machine_id = new.machine_id
          and item.item_kind = 'food_slot'
          and item.planogram_slot_id = slot.id
          and item.accepted_at is not null
          and item.actual_before_quantity is not null
          and item.final_quantity is not null
          and item.capacity_quantity is not null
          and item.capacity_quantity > 0
          and item.final_quantity >= 0
          and item.final_quantity <= slot.capacity_units + 0.011
          and abs(
            item.final_quantity
            - (item.actual_before_quantity + coalesce(item.actual_add_quantity, 0) - coalesce(item.removed_quantity, 0))
          ) <= 0.011
      )
    order by slot.sort_order, slot.id
    limit 1;

    if v_missing_label is not null then
      raise exception 'Návštěvu nelze dokončit: pozice % nemá platný potvrzený stav.', v_missing_label
        using errcode = '23514';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists route_machine_visits_completion_integrity_v63
  on public.route_machine_visits;
drop trigger if exists route_machine_visits_completion_insert_v64
  on public.route_machine_visits;
drop trigger if exists route_machine_visits_completion_update_v64
  on public.route_machine_visits;

create trigger route_machine_visits_completion_insert_v64
before insert on public.route_machine_visits
for each row
execute function public.guard_route_visit_completion_integrity_v64();

create trigger route_machine_visits_completion_update_v64
before update of status on public.route_machine_visits
for each row
execute function public.guard_route_visit_completion_integrity_v64();

create or replace function public.apply_control_coffee_observation_v64()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_observed_at timestamptz;
  v_quantity numeric;
  v_depleted_after numeric(14,3) := 0;
  v_container public.machine_coffee_containers%rowtype;
begin
  if new.status <> 'applied'
     or new.adjustment_type <> 'stock'
     or new.target_kind <> 'coffee_container'
     or new.target_record_id is null then
    return new;
  end if;

  v_quantity := nullif(new.after_value ->> 'current_quantity', '')::numeric;
  if v_quantity is null then
    raise exception 'Korekce zásobníku nemá nový fyzický stav.' using errcode = '23514';
  end if;
  v_observed_at := least(coalesce(new.applied_at, new.created_at, now()), now());

  select * into strict v_container
  from public.machine_coffee_containers container
  where container.id = new.target_record_id
    and container.machine_id = new.machine_id
  for update;

  if v_quantity < 0
     or v_quantity > v_container.capacity_quantity + coalesce(v_container.refill_package_quantity, 0) + 0.011 then
    raise exception 'Korekce zásobníku je mimo povolenou kapacitu.' using errcode = '23514';
  end if;

  select coalesce(sum(depletion.quantity), 0)::numeric(14,3)
    into v_depleted_after
  from public.telemetry_coffee_recipe_depletions depletion
  join public.telemetry_sales_events sale on sale.id = depletion.sale_event_id
  where depletion.coffee_container_id = v_container.id
    and sale.source_event_at > v_observed_at;

  update public.machine_coffee_containers container
  set current_quantity = greatest(0, v_quantity - v_depleted_after),
      physical_counted_at = v_observed_at,
      physical_count_source = 'control_route',
      physical_count_visit_item_id = null,
      updated_at = now()
  where container.id = v_container.id;

  insert into public.machine_coffee_container_correction_audit (
    correction_key, coffee_container_id, machine_id, before_quantity,
    after_quantity, capacity_quantity, unit, reason, source, context,
    created_by, created_at
  ) values (
    'v64-control-adjustment-' || new.id,
    v_container.id,
    new.machine_id,
    coalesce(nullif(new.before_value ->> 'current_quantity', '')::numeric, v_container.current_quantity),
    greatest(0, v_quantity - v_depleted_after),
    v_container.capacity_quantity,
    v_container.unit,
    coalesce(nullif(trim(new.note), ''), 'Fyzická korekce v kontrolní trase.'),
    'control_route',
    jsonb_build_object(
      'control_adjustment_id', new.id,
      'observed_quantity', v_quantity,
      'telemetry_used_after_observation', v_depleted_after
    ),
    new.created_by,
    now()
  )
  on conflict (correction_key) do nothing;

  return new;
end
$$;

drop trigger if exists control_coffee_observation_v64
  on public.control_machine_adjustments;
create trigger control_coffee_observation_v64
after insert or update of status, after_value, applied_at
on public.control_machine_adjustments
for each row
execute function public.apply_control_coffee_observation_v64();

create or replace function public.apply_service_coffee_observation_v64()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_observed_at timestamptz := least(coalesce(new.created_at, now()), now());
  v_depleted_after numeric(14,3) := 0;
  v_container public.machine_coffee_containers%rowtype;
begin
  select * into strict v_container
  from public.machine_coffee_containers container
  where container.id = new.coffee_container_id
    and container.machine_id = new.machine_id
  for update;

  select coalesce(sum(depletion.quantity), 0)::numeric(14,3)
    into v_depleted_after
  from public.telemetry_coffee_recipe_depletions depletion
  join public.telemetry_sales_events sale on sale.id = depletion.sale_event_id
  where depletion.coffee_container_id = v_container.id
    and sale.source_event_at > v_observed_at;

  update public.machine_coffee_containers container
  set current_quantity = greatest(0, new.final_quantity - v_depleted_after),
      physical_counted_at = v_observed_at,
      physical_count_source = 'technician_service',
      physical_count_visit_item_id = null,
      updated_at = now()
  where container.id = v_container.id;

  insert into public.machine_coffee_container_correction_audit (
    correction_key, coffee_container_id, machine_id, before_quantity,
    after_quantity, capacity_quantity, unit, reason, source, context,
    created_by, created_at
  ) values (
    'v64-service-action-' || new.id,
    v_container.id,
    new.machine_id,
    new.system_quantity,
    greatest(0, new.final_quantity - v_depleted_after),
    new.capacity_quantity,
    new.unit,
    coalesce(nullif(trim(new.note), ''), 'Fyzický stav zapsaný technikem při servisu.'),
    'technician_service',
    jsonb_build_object(
      'service_request_container_action_id', new.id,
      'service_request_id', new.service_request_id,
      'observed_quantity', new.final_quantity,
      'telemetry_used_after_observation', v_depleted_after
    ),
    new.employee_id,
    now()
  )
  on conflict (correction_key) do nothing;

  return new;
end
$$;

drop trigger if exists service_coffee_observation_v64
  on public.service_request_container_actions;
create trigger service_coffee_observation_v64
after insert on public.service_request_container_actions
for each row
execute function public.apply_service_coffee_observation_v64();

create or replace function public.get_route_stock_integrity_issues_v64()
returns table (
  severity text,
  issue_type text,
  title text,
  detail text,
  href text,
  confidence integer,
  machine_id bigint,
  visit_id bigint,
  detected_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with runtime as (
    select enforced_at
    from public.route_stock_integrity_runtime_v64
    where singleton = true
  ), completion_gaps as (
    select
      'critical'::text as severity,
      'route_stock_incomplete'::text as issue_type,
      format('EV %s: dokončená návštěva nemá všechny stavy', machine.evidence_number)::text as title,
      format('Návštěva %s z %s byla dokončena bez platného zápisu pro všechny aktivní pozice nebo zásobníky.', visit.id, to_char(visit.visit_date, 'DD.MM.YYYY'))::text as detail,
      ('routes-detail.html?id=' || visit.route_plan_id)::text as href,
      100::integer as confidence,
      visit.machine_id,
      visit.id as visit_id,
      visit.completed_at as detected_at
    from public.route_machine_visits visit
    join public.machines machine on machine.id = visit.machine_id
    cross join runtime
    where visit.status = 'completed'
      and visit.completed_at >= runtime.enforced_at
      and (
        (lower(coalesce(visit.machine_kind, '')) = 'coffee' and exists (
          select 1
          from public.machine_coffee_containers container
          where container.machine_id = visit.machine_id
            and container.active = true
            and not exists (
              select 1 from public.route_machine_visit_items item
              where item.visit_id = visit.id
                and item.machine_id = visit.machine_id
                and item.item_kind = 'coffee_container'
                and item.coffee_container_id = container.id
                and item.accepted_at is not null
            )
        ))
        or
        (lower(coalesce(visit.machine_kind, '')) = 'food' and exists (
          select 1
          from public.machine_planogram_slots slot
          where slot.machine_id = visit.machine_id
            and slot.active = true
            and not exists (
              select 1 from public.route_machine_visit_items item
              where item.visit_id = visit.id
                and item.machine_id = visit.machine_id
                and item.item_kind = 'food_slot'
                and item.planogram_slot_id = slot.id
                and item.accepted_at is not null
            )
        ))
      )
  ), invalid_balances as (
    select
      'critical'::text,
      'coffee_stock_out_of_bounds'::text,
      format('EV %s: stav zásobníku je mimo kapacitu', machine.evidence_number)::text,
      format('%s (%s): %s %s z kapacity %s %s.', container.product_name, container.container_code, container.current_quantity, container.unit, container.capacity_quantity, container.unit)::text,
      ('machines.html?machine=' || machine.id)::text,
      100::integer,
      machine.id,
      null::bigint,
      container.updated_at
    from public.machine_coffee_containers container
    join public.machines machine on machine.id = container.machine_id and machine.active = true
    where container.active = true
      and (
        container.current_quantity < 0
        or container.current_quantity > container.capacity_quantity + coalesce(container.refill_package_quantity, 0) + 0.011
      )
    union all
    select
      'critical'::text,
      'food_stock_out_of_bounds'::text,
      format('EV %s: stav pozice je mimo kapacitu', machine.evidence_number)::text,
      format('%s (%s): %s ks z kapacity %s ks.', slot.product_name, slot.slot_code, slot.current_units, slot.capacity_units)::text,
      ('machines.html?machine=' || machine.id)::text,
      100::integer,
      machine.id,
      null::bigint,
      slot.updated_at
    from public.machine_planogram_slots slot
    join public.machines machine on machine.id = slot.machine_id and machine.active = true
    where slot.active = true
      and (slot.current_units < 0 or slot.current_units > slot.capacity_units)
  ), documented_exceptions as (
    select
      'warning'::text,
      'route_stock_missing_on_vehicle'::text,
      format('EV %s: zásoba nebyla doplněna', machine.evidence_number)::text,
      format('%s (%s): %s', item.planned_product_name, item.physical_position_label, item.operator_note)::text,
      ('routes-detail.html?id=' || visit.route_plan_id)::text,
      100::integer,
      visit.machine_id,
      visit.id,
      item.accepted_at
    from public.route_machine_visit_items item
    join public.route_machine_visits visit on visit.id = item.visit_id
    join public.machines machine on machine.id = visit.machine_id
    where item.item_kind = 'coffee_container'
      and item.accepted_at >= now() - interval '7 days'
      and item.final_quantity is null
      and item.issue_type = 'missing_stock'
      and coalesce(item.actual_add_quantity, 0) = 0
      and length(trim(coalesce(item.operator_note, ''))) >= 10
  )
  select * from completion_gaps
  union all select * from invalid_balances
  union all select * from documented_exceptions
  order by detected_at desc nulls last;
$$;

revoke all on function public.get_route_stock_integrity_issues_v64() from public, anon;
grant execute on function public.get_route_stock_integrity_issues_v64() to authenticated, service_role;

create or replace function public.get_ai_dispatcher_alerts_v64()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with issues as (
    select *
    from public.get_route_stock_integrity_issues_v64()
    order by detected_at desc nulls last
    limit 50
  )
  select jsonb_build_object(
    'status', case when exists(select 1 from issues where severity = 'critical') then 'critical'
                   when exists(select 1 from issues) then 'warning'
                   else 'healthy' end,
    'generated_at', now(),
    'critical_count', (select count(*) from issues where severity = 'critical'),
    'warning_count', (select count(*) from issues where severity = 'warning'),
    'alerts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'severity', severity,
        'type', issue_type,
        'title', title,
        'detail', detail,
        'href', href,
        'confidence', confidence,
        'machine_id', machine_id,
        'visit_id', visit_id,
        'detected_at', detected_at
      ) order by detected_at desc nulls last)
      from issues
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_ai_dispatcher_alerts_v64() from public, anon;
grant execute on function public.get_ai_dispatcher_alerts_v64() to authenticated, service_role;

commit;

notify pgrst, 'reload schema';
