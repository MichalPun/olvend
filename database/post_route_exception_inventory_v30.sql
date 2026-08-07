begin;

alter table public.inventory_audits
  add column if not exists source_route_plan_id bigint references public.route_plans (id) on delete set null,
  add column if not exists audit_origin text not null default 'manual';

create unique index if not exists inventory_audits_source_route_plan_unique_idx
  on public.inventory_audits (source_route_plan_id)
  where source_route_plan_id is not null;

create or replace function public.ensure_post_route_exception_inventory_v30(p_route_plan_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.route_plans%rowtype;
  v_stock_location_id bigint;
  v_existing_audit_id bigint;
  v_audit_id bigint;
  v_item_count integer;
  v_book_total numeric(14,3);
begin
  perform pg_advisory_xact_lock(hashtextextended('post-route-exception-inventory:' || p_route_plan_id::text, 0));

  select * into v_plan from public.route_plans where id = p_route_plan_id;
  if not found then
    return jsonb_build_object('created', false, 'reason', 'route_not_found');
  end if;

  select id into v_existing_audit_id
  from public.inventory_audits
  where source_route_plan_id = p_route_plan_id
  limit 1;
  if v_existing_audit_id is not null then
    return jsonb_build_object('created', false, 'reason', 'already_exists', 'audit_id', v_existing_audit_id);
  end if;

  if v_plan.execution_status <> 'done' then
    return jsonb_build_object('created', false, 'reason', 'route_not_completed');
  end if;
  if v_plan.vehicle_id is null or v_plan.planned_employee_id is null then
    return jsonb_build_object('created', false, 'reason', 'missing_vehicle_or_employee');
  end if;
  if not exists (select 1 from public.route_plan_stops where route_plan_id = p_route_plan_id)
     or exists (
       select 1 from public.route_plan_stops
       where route_plan_id = p_route_plan_id and status not in ('done', 'skipped')
     ) then
    return jsonb_build_object('created', false, 'reason', 'open_stops');
  end if;

  select id into v_stock_location_id
  from public.stock_locations
  where location_type = 'vehicle'
    and vehicle_id = v_plan.vehicle_id
    and active = true
  order by id
  limit 1;
  if v_stock_location_id is null then
    return jsonb_build_object('created', false, 'reason', 'vehicle_stock_location_missing');
  end if;

  with vehicle_balances as (
    select product_id, sum(quantity_on_hand)::numeric(14,3) as vehicle_quantity
    from public.stock_location_balances
    where stock_location_id = v_stock_location_id
    group by product_id
  ), missed_products as (
    select coalesce(item.actual_product_id, item.planned_product_id) as product_id
    from public.route_machine_visits visit
    join public.route_machine_visit_items item on item.visit_id = visit.id
    where visit.route_plan_id = p_route_plan_id
      and visit.status = 'completed'
      and item.accepted_at is not null
      and item.item_kind in ('food_slot', 'coffee_container')
      and coalesce(item.actual_add_quantity, 0) <= 0.0001
      and coalesce(item.final_quantity, 0) <= 0.0001
      and coalesce(item.actual_product_id, item.planned_product_id) is not null
    group by coalesce(item.actual_product_id, item.planned_product_id)
  ), candidates as (
    select balance.product_id, balance.vehicle_quantity
    from missed_products missed
    join vehicle_balances balance on balance.product_id = missed.product_id
    where balance.vehicle_quantity > 0.0001
  )
  select count(*), coalesce(sum(vehicle_quantity), 0)
    into v_item_count, v_book_total
  from candidates;

  if v_item_count = 0 then
    return jsonb_build_object('created', false, 'reason', 'no_suspicious_products');
  end if;

  insert into public.inventory_audits (
    audit_date, scope_type, stock_location_id, vehicle_id, assigned_employee_id,
    responsible_name, note, status, book_quantity_total, counted_quantity_total,
    difference_quantity_total, difference_value_total, created_by,
    source_route_plan_id, audit_origin
  ) values (
    coalesce(v_plan.planning_date, current_date),
    'vehicle', v_stock_location_id, v_plan.vehicle_id, v_plan.planned_employee_id,
    null,
    'Cílená kontrola po trase #' || p_route_plan_id || ': automat po návštěvě zůstal na 0, nebylo doplněno a stejné zboží je podle evidence stále ve vozidle. Počítají se pouze vypsané podezřelé položky.',
    'assigned', v_book_total, 0, 0, 0, null,
    p_route_plan_id, 'post_route_exception'
  )
  returning id into v_audit_id;

  with vehicle_balances as (
    select product_id, sum(quantity_on_hand)::numeric(14,3) as vehicle_quantity
    from public.stock_location_balances
    where stock_location_id = v_stock_location_id
    group by product_id
  ), missed_products as (
    select
      coalesce(item.actual_product_id, item.planned_product_id) as product_id,
      string_agg(
        distinct concat_ws(' · ',
          coalesce(machine.name, 'Automat ' || visit.machine_id::text),
          'pozice ' || coalesce(item.physical_position_label, '?'),
          'stav 0, doplněno 0'
        ),
        ' / '
      ) as reason_note
    from public.route_machine_visits visit
    join public.route_machine_visit_items item on item.visit_id = visit.id
    left join public.machines machine on machine.id = visit.machine_id
    where visit.route_plan_id = p_route_plan_id
      and visit.status = 'completed'
      and item.accepted_at is not null
      and item.item_kind in ('food_slot', 'coffee_container')
      and coalesce(item.actual_add_quantity, 0) <= 0.0001
      and coalesce(item.final_quantity, 0) <= 0.0001
      and coalesce(item.actual_product_id, item.planned_product_id) is not null
    group by coalesce(item.actual_product_id, item.planned_product_id)
  )
  insert into public.inventory_audit_items (
    audit_id, stock_location_id, product_id, batch_id, book_quantity,
    counted_quantity, difference_quantity, unit_cost, difference_value, note
  )
  select
    v_audit_id, v_stock_location_id, missed.product_id, null,
    balance.vehicle_quantity, 0, 0, null, 0,
    'Kontrola po trase: ' || missed.reason_note
  from missed_products missed
  join vehicle_balances balance on balance.product_id = missed.product_id
  where balance.vehicle_quantity > 0.0001
  order by missed.product_id;

  return jsonb_build_object(
    'created', true,
    'audit_id', v_audit_id,
    'item_count', v_item_count,
    'book_quantity_total', v_book_total
  );
end
$$;

create or replace function public.create_post_route_exception_inventory_v30()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_post_route_exception_inventory_v30(new.id);
  return new;
end
$$;

drop trigger if exists trg_post_route_exception_inventory_v30 on public.route_plans;
create trigger trg_post_route_exception_inventory_v30
after update of execution_status, completed_at on public.route_plans
for each row
when (new.execution_status = 'done' and old.execution_status is distinct from new.execution_status)
execute function public.create_post_route_exception_inventory_v30();

grant execute on function public.ensure_post_route_exception_inventory_v30(bigint) to anon, authenticated;

commit;
