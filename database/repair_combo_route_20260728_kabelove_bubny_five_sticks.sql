-- Zpřesnění opravy Kabelových Buben podle potvrzení operátorky:
-- do zásobníku Z8 vložila 5 tyčí po 50 ks, tedy 250 ks.
--
-- Předchozí technická oprava počítala s maximem 300 ks podle volné kapacity.
-- Tento skript vrací rozdíl 50 ks do vozidla, současně jej inventurně odečte,
-- aby Opel Combo zůstal na fyzicky spočítaných 100 ks, a opraví stav zásobníku.

do $$
begin
  update public.route_machine_visit_items
  set
    actual_add_quantity = 250,
    final_quantity = 350,
    operator_note = 'Potvrzeno operátorkou: 5 tyčí po 50 ks, celkem 250 ks',
    updated_at = now()
  where id = 49
    and visit_id = 7
    and coffee_container_id = 250
    and (
      actual_add_quantity is distinct from 250
      or final_quantity is distinct from 350
      or operator_note is distinct from 'Potvrzeno operátorkou: 5 tyčí po 50 ks, celkem 250 ks'
    );

  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'mobile_stock_request'
      and reference_id = 'route_visit_7_container_250_operator_confirmed_back_50'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 79,
          'batch_id', null,
          'from_stock_location_id', 8,
          'to_stock_location_id', 6,
          'movement_type', 'return',
          'quantity_base_units', 50,
          'reference_type', 'mobile_stock_request',
          'reference_id', 'route_visit_7_container_250_operator_confirmed_back_50',
          'note', 'Kabelové Bubny · zpřesnění na 5 tyčí po 50 ks · vrácení rozdílu 50 ks'
        )
      )
    );

    update public.machine_coffee_containers
    set
      current_quantity = 331,
      refill_package_quantity = 50,
      updated_at = now()
    where id = 250;
  else
    update public.machine_coffee_containers
    set
      refill_package_quantity = 50,
      updated_at = now()
    where id = 250
      and refill_package_quantity is distinct from 50;
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'vehicle-inventory:combo-20260728-cup250-five-sticks'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 79,
          'batch_id', null,
          'from_stock_location_id', 6,
          'to_stock_location_id', null,
          'movement_type', 'adjustment',
          'quantity_base_units', 50,
          'reference_type', 'vehicle_inventory_audit_correction',
          'reference_id', 'vehicle-inventory:combo-20260728-cup250-five-sticks',
          'note', 'Fyzická kontrola Opel Combo · po potvrzení 5 tyčí v Kabelových Bubnech zůstává 100 ks'
        )
      )
    );
  end if;
end
$$;
