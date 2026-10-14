begin;

-- A saved physical item is authoritative even when the old mobile draft kept
-- accepted=false. This pass intentionally does not require a vehicle stock
-- location, because two legacy visits were completed without one.
do $$
declare
  v_row record;
begin
  for v_row in
    select visit.id visit_id, item.coffee_container_id container_id
    from public.route_machine_visits visit
    join public.route_machine_visit_items item on item.visit_id=visit.id
    where visit.status='completed'
      and visit.machine_kind='coffee'
      and visit.visit_date between date '2026-10-01' and date '2026-10-14'
      and item.item_kind='coffee_container'
      and item.coffee_container_id is not null
      and not coalesce((visit.coffee_preparation->'containers'->(item.coffee_container_id::text)->>'accepted')::boolean,false)
  loop
    update public.route_machine_visits
    set coffee_preparation=jsonb_set(
          coalesce(coffee_preparation,'{}'::jsonb),
          array['containers',v_row.container_id::text,'accepted'],
          'true'::jsonb,true),
        synced_at=now()
    where id=v_row.visit_id;
  end loop;
end
$$;

create temporary table recent_coffee_audit on commit drop as
with visit_containers as (
  select
    v.id visit_id,
    v.visit_date,
    v.completed_at,
    v.machine_id,
    v.vehicle_id,
    machine_location.id machine_location_id,
    vehicle_location.id vehicle_location_id,
    c.id container_id,
    c.container_code,
    c.product_id,
    p.sku product_sku,
    p.name product_name,
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
  join public.products p on p.id = c.product_id
  join public.stock_locations machine_location
    on machine_location.location_type = 'machine'
   and machine_location.machine_id = v.machine_id
  join public.stock_locations vehicle_location
    on vehicle_location.location_type = 'vehicle'
   and vehicle_location.vehicle_id = v.vehicle_id
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
      when m.to_stock_location_id = vc.machine_location_id then m.quantity_base_units
      when m.from_stock_location_id = vc.machine_location_id then -m.quantity_base_units
      else 0
    end) net_quantity
    from public.stock_movements_v13 m
    where m.reference_type = 'mobile_stock_request'
      and m.reference_id like format('route_visit_%s_container_%s_%%', vc.visit_id, vc.container_id)
      and m.product_id = vc.product_id
  ) movement on true
)
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
  else 'consistent_or_irrelevant'
end category
from audited;

do $$
declare
  v_row record;
  v_batch record;
  v_reference text;
begin
  -- A physical visit item is the source of truth. Only repair the stale draft flag.
  for v_row in
    select * from recent_coffee_audit
    where category = 'item_saved_accept_false'
    order by visit_id, container_id
  loop
    update public.route_machine_visits
    set coffee_preparation = jsonb_set(
          coalesce(coffee_preparation, '{}'::jsonb),
          array['containers', v_row.container_id::text, 'accepted'],
          'true'::jsonb,
          true
        ),
        synced_at = now()
    where id = v_row.visit_id;
  end loop;

  -- Exact physical reading proves that the stale vehicle-to-machine movement was not poured in.
  for v_row in
    select * from recent_coffee_audit
    where category = 'missing_item_proven_no_fill'
    order by visit_id, container_id
  loop
    for v_batch in
      select
        m.batch_id,
        sum(case
          when m.to_stock_location_id = v_row.machine_location_id then m.quantity_base_units
          when m.from_stock_location_id = v_row.machine_location_id then -m.quantity_base_units
          else 0
        end) net_quantity
      from public.stock_movements_v13 m
      where m.reference_type = 'mobile_stock_request'
        and m.reference_id like format('route_visit_%s_container_%s_%%', v_row.visit_id, v_row.container_id)
        and m.product_id = v_row.product_id
      group by m.batch_id
      having sum(case
        when m.to_stock_location_id = v_row.machine_location_id then m.quantity_base_units
        when m.from_stock_location_id = v_row.machine_location_id then -m.quantity_base_units
        else 0
      end) > 0.0001
    loop
      v_reference := format(
        'route_visit_%s_container_%s_audit_back_%s_20261014',
        v_row.visit_id,
        v_row.container_id,
        coalesce(v_batch.batch_id::text, 'none')
      );

      if not exists (
        select 1 from public.stock_movements_v13
        where reference_type = 'mobile_stock_request'
          and reference_id = v_reference
      ) then
        perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
          'product_id', v_row.product_id,
          'batch_id', v_batch.batch_id,
          'from_stock_location_id', v_row.machine_location_id,
          'to_stock_location_id', v_row.vehicle_location_id,
          'movement_type', 'return',
          'quantity_base_units', v_batch.net_quantity,
          'reference_type', 'mobile_stock_request',
          'reference_id', v_reference,
          'note', format(
            'Systemova revize 14. 10. 2026 · navsteva #%s · %s: fyzicky stav %s %s, doplneni 0; chybny pohyb vracen do vozidla',
            v_row.visit_id, v_row.container_code, v_row.actual_before, v_row.unit
          )
        )));
      end if;
    end loop;

    insert into public.route_machine_visit_items (
      visit_id, client_uuid, machine_id, item_kind, coffee_container_id,
      physical_position_label,
      planned_product_id, planned_product_sku, planned_product_name,
      actual_product_id, actual_product_sku, actual_product_name,
      system_current_quantity, actual_before_quantity,
      suggested_add_quantity, actual_add_quantity, removed_quantity,
      final_quantity, capacity_quantity, unit,
      issue_type, operator_note, accepted_at
    ) values (
      v_row.visit_id,
      md5(format('recent-coffee-audit:%s:%s', v_row.visit_id, v_row.container_id))::uuid,
      v_row.machine_id, 'coffee_container', v_row.container_id,
      v_row.container_code,
      v_row.product_id, v_row.product_sku, v_row.product_name,
      v_row.product_id, v_row.product_sku, v_row.product_name,
      null, v_row.actual_before,
      v_row.packages * v_row.refill_package_quantity, 0, 0,
      v_row.actual_before, v_row.capacity_quantity, v_row.unit,
      'telemetry_mismatch',
      format(
        'Systemova revize 14. 10. 2026: ulozeny fyzicky stav %s %s dokazuje nulove doplneni; aplikace presto ponechala skladovy pohyb bez navstevni polozky.',
        v_row.actual_before, v_row.unit
      ),
      v_row.completed_at
    )
    on conflict (client_uuid) do nothing;

    update public.route_machine_visits
    set coffee_preparation = jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(coalesce(coffee_preparation, '{}'::jsonb),
                array['containers', v_row.container_id::text, 'accepted'], 'true'::jsonb, true),
              array['containers', v_row.container_id::text, 'actualBeforeQuantity'], to_jsonb(v_row.actual_before), true
            ),
            array['containers', v_row.container_id::text, 'packages'], '0'::jsonb, true
          ),
          array['containers', v_row.container_id::text, 'movedPackages'], '0'::jsonb, true
        ),
        synced_at = now()
    where id = v_row.visit_id;
  end loop;

  -- A draft explicitly requesting zero packages cannot justify a stale stock movement.
  -- There is no physical reading, so reverse accounting only and do not invent a visit item.
  for v_row in
    select * from recent_coffee_audit
    where category = 'movement_packages_zero_no_physical_reading'
    order by visit_id, container_id
  loop
    for v_batch in
      select
        m.batch_id,
        sum(case
          when m.to_stock_location_id = v_row.machine_location_id then m.quantity_base_units
          when m.from_stock_location_id = v_row.machine_location_id then -m.quantity_base_units
          else 0
        end) net_quantity
      from public.stock_movements_v13 m
      where m.reference_type = 'mobile_stock_request'
        and m.reference_id like format('route_visit_%s_container_%s_%%', v_row.visit_id, v_row.container_id)
        and m.product_id = v_row.product_id
      group by m.batch_id
      having sum(case
        when m.to_stock_location_id = v_row.machine_location_id then m.quantity_base_units
        when m.from_stock_location_id = v_row.machine_location_id then -m.quantity_base_units
        else 0
      end) > 0.0001
    loop
      v_reference := format(
        'route_visit_%s_container_%s_audit_back_%s_20261014',
        v_row.visit_id,
        v_row.container_id,
        coalesce(v_batch.batch_id::text, 'none')
      );

      if not exists (
        select 1 from public.stock_movements_v13
        where reference_type = 'mobile_stock_request'
          and reference_id = v_reference
      ) then
        perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
          'product_id', v_row.product_id,
          'batch_id', v_batch.batch_id,
          'from_stock_location_id', v_row.machine_location_id,
          'to_stock_location_id', v_row.vehicle_location_id,
          'movement_type', 'return',
          'quantity_base_units', v_batch.net_quantity,
          'reference_type', 'mobile_stock_request',
          'reference_id', v_reference,
          'note', format(
            'Systemova revize 14. 10. 2026 · navsteva #%s · %s: draft ma 0 baleni a chybi fyzicky zapis; stary pohyb vracen do vozidla bez domysleni fyzickeho stavu',
            v_row.visit_id, v_row.container_code
          )
        )));
      end if;
    end loop;

    update public.route_machine_visits
    set coffee_preparation = jsonb_set(
          coalesce(coffee_preparation, '{}'::jsonb),
          array['containers', v_row.container_id::text, 'movedPackages'],
          '0'::jsonb,
          true
        ),
        synced_at = now()
    where id = v_row.visit_id;
  end loop;
end
$$;

select jsonb_build_object(
  'draft_flags_repaired', (select count(*) from recent_coffee_audit where category = 'item_saved_accept_false'),
  'proven_no_fill_repaired', (select count(*) from recent_coffee_audit where category = 'missing_item_proven_no_fill'),
  'zero_package_movements_repaired', (select count(*) from recent_coffee_audit where category = 'movement_packages_zero_no_physical_reading'),
  'ambiguous_left_for_evidence_reconciliation', (select count(*) from recent_coffee_audit where category = 'missing_item_ambiguous')
) as repair_summary;

commit;

