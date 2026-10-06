-- EV 83 / OSRAM Bruntal / visit 1122: operator physically inserted three
-- Snack Mlska pieces into slot 25, but the mobile route allocator recorded one.
-- Move the two still-booked vehicle pieces into the machine and align the visit.

begin;

do $$
declare
  v_visit public.route_machine_visits%rowtype;
  v_item public.route_machine_visit_items%rowtype;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = 'ev83-visit1122-mlska-extra-2-20261006'
  ) then
    raise notice 'EV 83 visit 1122 Mlska repair already applied.';
    return;
  end if;

  select * into strict v_visit
  from public.route_machine_visits
  where id = 1122
    and route_plan_id = 141
    and route_plan_stop_id = 1688
    and machine_id = 63
    and vehicle_id = 4
    and visit_date = date '2026-10-06'
    and status = 'completed';

  select * into strict v_item
  from public.route_machine_visit_items
  where id = 31961
    and visit_id = v_visit.id
    and planogram_slot_id = 1733
    and actual_product_id = 238
    and actual_add_quantity = 1
    and final_quantity = 1
    and capacity_quantity = 3;

  if not exists (
    select 1
    from public.route_machine_visit_food_fills
    where id = 11725
      and visit_item_id = v_item.id
      and product_id = 238
      and quantity = 1
      and expiry_date = date '2026-10-13'
  ) then
    raise exception 'Original EV 83 Mlska fill no longer matches the audited visit.';
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where id = 154563
      and product_id = 238
      and batch_id = 828
      and from_stock_location_id = 58
      and to_stock_location_id = 54
      and quantity_base_units = 1
      and reference_id = 'route_visit_1122_food_slot_1733_fill_0_238'
  ) then
    raise exception 'Original EV 83 Mlska stock movement no longer matches the audited visit.';
  end if;

  if not exists (
    select 1
    from public.stock_location_balances
    where stock_location_id = 58
      and product_id = 238
      and batch_id = 828
      and quantity_on_hand >= 2
  ) then
    raise exception 'Opel Movano no longer has the two physical Mlska pieces required for this repair.';
  end if;

  perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
    'product_id', 238,
    'batch_id', 828,
    'from_stock_location_id', 58,
    'to_stock_location_id', 54,
    'movement_type', 'fill_machine',
    'quantity_base_units', 2,
    'reference_type', 'data_repair',
    'reference_id', 'ev83-visit1122-mlska-extra-2-20261006',
    'note', 'EV 83 / OSRAM Bruntal / visit 1122 / slot 25: operator physically inserted 3 Mlska, mobile recorded 1; add the missing 2 pieces',
    'allow_negative_source', false
  )));

  update public.route_machine_visit_items
  set actual_add_quantity = 3,
      final_quantity = 3,
      issue_type = 'none',
      substitution_reason = null,
      operator_note = 'Cena na automatu potvrzena: 55 Kc -> 44 Kc. Fyzicky doplneny 3 ks Snack Mlska, expirace 2026-10-13. Evidence opravena 6. 10. 2026.',
      updated_at = now()
  where id = v_item.id;

  update public.route_machine_visit_food_fills
  set quantity = 3,
      correction_sources = jsonb_build_array(jsonb_build_object(
        'product_id', 238,
        'batch_id', 828,
        'quantity', 3
      ))
  where id = 11725
    and visit_item_id = v_item.id;

  update public.machine_planogram_slots
  set current_units = 3,
      desired_units = 0,
      fill_percent = 100,
      updated_at = now()
  where id = 1733
    and machine_id = 63
    and slot_code = '25'
    and capacity_units = 3;

  update public.route_machine_visits
  set food_preparation = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(coalesce(food_preparation, '{}'::jsonb), '{1733,fillItems,0,quantity}', '3'::jsonb, true),
                '{1733,pickedQuantity}', '3'::jsonb, true
              ),
              '{1733,preparedQuantity}', '3'::jsonb, true
            ),
            '{1733,basePreparedQuantity}', '3'::jsonb, true
          ),
          '{1733,extraVehicleQuantity}', '0'::jsonb, true
        ),
        '{1733,actualAdd}', '3'::jsonb, true
      ),
      synced_at = now(),
      updated_at = now()
  where id = v_visit.id;
end
$$;

commit;

select jsonb_build_object(
  'visit_item', (
    select jsonb_build_object(
      'id', id,
      'suggested', suggested_add_quantity,
      'inserted', actual_add_quantity,
      'final', final_quantity,
      'capacity', capacity_quantity
    )
    from public.route_machine_visit_items
    where id = 31961
  ),
  'fill', (
    select jsonb_build_object('id', id, 'quantity', quantity, 'expiry', expiry_date)
    from public.route_machine_visit_food_fills
    where id = 11725
  ),
  'slot', (
    select jsonb_build_object(
      'id', id,
      'current', current_units,
      'desired', desired_units,
      'capacity', capacity_units,
      'fill_percent', fill_percent
    )
    from public.machine_planogram_slots
    where id = 1733
  ),
  'vehicle_balance', (
    select quantity_on_hand
    from public.stock_location_balances
    where stock_location_id = 58 and product_id = 238 and batch_id = 828
  ),
  'machine_balance', (
    select quantity_on_hand
    from public.stock_location_balances
    where stock_location_id = 54 and product_id = 238 and batch_id = 828
  )
) as verification;
