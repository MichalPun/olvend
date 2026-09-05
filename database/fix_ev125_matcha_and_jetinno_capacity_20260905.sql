-- Jetinno JL300 EV125/EV126:
-- 1. instantni zasobniky Z2-Z7 maji fyzicke maximum 2,5 kg,
-- 2. oprava navstevy #610 na EV125: fyzicky byly vzaty a doplneny 2 kg Matchy,
--    nikoli chybne zapsane 3 kg.

begin;

do $$
declare
  v_ev125_id bigint;
  v_ev126_id bigint;
  v_matcha_container_id bigint;
  v_matcha_product_id bigint;
  v_machine_stock_location_id bigint;
  v_vehicle_stock_location_id bigint;
  v_updated integer;
  v_result jsonb;
begin
  select id into v_ev125_id
  from public.machines
  where evidence_number = 125
    and brand = 'Jetinno'
    and model = 'JL300';

  select id into v_ev126_id
  from public.machines
  where evidence_number = 126
    and brand = 'Jetinno'
    and model = 'JL300';

  if v_ev125_id is null or v_ev126_id is null then
    raise exception 'Jetinno EV125 nebo EV126 nebylo nalezeno.';
  end if;

  update public.machine_coffee_containers
  set capacity_quantity = 2500,
      note = concat_ws(' ', nullif(note, ''), 'Fyzicke maximum instantniho zasobniku upraveno na 2,5 kg dne 5. 9. 2026.'),
      updated_at = now()
  where machine_id in (v_ev125_id, v_ev126_id)
    and container_code in ('Z2','Z3','Z4','Z5','Z6','Z7')
    and unit = 'g'
    and active = true;

  get diagnostics v_updated = row_count;
  if v_updated <> 12 then
    raise exception 'Ocekavano 12 instantnich zasobniku Jetinno, upraveno %.', v_updated;
  end if;

  select id, product_id
  into v_matcha_container_id, v_matcha_product_id
  from public.machine_coffee_containers
  where machine_id = v_ev125_id
    and container_code = 'Z6'
    and product_sku = '262'
    and active = true;

  if v_matcha_container_id is null then
    raise exception 'Aktivni Matcha zasobnik Z6 na EV125 nebyl nalezen.';
  end if;

  if not exists (
    select 1
    from public.route_machine_visit_items
    where id = 18235
      and visit_id = 610
      and machine_id = v_ev125_id
      and coffee_container_id = v_matcha_container_id
      and actual_before_quantity = 0
      and actual_add_quantity = 3000
      and final_quantity = 3000
  ) then
    raise exception 'Dnesni chybny zaznam Matchy na EV125 uz neodpovida ocekavanemu stavu; oprava zastavena.';
  end if;

  select id into v_machine_stock_location_id
  from public.stock_locations
  where location_type = 'machine'
    and machine_id = v_ev125_id
    and active = true;

  select id into v_vehicle_stock_location_id
  from public.stock_locations
  where location_type = 'vehicle'
    and vehicle_id = 1
    and active = true;

  if v_machine_stock_location_id is null or v_vehicle_stock_location_id is null then
    raise exception 'Chybi skladove misto EV125 nebo vozidla 1.';
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where product_id = v_matcha_product_id
      and from_stock_location_id = v_vehicle_stock_location_id
      and to_stock_location_id = v_machine_stock_location_id
      and reference_type = 'mobile_stock_request'
      and reference_id like 'route_visit_610_container_617%'
      and quantity_base_units = 3
  ) then
    raise exception 'Puvodni chybny pohyb 3 kg Matchy nebyl nalezen.';
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'mobile_stock_request'
      and reference_id = 'repair_visit_610_ev125_matcha_return_1kg_20260905'
  ) then
    select public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
      'product_id', v_matcha_product_id,
      'batch_id', null,
      'from_stock_location_id', v_machine_stock_location_id,
      'to_stock_location_id', v_vehicle_stock_location_id,
      'movement_type', 'return',
      'quantity_base_units', 1,
      'reference_type', 'mobile_stock_request',
      'reference_id', 'repair_visit_610_ev125_matcha_return_1kg_20260905',
      'note', 'Oprava navstevy #610 EV125: fyzicky vzaty a doplneny 2 kg Matchy, chybne byly zapsany 3 kg; 1 kg vracen do vozidla Renault Kangoo Maxi 2TX7928.'
    ))) into v_result;

    if coalesce((v_result->>'inserted')::integer, 0) <> 1 then
      raise exception 'Vraceni 1 kg Matchy do vozidla se neprovedlo: %.', v_result;
    end if;
  end if;

  update public.route_machine_visit_items
  set actual_add_quantity = 2000,
      final_quantity = 2000,
      operator_note = concat_ws(' ', nullif(operator_note, ''), 'Opraveno 5. 9. 2026: fyzicky doplneny 2 kg; aplikace chybne obnovila puvodni navrh 3 kg.'),
      updated_at = now()
  where id = 18235
    and visit_id = 610
    and machine_id = v_ev125_id
    and coffee_container_id = v_matcha_container_id;

  update public.machine_coffee_containers
  set current_quantity = 2000,
      updated_at = now()
  where id = v_matcha_container_id;

  if exists (
    select 1
    from public.machine_coffee_containers
    where machine_id in (v_ev125_id, v_ev126_id)
      and container_code in ('Z2','Z3','Z4','Z5','Z6','Z7')
      and (capacity_quantity <> 2500 or current_quantity > capacity_quantity)
  ) then
    raise exception 'Po oprave zustal instantni zasobnik Jetinno s chybnou kapacitou nebo stavem nad kapacitou.';
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
