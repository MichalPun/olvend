-- Route 56 / Michaela Nerudova: reported physical fills differ from the saved visit.
-- EV 82 Hodonin: Nestea Peach slot 14, saved 1 pc, physically inserted 0.
-- EV 100 Rigum: ZON slot 54, saved 3 pcs, physically inserted 0.
-- The products were not physically present in the vehicle, so the false machine fills
-- are removed without returning phantom stock to the vehicle. A targeted vehicle audit
-- will reconcile the remaining book balance when the route is completed.

begin;

do $$
declare
  v_hodonin_item public.route_machine_visit_items%rowtype;
  v_rigum_item public.route_machine_visit_items%rowtype;
begin
  select * into strict v_hodonin_item
  from public.route_machine_visit_items
  where id = 6515
    and visit_id = 285
    and machine_id = 62
    and planogram_slot_id = 1887
    and actual_product_id = 99
    and actual_add_quantity = 1
    and final_quantity = 6;

  select * into strict v_rigum_item
  from public.route_machine_visit_items
  where id = 6554
    and visit_id = 287
    and machine_id = 80
    and planogram_slot_id = 2007
    and actual_product_id = 139
    and actual_add_quantity = 3
    and final_quantity = 6;

  if not exists (
    select 1 from public.stock_movements_v13
    where id = 44501
      and product_id = 99
      and batch_id = 462
      and from_stock_location_id = 3
      and to_stock_location_id = 40
      and quantity_base_units = 1
      and reference_id = 'route_visit_285_food_slot_1887_fill_0_99'
  ) then
    raise exception 'Hodonin Nestea movement no longer matches the audited fill.';
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where id = 44657
      and product_id = 139
      and batch_id = 474
      and from_stock_location_id = 3
      and to_stock_location_id = 31
      and quantity_base_units = 3
      and reference_id = 'route_visit_287_food_slot_2007_fill_0_139'
  ) then
    raise exception 'Rigum ZON movement no longer matches the audited fill.';
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = 'route56-visit285-hodonin-nestea-false-fill-20260817'
  ) then
    perform public.apply_stock_movements_v13(jsonb_build_array(
      jsonb_build_object(
        'product_id', 99,
        'batch_id', 462,
        'from_stock_location_id', 40,
        'to_stock_location_id', null,
        'movement_type', 'adjustment',
        'quantity_base_units', 1,
        'reference_type', 'data_repair',
        'reference_id', 'route56-visit285-hodonin-nestea-false-fill-20260817',
        'note', 'EV 82 / Hodonin / visit 285: operator physically inserted 0 of 1 saved Nestea Peach; false machine fill removed, vehicle shortage left for targeted audit',
        'allow_negative_source', false
      ),
      jsonb_build_object(
        'product_id', 139,
        'batch_id', 474,
        'from_stock_location_id', 31,
        'to_stock_location_id', null,
        'movement_type', 'adjustment',
        'quantity_base_units', 3,
        'reference_type', 'data_repair',
        'reference_id', 'route56-visit287-rigum-zon-false-fill-20260817',
        'note', 'EV 100 / Rigum / visit 287: operator physically inserted 0 of 3 saved ZON; false machine fill removed, vehicle shortage left for targeted audit',
        'allow_negative_source', false
      )
    ));
  end if;

  update public.route_machine_visit_items
  set actual_add_quantity = 0,
      final_quantity = actual_before_quantity,
      issue_type = 'missing_stock',
      operator_note = 'Připraveno 1 ks, fyzicky vloženo 0 ks. Operátorka uvedla, že Nestea nebyla ve vozidle. Falešné doplnění odstraněno; zůstatek vozidla ověří cílená inventura. Manažerská oprava 17. 8. 2026.',
      updated_at = now()
  where id = v_hodonin_item.id;

  update public.route_machine_visit_items
  set actual_add_quantity = 0,
      final_quantity = actual_before_quantity,
      issue_type = 'missing_stock',
      operator_note = 'Připraveno 3 ks, fyzicky vloženo 0 ks. Operátorka uvedla, že ZON nebyl ve vozidle. Falešné doplnění odstraněno; zůstatek vozidla ověří cílená inventura. Manažerská oprava 17. 8. 2026.',
      updated_at = now()
  where id = v_rigum_item.id;

  delete from public.route_machine_visit_food_fills
  where id = 2434 and visit_item_id = v_hodonin_item.id;

  delete from public.route_machine_visit_food_fills
  where id = 2453 and visit_item_id = v_rigum_item.id;

  update public.machine_planogram_slots
  set current_units = 5,
      last_units = 5,
      desired_units = 1,
      fill_percent = 83.33,
      updated_at = now()
  where id = 1887 and machine_id = 62 and slot_code = '14';

  update public.machine_planogram_slots
  set current_units = 3,
      last_units = 3,
      desired_units = 3,
      fill_percent = 50,
      updated_at = now()
  where id = 2007 and machine_id = 80 and slot_code = '54';

  update public.route_machine_visits
  set food_preparation = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  jsonb_set(
                    jsonb_set(coalesce(food_preparation, '{}'::jsonb), '{1887,fillItems,0,quantity}', '0'::jsonb, true),
                    '{1887,pickedQuantity}', '0'::jsonb, true
                  ),
                  '{1887,preparedQuantity}', '0'::jsonb, true
                ),
                '{1887,basePreparedQuantity}', '0'::jsonb, true
              ),
              '{1887,actualAdd}', '0'::jsonb, true
            ),
            '{1887,picked}', 'false'::jsonb, true
          ),
          '{1887,skipped}', 'true'::jsonb, true
        ),
        '{1887,skipReason}', '"not_in_vehicle"'::jsonb, true
      ),
      synced_at = now(),
      updated_at = now()
  where id = 285;

  update public.route_machine_visits
  set food_preparation = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  jsonb_set(
                    jsonb_set(coalesce(food_preparation, '{}'::jsonb), '{2007,fillItems,0,quantity}', '0'::jsonb, true),
                    '{2007,pickedQuantity}', '0'::jsonb, true
                  ),
                  '{2007,preparedQuantity}', '0'::jsonb, true
                ),
                '{2007,basePreparedQuantity}', '0'::jsonb, true
              ),
              '{2007,actualAdd}', '0'::jsonb, true
            ),
            '{2007,picked}', 'false'::jsonb, true
          ),
          '{2007,skipped}', 'true'::jsonb, true
        ),
        '{2007,skipReason}', '"not_in_vehicle"'::jsonb, true
      ),
      synced_at = now(),
      updated_at = now()
  where id = 287;
end
$$;

commit;

select jsonb_build_object(
  'items', (
    select jsonb_agg(jsonb_build_object(
      'id', item.id,
      'product', item.actual_product_name,
      'prepared', item.suggested_add_quantity,
      'inserted', item.actual_add_quantity,
      'final', item.final_quantity,
      'issue', item.issue_type
    ) order by item.id)
    from public.route_machine_visit_items item
    where item.id in (6515,6554)
  ),
  'slots', (
    select jsonb_agg(jsonb_build_object(
      'id', slot.id,
      'current', slot.current_units,
      'desired', slot.desired_units,
      'fill_percent', slot.fill_percent
    ) order by slot.id)
    from public.machine_planogram_slots slot
    where slot.id in (1887,2007)
  ),
  'vehicle_balances', (
    select jsonb_agg(jsonb_build_object(
      'product_id', grouped.product_id,
      'quantity', grouped.quantity
    ) order by grouped.product_id)
    from (
      select balance.product_id, sum(balance.quantity_on_hand) as quantity
      from public.stock_location_balances balance
      where balance.stock_location_id = 3 and balance.product_id in (99,139)
      group by balance.product_id
    ) grouped
  )
);
