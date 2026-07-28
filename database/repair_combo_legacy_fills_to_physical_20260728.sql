-- Dorovnání starých převodů Opel Combo -> souhrnný sklad Automaty
-- podle reportu Filled Products 29. 4. - 28. 7. 2026 a fyzické inventury
-- vozidla po trase 28. 7. 2026.
--
-- Nové mobilní výdeje do konkrétních automatů zůstávají beze změny.
-- Kelímky a víčka tento skript záměrně neřeší.

do $$
begin
  -- Cukr: stará nakládka 10 pytlů byla zapsána jako 10 kg místo 15 kg.
  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-sugar-load-bags-to-kg'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 42,
        'batch_id', null,
        'from_stock_location_id', 1,
        'to_stock_location_id', 6,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 5,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-sugar-load-bags-to-kg',
        'note', 'Oprava staré nakládky: 10 pytlů × 1,5 kg = 15 kg, původně zapsáno 10 kg'
      ))
    );
  end if;

  -- Cukr: staré doplnění 5 pytlů bylo zapsáno jako 5 kg místo 7,5 kg.
  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-sugar-fill-bags-to-kg'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 42,
        'batch_id', null,
        'from_stock_location_id', 6,
        'to_stock_location_id', 5,
        'movement_type', 'fill_machine',
        'quantity_base_units', 2.5,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-sugar-fill-bags-to-kg',
        'note', 'Oprava starého doplnění: 5 pytlů × 1,5 kg = 7,5 kg, původně zapsáno 5 kg'
      ))
    );
  end if;

  -- Starý report proti OLVEND: chybějící výdeje do souhrnného skladu Automaty.
  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-creamer-fill'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 104, 'batch_id', null,
        'from_stock_location_id', 6, 'to_stock_location_id', 5,
        'movement_type', 'fill_machine', 'quantity_base_units', 4,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-creamer-fill',
        'note', 'Dorovnání starého Filled Products reportu · creamer 4 kg'
      ))
    );
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-cocoa-fill'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 106, 'batch_id', null,
        'from_stock_location_id', 6, 'to_stock_location_id', 5,
        'movement_type', 'fill_machine', 'quantity_base_units', 4,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-cocoa-fill',
        'note', 'Dorovnání starého Filled Products reportu · kakao 4 kg'
      ))
    );
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-irish-fill'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 110, 'batch_id', null,
        'from_stock_location_id', 6, 'to_stock_location_id', 5,
        'movement_type', 'fill_machine', 'quantity_base_units', 3,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-irish-fill',
        'note', 'Dorovnání starého Filled Products reportu · Irish 3 kg'
      ))
    );
  end if;

  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-pistachio-fill'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 103, 'batch_id', null,
        'from_stock_location_id', 6, 'to_stock_location_id', 5,
        'movement_type', 'fill_machine', 'quantity_base_units', 1,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-pistachio-fill',
        'note', 'Dorovnání starého Filled Products reportu · pistácie 1 kg'
      ))
    );
  end if;

  -- VendSoft vykazoval 7 kg jako Elite, fyzicky i v OLVEND jde o Barbera Tris.
  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-tris-elite-mapping-fill'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 26, 'batch_id', null,
        'from_stock_location_id', 6, 'to_stock_location_id', 5,
        'movement_type', 'fill_machine', 'quantity_base_units', 2,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-tris-elite-mapping-fill',
        'note', 'Dorovnání starého reportu: VendSoft Elite, fyzicky Barbera Tris · 2 kg'
      ))
    );
  end if;

  -- Sophia byla ve starých převodech odečtena o 2 kg navíc.
  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-legacy-20260728-sophia-return'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 108, 'batch_id', null,
        'from_stock_location_id', 5, 'to_stock_location_id', 6,
        'movement_type', 'return', 'quantity_base_units', 2,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-legacy-20260728-sophia-return',
        'note', 'Vrácení starého nadbytečného odpisu Sophie · 2 kg'
      ))
    );
  end if;

  -- Karamel je fyzicky v autě, ale nemá žádný historický pohyb.
  if not exists (
    select 1 from public.stock_movements_v13
    where reference_type = 'vehicle_inventory_audit_correction'
      and reference_id = 'combo-physical-20260728-caramel'
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(jsonb_build_object(
        'product_id', 40, 'batch_id', null,
        'from_stock_location_id', null, 'to_stock_location_id', 6,
        'movement_type', 'adjustment', 'quantity_base_units', 1000,
        'reference_type', 'vehicle_inventory_audit_correction',
        'reference_id', 'combo-physical-20260728-caramel',
        'note', 'Fyzická inventura Opel Combo 28. 7. 2026 · karamel 1 kg'
      ))
    );
  end if;
end
$$;
