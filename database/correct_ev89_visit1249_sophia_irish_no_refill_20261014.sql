begin;

do $$
declare
  v_visit_id constant bigint := 1249;
  v_machine_id constant bigint := 69;
  v_vehicle_location_id constant bigint := 93;
  v_machine_location_id constant bigint := 48;
  v_accepted_at timestamptz;
  v_row record;
begin
  select completed_at into v_accepted_at
  from public.route_machine_visits
  where id = v_visit_id
    and machine_id = v_machine_id
    and vehicle_id = 6
    and status = 'completed'
    and visit_date = date '2026-10-13'
  for update;

  if not found then
    raise exception 'Navsteva #1249 neodpovida EV 89 dne 13. 10. 2026.';
  end if;

  for v_row in
    select *
    from (values
      (471::bigint, 'Z5'::text, 108::bigint, '44'::text, 'oVe FD COFFEE SOPHIA 500g'::text,
       427.100::numeric, 500.000::numeric, 1000.000::numeric, 0.500::numeric,
       '12490000-0000-4000-8000-000000000471'::uuid,
       'route_visit_1249_container_471_sync_back_user_confirmation_20261014'::text),
      (472::bigint, 'Z6'::text, 110::bigint, '46'::text, 'Irish Cream 1 kg'::text,
       1292.000::numeric, 1000.000::numeric, 2000.000::numeric, 1.000::numeric,
       '12490000-0000-4000-8000-000000000472'::uuid,
       'route_visit_1249_container_472_sync_back_user_confirmation_20261014'::text)
    ) as x(container_id, container_code, product_id, sku, product_name,
           actual_before, suggested_add, capacity, movement_quantity,
           client_uuid, return_reference)
  loop
    perform 1
    from public.machine_coffee_containers container
    where container.id = v_row.container_id
      and container.machine_id = v_machine_id
      and container.product_id = v_row.product_id
      and container.container_code = v_row.container_code
    for update;

    if not found then
      raise exception 'EV 89 / % se zmenil; korekce nebyla provedena.', v_row.container_code;
    end if;

    if not exists (
      select 1
      from public.stock_movements_v13 movement
      where movement.reference_type = 'mobile_stock_request'
        and movement.reference_id like format('route_visit_1249_container_%s_sync_in_%%', v_row.container_id)
        and movement.product_id = v_row.product_id
        and movement.batch_id is null
        and movement.from_stock_location_id = v_vehicle_location_id
        and movement.to_stock_location_id = v_machine_location_id
        and movement.movement_type = 'fill_machine'
        and movement.quantity_base_units = v_row.movement_quantity
    ) then
      raise exception 'Puvodni chybny prevod pro navstevu #1249 / % nebyl nalezen.', v_row.container_code;
    end if;

    if not exists (
      select 1 from public.stock_movements_v13
      where reference_type = 'mobile_stock_request'
        and reference_id = v_row.return_reference
    ) then
      perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
        'product_id', v_row.product_id,
        'batch_id', null,
        'from_stock_location_id', v_machine_location_id,
        'to_stock_location_id', v_vehicle_location_id,
        'movement_type', 'return',
        'quantity_base_units', v_row.movement_quantity,
        'reference_type', 'mobile_stock_request',
        'reference_id', v_row.return_reference,
        'note', format(
          'EV 89 · navsteva #1249 · Michal Puncochar potvrdil, ze 13. 10. nebylo nic doplneno; chybny prevod %s vracen do vozidla',
          v_row.product_name
        )
      )));
    end if;

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
      v_visit_id, v_row.client_uuid, v_machine_id, 'coffee_container', v_row.container_id,
      v_row.container_code,
      v_row.product_id, v_row.sku, v_row.product_name,
      v_row.product_id, v_row.sku, v_row.product_name,
      null, v_row.actual_before,
      v_row.suggested_add, 0, 0,
      v_row.actual_before, v_row.capacity, 'g',
      'telemetry_mismatch',
      format(
        'Oprava 14. 10. 2026 podle potvrzeni Michala Puncochare: pri navsteve 13. 10. nebylo nic doplneno. Fyzicky stav %s g byl zpetne overen z mereni pri navsteve #1274 a telemetricke spotreby mezi navstevami.',
        v_row.actual_before
      ),
      v_accepted_at
    )
    on conflict (client_uuid) do update
    set actual_before_quantity = excluded.actual_before_quantity,
        suggested_add_quantity = excluded.suggested_add_quantity,
        actual_add_quantity = 0,
        removed_quantity = 0,
        final_quantity = excluded.final_quantity,
        capacity_quantity = excluded.capacity_quantity,
        issue_type = excluded.issue_type,
        operator_note = excluded.operator_note,
        accepted_at = excluded.accepted_at,
        updated_at = now();

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
    where id = v_visit_id;
  end loop;
end
$$;

commit;

select jsonb_build_object(
  'items', (
    select jsonb_agg(jsonb_build_object(
      'container', coffee_container_id,
      'actual_before', actual_before_quantity,
      'actual_add', actual_add_quantity,
      'final', final_quantity
    ) order by coffee_container_id)
    from public.route_machine_visit_items
    where visit_id = 1249 and coffee_container_id in (471, 472)
  ),
  'visit_471', (select coffee_preparation->'containers'->'471' from public.route_machine_visits where id = 1249),
  'visit_472', (select coffee_preparation->'containers'->'472' from public.route_machine_visits where id = 1249),
  'returns', (
    select jsonb_agg(jsonb_build_object('product', product_id, 'quantity', quantity_base_units, 'reference', reference_id) order by product_id)
    from public.stock_movements_v13
    where reference_id in (
      'route_visit_1249_container_471_sync_back_user_confirmation_20261014',
      'route_visit_1249_container_472_sync_back_user_confirmation_20261014'
    )
  )
) as verification;

