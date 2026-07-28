-- Oprava dvou nesouladů mezi návštěvou automatu a skladem Opelu Combo dne 28. 7. 2026.
--
-- 1) Kabelové Bubny / návštěva 7 / zásobník 250:
--    před návštěvou 100 ks, kapacita 400 ks => skutečně lze doplnit nejvýše 300 ks.
--    Pohyb do automatu chyběl celý.
-- 2) SWR / návštěva 10 / zásobník 259:
--    potvrzeno 50 ks, ale ze skladového místa vozidla odešlo 100 ks.
--
-- Součástí jsou dvě inventurní korekce dotčených kelímků podle fyzického soupisu
-- Opelu Combo po trase: 250 ml = 100 ks, 180 ml = 950 ks.

do $$
begin
  -- Oprav uložené skutečné doplnění Kabelových Buben podle kapacity zásobníku.
  update public.route_machine_visit_items
  set
    actual_add_quantity = 300,
    final_quantity = 400,
    operator_note = concat_ws(
      ' · ',
      nullif(operator_note, ''),
      'Oprava 28. 7. 2026: zásobník 100/400 ks, skutečné doplnění nejvýše 300 ks'
    ),
    updated_at = now()
  where id = 49
    and visit_id = 7
    and coffee_container_id = 250
    and actual_add_quantity <> 300;

  -- Starší rozdíl před dnešní návštěvou: +50 ks, aby po správném výdeji
  -- 300 ks odpovídal stav vozidla fyzicky spočítaným 100 ks.
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'vehicle-inventory:combo-20260728-cup250-baseline'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 79,
          'batch_id', null,
          'from_stock_location_id', null,
          'to_stock_location_id', 6,
          'movement_type', 'adjustment',
          'quantity_base_units', 50,
          'reference_type', 'vehicle_inventory_audit_correction',
          'reference_id', 'vehicle-inventory:combo-20260728-cup250-baseline',
          'note', 'Fyzická kontrola Opel Combo po trase 28. 7. 2026 · dorovnání před opravou chybějícího výdeje kelímků 250 ml'
        )
      )
    );
  end if;

  -- Chybějící výdej 300 ks z Comba do konkrétního automatu Kabelové Bubny.
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'mobile_stock_request'
      and reference_id = 'route_visit_7_container_250_reconcile_in_300'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 79,
          'batch_id', null,
          'from_stock_location_id', 6,
          'to_stock_location_id', 8,
          'movement_type', 'fill_machine',
          'quantity_base_units', 300,
          'reference_type', 'mobile_stock_request',
          'reference_id', 'route_visit_7_container_250_reconcile_in_300',
          'note', 'Oprava návštěvy 7 · Kabelové Bubny · kelímek 250 ml · 100 → 400 ks, doplněno 300 ks'
        )
      )
    );
  end if;

  -- Vrať 50 ks, které byly u SWR odečtené navíc.
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'mobile_stock_request'
      and reference_id = 'route_visit_10_container_259_reconcile_back_50'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 78,
          'batch_id', null,
          'from_stock_location_id', 10,
          'to_stock_location_id', 6,
          'movement_type', 'return',
          'quantity_base_units', 50,
          'reference_type', 'mobile_stock_request',
          'reference_id', 'route_visit_10_container_259_reconcile_back_50',
          'note', 'Oprava návštěvy 10 · SWR · potvrzeno 50 ks místo původně odečtených 100 ks'
        )
      )
    );
  end if;

  -- Po vrácení nadbytečného odpisu dorovnej vozidlo na fyzických 950 ks.
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'vehicle-inventory:combo-20260728-cup180-baseline'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 78,
          'batch_id', null,
          'from_stock_location_id', 6,
          'to_stock_location_id', null,
          'movement_type', 'adjustment',
          'quantity_base_units', 100,
          'reference_type', 'vehicle_inventory_audit_correction',
          'reference_id', 'vehicle-inventory:combo-20260728-cup180-baseline',
          'note', 'Fyzická kontrola Opel Combo po trase 28. 7. 2026 · kelímek 180 ml dorovnán na 950 ks'
        )
      )
    );
  end if;
end
$$;
