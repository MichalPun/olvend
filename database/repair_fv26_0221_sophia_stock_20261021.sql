begin;

do $$
declare
  v_movement public.stock_movements_v13%rowtype;
  v_balance public.stock_location_balances%rowtype;
  v_old_quantity numeric(12,3) := 5000.000;
  v_new_quantity numeric(12,3) := 5.000;
  v_correction numeric(12,3) := 4995.000;
  v_marker text := 'Oprava 21. 10. 2026: FV26-0221, 10 × 0,5 kg Sophia = 5 kg';
begin
  select *
    into v_movement
  from public.stock_movements_v13
  where id = 183927
  for update;

  if not found then
    raise exception 'Skladový pohyb 183927 pro FV26-0221 nebyl nalezen.';
  end if;

  if v_movement.quantity_base_units = v_new_quantity
     and position(v_marker in coalesce(v_movement.note, '')) > 0 then
    return;
  end if;

  if v_movement.product_id is distinct from 108
     or v_movement.movement_type is distinct from 'sale'
     or v_movement.from_stock_location_id is null
     or v_movement.to_stock_location_id is not null
     or v_movement.reference_type is distinct from 'sales_document'
     or v_movement.quantity_base_units is distinct from v_old_quantity
     or coalesce(v_movement.note, '') not ilike '%FV26-0221%'
     or coalesce(v_movement.note, '') not ilike '%Sophia%'
     or coalesce(v_movement.note, '') not ilike '%10 × 0,5 kg%'
     or coalesce(v_movement.note, '') not ilike '%5%000 kg%'
  then
    raise exception 'Skladový pohyb 183927 není v očekávaném původním stavu; oprava byla zastavena.';
  end if;

  select *
    into v_balance
  from public.stock_location_balances
  where id = 46
    and stock_location_id = v_movement.from_stock_location_id
    and product_id = v_movement.product_id
    and batch_id is null
  for update;

  if not found then
    raise exception 'Očekávaný skladový zůstatek Sophia id 46 nebyl nalezen; oprava byla zastavena.';
  end if;

  update public.stock_movements_v13
  set quantity_base_units = v_new_quantity,
      note = concat_ws(' · ', nullif(note, ''), v_marker)
  where id = v_movement.id;

  update public.stock_location_balances
  set quantity_on_hand = round((quantity_on_hand + v_correction)::numeric, 3),
      updated_at = now()
  where id = v_balance.id;
end
$$;

commit;
