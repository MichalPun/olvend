with visit_containers as (
  select
    v.id visit_id,
    v.visit_date,
    v.completed_at,
    v.machine_id,
    v.vehicle_id,
    machine.evidence_number,
    location.name location_name,
    concat_ws(' ', employee.name, employee.surname) operator_name,
    c.id container_id,
    c.container_code,
    c.product_id,
    c.capacity_quantity,
    c.refill_package_quantity,
    c.unit,
    entry.value draft,
    nullif(entry.value->>'actualBeforeQuantity', '')::numeric actual_before,
    coalesce(nullif(entry.value->>'packages', '')::numeric, 0) packages,
    coalesce(nullif(entry.value->>'movedPackages', '')::numeric, 0) moved_packages,
    coalesce((entry.value->>'accepted')::boolean, false) accepted
  from public.route_machine_visits v
  cross join lateral jsonb_each(coalesce(v.coffee_preparation->'containers', '{}'::jsonb)) entry
  join public.machine_coffee_containers c on c.id = entry.key::bigint
  join public.machines machine on machine.id=v.machine_id
  left join public.locations location on location.id=machine.location_id
  left join public.employees employee on employee.id=v.employee_id
  where v.status = 'completed'
    and v.machine_kind = 'coffee'
    and v.visit_date between date '2026-10-01' and date '2026-10-14'
), audited as (
  select
    vc.*,
    item.id visit_item_id,
    item.actual_before_quantity item_actual_before,
    item.actual_add_quantity item_actual_add,
    coalesce(movement.net_quantity, 0) net_movement
  from visit_containers vc
  left join lateral (
    select i.*
    from public.route_machine_visit_items i
    where i.visit_id = vc.visit_id
      and i.coffee_container_id = vc.container_id
      and i.item_kind = 'coffee_container'
    order by i.id desc
    limit 1
  ) item on true
  left join lateral (
    select sum(case
      when m.to_stock_location_id = machine_location.id then m.quantity_base_units
      when m.from_stock_location_id = machine_location.id then -m.quantity_base_units
      else 0
    end) net_quantity
    from public.stock_movements_v13 m
    join public.stock_locations machine_location
      on machine_location.location_type = 'machine'
     and machine_location.machine_id = vc.machine_id
    where m.reference_type = 'mobile_stock_request'
      and m.reference_id like format('route_visit_%s_container_%s_%%', vc.visit_id, vc.container_id)
      and m.product_id = vc.product_id
  ) movement on true
), classified as (
  select *, case
    when visit_item_id is not null and not accepted then 'item_saved_accept_false'
    when visit_item_id is null and net_movement > 0
      and actual_before is not null
      and (packages = 0 or actual_before + refill_package_quantity > capacity_quantity + 0.0001)
      then 'missing_item_proven_no_fill'
    when visit_item_id is null and net_movement > 0 and packages = 0
      then 'movement_packages_zero_no_physical_reading'
    when visit_item_id is null and net_movement > 0
      then 'missing_item_ambiguous'
    when visit_item_id is null and net_movement = 0 and accepted
      then 'accepted_without_item_no_movement'
    else 'consistent_or_irrelevant'
  end category
  from audited
)
select jsonb_build_object(
  'counts', (
    select jsonb_object_agg(category, row_count order by category)
    from (select category, count(*) row_count from classified group by category) counts
  ),
  'proven_no_fill', (
    select jsonb_agg(jsonb_build_object(
      'visit', visit_id, 'date', visit_date, 'machine', machine_id,
      'container', container_id, 'code', container_code,
      'actual_before', actual_before, 'capacity', capacity_quantity,
      'package', refill_package_quantity, 'packages', packages,
      'moved_packages', moved_packages, 'net_movement', net_movement
    ) order by visit_date, visit_id, container_id)
    from classified where category = 'missing_item_proven_no_fill'
  ),
  'ambiguous_count', (select count(*) from classified where category = 'missing_item_ambiguous'),
  'ambiguous', (
    select jsonb_agg(jsonb_build_object(
      'visit',visit_id,'date',visit_date,'ev',evidence_number,
      'location',location_name,'operator',operator_name,
      'container',container_id,'code',container_code,
      'packages',packages,'moved_packages',moved_packages,
      'net_movement',net_movement
    ) order by visit_date,visit_id,container_id)
    from classified where category='missing_item_ambiguous'
  )
) as audit;

